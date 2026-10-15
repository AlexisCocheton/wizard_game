extends Node
## Audio : effets (400 Sounds Pack, FreeSFX), musiques (16-bit RPG Music,
## xDeviruchi) et VOIX DU MAGE (Mage Voice Pack), charges depuis assets/.
## Inerte en headless.
##
## VAGUE 10 (revue globale, chantier A4). Le son etait reste celui du premier
## prototype quand l image avait ete refaite deux fois : une seule mort, un seul
## coup, un seul son pour tous les objets de terrain, une seule musique de combat
## pour 21 niveaux, des voix extraites mais jamais declenchees. Ce fichier porte
## maintenant les CHOIX (quel son pour quel monstre, quel objet, quel sort, quelle
## musique pour quel acte, quelle replique a quel moment) sous forme de tables
## statiques, verifiees par tests/unit/test_audio_w10.gd sans serveur audio.

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const VOICE_DIR := "res://assets/voice/"
## 14 et non 10 : chaque famille de monstres a maintenant son son, et une vague
## dense en declenche plusieurs dans la meme image.
const POOL_SIZE: int = 14

## La voix a SON lecteur, pas la reserve des bruitages.
##
## Deux raisons, et la seconde compte plus que la premiere :
##   - une replique dure une seconde ou deux, la ou un bruitage dure 200 ms :
##     elle monopoliserait un lecteur de la reserve a chaque fois ;
##   - surtout, deux repliques qui se SUPERPOSENT donnent un mage qui se parle
##     par-dessus. Un seul lecteur garantit qu une voix en interrompt une autre
##     au lieu de s y ajouter.
var _voice: AudioStreamPlayer = null
## Secondes avant qu une nouvelle replique soit permise. Sans ce repit, un sort
## lance toutes les 1,5 s a 400 % de vitesse fait parler le mage en continu.
const VOICE_COOLDOWN: float = 2.5
var _voice_libre_a: float = 0.0

var _muted: bool = false
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer = null
var _current_music: StringName = &""
var _music_gain_db: float = 0.0
var _music_fade: Tween = null
var _streams: Dictionary = {}
## Hasard PROPRE au son (hauteur des coups, variantes, repliques) : le hasard
## global ou celui du monde ne doivent pas bouger parce qu une voix a ete tiree.
var _rng := RandomNumberGenerator.new()
## cle -> instant (s) de la derniere lecture, pour la limite de cadence.
var _last_play: Dictionary = {}


func _ready() -> void:
	_muted = DisplayServer.get_name() == "headless"
	if _muted:
		return
	_rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Master"
	add_child(_voice)
	apply_settings()
	# La jauge de vitesse est un autoload charge AVANT celui-ci : on l ecoute
	# ici plutot que d ajouter un appel sonore dans chaque ecran qui la montre.
	if not SpeedGauge.multiplier_changed.is_connected(_on_speed_changed):
		SpeedGauge.multiplier_changed.connect(_on_speed_changed)
	if not SpeedGauge.death_started.is_connected(_on_death_started):
		SpeedGauge.death_started.connect(_on_death_started)


func _stream(dir: String, key: StringName, ext: String) -> AudioStream:
	var path: String = dir + String(key) + ext
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_streams[path] = s
	return s


func _now() -> float:
	return float(Time.get_ticks_msec()) * 0.001


## Relit les volumes dans SaveData et les pousse sur les bus audio.
func apply_settings() -> void:
	if _muted:
		return
	var master: float = clampf(float(SaveData.get_setting("master_volume", 0.8)), 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(master, 0.0001)))
		AudioServer.set_bus_mute(idx, master <= 0.0)
	if _music != null:
		_music.volume_db = _music_volume_db()


func _music_volume_db() -> float:
	var mv: float = clampf(float(SaveData.get_setting("music_volume", 0.6)), 0.0, 1.0)
	return linear_to_db(maxf(mv, 0.0001)) + _music_gain_db


# --- BRUITAGES ----------------------------------------------------------------

## Deux lectures du MEME son a moins de cet ecart n en font qu une. Une zone qui
## touche six monstres dans la meme image donnait six « coups » superposes : un
## seul claquement six fois plus fort, l agression exacte que demandait d eviter
## la revue. 50 ms est sous le seuil ou l oreille separe deux attaques.
const SFX_MIN_INTERVAL: float = 0.05
## Et jamais plus de trois exemplaires du meme son en meme temps.
const SFX_MAX_SAME: int = 3
## Ecart de hauteur des sons FREQUENTS (coups, morts, tirs) : dix fois le meme
## echantillon a la meme hauteur sonne comme une mitrailleuse.
const PITCH_SPREAD: float = 0.07

## Variantes tirees au hasard : la cle de gauche est celle que le jeu demande.
const VARIANTS: Dictionary = {
	"die_human": [&"die_human", &"die_human_2", &"die_human_3"],
}


## La cadence permet-elle de jouer ce son ? Statique et pure : le test la
## verifie sans serveur audio.
static func may_play(now: float, last_at: float, playing_same: int) -> bool:
	if playing_same >= SFX_MAX_SAME:
		return false
	return last_at < 0.0 or now - last_at >= SFX_MIN_INTERVAL


static func is_frequent(key: StringName) -> bool:
	var k: String = String(key)
	return k.begins_with("hit") or k.begins_with("die_") or k == "enemy_die" \
		or k == "throw" or k == "arrow" or k == "spell_shot"


static func sfx_gain_db(key: StringName) -> float:
	return float(SFX_GAIN_DB.get(String(key), 0.0))


static func music_gain_db(key: StringName) -> float:
	return float(MUSIC_GAIN_DB.get(String(key), 0.0))


func play_sfx(key: StringName) -> void:
	if _muted or _pool.is_empty() or key == &"":
		return
	if VARIANTS.has(String(key)):
		var v: Array = VARIANTS[String(key)]
		key = v[_rng.randi() % v.size()]
	var s: AudioStream = _stream(SFX_DIR, key, ".wav")
	if s == null:
		return
	var meme: int = 0
	for p in _pool:
		if p.playing and p.stream == s:
			meme += 1
	var maintenant: float = _now()
	if not may_play(maintenant, float(_last_play.get(key, -1.0)), meme):
		return
	_last_play[key] = maintenant
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = linear_to_db(clampf(float(SaveData.get_setting("sfx_volume", 1.0)),
		0.0001, 1.0)) + sfx_gain_db(key)
	p.pitch_scale = 1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD) \
		if is_frequent(key) else 1.0
	p.play()


# --- MONSTRES : un son par FAMILLE ----------------------------------------------
##
## La famille se lit sur la FEUILLE du monstre (`EnemyDef.anim_key`) : c est ce
## que le joueur voit, donc ce qu il s attend a entendre. Une gelee qui meurt
## eclate, un golem s eboule, un mage s eteint. Les exceptions (le Miroir est de
## verre, les echos sont des spectres) sont dans ENEMY_FAMILY.

const SHEET_FAMILY: Dictionary = {
	"slimer": "slime", "slime_big": "slime", "slime_colossal": "slime",
	"slime_ghost": "slime", "slime_skeleton": "slime", "blood": "slime",
	"demonslime": "slime", "poison_ball": "slime",
	"skeleton2": "bone", "executioner": "bone", "ghoul": "bone",
	"golem_blue": "stone", "golem_orange": "stone", "mechagolem": "stone",
	"totem_tower": "wood",
	"warrior_red": "metal", "warrior_black": "metal", "warrior_yellow": "metal",
	"lancer_red": "metal", "lancer_purple": "metal", "lancer_yellow": "metal",
	"juggernaut": "metal", "chaosknight": "metal", "decepticle": "metal",
	"dog": "beast", "dino": "beast", "fox": "beast", "fireworm": "beast", "gorgon": "beast",
	"peacock": "bird", "vulture": "bird",
	"flyer": "insect", "beetle": "insect", "flyingeye": "insect",
	"pawn_red": "human", "pawn_yellow": "human", "pawn_purple": "human",
	"pawn_black": "human", "monk_black": "human", "monk_purple": "human",
	"archer_red": "human", "goblin2": "human", "soldier": "human",
	"monk_blue": "arcane", "evilwizard": "arcane", "mageguardian": "arcane",
	"mageguardian_red": "arcane", "mageguardian_magenta": "arcane", "bluewitch": "arcane",
	"demon": "demon", "demonlord": "demon", "cacodaemon": "demon",
	"wraith": "ghost", "unhallowed": "ghost", "nightborne": "ghost",
	"mushroom": "plant", "smallmonster": "plant",
}

const ENEMY_FAMILY: Dictionary = {
	# Le Miroir de Forge et ses eclats : du verre, pas un mage.
	"glass_mirror": "glass", "mirror_shard": "glass",
	# L Ombre porte la feuille du vautour, teintee en spectre.
	"shade": "ghost",
	# Les echos des anciens boss (acte 5) sont pales et translucides : des
	# souvenirs, ils ne s ecroulent pas comme le boss qu ils imitent.
	# Vague 10 (chantier B2) : les echos des quatre seigneurs sont retires ; les
	# boss revenus en echo (mini-boss ou ordinaires) sont des spectres aussi.
	"chronos_echo": "ghost", "warden_echo": "ghost", "reliquary_echo": "ghost",
	"great_eye_echo": "ghost", "dark_mage_echo": "ghost", "tombol_echo": "ghost",
	"gravecaller_echo": "ghost",
}

## famille -> [coup, mort]. `flesh` est le repli : les sons historiques.
const FAMILY_SFX: Dictionary = {
	"flesh": [&"hit", &"enemy_die"],
	"slime": [&"hit_slime", &"die_slime"],
	"bone": [&"hit_bone", &"die_bone"],
	"stone": [&"hit_stone", &"die_stone"],
	"wood": [&"hit_wood", &"wood_break"],
	"metal": [&"hit_metal", &"die_metal"],
	"beast": [&"hit", &"die_beast"],
	"bird": [&"hit", &"die_bird"],
	"insect": [&"hit", &"die_insect"],
	"human": [&"hit", &"die_human"],
	"arcane": [&"hit", &"die_arcane"],
	"demon": [&"hit", &"die_demon"],
	"ghost": [&"hit_ghost", &"die_ghost"],
	"plant": [&"hit_wood", &"die_plant"],
	"glass": [&"hit_glass", &"die_glass"],
}


static func enemy_family(def: EnemyDef) -> String:
	if def == null:
		return "flesh"
	if ENEMY_FAMILY.has(String(def.id)):
		return String(ENEMY_FAMILY[String(def.id)])
	return String(SHEET_FAMILY.get(String(def.anim_key), "flesh"))


static func enemy_hit_key(def: EnemyDef) -> StringName:
	return FAMILY_SFX[enemy_family(def)][0]


static func enemy_death_key(def: EnemyDef) -> StringName:
	return FAMILY_SFX[enemy_family(def)][1]


## Tir d un monstre : la fleche pour qui porte un arc ou une arme, le trait
## magique pour un mage, un jet pour le reste (une bete ne decoche rien).
static func shot_sfx_key(def: EnemyDef) -> StringName:
	match enemy_family(def):
		"human", "metal":
			return &"arrow"
		"arcane", "ghost", "glass":
			return &"spell_shot"
	return &"throw"


func play_enemy_hit(def: EnemyDef) -> void:
	play_sfx(enemy_hit_key(def))


## Un boss garde l explosion qui annonce la fin du combat, EN PLUS du cri de sa
## famille : sans le cri, Malyk et le Golem mouraient du meme bruit.
func play_enemy_death(def: EnemyDef) -> void:
	if def != null and def.is_boss():
		play_sfx(&"explosion")
	play_sfx(enemy_death_key(def))


# --- OBJETS DE TERRAIN ET MURS --------------------------------------------------
##
## Tous les objets sonnaient `wall` (un coup sourd) : un arbre qu on plante, une
## fosse qu on creuse et un autel qu on dresse se confondaient a l oreille, et la
## perte d un objet ne se distinguait pas de sa pose.

## TerrainProp.Kind -> [pose, bris]. Indexe par la VALEUR de l enum (TREE=0...).
const PROP_SFX: Array = [
	[&"wood_creak", &"wood_break"],         # TREE
	[&"water_splash", &"water_drop"],       # WATER
	[&"water_flow", &"water_flow"],         # RIVER
	[&"bramble_rustle", &"bramble_rustle"], # BRAMBLE
	[&"earth_dig", &"wall_break"],          # PIT
	[&"altar_hum", &"armor_break"],         # ALTAR
]


static func prop_sfx_key(kind: int, broken: bool) -> StringName:
	if kind < 0 or kind >= PROP_SFX.size():
		return &"wall"
	return PROP_SFX[kind][1 if broken else 0]


## Un mur porte l element de sa carte (vague 8) : un mur de glace tinte et se
## fend, un mur de pierre ou d ecorce cogne et s eboule.
static func wall_sfx_key(tags: Array, broken: bool) -> StringName:
	if GameEnums.DamageTag.ICE in tags:
		return &"ice_crack" if broken else &"ice_wall"
	return &"wall_break" if broken else &"wall"


# --- SORTS ----------------------------------------------------------------------
##
## 21 sons pour 53 sorts, et des sorts de glace sur un gresillement electrique :
## le chantier A4 (vague 10) a donne a chaque sort un son de la famille de son
## ELEMENT, partage par deux sorts au plus.
##
## DETTE SOLDEE (chantier B1a) : la table d A4 vivait ici faute de pouvoir
## ecrire tools/make_content.gd pendant la phase A. Elle a ete recopiee dans les
## `sfx_key` des cartes, sa vraie place, puis VIDEE : le son d un sort ne vit
## plus qu a un endroit. La constante reste comme porte de secours (une entree
## y PRIMERAIT sur `SpellCard.sfx_key`) ; test_audio_w10 verifie toujours la
## regle sur la cle effective, et qu une entree eventuelle nomme une carte.
const CARD_SFX: Dictionary = {}

## Element(s) qu evoque chaque son de SORT. Une liste vide = son NEUTRE (un
## frottement, une dechirure) qui ne contredit aucun element. C est ce que
## test_audio_w10 confronte a l element de chaque carte : plus jamais une Prison
## de givre qui gresille comme la foudre.
const SFX_ELEMENTS: Dictionary = {
	"blast_short": [1], "blast_pop": [1], "blast_long": [1], "fire_ignite": [1],
	"fire_forge": [1], "fire_swoosh": [1],
	"drip_frost": [2, 8], "ice_chime": [2], "ice_crack": [2], "ice_wall": [2],
	"spell_arcane": [3, 7], "charge_magic": [3], "curse_mark": [3, 6],
	"spell_crackle": [3, 7], "spell_deep": [3, 8], "spell_grand": [3],
	"time_rift": [3], "spell_rise": [3], "time_haste": [3], "time_slow": [3],
	"ward_deep": [3, 6], "ward_light": [3], "void_pull": [3],
	"poison_dart": [6], "poison_bubble": [6],
	"zap_spark": [7], "zap_short": [7], "zap_long": [7, 3],
	"water_splash": [8], "water_drop": [8], "water_flow": [8],
	"earth_dig": [9], "bramble_rustle": [9], "stone_heavy": [9], "stone_shove": [9],
	"wood_creak": [9], "wood_break": [9], "wood_knock": [9],
	"wind_arrow": [10], "air_burst": [10], "wind_gust": [10], "wind_swirl": [10],
	"arrow_laser": [10],
	"whoosh_summon": [], "whoosh_deep": [], "impact_heavy": [], "bone_rattle": [],
	"card_tear": [], "altar_hum": [],
}


static func card_sfx_key(card: SpellCard) -> StringName:
	if card == null:
		return &""
	return CARD_SFX.get(String(card.id), card.sfx_key)


func play_card(card: SpellCard) -> void:
	play_sfx(card_sfx_key(card))


# --- MUSIQUES -------------------------------------------------------------------
##
## Une musique de combat PAR ACTE (LevelDef.act), au lieu d une seule pour les 21
## niveaux. L acte I garde le theme historique : c est celui que le joueur
## connait depuis le tutoriel.
const ACT_MUSIC: Dictionary = {
	1: &"battle", 2: &"battle_act2", 3: &"battle_act3", 4: &"battle_act4", 5: &"battle_act5",
}
## Les boss qui ont leur propre musique : la fin du voyage ne se joue pas sur le
## theme de n importe quel boss.
const FINAL_BOSSES: Array[StringName] = [&"child_god"]


static func battle_music_for(level: LevelDef, mode: int) -> StringName:
	if mode == GameEnums.Mode.MASSACRE:
		return &"massacre"
	if level == null:
		return &"battle"
	return ACT_MUSIC.get(level.act, &"battle")


static func boss_music_for(wave: WaveDef) -> StringName:
	if wave != null:
		for d in wave.enemy_defs():
			if d != null and d.id in FINAL_BOSSES:
				return &"boss_final"
	return &"boss"


## Duree du fondu entre deux musiques : un changement sec de theme, a l entree
## d un boss, sonnait comme une coupure.
const MUSIC_FADE: float = 0.45


func play_music(key: StringName, loop: bool = true) -> void:
	if _muted or _music == null:
		return
	if _current_music == key and _music.playing:
		return
	var s: AudioStream = _stream(MUSIC_DIR, key, ".ogg")
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_current_music = key
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()
	if not _music.playing:
		_start_music(s, key)
		return
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", -40.0, MUSIC_FADE)
	_music_fade.tween_callback(_start_music.bind(s, key))


func _start_music(s: AudioStream, key: StringName) -> void:
	_music_gain_db = music_gain_db(key)
	_music.stream = s
	_music.volume_db = _music_volume_db()
	_music.play()


func stop_music() -> void:
	_current_music = &""
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()
	if _music != null:
		_music.stop()


# --- VOIX -----------------------------------------------------------------------

## Repliques qui COUPENT la precedente et ignorent le repit : la fin d une partie
## ne doit pas rester muette parce que le mage venait de dire « aie ».
const PRIORITY_VOICES: Array[StringName] = [&"death", &"victory"]
## Repit propre aux repliques de LANCEMENT : un sort toutes les 1,5 s a haute
## vitesse, une replique au plus toutes les 9 s, et une chance sur deux encore.
## Le mage commente ses grands gestes, il ne les annonce pas tous.
const CAST_VOICE_COOLDOWN: float = 9.0
const CAST_VOICE_CHANCE: float = 0.5
## La vitesse au maximum fait dire « hate ! » au mage : au plus toutes les 20 s,
## une jauge qui oscille autour du plafond ne doit pas le faire radoter.
const HASTE_VOICE_COOLDOWN: float = 20.0
var _cast_voice_libre_a: float = 0.0
var _haste_voice_libre_a: float = 0.0
var _speed_up_libre_a: float = 0.0


static func voice_allowed(now: float, free_at: float, playing: bool, priority: bool) -> bool:
	if priority:
		return true
	return not playing and now >= free_at


## La replique qui convient a un sort, d apres ce qu il FAIT puis son element.
## Ordre : invoquer, proteger, se hater, puis l element (feu, givre, foudre),
## puis l arcane qui frappe, puis toute autre attaque ; enfin l incantation
## generique pour les sorts qui ne frappent rien (pioche, cout, focalisation).
static func cast_voice_moment(card: SpellCard) -> StringName:
	if card == null:
		return &""
	var cles: Array[StringName] = []
	for spec in card.effects:
		if spec != null:
			cles.append(spec.key)
	if GameEnums.DamageTag.SUMMON in card.tags or &"summon_ally" in cles:
		return &"summon"
	if &"build_wall" in cles or &"taunt_prop" in cles or &"dispel_zone" in cles:
		return &"shield"
	if &"self_haste" in cles or &"gain_speed" in cles:
		return &"haste"
	var frappe: bool = false
	for k in cles:
		if k in DAMAGE_EFFECTS:
			frappe = true
	match card.element:
		GameEnums.DamageTag.FIRE:
			return &"fire"
		GameEnums.DamageTag.ICE:
			return &"frost"
		GameEnums.DamageTag.LIGHTNING:
			return &"lightning"
		GameEnums.DamageTag.ARCANE:
			return &"spell" if frappe else &"cast"
	return &"attack" if frappe else &"cast"


## Effets qui FRAPPENT (une replique d attaque leur va) ; les autres preparent.
const DAMAGE_EFFECTS: Array[StringName] = [&"damage_single", &"pierce_line", &"ground_zone",
	&"damage_per_enemy", &"meteor_storm", &"vortex_pull", &"knockback", &"stun_zone",
	&"poison_dot", &"water_flood", &"place_terrain", &"terrain_river"]


## Replique de lancement (MageView l appelle au debut de l incantation).
func play_cast_voice(card: SpellCard) -> void:
	if _muted:
		return
	var maintenant: float = _now()
	if maintenant < _cast_voice_libre_a:
		return
	if _rng.randf() >= CAST_VOICE_CHANCE:
		return
	var moment: StringName = cast_voice_moment(card)
	if moment == &"":
		return
	_cast_voice_libre_a = maintenant + CAST_VOICE_COOLDOWN
	play_voice(moment)


## Une REPLIQUE du mage, tiree au hasard parmi les variantes du moment.
##
## `moment` est un moment de JEU (cast, hurt, death, victory...), pas un nom de
## fichier du pack : voir tools/assets/extract_voice.py, qui fait la traduction
## une fois pour toutes a l extraction.
##
## Silencieux quand la voix precedente n est pas finie ou que le repit n est pas
## ecoule — une voix qui se coupe elle-meme est pire que pas de voix. Sauf pour
## PRIORITY_VOICES, qui coupent.
func play_voice(moment: StringName) -> void:
	if _muted or _voice == null:
		return
	var maintenant: float = _now()
	if not voice_allowed(maintenant, _voice_libre_a, _voice.playing, moment in PRIORITY_VOICES):
		return
	# Les variantes sont numerotees a partir de 1 ; on tire jusqu a en trouver
	# une, ce qui evite de coder en dur combien il y en a par moment.
	var dispo: Array[AudioStream] = []
	for i in range(1, 6):
		var s: AudioStream = _stream(VOICE_DIR,
			StringName("voice_%s_%d" % [moment, i]), ".wav")
		if s != null:
			dispo.append(s)
	if dispo.is_empty():
		return
	_voice.stream = dispo[_rng.randi() % dispo.size()]
	# Un peu en retrait des bruitages : la voix commente l action, elle ne la
	# remplace pas.
	_voice.volume_db = linear_to_db(clampf(
		float(SaveData.get_setting("sfx_volume", 1.0)) * 0.75, 0.0001, 1.0))
	_voice.play()
	_voice_libre_a = maintenant + VOICE_COOLDOWN


## Franchir une centaine de vitesse VERS LE HAUT (200, 300, 400, 500 %) : le
## bruitage `speed_up`, extrait des le debut et jamais joue jusqu ici.
static func crosses_speed_step(old_percent: int, new_percent: int) -> bool:
	return new_percent > old_percent and int(new_percent / 100.0) > int(old_percent / 100.0)


func _on_speed_changed(old_percent: int, new_percent: int) -> void:
	var maintenant: float = _now()
	if crosses_speed_step(old_percent, new_percent) and maintenant >= _speed_up_libre_a:
		_speed_up_libre_a = maintenant + 2.0
		play_sfx(&"speed_up")
	if new_percent >= GameConfig.SPEED_MAX_PERCENT and old_percent < GameConfig.SPEED_MAX_PERCENT \
			and maintenant >= _haste_voice_libre_a:
		_haste_voice_libre_a = maintenant + HASTE_VOICE_COOLDOWN
		play_voice(&"haste")


## Plus de vie : la jauge se vide lentement vers la defaite. Le mage s epuise
## (« tired » du pack, extrait sous `defeat` et jamais joue jusqu ici).
func _on_death_started() -> void:
	play_voice(&"defeat")


## Cles connues, pour l AUDIT : chaque cle doit avoir son fichier.
static func sfx_keys() -> Array[StringName]:
	return [&"cast_start", &"cast_done", &"cast_zone", &"hit", &"enemy_die", &"shield_break",
		&"hp_lost", &"wall", &"wave_start", &"boss", &"victory", &"defeat", &"ui_tap",
		&"card_pick", &"card_draw", &"speed_up", &"level_up", &"arrow", &"explosion", &"grow", &"heal",
		# Sons PROPRES aux sorts (SpellCard.sfx_key), extraits par
		# tools/assets/extract_fxpack.py : un son par famille de sorts, partage
		# entre 2 ou 3 cartes au plus. Retour du testeur : tous les sorts
		# faisaient le meme "cast_done".
		&"spell_arcane", &"spell_deep", &"spell_rise", &"spell_grand", &"spell_crackle",
		&"ward_light", &"ward_deep", &"charge_magic", &"zap_short", &"zap_long",
		&"blast_short", &"blast_pop", &"blast_long", &"impact_heavy", &"arrow_laser",
		&"drip_frost", &"wind_gust", &"fire_ignite", &"whoosh_summon", &"whoosh_deep",
		&"stone_shove",
		# VAGUE 10 (tools/assets/extract_w10_audio.py) : familles de monstres...
		&"hit_slime", &"die_slime", &"hit_bone", &"die_bone", &"hit_stone", &"die_stone",
		&"hit_metal", &"die_metal", &"die_beast", &"die_bird", &"die_insect",
		&"die_human", &"die_human_2", &"die_human_3", &"die_arcane", &"die_demon",
		&"hit_ghost", &"die_ghost", &"hit_wood", &"die_plant", &"hit_glass", &"die_glass",
		# ... mecaniques de monstres ...
		&"seal_tick", &"armor_break", &"revive", &"summon_call", &"time_rewind",
		&"twin_fall", &"chameleon_shift", &"card_steal", &"devour", &"aura_break",
		&"quake", &"laser_beam", &"spell_shot", &"throw", &"magic_silence", &"reanimate",
		# ... objets de terrain ...
		&"wood_creak", &"wood_break", &"wall_break", &"earth_dig", &"bramble_rustle",
		&"altar_hum",
		# ... et sorts.
		&"fire_forge", &"fire_swoosh", &"ice_chime", &"ice_crack", &"ice_wall",
		&"curse_mark", &"time_rift", &"time_haste", &"time_slow", &"void_pull",
		&"poison_dart", &"poison_bubble", &"bone_rattle", &"card_tear", &"zap_spark",
		&"water_splash", &"water_drop", &"water_flow", &"stone_heavy", &"wind_arrow",
		&"air_burst", &"wind_swirl", &"wood_knock"]


static func music_keys() -> Array[StringName]:
	return [&"menu", &"battle", &"boss", &"victory", &"defeat",
		&"battle_act2", &"battle_act3", &"battle_act4", &"battle_act5", &"boss_final",
		&"massacre"]


## Gains de lecture (dB), MESURES sur les fichiers : ils ramenent chaque son au
## niveau de sa categorie (coups et morts plus bas que les sorts, on en entend
## dix par seconde). Les fichiers allaient de -5,6 a -23,5 dB de niveau moyen.
## Ne pas editer a la main : relancer le script.
## --- GAINS : genere par tools/assets/extract_w10_audio.py ---
const SFX_GAIN_DB: Dictionary = {
	"air_burst": -4.2,
	"altar_hum": -12.3,
	"armor_break": 0.1,
	"arrow": -2.6,
	"arrow_laser": -2.4,
	"aura_break": -10.3,
	"blast_long": -3.5,
	"blast_pop": -4.2,
	"blast_short": -0.7,
	"bone_rattle": 0.5,
	"boss": 2.3,
	"bramble_rustle": -2.6,
	"card_draw": -7.1,
	"card_pick": -6.8,
	"card_steal": 0.5,
	"card_tear": 0.5,
	"cast_done": -6.0,
	"cast_start": -3.6,
	"cast_zone": -3.7,
	"chameleon_shift": -6.5,
	"charge_magic": -2.6,
	"curse_mark": -10.2,
	"defeat": 5.6,
	"devour": 0.5,
	"die_arcane": -13.2,
	"die_beast": -14.0,
	"die_bird": -7.2,
	"die_bone": -3.6,
	"die_demon": -12.4,
	"die_ghost": -10.7,
	"die_glass": -7.6,
	"die_human": -12.1,
	"die_human_2": -10.4,
	"die_human_3": -11.3,
	"die_insect": -2.9,
	"die_metal": -12.1,
	"die_plant": -6.3,
	"die_slime": -4.6,
	"die_stone": -9.4,
	"drip_frost": -2.0,
	"earth_dig": 0.5,
	"enemy_die": -1.9,
	"explosion": -1.2,
	"fire_forge": -4.2,
	"fire_ignite": -0.4,
	"fire_swoosh": -5.0,
	"grow": -4.7,
	"heal": -2.6,
	"hit": -13.2,
	"hit_bone": -9.3,
	"hit_ghost": -8.2,
	"hit_glass": -5.5,
	"hit_metal": -13.6,
	"hit_slime": -3.5,
	"hit_stone": -13.2,
	"hit_wood": -10.6,
	"hp_lost": -4.2,
	"ice_chime": 0.5,
	"ice_crack": -1.0,
	"ice_wall": -0.6,
	"impact_heavy": -4.7,
	"laser_beam": -7.2,
	"level_up": 5.8,
	"magic_silence": -5.1,
	"poison_bubble": 0.5,
	"poison_dart": -4.4,
	"quake": -9.7,
	"reanimate": -7.7,
	"revive": -4.8,
	"seal_tick": 0.5,
	"shield_break": -5.0,
	"speed_up": -4.3,
	"spell_arcane": -5.0,
	"spell_crackle": -7.0,
	"spell_deep": -6.2,
	"spell_grand": -11.0,
	"spell_rise": -2.7,
	"spell_shot": -7.8,
	"stone_heavy": -2.5,
	"stone_shove": -0.2,
	"summon_call": -3.4,
	"throw": -14.0,
	"time_haste": -1.5,
	"time_rewind": 0.5,
	"time_rift": -6.3,
	"time_slow": -2.4,
	"twin_fall": -6.7,
	"ui_tap": -7.6,
	"victory": 6.5,
	"void_pull": -5.1,
	"wall": -2.1,
	"wall_break": -2.9,
	"ward_deep": -4.0,
	"ward_light": -1.6,
	"water_drop": -0.4,
	"water_flow": -8.3,
	"water_splash": 0.5,
	"wave_start": -3.9,
	"whoosh_deep": -1.6,
	"whoosh_summon": -7.2,
	"wind_arrow": -3.4,
	"wind_gust": 0.3,
	"wind_swirl": -0.1,
	"wood_break": 0.5,
	"wood_creak": -0.6,
	"wood_knock": -0.2,
	"zap_long": -12.4,
	"zap_short": -0.5,
	"zap_spark": 0.5,
}
const MUSIC_GAIN_DB: Dictionary = {
	"battle": -0.7,
	"battle_act2": 0.3,
	"battle_act3": -0.4,
	"battle_act4": -1.0,
	"battle_act5": -5.8,
	"boss": -0.2,
	"boss_final": -4.5,
	"defeat": 3.0,
	"massacre": 0.8,
	"menu": -4.3,
	"victory": -1.7,
}
## --- fin des gains ---

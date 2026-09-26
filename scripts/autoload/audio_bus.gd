extends Node
## Audio : effets (400 Sounds Pack, FreeSFX), musiques (16-bit RPG Music,
## xDeviruchi) et VOIX DU MAGE (Mage Voice Pack), charges depuis assets/.
## Inerte en headless.

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const VOICE_DIR := "res://assets/voice/"
const POOL_SIZE: int = 10

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
var _streams: Dictionary = {}


func _ready() -> void:
	_muted = DisplayServer.get_name() == "headless"
	if _muted:
		return
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


func _stream(dir: String, key: StringName, ext: String) -> AudioStream:
	var path: String = dir + String(key) + ext
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_streams[path] = s
	return s


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
		var mv: float = clampf(float(SaveData.get_setting("music_volume", 0.6)), 0.0, 1.0)
		_music.volume_db = linear_to_db(maxf(mv, 0.0001))


func play_sfx(key: StringName) -> void:
	if _muted or _pool.is_empty():
		return
	var s: AudioStream = _stream(SFX_DIR, key, ".wav")
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = linear_to_db(clampf(float(SaveData.get_setting("sfx_volume", 1.0)), 0.0001, 1.0))
	p.play()


## Une REPLIQUE du mage, tiree au hasard parmi les variantes du moment.
##
## `moment` est un moment de JEU (cast, hurt, death, victory...), pas un nom de
## fichier du pack : voir tools/assets/extract_voice.py, qui fait la traduction
## une fois pour toutes a l extraction.
##
## Silencieux quand la voix precedente n est pas finie ou que le repit n est pas
## ecoule — une voix qui se coupe elle-meme est pire que pas de voix.
func play_voice(moment: StringName) -> void:
	if _muted or _voice == null:
		return
	if _voice.playing:
		return
	var maintenant: float = float(Time.get_ticks_msec()) * 0.001
	if maintenant < _voice_libre_a:
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
	_voice.stream = dispo[randi() % dispo.size()]
	# Un peu en retrait des bruitages : la voix commente l action, elle ne la
	# remplace pas.
	_voice.volume_db = linear_to_db(clampf(
		float(SaveData.get_setting("sfx_volume", 1.0)) * 0.75, 0.0001, 1.0))
	_voice.play()
	_voice_libre_a = maintenant + VOICE_COOLDOWN


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
	_music.stream = s
	_music.play()


func stop_music() -> void:
	_current_music = &""
	if _music != null:
		_music.stop()


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
		&"stone_shove"]


static func music_keys() -> Array[StringName]:
	return [&"menu", &"battle", &"boss", &"victory", &"defeat"]

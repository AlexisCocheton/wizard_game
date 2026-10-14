extends TestCase
## VAGUE 10, REVUE GLOBALE (chantier A4) : le son et le retour visuel des
## monstres rattrapent le reste du jeu.
##
## Tout est verifie par les fonctions STATIQUES de AudioBus et de Fx : en headless
## le serveur audio est muet et aucun sprite n est dessine, mais les CHOIX (quel
## son, quelle musique, quelle replique, quelle mort) sont des donnees, et ce
## sont elles qui se trompent. Les vitrines de l etage `visual` montrent le rendu.

## Un meme son de sort pour plus de deux cartes : c est le defaut que la revue a
## releve (21 sons pour 53 sorts). Regle, pas reglage.
const MAX_CARTES_PAR_SON: int = 2


func get_suite_name() -> String:
	return "audio_w10"


func run() -> void:
	_test_chaque_monstre_a_une_famille_sonore()
	_test_les_familles_ne_meurent_pas_du_meme_son()
	_test_objets_de_terrain()
	_test_sons_des_sorts()
	_test_musique_par_acte()
	_test_voix_branchees()
	_test_cadence_et_repit()
	_test_gains_couvrent_tout()
	_test_plan_de_mort()
	_test_retour_de_coup()


## Un son doit EXISTER et se CHARGER : `ResourceLoader.exists` repond oui sur la
## foi du seul .import quand le fichier a disparu (assets.md).
func _fichier(path: String, quoi: String) -> void:
	ok(FileAccess.file_exists(path), "%s : %s present sur le disque" % [quoi, path])
	ok(load(path) != null, "%s : %s se charge" % [quoi, path])


func _son(key: StringName, quoi: String) -> void:
	ok(key in AudioBus.sfx_keys(), "%s : '%s' est dans AudioBus.sfx_keys()" % [quoi, key])
	_fichier(AudioBus.SFX_DIR + String(key) + ".wav", quoi)


func _test_chaque_monstre_a_une_famille_sonore() -> void:
	ok(not ContentDB.enemies.is_empty(), "le bestiaire est charge")
	for id in ContentDB.enemies:
		var d: EnemyDef = ContentDB.enemies[id]
		# `flesh` est le REPLI : un monstre qui y tombe a une feuille que personne
		# n a classee, et il meurt du vieux son generique.
		var fam: String = AudioBus.enemy_family(d)
		ok(fam != "flesh", "%s (feuille %s) a une famille sonore" % [id, d.anim_key])
		_son(AudioBus.enemy_hit_key(d), "coup de %s" % id)
		_son(AudioBus.enemy_death_key(d), "mort de %s" % id)
		_son(AudioBus.shot_sfx_key(d), "tir de %s" % id)
	# Les exceptions par monstre visent des monstres qui existent.
	for id in AudioBus.ENEMY_FAMILY:
		ok(ContentDB.enemies.has(StringName(id)), "ENEMY_FAMILY : %s existe" % id)
		ok(AudioBus.FAMILY_SFX.has(AudioBus.ENEMY_FAMILY[id]), "famille %s connue" % id)
	for sheet in AudioBus.SHEET_FAMILY:
		ok(AudioBus.FAMILY_SFX.has(AudioBus.SHEET_FAMILY[sheet]), "famille de %s connue" % sheet)


func _test_les_familles_ne_meurent_pas_du_meme_son() -> void:
	var vus: Dictionary = {}
	for fam in AudioBus.FAMILY_SFX:
		var mort: StringName = AudioBus.FAMILY_SFX[fam][1]
		ok(not vus.has(mort), "la mort '%s' n est pas partagee (%s et %s)"
			% [mort, fam, vus.get(mort, "")])
		vus[mort] = fam
	# Une gelee et un golem ne meurent plus du meme bruit (le defaut d origine).
	var gelee: EnemyDef = null
	var golem: EnemyDef = null
	for id in ContentDB.enemies:
		var d: EnemyDef = ContentDB.enemies[id]
		if AudioBus.enemy_family(d) == "slime" and gelee == null:
			gelee = d
		if AudioBus.enemy_family(d) == "stone" and golem == null:
			golem = d
	ok(gelee != null and golem != null, "le bestiaire a une gelee et un golem")
	if gelee != null and golem != null:
		ok(AudioBus.enemy_death_key(gelee) != AudioBus.enemy_death_key(golem),
			"une gelee et un golem meurent de sons differents")


func _test_objets_de_terrain() -> void:
	var poses: Dictionary = {}
	for kind in TerrainProp.Kind.values():
		var pose: StringName = AudioBus.prop_sfx_key(kind, false)
		var bris: StringName = AudioBus.prop_sfx_key(kind, true)
		_son(pose, "pose de l objet %d" % kind)
		_son(bris, "bris de l objet %d" % kind)
		ok(pose != &"wall", "l objet %d ne sonne plus `wall`" % kind)
		ok(not poses.has(pose), "l objet %d a un son de pose a lui" % kind)
		poses[pose] = kind
	var glace: Array = [GameEnums.DamageTag.ICE]
	var nature: Array = [GameEnums.DamageTag.NATURE]
	ok(AudioBus.wall_sfx_key(glace, false) != AudioBus.wall_sfx_key(nature, false),
		"un mur de glace ne sonne pas comme un mur d ecorce")
	ok(AudioBus.wall_sfx_key(nature, false) != AudioBus.wall_sfx_key(nature, true),
		"un mur qui tombe ne sonne pas comme un mur qu on pose")
	for tags in [glace, nature, []]:
		_son(AudioBus.wall_sfx_key(tags, false), "pose de mur")
		_son(AudioBus.wall_sfx_key(tags, true), "bris de mur")


func _test_sons_des_sorts() -> void:
	var par_son: Dictionary = {}
	var cartes: int = 0
	for id in ContentDB.cards:
		var c: SpellCard = ContentDB.cards[id]
		if c.is_passive:
			continue
		cartes += 1
		var k: StringName = AudioBus.card_sfx_key(c)
		_son(k, "sort %s" % id)
		ok(AudioBus.SFX_ELEMENTS.has(String(k)), "le son '%s' de %s declare son element" % [k, id])
		var permis: Array = AudioBus.SFX_ELEMENTS.get(String(k), [])
		ok(permis.is_empty() or int(c.element) in permis,
			"%s (element %d) ne sonne pas comme un autre element ('%s' : %s)"
			% [id, c.element, k, permis])
		var liste: Array = par_son.get(k, [])
		liste.append(id)
		par_son[k] = liste
	ok(cartes > 0, "des sorts sont charges")
	for k in par_son:
		ok((par_son[k] as Array).size() <= MAX_CARTES_PAR_SON,
			"le son '%s' sert a %d sorts au plus : %s" % [k, MAX_CARTES_PAR_SON, par_son[k]])
	for id in AudioBus.CARD_SFX:
		ok(ContentDB.cards.has(StringName(id)), "CARD_SFX : la carte %s existe" % id)


func _test_musique_par_acte() -> void:
	var actes: Dictionary = {}
	for id in ContentDB.levels:
		var l: LevelDef = ContentDB.levels[id]
		var m: StringName = AudioBus.battle_music_for(l, GameEnums.Mode.EXPLORATION)
		if actes.has(l.act):
			eq(actes[l.act], m, "tous les niveaux de l acte %d ont la meme musique" % l.act)
		actes[l.act] = m
	ok(actes.size() > 1, "la campagne compte plusieurs actes")
	var musiques: Dictionary = {}
	for a in actes:
		ok(not musiques.has(actes[a]), "l acte %d a SA musique (%s)" % [a, actes[a]])
		musiques[actes[a]] = a
	var massacre: StringName = AudioBus.battle_music_for(null, GameEnums.Mode.MASSACRE)
	ok(not musiques.has(massacre), "le Massacre a sa propre musique")
	musiques[massacre] = -1
	for w in WaveBudget.WORLDS:
		musiques[AudioBus.world_music(String(w["backdrop"]))] = -2
	# Le boss final n a pas le theme de n importe quel boss.
	var vague_finale: WaveDef = null
	var autre_boss: WaveDef = null
	for id in ContentDB.levels:
		for w: WaveDef in (ContentDB.levels[id] as LevelDef).waves:
			if w == null or not w.is_boss:
				continue
			var finale: bool = false
			for d in w.enemy_defs():
				if d != null and d.id in AudioBus.FINAL_BOSSES:
					finale = true
			if finale and vague_finale == null:
				vague_finale = w
			elif not finale and autre_boss == null:
				autre_boss = w
	ok(vague_finale != null, "une vague de boss porte le boss final")
	if vague_finale != null and autre_boss != null:
		ok(AudioBus.boss_music_for(vague_finale) != AudioBus.boss_music_for(autre_boss),
			"le boss final a son theme")
		musiques[AudioBus.boss_music_for(vague_finale)] = -3
		musiques[AudioBus.boss_music_for(autre_boss)] = -4
	for m in musiques:
		ok(m in AudioBus.music_keys(), "'%s' est dans AudioBus.music_keys()" % m)
		_fichier(AudioBus.MUSIC_DIR + String(m) + ".ogg", "musique")


func _voix(moment: StringName) -> void:
	_fichier(AudioBus.VOICE_DIR + "voice_%s_1.wav" % moment, "replique %s" % moment)


func _test_voix_branchees() -> void:
	# Chaque sort trouve une replique qui existe.
	var vus: Dictionary = {}
	for id in ContentDB.cards:
		var c: SpellCard = ContentDB.cards[id]
		if c.is_passive:
			continue
		var m: StringName = AudioBus.cast_voice_moment(c)
		ok(m != &"", "%s a une replique de lancement" % id)
		vus[m] = true
	for m in vus:
		_voix(m)
	# Les repliques par ELEMENT sont bien atteintes : un sort de feu qui frappe
	# fait dire « feu », de glace « givre », de foudre « foudre ».
	var attendu: Dictionary = {
		GameEnums.DamageTag.FIRE: &"fire",
		GameEnums.DamageTag.ICE: &"frost",
		GameEnums.DamageTag.LIGHTNING: &"lightning",
	}
	for el in attendu:
		var trouve: bool = false
		for id in ContentDB.cards:
			var c: SpellCard = ContentDB.cards[id]
			if not c.is_passive and c.element == el and AudioBus.cast_voice_moment(c) == attendu[el]:
				trouve = true
		ok(trouve, "un sort d element %d fait dire '%s'" % [el, attendu[el]])
	for m in [&"summon", &"shield", &"haste"]:
		ok(vus.has(m), "un sort au moins fait dire '%s'" % m)
	# Les moments branches hors des sorts (debut de niveau, epuisement, vitesse
	# au plafond) et les repliques prioritaires.
	for m in [&"level_start", &"defeat", &"haste"]:
		_voix(m)
	for m in AudioBus.PRIORITY_VOICES:
		_voix(m)


func _test_cadence_et_repit() -> void:
	var dt: float = AudioBus.SFX_MIN_INTERVAL
	ok(AudioBus.may_play(10.0, -1.0, 0), "un son jamais joue passe")
	not_ok(AudioBus.may_play(10.0, 10.0 - dt * 0.5, 0), "le meme son, trop tot, ne double pas")
	ok(AudioBus.may_play(10.0, 10.0 - dt * 1.5, 0), "le meme son, plus tard, repasse")
	not_ok(AudioBus.may_play(10.0, -1.0, AudioBus.SFX_MAX_SAME),
		"au plafond d exemplaires simultanes, il ne passe pas")
	ok(AudioBus.voice_allowed(5.0, 4.0, false, false), "voix libre apres le repit")
	not_ok(AudioBus.voice_allowed(5.0, 6.0, false, false), "voix refusee pendant le repit")
	not_ok(AudioBus.voice_allowed(5.0, 4.0, true, false), "une voix n en couvre pas une autre")
	ok(AudioBus.voice_allowed(5.0, 6.0, true, true), "une voix prioritaire passe toujours")
	# speed_up au passage de chaque centaine, vers le haut seulement.
	ok(AudioBus.crosses_speed_step(199, 200), "199 -> 200 franchit un palier")
	ok(AudioBus.crosses_speed_step(150, 310), "un saut de deux paliers en franchit un")
	not_ok(AudioBus.crosses_speed_step(200, 250), "200 -> 250 ne franchit rien")
	not_ok(AudioBus.crosses_speed_step(310, 290), "redescendre ne sonne pas")


func _test_gains_couvrent_tout() -> void:
	for k in AudioBus.sfx_keys():
		ok(AudioBus.SFX_GAIN_DB.has(String(k)), "le son '%s' a un gain mesure" % k)
	for k in AudioBus.music_keys():
		ok(AudioBus.MUSIC_GAIN_DB.has(String(k)), "la musique '%s' a un gain mesure" % k)
	# Les sons FREQUENTS sont plus bas que le son d un sort : a gain egal, dix
	# coups par seconde couvraient tout le reste.
	ok(AudioBus.is_frequent(&"hit") and AudioBus.is_frequent(&"die_slime"),
		"coups et morts sont classes frequents")
	not_ok(AudioBus.is_frequent(&"blast_long"), "un sort n est pas un son frequent")


func _test_plan_de_mort() -> void:
	var r: float = 40.0
	var anime: Dictionary = Fx.death_plan(true, r, false)
	eq(anime["corpse"], "anim", "une feuille a pose de mort la JOUE")
	not_ok(String(anime["sheet"]).begins_with("explosion") or anime["sheet"] == "boom_hd",
		"un monstre ordinaire qui joue sa mort n explose plus")
	var boss: Dictionary = Fx.death_plan(true, r, true)
	eq(boss["corpse"], "anim", "un boss joue aussi sa mort")
	ok(bool(boss["after_anim"]), "un boss explose APRES sa pose de mort")
	eq(boss["sheet"], Fx.explosion_sheet(r), "avec l explosion de sa taille")
	var nu: Dictionary = Fx.death_plan(false, r, false)
	eq(nu["corpse"], "collapse", "sans pose de mort, l image s affaisse")
	eq(nu["sheet"], Fx.explosion_sheet(r), "et l explosion historique reste")
	ok(Fx.has_sheet(String(anime["sheet"])), "la bouffee de mort est une feuille connue")
	# Paliers d explosion croissants (le gros monstre a la plus grosse feuille).
	ok(Fx.cell_size(Fx.explosion_sheet(r * 4.0)) >= Fx.cell_size(Fx.explosion_sheet(r * 0.5))
		or Fx.explosion_sheet(r * 4.0) == "boom_hd", "un gros monstre a la grosse explosion")
	# Le catalogue a bien des poses de mort, et des monstres en portent.
	var avec: int = 0
	for id in ContentDB.enemies:
		var d: EnemyDef = ContentDB.enemies[id]
		if AnimCatalog.has_anim(d.anim_key, "death"):
			avec += 1
	ok(avec > 0, "des monstres livres ont une pose de mort a jouer")


func _test_retour_de_coup() -> void:
	# squash : ecrase au coup, EXACTEMENT au repos a la fin (pas de derive).
	var debut: Vector2 = Fx.squash_factor(0.0)
	ok(debut.x > 1.0 and debut.y < 1.0, "au coup, le corps est plus large et plus bas")
	eq(Fx.squash_factor(1.0), Vector2.ONE, "a la fin, l echelle revient exactement")
	# Qui a besoin du retour generique : une feuille SANS douleur.
	var avec_douleur := SpriteFrames.new()
	avec_douleur.add_animation(&"hurt")
	var sans := SpriteFrames.new()
	var a := AnimatedSprite2D.new()
	a.sprite_frames = avec_douleur
	not_ok(Fx.needs_generic_hurt(a), "une feuille qui a `hurt` joue sa propre douleur")
	a.sprite_frames = sans
	ok(Fx.needs_generic_hurt(a), "une feuille sans `hurt` recoit le recul generique")
	var s := Sprite2D.new()
	ok(Fx.needs_generic_hurt(s), "une image fixe recoit le recul generique")
	not_ok(Fx.has_death_anim(a), "sans `death`, pas de pose de mort")
	sans.add_animation(&"death")
	ok(Fx.has_death_anim(a), "avec `death`, la pose de mort est jouee")
	a.free()
	s.free()
	# Le compte du catalogue : combien de monstres n avaient que le flash.
	var generiques: int = 0
	for id in ContentDB.enemies:
		var d: EnemyDef = ContentDB.enemies[id]
		if not AnimCatalog.has_anim(Enemy.shown_sheet(d), "hurt"):
			generiques += 1
	ok(generiques > 0, "des monstres livres n ont pas de pose de douleur (recul generique)")

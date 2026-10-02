extends Node
## ETAGE SMOKE — joue un niveau complet en headless avec un delta fixe.
##
## Verifie sur 4.4.stable : une SCRIPT ERROR runtime ne change pas le code de
## sortie. Le marqueur SMOKE_OK distingue donc "partie jouee jusqu au bout" de
## "mort silencieuse a la frame 3", et run_tests.sh parse stderr en plus.

const FIXED_DELTA: float = 1.0 / 60.0
const MAX_STEPS: int = 60 * 60 * 12   # 12 minutes simulees au maximum

var _game: GameController = null
var _won: bool = false
var _lost: bool = false
## get_tree().quit(code) ne stoppe pas l execution immediatement : le reste de la
## fonction continue et un quit(0) ulterieur ECRASE le code d erreur. On memorise
## donc l echec et on sort une seule fois, a la fin.
var _failed: bool = false


## Vrai quand le smoke tourne en fenetre reelle (etage `visual`) : le code de
## sprites s execute et des captures d ecran sont ecrites dans .testout/.
var _visual: bool = false
var _shot_index: int = 0


func _ready() -> void:
	# Jamais d ecriture dans le vrai profil, meme en fenetre reelle.
	SaveData.persistence_enabled = false
	_visual = DisplayServer.get_name() != "headless"
	await get_tree().process_frame
	await _run_all()
	# UNIQUE point de sortie : un `return` anticipe dans _run_all() ne peut plus
	# laisser le process tourner sans fin (verifie : ca a deja hang une fois).
	_finish()


func _finish() -> void:
	if _failed:
		get_tree().quit(1)
		return
	print("SMOKE_OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	_failed = true
	printerr("[SMOKE] %s" % message)


## Capture d ecran (mode visuel seulement). Attend un rendu complet avant de lire.
func _shot(label: String) -> void:
	if not _visual:
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	_shot_index += 1
	var dir: String = ProjectSettings.globalize_path("res://.testout")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = "%s/shot_%02d_%s.png" % [dir, _shot_index, label]
	img.save_png(path)
	print("[SMOKE] capture : %s" % path.get_file())


## Laisse s ecouler du temps REEL, pour que les AnimatedSprite2D avancent.
## `simulate()` ne les touche pas : ils suivent l horloge du moteur. Sans cette
## attente, toute vitrine capture la premiere image de chaque feuille.
func _laisser_jouer(secondes: float) -> void:
	var t: float = 0.0
	while t < secondes:
		t += await _frame_delta()


func _frame_delta() -> float:
	await get_tree().process_frame
	return get_process_delta_time()


func _run_all() -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		_fail("niveau lvl_01 introuvable")
		return

	# 0) Vitrines visuelles : tous les monstres, puis quelques sorts isoles.
	await _showcase_enemies()
	await _showcase_effects()

	# 1) Chaque carte doit passer dans son handler sans erreur.
	await _exercise_every_card()

	# 2) Partie complete, pilotee a delta fixe.
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	_game = packed.instantiate()
	_game.headless_mode = true
	add_child(_game)
	_game.level_won.connect(func() -> void: _won = true)
	_game.level_lost.connect(func() -> void: _lost = true)
	_game.start_level(level, GameEnums.Mode.EXPLORATION)
	# Seul le smoke fait avancer la partie : sinon _process() la joue en temps reel
	# pendant les frames d attente des captures, et l etat n est plus celui attendu.
	_game.running = false

	var steps: int = 0
	var shot_done: bool = false
	while steps < MAX_STEPS and not _won and not _lost:
		# Le mage tue tout : on veut atteindre la victoire, pas mourir de faiblesse.
		_autoplay()
		_game.simulate(FIXED_DELTA)
		steps += 1
		# Vers la vague 5 : des monstres varies, des zones au sol, une incantation.
		if _visual and not shot_done and RunState.wave_index >= 4 				and _game.battlefield.alive_count() >= 5 and RunState.pending_offer.is_empty():
			shot_done = true
			# Trois passifs a SEUILS ECARTES avant la capture : sans cela la
			# capture ne prouve rien du rail. Il en faut un sous la vitesse
			# courante (allume) et un tres au-dessus (grise), sinon on ne voit
			# jamais que le seuil commande bien l affichage.
			# On VIDE d abord la barre : les passifs deja gagnes en jeu occupaient
			# les trois places et le passif a seuil eleve — celui qui prouve
			# l etat GRISE — ne pouvait plus entrer.
			RunState.equipped_passives.clear()
			for id in [&"pass_celerity", &"pass_fireboom", &"pass_apotheosis"]:
				var pc: SpellCard = ContentDB.cards.get(id)
				if pc != null:
					RunState.equip_passive(pc)
			await _shot("bataille")
			# Le panneau de pause montre les passifs actifs : on le capture avec un
			# passif joue, sinon la capture ne prouve rien.
			if _visual:
				var hud: Node = _game.get_node_or_null("HUD")
				if hud != null and hud.has_method("_show_pause_panel"):
					hud.call("_show_pause_panel")
					await _shot("pause")
					var panel: Node = hud.get("_pause_panel")
					if panel != null:
						panel.queue_free()
						hud.set("_pause_panel", null)
		if _visual and RunState.pending_offer.size() > 0 and _shot_index < 2:
			await _shot("choix")

	print("[SMOKE] %d pas simules, vagues=%d, niveau joueur=%d"
		% [steps, RunState.wave_index, RunState.level])

	if _lost:
		_fail("defaite inattendue en autoplay")
		return
	if not _won:
		_fail("la partie ne s est jamais terminee (limite de pas atteinte)")
		return

	# La partie de test est terminee : on la retire pour que son HUD (et un
	# eventuel choix de sort en attente) ne recouvre pas les ecrans suivants.
	RunState.pending_offer.clear()
	_game.queue_free()
	_game = null
	if _visual:
		await get_tree().process_frame

	# 3) Le mur doit bloquer puis liberer la navigation.
	_check_wall_pathfinding()

	# 4) Le PREMIER LANCEMENT : ce que voit quelqu un qui ouvre le jeu pour la
	#    premiere fois. Il passe AVANT les autres ecrans parce qu il exige un
	#    profil vierge, et que tout ce qui suit en accorde un rempli.
	await _check_premier_lancement()

	# 5) Tous les ecrans du menu et de fin de niveau doivent se construire.
	await _check_menu_screens()
	await _check_briefing()
	await _check_story()
	await _check_boss_reward()
	await _check_precast()
	await _check_upgrade_panel()
	await _check_cartes_petrifiees()
	await _showcase_mecaniques_v3()
	await _check_objectifs_en_combat()
	await _showcase_miroir()
	await _check_end_screens()
	await _check_cosmetics_in_battle()
	await _check_massacre_deck()

	# 4) La defaite doit aussi fonctionner.
	_check_defeat_path()



## Vitrine : un exemplaire de chaque monstre en grille, pour juger sprites et tailles.
##
## PAR PAGES (chantier W2). Une seule planche posait les monstres sur 180 px de
## haut par rangee : a 79 monstres la grille descendait a 4 900 px, et tout ce qui
## passait la dixieme rangee etait dessine HORS de l ecran. La vitrine affirmait
## montrer le bestiaire et n en montrait qu un tiers — dont aucun des monstres
## neufs, que l ordre alphabetique rejetait en bas. Une page = 18 monstres.
const VITRINE_PAR_PAGE: int = 18


func _showcase_enemies() -> void:
	if not _visual:
		return
	var ids: Array = ContentDB.enemies.keys()
	# Tri sur les String : le tri des StringName n est pas fiable en 4.4 (gotcha).
	ids.sort_custom(func(a, b): return String(a) < String(b))
	var page: int = 0
	while page * VITRINE_PAR_PAGE < ids.size():
		var tranche: Array = ids.slice(page * VITRINE_PAR_PAGE, (page + 1) * VITRINE_PAR_PAGE)
		await _vitrine_page(tranche, "vitrine_monstres" if page == 0 else "vitrine_monstres_%d" % (page + 1))
		page += 1
	await _showcase_giants()


func _vitrine_page(ids: Array, label: String) -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("grass")
	var cols: int = 3
	var i: int = 0
	for id in ids:
		var def: EnemyDef = ContentDB.enemies[id]
		var x: float = 200.0 + (i % cols) * 340.0
		var y: float = 260.0 + int(i / cols) * 260.0
		var e: Enemy = g.battlefield.spawn_enemy(def, x, 1.0, Vector2(x, y))
		if e != null:
			e.take_damage(1.0, [])  # fait apparaitre la barre de vie
		# Etiquette sous chaque monstre : indispensable pour verifier le mapping.
		var l := Label.new()
		l.text = "%s (P%d)" % [def.id, def.power]
		l.add_theme_font_size_override(&"font_size", 22)
		l.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
		l.position = Vector2(x - 120.0, y + 50.0)
		l.size = Vector2(240.0, 30.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.battlefield.add_child(l)
		i += 1
	await _shot(label)
	g.queue_free()
	await get_tree().process_frame


## Les deux mises en scene que la grille ne peut pas juger (chantier W2) : le
## Slime colossal a sa taille reelle, pose ou le couloir le plus large le ferait
## naitre, et le trio de mages ensemble. Dans la grille, un sprite de 600 px
## deborde sur ses voisins ; ici on verifie qu il tient ENTIER dans le cadre et
## que les trois mages se lisent comme trois, pas comme une tache.
func _showcase_giants() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("grass")
	var W: float = GameConfig.BATTLEFIELD_WIDTH
	var colosse: EnemyDef = ContentDB.enemies.get(&"slime_colossal")
	if colosse != null:
		# Au bord gauche de ce que la marge d apparition autorise : le pire cas.
		var x: float = WaveSpawner.spawn_margin(colosse)
		g.battlefield.spawn_enemy(colosse, x, 1.0, Vector2(x, 520.0))
	var trio: Array[StringName] = [&"trio_frost", &"trio_ember", &"trio_arcane"]
	for k in trio.size():
		var d: EnemyDef = ContentDB.enemies.get(trio[k])
		if d == null:
			_fail("vitrine geants : %s introuvable" % trio[k])
			continue
		var x: float = W * (0.22 + 0.28 * k)
		g.battlefield.spawn_enemy(d, x, 1.0, Vector2(x, 1180.0))
	await _laisser_jouer(0.3)
	await _shot("vitrine_geants")
	g.queue_free()
	await get_tree().process_frame
	await _showcase_tints()


## Les feuilles PARTAGEES entre deux tetes, cote a cote : a gauche celle qui
## porte la feuille nue, a droite celle que AnimCatalog.MODULATE teinte. Sans
## coup encaisse (la grille en inflige un pour la barre de vie, et l eclair de
## degat blanchit la silhouette) : on juge la teinte, pas le flash.
func _showcase_tints() -> void:
	var paires: Array = [
		[&"gravecaller", &"pit_witch"],
		[&"trio_frost", &"tombol_seal"],
		[&"forge_colossus", &"clockmaker"],
		[&"wraith_lord", &"season_chameleon"],
		[&"dark_mage", &"spell_clerk"],
	]
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("grass")
	for i in paires.size():
		for k in 2:
			var d: EnemyDef = ContentDB.enemies.get(paires[i][k])
			if d == null:
				_fail("vitrine teintes : %s introuvable" % paires[i][k])
				continue
			var x: float = 300.0 + 480.0 * k
			var y: float = 230.0 + 270.0 * i
			g.battlefield.spawn_enemy(d, x, 1.0, Vector2(x, y))
			var l := Label.new()
			l.text = String(d.id)
			l.add_theme_font_size_override(&"font_size", 22)
			l.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
			l.position = Vector2(x - 120.0, y + 90.0)
			l.size = Vector2(240.0, 30.0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			g.battlefield.add_child(l)
	await _laisser_jouer(0.2)
	await _shot("vitrine_teintes")
	g.queue_free()
	await get_tree().process_frame


## Vitrine : quelques sorts lances separement sur un terrain propre.
func _showcase_effects() -> void:
	if not _visual:
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("sand")
	var bf: Battlefield = g.battlefield
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	for k in 4:
		bf.spawn_enemy(gnome, 300.0 + k * 160.0, 1.0, Vector2(300.0 + k * 160.0, 520.0))
	var casts: Array = [
		[&"fireball", Vector2(260.0, 900.0)],
		[&"frost_field", Vector2(800.0, 900.0)],
		[&"stone_wall", Vector2(540.0, 700.0)],
		[&"weakness_mark", Vector2(540.0, 1200.0)],
		[&"piercing_arrow", Vector2(540.0, 300.0)],
	]
	for c in casts:
		var card: SpellCard = ContentDB.cards.get(c[0])
		if card == null:
			continue
		var ctx := CastContext.make(bf, card)
		ctx.caster = g
		ctx.target_position = c[1]
		ctx.direction = (c[1] - Vector2(540.0, GameConfig.MAGE_LINE_Y)).normalized()
		ctx.target_enemy = bf.enemy_nearest_to(c[1])
		EffectRegistry.cast(card, ctx)
	for k in 6:
		bf.simulate(FIXED_DELTA)
	await _shot("vitrine_sorts")

	g.queue_free()
	await get_tree().process_frame
	await _showcase_terrain()


## SECONDE PLANCHE : les sorts de TERRAIN, sur un champ NEUF.
##
## Pourquoi une planche a part, et pas quatre lancers de plus dans la premiere :
## ces sorts posent un objet qui DURE et occupe de la place (un arbre de 460 px
## de portee, une nappe de 300 px de rayon). Les melanger aux cinq autres donnait
## une bouillie ou plus rien ne se distinguait — c est deja le defaut de
## `shot_03_effets`, qui lance les 49 cartes au meme point et ne permet d en
## juger aucune.
##
## Une scene neuve plutot qu un nettoyage de la premiere : Battlefield n expose
## aucun retrait de monstre, et en inventer un pour le confort d un test ferait
## porter au code de production une contrainte que seul le test demande.
func _showcase_terrain() -> void:
	if not _visual:
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("grass")
	var bf: Battlefield = g.battlefield
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	# Les monstres sont poses DANS la portee des accessoires, sinon la vitrine
	# ment : au premier essai ils etaient a 482 px d un arbre qui attire a 460,
	# donc tous juste hors de portee. La capture montrait six gnomes immobiles
	# et donnait a croire que l attraction ne marchait pas.
	for k in 6:
		bf.spawn_enemy(gnome, 220.0 + k * 130.0, 1.0,
			Vector2(220.0 + k * 130.0, 640.0))
	var terrain: Array = [
		[&"heartwood_totem", Vector2(300.0, 900.0)],
		[&"blight_sapling", Vector2(820.0, 900.0)],
		[&"thunder_root", Vector2(300.0, 1300.0)],
		[&"tidal_pool", Vector2(820.0, 1300.0)],
	]
	for c in terrain:
		var card2: SpellCard = ContentDB.cards.get(c[0])
		if card2 == null:
			_fail("vitrine terrain : carte %s introuvable" % c[0])
			continue
		var ctx2 := CastContext.make(bf, card2)
		ctx2.caster = g
		ctx2.target_position = c[1]
		ctx2.direction = (c[1] - Vector2(540.0, GameConfig.MAGE_LINE_Y)).normalized()
		ctx2.target_enemy = bf.enemy_nearest_to(c[1])
		EffectRegistry.cast(card2, ctx2)
	# Assez de temps pour que les monstres REAGISSENT : qu ils marchent vers
	# l arbre, qu ils reculent dans le courant. 40 pas ne faisaient que 0,67 s —
	# la capture montrait six gnomes encore alignes et donnait a croire que
	# l attraction ne marchait pas. 150 pas valent 2,5 s, de quoi voir un
	# deplacement franc sans que les arbres aient deja expire (10 et 12 s).
	for k in 150:
		bf.simulate(FIXED_DELTA)
	await _shot("vitrine_terrain")

	g.queue_free()
	await get_tree().process_frame
	await _showcase_terrain_permanent()
	await _showcase_ombre_et_temps()


## PLANCHE DES SORTS DE TERRAIN PERMANENTS : la riviere et son pont, les deux
## arbres devenus permanents, ronces, fosse, autel. Une planche a part pour la
## meme raison que la precedente : la riviere coupe TOUT le terrain, melangee aux
## quatre autres sorts elle rendrait la capture illisible.
##
## Les gnomes partent AU-DESSUS de l eau : apres 2,5 s ils doivent se presser vers
## le pont, ce qui est la seule preuve a l oeil que la riviere bloque.
func _showcase_terrain_permanent() -> void:
	if not _visual:
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("grass")
	var bf: Battlefield = g.battlefield
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	for k in 6:
		bf.spawn_enemy(gnome, 140.0 + k * 160.0, 1.0, Vector2(140.0 + k * 160.0, 420.0))
	var poses: Array = [
		[&"terrain_river", Vector2(540.0, 700.0)],
		[&"heartwood_totem", Vector2(250.0, 1000.0)],
		[&"blight_sapling", Vector2(830.0, 960.0)],
		[&"terrain_altar", Vector2(540.0, 1180.0)],
		[&"terrain_brambles", Vector2(220.0, 1330.0)],
		[&"terrain_pit", Vector2(860.0, 1330.0)],
	]
	for c in poses:
		var card3: SpellCard = ContentDB.cards.get(c[0])
		if card3 == null:
			_fail("vitrine terrain permanent : carte %s introuvable" % c[0])
			continue
		var ctx3 := CastContext.make(bf, card3)
		ctx3.caster = g
		ctx3.target_position = c[1]
		ctx3.direction = Vector2.UP
		EffectRegistry.cast(card3, ctx3)
	if bf.river() == null:
		_fail("vitrine terrain permanent : la riviere n a pas ete posee")
	# 6 s : le temps que les gnomes rejoignent le pont et que les premiers le
	# franchissent. Plus tot, la capture les montre encore alignes et ne prouve
	# rien ; les objets etant permanents, attendre ne les fait pas disparaitre.
	for k in 360:
		bf.simulate(FIXED_DELTA)
	await _shot("vitrine_riviere")
	g.queue_free()
	await get_tree().process_frame


## TROISIEME PLANCHE (chantier F2) : les cinq feuilles des packs du 26/09.
##
## Une planche a part, pour la meme raison que la precedente : `shot_04_effets`
## lance les 43 cartes au MEME point et ne permet d en juger aucune — c est la
## bouillie qu on voit sur la capture. Un effet visuel ne se verifie qu a l oeil,
## et l oeil a besoin d un effet a la fois.
##
## Deux planches et non une : `timemagic` est joue par `screen_tint`, donc etire
## sur 1400 px de large. Il recouvre tout. Lance avec les quatre autres, il les
## cacherait tous — c est d ailleurs ce qui rendait `shot_04` illisible.
func _showcase_ombre_et_temps() -> void:
	if not _visual:
		return
	# a) Les quatre feuilles LOCALES, une par quadrant.
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("grass")
	var bf: Battlefield = g.battlefield
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	# Des monstres VIVANTS sous chaque effet : la Lumiere purifiante ne dissipe
	# que ce qu elle touche, et une planche sans cible ne prouverait rien.
	# Les deux sorts d OMBRE qui agissent sur la main (Rappel d ossements,
	# Epuration) s affichent sur le MAGE et non au point vise : c est la regle de
	# `self_aura`, et la premiere capture l a rappelee en posant leurs deux auras
	# l une sur l autre en bas de l ecran pendant que leurs etiquettes montraient
	# un coin de pelouse vide. On ne les met donc pas cote a cote : une seule des
	# deux ici, l autre sur la planche du temps, et l etiquette dit ou regarder.
	var postes: Array = [
		[&"purifying_light", Vector2(300.0, 560.0), "lightpillar"],
		[&"venom_mire", Vector2(800.0, 560.0), "dark_swirl"],
		[&"bone_recall", Vector2(540.0, 1180.0), "dark_soul -> sur le mage"],
	]
	for poste in postes:
		var at: Vector2 = poste[1]
		bf.spawn_enemy(gnome, at.x, 1.0, at + Vector2(0.0, -70.0))
	for poste in postes:
		var card: SpellCard = ContentDB.cards.get(poste[0])
		if card == null:
			_fail("vitrine ombre : carte %s introuvable" % poste[0])
			continue
		var ctx := CastContext.make(bf, card)
		ctx.caster = g
		ctx.target_position = poste[1]
		ctx.direction = Vector2(0.0, -1.0)
		ctx.target_enemy = bf.enemy_nearest_to(poste[1])
		EffectRegistry.cast(card, ctx)
		# Etiquette : sans elle, impossible de dire QUELLE feuille on regarde.
		var l := Label.new()
		l.text = "%s\n%s" % [poste[0], poste[2]]
		l.add_theme_font_size_override(&"font_size", 24)
		l.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
		l.position = poste[1] + Vector2(-150.0, 120.0)
		l.size = Vector2(300.0, 60.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bf.add_child(l)
	for k in 6:
		bf.simulate(FIXED_DELTA)
	# Puis on laisse passer du temps REEL.
	#
	# Piege verifie sur cette vitrine : `simulate()` ne fait PAS avancer les
	# animations. Un AnimatedSprite2D avance sur l horloge du moteur, pas sur le
	# delta qu on passe a la logique de jeu — ajouter des pas de simulation ne
	# changeait donc rien a l image capturee. Et `_shot` n attend que deux frames
	# rendues, soit ~33 ms : toutes les vitrines capturent le DEBUT des
	# animations.
	#
	# 0,22 s est un COMPROMIS mesure sur trois captures successives, entre deux
	# feuilles qui ne durent pas pareil :
	#   - `dark_swirl` boucle sur la mare : ses spectres ne se sont leves qu au
	#     bout de ~0,2 s, avant quoi on ne voit qu une tache ;
	#   - `dark_soul` ne boucle PAS et se libere seule apres 0,71 s. A 0,35 s la
	#     capture arrivait apres sa disparition — la planche montrait un gnome
	#     seul sous son etiquette.
	# Un seul instant doit servir les deux : on se place juste apres la levee des
	# spectres, bien avant la fin de l ame.
	await _laisser_jouer(0.22)
	await _shot("vitrine_ombre")
	g.queue_free()
	await get_tree().process_frame

	# b) L HORLOGE seule, puisqu elle occupe tout l ecran.
	var packed2: PackedScene = load("res://scenes/game/Game.tscn")
	var g2: GameController = packed2.instantiate()
	g2.headless_mode = true
	add_child(g2)
	g2.running = false
	g2.backdrop.setup("sand")
	var bf2: Battlefield = g2.battlefield
	for k in 5:
		bf2.spawn_enemy(gnome, 220.0 + k * 150.0, 1.0,
			Vector2(220.0 + k * 150.0, 620.0))
	var drag: SpellCard = ContentDB.cards.get(&"temporal_drag")
	if drag == null:
		_fail("vitrine temps : carte temporal_drag introuvable")
	else:
		var ctx2 := CastContext.make(bf2, drag)
		ctx2.caster = g2
		ctx2.target_position = Vector2(540.0, 700.0)
		ctx2.direction = Vector2(0.0, -1.0)
		ctx2.target_enemy = bf2.enemy_nearest_to(ctx2.target_position)
		EffectRegistry.cast(drag, ctx2)
	# `dark_vanish` partage cette planche : c est aussi une aura sur le mage, et
	# elle se lit mieux seule sous l horloge que collee a `dark_soul`.
	var purge: SpellCard = ContentDB.cards.get(&"deck_purge")
	if purge != null:
		var ctx3 := CastContext.make(bf2, purge)
		ctx3.caster = g2
		ctx3.target_position = Vector2(540.0, 700.0)
		ctx3.direction = Vector2(0.0, -1.0)
		EffectRegistry.cast(purge, ctx3)
	var l2 := Label.new()
	l2.text = "temporal_drag -> timemagic (plein ecran)\ndeck_purge -> dark_vanish (sur le mage)"
	l2.add_theme_font_size_override(&"font_size", 22)
	l2.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
	l2.position = Vector2(70.0, 1420.0)
	l2.size = Vector2(940.0, 70.0)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bf2.add_child(l2)
	for k in 6:
		bf2.simulate(FIXED_DELTA)
	# L horloge s OUVRE : ses deux premieres images ne sont qu un point, le cadran
	# et les aiguilles ne se deploient qu au tiers de la feuille. Capturee des la
	# premiere frame rendue, elle ressemblerait a un decoupage rate. 0,45 s sur
	# les 0,83 s de la feuille : le cadran est grand ouvert et les aiguilles se
	# lisent.
	await _laisser_jouer(0.45)
	await _shot("vitrine_temps")
	g2.queue_free()
	await get_tree().process_frame


## Joue toutes les cartes du catalogue contre un champ de bataille reel.
## Attrape les cles d effet sans handler et les erreurs de parametres.
func _exercise_every_card() -> void:
	var bf_scene: PackedScene = load("res://scenes/game/Game.tscn")
	var probe: GameController = bf_scene.instantiate()
	probe.headless_mode = true
	add_child(probe)
	probe.running = false
	var bf: Battlefield = probe.battlefield

	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	for i in 6:
		bf.spawn_enemy(gnome, 200.0 + i * 100.0)

	var count: int = 0
	for card: SpellCard in ContentDB.cards.values():
		# On vise comme le ferait un joueur : un point sur le terrain.
		var aim := Vector2(540.0, 900.0)
		var ctx := CastContext.make(bf, card)
		ctx.caster = probe
		ctx.target_position = aim
		ctx.direction = (aim - Vector2(540.0, GameConfig.MAGE_LINE_Y)).normalized()
		ctx.target_enemy = bf.enemy_nearest_to(aim)
		EffectRegistry.cast(card, ctx)
		count += 1
	# Laisse tourner les zones et allies crees.
	for i in 30:
		bf.simulate(FIXED_DELTA)
	await _shot("effets")
	for i in 90:
		bf.simulate(FIXED_DELTA)
	print("[SMOKE] %d cartes lancees sans erreur" % count)
	probe.queue_free()


## Detruit les ennemis proches pour que la simulation avance jusqu au boss.
func _autoplay() -> void:
	_autoplay_for(_game)


func _autoplay_for(g: GameController) -> void:
	# Un choix de sort en attente met la partie en pause : on prend le premier.
	if not RunState.pending_offer.is_empty():
		g.choose_card(0)
		return
	var bf: Battlefield = g.battlefield
	# Le mage de test est invulnerable aux tirs : on veut atteindre la victoire.
	bf.shots.clear()
	for e in bf.enemies.duplicate():
		if e == null or not is_instance_valid(e) or e.is_dead():
			continue
		if e.position.y > GameConfig.MAGE_LINE_Y - 500.0:
			e.take_damage(9999.0, [])
	# Joue une carte des que possible, pour exercer la boucle d incantation.
	if not g.caster.is_busy() and not RunState.hand.is_empty():
		g.play_card(RunState.hand[0], Vector2(540.0, 900.0))


## Instancie le menu et passe par chaque onglet : attrape les chemins de noeuds
## casses et les panneaux qui plantent a la construction.
## PREMIER LANCEMENT — le seul etat que personne ne regarde jamais.
##
## Tous les autres controles tournent apres une partie, donc avec des cartes
## decouvertes, de l XP de compte et des niveaux finis. L ecran d accueil d un
## joueur qui vient d installer le jeu n etait verifie NULLE PART : un panneau
## qui plante sur une liste vide, un compteur a "0 / 0", un bouton actif qui ne
## mene nulle part passeraient tous le harnais.
##
## Ce que ce controle exige :
##   - les quatre onglets se construisent sur un profil vierge ;
##   - la campagne n ouvre QUE le premier niveau ;
##   - le Massacre est ferme (il se merite en finissant la campagne) ;
##   - le deck de depart est jouable tel quel, sans que le joueur touche a rien.
func _check_premier_lancement() -> void:
	SaveData.reset_profile()

	# La campagne s ouvre sur le premier niveau, et lui seul.
	var ouverts: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		if SaveData.is_level_unlocked(lv.id):
			ouverts += 1
	if ouverts != 1:
		_fail("premier lancement : %d niveaux ouverts au lieu d un seul" % ouverts)
	if not SaveData.is_level_unlocked(&"lvl_01"):
		_fail("premier lancement : le niveau 1 n est pas ouvert")

	# Le Massacre (onglet) s ouvre au premier niveau GAGNE : sur un profil
	# vierge il est ferme. L Infini du niveau 1, lui, est ouvert d office.
	if SaveData.massacre_unlocked():
		_fail("premier lancement : le Massacre est deja ouvert")
	if not SaveData.infinite_unlocked(&"lvl_01"):
		_fail("premier lancement : l Infini du niveau 1 est ferme")

	# Le deck de depart doit etre JOUABLE sans rien toucher : un joueur neuf qui
	# tombe sur "Ajoute 7 cartes" avant sa premiere partie ne comprend pas.
	var depart: Array = DeckRules.default_deck_ids()
	if not DeckRules.is_valid(depart):
		_fail("premier lancement : le deck de depart est invalide (%s)"
			% DeckRules.validation_message(depart))

	# Les quatre onglets se construisent sur ce profil vierge.
	var packed: PackedScene = load("res://scenes/main_menu/MainMenu.tscn")
	if packed == null:
		_fail("MainMenu.tscn introuvable")
		return
	var menu: Control = packed.instantiate()
	add_child(menu)
	var tabs: Array = menu.get("TABS")
	for i in tabs.size():
		menu.select_tab(i)
		if menu.current_tab() != i:
			_fail("premier lancement : l onglet %s ne s active pas" % String(tabs[i]))
	# L onglet d ACCUEIL, celui sur lequel le menu s ouvre vraiment. Forcer
	# l onglet 0 photographiait la galerie et donnait a croire qu un joueur neuf
	# tombe sur un catalogue de cartes avant d avoir joue — c est faux, le menu
	# ouvre sur la campagne.
	var accueil: int = int(menu.get("HOME_TAB"))
	menu.select_tab(accueil)
	if menu.current_tab() != accueil:
		_fail("premier lancement : l onglet d accueil ne s ouvre pas")
	await _shot("premier_lancement")
	menu.queue_free()
	await get_tree().process_frame


func _check_menu_screens() -> void:
	var packed: PackedScene = load("res://scenes/main_menu/MainMenu.tscn")
	if packed == null:
		_fail("MainMenu.tscn introuvable")
		return
	var menu: Control = packed.instantiate()
	add_child(menu)
	# Le nombre d onglets se lit sur le menu : ajouter un onglet ne doit pas
	# laisser le smoke en tester silencieusement un de moins.
	var tabs: Array = menu.get("TABS")
	var count: int = tabs.size()
	for i in count:
		menu.select_tab(i)
		if menu.current_tab() != i:
			_fail("l onglet %d ne s active pas" % i)
	# Un second passage exerce refresh() sur un panneau deja construit, et
	# capture chaque onglet sous son propre nom.
	for i in count:
		menu.select_tab(i)
		await _shot("menu_" + String(tabs[i]).to_lower())

	# La campagne est maintenant UN ECRAN PAR ACTE : une seule capture n en
	# montrerait qu un cinquieme, et un fond manquant ou un point pose dans le
	# ciel resterait invisible sur les quatre autres. On tourne toutes les pages,
	# y compris l acte 5, qui n a encore aucun niveau — c est justement le cas qui
	# plante si on oublie le tableau vide.
	menu.select_tab(menu.HOME_TAB)
	var campagne: Control = null
	for p in menu.get_node("%Content").get_children():
		if p is CampaignPanel:
			campagne = p
	if campagne == null:
		_fail("le panneau de campagne est introuvable")
	else:
		var carte: CampaignMap = campagne.get_child(0)
		for a in carte.acts():
			carte.show_act(a)
			await _shot("campagne_acte%d" % a)
		# Les medaillons (UI-007) ont DEUX etats a juger : sur un profil neuf
		# presque tout est verrouille, donc les pages ci-dessus ne montrent que
		# des OMBRES. Le mode testeur ouvre tout sans rien ecrire au profil :
		# on voit alors chaque illustration en couleurs, puis on le referme pour
		# ne rien changer a la suite du smoke.
		#
		# Les ETOILES aussi ont deux etats a juger, sur chacun des cinq fonds : un
		# profil neuf n en montre que des vides. On accorde donc a chaque niveau
		# 0, 1, 2... objectifs (en tournant), sur une COPIE du profil restauree
		# juste apres : la suite du smoke retrouve le profil d avant, a l octet.
		var avant_etoiles: Dictionary = SaveData.to_dictionary()
		var rang_etoiles: int = 0
		for id_e in ContentDB.levels.keys():
			var lv_e: LevelDef = ContentDB.levels[id_e]
			if lv_e.objectives.is_empty():
				continue
			var faits: Dictionary = {}
			for o_i in rang_etoiles % (lv_e.objectives.size() + 1):
				faits[lv_e.objectives[o_i].id] = true
			SaveData.record_victory(lv_e, GameEnums.Mode.EXPLORATION, faits, 1)
			rang_etoiles += 1
		SaveData.set_tester_mode(true)
		carte.rebuild()
		for a in carte.acts():
			carte.show_act(a)
			for id in carte.levels_in_act(a):
				if carte.medallion_for(id) == null:
					_fail("le niveau %s n a pas de medaillon sur la carte" % id)
			await _shot("campagne_ouvert_acte%d" % a)
		SaveData.set_tester_mode(false)
		SaveData.load_from_dictionary(avant_etoiles)
		carte.rebuild()
		# Le detail d un niveau : c est l ecran que le testeur voulait conserver,
		# et il n est atteignable que par un toucher sur un point de la carte.
		campagne.open_level(SaveData.current_level())
		await _shot("campagne_detail")
		await _vitrine_recompenses_campagne(campagne)
		# La meme fiche en INFINI : le second bouton du segment, sa ligne de
		# record et son aide. Le mot MASSACRE ne doit plus y figurer.
		campagne.select_mode(GameEnums.Mode.INFINITE)
		if campagne.current_mode() != GameEnums.Mode.INFINITE:
			_fail("la fiche de niveau refuse le mode INFINI")
		if campagne.mode_labels().has("MASSACRE"):
			_fail("la fiche de niveau affiche encore MASSACRE")
		await _shot("campagne_detail_infini")
		campagne.select_mode(GameEnums.Mode.EXPLORATION)
		campagne.back_to_map()

	# L onglet MASSACRE dans ses deux etats : ferme (profil neuf, deja capture
	# par le passage des onglets) et OUVERT, avec un record et un deck. Sur une
	# COPIE du profil, restauree ensuite, comme les etoiles ci-dessus.
	await _check_massacre_tab(menu)

	# Le grimoire (onglet Galerie) a trois SECTIONS et une fiche detaillee : un
	# seul passage par l onglet n en montrerait qu un neuvieme. On les parcourt
	# toutes, plus une fiche, sinon une section qui plante resterait invisible.
	menu.select_tab(0)
	var grimoire: Control = null
	for p in menu.get_node("%Content").get_children():
		if p is GalleryPanel:
			grimoire = p
	if grimoire == null:
		_fail("le grimoire est introuvable dans l onglet Galerie")
	else:
		for s in GalleryPanel.SECTIONS.size():
			grimoire.show_section(s)
			await _shot("livre_" + GalleryPanel.SECTIONS[s].to_lower())
		# Une fiche ouverte : c est la moitie de l ecran que le joueur lit.
		grimoire.show_section(GalleryPanel.Section.SPELLS)
		grimoire.open_detail(0)
		await _shot("livre_fiche")
		await _vitrine_grimoire_visibilite(grimoire)
		# Une fiche de MONSTRE aussi : elle est bien plus longue (competences),
		# c est elle qui deborde si la mise en page est trop serree.
		grimoire.show_section(GalleryPanel.Section.BEASTS)
		# Un monstre DEJA CROISE (vague 5) : sa fiche montre les resistances en
		# logos et la regle « degats et effets ». La premiere fiche de la liste
		# peut etre une ombre « a rencontrer », qui ne montre rien de tout cela.
		# A ce stade du smoke aucun monstre n est encore croise : on en fait
		# rencontrer un (la persistance est coupee en vitrine), le plus riche en
		# ecarts pour que la capture montre les trois groupes.
		var vu: int = -1
		var ecarts: int = 0
		var betes_vues: Array = grimoire.entries()
		for j in betes_vues.size():
			var n: int = (betes_vues[j] as EnemyDef).resistances.size()
			if n > ecarts:
				ecarts = n
				vu = j
		if vu >= 0:
			SaveData.discover_enemy((betes_vues[vu] as EnemyDef).id)
			grimoire.show_section(GalleryPanel.Section.BEASTS)
			vu = grimoire.entries().find(betes_vues[vu])
		grimoire.open_detail(maxi(vu, 0))
		await _shot("livre_fiche_monstre")
		# La meme fiche defilee jusqu en bas : les groupes Resiste / Vulnerable.
		var defile: ScrollContainer = null
		for n in _tous_les_noeuds(grimoire):
			if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree():
				defile = n as ScrollContainer
		if defile != null:
			defile.scroll_vertical = 100000
			await _shot("livre_fiche_monstre_resistances")
		grimoire.close_detail()

	# L ecran de deck a plusieurs ONGLETS DE DECKS et une fiche d effet qui prend
	# la page : la capture de l onglet ne montre que le premier deck plein. On en
	# cree un second, VIDE, parce que c est lui qui expose le cas limite (les six
	# emplacements vides et le message "il manque 15 cartes").
	menu.select_tab(1)
	var deck_ecran: Control = null
	for p2 in menu.get_node("%Content").get_children():
		if p2 is DeckPanel:
			deck_ecran = p2
	if deck_ecran == null:
		_fail("l ecran de deck est introuvable dans l onglet Deck")
	else:
		deck_ecran.create_deck()
		await _shot("deck_vide")
		await _check_deck_drag(deck_ecran)
		# Tourner une page de collection : les fleches du pied de page doivent
		# marcher ici comme dans le grimoire.
		deck_ecran.turn_page(1)
		await _shot("deck_page2")
		deck_ecran.delete_current_deck()
		await _shot("deck_plein")
		await _check_deck_drag_refused(deck_ecran)
		await _check_deck_scroll(deck_ecran)
		await _vitrine_passifs_deck(deck_ecran)

	# Le profil a quitte la barre du bas pour l en-tete : sans cette capture il
	# ne serait plus verifie du tout.
	# Un compte de niveau 6 pour la capture : au niveau 1 tous les cosmetiques
	# sont verrouilles et l onglet ne montrerait que des cases grises, donc ni
	# le cadre dore de l equipe, ni les contours de rarete des succes accomplis.
	# Le profil est deja factice en smoke (persistence desactivee en headless).
	SaveData.grant_account_xp(SaveData.account_xp_for_level(6))
	for _ch: ChallengeDef in ContentDB.challenges_list():
		if _ch.rarity <= GameEnums.Rarity.RARE:
			SaveData.complete_challenge(_ch.id)
	menu.call("show_profile", true)
	await _shot("menu_profil")
	# Le profil a TROIS sections depuis le chantier L (succes, cosmetiques,
	# stats). Un seul passage n en montrerait qu un tiers, et une section qui
	# plante resterait invisible — exactement le defaut que le SMOKE existe pour
	# attraper sur les autres ecrans a sections (le grimoire, plus haut).
	var profil: Control = _find_profile_panel(menu)
	if profil == null:
		_fail("le panneau de profil est introuvable")
	else:
		for s in ProfilePanel.SECTIONS.size():
			profil.show_section(s)
			await _shot("profil_" + ProfilePanel.SECTIONS[s].to_lower())
		profil.show_section(ProfilePanel.Section.ACHIEVEMENTS)
	menu.call("show_profile", false)

	menu.select_tab(menu.HOME_TAB)
	menu.queue_free()
	print("[SMOKE] menu : %d onglets construits" % count)


## Rejoue un GLISSER au doigt, par la vraie file d evenements du viewport.
##
## Pourquoi pas les methodes publiques du panneau (begin_drag/drop_on) : le
## piege du projet est justement que le Button de la vignette AVALE le
## relachement. Seul un evenement pousse dans le viewport traverse le meme
## chemin que le doigt (_input, puis l interface) ; appeler les methodes
## prouverait la regle, pas le geste. Les tests unitaires couvrent la regle.
func _glisser(depart: Vector2, arrivee: Vector2, capture: String) -> void:
	# Trois pas : le premier franchit le seuil de demarrage, les suivants
	# promenent la carte jusqu a la zone.
	await _glisser_par([depart, depart.lerp(arrivee, 0.15), depart.lerp(arrivee, 0.6),
		arrivee], capture)


## Le meme geste le long d un CHEMIN : appui sur le premier point, un mouvement
## par point suivant, relachement sur le dernier. Sert aux gestes qui changent
## de direction (partir de cote pour prendre une carte, puis descendre).
##
## `pendant` est appele AVANT le relachement : c est le seul moment ou l on
## peut constater qu une carte est prise (le relachement la depose).
func _glisser_par(points: Array[Vector2], capture: String,
		pendant: Callable = Callable()) -> void:
	var vp: Viewport = get_viewport()
	var depart: Vector2 = points[0]
	var arrivee: Vector2 = points[points.size() - 1]
	var appui := InputEventMouseButton.new()
	appui.button_index = MOUSE_BUTTON_LEFT
	appui.pressed = true
	appui.button_mask = MOUSE_BUTTON_MASK_LEFT
	appui.position = depart
	appui.global_position = depart
	vp.push_input(appui, true)
	await get_tree().process_frame
	var avant: Vector2 = depart
	for i in range(1, points.size()):
		var bouge := InputEventMouseMotion.new()
		bouge.button_mask = MOUSE_BUTTON_MASK_LEFT
		bouge.position = points[i]
		bouge.global_position = bouge.position
		bouge.relative = points[i] - avant
		avant = points[i]
		vp.push_input(bouge, true)
		await get_tree().process_frame
	if capture != "":
		await _shot(capture)
	if pendant.is_valid():
		pendant.call()
	var lache := InputEventMouseButton.new()
	lache.button_index = MOUSE_BUTTON_LEFT
	lache.pressed = false
	lache.position = arrivee
	lache.global_position = arrivee
	vp.push_input(lache, true)
	await get_tree().process_frame


## Un toucher simple (appui puis relachement au meme point).
func _toucher(point: Vector2) -> void:
	await _glisser_par([point], "")


## Laisse les conteneurs se disposer. Les vignettes sont reconstruites a chaque
## rendu et leur rectangle n est juste qu apres le tri differe des conteneurs :
## en headless, `_shot` ne fait pas attendre de frame, et le premier appui
## tombait sur la barre du haut (vu : (125, 105)).
func _disposer() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## UI-006 sur un deck VIDE : collection -> deck ajoute, deck -> collection
## retire, et un depot hors zone ne change rien.
func _check_deck_drag(panel: DeckPanel) -> void:
	await _disposer()
	var tuiles: Array[Button] = panel.draggable_tiles(false)
	if tuiles.is_empty():
		_fail("aucune vignette glissable dans la collection")
		return
	var t: Button = tuiles[0]
	var id: StringName = t.get_meta(&"card_id")
	var avant: int = SaveData.massacre_deck().size()
	var cible: Vector2 = panel.deck_zone_rect().get_center()
	await _glisser(t.get_global_rect().get_center(), cible, "deck_glisser")
	if panel.is_dragging():
		_fail("le glisser ne se termine pas au relachement")
	if SaveData.massacre_deck().size() != avant + 1:
		_fail("glisser une carte sur le deck ne l ajoute pas (%d -> %d)" % [
			avant, SaveData.massacre_deck().size()])
	if panel.armed_card() != &"":
		_fail("le relachement d un glisser a ete pris pour un toucher")

	# Hors zone : la carte revient, rien ne change.
	await _disposer()
	tuiles = panel.draggable_tiles(false)
	var n: int = SaveData.massacre_deck().size()
	var t2: Button = tuiles[0]
	var r: Rect2 = t2.get_global_rect()
	# Un point de la COLLECTION, loin de la vignette : ni deck ni seuil manque.
	var ailleurs: Vector2 = panel.collection_zone_rect().end - Vector2(20.0, 20.0)
	await _glisser(r.get_center(), ailleurs, "")
	if SaveData.massacre_deck().size() != n:
		_fail("un depot hors du deck a change le deck")
	# Laisser la carte finir son retour : sinon la capture suivante montre deux
	# cartes en vol et ne permet plus de juger le geste en cours.
	await get_tree().create_timer(DeckPanel.RETURN_S + 0.1).timeout

	# Deck -> collection : retire un exemplaire.
	await _disposer()
	var du_deck: Array[Button] = panel.draggable_tiles(true)
	if du_deck.is_empty():
		_fail("la carte ajoutee n apparait pas dans la grille du deck")
		return
	var d: Button = du_deck[0]
	await _glisser(d.get_global_rect().get_center(),
		panel.collection_zone_rect().get_center(), "deck_glisser_retrait")
	if SaveData.massacre_deck().size() != n - 1:
		_fail("glisser une carte du deck vers la collection ne la retire pas")
	# Le deck ne contenait que la carte ajoutee plus haut : elle doit etre partie.
	if DeckRules.count_of(SaveData.massacre_deck(), id) != 0:
		_fail("la carte glissee hors du deck y est restee")
	print("[SMOKE] deck : glisser-deposer dans les deux sens")


## UI-006 + raison du refus, sur le deck PLEIN : la zone annonce le refus
## pendant le glisser, la carte revient, et le bandeau dit POURQUOI.
func _check_deck_drag_refused(panel: DeckPanel) -> void:
	await _disposer()
	var tuiles: Array[Button] = panel.draggable_tiles(false)
	# La page laissee par le controle precedent peut ne montrer que des cartes
	# GRISEES (non glissables) : les obtenues passent en premier, et le livre
	# d un profil neuf est le seul deck du premier niveau (regle du livre de
	# sorts, 01/10), soit tout juste une page. On cherche donc une page qui en
	# montre une, au lieu de supposer la page courante.
	var tours: int = 0
	while tuiles.is_empty() and tours < panel.page_count():
		panel.turn_page(1)
		await _disposer()
		tuiles = panel.draggable_tiles(false)
		tours += 1
	if tuiles.is_empty():
		_fail("aucune vignette glissable dans la collection (deck plein)")
		return
	var t: Button = tuiles[0]
	var carte: SpellCard = ContentDB.cards.get(StringName(t.get_meta(&"card_id")))
	var attendu: String = DeckRules.refusal_reason(SaveData.massacre_deck(), carte, true)
	if attendu == "":
		_fail("le deck de base devrait etre plein : aucun refus a montrer")
		return
	var avant: Array = SaveData.massacre_deck().duplicate()
	await _glisser(t.get_global_rect().get_center(),
		panel.deck_zone_rect().get_center(), "deck_glisser_refus")
	if SaveData.massacre_deck() != avant:
		_fail("un ajout refuse a quand meme change le deck")
	if panel.refusal_message() != attendu:
		_fail("le refus affiche '%s' au lieu de la raison de DeckRules '%s'" % [
			panel.refusal_message(), attendu])
	# Le retour de la carte vers sa vignette doit s etre joue sans erreur, et la
	# capture doit montrer le bandeau seul : la carte qui revient passe dessus.
	await get_tree().create_timer(DeckPanel.RETURN_S + 0.1).timeout
	await _shot("deck_refus")


## DEFILEMENT AU DOIGT de la zone du deck, geste commence SUR une vignette.
##
## Le defaut : les vignettes sont des Button, qui gardent l appui pour eux ; et
## le glisser-deposer (UI-006) prenait la carte des 28 px de mouvement, dans
## toutes les directions. Un pouce qui voulait faire defiler un deck trop long
## soulevait donc une carte — il ne pouvait defiler qu en visant l interstice
## de 8 px entre deux vignettes.
##
## Ce qui est verifie, au doigt et par la vraie file d evenements :
##  - glisser VERTICAL sur une vignette -> la zone defile, aucune carte prise,
##    et le relachement n est pas pris pour un toucher (rien n est retire) ;
##  - partir DE COTE -> la carte est prise, et deposee sur la collection elle
##    quitte le deck (le glisser-deposer survit) ;
##  - toucher simple -> retire toujours un exemplaire.
func _check_deck_scroll(panel: DeckPanel) -> void:
	# Un deck a DEUX FOIS plus de cartes differentes que la regle n en permet :
	# c est un deck hors regle (profil anterieur a la regle des six), le seul
	# qui depasse de sa zone. Il est cree a part et supprime a la fin.
	panel.create_deck()
	var ids: Array = []
	for c: SpellCard in panel.collection():
		ids.append(String(c.id))
		if ids.size() >= DeckRules.MAX_DISTINCT * 2:
			break
	SaveData.set_massacre_deck(ids)
	panel.refresh()
	await _disposer()
	var zone: ScrollContainer = panel.deck_scroll()
	if not panel.deck_can_scroll():
		_fail("un deck de %d cartes differentes devrait faire defiler sa zone" % ids.size())
		panel.delete_current_deck()
		return

	# 1) Vertical, commence sur une vignette : la zone defile.
	var tuiles: Array[Button] = panel.draggable_tiles(true)
	var t: Button = tuiles[DeckPanel.COLS]   # deuxieme rangee : il y a de quoi remonter
	var depart: Vector2 = t.get_global_rect().get_center()
	var haut: Vector2 = depart - Vector2(0.0, DeckPanel.TILE_H)
	var avant_defil: int = zone.scroll_vertical
	var n: int = SaveData.massacre_deck().size()
	await _glisser_par([depart, depart.lerp(haut, 0.15), depart.lerp(haut, 0.6), haut],
		"deck_defiler", func() -> void:
			if panel.is_dragging():
				_fail("glisser verticalement sur une vignette du deck prend la carte au lieu de defiler"))
	if zone.scroll_vertical <= avant_defil:
		_fail("glisser verticalement sur une vignette ne fait pas defiler le deck (%d -> %d)" % [
			avant_defil, zone.scroll_vertical])
	if SaveData.massacre_deck().size() != n:
		_fail("le relachement d un defilement a ete pris pour un toucher (%d -> %d cartes)" % [
			n, SaveData.massacre_deck().size()])

	# 2) De cote puis vers la collection : le glisser-deposer tient toujours.
	await _disposer()
	var d: Button = _tuile_visible(panel)
	if d == null:
		_fail("aucune vignette du deck n est entierement visible apres le defilement")
		panel.delete_current_deck()
		return
	var id_d: StringName = d.get_meta(&"card_id")
	var avant_d: int = DeckRules.count_of(SaveData.massacre_deck(), id_d)
	var p0: Vector2 = d.get_global_rect().get_center()
	var cible: Vector2 = panel.collection_zone_rect().get_center()
	await _glisser_par([p0, p0 + Vector2(DeckPanel.DRAG_START_PX * 2.0, 0.0),
		cible.lerp(p0, 0.5), cible], "")
	if DeckRules.count_of(SaveData.massacre_deck(), id_d) != avant_d - 1:
		_fail("prendre une carte du deck de cote puis la deposer sur la collection ne la retire plus")

	# 3) Toucher simple : retire un exemplaire, comme avant.
	await get_tree().create_timer(DeckPanel.RETURN_S + 0.1).timeout
	await _disposer()
	var v: Button = _tuile_visible(panel)
	var n2: int = SaveData.massacre_deck().size()
	if v == null:
		_fail("aucune vignette du deck visible pour le toucher simple")
	else:
		await _toucher(v.get_global_rect().get_center())
	if SaveData.massacre_deck().size() != n2 - 1:
		_fail("un toucher sur une vignette du deck ne retire plus d exemplaire (%d -> %d)" % [
			n2, SaveData.massacre_deck().size()])
	panel.delete_current_deck()
	print("[SMOKE] deck : defilement au doigt, glisser-deposer et toucher")


## Une vignette du deck ENTIEREMENT dans la partie visible de la zone qui
## defile : une vignette a moitie sortie se toucherait sur ce qui la recouvre.
func _tuile_visible(panel: DeckPanel) -> Button:
	var vue: Rect2 = panel.deck_scroll().get_global_rect()
	for t in panel.draggable_tiles(true):
		if vue.encloses(t.get_global_rect()):
			return t
	return null


## Pre-cast : un second sort doit pouvoir etre prepare pendant le chargement du
## premier, et un troisieme remplacer celui qui attendait.
## L ecran d AMELIORATION, pose sur un vrai combat.
##
## Pourquoi il faut le forcer : en headless `GameController` tranche tout de
## suite (`AutoPick.upgrade_index`) pour ne pas bloquer le banc, donc le panneau ne
## s affiche JAMAIS dans une partie de test. Sans ce controle, le seul regard
## porte sur lui venait de `tools/make_upgrades`, qui le pose sur un fond neutre
## — on ne pouvait donc pas juger ce que le joueur voit reellement : un voile
## semi-transparent par-dessus des monstres qui descendent.
## LA MAIN PETRIFIEE par le regard d une gorgone.
##
## Pourquoi il faut la forcer : aucune partie de test ne croise une gorgone au
## bon moment, donc le rendu des cartes bloquees n etait verifie NULLE PART. Le
## moteur refusait bien de les jouer — et le joueur voyait six cartes
## identiques, appuyait dans le vide, sans rien comprendre. Une regle qu on
## subit sans la voir se lit comme un bug.
func _check_cartes_petrifiees() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	add_child(g)
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		_fail("cartes petrifiees : lvl_01 introuvable")
		g.queue_free()
		return
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	# APRES start_level, qui remet `running` a vrai. Pose avant, il etait ecrase :
	# la partie tournait pendant les images d attente de la capture, et le terrain
	# (sans gorgone) remettait le nombre de regards a zero a chaque image — la
	# capture `main_petrifiee` ne montrait AUCUNE carte petrifiee.
	g.running = false
	for k in 6:
		g.battlefield.simulate(FIXED_DELTA)

	# UNE MAIN AVEC DOUBLONS : c est le cas que l ancien registre ratait. Les
	# copies d une carte partagent la meme ressource ; geler « la carte » gelait
	# toutes ses copies (deux regards, quatre cartes grises). Trois cartes
	# distinctes du deck du niveau, reparties pour que les deux cartes gelees
	# (les plus a droite) aient chacune une jumelle LIBRE plus a gauche.
	var distinctes: Array[SpellCard] = []
	for c: SpellCard in level.exploration_deck:
		if c != null and not c.is_passive and not distinctes.has(c):
			distinctes.append(c)
	if distinctes.size() < 3:
		_fail("cartes petrifiees : le deck de lvl_01 compte moins de 3 sorts differents")
		g.queue_free()
		return
	var a: SpellCard = distinctes[0]
	var b: SpellCard = distinctes[1]
	var c3: SpellCard = distinctes[2]
	RunState.hand.clear()
	for card: SpellCard in [a, b, c3, a, b, a]:
		if RunState.hand.size() < GameConfig.MAX_HAND_SIZE:
			RunState.hand.append(card)
	RunState.hand_changed.emit()

	# LE PLAFOND : il doit toujours rester une carte jouable, quoi qu il arrive.
	RunState.set_card_block_count(99)
	var restantes: int = 0
	for i in RunState.hand.size():
		if not RunState.is_slot_blocked(i):
			restantes += 1
	if restantes < RunState.MIN_PLAYABLE_CARDS:
		_fail("cartes petrifiees : %d carte(s) jouable(s), le plafond ne tient pas"
			% restantes)
	# Deux regards : la Matrone en gele deux. EXEMPLAIRES, pas cartes.
	RunState.set_card_block_count(2)
	var attendu_gel: int = mini(2, maxi(0,
		RunState.hand.size() - RunState.MIN_PLAYABLE_CARDS))
	if RunState.blocked_count() != attendu_gel:
		_fail("cartes petrifiees : %d gelees au lieu de %d (main de %d)"
			% [RunState.blocked_count(), attendu_gel, RunState.hand.size()])
	await get_tree().process_frame
	# CE QUE L ECRAN MONTRE : autant de cartes marquees que d exemplaires geles.
	# C est le controle qui rougit sur le defaut d origine (4 marquees pour 2).
	var marquees: int = _cartes_marquees(g, "Petrifiee")
	if marquees != attendu_gel:
		_fail("cartes petrifiees : %d cartes marquees a l ecran pour %d exemplaires geles"
			% [marquees, attendu_gel])
	await _shot("main_petrifiee")
	g.queue_free()
	await get_tree().process_frame


## Cartes de la main du HUD qui portent le bandeau `nom` ("Petrifiee", "Volee",
## "Sommeil"). Les cartes en cours de liberation (reconstruction de la main dans
## la meme image) ne comptent pas.
func _cartes_marquees(g: GameController, nom: String) -> int:
	var hud: Node = g.get_node_or_null("HUD")
	if hud == null:
		return -1
	var main: Node = hud.get("_hand")
	if main == null:
		return -1
	var n: int = 0
	for cv in main.get_children():
		if cv.is_queued_for_deletion():
			continue
		if cv.get_node_or_null(nom) != null:
			n += 1
	return n


## VITRINE DES MECANIQUES v3 — ce que deux chantiers n avaient capture qu avec
## des sondes jetables : la marque de renaissance, le Zzz du dormeur et la main
## grisee qu il impose, le laser de riposte, le fantome de l Horloger, la carte
## VOLEE. Une sonde jetable ne protege rien : le prochain changement de Fx ou du
## HUD pouvait effacer l un de ces signaux sans qu aucun etage ne bronche.
##
## Des EnemyDef CONSTRUITS ICI plutot que ceux du contenu : le contenu de ces
## monstres arrive en parallele, et une vitrine qui dependrait d un id de
## contenu disparaitrait avec lui. Seules les feuilles (anim_key) viennent du
## catalogue, pour que la capture montre de vrais monstres.
##
## Une partie COMPLETE (start_level) et non un terrain nu : la carte volee et la
## main grisee vivent dans le HUD, que seul start_level branche.
func _showcase_mecaniques_v3() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		_fail("vitrine v3 : lvl_01 introuvable")
		g.queue_free()
		return
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	g.running = false          # apres start_level, voir _check_cartes_petrifiees
	var bf: Battlefield = g.battlefield
	bf.clear_all()             # la vague 1 du niveau ne doit pas se meler a la planche
	RunState.draw(GameConfig.MAX_HAND_SIZE)
	# Le voleur vise la carte la plus LONGUE : on lui en garantit une, sinon sur
	# une main de copies egales il prendrait la premiere et la capture ne dirait
	# rien de sa regle.
	if RunState.hand.size() < 3:
		_fail("vitrine v3 : main de %d cartes, le voleur n aurait rien a prendre"
			% RunState.hand.size())

	# 1) RENAISSANCE : tue tout de suite, la marque reste au sol (delai long).
	var ne := _def_v3("vitrine_ne", "slime_ghost", 20.0, 0.0)
	var fantome := _def_v3("vitrine_renaissance", "slime_ghost", 20.0, 0.0)
	fantome.rebirth_def = ne
	fantome.rebirth_count = 2
	fantome.rebirth_delay = 60.0
	var f: Enemy = bf.spawn_enemy(fantome, 230.0, 1.0, Vector2(230.0, 380.0))
	# L Horloger fixe la duree de la scene : on attend qu il approche de son
	# retour (son fantome s allume a l approche) sans l atteindre.
	# Il marche VITE : a allure normale, deux secondes de retour ne l ecartaient
	# que d un demi-corps de son fantome, et la capture les confondait.
	var horloger := _def_v3("vitrine_horloger", "demon", 400.0, 250.0)
	horloger.rewind_interval = 6.0
	horloger.rewind_seconds = 2.0
	var attente: float = Enemy._rewind_period(horloger) * 0.8
	# 2) SOMMEIL : s endort vers la FIN de l attente. Un sommeil est plafonne
	#    (Enemy.SLEEP_MAX_DURATION) et suivi d une fenetre de magie garantie : endormi
	#    trop tot, le renard etait deja reveille a la capture.
	var dormeur := _def_v3("vitrine_sommeil", "fox", 400.0, 0.0)
	dormeur.sleep_interval = attente * 0.8
	dormeur.sleep_duration = Enemy.SLEEP_MAX_DURATION
	bf.spawn_enemy(dormeur, 850.0, 1.0, Vector2(850.0, 380.0))
	# 3) VOLEUR : prend une carte, et ne la lance pas avant la capture.
	var voleur := _def_v3("vitrine_voleur", "mageguardian_magenta", 400.0, 0.0)
	voleur.steal_interval = 0.4
	voleur.steal_cast_delay = 60.0
	voleur.steal_damage_per_cast_second = 1.0
	var v: Enemy = bf.spawn_enemy(voleur, 540.0, 1.0, Vector2(540.0, 560.0))
	# 4) HORLOGER : il marche ; son fantome reste la ou il reviendra.
	var h: Enemy = bf.spawn_enemy(horloger, 820.0, 1.0, Vector2(820.0, 420.0))
	# 5) LASER : un coup recu, un rayon vers le mage. Tire en DERNIER, juste
	#    avant la capture : le rayon ne dure qu une fraction de seconde.
	var golem := _def_v3("vitrine_laser", "mechagolem", 5000.0, 0.0)
	golem.laser_damage = 1
	golem.laser_cooldown = 1.0
	var l: Enemy = bf.spawn_enemy(golem, 250.0, 1.0, Vector2(250.0, 900.0))
	if f == null or v == null or h == null or l == null:
		_fail("vitrine v3 : un monstre construit n a pas pu naitre")
		g.queue_free()
		return

	f.take_damage(99999.0, [])
	# Assez de temps de monde pour que le dormeur s endorme, que le voleur vole,
	# et que l Horloger s approche de son retour sans l atteindre.
	var t: float = 0.0
	while t < attente:
		bf.simulate(FIXED_DELTA)
		t += SpeedGauge.world_delta(FIXED_DELTA)

	# CONTROLES MOTEUR (valent aussi en headless).
	if bf.pending_rebirth_count() != 1:
		_fail("vitrine v3 : %d marque(s) de renaissance au sol au lieu de 1"
			% bf.pending_rebirth_count())
	if not RunState.is_silenced():
		_fail("vitrine v3 : le dormeur ne coupe pas la magie")
	if v.stolen_card() == null:
		_fail("vitrine v3 : le voleur n a rien vole")
	if h.rewinds_done() != 0:
		_fail("vitrine v3 : l Horloger est deja revenu, le fantome ne se verrait plus")

	_etiquette_v3(bf, Vector2(230.0, 380.0), "renaissance\n(marque au sol)")
	_etiquette_v3(bf, Vector2(850.0, 380.0), "sommeil (Zzz)\nmain grisee")
	_etiquette_v3(bf, Vector2(540.0, 560.0), "voleur\n(carte VOLEE)")
	_etiquette_v3(bf, h.position, "Horloger\n(fantome = retour)")
	_etiquette_v3(bf, Vector2(250.0, 900.0), "laser de riposte")

	var tirs: int = bf.lasers_fired
	bf._hit(l, 1.0, [])
	if bf.lasers_fired != tirs + 1:
		_fail("vitrine v3 : le coup n a pas declenche de laser")

	if _visual:
		await get_tree().process_frame
		# CONTROLES D AFFICHAGE : chaque signal doit EXISTER, pas seulement sa regle.
		var ghost: Node2D = h.get("_rewind_ghost")
		if ghost == null:
			_fail("vitrine v3 : l Horloger n a pas de fantome")
		elif ghost.global_position.distance_to(h.global_position) < h.visual_radius():
			_fail("vitrine v3 : le fantome de l Horloger se confond avec lui")
		var zzz: bool = false
		for e in bf.enemies:
			if e != null and is_instance_valid(e) and e.is_sleeping() and e.get("_v3_zzz") != null:
				zzz = true
		if not zzz:
			_fail("vitrine v3 : le dormeur ne porte pas de Zzz")
		if _cartes_marquees(g, "Volee") != 1:
			_fail("vitrine v3 : %d carte(s) marquee(s) VOLEE au lieu de 1"
				% _cartes_marquees(g, "Volee"))
		if _cartes_marquees(g, "Sommeil") < 1:
			_fail("vitrine v3 : aucune carte marquee SOMMEIL dans la main")
		await _shot("vitrine_mecaniques_v3")
	g.queue_free()
	await get_tree().process_frame
	# Le laser a coute un point de vitesse au mage : les ecrans suivants
	# repartent d une jauge neuve.
	SpeedGauge.reset()


## LE BANDEAU D OBJECTIFS EN COMBAT, sur un vrai HUD.
##
## La partie autoplay ne montre le bandeau que dans l etat ou elle le laisse :
## elle ne garantit ni un compte en cours ni un objectif PERDU. On pose donc ici
## un niveau aux trois objectifs representatifs — deux comptes et une
## interdiction qu on fait perdre — pour que les trois etats du bandeau soient
## captures a chaque passage, et on passe par le VRAI chemin : GameController.simulate ->
## RunState.advance_clock -> objective_failed -> HUD.
##
## UN COMBAT CHARGE, sur le premier et le dernier acte : main de 6 cartes, rail
## des passifs plein, monstres sur la ligne d apparition ET en fin de course a
## cote du bandeau. Le bandeau a quitte le haut de l ecran parce qu il cachait
## les apparitions ; la capture doit montrer qu il ne cache plus rien d utile, et
## qu il se lit sur le fond clair de l acte I comme sur l espace de l acte V.
func _check_objectifs_en_combat() -> void:
	var niveaux: Array = ContentDB.levels.values()
	niveaux.sort_custom(func(a: LevelDef, b: LevelDef) -> bool:
		return String(a.id) < String(b.id))
	var dernier_acte: int = 0
	for l: LevelDef in niveaux:
		dernier_acte = maxi(dernier_acte, l.act)
	for acte: int in [1, dernier_acte]:
		var base: LevelDef = null
		for l: LevelDef in niveaux:
			if l.act == acte:
				base = l
				break
		if base == null:
			_fail("objectifs en combat : aucun niveau dans l acte %d" % acte)
			continue
		await _vitrine_objectifs(base, acte)


func _vitrine_objectifs(base: LevelDef, acte: int) -> void:
	var level: LevelDef = base.duplicate()
	var meme := _objectif_vitrine(&"vitrine_meme_sort", &"same_card_casts", {"count": 30})
	var vol := _objectif_vitrine(&"vitrine_volants", &"kill_flying", {"count": 5})
	var intact := _objectif_vitrine(&"vitrine_intact", &"no_damage_taken", {})
	var objs: Array[ObjectiveDef] = [meme, vol, intact]
	level.objectives = objs
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	add_child(g)
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	g.running = false          # apres start_level, voir _check_cartes_petrifiees

	# Main PLEINE : les sorts du deck du niveau, en boucle jusqu au plafond.
	var sorts: Array[SpellCard] = []
	for c: SpellCard in level.exploration_deck:
		if c != null and not c.is_passive:
			sorts.append(c)
	if not sorts.is_empty():
		RunState.hand.clear()
		var k: int = 0
		while RunState.hand.size() < GameConfig.MAX_HAND_SIZE:
			RunState.hand.append(sorts[k % sorts.size()])
			k += 1
		RunState.hand_changed.emit()
	# Rail des passifs PLEIN.
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive and RunState.equipped_passives.size() < GameConfig.PASSIVE_SLOTS:
			RunState.equipped_passives.append(c)
	RunState.passives_changed.emit()

	# Les monstres du niveau : une rangee sur la ligne d apparition, une au milieu,
	# et deux en fin de course sur la droite, la ou vit le bandeau.
	var defs: Array[EnemyDef] = []
	for w: WaveDef in level.waves:
		for e: WaveEntry in w.entries:
			var est_boss: bool = e != null and e.enemy != null and e.enemy.kind == GameEnums.EnemyKind.BOSS
			if e != null and e.enemy != null and not defs.has(e.enemy) and not est_boss:
				defs.append(e.enemy)
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	if defs.is_empty() and gnome != null:
		defs.append(gnome)
	var places: Array[Vector2] = []
	for i in 5:
		places.append(Vector2(160.0 + i * 190.0, GameConfig.SPAWN_LINE_Y))
	for i in 4:
		places.append(Vector2(220.0 + i * 220.0, GameConfig.MAGE_LINE_Y * 0.5))
	places.append(Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.75, GameConfig.MAGE_LINE_Y - 160.0))
	places.append(Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.9, GameConfig.MAGE_LINE_Y - 60.0))
	for i in places.size():
		if not defs.is_empty():
			g.battlefield.spawn_enemy(defs[i % defs.size()], places[i].x, 1.0, places[i])

	var carte: SpellCard = RunState.hand[0] if not RunState.hand.is_empty() else null
	# Un lancer de MOINS que le palier d amelioration : au palier, l ecran modal
	# d amelioration s ouvre et recouvre la capture (vu au premier essai).
	if carte != null:
		for i in GameConfig.CARD_UPGRADE_CASTS - 1:
			RunState.note_cast(carte)
	var volant := EnemyDef.new()
	volant.flying = true
	for i in 3:
		RunState.note_kill(volant)
	RunState.note_damage_taken(gnome)
	for k in 3:
		g.simulate(FIXED_DELTA)
	if not RunState.is_objective_failed(intact.id):
		_fail("objectifs en combat : le coup recu n a pas fait perdre « sans degats »")
	var hud: Node = g.get_node_or_null("HUD")
	var lignes: Dictionary = hud.get("_obj_lines") if hud != null else {}
	if lignes.size() != objs.size():
		_fail("objectifs en combat : %d lignes au bandeau pour %d objectifs"
			% [lignes.size(), objs.size()])
	else:
		var l_vol: Label = lignes[vol]
		var l_int: Label = lignes[intact]
		if not l_vol.visible or not l_vol.text.ends_with("3/5"):
			_fail("objectifs en combat : volants affiches '%s'" % l_vol.text)
		if not l_int.visible or not l_int.text.ends_with("rate"):
			_fail("objectifs en combat : l echec ne s affiche pas ('%s')" % l_int.text)
	await get_tree().process_frame
	await _shot("objectifs_en_combat_acte%d" % acte)
	RunState.equipped_passives.clear()
	RunState.passives_changed.emit()
	g.queue_free()
	await get_tree().process_frame
	SpeedGauge.reset()


func _objectif_vitrine(id: StringName, key: StringName, params: Dictionary) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = id
	o.check_key = key
	o.params = params
	return o


## LE MIROIR DE FORGE avec une APPRENTIE jouee : il doit etre son reflet, pas
## celui du vieux mage. Le mage en bas de l ecran et le Miroir en haut doivent
## porter la meme silhouette.
func _showcase_miroir() -> void:
	var miroir: EnemyDef = ContentDB.enemies.get(&"glass_mirror")
	var apprentie: AccountRewardDef = null
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r != null and r.is_apprentice():
			apprentie = r
			break
	if miroir == null or apprentie == null:
		_fail("vitrine miroir : Miroir de Forge ou apprentie introuvable")
		return
	# Le profil est rendu tel quel apres la vitrine : les controles suivants
	# (cosmetiques du mage) supposent le mage equipe.
	var profil: Dictionary = SaveData.to_dictionary()
	SaveData.set_tester_mode(true)
	if not SaveData.equip_cosmetic(apprentie.id):
		_fail("vitrine miroir : %s ne s equipe pas" % apprentie.id)
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	g.running = false
	g.battlefield.clear_all()
	var e: Enemy = g.battlefield.spawn_enemy(miroir, 540.0, 1.0, Vector2(540.0, 700.0))
	if e == null:
		_fail("vitrine miroir : le Miroir ne nait pas")
	elif String(e.sheet_key()) != apprentie.texture_name:
		_fail("vitrine miroir : le Miroir porte %s au lieu de %s"
			% [e.sheet_key(), apprentie.texture_name])
	elif _visual:
		var anim: AnimatedSprite2D = e.get("_anim")
		if anim == null or anim.sprite_frames != AnimCatalog.frames(StringName(apprentie.texture_name)):
			_fail("vitrine miroir : le sprite du Miroir n est pas celui de l apprentie")
	_etiquette_v3(g.battlefield, Vector2(540.0, 700.0),
		"Miroir de Forge\nreflet de : %s" % apprentie.texture_name)
	await _laisser_jouer(0.2)
	await _shot("vitrine_miroir_apprentie")
	g.queue_free()
	await get_tree().process_frame
	SaveData.load_from_dictionary(profil)
	SaveData.set_tester_mode(false)


func _def_v3(id: String, sheet: String, hp: float, speed: float) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.kind = GameEnums.EnemyKind.NORMAL
	d.max_hp = hp
	d.base_speed = speed
	d.base_radius = 40.0
	d.power = 2
	d.anim_key = StringName(sheet)
	return d


func _etiquette_v3(bf: Node2D, at: Vector2, texte: String) -> void:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override(&"font_size", 24)
	l.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
	l.position = at + Vector2(-150.0, 70.0)
	l.size = Vector2(300.0, 60.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bf.add_child(l)


func _check_upgrade_panel() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	# PAS headless : c est tout l objet du controle.
	add_child(g)
	g.running = false
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		_fail("ecran d amelioration : lvl_01 introuvable")
		g.queue_free()
		return
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	# Des monstres a l ecran : le voile doit laisser voir ce qui descend.
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	if gnome != null:
		for k in 5:
			g.battlefield.spawn_enemy(gnome, 220.0 + k * 150.0, 1.0,
				Vector2(220.0 + k * 150.0, 500.0))
	for k in 10:
		g.battlefield.simulate(FIXED_DELTA)

	var carte: SpellCard = ContentDB.cards.get(&"ember_pool")
	if carte == null:
		_fail("ecran d amelioration : ember_pool introuvable")
		g.queue_free()
		return

	# LE LISERE DE PROGRESSION sur les cartes en main. On force des lancers sur
	# une carte que la main porte, sinon la capture est prise avant qu un seul
	# sort ait ete joue et la jauge n a rien a montrer. C est ce qui m a d abord
	# fait croire qu elle ne s affichait pas.
	var suivie: SpellCard = null
	for c: SpellCard in RunState.hand:
		if c != null and not c.is_passive:
			suivie = c
			break
	if suivie != null:
		var moitie: int = maxi(1, GameConfig.CARD_UPGRADE_CASTS / 2)
		for i in moitie:
			RunState.note_cast(suivie)
		var avance: float = RunState.upgrade_progress(suivie)
		if avance < 0.4 or avance > 0.7:
			_fail("liseré d amelioration : %d lancers sur %d donnent %.2f, attendu ~0,5"
				% [moitie, GameConfig.CARD_UPGRADE_CASTS, avance])
		RunState.hand_changed.emit()
		await get_tree().process_frame
		await _shot("main_progression")
	# SECONDE maturation, pour que la capture montre aussi le CUMUL : l entete
	# "Maturation 2 sur 2" et la ligne "Deja acquis". C est l etat le plus charge
	# de l ecran, donc celui ou un debordement se verrait.
	var pool: Array = RunState.upgrade_pool_for(carte)
	if GameConfig.CARD_UPGRADE_TIERS > 1 and not pool.is_empty():
		RunState.upgrades_taken[carte.id] = [StringName(pool[0]["id"])]
	var voies: Array = RunState.draw_upgrade_offer(carte)
	if voies.size() != GameConfig.LEVEL_UP_CHOICES:
		_fail("ecran d amelioration : %d voies au lieu de %d"
			% [voies.size(), GameConfig.LEVEL_UP_CHOICES])
	var panel: CardUpgradePanel = g.call(&"_ensure_upgrade_panel")
	if panel == null:
		_fail("ecran d amelioration : le panneau ne se construit pas")
		g.queue_free()
		return
	panel.show_paths(carte, voies)
	await get_tree().process_frame
	# Le panneau doit COUVRIR l ecran. Un `set_anchors_preset` sans offsets rend
	# une taille (0,0) et tout se dessine dans le coin : rien ne plante, aucun
	# etage ne le voit, seule une capture le montre.
	if panel.size.x < 900.0 or panel.size.y < 1600.0:
		_fail("ecran d amelioration : panneau de %s, il ne couvre pas l ecran"
			% panel.size)
	await _shot("amelioration")
	g.queue_free()
	await get_tree().process_frame


func _check_precast() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = true
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	RunState.draw(4)
	if RunState.hand.size() < 3:
		_fail("pas assez de cartes en main pour tester le pre-cast")
	else:
		var a: SpellCard = RunState.hand[0]
		var b: SpellCard = RunState.hand[1]
		var c: SpellCard = RunState.hand[2]
		var cible := Vector2(540.0, 700.0)
		if not g.play_card(a, cible, null):
			_fail("le premier sort ne part pas")
		elif not g.play_card(b, cible, null):
			_fail("impossible de preparer un second sort pendant le chargement")
		elif not g.play_card(c, cible, null):
			_fail("impossible de remplacer le sort en attente")
		elif g.caster.queued_card() != c:
			_fail("le troisieme sort n a pas remplace le second en attente")
		else:
			print("[SMOKE] pre-cast : 1 en cours, 1 en attente, remplacable")
	g.queue_free()
	await get_tree().process_frame


## CHANTIER P : vaincre un mini-boss ou un boss ne propose PLUS de carte d office
## (trois epiques / trois legendaires tirees hors de tout pool). Les cartes
## fortes viennent des objectifs du niveau. Joue sur une vraie partie : la
## vague de boss nettoyee ne doit mettre aucune offre en attente.
func _check_boss_reward() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	g.start_level(level, GameEnums.Mode.EXPLORATION)

	# Trouve l index d une vague de boss et simule son nettoyage.
	var index: int = -1
	for i in g.spawner.waves.size():
		var w: WaveDef = g.spawner.waves[i]
		if w != null and (w.is_boss or w.is_miniboss):
			index = i
			break
	if index < 0:
		_fail("le niveau 1 ne contient aucune vague de boss")
	else:
		RunState.pending_offer.clear()
		g._on_wave_cleared(index)
		if not RunState.pending_offer.is_empty():
			_fail("vaincre un boss offre encore %d cartes d office"
				% RunState.pending_offer.size())
		else:
			print("[SMOKE] vague de boss nettoyee : aucune carte d office")
		RunState.pending_offer.clear()
	g.queue_free()
	await get_tree().process_frame


## L ecran de briefing se construit pour les deux modes et mene bien a la partie.
func _check_briefing() -> void:
	var packed: PackedScene = load("res://scenes/loading/LoadingScreen.tscn")
	if packed == null:
		_fail("LoadingScreen.tscn introuvable")
		return
	for mode in [GameEnums.Mode.EXPLORATION, GameEnums.Mode.INFINITE, GameEnums.Mode.MASSACRE]:
		var niveau: StringName = &"lvl_01"
		if mode == GameEnums.Mode.MASSACRE:
			niveau = MassacreMode.LEVEL_ID
		SceneRouter.payload = {"level_id": niveau, "mode": mode}
		var screen: Control = packed.instantiate()
		add_child(screen)
		await get_tree().process_frame
		# Le briefing doit montrer QUELQUE CHOSE : un ecran vide ne sert a rien.
		var menaces: VBoxContainer = screen.get_node_or_null("%Waves")
		if menaces == null or menaces.get_child_count() == 0:
			_fail("le briefing n affiche aucune menace (mode %d)" % mode)
		if mode == GameEnums.Mode.EXPLORATION:
			await _shot("briefing")
		elif mode == GameEnums.Mode.MASSACRE:
			await _shot("briefing_massacre")
		screen.queue_free()
		await get_tree().process_frame
	# La route du menu passe bien par le briefing, pas directement par la partie.
	if SceneRouter.LOADING == SceneRouter.GAME:
		_fail("la route de briefing pointe sur la partie")
	print("[SMOKE] briefing construit pour les trois modes")


## Une scene de visual novel doit se construire et se derouler jusqu au bout.
## En fenetre reelle, la capture montre fond + portraits + boite de texte : c est
## la seule preuve que le texte sombre est lisible sur le papier.
func _check_story() -> void:
	var packed: PackedScene = load(SceneRouter.STORY)
	if packed == null:
		_fail("StoryScene.tscn introuvable")
		return
	# test_mode : la scene ne previent pas le routeur a la fin, sinon elle
	# ferait changer de scene le harnais lui-meme au milieu du smoke.
	SceneRouter.payload = {"story_id": SceneRouter.PROLOGUE_STORY, "test_mode": true}
	var screen: Control = packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var total: int = int(screen.call("total_lines"))
	if total <= 0:
		_fail("la scene de prologue n a aucune replique")
		screen.queue_free()
		return
	# Capture sur la 3e replique : le prologue y a un portrait ET du texte long,
	# donc la capture prouve la mise en page, pas un ecran presque vide.
	for i: int in mini(2, total - 1):
		screen.call("advance")
		await get_tree().process_frame
	await _shot("histoire")
	var garde: int = 0
	while not bool(screen.call("is_finished")) and garde < 200:
		screen.call("advance")
		garde += 1
	if not bool(screen.call("is_finished")):
		_fail("la scene d histoire ne se termine jamais")
	print("[SMOKE] scene d histoire deroulee : %d repliques" % total)
	screen.queue_free()
	await get_tree().process_frame
	SceneRouter.payload = {}


## Victoire puis defaite, avec la progression reelle derriere.
func _check_end_screens() -> void:
	SaveData.reset_profile()
	RunState.mode = GameEnums.Mode.EXPLORATION
	SceneRouter.payload = {"level_id": &"lvl_01"}
	# CHANTIER P : l ecran dit ce que CHAQUE objectif rapporte. Le contenu des
	# recompenses n est pas encore ecrit : on en pose trois le temps de la
	# capture (rare, epique, legendaire, comme le veut le rang), puis on rend
	# au niveau ses recompenses d origine.
	var lv_v: LevelDef = ContentDB.levels[&"lvl_01"]
	var rec_v: Array[SpellCard] = lv_v.objective_rewards.duplicate()
	lv_v.objective_rewards = _recompenses_de_vitrine(lv_v)
	var v: PackedScene = load("res://scenes/endgame/VictoryScreen.tscn")
	var vs: Control = v.instantiate()
	add_child(vs)
	var dit_rapporte: bool = false
	for n2 in _tous_les_noeuds(vs):
		if n2 is Label and (n2 as Label).text.contains(lv_v.objective_rewards[0].display_name):
			dit_rapporte = true
	if not dit_rapporte:
		_fail("ecran de victoire : la carte du premier objectif n est pas nommee")
	if not SaveData.is_level_unlocked(&"lvl_02"):
		_fail("l ecran de victoire n a pas debloque le niveau suivant")
	# Les ETOILES sont ce que le joueur regarde en premier. Une rangee vide
	# passerait inapercue : l ecran continuerait de s afficher, et seule une
	# capture relue a l oeil le montrerait. On compte donc les pastilles.
	var etoiles: int = 0
	var barres: int = 0
	for n in _tous_les_noeuds(vs):
		if n is TextureRect and n.get_parent() is HBoxContainer:
			etoiles += 1
		elif n is ProgressBar:
			barres += 1
	var attendu: int = ContentDB.levels[&"lvl_01"].objectives.size()
	if etoiles != attendu:
		_fail("ecran de victoire : %d pastilles d objectif au lieu de %d"
			% [etoiles, attendu])
	# La progression de COMPTE : la seule chose qui survit a la partie.
	if barres < 1:
		_fail("ecran de victoire : aucune barre d avancement de compte")
	await _shot("victoire")
	vs.queue_free()
	lv_v.objective_rewards = rec_v

	# Le bilan de defaite ne s affiche que s il y a des coups a montrer.
	RunState.note_damage_taken(ContentDB.enemies.get(&"gnome"))
	RunState.note_damage_taken(ContentDB.enemies.get(&"gnome"))
	RunState.note_damage_taken(ContentDB.enemies.get(&"imp_archer"))
	SceneRouter.payload = {"level_id": &"lvl_01", "waves": 3}
	var d: PackedScene = load("res://scenes/endgame/DefeatScreen.tscn")
	var ds: Control = d.instantiate()
	add_child(ds)
	await _shot("defaite")
	ds.queue_free()
	# La defaite d un MASSACRE : son level_id n est pas dans ContentDB, et sa
	# ligne de resume porte le record. REJOUER doit y ramener, pas au niveau 1.
	RunState.mode = GameEnums.Mode.MASSACRE
	SceneRouter.payload = {"level_id": MassacreMode.LEVEL_ID, "waves": 11}
	var dm: Control = d.instantiate()
	add_child(dm)
	if SaveData.massacre_best_wave() < 11:
		_fail("defaite en Massacre : record non enregistre (%d)" % SaveData.massacre_best_wave())
	await _shot("defaite_massacre")
	dm.queue_free()
	RunState.mode = GameEnums.Mode.EXPLORATION
	print("[SMOKE] ecrans de fin construits")


## Une partie INFINIE (un niveau prolonge) doit demarrer avec le deck du joueur.
## Ancien "Massacre par niveau", renomme au chantier M.
func _check_massacre_deck() -> void:
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.start_level(level, GameEnums.Mode.INFINITE)
	g.running = false
	# Le bandeau du monde s annonce a la premiere vague : on laisse le fondu se
	# faire en temps reel (la partie, elle, est arretee) pour la capture.
	var hud: Node = g.get_node_or_null("HUD")
	if hud != null and String(hud.call("world_banner_text")) != WaveBudget.world_name_for(1):
		_fail("mode infini : le bandeau n annonce pas le premier monde")
	if _visual:
		await _laisser_jouer(0.5)
		await _shot("bataille_infini_monde")
	if RunState.total_cards() < DeckRules.MIN_CARDS:
		_fail("deck Massacre trop petit en partie : %d" % RunState.total_cards())
	if RunState.hand.is_empty():
		_fail("aucune carte en main au depart en Massacre")
	# Mode infini : on joue 6 vagues, un choix de sort doit survenir toutes les 2.
	var offers: Array[int] = [0]
	g.cards_offered.connect(func(_c: Array[SpellCard]) -> void: offers[0] += 1)
	var steps: int = 0
	while RunState.wave_index < 6 and steps < 60 * 60 * 6 and not _lost:
		_autoplay_for(g)
		g.simulate(FIXED_DELTA)
		steps += 1
	if RunState.wave_index < 6:
		_fail("mode infini : seulement %d vagues en %d pas" % [RunState.wave_index, steps])
	if offers[0] < 3:
		_fail("mode infini : %d choix de sorts au lieu de 3 en 6 vagues" % offers[0])
	if g.spawner.is_finished():
		_fail("le mode infini ne doit jamais se terminer")
	g.queue_free()
	print("[SMOKE] mode infini : %d vagues, %d choix de sorts, deck de %d cartes"
		% [RunState.wave_index, offers[0], RunState.total_cards()])
	await _check_massacre_run()


## LE MASSACRE (onglet) joue pour de vrai : son niveau fabrique, le deck du
## joueur, et des monstres de PLUSIEURS mondes sur le terrain. Un pool qui
## retomberait sur celui d un seul niveau passerait tous les controles de
## construction ; seul le jeu le montre.
func _check_massacre_run() -> void:
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.start_level(MassacreMode.level_def(), GameEnums.Mode.MASSACRE)
	g.running = false
	if RunState.total_cards() < DeckRules.MIN_CARDS:
		_fail("Massacre : deck trop petit en partie (%d)" % RunState.total_cards())
	var membres: Dictionary = WaveSpawner.build_membership()
	var mondes: Dictionary = {}
	var capture_faite: bool = false
	var perdu: Array[bool] = [false]
	g.level_lost.connect(func() -> void: perdu[0] = true)
	var steps: int = 0
	var cible: int = WaveBudget.MINIBOSS_EVERY * 2
	# BALAYEUR : l autoplay ne frappe que ce qui approche du mage. Le Massacre
	# tire dans TOUT le bestiaire, dont des tireurs et des boss qui tiennent le
	# haut de l ecran ; un joueur les viserait, l autoplay non, et la vague ne
	# finissait jamais (vu une fois en fenetre reelle, 5 vagues en 28 800 pas).
	# Ce controle juge le MODE (il tourne, il melange les mondes), pas
	# l equilibrage : passe une minute simulee sur la meme vague, on nettoie.
	var vague_vue: int = -1
	var pas_dans_la_vague: int = 0
	var balayes: Array[String] = []
	while RunState.wave_index < cible and steps < 60 * 60 * 8 and not perdu[0]:
		if RunState.wave_index != vague_vue:
			vague_vue = RunState.wave_index
			pas_dans_la_vague = 0
		pas_dans_la_vague += 1
		if pas_dans_la_vague > 60 * 60:
			pas_dans_la_vague = 0
			for e in g.battlefield.enemies.duplicate():
				if e != null and is_instance_valid(e) and not e.is_dead():
					if e.definition != null:
						balayes.append(String(e.definition.id))
					e.take_damage(999999.0, [])
		var a_l_ecran: Dictionary = {}
		for e in g.battlefield.enemies:
			if e == null or not is_instance_valid(e) or e.definition == null:
				continue
			if membres.has(e.definition.id):
				mondes[int(membres[e.definition.id])] = true
				if e.position.y < GameConfig.MAGE_LINE_Y - 500.0:
					a_l_ecran[int(membres[e.definition.id])] = true
		# La capture quand TROIS mondes sont a l ecran en meme temps : c est ce
		# que la photo doit prouver, et a la premiere vague (6 points de budget)
		# il n y a que deux monstres, trop peu pour juger quoi que ce soit.
		if _visual and not capture_faite and a_l_ecran.size() >= 3:
			capture_faite = true
			await _shot("bataille_massacre")
		_autoplay_for(g)
		g.simulate(FIXED_DELTA)
		steps += 1
	if _visual and not capture_faite:
		await _shot("bataille_massacre")
	if RunState.wave_index < cible:
		var restants: Array[String] = []
		for e in g.battlefield.enemies:
			if e != null and is_instance_valid(e) and e.definition != null:
				restants.append("%s@%d" % [e.definition.id, int(e.position.y)])
		_fail("Massacre : seulement %d vagues en %d pas (restent : %s)"
			% [RunState.wave_index, steps, ", ".join(restants)])
	if mondes.size() < 2:
		_fail("Massacre : les monstres ne viennent que de %d monde(s)" % mondes.size())
	if g.spawner.is_finished():
		_fail("le Massacre ne doit jamais se terminer")
	if SaveData.massacre_best_wave() < RunState.wave_index:
		_fail("Massacre : record %d sous les %d vagues jouees"
			% [SaveData.massacre_best_wave(), RunState.wave_index])
	RunState.pending_offer.clear()
	g.queue_free()
	await get_tree().process_frame
	print("[SMOKE] Massacre : %d vagues, monstres de %d mondes, record %d, balayes : %s"
		% [RunState.wave_index, mondes.size(), SaveData.massacre_best_wave(),
		", ".join(balayes) if not balayes.is_empty() else "aucun"])


## L onglet MASSACRE ouvert : record, regle, deck utilise, JOUER actif.
func _check_massacre_tab(menu: Control) -> void:
	var panneau: MassacrePanel = null
	for p in menu.get_node("%Content").get_children():
		if p is MassacrePanel:
			panneau = p
	if panneau == null:
		_fail("l onglet Massacre est introuvable")
		return
	var avant: Dictionary = SaveData.to_dictionary()
	# Un niveau gagne ne suffit plus : le Massacre s ouvre a la FIN de la
	# campagne (retouche du 30/09). L onglet ferme doit le dire, dans le lieu.
	SaveData.record_victory(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION, {}, 6)
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	menu.select_tab(menu.get("TABS").find("MASSACRE"))
	panneau.refresh()
	if panneau.can_play():
		_fail("onglet Massacre : JOUER actif apres un seul niveau gagne")
	if not panneau.lock_shown():
		_fail("onglet Massacre ferme : le bandeau du verrou n est pas affiche")
	await _shot("massacre_ferme")
	for lv: LevelDef in ContentDB.levels.values():
		SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {}, 6)
	SaveData.record_run_waves(MassacreMode.LEVEL_ID, GameEnums.Mode.MASSACRE, 14)
	panneau.refresh()
	if not panneau.can_play():
		_fail("onglet Massacre : JOUER coupe malgre la campagne finie et un deck valide (%s)"
			% MassacrePanel.block_reason())
	if panneau.lock_shown():
		_fail("onglet Massacre ouvert : le bandeau du verrou est reste")
	await _shot("massacre_ouvert")
	SaveData.load_from_dictionary(avant)
	panneau.refresh()
	menu.select_tab(menu.HOME_TAB)


## Verifie qu un mur devie reellement les monstres puis libere le passage.
func _check_wall_pathfinding() -> void:
	var grid := NavGrid.new()
	var depart := Vector2(540.0, 300.0)
	if grid.find_path(depart).is_empty():
		_fail("aucun chemin sans obstacle")
		return

	var cells: Array[Vector2i] = grid.block_rect(Vector2(540.0, 800.0), 240.0, 60.0)
	var devie: Array[Vector2] = grid.find_path(depart)
	if devie.is_empty():
		_fail("le mur bloque totalement alors qu il laisse les bords libres")
		return
	var ecart: float = 0.0
	for p in devie:
		ecart = maxf(ecart, absf(p.x - depart.x))
	if ecart <= NavGrid.CELL_SIZE:
		_fail("le monstre ne contourne pas le mur")
		return

	grid.unblock_cells(cells)
	if grid.blocked_count() != 0:
		_fail("cellules non liberees apres expiration du mur")
		return
	print("[SMOKE] mur : contournement de %.0f px puis liberation" % ecart)


## Verifie que 0 PV mene bien a la defaite via le drain post-mortem.
func _check_defeat_path() -> void:
	SpeedGauge.reset()
	var died: Array[bool] = [false]
	var cb := func() -> void: died[0] = true
	SpeedGauge.died.connect(cb)
	# Un seul coup de la valeur des PV : compter des coups de 1 dependait de
	# l ancienne echelle (8 PV) et cassait des que le maximum changeait. Depuis
	# le 26 septembre la reserve EST la vitesse : on la vide d un coup.
	SpeedGauge.take_hit(SpeedGauge.max_reserve())
	var guard: int = 0
	while not died[0] and guard < 6000:
		SpeedGauge.tick(FIXED_DELTA)
		guard += 1
	SpeedGauge.died.disconnect(cb)
	if not died[0]:
		_fail("le drain post-mortem n a jamais abouti a la defaite")
		return
	print("[SMOKE] chemin de defaite verifie")


## Le panneau de profil, ou qu il soit dans l arbre du menu. Il est pose sous un
## CALQUE de superposition (Content > calque > boite > panneau) : chercher dans
## les enfants directs de Content ne le trouve pas.
func _find_profile_panel(root: Node) -> Control:
	if root is ProfilePanel:
		return root as Control
	for c in root.get_children():
		var found: Control = _find_profile_panel(c)
		if found != null:
			return found
	return null


## Le mage et la tour doivent CHANGER quand on equipe un cosmetique. Sans cette
## verification, `equipped_cosmetic()` pourrait rendre la bonne chaine pendant
## que le combat continue d afficher le moine bleu : la seule preuve qui compte
## est que les deux fichiers de jeu lisent bien le profil.
func _check_cosmetics_in_battle() -> void:
	SaveData.grant_account_xp(SaveData.account_xp_for_level(12))
	if not SaveData.equip_cosmetic(&"rw_hat_gold"):
		_fail("le chapeau d or ne s equipe pas au niveau 12")
	if not SaveData.equip_cosmetic(&"rw_tower_ember"):
		_fail("la tour de braise ne s equipe pas au niveau 12")

	# Le mage : la feuille lue doit etre celle du chapeau equipe, et porter ses
	# trois animations — une feuille vide donnerait un mage invisible en combat.
	if UiTheme.mage_sheet_key() != "monk_hat_gold":
		_fail("le mage ne lit pas le chapeau equipe (%s)" % UiTheme.mage_sheet_key())
	var sf: SpriteFrames = UiTheme.mage_frames()
	if sf == null:
		_fail("le mage equipe n a aucune feuille d animation")
	else:
		for anim in ["idle", "walk", "cast"]:
			if not sf.has_animation(anim) or sf.get_frame_count(anim) == 0:
				_fail("le mage equipe n a pas d animation %s" % anim)

	# La tour : une texture differente de celle d origine, pas un simple repli.
	var tour: Texture2D = UiTheme.tower_texture()
	var origine: Texture2D = SheetLib.texture("res://assets/terrain/tower_blue.png")
	if tour == null or tour == origine:
		_fail("la tour equipee ne change pas de texture")

	# Et une capture du combat ainsi equipe : c est la seule facon de voir que le
	# mage et la tour ont vraiment change de couleur a l ecran.
	if _visual:
		var packed: PackedScene = load("res://scenes/game/Game.tscn")
		var g: GameController = packed.instantiate()
		g.headless_mode = true
		add_child(g)
		g.running = false
		g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
		for _i in 40:
			g.simulate(FIXED_DELTA)
		await _shot("bataille_cosmetiques")
		g.queue_free()
	SaveData.reset_profile()
	print("[SMOKE] cosmetiques : mage et tour equipes")


## Tous les descendants d un noeud, a plat. Sert aux controles d ecran qui
## comptent des elements sans connaitre la structure exacte du panneau.
func _tous_les_noeuds(racine: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in racine.get_children():
		out.append(c)
		out.append_array(_tous_les_noeuds(c))
	return out


# --- VITRINES DU CHANTIER P : progression des cartes et passifs ------------

## Trois sorts pour les trois objectifs d un niveau, de la rarete de leur rang
## (LevelDef.REWARD_RARITY_BY_RANK), hors du deck. Seulement pour les captures :
## le vrai contenu viendra du chantier suivant.
func _recompenses_de_vitrine(level: LevelDef) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	for i in level.objectives.size():
		var voulue: int = LevelDef.reward_rarity_for_rank(LevelDef.objective_rank(i))
		for id in ids:
			var c: SpellCard = ContentDB.cards[id]
			if c.is_passive or c.rarity != voulue or out.has(c) \
					or level.exploration_deck.has(c):
				continue
			out.append(c)
			break
	return out


## La fiche de campagne nomme la carte de chaque objectif.
func _vitrine_recompenses_campagne(campagne: CampaignPanel) -> void:
	var level: LevelDef = ContentDB.levels.get(SaveData.current_level())
	if level == null:
		return
	var avant: Array[SpellCard] = level.objective_rewards.duplicate()
	var profil: Dictionary = SaveData.to_dictionary()
	level.objective_rewards = _recompenses_de_vitrine(level)
	# Le premier objectif est acquis : sa ligne doit dire "a prendre en combat".
	if not level.objectives.is_empty():
		SaveData.record_victory(level, GameEnums.Mode.EXPLORATION,
			{level.objectives[0].id: true}, 1)
	campagne.open_level(level.id)
	# La fiche precedente attend sa liberation en fin d image : sans cette
	# attente, ses lignes seraient comptees avec celles de la fiche affichee.
	await get_tree().process_frame
	var lignes: int = 0
	for n in _tous_les_noeuds(campagne):
		if n is Label and (n as Label).text.contains("rapporte :"):
			lignes += 1
	if lignes != level.objectives.size():
		_fail("fiche de campagne : %d lignes de recompense pour %d objectifs"
			% [lignes, level.objectives.size()])
	await _shot("campagne_recompenses")
	level.objective_rewards = avant
	SaveData.load_from_dictionary(profil)
	campagne.open_level(level.id)


## Le grimoire ne montre aucune carte INVISIBLE, et une fiche OBTENABLE dit ou
## l obtenir.
func _vitrine_grimoire_visibilite(grimoire: GalleryPanel) -> void:
	grimoire.close_detail()
	grimoire.show_section(GalleryPanel.Section.SPELLS)
	var liste: Array = grimoire.entries()
	var grisee: int = -1
	for i in liste.size():
		var c: SpellCard = liste[i]
		var etat: int = SaveData.card_visibility(c.id)
		if etat == SaveData.CARD_HIDDEN:
			_fail("le grimoire montre %s, qui devrait etre invisible" % c.id)
		if etat == SaveData.CARD_OBTAINABLE and grisee < 0:
			grisee = i
	if grisee < 0:
		_fail("le grimoire ne montre aucune carte a obtenir apres une partie")
		return
	grimoire.open_detail(grisee)
	await _shot("livre_fiche_a_obtenir")
	grimoire.close_detail()
	# BESTIAIRE EN TROIS ETATS (retouche du 30/09) : aucun monstre d un niveau
	# pas encore atteint, et une fiche A RENCONTRER lisible.
	grimoire.show_section(GalleryPanel.Section.BEASTS)
	var betes: Array = grimoire.entries()
	var a_voir: int = -1
	for j in betes.size():
		var e: EnemyDef = betes[j]
		var etat_e: int = SaveData.enemy_visibility(e.id)
		if etat_e == SaveData.ENEMY_HIDDEN:
			_fail("le bestiaire montre %s, d un niveau pas encore atteint" % e.id)
		if etat_e == SaveData.ENEMY_REACHABLE and a_voir < 0:
			a_voir = j
	await _shot("livre_bestiaire_trois_etats")
	if a_voir >= 0:
		grimoire.open_detail(a_voir)
		await _shot("livre_fiche_a_rencontrer")
		grimoire.close_detail()
	grimoire.show_section(GalleryPanel.Section.SPELLS)


## La phrase de verrou des passifs, DANS LA VRAIE MISE EN PAGE du menu (marges,
## onglets, largeur portrait) : elle recoit au moins la largeur de son texte et
## reste dans l ecran. Le test unitaire verifie la structure ; seul le menu
## assemble dit si la bande a vraiment la place. Retouche du 30/09 : sur les
## captures, la phrase se lisait comme amputee de son debut.
func _verrou_des_passifs_en_entier(panel: DeckPanel) -> void:
	# Deux images : en headless _shot() rend la main sans attendre, et les
	# conteneurs ne placent leurs enfants qu a l image suivante.
	await get_tree().process_frame
	await get_tree().process_frame
	var verrou: Label = panel.passive_lock_label()
	if verrou == null:
		_fail("avant l acte 2, la bande des passifs n affiche pas sa phrase de verrou")
		return
	var f: Font = verrou.get_theme_font(&"font")
	var largeur: float = f.get_string_size(verrou.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		verrou.get_theme_font_size(&"font_size")).x
	var r: Rect2 = verrou.get_global_rect()
	if r.size.x < floorf(largeur):
		_fail("phrase de verrou des passifs rognee : %d px pour %d px de texte (%s)"
			% [r.size.x, largeur, verrou.text])
	if not panel.get_viewport_rect().encloses(r):
		_fail("phrase de verrou des passifs hors de l ecran : %s" % r)


## La bande des passifs de l ecran de deck : verrouillee avant l acte 2, puis
## trois emplacements equipables et le choix du passif sur la page.
func _vitrine_passifs_deck(panel: DeckPanel) -> void:
	var profil: Dictionary = SaveData.to_dictionary()
	panel.refresh()
	if SaveData.passives_unlocked():
		_fail("profil de smoke : l acte 2 ne devrait pas encore etre atteint")
	panel.open_passive_picker(0)
	if panel.picker_slot() != -1:
		_fail("avant l acte 2, les emplacements de passif ne s ouvrent pas")
	await _shot("deck_passifs_verrou")
	await _verrou_des_passifs_en_entier(panel)
	for lv: LevelDef in ContentDB.levels.values():
		if lv.allows_passives():
			SaveData.unlock_level(lv.id)
			break
	var passifs: Array[SpellCard] = []
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if c.is_passive and passifs.size() < DeckRules.MAX_PASSIVES + 1:
			passifs.append(c)
			SaveData.discover_card(c.id)
	panel.refresh()
	if not panel.equip_passive_in_slot(0, passifs[0]) \
			or not panel.equip_passive_in_slot(1, passifs[1]):
		_fail("l ecran de deck n equipe pas un passif obtenu")
	if SaveData.equipped_passive_cards().size() != 2:
		_fail("deux passifs equipes attendus, %d lus" % SaveData.equipped_passive_cards().size())
	if not panel.passive_scope_text().contains("campagne"):
		_fail("l ecran de deck ne dit pas que les passifs equipes ne valent pas en campagne")
	await _shot("deck_passifs")
	panel.open_passive_picker(2)
	if panel.picker_slot() != 2:
		_fail("le choix du troisieme emplacement ne s ouvre pas")
	await _shot("deck_passifs_choix")
	panel.close_passive_picker()
	SaveData.load_from_dictionary(profil)
	panel.refresh()

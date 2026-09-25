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
	await _check_end_screens()
	await _check_cosmetics_in_battle()
	_check_massacre_deck()

	# 4) La defaite doit aussi fonctionner.
	_check_defeat_path()



## Vitrine : un exemplaire de chaque monstre en grille, pour juger sprites et tailles.
func _showcase_enemies() -> void:
	if not _visual:
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("grass")
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	var cols: int = 3
	var i: int = 0
	for id in ids:
		var def: EnemyDef = ContentDB.enemies[id]
		var x: float = 200.0 + (i % cols) * 340.0
		var y: float = 230.0 + int(i / cols) * 180.0
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
	await _shot("vitrine_monstres")
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
	ContentDB.discover_starters()

	# La campagne s ouvre sur le premier niveau, et lui seul.
	var ouverts: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		if SaveData.is_level_unlocked(lv.id):
			ouverts += 1
	if ouverts != 1:
		_fail("premier lancement : %d niveaux ouverts au lieu d un seul" % ouverts)
	if not SaveData.is_level_unlocked(&"lvl_01"):
		_fail("premier lancement : le niveau 1 n est pas ouvert")

	# Le mode sans fin est une recompense, pas une porte ouverte.
	if SaveData.campaign_cleared():
		_fail("premier lancement : le Massacre est deja ouvert")

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
	# Une capture de l accueil tel qu on le decouvre.
	menu.select_tab(0)
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
		# Le detail d un niveau : c est l ecran que le testeur voulait conserver,
		# et il n est atteignable que par un toucher sur un point de la carte.
		campagne.open_level(SaveData.current_level())
		await _shot("campagne_detail")
		campagne.back_to_map()

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
		# Une fiche de MONSTRE aussi : elle est bien plus longue (competences),
		# c est elle qui deborde si la mise en page est trop serree.
		grimoire.show_section(GalleryPanel.Section.BEASTS)
		grimoire.open_detail(1)
		await _shot("livre_fiche_monstre")
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
		# Tourner une page de collection : les fleches du pied de page doivent
		# marcher ici comme dans le grimoire.
		deck_ecran.turn_page(1)
		await _shot("deck_page2")
		deck_ecran.delete_current_deck()
		await _shot("deck_plein")

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


## Pre-cast : un second sort doit pouvoir etre prepare pendant le chargement du
## premier, et un troisieme remplacer celui qui attendait.
## L ecran d AMELIORATION, pose sur un vrai combat.
##
## Pourquoi il faut le forcer : en headless `GameController` tranche tout de
## suite (`pick_upgrade(0)`) pour ne pas bloquer le banc, donc le panneau ne
## s affiche JAMAIS dans une partie de test. Sans ce controle, le seul regard
## porte sur lui venait de `tools/make_upgrades`, qui le pose sur un fond neutre
## — on ne pouvait donc pas juger ce que le joueur voit reellement : un voile
## semi-transparent par-dessus des monstres qui descendent.
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
	var voies: Array = RunState.upgrade_paths_for(carte)
	if voies.size() != 3:
		_fail("ecran d amelioration : %d voies au lieu de 3" % voies.size())
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


## Vaincre un mini-boss ou un boss doit proposer une carte : c est la recompense
## promise par le cahier des charges, et elle ne passait par aucun code.
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
		if RunState.pending_offer.is_empty():
			_fail("vaincre un boss n offre aucune carte")
		else:
			print("[SMOKE] recompense de boss : %d cartes proposees" % RunState.pending_offer.size())
		RunState.pending_offer.clear()
	g.queue_free()
	await get_tree().process_frame


## L ecran de briefing se construit pour les deux modes et mene bien a la partie.
func _check_briefing() -> void:
	var packed: PackedScene = load("res://scenes/loading/LoadingScreen.tscn")
	if packed == null:
		_fail("LoadingScreen.tscn introuvable")
		return
	for mode in [GameEnums.Mode.EXPLORATION, GameEnums.Mode.MASSACRE]:
		SceneRouter.payload = {"level_id": &"lvl_01", "mode": mode}
		var screen: Control = packed.instantiate()
		add_child(screen)
		await get_tree().process_frame
		# Le briefing doit montrer QUELQUE CHOSE : un ecran vide ne sert a rien.
		var menaces: VBoxContainer = screen.get_node_or_null("%Waves")
		if menaces == null or menaces.get_child_count() == 0:
			_fail("le briefing n affiche aucune menace (mode %d)" % mode)
		if mode == GameEnums.Mode.EXPLORATION:
			await _shot("briefing")
		screen.queue_free()
		await get_tree().process_frame
	# La route du menu passe bien par le briefing, pas directement par la partie.
	if SceneRouter.LOADING == SceneRouter.GAME:
		_fail("la route de briefing pointe sur la partie")
	print("[SMOKE] briefing construit pour les deux modes")


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
	ContentDB.discover_starters()
	RunState.mode = GameEnums.Mode.EXPLORATION
	SceneRouter.payload = {"level_id": &"lvl_01"}
	var v: PackedScene = load("res://scenes/endgame/VictoryScreen.tscn")
	var vs: Control = v.instantiate()
	add_child(vs)
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
	print("[SMOKE] ecrans de fin construits")


## Une partie en Massacre doit demarrer avec le deck du joueur.
func _check_massacre_deck() -> void:
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.start_level(level, GameEnums.Mode.MASSACRE)
	g.running = false
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
	# l ancienne echelle (8 PV) et cassait des que MAGE_MAX_HP changeait.
	SpeedGauge.take_hit(GameConfig.MAGE_MAX_HP)
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

extends TestCase
## CHANTIER W8 — la montee de niveau et la maturation des cartes.
##
##   - BRULER : la carte brulee se VISE (meme geste que la main), la partie est en
##     pause tant qu elle attend ; un passif ne se brule pas (l offre reste ouverte).
##   - MEDITER : +1 XP de carte a chaque carte distincte de la main, sans compter
##     comme un lancer pour les objectifs ; une XP peut ouvrir une maturation, et
##     deux cartes qui franchissent leur palier ensemble murissent l une apres
##     l autre.
##   - ECHANGE DE PASSIF : panneau en pause, chaque carte liee a SON emplacement
##     (le rail, trie par seuil, passait un indice d ecran a swap_passive).
##   - MATURATION : plusieurs paliers, borne par le pool, cumul lisible, icone du
##     sort en tete de l ecran.
##   - RAIL : l icone du passif dans sa pastille.
##
## Aucune valeur de reglage n est ecrite ici : tout se lit dans GameConfig.

func get_suite_name() -> String:
	return "level_up_w8"


func run() -> void:
	_test_un_passif_ne_se_brule_pas()
	_test_la_carte_brulee_se_vise_en_pause()
	_test_une_carte_sans_visee_brulee_part_tout_de_suite()
	_test_mediter_donne_une_xp_par_carte_distincte()
	_test_mediter_n_est_pas_un_lancer_pour_les_objectifs()
	_test_une_meditation_fait_murir_deux_cartes_l_une_apres_l_autre()
	_test_l_echange_de_passif_retire_le_bon_emplacement()
	_test_l_echange_de_passif_se_refuse_et_met_en_pause()
	_test_en_headless_l_echange_est_refuse_sans_bloquer()
	_test_plusieurs_paliers_bornes_par_le_pool()
	_test_le_cumul_des_voies_se_lit_par_axe()
	_test_l_ecran_de_maturation_montre_l_icone_du_sort()
	_test_le_rail_montre_l_icone_des_passifs()
	RunState.reset()
	SpeedGauge.reset()


# --- Fabriques ---

func _partie() -> GameController:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	# Le test pilote la simulation lui-meme (voir le piege « running = false »).
	g.running = false
	g.set_process(false)
	reset_gauge_with_survivable_mage()
	return g


## Un monstre IMMOBILE et solide : on mesure ce que le sort lui retire.
func _cible(id: String, hp: float = 1000.0) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = hp
	d.base_speed = 0.0
	d.power = 1
	return d


func _passifs() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return String(a.id) < String(b.id))
	return out


func _spec(key: StringName, magnitude: float = 0.0, duration: float = 0.0,
		radius: float = 0.0, params: Dictionary = {}) -> EffectSpec:
	var s := EffectSpec.new()
	s.key = key
	s.magnitude = magnitude
	s.duration = duration
	s.radius = radius
	s.params = params
	return s


func _carte(id: String, specs: Array) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = "Test " + id
	c.base_cast_time = 1.0
	c.targeting = GameEnums.Targeting.POSITION
	var typed: Array[EffectSpec] = []
	for s in specs:
		typed.append(s)
	c.effects = typed
	return c


# --- BRULER ---

func _test_un_passif_ne_se_brule_pas() -> void:
	RunState.reset()
	var p: SpellCard = _passifs()[0]
	var sort: SpellCard = ContentDB.cards.get(&"fireball")
	not_ok(RunState.can_burn(p), "un passif ne se brule pas")
	ok(RunState.can_burn(sort), "un sort se brule")
	RunState.pending_offer = [p, sort]
	eq(RunState.burn_offer(0), null, "bruler un passif est refuse")
	eq(RunState.pending_offer.size(), 2, "l offre reste ouverte : le choix n est pas perdu")
	eq(RunState.burned_card, null, "rien n attend d etre lance")
	RunState.pending_offer.clear()
	RunState.reset()


func _test_la_carte_brulee_se_vise_en_pause() -> void:
	var g: GameController = _partie()
	var boule: SpellCard = ContentDB.cards.get(&"fireball")
	ok(g.requires_aim(boule), "(la Boule de feu se vise)")
	var ici := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.25, GameConfig.MAGE_LINE_Y * 0.5)
	# Le point fixe d AVANT (centre de la moitie haute) : la cible lointaine y
	# est posee pour que l ancien comportement fasse rougir le test.
	var ancien := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y * 0.45)
	var visee: Enemy = g.battlefield.spawn_enemy(_cible("t_vise"), ici.x, 1.0, ici)
	var ailleurs: Enemy = g.battlefield.spawn_enemy(_cible("t_ailleurs"), ancien.x, 1.0, ancien)
	# Le fondu d apparition passe : avant, les monstres ne sont pas frappables.
	for i in 60:
		g.battlefield.simulate(1.0 / 60.0)
	var pv_vise: float = visee.hp
	var pv_ailleurs: float = ailleurs.hp

	RunState.pending_offer = [boule]
	eq(g.burn_card(0), boule, "la carte est brulee")
	eq(RunState.burned_card, boule, "elle attend d etre visee")
	ok(RunState.pending_offer.is_empty(), "l offre est consommee")
	feq(visee.hp, pv_vise, "rien n est parti avant la visee")
	feq(ailleurs.hp, pv_ailleurs, "et rien au point fixe d avant")
	var hud: Node = g.get_node_or_null("HUD")
	if hud != null:
		eq(hud.call("burn_tray_card"), boule, "le HUD presente la carte a glisser")

	# PAUSE : l horloge de la partie n avance pas tant que la carte attend.
	var t0: float = RunState.run_time
	g.simulate(0.5)
	feq(RunState.run_time, t0, "la partie est en pause pendant la visee")
	var main: SpellCard = RunState.hand[0] if not RunState.hand.is_empty() else null
	if main != null:
		not_ok(g.play_card(main, ici), "la main ne joue pas pendant la visee")

	not_ok(g.cast_burned(), "sans point, une carte a viser ne part pas")
	eq(RunState.burned_card, boule, "elle attend toujours")
	ok(g.cast_burned(ici), "lachee sur le terrain, elle part")
	eq(RunState.burned_card, null, "plus rien en attente")
	if hud != null:
		eq(hud.call("burn_tray_card"), null, "le plateau de visee disparait")
	# La Boule de feu pose une ZONE : elle frappe pendant que le monde avance.
	g.simulate(0.5)
	ok(RunState.run_time > t0, "la partie reprend")
	ok(visee.hp < pv_vise, "le monstre VISE est touche")
	feq(ailleurs.hp, pv_ailleurs, "le monstre loin du point vise ne l est pas")
	detach(g)
	RunState.reset()


func _test_une_carte_sans_visee_brulee_part_tout_de_suite() -> void:
	var g: GameController = _partie()
	var hate: SpellCard = ContentDB.cards.get(&"quickening")
	not_ok(g.requires_aim(hate), "(Precipitation ne se vise pas)")
	RunState.pending_offer = [hate]
	eq(g.burn_card(0), hate, "la carte est brulee")
	eq(RunState.burned_card, null, "elle n attend rien")
	eq(RunState.casts_of(hate), 1, "elle est partie tout de suite")
	not_ok(RunState.deck.has(hate) or RunState.discard.has(hate) or RunState.hand.has(hate),
		"et n entre pas dans le deck")
	detach(g)
	RunState.reset()


# --- MEDITER ---

func _test_mediter_donne_une_xp_par_carte_distincte() -> void:
	RunState.reset()
	var a: SpellCard = _carte("t_med_a", [_spec(&"damage_single", 10.0)])
	var b: SpellCard = _carte("t_med_b", [_spec(&"ground_zone", 5.0, 3.0, 120.0)])
	var p: SpellCard = _passifs()[0]
	RunState.hand = [a, a, b]
	RunState.pending_offer = [p]
	eq(RunState.meditate_offer(), 2, "deux cartes DISTINCTES meditent")
	eq(RunState.card_xp(a), GameConfig.MEDITATE_CARD_XP,
		"deux copies partagent leur XP : une seule part pour elles deux")
	eq(RunState.card_xp(b), GameConfig.MEDITATE_CARD_XP, "l autre carte gagne la sienne")
	ok(RunState.pending_offer.is_empty(), "l offre est consommee : la partie reprend")
	eq(RunState.total_cards(), 3, "aucune carte n entre dans le deck")
	ok(RunState.upgrade_progress(a) > 0.0, "le lisere de la carte avance")
	ok(DeckBrowser.maturation_text(a).contains("meditation"),
		"l onglet DECK de la pause montre l XP meditee (%s)" % DeckBrowser.maturation_text(a))
	eq(RunState.meditate_offer(), 0, "sans offre, rien a mediter")
	RunState.reset()


func _test_mediter_n_est_pas_un_lancer_pour_les_objectifs() -> void:
	RunState.reset()
	var a: SpellCard = _carte("t_med_obj", [_spec(&"damage_single", 10.0)])
	RunState.hand = [a]
	RunState.pending_offer = [a]
	RunState.meditate_offer()
	eq(RunState.casts_of(a), 0, "une meditation n est pas un lancer")
	eq(RunState.max_same_card_casts(), 0, "l objectif « meme sort N fois » n avance pas")
	eq(RunState.distinct_cards_cast(), 0, "ni « N sorts differents »")
	RunState.reset()


func _test_une_meditation_fait_murir_deux_cartes_l_une_apres_l_autre() -> void:
	RunState.reset()
	RunState.set_seed(808)
	var a: SpellCard = _carte("t_mur_a", [_spec(&"ground_zone", 6.0, 3.0, 140.0)])
	var b: SpellCard = _carte("t_mur_b", [_spec(&"ground_zone", 6.0, 3.0, 140.0)])
	RunState.hand = [a, b]
	# Les deux a une XP du palier : la meditation les y porte ENSEMBLE.
	for c in [a, b]:
		RunState.casts_by_card[c.id] = RunState.next_upgrade_at(c) - GameConfig.MEDITATE_CARD_XP
	ok(RunState.pending_upgrade_card == null, "(rien avant la meditation)")
	RunState.pending_offer = [a]
	RunState.meditate_offer()
	eq(RunState.pending_upgrade_card, a, "la premiere carte ouvre son ecran")
	RunState.pick_upgrade(0)
	eq(RunState.pending_upgrade_card, b,
		"la seconde ouvre le sien des que le premier se ferme, sans attendre un lancer")
	RunState.decline_upgrade()
	eq(RunState.pending_upgrade_card, null, "puis plus rien")
	RunState.reset()


# --- ECHANGE DE PASSIF ---

## Trois passifs equipes dans un ordre d emplacements DIFFERENT de l ordre des
## seuils : c est la donnee qui departage l ancien defaut (indice d ecran trie)
## et la regle (indice d emplacement).
func _equipe_en_desordre() -> Array[SpellCard]:
	var tous: Array[SpellCard] = _passifs()
	tous.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return a.speed_threshold < b.speed_threshold)
	# haut, bas, milieu : trie par seuil, l emplacement 0 devient le rang 2.
	var choisis: Array[SpellCard] = [tous[tous.size() - 1], tous[0], tous[tous.size() / 2]]
	for c in choisis:
		RunState.equip_passive(c)
	return choisis


func _nouveau_passif(deja: Array[SpellCard]) -> SpellCard:
	for c in _passifs():
		if not deja.has(c):
			return c
	return null


func _test_l_echange_de_passif_retire_le_bon_emplacement() -> void:
	var g: GameController = _partie()
	g.headless_mode = false
	var equipes: Array[SpellCard] = _equipe_en_desordre()
	eq(RunState.equipped_passives.size(), GameConfig.PASSIVE_SLOTS, "(trois equipes)")
	var tries: Array[SpellCard] = equipes.duplicate()
	tries.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return a.speed_threshold < b.speed_threshold)
	ok(tries[0] != equipes[0], "(l ordre des seuils differe de l ordre des emplacements)")
	var neuf: SpellCard = _nouveau_passif(equipes)
	RunState.gain_passive(neuf)
	eq(RunState.pending_passive, neuf, "le quatrieme attend")
	var panel: PassiveSwapPanel = g.get("_passive_swap_panel")
	ok(panel != null and panel.visible, "le panneau d echange s ouvre")
	if panel == null:
		detach(g)
		return
	eq(panel.slot_cards(), equipes, "le panneau montre les trois cartes, par emplacement")
	# On retire le passif au seuil le PLUS BAS, qui est a l emplacement 1 : l ancien
	# rail (trie) l affichait en position 0, et passait 0 a swap_passive.
	var cible: SpellCard = tries[0]
	var slot: int = panel.slot_cards().find(cible)
	panel.press_slot(slot)
	eq(RunState.pending_passive, null, "l echange est fait")
	not_ok(RunState.equipped_passives.has(cible), "le passif touche est retire")
	ok(RunState.equipped_passives.has(neuf), "le nouveau est equipe")
	for c in equipes:
		if c != cible:
			ok(RunState.equipped_passives.has(c), "%s, non touche, reste equipe" % c.id)
	not_ok(panel.visible, "le panneau se ferme")
	detach(g)
	RunState.reset()


func _test_l_echange_de_passif_se_refuse_et_met_en_pause() -> void:
	var g: GameController = _partie()
	g.headless_mode = false
	var equipes: Array[SpellCard] = _equipe_en_desordre()
	var neuf: SpellCard = _nouveau_passif(equipes)
	RunState.gain_passive(neuf)
	var t0: float = RunState.run_time
	g.simulate(0.5)
	feq(RunState.run_time, t0, "la partie est en pause pendant l echange")
	var panel: PassiveSwapPanel = g.get("_passive_swap_panel")
	if panel != null:
		var refus: Button = panel.find_child("Refuser", true, false) as Button
		ok(refus != null, "le panneau a un bouton REFUSER")
		if refus != null:
			refus.pressed.emit()
	eq(RunState.pending_passive, null, "refuser vide l attente")
	eq(RunState.equipped_passives, equipes, "les trois passifs restent, a leur place")
	g.simulate(0.5)
	ok(RunState.run_time > t0, "la partie reprend")
	detach(g)
	RunState.reset()


## Le banc et les tests jouent sans doigt : l echange doit se trancher seul, sinon
## la partie resterait en pause pour toujours (piege deja vu avec l amelioration).
func _test_en_headless_l_echange_est_refuse_sans_bloquer() -> void:
	var g: GameController = _partie()
	var equipes: Array[SpellCard] = _equipe_en_desordre()
	RunState.gain_passive(_nouveau_passif(equipes))
	eq(RunState.pending_passive, null, "en headless, l echange est refuse tout de suite")
	eq(RunState.equipped_passives, equipes, "les trois passifs restent")
	detach(g)
	RunState.reset()


# --- MATURATION ---

func _test_plusieurs_paliers_bornes_par_le_pool() -> void:
	RunState.reset()
	ok(GameConfig.CARD_UPGRADE_TIERS > 2, "un sort murit plus de deux fois")
	var riviere: SpellCard = ContentDB.cards.get(&"terrain_river")
	var boule: SpellCard = ContentDB.cards.get(&"fireball")
	for c: SpellCard in [riviere, boule]:
		if c == null:
			continue
		eq(RunState.upgrade_tiers_for(c),
			mini(GameConfig.CARD_UPGRADE_TIERS, RunState.upgrade_pool_for(c).size()),
			"%s : autant de maturations que de paliers, jamais plus que de voies" % c.id)
	# Un sort qui a pris TOUTES ses maturations a un lisere plein, et ne
	# redemande plus rien, meme tres au-dela du dernier palier.
	var c2: SpellCard = _carte("t_tiers", [_spec(&"ground_zone", 6.0, 3.0, 140.0)])
	var n: int = RunState.upgrade_tiers_for(c2)
	var prises: Array = []
	for i in n:
		prises.append(&"none")
	RunState.upgrades_taken[c2.id] = prises
	RunState.casts_by_card[c2.id] = RunState.upgrade_threshold(n) * 2
	RunState.note_cast(c2)
	eq(RunState.pending_upgrade_card, null, "apres la derniere maturation, plus d ecran")
	feq(RunState.upgrade_progress(c2), 1.0, "et le lisere est plein")
	RunState.reset()


func _test_le_cumul_des_voies_se_lit_par_axe() -> void:
	RunState.reset()
	var c: SpellCard = _carte("t_cumul_w8", [_spec(&"damage_single", 20.0)])
	RunState.upgrades_taken[c.id] = [&"damage_strong", &"damage_light"]
	var lignes: Array[String] = RunState.upgrade_cumul_lines(c)
	var total: int = int(round((GameConfig.UPGRADE_STRONG_GAIN + GameConfig.UPGRADE_LIGHT_GAIN) * 100.0))
	ok(lignes.has("+%d %% degats" % total), "les degats s ADDITIONNENT en une ligne (%s)" % [lignes])
	var prix: int = int(round(GameConfig.UPGRADE_STRONG_COST * 100.0))
	ok(lignes.has("-%d %% vitesse de lancement" % prix), "le prix reste ecrit (%s)" % [lignes])
	eq(lignes.size(), 2, "une ligne par axe, pas une par voie")
	# Un gain et un prix qui s annulent ne s ecrivent pas.
	RunState.upgrades_taken[c.id] = [&"damage_strong", &"cast_strong"]
	for l in RunState.upgrade_cumul_lines(c):
		not_ok(l.begins_with("+0 ") or l.begins_with("-0 "), "pas de ligne nulle (%s)" % l)
	RunState.reset()


func _test_l_ecran_de_maturation_montre_l_icone_du_sort() -> void:
	RunState.reset()
	RunState.set_seed(99)
	var boule: SpellCard = ContentDB.cards.get(&"fireball")
	var hote := Control.new()
	hote.size = Vector2(GameConfig.BATTLEFIELD_WIDTH, GameConfig.BATTLEFIELD_HEIGHT)
	attach(hote)
	var panneau := CardUpgradePanel.new()
	hote.add_child(panneau)
	panneau.show_paths(boule, RunState.draw_upgrade_offer(boule))
	var portrait: Node = panneau.find_child("Portrait", true, false)
	ok(portrait != null, "l ecran de maturation montre le portrait du sort")
	if portrait != null:
		var ico: TextureRect = null
		for n in portrait.find_children("*", "TextureRect", true, false):
			if (n as TextureRect).texture == CardIcons.art(boule):
				ico = n
		ok(ico != null, "c est l ICONE de la carte (la meme qu en main)")
		ok(portrait.find_child("TypeBadge", true, false) != null, "avec son sceau de type")
	detach(hote)
	RunState.reset()


# --- RAIL ---

func _test_le_rail_montre_l_icone_des_passifs() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var hud: Node = load("res://scenes/hud/HUD.tscn").instantiate()
	attach(hud)
	var equipes: Array[SpellCard] = _equipe_en_desordre()
	hud.call("_build_passive_rail")
	var pastilles: Array = hud.get("_passive_icons")
	eq(pastilles.size(), equipes.size(), "une pastille par passif")
	for p: Control in pastilles:
		var carte: SpellCard = p.get_meta(&"carte") as SpellCard
		var ico: TextureRect = p.find_child("Icone", false, false) as TextureRect
		ok(ico != null, "%s : la pastille porte une icone" % carte.id)
		if ico != null:
			eq(ico.texture, CardIcons.art(carte), "%s : c est l icone du passif" % carte.id)
		eq(p.find_child("Initiale", false, false), null, "%s : plus d initiale" % carte.id)
		var sb: StyleBoxFlat = p.get_theme_stylebox(&"panel") as StyleBoxFlat
		ok(sb != null and sb.border_color == UiTheme.rarity_color(carte.rarity),
			"%s : le contour garde la couleur de rarete" % carte.id)
	detach(hud)
	RunState.reset()
	SpeedGauge.reset()

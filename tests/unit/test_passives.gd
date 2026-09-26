extends TestCase
## POUVOIRS PASSIFS — version 2 (demande du testeur du 21 septembre).
##
## Les passifs ne sont PLUS des cartes du deck. Ils sont EQUIPES (3 emplacements)
## et actifs des le debut du combat. Deux regles nouvelles :
##
##  1. un passif ne s applique QUE si la vitesse du jeu depasse son seuil
##     (`speed_threshold`, en pourcentage) — "fire boom n a lieu qu a partir de
##     140 % de speed" ;
##  2. un quatrieme passif ne se cumule pas : il faut en ECHANGER un des trois.
##
## Et deux regles de conception, verrouillees ici parce qu elles sont invisibles
## a la lecture du code : plus un passif est FORT, plus son seuil est haut ; plus
## il est COMPLEXE, plus il est rare.

func get_suite_name() -> String:
	return "passives"


func run() -> void:
	_test_un_passif_equipe_est_actif_des_le_debut()
	_test_le_seuil_de_vitesse_commande_l_effet()
	_test_trois_emplacements_et_echange_au_quatrieme()
	_test_les_passifs_ne_sont_plus_dans_le_deck()
	_test_reduction_du_temps_de_charge()
	_test_double_cast_ralentit_les_sorts()
	_test_le_malus_de_double_cast_se_merite()
	_test_les_passifs_repartent_a_zero_entre_les_parties()
	_test_le_catalogue_couvre_les_quatre_raretes()
	_test_seuil_croissant_avec_la_rarete()
	_test_chaque_passif_a_un_effet_connu()
	_test_has_passive_respecte_le_seuil()


func _passive(id: String, key: String, magnitude: float = 0.0,
		seuil: int = 100) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.base_cast_time = 1.0
	c.is_passive = true
	c.speed_threshold = seuil
	c.targeting = GameEnums.Targeting.NONE
	var sp := EffectSpec.new()
	sp.key = StringName(key)
	sp.magnitude = magnitude
	c.effects = [sp]
	return c


## Un passif equipe est actif SANS avoir ete joue : plus de temps d incantation,
## plus de carte a piocher. C est tout l objet du changement.
func _test_un_passif_equipe_est_actif_des_le_debut() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var p := _passive("t_haste", "passive_cast_haste", 0.3, 100)
	ok(RunState.equip_passive(p), "le passif s equipe")
	eq(RunState.equipped_passives.size(), 1, "il occupe un emplacement")
	ok(RunState.passive_active(p), "et il est deja actif, sans etre joue")


## LA regle du testeur : "le passif n a lieu qu a partir de 140 % de speed".
func _test_le_seuil_de_vitesse_commande_l_effet() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var boom := _passive("t_boom", "passive_death_blast", 5.0, 140)
	RunState.equip_passive(boom)

	SpeedGauge.set_speed_percent(139)
	not_ok(RunState.passive_active(boom), "sous le seuil : le passif dort")
	not_ok(RunState.has_passive(&"passive_death_blast"),
		"et has_passive() le voit dormir aussi")

	SpeedGauge.set_speed_percent(140)
	ok(RunState.passive_active(boom), "pile au seuil : il s allume")
	ok(RunState.has_passive(&"passive_death_blast"), "has_passive() le voit allume")

	SpeedGauge.set_speed_percent(300)
	ok(RunState.passive_active(boom), "au-dessus : il reste allume")

	# Un coup recu fait retomber la vitesse : le passif doit s eteindre avec elle.
	SpeedGauge.set_speed_percent(100)
	not_ok(RunState.passive_active(boom), "la vitesse retombe, le passif s eteint")
	RunState.reset()
	reset_gauge_at_normal_speed()


## "Si on obtient un quatrieme passif en jeu il ne peut pas se cumuler : on doit
## selectionner un des trois passifs a changer."
func _test_trois_emplacements_et_echange_au_quatrieme() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var a := _passive("t_a", "passive_cast_haste", 0.1, 110)
	var b := _passive("t_b", "passive_wave_ally", 1.0, 150)
	var c := _passive("t_c", "passive_death_blast", 5.0, 140)
	var d := _passive("t_d", "passive_double_cast", 1.0, 200)
	ok(RunState.equip_passive(a), "premier emplacement")
	ok(RunState.equip_passive(b), "deuxieme emplacement")
	ok(RunState.equip_passive(c), "troisieme emplacement")
	eq(RunState.equipped_passives.size(), GameConfig.PASSIVE_SLOTS, "trois emplacements pleins")

	# Le quatrieme ne rentre PAS tout seul : c est le coeur de la demande.
	not_ok(RunState.equip_passive(d), "le quatrieme ne se cumule pas")
	eq(RunState.equipped_passives.size(), GameConfig.PASSIVE_SLOTS, "toujours trois")
	not_ok(RunState.equipped_passives.has(d), "et le quatrieme n est pas entre en douce")

	# Il faut designer celui qu on remplace.
	ok(RunState.swap_passive(1, d), "l echange a l emplacement 1 reussit")
	eq(RunState.equipped_passives.size(), GameConfig.PASSIVE_SLOTS, "toujours trois apres echange")
	eq(RunState.equipped_passives[1].id, d.id, "le nouveau a pris la place designee")
	not_ok(RunState.equipped_passives.has(b), "l ancien a bien quitte la barre")
	ok(RunState.equipped_passives.has(a) and RunState.equipped_passives.has(c),
		"les deux autres sont intacts")

	# Un index hors bornes ne doit rien casser ni rien ajouter.
	not_ok(RunState.swap_passive(9, _passive("t_e", "passive_cast_haste", 0.1, 110)),
		"un index hors bornes est refuse")
	eq(RunState.equipped_passives.size(), GameConfig.PASSIVE_SLOTS, "et n ajoute rien")

	# Le meme passif deux fois n a aucun sens : il occuperait un emplacement pour rien.
	not_ok(RunState.equip_passive(a), "un passif deja equipe ne se re-equipe pas")
	RunState.reset()


## Les passifs ne sont PLUS melanges au deck : ni dans le deck pre-etabli du
## niveau, ni dans le deck du joueur, ni dans les cartes qu on pioche.
func _test_les_passifs_ne_sont_plus_dans_le_deck() -> void:
	# with_passives() a disparu : la laisser aurait garde un chemin par lequel un
	# passif retombe dans la pioche.
	# DeckRules est une classe statique : has_method() n y est pas appelable. On
	# lit donc la SOURCE — c est la seule facon d affirmer qu un chemin a disparu.
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/deck_rules.gd")
	not_ok(src.contains("static func with_passives"),
		"DeckRules.with_passives() n existe plus")

	var niveau: LevelDef = ContentDB.levels.get(&"lvl_01")
	if niveau != null:
		for c: SpellCard in niveau.exploration_deck:
			if c != null:
				not_ok(c.is_passive, "aucun passif dans le deck du niveau 1")

	for c2: SpellCard in DeckRules.resolve(DeckRules.default_deck_ids()):
		not_ok(c2.is_passive, "aucun passif dans le deck de depart par defaut")


## Le passif de celerite retire un temps fixe a chaque incantation — mais
## seulement au-dessus de son seuil.
func _test_reduction_du_temps_de_charge() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var c := SpellCard.new()
	c.id = &"t_spell"
	c.base_cast_time = 2.0
	var sans: float = RunState.effective_cast_time(c)
	RunState.equip_passive(_passive("t_haste", "passive_cast_haste", 0.3, 110))
	feq(RunState.effective_cast_time(c), sans, "a 100 %, le passif dort encore")

	SpeedGauge.set_speed_percent(110)
	var sans110: float = SpeedGauge.effective_cast_time(2.0)
	feq(RunState.effective_cast_time(c), SpeedGauge.effective_cast_time(2.0 - 0.3),
		"au seuil, le passif retire 0,3 s au temps de base")
	ok(RunState.effective_cast_time(c) < sans110, "et le sort part plus vite")

	# Il ne peut pas rendre un sort instantane : il ne resterait rien a lire.
	var court := SpellCard.new()
	court.id = &"t_court"
	court.base_cast_time = 0.2
	ok(RunState.effective_cast_time(court) >= 0.1 / 5.0, "un sort tres court reste lisible")
	RunState.reset()
	reset_gauge_at_normal_speed()


## Double cast : deux sorts a la fois, mais chacun 50 % plus lent.
func _test_double_cast_ralentit_les_sorts() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var dual := _passive("t_double", "passive_double_cast", 1.0, 200)
	RunState.equip_passive(dual)
	eq(RunState.cast_slots(), 1, "sous le seuil, la seconde place reste fermee")

	SpeedGauge.set_speed_percent(200)
	eq(RunState.cast_slots(), 2, "au seuil, deux sorts peuvent charger ensemble")
	var c := SpellCard.new()
	c.id = &"t_spell"
	c.base_cast_time = 2.0
	var seul: float = RunState.effective_cast_time(c)
	RunState.set_casting_count(2)
	feq(RunState.effective_cast_time(c), seul * 1.5, "mais chacun prend 50 % de plus")
	RunState.set_casting_count(1)
	RunState.reset()
	reset_gauge_at_normal_speed()


## Le malus de Double incantation ne se paie QUE si la seconde place sert.
## Mesure au banc : applique en permanence, le mage passait 85 % du temps a incanter.
func _test_le_malus_de_double_cast_se_merite() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	SpeedGauge.set_speed_percent(200)
	var c := SpellCard.new()
	c.id = &"t_spell"
	c.base_cast_time = 2.0
	var sans: float = RunState.effective_cast_time(c)
	RunState.equip_passive(_passive("t_double", "passive_double_cast", 1.0, 200))
	eq(RunState.cast_slots(), 2, "la seconde place est ouverte")
	feq(RunState.effective_cast_time(c), sans, "un sort seul garde sa vitesse normale")
	RunState.set_casting_count(2)
	feq(RunState.effective_cast_time(c), sans * 1.5, "deux sorts coutent 50 % de plus chacun")
	RunState.set_casting_count(1)
	feq(RunState.effective_cast_time(c), sans, "retour a la normale ensuite")
	RunState.reset()
	reset_gauge_at_normal_speed()


func _test_les_passifs_repartent_a_zero_entre_les_parties() -> void:
	RunState.reset()
	RunState.equip_passive(_passive("t_haste", "passive_cast_haste", 0.3, 100))
	ok(RunState.equipped_passives.size() > 0, "un passif est equipe")
	RunState.reset()
	eq(RunState.equipped_passives.size(), 0, "une nouvelle partie repart sans passif")
	eq(RunState.cast_slots(), 1, "et avec une seule place d incantation")


func _catalogue() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			out.append(c)
	return out


## "Il faut creer une plus grande diversite de passifs avec des raretes comme les
## cartes de sorts." Trois passifs, tous rares ou epiques, ne font pas une
## collection : il faut du choix a chaque rarete.
func _test_le_catalogue_couvre_les_quatre_raretes() -> void:
	var tous: Array[SpellCard] = _catalogue()
	ok(tous.size() >= 12, "au moins 12 passifs au catalogue (il y en a %d)" % tous.size())
	for r: GameEnums.Rarity in [GameEnums.Rarity.COMMON, GameEnums.Rarity.RARE,
			GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY]:
		var n: int = 0
		for c in tous:
			if c.rarity == r:
				n += 1
		ok(n >= 2, "au moins 2 passifs de rarete %d (il y en a %d)" % [r, n])


## "Plus le passif est fort, plus le jeu doit aller vite pour qu il soit active.
## Plus le passif est complexe, plus il est rare." Les deux echelles doivent donc
## monter ENSEMBLE : une legendaire qui s allumerait a 110 % serait un cadeau, et
## une commune a 400 % ne servirait jamais.
func _test_seuil_croissant_avec_la_rarete() -> void:
	var bornes: Dictionary = {
		GameEnums.Rarity.COMMON: [105, 135],
		GameEnums.Rarity.RARE: [136, 199],
		GameEnums.Rarity.EPIC: [200, 275],
		GameEnums.Rarity.LEGENDARY: [276, GameConfig.SPEED_MAX_PERCENT],
	}
	for c in _catalogue():
		var b: Array = bornes.get(c.rarity, [])
		if b.is_empty():
			continue
		ok(c.speed_threshold >= int(b[0]) and c.speed_threshold <= int(b[1]),
			"%s : seuil %d dans [%d, %d] pour sa rarete"
				% [c.id, c.speed_threshold, b[0], b[1]])
		# Un seuil au-dessus du maximum atteignable serait un passif mort.
		ok(c.speed_threshold <= GameConfig.SPEED_MAX_PERCENT,
			"%s : son seuil est atteignable" % c.id)


## Un passif dont la cle n est lue nulle part ne fait RIEN : il occupe un
## emplacement et ment au joueur. L AUDIT ne peut pas l attraper (les passifs
## n ont pas de handler), donc c est ici que ca se verrouille.
func _test_chaque_passif_a_un_effet_connu() -> void:
	for c in _catalogue():
		ok(not c.effects.is_empty(), "%s a au moins un effet" % c.id)
		for spec in c.effects:
			if spec == null:
				ok(false, "%s : effet vide" % c.id)
				continue
			ok(RunState.PASSIVE_KEYS.has(spec.key),
				"%s : la cle '%s' est lue par le jeu" % [c.id, spec.key])


## has_passive() est lu par GameController et Battlefield : il doit DEJA tenir
## compte du seuil, sinon chaque appelant devrait y penser et un seul oubli
## rendrait un passif actif a 100 %.
func _test_has_passive_respecte_le_seuil() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var ally := _passive("t_ally", "passive_wave_ally", 1.0, 150)
	RunState.equip_passive(ally)
	not_ok(RunState.has_passive(&"passive_wave_ally"), "a 100 %, pas d allie")
	SpeedGauge.set_speed_percent(150)
	ok(RunState.has_passive(&"passive_wave_ally"), "a 150 %, l allie arrive")
	RunState.reset()
	reset_gauge_at_normal_speed()

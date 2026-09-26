extends TestCase
## ELEMENTS ET RESISTANCES — la table qui remplace l immunite binaire.
##
## Avant, un monstre etait immunise ou ne l etait pas : deux etats, aucune
## nuance. Un golem de pierre et une gelee encaissaient le feu exactement pareil,
## donc changer de deck ne servait a rien. Les resistances en POURCENTAGE
## rendent chaque element bon quelque part et mauvais ailleurs, et c est ce
## qui donne une raison de composer son deck contre un niveau.
##
## Les tests portent sur la REGLE, pas sur les valeurs de contenu (un reglage
## d equilibrage ne doit pas les casser), sauf trois ecarts de design que le
## testeur a explicitement demandes et qui doivent rester vrais.

func get_suite_name() -> String:
	return "elements"


func _def(id: String, hp: float = 100.0) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = hp
	return d


func _enemy(def: EnemyDef) -> Enemy:
	var packed: PackedScene = load("res://scenes/game/Enemy.tscn")
	var e: Enemy = packed.instantiate()
	e.setup(def, 1.0)
	return e


## PV restants apres un sort, mesures A TRAVERS le Battlefield.
##
## On ne tape JAMAIS `Enemy.take_damage()` directement dans ces tests : la
## resistance vit dans `Battlefield._hit()`, le point de passage unique des
## degats. Un test qui court-circuite ce point mesurerait une regle que le jeu
## n applique pas — et c est exactement l erreur que ce harnais doit attraper.
## Godot 4.4 refuse de convertir un Array litteral vers un Array[DamageTag] a
## l appel : le litteral doit etre copie element par element (voir [[gotchas]]).
func _tags(src: Array) -> Array[GameEnums.DamageTag]:
	var out: Array[GameEnums.DamageTag] = []
	for t in src:
		out.append(t)
	return out


func _pv_apres(def: EnemyDef, degats: float, tags: Array[GameEnums.DamageTag]) -> float:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	reset_gauge_at_normal_speed()
	RunState.reset()
	var e: Enemy = bf.spawn_enemy(def, 1.0, 1.0, Vector2(540.0, 600.0))
	# Le fondu d apparition rend le monstre intouchable : on l epuise avant de
	# frapper, sinon le sort ne porterait jamais et le test passerait pour de
	# mauvaises raisons.
	for i in 30:
		bf.simulate(1.0 / 60.0)
	var carte := SpellCard.new()
	carte.id = &"t_elem"
	carte.tags = tags
	bf.damage_enemy(e, degats, carte)
	var pv: float = e.hp
	detach(bf)
	return pv


func run() -> void:
	_test_la_palette_couvre_les_six_elements()
	_test_resistance_moitie()
	_test_vulnerabilite_majore()
	_test_resistance_zero_est_une_immunite()
	_test_sans_entree_les_degats_passent_entiers()
	_test_le_pire_element_du_sort_gagne()
	_test_immune_tags_reste_compris()
	_test_le_ralentissement_respecte_la_resistance()
	_test_chaque_monstre_a_une_table()
	_test_chaque_carte_de_degats_porte_un_element()
	_test_les_ecarts_de_design_demandes()
	_test_la_fiche_annonce_les_resistances()
	_test_la_fiche_annonce_le_vol()
	_test_chaque_element_a_une_couleur_et_une_feuille()


## La palette doit couvrir les six ELEMENTS de degats. SLOW et SUMMON restent
## dans le meme enum mais ne sont pas des elements : ce sont des categories
## d effet (on ne resiste pas "au ralentissement" comme on resiste au feu, on y
## est insensible ou non).
func _test_la_palette_couvre_les_six_elements() -> void:
	var elems: Array = GameEnums.ELEMENTS
	eq(elems.size(), 6, "six elements de degats")
	for e in [GameEnums.DamageTag.PHYSICAL, GameEnums.DamageTag.FIRE,
			GameEnums.DamageTag.FROST, GameEnums.DamageTag.ARCANE,
			GameEnums.DamageTag.POISON, GameEnums.DamageTag.LIGHTNING]:
		ok(e in elems, "%d est un element" % e)
	not_ok(GameEnums.DamageTag.SLOW in elems, "le ralentissement n est pas un element")
	not_ok(GameEnums.DamageTag.SUMMON in elems, "l invocation n est pas un element")


func _test_resistance_moitie() -> void:
	var d := _def("resistant")
	d.resistances = {GameEnums.DamageTag.FIRE: 0.5}
	feq(d.resistance_to(GameEnums.DamageTag.FIRE), 0.5, "la table est lue")
	feq(_pv_apres(d, 40.0, _tags([GameEnums.DamageTag.FIRE])), 80.0,
		"50 pourcent de resistance = moitie des degats", 0.01)


func _test_vulnerabilite_majore() -> void:
	var d := _def("fragile")
	d.resistances = {GameEnums.DamageTag.FIRE: 1.5}
	feq(_pv_apres(d, 40.0, _tags([GameEnums.DamageTag.FIRE])), 40.0,
		"150 pourcent = degats majores de moitie", 0.01)


## Zero remplace l immunite binaire : meme resultat visible pour le joueur (rien
## ne passe), mais c est la MEME table qui l exprime, donc une seule regle a lire.
func _test_resistance_zero_est_une_immunite() -> void:
	var d := _def("immune")
	d.resistances = {GameEnums.DamageTag.FROST: 0.0}
	ok(d.is_immune_to(GameEnums.DamageTag.FROST), "zero se lit comme une immunite")
	feq(_pv_apres(d, 40.0, _tags([GameEnums.DamageTag.FROST])), 100.0,
		"un element a zero n applique aucun degat", 0.01)
	feq(_pv_apres(d, 40.0, _tags([GameEnums.DamageTag.FIRE])), 60.0,
		"un autre element passe entier", 0.01)


func _test_sans_entree_les_degats_passent_entiers() -> void:
	var d := _def("neutre")
	feq(d.resistance_to(GameEnums.DamageTag.ARCANE), 1.0,
		"pas d entree = degats entiers")
	feq(_pv_apres(d, 30.0, _tags([GameEnums.DamageTag.ARCANE])), 70.0,
		"aucune correction appliquee", 0.01)


## Un sort a plusieurs elements (le Meteore est FEU + PHYSIQUE). On prend le
## PIRE pour le joueur : sinon ajouter un second element a une carte serait un
## bonus gratuit, et toute carte finirait bi-element pour contourner les
## resistances. La ou le monstre resiste, il resiste.
func _test_le_pire_element_du_sort_gagne() -> void:
	var d := _def("mixte")
	d.resistances = {
		GameEnums.DamageTag.FIRE: 0.25,
		GameEnums.DamageTag.PHYSICAL: 1.5,
	}
	feq(d.resistance_to_tags([GameEnums.DamageTag.FIRE, GameEnums.DamageTag.PHYSICAL]),
		0.25, "le sort bi-element subit la meilleure resistance du monstre")
	feq(d.resistance_to_tags([]), 1.0, "un sort sans element passe entier")
	feq(d.resistance_to_tags([GameEnums.DamageTag.SLOW]), 1.0,
		"un tag non elementaire ne change pas les degats")


## MIGRATION : `immune_tags` reste lisible par le code ancien (sauvegardes, .tres
## non regeneres) et vaut une resistance de 0.
func _test_immune_tags_reste_compris() -> void:
	var d := _def("vieux")
	d.immune_tags = [GameEnums.DamageTag.SLOW]
	ok(d.is_immune_to(GameEnums.DamageTag.SLOW), "l ancien champ fait toujours foi")
	feq(d.resistance_to(GameEnums.DamageTag.SLOW), 0.0,
		"une immunite heritee vaut resistance 0")


## Le ralentissement passe par la MEME table : un monstre qui resiste a 50 pour
## cent au givre doit etre ralenti moitie moins, pas insensible ou insensible.
func _test_le_ralentissement_respecte_la_resistance() -> void:
	var total := _def("fige")
	total.resistances = {GameEnums.DamageTag.SLOW: 0.0}
	feq(total.slow_factor(0.5), 1.0, "resistance 0 au ralentissement = aucun effet")

	var partiel := _def("lourd")
	partiel.resistances = {GameEnums.DamageTag.SLOW: 0.5}
	# 50 pourcent de ralentissement subi a moitie = 25 pourcent : facteur 0.75.
	feq(partiel.slow_factor(0.5), 0.75,
		"un ralentissement resiste est adouci, pas annule")

	var nu := _def("ordinaire")
	feq(nu.slow_factor(0.5), 0.5, "sans entree, le ralentissement est entier")

	# Et le monstre l applique vraiment : la regle ne vit pas que dans la donnee.
	feq(_descente(total, true), _descente(_def("temoin"), false),
		"le monstre immunise avance a pleine vitesse malgre le gel", 0.5)
	var mou := _def("mou")
	mou.resistances = {GameEnums.DamageTag.SLOW: 1.0}
	ok(_descente(mou, true) < _descente(_def("temoin2"), false) - 1.0,
		"un monstre sans resistance, lui, est bien ralenti")


## Distance descendue en une seconde, gele ou non. Le calcul de vitesse vit dans
## `advance()` : le mesurer la plutot que de recopier la formule garantit que le
## test suit le code et non une copie perimee.
func _descente(def: EnemyDef, gele: bool) -> float:
	var e: Enemy = _enemy(def)
	e.position = Vector2(540.0, 100.0)
	if gele:
		e.apply_slow(0.5, 5.0)
	var depart: float = e.position.y
	for i in 60:
		e.advance(1.0 / 60.0)
	var parcouru: float = e.position.y - depart
	e.free()
	return parcouru


## CONTENU : aucun monstre ne doit rester sans table. Une table vide est un
## monstre que tous les decks traitent pareil — exactement ce qu on supprime.
func _test_chaque_monstre_a_une_table() -> void:
	for id in ContentDB.enemies.keys():
		var def: EnemyDef = ContentDB.enemies[id]
		if def == null:
			continue
		ok(not def.resistances.is_empty(),
			"%s a une table de resistances" % id)
		# Une table uniforme (tout a 1.0) ne distingue rien : autant ne rien
		# ecrire. L AUDIT du contenu exige au moins un ECART.
		var ecart: bool = false
		for t in def.resistances.keys():
			if not is_equal_approx(float(def.resistances[t]), 1.0):
				ecart = true
		ok(ecart, "%s a au moins un ecart reel (resistance ou faiblesse)" % id)


## CONTENU : toute carte qui inflige des degats porte un element. Une carte de
## degats sans element echapperait a toutes les resistances et serait la
## meilleure carte du jeu par accident.
func _test_chaque_carte_de_degats_porte_un_element() -> void:
	for id in ContentDB.cards.keys():
		var card: SpellCard = ContentDB.cards[id]
		if card == null or not _fait_des_degats(card):
			continue
		var a_un_element: bool = false
		for t in card.tags:
			if t in GameEnums.ELEMENTS:
				a_un_element = true
		ok(a_un_element, "%s inflige des degats et porte un element" % id)


func _fait_des_degats(card: SpellCard) -> bool:
	const CLES_DE_DEGATS: Array[StringName] = [
		&"damage_single", &"pierce_line", &"damage_per_enemy",
		&"meteor_storm", &"knockback",
	]
	for e in card.effects:
		if e == null:
			continue
		if e.key in CLES_DE_DEGATS:
			return true
		# Une zone ne fait des degats que si sa magnitude en fait.
		if e.key == &"ground_zone" and e.magnitude > 0.0:
			return true
	return false


## Trois ecarts de design nommes par le testeur. Ils tiennent l intention en
## place : si un reglage les inverse, la logique du bestiaire est perdue.
func _test_les_ecarts_de_design_demandes() -> void:
	var golem: EnemyDef = ContentDB.enemies.get(&"golem")
	if golem != null:
		ok(golem.resistance_to(GameEnums.DamageTag.PHYSICAL) < 1.0,
			"le golem de pierre encaisse le physique")
		ok(golem.resistance_to(GameEnums.DamageTag.ARCANE) > 1.0,
			"le golem de pierre craint l arcane")

	var jelly: EnemyDef = ContentDB.enemies.get(&"jelly")
	if jelly != null:
		ok(jelly.resistance_to(GameEnums.DamageTag.FIRE) > 1.0,
			"la gelee encaisse mal le feu")
		ok(jelly.resistance_to(GameEnums.DamageTag.POISON) < 1.0,
			"la gelee, faite de poison, s en moque")

	var priest: EnemyDef = ContentDB.enemies.get(&"ghoul_priest")
	if priest != null:
		ok(priest.resistance_to(GameEnums.DamageTag.POISON) <= 0.0,
			"un mort-vivant ignore totalement le poison")


## Le joueur doit pouvoir LIRE tout cela : une resistance invisible est une
## resistance qui n existe pas pour lui.
func _test_la_fiche_annonce_les_resistances() -> void:
	var d := _def("cobaye")
	d.resistances = {
		GameEnums.DamageTag.FIRE: 0.5,
		GameEnums.DamageTag.FROST: 1.5,
		GameEnums.DamageTag.POISON: 0.0,
	}
	var lignes: Array[String] = BestiaryLore.behaviours(d)
	ok(_contient(lignes, "feu"), "le feu resiste est nomme")
	ok(_contient(lignes, "50"), "la resistance est chiffree en pourcentage")
	ok(_contient(lignes, "givre"), "la faiblesse au givre est nommee")
	ok(_contient(lignes, "Immunise"), "une resistance a 0 se dit immunite")
	not_ok(_contient(lignes, "resistances"),
		"aucun nom de champ technique ne fuit")


## `flying` n etait traduit nulle part : le joueur posait un mur inutile sans
## comprendre pourquoi. C est la ligne la plus utile de la fiche.
func _test_la_fiche_annonce_le_vol() -> void:
	var d := _def("volant")
	d.flying = true
	ok(_contient(BestiaryLore.behaviours(d), "mur"),
		"un volant previent que les murs ne l arretent pas")

	# Une MUNITION n est pas une creature : sa fiche ne doit pas se lire comme
	# celle d un monstre a farmer.
	var p := _def("munition")
	p.projectile = true
	ok(_contient(BestiaryLore.behaviours(p), "projectile"),
		"un projectile est annonce comme tel")


## Chaque element doit avoir sa couleur et sa feuille : un element sans rendu
## retombe sur l arcane et devient invisible en jeu.
func _test_chaque_element_a_une_couleur_et_une_feuille() -> void:
	var couleurs: Array[Color] = []
	for t in GameEnums.ELEMENTS:
		var c: Color = Fx.color_for([t])
		not_ok(c in couleurs, "l element %d a sa propre couleur" % t)
		couleurs.append(c)
		ok(Fx.impact_sheet(c) != "", "l element %d a une feuille d impact" % t)
		ok(Fx.zone_sheet(c) != "", "l element %d a une feuille de zone" % t)
		ok(CardIcons.BY_TAG.has(t), "l element %d a une icone de repli" % t)


func _contient(lignes: Array[String], morceau: String) -> bool:
	for l in lignes:
		if l.to_lower().contains(morceau.to_lower()):
			return true
	return false

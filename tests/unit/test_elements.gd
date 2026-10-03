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
	_test_la_palette_couvre_les_huit_elements()
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
	_test_l_immunite_au_ralentissement_ne_protege_pas_du_givre()
	_test_l_accentuation_creuse_les_ecarts()
	_test_chaque_carte_a_un_type()
	_test_les_logos_se_distinguent_par_la_forme()
	_test_la_carte_porte_son_logo()
	_test_l_ecran_de_deck_porte_le_sceau()
	_test_chaque_sort_a_exactement_un_element()
	_test_la_regle_de_passage_des_resistances()
	_test_les_logos_dans_le_texte()
	_test_l_element_s_appelle_arcanique()


## Les HUIT elements du co-auteur (vague 8) : Feu, Eau, Nature, Vent, Foudre,
## Glace, Arcanique, Poison — dans cet ordre, qui est l ordre d affichage. SLOW
## et SUMMON restent dans le meme enum mais ne sont pas des elements : ce sont
## des categories d effet. Le physique n existe plus.
func _test_la_palette_couvre_les_huit_elements() -> void:
	var T := GameEnums.DamageTag
	var voulus: Array = [T.FIRE, T.WATER, T.NATURE, T.WIND, T.LIGHTNING, T.ICE,
		T.ARCANE, T.POISON]
	eq(GameEnums.ELEMENTS, voulus, "huit elements, dans l ordre du co-auteur")
	var noms: Array = []
	for e in voulus:
		noms.append(GameEnums.tag_name(e))
	eq(noms, ["feu", "eau", "nature", "vent", "foudre", "glace", "arcanique", "poison"],
		"chaque element a son nom joueur")
	not_ok(T.SLOW in GameEnums.ELEMENTS, "le ralentissement n est pas un element")
	not_ok(T.SUMMON in GameEnums.ELEMENTS, "l invocation n est pas un element")
	not_ok(T.has("PHYSICAL"), "le physique a disparu de l enum")
	not_ok(T.NONE in GameEnums.ELEMENTS, "NONE n est pas un element")
	# Les valeurs ENTIERES des noms survivants n ont pas bouge : un .tres ou une
	# donnee d un telephone qui les stocke garde son sens. La glace est l ancien
	# givre ; l ancien physique (0) est devenu un trou inerte.
	eq(GameEnums.tag_from_name("ICE"), 2, "la glace garde la valeur du givre")
	eq(int(T.FIRE), 1, "le feu garde sa valeur")
	eq(int(T.NONE), 0, "la valeur de l ancien physique ne designe plus aucun element")
	for e in voulus:
		eq(GameEnums.tag_from_name(GameEnums.tag_key(e)), e,
			"%s : nom et valeur font l aller-retour" % GameEnums.tag_name(e))


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
	d.resistances = {GameEnums.DamageTag.ICE: 0.0}
	ok(d.is_immune_to(GameEnums.DamageTag.ICE), "zero se lit comme une immunite")
	feq(_pv_apres(d, 40.0, _tags([GameEnums.DamageTag.ICE])), 100.0,
		"un element a zero n applique aucun degat", 0.01)
	feq(_pv_apres(d, 40.0, _tags([GameEnums.DamageTag.FIRE])), 60.0,
		"un autre element passe entier", 0.01)


func _test_sans_entree_les_degats_passent_entiers() -> void:
	var d := _def("neutre")
	feq(d.resistance_to(GameEnums.DamageTag.ARCANE), 1.0,
		"pas d entree = degats entiers")
	feq(_pv_apres(d, 30.0, _tags([GameEnums.DamageTag.ARCANE])), 70.0,
		"aucune correction appliquee", 0.01)


## Un tableau a plusieurs elements (aucune carte n en porte depuis la vague 8,
## mais un effet ancien ou un test peut en fabriquer). On prend le PIRE pour le
## joueur : sinon ajouter un second element a une carte serait un
## bonus gratuit, et toute carte finirait bi-element pour contourner les
## resistances. La ou le monstre resiste, il resiste.
func _test_le_pire_element_du_sort_gagne() -> void:
	var d := _def("mixte")
	d.resistances = {
		GameEnums.DamageTag.FIRE: 0.25,
		GameEnums.DamageTag.WIND: 1.5,
	}
	feq(d.resistance_to_tags([GameEnums.DamageTag.FIRE, GameEnums.DamageTag.WIND]),
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
		ok(card.main_element() in GameEnums.ELEMENTS,
			"%s inflige des degats et porte un element" % id)


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
		# Vague 8 : l ancienne durete (« physique ») vit dans le vent et la nature.
		ok(golem.resistance_to(GameEnums.DamageTag.NATURE) < 1.0,
			"le golem de pierre encaisse la nature")
		ok(golem.resistance_to(GameEnums.DamageTag.WIND) < 1.0,
			"le golem de pierre encaisse le vent")
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
##
## Vague 5 : la fiche ne l ECRIT plus en phrase, elle la pose en LOGO +
## pourcentage, groupee sous un mot (Immunise / Resiste / Vulnerable). On verifie
## donc les groupes que la fiche affiche, et que la phrase n est plus doublee
## dans les competences.
func _test_la_fiche_annonce_les_resistances() -> void:
	var d := _def("cobaye")
	d.resistances = {
		GameEnums.DamageTag.FIRE: 0.5,
		GameEnums.DamageTag.ICE: 1.5,
		GameEnums.DamageTag.POISON: 0.0,
		GameEnums.DamageTag.SLOW: 0.0,
	}
	var groupes: Array[Dictionary] = BestiaryLore.resistance_groups(d)
	var par_titre: Dictionary = {}
	for g in groupes:
		par_titre[str(g["title"])] = g["items"]
	eq(par_titre.keys().size(), 3, "trois groupes : immunite, resistance, faiblesse")
	ok(_a_le_tag(par_titre.get("Immunise", []), GameEnums.DamageTag.POISON),
		"une resistance a 0 se range sous Immunise")
	ok(_a_le_tag(par_titre.get("Immunise", []), GameEnums.DamageTag.SLOW),
		"l immunite au ralentissement se lit au meme endroit")
	ok(_a_le_tag(par_titre.get("Resiste", []), GameEnums.DamageTag.FIRE),
		"le feu resiste est range sous Resiste")
	ok(_a_le_tag(par_titre.get("Vulnerable", []), GameEnums.DamageTag.ICE),
		"la faiblesse au givre est rangee sous Vulnerable")
	eq(ElementIcons.percent_text(d.resistance_to(GameEnums.DamageTag.FIRE)), "-50 %",
		"la resistance est chiffree en pourcentage")
	eq(ElementIcons.percent_text(d.resistance_to(GameEnums.DamageTag.ICE)), "+50 %",
		"la faiblesse aussi")
	eq(ElementIcons.percent_text(0.0), "",
		"une immunite n a pas de chiffre : le mot du groupe la dit")
	for g in groupes:
		for item in g["items"]:
			ok(ElementIcons.texture_for_tag(int(item["tag"])) != null,
				"chaque case de resistance a son logo (%d)" % int(item["tag"]))
	# La ligne dit que la resistance vaut AUSSI pour les effets (retour du
	# co-auteur : « je ne sais pas si c est fait »). Une faiblesse, elle, ne
	# promet que des degats : elle ne renforce pas le controle.
	var T := GameEnums.DamageTag
	ok(ElementIcons.effect_text(T.ICE, 0.5).contains("degats et effets"),
		"une resistance annonce degats ET effets")
	ok(ElementIcons.effect_text(T.ICE, 0.5).contains("-50"), "chiffree")
	ok(ElementIcons.effect_text(T.ICE, 0.5).contains("Glace"), "l element est nomme a cote du logo")
	not_ok(ElementIcons.effect_text(T.FIRE, 1.5).contains("effets"),
		"une faiblesse ne promet pas d effets renforces")
	ok(ElementIcons.effect_text(T.POISON, 0.0).contains("ni degats ni effets"),
		"une immunite annonce qu aucun effet ne passe")
	ok(ElementIcons.effect_text(T.SLOW, 0.0).contains("ralenti"),
		"l immunite au ralentissement se dit en clair")
	ok(BestiaryLore.RESIST_RULE_TEXT.contains("EFFETS"), "la regle est ecrite en tete du bloc")
	_la_fiche_affiche_logos_et_regle()
	# Plus de phrase en double dans les competences : le logo l a remplacee.
	var lignes: Array[String] = BestiaryLore.behaviours(d)
	not_ok(_contient(lignes, "Resiste :"), "la phrase de resistance n est plus ecrite")
	not_ok(_contient(lignes, "resistances"), "aucun nom de champ technique ne fuit")


## La VRAIE fiche du grimoire, construite : la regle en tete, une ligne a logo
## par ecart. Sans ce test, la fiche pouvait revenir a la phrase sans que rien
## ne rougisse — c est exactement ce que le co-auteur n a pas vu a l ecran.
func _la_fiche_affiche_logos_et_regle() -> void:
	var golem: EnemyDef = ContentDB.enemies.get(&"golem")
	if golem == null:
		return
	# Un monstre JAMAIS CROISE n a qu une fiche d ombre (chantier P) : on le
	# fait rencontrer, puis on rend le profil tel qu il etait.
	var connu: bool = SaveData.is_enemy_discovered(golem.id)
	SaveData.discover_enemy(golem.id)
	var gp := GalleryPanel.new()
	gp.size = Vector2(1000, 1500)
	attach(gp)
	gp.show_section(GalleryPanel.Section.BEASTS)
	var idx: int = gp.entries().find(golem)
	ok(idx >= 0, "le golem est au bestiaire")
	gp.open_detail(idx)
	ok(gp.find_child("ResistRule", true, false) != null, "la fiche ecrit la regle des effets")
	# Vague 8 : une LIGNE de texte par groupe, logos dans la phrase
	# (« [feu] feu -30 %   [eau] eau +60 % »). Chaque ecart du golem doit y
	# figurer avec SON logo et son pourcentage.
	var texte: String = ""
	for g in BestiaryLore.resistance_groups(golem):
		var ligne: Node = gp.find_child("ResistLine_" + str(g["title"]), true, false)
		ok(ligne is RichTextLabel, "golem : le groupe %s a sa ligne a logos" % g["title"])
		if ligne is RichTextLabel:
			# Sans le « gluon » U+2060 pose apres le signe (ElementIcons.resist_bbcode).
			texte += (ligne as RichTextLabel).text.replace("\u2060", "")
	var ecarts: int = 0
	for t in golem.resistances.keys():
		var r: float = float(golem.resistances[t])
		if is_equal_approx(r, 1.0):
			continue
		ecarts += 1
		ok(texte.contains(ElementIcons.path(SpellCard.type_of_tag(int(t)))),
			"golem : l ecart %s porte son logo dans le texte" % GameEnums.tag_name(int(t)))
		ok(texte.contains(GameEnums.tag_name(int(t))),
			"golem : l ecart %s est nomme" % GameEnums.tag_name(int(t)))
		var pct: String = ElementIcons.percent_text(r).replace(" ", "\u00a0")
		ok(pct == "" or texte.contains(pct),
			"golem : l ecart %s est chiffre" % GameEnums.tag_name(int(t)))
	ok(ecarts >= 3, "le golem montre ses ecarts")
	detach(gp)
	if not connu:
		(SaveData.profile().get("discovered_enemies", []) as Array).erase(String(golem.id))


func _a_le_tag(items: Array, tag: int) -> bool:
	for it in items:
		if int(it["tag"]) == tag:
			return true
	return false


## LE DEFAUT DE DEPART DE LA VAGUE 5. Enemy.take_damage refusait TOUT degat des
## qu un tag du sort etait immunise, SLOW compris : un Champ de givre [givre,
## ralentissement] faisait 0 a Chronos, au golem, au Behemoth. Le niveau 1 porte
## deux Champs de givre et son boss est Chronos.
func _test_l_immunite_au_ralentissement_ne_protege_pas_du_givre() -> void:
	var lourd := _def("lourd")
	lourd.resistances = {GameEnums.DamageTag.SLOW: 0.0}
	feq(_pv_apres(lourd, 40.0, _tags([GameEnums.DamageTag.ICE, GameEnums.DamageTag.SLOW])),
		60.0, "immunise au RALENTISSEMENT, il encaisse le givre entier", 0.01)
	var glace := _def("glace")
	glace.resistances = {GameEnums.DamageTag.ICE: 0.0}
	feq(_pv_apres(glace, 40.0, _tags([GameEnums.DamageTag.ICE, GameEnums.DamageTag.SLOW])),
		100.0, "immunise au GIVRE, rien ne passe", 0.01)
	# Sur le contenu : chaque carte de degats du deck du niveau 1 mord sur son boss.
	var lvl: LevelDef = ContentDB.levels.get(&"lvl_01")
	if lvl == null:
		return
	var boss: EnemyDef = null
	for id in ContentDB.enemies.keys():
		var d: EnemyDef = ContentDB.enemies[id]
		if d.kind == GameEnums.EnemyKind.BOSS and _niveau_contient(lvl, d):
			boss = d
	ok(boss != null, "le niveau 1 a un boss")
	if boss == null:
		return
	ok(not _cartes_du_niveau(lvl).is_empty(), "le niveau 1 fournit un deck")
	for card in _cartes_du_niveau(lvl):
		if not _fait_des_degats(card):
			continue
		# A TRAVERS le Battlefield, comme en jeu : c est take_damage qui refusait.
		var tags: Array[GameEnums.DamageTag] = _tags(card.combat_tags())
		ok(_pv_apres(boss, 10.0, tags) < _pv_apres(boss, 0.0, tags),
			"%s mord sur %s, boss du niveau 1" % [card.id, boss.id])


func _niveau_contient(lvl: LevelDef, d: EnemyDef) -> bool:
	for w in lvl.waves:
		if w == null:
			continue
		for s in w.entries:
			if s != null and s.enemy != null and s.enemy.id == d.id:
				return true
	return false


func _cartes_du_niveau(lvl: LevelDef) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c in lvl.exploration_deck:
		if c != null:
			out.append(c)
	return out


## LA REGLE D ACCENTUATION (vague 5) : une puissance, jamais au-dela de zero ni
## du plafond, et dans le sens de l ecart. Les deux reperes du co-auteur
## (« 0,5 -> ~0,3 », « 1,2 -> ~1,6 ») sont la specification : ils sont ecrits.
func _test_l_accentuation_creuse_les_ecarts() -> void:
	feq(EnemyDef.accentuate(0.0), 0.0, "une immunite reste une immunite")
	feq(EnemyDef.accentuate(1.0), 1.0, "le neutre reste neutre")
	between(EnemyDef.accentuate(0.5), 0.25, 0.35, "resiste ~0,5 devient ~0,3")
	between(EnemyDef.accentuate(1.2), 1.5, 1.7, "vulnerable ~1,2 devient ~1,6")
	var avant: float = -1.0
	for i in range(1, 60):
		var r: float = float(i) * 0.05
		var a: float = EnemyDef.accentuate(r)
		ok(a >= avant, "l accentuation garde l ordre (%.2f)" % r)
		avant = a
		if r < 0.97:
			ok(a < r and a > 0.0, "une resistance %.2f est creusee sans devenir immunite" % r)
		elif r > 1.03:
			ok(a > r or is_equal_approx(a, EnemyDef.WEAK_CAP),
				"une faiblesse %.2f est creusee" % r)
			ok(a <= EnemyDef.WEAK_CAP, "une faiblesse ne depasse pas le plafond")
	# Le CONTENU est bien passe par la regle : ecrit sur l ancienne echelle
	# (+/- 35 %), il doit maintenant compter des ecarts au-dela.
	var creuse: bool = false
	var plafond: bool = false
	for id in ContentDB.enemies.keys():
		var d: EnemyDef = ContentDB.enemies[id]
		for t in d.resistances.keys():
			var v: float = float(d.resistances[t])
			ok(v <= EnemyDef.WEAK_CAP, "%s : aucune faiblesse au-dela du plafond" % id)
			if v > 0.0 and v < 0.5:
				creuse = true
			if is_equal_approx(v, EnemyDef.WEAK_CAP):
				plafond = true
	ok(creuse, "des resistances depassent -50 % (table accentuee et regeneree)")
	ok(plafond, "des faiblesses atteignent le plafond (table accentuee et regeneree)")
	var cam: EnemyDef = ContentDB.enemies.get(&"season_chameleon")
	if cam != null:
		ok(cam.chameleon_weak_mult > 1.5 and cam.chameleon_resist_mult < 0.5,
			"le Cameleon est accentue comme les autres tables")


## UN TYPE PAR SORT (vague 5) : aucune carte ne reste sans type ni sans logo.
func _test_chaque_carte_a_un_type() -> void:
	for id in ContentDB.cards.keys():
		var card: SpellCard = ContentDB.cards[id]
		var type: StringName = card.spell_type()
		ok(type != &"", "%s a un type" % id)
		ok(ElementIcons.texture(type) != null, "%s : le logo de son type existe (%s)" % [id, type])
		ok(ElementIcons.type_name(type) != "", "%s : son type a un nom" % id)
		# Vague 8 : le type d une carte a element EST son element — c est lui que
		# les resistances lisent, le logo ne doit pas dire autre chose.
		if card.main_element() != GameEnums.DamageTag.NONE:
			eq(type, SpellCard.type_of_tag(card.main_element()),
				"%s : son type est son element" % id)
	# Une carte INVENTEE sans element ni verbe connu n a pas de type : c est ce
	# qui fait rougir le harnais au lieu d afficher un blanc sur la carte.
	var orpheline := SpellCard.new()
	var sp := EffectSpec.new()
	sp.key = &"verbe_inconnu"
	orpheline.effects.append(sp)
	eq(orpheline.spell_type(), &"", "un verbe sans famille ne recoit pas de type par defaut")


## LOGOS : un par element, par le ralentissement et par type non elementaire ;
## deux elements ne partagent JAMAIS une forme (joueurs daltoniens).
func _test_les_logos_se_distinguent_par_la_forme() -> void:
	var formes: Dictionary = {}
	var cles: Array[StringName] = []
	for t in GameEnums.ELEMENTS:
		cles.append(SpellCard.type_of_tag(t))
	cles.append(SpellCard.type_of_tag(GameEnums.DamageTag.SLOW))
	for k in cles:
		ok(ElementIcons.texture(k) != null, "le logo %s existe" % k)
		ok(ElementIcons.SHAPES.has(k), "%s a une forme declaree" % k)
		var f: String = str(ElementIcons.SHAPES.get(k, ""))
		not_ok(formes.has(f), "%s ne partage pas la forme '%s'" % [k, f])
		formes[f] = k
	for k in ElementIcons.KEYS:
		ok(ElementIcons.texture(k) != null, "le logo de type %s existe" % k)
		# Un type non elementaire ne prend jamais la forme d un element.
		if not (k in cles):
			not_ok(formes.has(str(ElementIcons.SHAPES.get(k, ""))),
				"le type %s ne se confond pas avec un element" % k)


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


## LE LOGO EST SUR LA CARTE, en main comme en detail, et c est celui de son type.
## Il ne coute aucune ligne de texte : la carte de main reste a trois labels au
## plus (test_card_view le verifie par ailleurs).
func _test_la_carte_porte_son_logo() -> void:
	for id in ContentDB.cards.keys():
		var card: SpellCard = ContentDB.cards[id]
		for mode in ["main", "detail"]:
			var cv := CardView.new()
			if mode == "main":
				cv.setup_hand(card, 118.0, 230.0)
			else:
				cv.setup_detail(card, 300.0, 440.0)
			var badge: Node = cv.find_child("TypeBadge", true, false)
			ok(badge is TextureRect, "%s (%s) porte le logo de son type" % [id, mode])
			if badge is TextureRect:
				ok((badge as TextureRect).texture == ElementIcons.texture(card.spell_type()),
					"%s (%s) : le logo est celui de son type" % [id, mode])
				ok((badge as TextureRect).custom_minimum_size.x >= CardView.BADGE_MIN,
					"%s (%s) : le logo reste lisible" % [id, mode])
			cv.free()


## LE SCEAU EST AUSSI SUR LES VIGNETTES DE L ECRAN DE DECK (retouche du 30/09),
## meme regle qu au grimoire : chaque vignette, du deck comme de la collection,
## porte le logo du type de SA carte ; une carte a obtenir a son image ET son
## sceau grises (CollectionStyle.GREY_ART), jamais son texte ; une carte obtenue
## garde des couleurs intactes. On parcourt TOUTES les pages : sur un profil
## neuf les grisees viennent apres les obtenues, donc pas en page 1.
func _test_l_ecran_de_deck_porte_le_sceau() -> void:
	SaveData.reset_profile()
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	var vues: int = 0
	var grisees: int = 0
	for page in panel.page_count():
		for n: Node in panel.find_children("*", "Button", true, false):
			if not n.has_meta(&"tile_card_id"):
				continue
			var card: SpellCard = ContentDB.cards.get(n.get_meta(&"tile_card_id"))
			if card == null:
				continue
			vues += 1
			var badge: Node = n.find_child("TypeBadge", true, false)
			ok(badge is TextureRect, "%s : sa vignette de deck porte un sceau" % card.id)
			if not (badge is TextureRect):
				continue
			ok((badge as TextureRect).texture == ElementIcons.texture(card.spell_type()),
				"%s : le sceau de sa vignette est celui de son type" % card.id)
			var icone: Node = badge.get_parent().get_child(0)
			if SaveData.is_discovered(card.id):
				eq((badge as TextureRect).modulate, Color.WHITE,
					"%s obtenue : sceau en couleurs" % card.id)
				continue
			grisees += 1
			eq((badge as TextureRect).modulate, CollectionStyle.GREY_ART,
				"%s a obtenir : sceau grise comme au grimoire" % card.id)
			ok(icone is TextureRect and (icone as TextureRect).modulate == CollectionStyle.GREY_ART,
				"%s a obtenir : icone grisee une seule fois" % card.id)
			eq((badge.get_parent() as Control).modulate, Color.WHITE,
				"%s a obtenir : le porteur n est pas grise (le gris multiplie)" % card.id)
			for l: Node in n.find_children("*", "Label", true, false):
				eq((l as Label).modulate, Color.WHITE,
					"%s a obtenir : son texte reste intact" % card.id)
		panel.turn_page(1)
	# Les vignettes du DECK (en haut) passent aussi par la boucle : elles sont
	# dans l arbre a chaque page.
	ok(not panel.draggable_tiles(true).is_empty(), "le deck de depart a des vignettes")
	ok(vues >= panel.collection().size() + panel.draggable_tiles(true).size(),
		"toutes les vignettes du deck et de la collection ont ete vues (%d)" % vues)
	ok(grisees > 0, "un profil neuf montre des cartes a obtenir dans l ecran de deck")
	detach(panel)
	SaveData.reset_profile()


func _contient(lignes: Array[String], morceau: String) -> bool:
	for l in lignes:
		if l.to_lower().contains(morceau.to_lower()):
			return true
	return false


## VAGUE 8 — « Toutes les cartes doivent etre associees a un de ces elements. »
## Chaque SORT (pas seulement ceux qui font des degats : pioche, temps, terrain
## aussi) porte EXACTEMENT un element, dans le champ explicite
## `SpellCard.element`, et aucun element ne traine dans `tags` pour le
## contredire. Les tags du combat n en contiennent qu un.
func _test_chaque_sort_a_exactement_un_element() -> void:
	var par_element: Dictionary = {}
	for id in ContentDB.cards.keys():
		var card: SpellCard = ContentDB.cards[id]
		if card == null or card.is_passive:
			continue
		ok(int(card.element) in GameEnums.ELEMENTS, "%s a un element explicite" % id)
		for t in card.tags:
			not_ok(int(t) in GameEnums.ELEMENTS,
				"%s : aucun element dans ses tags, seulement des marqueurs" % id)
		var n: int = 0
		for t in card.combat_tags():
			if int(t) in GameEnums.ELEMENTS:
				n += 1
		eq(n, 1, "%s : un seul element dans les tags du combat" % id)
		par_element[int(card.element)] = int(par_element.get(int(card.element), 0)) + 1
	for e in GameEnums.ELEMENTS:
		ok(int(par_element.get(e, 0)) > 0,
			"au moins un sort de %s : chaque element sert" % GameEnums.tag_name(e))
	# Le repli d une carte ancienne : un element ecrit dans les tags est lu.
	var vieille := SpellCard.new()
	vieille.tags = _tags([GameEnums.DamageTag.FIRE, GameEnums.DamageTag.SLOW])
	eq(vieille.main_element(), GameEnums.DamageTag.FIRE, "repli : l element des tags")
	vieille.element = GameEnums.DamageTag.ICE
	eq(vieille.combat_tags(), [GameEnums.DamageTag.ICE, GameEnums.DamageTag.SLOW],
		"le champ l emporte, et l element des tags ne s ajoute pas")


## LA REGLE DE PASSAGE DES RESISTANCES (vague 8), verifiee sur le contenu livre
## et contre les constantes de make_content.gd : pas 86 valeurs a relire, une
## regle. Le vent et la nature naissent de l ancienne durete (« phys ») — donc
## egaux pour un monstre au sol ; un volant craint le vent et resiste a la
## nature ; l eau est le miroir borne du feu. Une seule exception, nommee dans
## make_content (ANCRES_AU_SOL, chantier W9) : les enclumes, immunisees au vent.
func _test_la_regle_de_passage_des_resistances() -> void:
	var MC: GDScript = load("res://tools/make_content.gd")
	var T := GameEnums.DamageTag
	var vus_volants: int = 0
	var vus_ancres: int = 0
	for id in ContentDB.enemies.keys():
		var d: EnemyDef = ContentDB.enemies[id]
		if d == null or d.chameleon_interval > 0.0:
			continue
		var vent: float = d.resistance_to(T.WIND)
		var nature: float = d.resistance_to(T.NATURE)
		if String(id) in MC.ANCRES_AU_SOL:
			# LA SEULE EXCEPTION ECRITE (chantier W9) : une enclume ne s envole
			# pas. Immunise au vent, la nature suit encore la regle (pas immunise).
			vus_ancres += 1
			not_ok(d.flying, "%s est une ancre au sol : il ne vole pas" % id)
			feq(vent, 0.0, "%s : ancre au sol, immunise au vent" % id, 0.001)
			ok(nature > 0.0, "%s : la nature, elle, l entame encore" % id)
			continue
		ok(vent > 0.0, "%s : seules les ancres au sol sont immunisees au vent" % id)
		if d.flying:
			vus_volants += 1
			ok(vent >= EnemyDef.accentuate(MC.WIND_FLYER_MIN) - 0.001,
				"%s vole : il craint le vent" % id)
			ok(nature <= EnemyDef.accentuate(MC.NATURE_FLYER_MAX) + 0.001,
				"%s vole : la nature ne l atteint pas" % id)
		else:
			feq(vent, nature, "%s : vent et nature heritent de la meme durete" % id, 0.001)
		# L eau, miroir du feu, sans jamais sortir de ses bornes.
		var feu: float = d.resistance_to(T.FIRE)
		var eau: float = d.resistance_to(T.WATER)
		ok(eau >= EnemyDef.accentuate(MC.WATER_FROM_FIRE_MIN) - 0.001
			and eau <= EnemyDef.accentuate(MC.WATER_FROM_FIRE_MAX) + 0.001,
			"%s : l eau reste dans ses bornes" % id)
		if feu < 1.0:
			ok(eau > 1.0, "%s resiste au feu : il craint l eau" % id)
		elif feu > 1.0:
			ok(eau < 1.0, "%s craint le feu : il boit l eau" % id)
		else:
			feq(eau, 1.0, "%s neutre au feu : neutre a l eau" % id, 0.001)
		not_ok(d.resistances.has(T.NONE), "%s : aucune ligne a l ancien physique" % id)
	ok(vus_volants > 0, "des volants ont ete verifies")
	eq(vus_ancres, (MC.ANCRES_AU_SOL as Array).size(),
		"chaque ancre au sol nommee par make_content est un monstre livre")
	# Le Cameleon ne declare aucun element de son cycle (les tables se multiplieraient).
	var cam: EnemyDef = ContentDB.enemies.get(&"season_chameleon")
	if cam != null:
		for t in cam.chameleon_elements:
			not_ok(cam.resistances.has(int(t)),
				"Cameleon : %s tourne, il n est pas dans sa table" % GameEnums.tag_name(int(t)))
			ok(int(t) in GameEnums.ELEMENTS, "Cameleon : son cycle est fait d elements")


## LOGOS DANS LE TEXTE (vague 8) : « feu -30 %  eau +60 % » avec les logos, un
## seul helper pour toute l interface.
func _test_les_logos_dans_le_texte() -> void:
	var T := GameEnums.DamageTag
	var px: int = ElementIcons.inline_px(UiTheme.FONT_BODY)
	ok(px > UiTheme.FONT_BODY, "le logo est plus haut qu une majuscule : lisible sur telephone")
	var ligne: String = ElementIcons.resist_bbcode(
		[{"tag": T.FIRE, "mult": 0.7}, {"tag": T.WATER, "mult": 1.6}], px)
	ok(ligne.contains(ElementIcons.path(&"feu")) and ligne.contains(ElementIcons.path(&"eau")),
		"chaque resistance porte son logo")
	ok(ligne.find("feu") < ligne.find("eau"), "dans l ordre donne")
	var sans_gluon: String = ligne.replace("\u2060", "")
	ok(sans_gluon.contains("-30\u00a0%") and sans_gluon.contains("+60\u00a0%"),
		"chiffres colles a leur logo par des espaces insecables")
	ok(ligne.contains("+\u206060"), "aucune coupure possible apres le signe")
	ok(ligne.contains(" "), "une coupure possible ENTRE deux resistances")
	ok(ligne.contains("[img=%dx%d]" % [px, px]), "taille imposee, pas celle du PNG")
	# Les descriptions : un mot d element en MAJUSCULES recoit son logo, un mot
	# en minuscules non (« feu » dans une phrase n annonce pas un element).
	var deco: String = ElementIcons.decorate("10 degats de VENT, le feu couve", px)
	ok(deco.contains(ElementIcons.path(&"vent")), "VENT recoit son logo")
	not_ok(deco.contains(ElementIcons.path(&"feu")), "un feu en minuscules reste un mot")
	eq(ElementIcons.strip_inline(deco), "10 degats de VENT, le feu couve",
		"le texte d origine se relit sans les logos")
	# Le detail d une carte qui cite son element porte le logo dans la phrase.
	var bolt: SpellCard = ContentDB.cards.get(&"arcane_bolt")
	if bolt != null:
		var cv := CardView.new()
		cv.setup_detail(bolt, 300.0, 440.0)
		var desc: Node = cv.find_child("Description", true, false)
		ok(desc is RichTextLabel, "la description qui cite l ARCANE est un texte a logos")
		if desc is RichTextLabel:
			ok((desc as RichTextLabel).text.contains(ElementIcons.path(&"arcane")),
				"le logo de l arcane est dans la description")
		cv.free()
	# La legende du Cameleon, a la fiche : ses elements en logos.
	var cam: EnemyDef = ContentDB.enemies.get(&"season_chameleon")
	if cam != null:
		var riche: String = "\n".join(BestiaryLore.behaviours(cam, true))
		var nu: String = "\n".join(BestiaryLore.behaviours(cam))
		for t in cam.chameleon_elements:
			ok(riche.contains(ElementIcons.path(SpellCard.type_of_tag(int(t)))),
				"legende du Cameleon : logo de %s" % GameEnums.tag_name(int(t)))
			ok(nu.contains(GameEnums.tag_name(int(t))), "et le texte nu le nomme")
		not_ok(nu.contains("[img"), "le texte nu ne contient aucun BBCode")


## « Arcanique », pas « Arcane » (audit vague 9) : le co-auteur a nomme les huit
## elements Feu, Eau, Nature, Vent, Foudre, Glace, Arcanique, Poison. Les
## IDENTIFIANTS internes (ARCANE, &"arcane", arcane_bolt) ne changent pas ; les
## libelles affiches, si. Verrous : les noms de type, la phrase de resistance,
## le logo dans un texte qui ecrit ARCANIQUE, l ancienne cle du testeur ; puis
## un balayage de scripts/ui : aucune chaine n ecrit « arcane » / « Arcane ».
func _test_l_element_s_appelle_arcanique() -> void:
	var noms: Array = []
	for e in GameEnums.ELEMENTS:
		noms.append(ElementIcons.type_name(SpellCard.type_of_tag(e)))
	eq(noms, ["Feu", "Eau", "Nature", "Vent", "Foudre", "Glace", "Arcanique", "Poison"],
		"les noms de type affiches sont ceux du co-auteur")
	var phrase: String = BestiaryLore._tag_name(GameEnums.DamageTag.ARCANE)
	ok(phrase.contains("arcanique"), "la fiche de monstre dit « arcanique » (%s)" % phrase)
	var px: int = ElementIcons.inline_px(UiTheme.FONT_BODY)
	for mot in ["ARCANIQUE", "ARCANIQUES"]:
		var texte: String = "6 degats %s ici" % mot
		var deco: String = ElementIcons.decorate(texte, px)
		ok(deco.contains(ElementIcons.path(&"arcane")), "%s recoit le logo de l element" % mot)
		eq(ElementIcons.strip_inline(deco), texte, "%s : le mot reste entier" % mot)
	# Un document de testeur ecrit avant le renommage garde sa cle.
	var monstre: EnemyDef = null
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null:
			monstre = d
			break
	if monstre != null:
		ok(not TesterOverrides.resolve_field(monstre, "resistances/arcane").is_empty(),
			"l ancienne cle resistances/arcane du testeur reste lisible")
		ok(not TesterOverrides.resolve_field(monstre, "resistances/"
			+ GameEnums.tag_name(GameEnums.DamageTag.ARCANE)).is_empty(), "la nouvelle cle aussi")
	# Balayage : une chaine (pas un StringName &"...") qui ecrit le mot en
	# minuscules ou avec une majuscule initiale serait un libelle affiche.
	var re := RegEx.new()
	re.compile("(?<!&)\"[^\"]*\\b(arcanes?|Arcanes?)\\b[^\"]*\"")
	var fautes: Array[String] = []
	for chemin in _scripts_ui("res://scripts/ui"):
		var f := FileAccess.open(chemin, FileAccess.READ)
		if f == null:
			continue
		var n: int = 0
		while not f.eof_reached():
			var ligne: String = f.get_line()
			n += 1
			var code: String = ligne.strip_edges()
			if code.begins_with("#"):
				continue
			if re.search(code) != null:
				fautes.append("%s:%d %s" % [chemin.get_file(), n, code])
	ok(fautes.is_empty(), "aucun libelle « arcane » dans scripts/ui : %s" % "; ".join(fautes))


func _scripts_ui(dossier: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dossier)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dossier.path_join(f))
	for sous in d.get_directories():
		out.append_array(_scripts_ui(dossier.path_join(sous)))
	return out

extends TestCase
## PALIERS DE RESISTANCES (vague 10, regle du co-auteur du 14/10).
##
## « Arrondis les resistances et les faiblesses pour qu on n ait que des chiffres
## clairs et alignes : les resistances/faiblesses proches d un meme monstre a une
## seule valeur (ex. 15, 20 et 30 -> les trois a 25) ; si elles sont trop proches
## de 0, mets-les a 0 ; et rends-les un peu plus equilibrees : trop de monstres
## immunises au poison. »
##
## La regle vit dans EnemyDef.tiered_table / tiered_value ; tools/make_content.gd
## l applique a la fin de `_resist`. Ce test la verifie sur des exemples ou une
## regle fausse et la bonne donnent des resultats DIFFERENTS, puis sur tout le
## bestiaire livre et sur ce que la fiche affiche.

const T := GameEnums.DamageTag


func get_suite_name() -> String:
	return "resist_tiers"


func run() -> void:
	_test_l_exemple_du_co_auteur()
	_test_trop_pres_de_zero_devient_neutre()
	_test_les_voisins_d_un_monstre_s_alignent()
	_test_chaque_cote_a_ses_groupes()
	_test_bornes_immunite_et_plafond()
	_test_l_ordre_des_cles_ne_change_rien()
	_test_une_ligne_qui_n_est_pas_un_element_reste_seule()
	_test_le_bestiaire_livre_est_aux_paliers()
	_test_la_fiche_affiche_des_pourcentages_ronds()
	_test_les_immunites_au_poison_sont_nommees()
	_test_le_poison_et_la_nature_reequilibres()


## Les valeurs permises : immunite, les resistances et les faiblesses au pas.
static func paliers_permis() -> Array[float]:
	var out: Array[float] = [0.0]
	var k: int = 1
	while 1.0 - k * EnemyDef.PALIER_PAS > 0.001:
		out.append(1.0 - k * EnemyDef.PALIER_PAS)
		k += 1
	k = 1
	while 1.0 + k * EnemyDef.PALIER_PAS <= EnemyDef.WEAK_CAP + 0.001:
		out.append(1.0 + k * EnemyDef.PALIER_PAS)
		k += 1
	return out


static func _est_un_palier(v: float) -> bool:
	for p in paliers_permis():
		if is_equal_approx(v, p):
			return true
	return false


## 15, 20 et 30 points de resistance : les trois a 25.
func _test_l_exemple_du_co_auteur() -> void:
	var t: Dictionary = EnemyDef.tiered_table({T.FIRE: 0.85, T.ICE: 0.80, T.ARCANE: 0.70})
	for tag in [T.FIRE, T.ICE, T.ARCANE]:
		feq(float(t.get(tag, 1.0)), 1.0 - EnemyDef.PALIER_PAS,
			"exemple du co-auteur : %s a -25" % GameEnums.tag_name(tag))
	# Et le meme exemple cote faiblesses.
	var f: Dictionary = EnemyDef.tiered_table({T.FIRE: 1.15, T.ICE: 1.20, T.ARCANE: 1.30})
	for tag in [T.FIRE, T.ICE, T.ARCANE]:
		feq(float(f.get(tag, 1.0)), 1.0 + EnemyDef.PALIER_PAS,
			"faiblesses 15 / 20 / 30 : %s a +25" % GameEnums.tag_name(tag))


func _test_trop_pres_de_zero_devient_neutre() -> void:
	var presque: float = EnemyDef.PALIER_NEUTRE * 0.6
	var t: Dictionary = EnemyDef.tiered_table({T.FIRE: 1.0 - presque, T.ICE: 1.0 + presque})
	ok(t.is_empty(), "un ecart trop proche de 0 disparait de la table (%s)" % [t])
	feq(EnemyDef.tiered_value(1.0 + presque), 1.0, "une valeur seule trop proche de 0 est neutre")
	# Juste au-dessus du seuil, l ecart reste : il prend le premier palier.
	var juste: float = EnemyDef.PALIER_NEUTRE + 0.01
	feq(float(EnemyDef.tiered_table({T.FIRE: 1.0 - juste}).get(T.FIRE, 1.0)),
		1.0 - EnemyDef.PALIER_PAS, "au-dessus du seuil, la resistance est gardee")


## Deux ecarts voisins de part et d autre d un MILIEU de palier (36 et 40
## points) : arrondis chacun, ils donneraient -25 et -50 ; groupes, ils
## prennent la meme valeur. C est la donnee qui departage la regle et un
## simple arrondi.
func _test_les_voisins_d_un_monstre_s_alignent() -> void:
	var t: Dictionary = EnemyDef.tiered_table({T.FIRE: 0.64, T.ICE: 0.60})
	ok(t.has(T.FIRE) and t.has(T.ICE), "les deux resistances restent")
	feq(float(t.get(T.FIRE, 1.0)), float(t.get(T.ICE, 0.0)),
		"deux resistances voisines d un meme monstre ont UNE valeur")
	not_ok(is_equal_approx(EnemyDef.tiered_value(0.64), EnemyDef.tiered_value(0.60)),
		"(seules, elles tomberaient sur deux paliers : l exemple departage bien)")
	# Deux ecarts eloignes ne se melangent pas.
	var loin: Dictionary = EnemyDef.tiered_table({T.FIRE: 0.80, T.ICE: 0.30})
	ok(float(loin.get(T.ICE, 1.0)) < float(loin.get(T.FIRE, 1.0)),
		"une forte et une faible resistance restent distinctes")


func _test_chaque_cote_a_ses_groupes() -> void:
	var t: Dictionary = EnemyDef.tiered_table({T.FIRE: 0.80, T.ICE: 1.20})
	ok(float(t.get(T.FIRE, 1.0)) < 1.0, "la resistance reste une resistance")
	ok(float(t.get(T.ICE, 1.0)) > 1.0, "la faiblesse reste une faiblesse")


func _test_bornes_immunite_et_plafond() -> void:
	var t: Dictionary = EnemyDef.tiered_table({T.POISON: 0.0, T.FIRE: 0.05, T.ICE: 9.0})
	feq(float(t.get(T.POISON, -1.0)), 0.0, "l immunite est gardee")
	ok(float(t.get(T.FIRE, 0.0)) > 0.0,
		"une tres forte resistance ne devient JAMAIS une immunite par arrondi")
	feq(float(t.get(T.ICE, 0.0)), EnemyDef.WEAK_CAP, "une faiblesse est plafonnee a WEAK_CAP")


func _test_l_ordre_des_cles_ne_change_rien() -> void:
	var a: Dictionary = {T.FIRE: 0.70, T.ICE: 0.62, T.ARCANE: 0.55, T.WIND: 1.27, T.WATER: 1.42}
	var b: Dictionary = {T.WATER: 1.42, T.ARCANE: 0.55, T.WIND: 1.27, T.ICE: 0.62, T.FIRE: 0.70}
	eq(EnemyDef.tiered_table(a), EnemyDef.tiered_table(b), "meme table, meme resultat")


## Le ralentissement est un EFFET : il est arrondi seul, il ne tire ni ne
## pousse les elements de son groupe.
func _test_une_ligne_qui_n_est_pas_un_element_reste_seule() -> void:
	var t: Dictionary = EnemyDef.tiered_table({T.SLOW: 0.64, T.FIRE: 0.60})
	feq(float(t.get(T.SLOW, 1.0)), EnemyDef.tiered_value(0.64), "la ligne SLOW est arrondie seule")
	feq(float(t.get(T.FIRE, 1.0)), EnemyDef.tiered_value(0.60), "le feu n est pas groupe avec elle")


## Tout le bestiaire livre : chaque valeur est un palier, chaque table est
## STABLE par la regle (la reappliquer ne change rien), le Cameleon aussi.
func _test_le_bestiaire_livre_est_aux_paliers() -> void:
	var vues: Dictionary = {}
	var monstres: int = 0
	for id in ContentDB.enemies.keys():
		var d: EnemyDef = ContentDB.enemies[id]
		if d == null:
			continue
		monstres += 1
		for tag in d.resistances.keys():
			var v: float = float(d.resistances[tag])
			ok(_est_un_palier(v), "%s : %s = %s est un palier" % [id, GameEnums.tag_name(int(tag)), v])
			not_ok(is_equal_approx(v, 1.0), "%s : aucune ligne neutre stockee" % id)
			vues[snappedf(v, 0.01)] = true
		eq(EnemyDef.tiered_table(d.resistances), d.resistances,
			"%s : la table est stable par la regle des paliers" % id)
		if d.chameleon_interval > 0.0:
			ok(_est_un_palier(d.chameleon_weak_mult), "%s : faiblesse tournante au palier" % id)
			ok(_est_un_palier(d.chameleon_resist_mult), "%s : resistance tournante au palier" % id)
	ok(monstres > 0, "des monstres ont ete verifies")
	ok(vues.size() <= paliers_permis().size(),
		"%d valeurs distinctes dans le bestiaire, %d paliers au plus" % [vues.size(), paliers_permis().size()])


## Ce que la fiche affiche (bestiaire, briefing, onglet VAGUE) passe par
## ElementIcons.percent_text : chaque pourcentage est un multiple du pas.
func _test_la_fiche_affiche_des_pourcentages_ronds() -> void:
	var pas: int = int(round(EnemyDef.PALIER_PAS * 100.0))
	for id in ContentDB.enemies.keys():
		var d: EnemyDef = ContentDB.enemies[id]
		if d == null:
			continue
		for tag in d.resistances.keys():
			var v: float = float(d.resistances[tag])
			if v <= 0.0:
				continue
			var txt: String = ElementIcons.percent_text(v)
			var n: int = absi(int(txt.replace("%", "").replace("+", "").replace("-", "").strip_edges()))
			ok(n > 0 and n % pas == 0, "%s : « %s » est un pourcentage rond" % [id, txt])


## L immunite au poison n est plus un reflexe : chaque monstre immunise est
## NOMME dans make_content (IMMUNISES_AU_POISON), et chaque nom est un monstre
## livre et immunise.
func _test_les_immunites_au_poison_sont_nommees() -> void:
	var MC: GDScript = load("res://tools/make_content.gd")
	var liste: Array = MC.IMMUNISES_AU_POISON
	ok(not liste.is_empty(), "la liste des immunises au poison existe")
	for id in ContentDB.enemies.keys():
		var d: EnemyDef = ContentDB.enemies[id]
		if d == null:
			continue
		if d.resistance_to(T.POISON) <= 0.0:
			ok(String(id) in liste, "%s est immunise au poison : il doit etre nomme" % id)
	for nom in liste:
		var d2: EnemyDef = ContentDB.enemies.get(StringName(nom))
		ok(d2 != null, "%s (immunise au poison) est un monstre livre" % nom)
		if d2 != null:
			feq(d2.resistance_to(T.POISON), 0.0, "%s est bien immunise au poison" % nom)


## « Un peu plus equilibrees » : le poison n est plus l element que le bestiaire
## refuse en bloc (les immunites sont nommees, ci-dessus), et la nature n est
## plus resistee comme la fleche : elle garde le SENS de la durete, en plus doux.
func _test_le_poison_et_la_nature_reequilibres() -> void:
	var MC: GDScript = load("res://tools/make_content.gd")
	var nature_plus_douce: int = 0
	var au_sol: int = 0
	var poison_faible_ou_neutre: int = 0
	for id in ContentDB.enemies.keys():
		var d: EnemyDef = ContentDB.enemies[id]
		if d == null or d.chameleon_interval > 0.0:
			continue
		if d.resistance_to(T.POISON) >= 1.0:
			poison_faible_ou_neutre += 1
		if not d.flying and not String(id) in MC.ANCRES_AU_SOL:
			au_sol += 1
			var v: float = d.resistance_to(T.WIND) - 1.0
			var n: float = d.resistance_to(T.NATURE) - 1.0
			ok(absf(n) <= absf(v) + 0.001 and (is_zero_approx(n) or signf(n) == signf(v)),
				"%s : la nature suit le vent, en plus doux (vent %+.2f, nature %+.2f)" % [id, v, n])
			if absf(n) < absf(v) - 0.001:
				nature_plus_douce += 1
	ok(poison_faible_ou_neutre > (MC.IMMUNISES_AU_POISON as Array).size(),
		"plus de monstres sentent le poison en plein (%d) que de monstres immunises"
		% poison_faible_ou_neutre)
	ok(au_sol > 0 and nature_plus_douce > 0, "la nature est plus douce que le vent pour %d monstres sur %d"
		% [nature_plus_douce, au_sol])

extends TestCase
## REGLE DES TROIS PROPOSITIONS (vague 9) : chaque maturation de chaque sort du
## catalogue montre exactement GameConfig.LEVEL_UP_CHOICES voies. Avant, un sort a
## 4 voies (Trait arcanique, Riviere) n en montrait que 2 a sa 3e maturation et 1
## a sa 4e. Voir RunState.upgrade_tiers_for.

func get_suite_name() -> String:
	return "maturation_offers"


func run() -> void:
	_test_toutes_les_maturations_de_tous_les_sorts_explorees()
	_test_toutes_les_maturations_jouees()
	_test_un_refus_ne_vide_pas_l_ecran()


func _sorts() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive:
			out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool: return String(a.id) < String(b.id))
	return out


## EXPLORATION de tous les etats atteignables : l ensemble des voies prises suffit
## a decrire l offre (un refus ne prend rien), on parcourt donc tous les ensembles
## qu un joueur peut construire en prenant n importe quelle voie offrable, jusqu a
## la derniere maturation. A chacun : au moins trois voies offrables.
func _test_toutes_les_maturations_de_tous_les_sorts_explorees() -> void:
	var n: int = GameConfig.LEVEL_UP_CHOICES
	var sorts: Array[SpellCard] = _sorts()
	ok(sorts.size() > 0, "le catalogue a des sorts")
	var etats_vus: int = 0
	var defauts: Array[String] = []
	for c in sorts:
		RunState.reset()
		var paliers: int = RunState.upgrade_tiers_for(c)
		if paliers <= 0:
			defauts.append("%s : aucune maturation (pool %d)" % [c.id, RunState.upgrade_pool_for(c).size()])
			continue
		var niveau: Array = [[]]
		for k in paliers:
			var suivant: Dictionary = {}
			for prises: Array in niveau:
				RunState.upgrades_taken[c.id] = prises.duplicate()
				var libres: Array = RunState.upgrade_offerable_for(c)
				etats_vus += 1
				if libres.size() < n:
					defauts.append("%s maturation %d apres %s : %d voies" % [c.id, k + 1, prises, libres.size()])
					continue
				# Le tirage lui-meme (trois voies distinctes) est verifie la ou il
				# a lieu, dans le parcours joue : le refaire ici a chaque etat
				# doublait le temps de la suite.
				if k + 1 >= paliers:
					continue
				for v in libres:
					var cle: Array = prises.duplicate()
					cle.append(StringName(v["id"]))
					cle.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
					suivant[str(cle)] = cle
			niveau = suivant.values()
	RunState.reset()
	eq(defauts.size(), 0, "trois propositions a chaque maturation de chaque sort %s"
		% [defauts.slice(0, 6)])
	ok(etats_vus > sorts.size(), "l exploration a parcouru les etats (%d)" % etats_vus)


## Le parcours REEL : l XP fait murir le sort, l ecran s ouvre, on prend une voie,
## jusqu a ce qu il ne s ouvre plus. Chaque ecran montre trois voies, et le sort
## a fait toutes ses maturations.
func _test_toutes_les_maturations_jouees() -> void:
	var n: int = GameConfig.LEVEL_UP_CHOICES
	var defauts: Array[String] = []
	var ecrans: int = 0
	for c in _sorts():
		RunState.reset()
		var paliers: int = RunState.upgrade_tiers_for(c)
		var garde: int = paliers + 2
		while garde > 0:
			garde -= 1
			var manque: int = RunState.next_upgrade_at(c) - RunState.card_xp(c)
			RunState.grant_card_xp(c, maxi(1, manque))
			if RunState.pending_upgrade_card == null:
				break
			ecrans += 1
			var ids: Dictionary = {}
			for v in RunState.pending_upgrade_paths:
				ids[v["id"]] = true
			if ids.size() != RunState.pending_upgrade_paths.size():
				defauts.append("%s : une voie montree deux fois" % c.id)
			if RunState.pending_upgrade_paths.size() != n:
				defauts.append("%s maturation %d : %d voies" % [c.id,
					RunState.maturations_done(c) + 1, RunState.pending_upgrade_paths.size()])
			# La DERNIERE voie de l ecran : un autre choix que la premiere.
			RunState.pick_upgrade(RunState.pending_upgrade_paths.size() - 1)
		if RunState.maturations_done(c) != paliers:
			defauts.append("%s : %d maturations sur %d" % [c.id, RunState.maturations_done(c), paliers])
		RunState.grant_card_xp(c, RunState.upgrade_threshold(paliers + 1))
		if RunState.pending_upgrade_card != null:
			defauts.append("%s : un ecran apres la derniere maturation" % c.id)
			RunState.decline_upgrade()
	RunState.reset()
	eq(defauts.size(), 0, "chaque ecran joue montre trois voies %s" % [defauts.slice(0, 6)])
	ok(ecrans > 0, "des ecrans se sont ouverts (%d)" % ecrans)


## Un refus consomme la maturation sans prendre de voie : l ecran suivant montre
## toujours trois voies.
func _test_un_refus_ne_vide_pas_l_ecran() -> void:
	var n: int = GameConfig.LEVEL_UP_CHOICES
	var petit: SpellCard = null
	for c in _sorts():
		if petit == null or RunState.upgrade_pool_for(c).size() < RunState.upgrade_pool_for(petit).size():
			petit = c
	if petit == null:
		return
	RunState.reset()
	var paliers: int = RunState.upgrade_tiers_for(petit)
	ok(paliers >= 1, "%s (pool %d) murit au moins une fois" % [petit.id,
		RunState.upgrade_pool_for(petit).size()])
	for k in paliers:
		RunState.grant_card_xp(petit, maxi(1, RunState.next_upgrade_at(petit) - RunState.card_xp(petit)))
		eq(RunState.pending_upgrade_paths.size(), n,
			"%s maturation %d : trois voies" % [petit.id, k + 1])
		if k % 2 == 0:
			RunState.decline_upgrade()
		else:
			RunState.pick_upgrade(0)
	RunState.reset()

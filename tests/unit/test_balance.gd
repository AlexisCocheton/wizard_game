extends TestCase
## Garde-fous d equilibrage.
##
## Ces tests ne rejouent pas une partie (trop long pour le harnais) : ils
## verrouillent les RAPPORTS mesures au banc tools/sim_balance.gd, ceux dont la
## rupture rendait le jeu injouable. Rejouer le banc reste la mesure de verite.

func get_suite_name() -> String:
	return "balance"


func run() -> void:
	_test_la_courbe_monte_sans_a_coup()
	_test_le_niveau_2_prolonge_le_niveau_1()
	_test_le_joueur_pioche_assez_pour_repondre()
	_test_le_mode_infini_laisse_le_temps_de_construire()


## Les PV d une vague ne doivent jamais plus que doubler d une vague a l autre :
## c est ce saut qui rendait la premiere vague du niveau 2 infranchissable.
func _test_la_courbe_monte_sans_a_coup() -> void:
	for level_id in [&"lvl_01", &"lvl_02"]:
		var level: LevelDef = ContentDB.levels.get(level_id)
		if level == null:
			continue
		var precedent: float = 0.0
		for wave: WaveDef in level.waves:
			var pv: float = _wave_hp(wave)
			if precedent > 0.0:
				ok(pv <= precedent * 2.0,
					"%s / %s : %.0f PV apres %.0f, le saut reste sous x2"
					% [level_id, wave.id, pv, precedent])
			precedent = pv


## Le niveau 2 reprend juste au-dessus de la fin du niveau 1, il ne repart pas
## d un mur : sa premiere vague valait plus que la cinquieme du niveau 1.
func _test_le_niveau_2_prolonge_le_niveau_1() -> void:
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	var l2: LevelDef = ContentDB.levels.get(&"lvl_02")
	if l1 == null or l2 == null or l1.waves.is_empty() or l2.waves.is_empty():
		return
	var fin_l1: float = _wave_hp(l1.waves[l1.waves.size() - 2])
	var debut_l2: float = _wave_hp(l2.waves[0])
	ok(debut_l2 < fin_l1,
		"la 1re vague du niveau 2 (%.0f PV) reste sous l avant-derniere du niveau 1 (%.0f PV)"
		% [debut_l2, fin_l1])


## La pioche suit le temps du monde : a x4 le joueur voit arriver quatre fois
## plus de monstres, il lui faut quatre fois plus de cartes. Voir [[test_deck]].
func _test_le_joueur_pioche_assez_pour_repondre() -> void:
	var vague_la_plus_dure: float = 0.0
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	if l1 == null:
		return
	for wave: WaveDef in l1.waves:
		vague_la_plus_dure = maxf(vague_la_plus_dure, _wave_count(wave) / maxf(wave.duration, 1.0))
	# Cartes piochees par seconde, a vitesse normale.
	var pioche: float = float(GameConfig.DRAW_COUNT) / GameConfig.DRAW_INTERVAL
	ok(pioche >= vague_la_plus_dure * 0.8,
		"la pioche (%.2f cartes/s) suit le rythme d arrivee le plus dense (%.2f monstres/s)"
		% [pioche, vague_la_plus_dure])


## Le mode Massacre doit laisser construire un deck avant de punir : sa vague 4
## valait la derniere du niveau 1 et les parties s arretaient vers la vague 3.
func _test_le_mode_infini_laisse_le_temps_de_construire() -> void:
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	if l1 == null or l1.waves.is_empty():
		return
	var derniere: int = 0
	for entry: WaveEntry in l1.waves[l1.waves.size() - 2].entries:
		if entry.enemy != null:
			derniere += entry.enemy.power * entry.count
	ok(WaveBudget.budget_for(5) <= derniere,
		"la vague 5 du mode infini (budget %d) reste sous l avant-derniere du niveau 1 (puissance %d)"
		% [WaveBudget.budget_for(5), derniere])


func _wave_hp(wave: WaveDef) -> float:
	var pv: float = 0.0
	for entry: WaveEntry in wave.entries:
		if entry.enemy != null:
			pv += entry.enemy.max_hp * entry.count * wave.difficulty
	return pv


func _wave_count(wave: WaveDef) -> float:
	var n: float = 0.0
	for entry: WaveEntry in wave.entries:
		if entry.enemy != null:
			n += entry.count
	return n

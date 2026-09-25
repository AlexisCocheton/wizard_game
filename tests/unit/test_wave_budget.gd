extends TestCase
## Vagues par budget de puissance : composition, bornes, determinisme, boss.

func get_suite_name() -> String:
	return "wave_budget"


func _def(id: String, power: int, kind: int = GameEnums.EnemyKind.NORMAL) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.power = power
	d.kind = kind
	return d


func _pool() -> Array[EnemyDef]:
	return [_def("p1", 1), _def("p2", 2), _def("p3", 3), _def("p4", 4)]


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func run() -> void:
	_test_budget_progressif()
	_test_composition_respecte_le_budget()
	_test_pool_seul()
	_test_determinisme()
	_test_boss_periodiques()
	_test_vague_jouable()
	_test_mondes_changent_toutes_les_6_vagues()
	_test_les_5_mondes_puis_on_boucle()
	_test_cadences_miniboss_et_boss()
	_test_le_monde_pese_sur_le_tirage_sans_le_verrouiller()
	_test_boss_differents_selon_le_monde()
	_test_budget_laisse_place_au_boss()
	_test_chaque_monde_a_une_famille_reelle()
	_test_chaque_monde_a_son_mini_boss()


func _test_budget_progressif() -> void:
	# Le budget de depart est un REGLAGE : le test verifie la regle, pas la valeur.
	eq(WaveBudget.budget_for(1), WaveBudget.BASE_BUDGET, "vague 1 : le budget de base")
	ok(WaveBudget.budget_for(2) > WaveBudget.budget_for(1), "le budget monte a la vague 2")
	ok(WaveBudget.budget_for(10) > WaveBudget.budget_for(5), "et continue de monter")
	ok(WaveBudget.difficulty_for(10) > WaveBudget.difficulty_for(1), "la difficulte monte aussi")


## Un budget de 8 avec des monstres 1..4 est exactement rempli, jamais depasse.
func _test_composition_respecte_le_budget() -> void:
	for seed_value in [1, 7, 42, 999]:
		var picks: Array[EnemyDef] = WaveBudget.compose(8, _pool(), _rng(seed_value))
		eq(WaveBudget.total_power(picks), 8, "budget 8 exactement rempli (graine %d)" % seed_value)
	var big: Array[EnemyDef] = WaveBudget.compose(23, _pool(), _rng(3))
	eq(WaveBudget.total_power(big), 23, "budget 23 exactement rempli")


func _test_pool_seul() -> void:
	var pool: Array[EnemyDef] = [_def("only", 3), _def("boss", 10, GameEnums.EnemyKind.BOSS)]
	var picks: Array[EnemyDef] = WaveBudget.compose(10, pool, _rng(5))
	for d in picks:
		eq(d.id, &"only", "seuls les monstres du pool, boss exclus")
	eq(WaveBudget.total_power(picks), 9, "3+3+3 : on s arrete quand plus rien n est abordable")


func _test_determinisme() -> void:
	var a: Array[EnemyDef] = WaveBudget.compose(14, _pool(), _rng(2026))
	var b: Array[EnemyDef] = WaveBudget.compose(14, _pool(), _rng(2026))
	eq(a.size(), b.size(), "meme graine, meme nombre")
	var same: bool = true
	for i in a.size():
		if a[i].id != b[i].id:
			same = false
	ok(same, "meme graine, meme composition")


## Les CADENCES sont des reglages : ce test verifie la REGLE (periodique, le boss
## l emporte, il ouvre la vague), pas les vagues 5 et 10 qui y etaient ecrites en
## dur et qui ont bloque le passage a la cadence 3/6 du mode infini.
func _test_boss_periodiques() -> void:
	var bosses: Array[EnemyDef] = [
		_def("mini", 6, GameEnums.EnemyKind.MINIBOSS),
		_def("big", 10, GameEnums.EnemyKind.BOSS),
	]
	var m: int = WaveBudget.MINIBOSS_EVERY
	var b: int = WaveBudget.BOSS_EVERY
	var ordinaire: WaveDef = WaveBudget.build_wave(m - 1, _pool(), _rng(1), bosses)
	not_ok(ordinaire.is_miniboss or ordinaire.is_boss,
		"vague %d : pas de boss hors palier" % (m - 1))
	var wm: WaveDef = WaveBudget.build_wave(m, _pool(), _rng(1), bosses)
	ok(wm.is_miniboss, "vague %d : mini-boss" % m)
	eq(wm.entries[0].enemy.id, &"mini", "le mini-boss ouvre la vague")
	var wb: WaveDef = WaveBudget.build_wave(b, _pool(), _rng(1), bosses)
	ok(wb.is_boss, "vague %d : boss" % b)
	eq(wb.entries[0].enemy.id, &"big", "le boss ouvre la vague")
	# La periodicite tient sur plusieurs tours, pas seulement au premier palier.
	var wb2: WaveDef = WaveBudget.build_wave(2 * b, _pool(), _rng(1), bosses)
	ok(wb2.is_boss, "vague %d : le boss revient" % (2 * b))


func _test_vague_jouable() -> void:
	var w: WaveDef = WaveBudget.build_wave(4, _pool(), _rng(11))
	eq(w.id, &"proc_4", "id de vague procedurale")
	var total: int = 0
	for e in w.entries:
		total += e.count * e.enemy.power
	eq(total, WaveBudget.budget_for(4), "les entrees totalisent le budget")
	ok(w.total_enemies() > 0, "la vague contient des monstres")


## --- MODE INFINI : la descente a travers les cinq mondes ---
##
## Specification du testeur : "fond change toutes les 6 vagues, mini-boss v3 /
## boss v6, fond qui pese sur le tirage". Les tests ci-dessous expriment ces
## REGLES en fonction des constantes, jamais des valeurs : changer WORLD_EVERY
## de 6 a 5 doit rester un reglage d equilibrage, pas une suite rouge.

## Le fond change toutes les WORLD_EVERY vagues, et jamais entre-temps.
func _test_mondes_changent_toutes_les_6_vagues() -> void:
	var n: int = WaveBudget.WORLD_EVERY
	for w in range(1, n + 1):
		eq(WaveBudget.world_index_for(w), 0, "vague %d : premier monde" % w)
	for w in range(n + 1, 2 * n + 1):
		eq(WaveBudget.world_index_for(w), 1, "vague %d : deuxieme monde" % w)
	# La cle de fond suit l index de monde, pas la vague.
	eq(WaveBudget.backdrop_for(1), WaveBudget.backdrop_for(n),
		"tout le premier bloc partage un fond")
	ok(WaveBudget.backdrop_for(n) != WaveBudget.backdrop_for(n + 1),
		"le fond CHANGE au passage de bloc")
	# Une cle vide laisserait le mode infini sans decor : le contrat est qu il y
	# en a toujours un.
	for w in range(1, 4 * n + 2):
		not_ok(String(WaveBudget.backdrop_for(w)).is_empty(),
			"vague %d : une cle de fond non vide" % w)


## Apres le dernier monde on BOUCLE : c est ce qui rend le mode vraiment sans
## fin. Sans bouclage, world_index_for() sortirait du tableau et le fond
## disparaitrait passe la derniere vague du cinquieme monde.
func _test_les_5_mondes_puis_on_boucle() -> void:
	var n: int = WaveBudget.WORLD_EVERY
	var count: int = WaveBudget.WORLDS.size()
	ok(count >= 2, "il y a plusieurs mondes a traverser")
	# La premiere vague du cycle suivant retrouve le premier fond.
	eq(WaveBudget.backdrop_for(count * n + 1), WaveBudget.backdrop_for(1),
		"apres le dernier monde, on revient au premier")
	# ... mais le NUMERO DE CYCLE, lui, monte : c est ce qui distingue le
	# deuxieme tour du premier.
	ok(WaveBudget.cycle_for(count * n + 1) > WaveBudget.cycle_for(1),
		"le cycle monte quand on reboucle")
	eq(WaveBudget.cycle_for(1), 1, "premier cycle numerote 1")
	# Tous les mondes sont visites avant de reboucler : aucun n est saute.
	var vus: Dictionary = {}
	for w in range(1, count * n + 1):
		vus[WaveBudget.world_index_for(w)] = true
	eq(vus.size(), count, "les %d mondes sont tous traverses" % count)


## Cadences demandees : un mini-boss tous les MINIBOSS_EVERY, un boss tous les
## BOSS_EVERY. Le boss l emporte quand les deux tombent ensemble.
func _test_cadences_miniboss_et_boss() -> void:
	var bosses: Array[EnemyDef] = [
		_def("mini", 6, GameEnums.EnemyKind.MINIBOSS),
		_def("big", 10, GameEnums.EnemyKind.BOSS),
	]
	# Le boss doit etre un MULTIPLE de la cadence mini-boss, sinon les deux
	# rythmes derivent et le joueur ne peut plus les anticiper.
	eq(WaveBudget.BOSS_EVERY % WaveBudget.MINIBOSS_EVERY, 0,
		"la cadence boss est un multiple de la cadence mini-boss")
	# Et le boss cloture le bloc de monde : c est le palier de la descente.
	eq(WaveBudget.BOSS_EVERY, WaveBudget.WORLD_EVERY,
		"le boss ferme le bloc de monde")
	var m: int = WaveBudget.MINIBOSS_EVERY
	var b: int = WaveBudget.BOSS_EVERY
	var wm: WaveDef = WaveBudget.build_wave(m, _pool(), _rng(1), bosses)
	ok(wm.is_miniboss, "vague %d : mini-boss" % m)
	not_ok(wm.is_boss, "vague %d : pas encore le boss" % m)
	var wb: WaveDef = WaveBudget.build_wave(b, _pool(), _rng(1), bosses)
	ok(wb.is_boss, "vague %d : boss" % b)
	not_ok(wb.is_miniboss, "un boss n est pas aussi un mini-boss")
	var w1: WaveDef = WaveBudget.build_wave(1, _pool(), _rng(1), bosses)
	not_ok(w1.is_boss or w1.is_miniboss, "vague 1 : rien d exceptionnel")


## LE DOSAGE, le point de conception le plus delicat : le monde doit peser sans
## verrouiller. S il n envoie QUE ses monstres, un deck specialise gagne pour
## toujours ; s il n en envoie qu a peine plus, personne ne le remarque.
func _test_le_monde_pese_sur_le_tirage_sans_le_verrouiller() -> void:
	# Deux familles de meme puissance : seul le monde peut les distinguer.
	var pool: Array[EnemyDef] = [_def("a1", 2), _def("a2", 2), _def("b1", 2), _def("b2", 2)]
	var appartenance: Dictionary = {&"a1": 0, &"a2": 0, &"b1": 1, &"b2": 1}
	# On tire beaucoup pour que la mesure soit un TAUX, pas un coup de chance.
	var part_local: float = _part_du_monde(0, pool, appartenance)
	var part_autre: float = _part_du_monde(1, pool, appartenance)
	# Le monde pese : sa famille est nettement majoritaire...
	ok(part_local > 0.55, "le monde courant domine le tirage (mesure %.2f)" % part_local)
	# ... mais il ne verrouille pas : les autres monstres restent possibles,
	# sinon un deck mono-element gagnerait pour toujours.
	ok(part_local < 0.95, "les autres mondes restent presents (mesure %.2f)" % part_local)
	# Et c est bien le MONDE qui decide, pas un biais fixe du pool : demander le
	# monde 1 doit inverser la majorite.
	ok(part_autre > 0.55, "changer de monde change la famille majoritaire (mesure %.2f)" % part_autre)


## Part des monstres du monde `world` dans un gros echantillon de compositions.
func _part_du_monde(world: int, pool: Array[EnemyDef], appartenance: Dictionary) -> float:
	var dedans: int = 0
	var total: int = 0
	for seed_value in range(1, 60):
		var picks: Array[EnemyDef] = WaveBudget.compose_for_world(
			24, pool, _rng(seed_value), world, appartenance)
		for d in picks:
			total += 1
			if int(appartenance.get(d.id, -1)) == world:
				dedans += 1
	return float(dedans) / maxf(total, 1.0)


## Le boss du cimetiere n est pas celui de la forge. Sans ce choix, les cinq
## mondes enverraient le meme boss et le changement de fond serait un decor vide.
func _test_boss_differents_selon_le_monde() -> void:
	var bosses: Array[EnemyDef] = [
		_def("b_a", 10, GameEnums.EnemyKind.BOSS),
		_def("b_b", 10, GameEnums.EnemyKind.BOSS),
	]
	var appartenance: Dictionary = {&"b_a": 0, &"b_b": 1}
	var pa: EnemyDef = WaveBudget.pick_boss(bosses, GameEnums.EnemyKind.BOSS, 0, appartenance)
	var pb: EnemyDef = WaveBudget.pick_boss(bosses, GameEnums.EnemyKind.BOSS, 1, appartenance)
	ok(pa != null and pb != null, "chaque monde trouve un boss")
	ok(pa != null and pb != null and pa.id != pb.id, "deux mondes, deux boss")
	# Repli : un monde sans boss attitre en recoit un quand meme, il ne saute
	# pas son palier.
	var pc: EnemyDef = WaveBudget.pick_boss(bosses, GameEnums.EnemyKind.BOSS, 4, appartenance)
	ok(pc != null, "un monde sans boss attitre retombe sur un boss existant")


## Un boss toutes les BOSS_EVERY vagues, c est beaucoup : la vague qui le porte
## doit laisser de la PLACE. Le test exprime le rapport, pas la valeur.
func _test_budget_laisse_place_au_boss() -> void:
	var b: int = WaveBudget.BOSS_EVERY
	var m: int = WaveBudget.MINIBOSS_EVERY
	# On compare une vague de palier a ce qu elle AURAIT porte sans boss, pas a la
	# vague precedente : au tout debut de la courbe deux vagues voisines peuvent
	# etre a egalite, et l intention du reglage est bien "la place que le boss
	# prend", pas "le budget recule".
	ok(WaveBudget.budget_for(b) < WaveBudget.raw_budget_for(b),
		"la vague de boss porte moins de troupes que son budget brut")
	ok(WaveBudget.budget_for(m) < WaveBudget.raw_budget_for(m),
		"idem pour la vague de mini-boss")
	# Le boss prend PLUS de place que le mini-boss : sinon le palier de monde ne
	# se distingue pas de son intermediaire.
	ok(float(WaveBudget.budget_for(b)) / WaveBudget.raw_budget_for(b)
		< float(WaveBudget.budget_for(m)) / WaveBudget.raw_budget_for(m),
		"le boss laisse moins de place aux troupes que le mini-boss")
	# Et le budget brut, lui, ne recule jamais : la montee de fond est intacte.
	for w in range(2, 40):
		ok(WaveBudget.raw_budget_for(w) > WaveBudget.raw_budget_for(w - 1),
			"vague %d : le budget brut monte toujours" % w)
	# Hors palier, le budget ne recule JAMAIS : la montee reste lisible.
	for w in range(2, 40):
		if WaveBudget.is_boss_wave(w) or WaveBudget.is_miniboss_wave(w):
			continue
		if WaveBudget.is_boss_wave(w - 1) or WaveBudget.is_miniboss_wave(w - 1):
			continue
		ok(WaveBudget.budget_for(w) > WaveBudget.budget_for(w - 1),
			"vague %d : le budget monte hors palier" % w)
	# Pas de saut superieur a x2 entre deux vagues consecutives : la regle
	# d equilibrage maison, appliquee au mode infini.
	for w in range(2, 40):
		ok(WaveBudget.budget_for(w) <= 2 * WaveBudget.budget_for(w - 1),
			"vague %d : pas de doublement du budget d un coup" % w)


## LE DEFAUT QUI A FAILLI PASSER. Premiere version : "un monstre appartient au
## premier acte dont un niveau le liste". Les tests logiques passaient tous, parce
## qu ils tournaient sur un pool fabrique moitie/moitie. Sur le VRAI contenu, les
## pools de niveaux se chevauchent : 11 monstres tombaient dans le monde 0 et les
## mondes 2 et 4 n en recevaient AUCUN. Le fond changeait, le tirage non — la
## demande "le fond pese sur le tirage" n etait pas tenue, et rien ne rougissait.
##
## Ce test regarde donc le contenu REEL et non un pool de test. C est le verrou
## qui manquait.
func _test_chaque_monde_a_une_famille_reelle() -> void:
	var membership: Dictionary = WaveSpawner.build_membership()
	ok(not membership.is_empty(), "le contenu rattache des monstres a des mondes")
	if membership.is_empty():
		return
	var par_monde: Dictionary = {}
	for id in membership:
		var w: int = int(membership[id])
		par_monde[w] = int(par_monde.get(w, 0)) + 1
	# L acte 5 (Seuil divin) n a pas de niveau de campagne : aucun monstre ne peut
	# lui appartenir, et c est voulu (il tire sur tout le bestiaire). Les AUTRES
	# mondes doivent tous avoir une famille, sinon leur fond est un decor vide.
	var sans_famille: Array[String] = []
	for i in WaveBudget.WORLDS.size():
		var act: int = int(WaveBudget.WORLDS[i].get("act", 0))
		if not _acte_a_un_niveau(act):
			continue
		if int(par_monde.get(i, 0)) < 2:
			sans_famille.append("%d (%s)" % [i, String(WaveBudget.WORLDS[i].get("name", ""))])
	ok(sans_famille.is_empty(),
		"tout monde adosse a un acte joue a sa famille de monstres — sans famille : %s"
		% ", ".join(sans_famille))
	# Et la repartition n est pas un tas : aucun monde ne ramasse tout.
	var total: int = membership.size()
	for i in par_monde:
		ok(int(par_monde[i]) < total,
			"le monde %d ne ramasse pas tout le bestiaire (%d sur %d)"
			% [i, int(par_monde[i]), total])
	# Le boss d un monde adosse a un acte doit etre rattache a CE monde, sinon le
	# palier de fin de bloc envoie un boss etranger au lieu.
	var boss_places: int = 0
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.is_boss() and membership.has(d.id):
			boss_places += 1
	ok(boss_places >= 2, "plusieurs boss sont rattaches a un monde (%d)" % boss_places)


func _acte_a_un_niveau(act: int) -> bool:
	for level_id in ContentDB.levels.keys():
		var lvl: LevelDef = ContentDB.levels.get(level_id)
		if lvl != null and lvl.act == act and not lvl.waves.is_empty():
			return true
	return false


## Chaque monde du mode infini doit avoir SON mini-boss.
##
## Le defaut mesure : le Massacre pose un mini-boss toutes les 3 vagues et
## traverse CINQ mondes, mais le jeu n avait qu UN SEUL monstre de type
## MINIBOSS. C etait le meme Gardien a chaque palier, dans chaque monde —
## exactement le defaut corrige pour la campagne.
##
## Le piege qui a failli me tromper : CREER les mini-boss ne suffisait pas.
## `build_membership()` deduit le monde d un monstre de sa DENSITE dans les
## vagues ECRITES ; les quatre nouveaux n apparaissaient dans aucune vague, donc
## ils n appartenaient a aucun monde et le mode infini ne les proposait jamais.
## Une sonde l a montre : ils etaient invisibles malgre leur existence.
## Ce test verifie donc l APPARTENANCE, pas seulement le catalogue.
func _test_chaque_monde_a_son_mini_boss() -> void:
	var minis: Array[EnemyDef] = []
	for e: EnemyDef in ContentDB.enemies.values():
		if e != null and e.kind == GameEnums.EnemyKind.MINIBOSS:
			minis.append(e)
	ok(minis.size() >= 4,
		"le jeu a au moins 4 mini-boss (%d) — un seul les rendait tous identiques"
		% minis.size())

	var membership: Dictionary = WaveSpawner.build_membership()
	var mondes: Dictionary = {}
	for e in minis:
		var w: int = int(membership.get(e.id, -1))
		if w >= 0:
			mondes[w] = true
	# Les mondes adosses a un acte QUI A DES NIVEAUX. Le Seuil divin n en a
	# aucun, donc aucun monstre ne peut lui etre rattache : c est voulu, il y
	# tire uniformement.
	var actes: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		actes[lv.act] = true
	var attendus: int = 0
	for i in WaveBudget.WORLDS.size():
		if actes.has(int(WaveBudget.WORLDS[i].get("act", 0))):
			attendus += 1
	eq(mondes.size(), attendus,
		"chaque monde adosse a un acte a son mini-boss (%d sur %d)"
		% [mondes.size(), attendus])

	# Et ils sont REELLEMENT tires : un mini-boss rattache mais jamais choisi
	# serait du contenu mort qu aucun audit ne voit.
	var pool: Array[EnemyDef] = []
	for e: EnemyDef in ContentDB.enemies.values():
		if e != null and not e.projectile:
			pool.append(e)
	var tires: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	for graine in 12:
		rng.seed = graine
		for vague in range(1, 25):
			var w: WaveDef = WaveBudget.build_wave(vague, pool, rng, pool, membership)
			if w == null:
				continue
			for entree: WaveEntry in w.entries:
				if entree != null and entree.enemy != null 						and entree.enemy.kind == GameEnums.EnemyKind.MINIBOSS:
					tires[entree.enemy.id] = true
	ok(tires.size() >= attendus,
		"chaque monde propose reellement son mini-boss (%d tires sur %d attendus)"
		% [tires.size(), attendus])

class_name WaveBudget
extends RefCounted
## Composition de vagues par budget de puissance.
##
## Chaque monstre a une puissance 1..4. Une vague de budget 8 est une combinaison
## dont les puissances totalisent 8 : par exemple un monstre 4 + deux monstres 2.
## Le budget croit vague apres vague : c est la montee progressive du mode infini.
##
## Logique pure, RNG injecte : deterministe et testable a froid.

## Mesure au banc : a +3 par vague, la vague 4 du mode infini valait deja la
## derniere du niveau 1 et la partie s arretait vers la vague 3. Le mode Massacre
## doit laisser le temps de construire un deck avant de punir.
const BASE_BUDGET: int = 6
const GROWTH_PER_WAVE: int = 2
## Un mini-boss toutes les 3 vagues, un boss toutes les 6 — et le boss FERME le
## bloc de monde, donc BOSS_EVERY == WORLD_EVERY. Trois cadences alignees plutot
## que deux rythmes qui derivent : le joueur peut anticiper la vague suivante.
const MINIBOSS_EVERY: int = 3
const BOSS_EVERY: int = 6
## Au-dela, la difficulte (PV/vitesse) monte aussi, pas seulement le nombre.
const DIFFICULTY_PER_WAVE: float = 0.03

## --- LA DESCENTE A TRAVERS LES MONDES ---
##
## Le mode Massacre n est plus un compteur qui monte sur un decor fixe : c est une
## descente a travers les cinq lieux du jeu. Toutes les WORLD_EVERY vagues le fond
## change, et le lieu PESE sur ce qui apparait (un cimetiere envoie des
## morts-vivants, une forge envoie des colosses).
const WORLD_EVERY: int = 6

## Les mondes, dans l ORDRE DE LA CAMPAGNE. C est le seul ordre lisible : le
## joueur qui debloque le Massacre vient de traverser ces lieux dans cet ordre et
## reconnait ou il est au premier coup d oeil. L argument inverse — "les premieres
## vagues sont trop faciles pour qui a fini le jeu" — ne tient pas : ce qui fait
## la difficulte de la vague 1 est son BUDGET (6 points), pas la famille de
## monstres tiree. Melanger l ordre rendrait le lieu illisible sans rien durcir.
##
## `act` rattache le monde aux niveaux de campagne (LevelDef.act) : c est par lui
## que WaveSpawner.build_membership() sait quels monstres et quel boss appartiennent
## au lieu.
##
## L ACTE 5 (Seuil divin) n a pas de niveau de campagne, donc aucun monstre ne lui
## appartient. C est voulu et non un trou : le Seuil est le lieu ou les quatre
## mondes CONVERGENT, et un lieu sans famille attitree tire uniformement sur tout
## le bestiaire. Son fond existe deja dans assets/backdrops/ ; le mode infini est
## le seul endroit du jeu ou on le voit.
const WORLDS: Array[Dictionary] = [
	{"act": 1, "backdrop": "act1_sky", "name": "Le Monde volant"},
	{"act": 2, "backdrop": "act2_graveyard", "name": "Le Grand Cimetiere"},
	{"act": 3, "backdrop": "act3_demon", "name": "Le Monde demoniaque"},
	{"act": 4, "backdrop": "act4_origin", "name": "Le Monde d origine"},
	{"act": 5, "backdrop": "act5_divine", "name": "Le Seuil divin"},
]

## LE DOSAGE DU LIEU. Un monstre du monde courant est POIDS_LOCAL fois plus
## probable qu un monstre venu d ailleurs.
##
## Pourquoi pas l exclusivite : si le cimetiere n envoyait QUE des morts-vivants,
## un deck specialise contre eux gagnerait pour toujours ses six vagues, et le
## joueur n aurait plus de decision a prendre. Pourquoi pas un simple coup de
## pouce : sous un facteur 2 on ne voit pas la difference, et le changement de
## fond redevient un decor vide.
##
## FACTEUR 6, choisi a la mesure sur le VRAI bestiaire (sonde sur 200 tirages par
## monde) et non sur un pool de test, parce que les familles n ont pas la meme
## taille : 4 monstres pour le Monde volant contre 10 pour le Monde demoniaque.
##
##   poids 4 : 37 a 62 % de monstres du lieu — le plus petit monde ne se lit pas
##   poids 6 : 47 a 70 % — chaque monde se lit, aucun ne verrouille   <-- retenu
##   poids 8 : 55 a 74 % — le plus gros monde commence a etouffer les autres
##
## A 70 %, trois monstres sur dix viennent encore d ailleurs : un deck monte
## contre le lieu reste pris de revers a chaque vague, ce qui est le but.
const LOCAL_WEIGHT: float = 6.0

## Part du budget de troupes qu il reste quand un boss ou un mini-boss occupe la
## vague. Le boss est HORS budget : sans cette reduction, une vague de palier
## envoyait tout son budget de troupes PLUS un boss a 320 PV. Les paliers sont des
## combats de boss, pas des vagues normales avec un boss en plus.
##
## POURQUOI 0,60 ET PAS PLUS BAS. Un creux plus profond viole la regle maison
## "pas de saut superieur a x2 entre deux vagues consecutives" : la vague qui suit
## le palier remonte alors d un coup. Mesure de la courbe : a 0,45 le saut de la
## vague 6 a la 7 valait x2,57, a 0,50 encore x2,25 ; a 0,60 il vaut x1,80, sous
## la limite. C est le test _test_budget_laisse_place_au_boss qui l a attrape.
const BOSS_WAVE_TROOPS: float = 0.60
const MINIBOSS_WAVE_TROOPS: float = 0.80


## Index du monde traverse a la vague n (0..WORLDS.size()-1), en BOUCLANT.
##
## Le bouclage est ce qui rend le mode reellement sans fin : passe le cinquieme
## monde on repart du premier, mais le budget et la difficulte, eux, n ont pas
## ete remis a zero — le deuxieme passage dans le Monde volant envoie les memes
## creatures avec trois fois plus de points. C est la reponse a "que se passe-t-il
## apres le cinquieme monde" : on recommence le tour, pas la partie.
static func world_index_for(wave_number: int) -> int:
	if WORLDS.is_empty():
		return 0
	var bloc: int = maxi(0, wave_number - 1) / WORLD_EVERY
	return bloc % WORLDS.size()


## Numero du tour complet des mondes (1 pour le premier). Sert a l affichage et a
## distinguer un deuxieme passage dans un lieu deja vu.
static func cycle_for(wave_number: int) -> int:
	if WORLDS.is_empty():
		return 1
	var bloc: int = maxi(0, wave_number - 1) / WORLD_EVERY
	return 1 + bloc / WORLDS.size()


## Cle de fond peint (assets/backdrops/) du lieu ou se joue la vague n.
static func backdrop_for(wave_number: int) -> String:
	if WORLDS.is_empty():
		return ""
	return String(WORLDS[world_index_for(wave_number)].get("backdrop", ""))


## Acte de campagne du lieu ou se joue la vague n. C est la cle qui relie le lieu
## aux monstres et aux boss.
static func act_for(wave_number: int) -> int:
	if WORLDS.is_empty():
		return 0
	return int(WORLDS[world_index_for(wave_number)].get("act", 0))


static func world_name_for(wave_number: int) -> String:
	if WORLDS.is_empty():
		return ""
	return String(WORLDS[world_index_for(wave_number)].get("name", ""))


static func is_boss_wave(wave_number: int) -> bool:
	return wave_number > 0 and wave_number % BOSS_EVERY == 0


## Un mini-boss tombe sur les multiples de MINIBOSS_EVERY, SAUF quand le boss
## occupe deja la vague : les deux ne se cumulent pas.
static func is_miniboss_wave(wave_number: int) -> bool:
	return wave_number > 0 and wave_number % MINIBOSS_EVERY == 0 \
		and not is_boss_wave(wave_number)


## Budget de troupes AVANT la place laissee au boss : la montee de fond du mode
## infini, qui ne recule jamais. C est sur elle que se mesure la reduction d un
## palier, pas sur la vague precedente.
static func raw_budget_for(wave_number: int) -> int:
	return BASE_BUDGET + GROWTH_PER_WAVE * maxi(0, wave_number - 1)


## Budget de puissance de la vague n (n commence a 1).
##
## Les vagues de palier portent MOINS de troupes : le boss occupe la place. Le
## budget brut continue de monter derriere, donc la vague 7 reprend la montee la
## ou la 5 l avait laissee — il n y a pas de rechute durable.
static func budget_for(wave_number: int) -> int:
	var brut: int = raw_budget_for(wave_number)
	if is_boss_wave(wave_number):
		return maxi(1, int(round(brut * BOSS_WAVE_TROOPS)))
	if is_miniboss_wave(wave_number):
		return maxi(1, int(round(brut * MINIBOSS_WAVE_TROOPS)))
	return brut


static func difficulty_for(wave_number: int) -> float:
	return 1.0 + DIFFICULTY_PER_WAVE * maxi(0, wave_number - 1)


## Tire des monstres du pool jusqu a epuiser le budget. Ne depasse jamais.
static func compose(budget: int, pool: Array[EnemyDef], rng: RandomNumberGenerator) -> Array[EnemyDef]:
	return compose_for_world(budget, pool, rng, -1, {})


## Comme `compose()`, mais le LIEU pese sur le tirage.
##
## `world` est un index de monde (-1 = aucun lieu, tirage uniforme) et
## `membership` associe un id de monstre a son index de monde. Un monstre du lieu
## courant pese LOCAL_WEIGHT, les autres pesent 1 : le lieu se lit sans etre un
## verrou. Un monstre dont le monde est inconnu est traite comme etranger, jamais
## exclu — sinon un ajout de contenu non classe disparaitrait du mode infini.
static func compose_for_world(budget: int, pool: Array[EnemyDef],
		rng: RandomNumberGenerator, world: int = -1,
		membership: Dictionary = {}) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	var remaining: int = budget
	var guard: int = 256
	while remaining > 0 and guard > 0:
		guard -= 1
		var affordable: Array[EnemyDef] = []
		var weights: Array[float] = []
		var total: float = 0.0
		for def in pool:
			if def == null or def.is_boss() or def.power > remaining:
				continue
			# Un PROJECTILE n est pas une creature qu on fait descendre en vague :
			# il est tire par un monstre. En laisser un dans le pool remplissait
			# le budget de boules de poison inertes.
			if def.projectile:
				continue
			var w: float = 1.0
			if world >= 0 and int(membership.get(def.id, -1)) == world:
				w = LOCAL_WEIGHT
			affordable.append(def)
			weights.append(w)
			total += w
		if affordable.is_empty():
			break
		var pick: EnemyDef = affordable[affordable.size() - 1]
		var roll: float = rng.randf() * total
		var acc: float = 0.0
		for i in affordable.size():
			acc += weights[i]
			if roll <= acc:
				pick = affordable[i]
				break
		out.append(pick)
		remaining -= pick.power
	return out


static func total_power(defs: Array[EnemyDef]) -> int:
	var n: int = 0
	for d in defs:
		if d != null:
			n += d.power
	return n


## Boss (ou mini-boss) du lieu. On prend celui du monde quand il en a un, sinon
## n importe lequel : un monde sans boss attitre ne doit pas SAUTER son palier,
## sinon la vague 6 du cinquieme monde serait une vague ordinaire.
static func pick_boss(bosses: Array[EnemyDef], kind: GameEnums.EnemyKind,
		world: int = -1, membership: Dictionary = {}) -> EnemyDef:
	var repli: EnemyDef = null
	for d in bosses:
		if d == null or d.kind != kind:
			continue
		if repli == null:
			repli = d
		if world >= 0 and int(membership.get(d.id, -1)) == world:
			return d
	return repli


## Construit une WaveDef jouable pour la vague n.
##
## `membership` (id de monstre -> index de monde) est FACULTATIF : sans lui, le
## tirage reste uniforme et le mode infini se comporte comme avant. C est ce qui
## permet aux tests et aux appelants anciens de ne rien savoir des mondes.
static func build_wave(wave_number: int, pool: Array[EnemyDef],
		rng: RandomNumberGenerator, bosses: Array[EnemyDef] = [],
		membership: Dictionary = {}) -> WaveDef:
	var w := WaveDef.new()
	w.id = StringName("proc_%d" % wave_number)
	w.duration = 25.0
	w.difficulty = difficulty_for(wave_number)
	var world: int = world_index_for(wave_number) if not membership.is_empty() else -1

	var picks: Array[EnemyDef] = compose_for_world(budget_for(wave_number), pool,
		rng, world, membership)
	# Regroupe par type pour espacer les apparitions d un meme groupe.
	var counts: Dictionary = {}
	var order: Array[EnemyDef] = []
	for d in picks:
		if not counts.has(d):
			counts[d] = 0
			order.append(d)
		counts[d] = int(counts[d]) + 1
	var offset: float = 0.0
	for d in order:
		var e := WaveEntry.new()
		e.enemy = d
		e.count = int(counts[d])
		# Les faibles arrivent serres, les forts espaces.
		e.spawn_delay = 0.6 + 0.35 * d.power
		e.start_offset = offset
		offset += 1.5
		w.entries.append(e)

	# Boss et mini-boss ponctuels, hors budget.
	if not bosses.is_empty():
		var boss: EnemyDef = null
		if is_boss_wave(wave_number):
			boss = pick_boss(bosses, GameEnums.EnemyKind.BOSS, world, membership)
			w.is_boss = boss != null
		elif is_miniboss_wave(wave_number):
			boss = pick_boss(bosses, GameEnums.EnemyKind.MINIBOSS, world, membership)
			w.is_miniboss = boss != null
		if boss != null:
			var be := WaveEntry.new()
			be.enemy = boss
			be.count = 1
			be.spawn_delay = 1.0
			be.start_offset = 0.0
			w.entries.insert(0, be)
			w.duration += 15.0
	return w

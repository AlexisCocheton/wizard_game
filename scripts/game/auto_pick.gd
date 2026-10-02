class_name AutoPick
extends RefCounted
## Les choix que fait la partie quand PERSONNE ne peut toucher l ecran : le banc
## d equilibrage (tools/sim_balance.gd) et les parties headless des tests.
##
## POURQUOI UNE REGLE ET PAS "LA PREMIERE OPTION"
## ----------------------------------------------
## Le banc prenait toujours la premiere option proposee. Tant que l offre
## d amelioration etait un trio FIXE, la premiere etait l identite du sort en
## forme forte (+30 % degats) : le bot jouait comme un joueur raisonnable par
## accident. Depuis que l offre est TIREE au hasard puis melangee, la premiere
## option est une voie au hasard, et le banc mesurait un joueur qui choisit a
## pile ou face : lvl_16 est tombe de 25 a 14 victoires sur 30 sans que le jeu
## ait change.
##
## La regle doit rester celle d un joueur RAISONNABLE, pas d un joueur parfait :
## elle ne lit que ce qui est a l ecran (les voies proposees, la carte, les
## monstres deja croises), jamais l avenir (vagues a venir, tirages suivants).

## Sous ce facteur moyen de degats, un sort est "resiste" par les monstres
## croises. Facteur JOUE (la table est deja accentuee, EnemyDef.accentuate) :
## 0,85 = 15 % des degats perdus, une resistance de 0,91 ecrite dans make_content.
const RESISTED: float = 0.85
## Vrai : l ANCIEN comportement, toujours la premiere option, pour les
## ameliorations (first_upgrade) ou les cartes (first_offer). Gardes pour que le
## banc puisse mesurer ce que chaque regle change (tools/sim_balance.gd,
## --premiere), jamais leves par le jeu.
static var first_upgrade: bool = false
static var first_offer: bool = false


## Voie d amelioration retenue parmi `paths` (offre de RunState), en indice.
##
## Dans l ordre, la premiere qui existe :
##   1. la FORTE sur l axe d identite du sort, a son prix naturel (le libelle le
##      plus lisible : "+30 % degats, -15 % vitesse") ;
##   2. la FORTE sur l identite, payee ailleurs ;
##   3. la FORTE sur la vitesse de lancement (prix naturel, puis l autre) ;
##   4. la LEGERE sur l identite ;
##   5. la premiere.
## Chaque rang ne designe qu UNE voie de l offre : le choix ne depend donc pas de
## l ordre d affichage, sauf au dernier recours (verrouille par test_auto_pick).
## C est ce que fait un joueur qui a choisi ce sort pour ce qu il fait : il le
## pousse dans son sens. Il ne compare pas les dix axes au pour cent pres.
static func upgrade_index(card: SpellCard, paths: Array) -> int:
	if paths.is_empty() or first_upgrade:
		return 0
	var identite: StringName = RunState.upgrade_identity_axis(card)
	var naturel: StringName = StringName("%s_%s" % [identite, RunState.UP_STRONG])
	var vitesse: StringName = StringName("%s_%s" % [RunState.UP_CAST, RunState.UP_STRONG])
	var rangs: Array = [
		func(v: Dictionary) -> bool: return StringName(v.get("id", &"")) == naturel,
		func(v: Dictionary) -> bool: return _is(v, identite, RunState.UP_STRONG),
		func(v: Dictionary) -> bool: return StringName(v.get("id", &"")) == vitesse,
		func(v: Dictionary) -> bool: return _is(v, RunState.UP_CAST, RunState.UP_STRONG),
		func(v: Dictionary) -> bool: return _is(v, identite, RunState.UP_LIGHT),
	]
	for regle: Callable in rangs:
		for i in paths.size():
			if paths[i] is Dictionary and regle.call(paths[i]):
				return i
	return 0


static func _is(v: Dictionary, axis: StringName, form: StringName) -> bool:
	return StringName(v.get("axis", &"")) == axis and StringName(v.get("form", &"")) == form


## Carte retenue parmi `offer` (montee de niveau), en indice.
##
## `seen` : les monstres DEJA croises dans la partie. Un joueur les a vus a
## l ecran ; il ne connait pas ceux des vagues suivantes.
##
## LA PREMIERE CARTE PROPOSEE, SAUF SI LES MONSTRES CROISES LA RESISTENT. Chaque
## case de l offre est un tirage independant dans le pool du niveau
## (RunState.offer_choices) : la premiere n est donc pas "la plus mauvaise", c est
## une carte au hasard du pool, et la prendre revient a garnir le deck comme le
## pool le propose. La seule erreur qu on corrige est celle qu un joueur ne fait
## qu une fois : prendre un sort de feu contre des vers de feu.
##
## Une regle plus "raisonnable" a ete MESUREE et rejetee (21 niveaux, puis 90
## parties sur lvl_13, lvl_16 et lvl_20) : "un sort qui frappe, puis la rarete la
## plus haute" coutait 11 a 21 points de victoire. Le bot prenait le meme sort a
## chaque montee (Meteore x149 sur lvl_20, Trait arcanique x124 sur lvl_16) :
## un deck qui se referme sur une carte lente perd ce que la variete du pool
## apportait (controle, marque, zones).
static func offer_index(offer: Array, seen: Array) -> int:
	if offer.size() <= 1 or first_offer:
		return 0
	var best: int = 0
	var best_f: float = -1.0
	for i in offer.size():
		var f: float = element_factor(offer[i] as SpellCard, seen)
		if f >= RESISTED:
			return i
		if f > best_f:
			best_f = f
			best = i
	return best


## Facteur moyen de degats de la carte contre les monstres croises (1 = neutre).
## Un passif, une carte sans element ou une partie sans monstre croise : 1.
static func element_factor(card: SpellCard, seen: Array) -> float:
	if card == null or card.is_passive or seen.is_empty():
		return 1.0
	var somme: float = 0.0
	var n: int = 0
	for d in seen:
		var def: EnemyDef = d as EnemyDef
		if def == null:
			continue
		somme += def.resistance_to_tags(card.tags)
		n += 1
	return somme / float(n) if n > 0 else 1.0


## EPURATION (vague 8) : les exemplaires a retirer quand personne ne peut
## choisir a l ecran (banc, tests headless). Un element par exemplaire, au plus
## `max_count`, dans la forme que lit RunState.resolve_purge.
##
## LA REGLE : retirer ce qui pese le moins. A defaut de mesurer la force d un
## sort, on prend la RARETE la plus basse (les communes), et parmi elles la carte
## qui a le PLUS d exemplaires : en retirer une copie amincit le deck sans faire
## disparaitre un sort. A egalite, l id le plus petit, pour que le choix ne
## depende pas de l ordre d affichage (meme exigence que pour les ameliorations).
##
## LE PLANCHER : on ne descend jamais sous GameConfig.MAX_HAND_SIZE cartes en
## tout. Une main pleine doit rester possible ; un bot qui viderait son deck
## mesurerait au banc une partie qu aucun joueur ne choisirait de jouer.
## Ancien comportement (2 cartes du dessus de la pioche, au hasard) : il n est
## plus le geste du joueur, le banc ne le garde donc pas.
static func purge_choice(groups: Array, max_count: int) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	if max_count <= 0:
		return out
	var restant: Dictionary = {}
	var total: int = 0
	var cartes: Array[SpellCard] = []
	for g in groups:
		if not (g is Dictionary) or not (g.get("card") is SpellCard):
			continue
		var c: SpellCard = g["card"]
		restant[c.id] = int(g.get("total", 0))
		total += int(g.get("total", 0))
		cartes.append(c)
	while out.size() < max_count and total > GameConfig.MAX_HAND_SIZE:
		var pire: SpellCard = null
		for c in cartes:
			if int(restant[c.id]) <= 0:
				continue
			if pire == null or _weaker(c, pire, restant):
				pire = c
		if pire == null:
			break
		out.append(pire)
		restant[pire.id] = int(restant[pire.id]) - 1
		total -= 1
	return out


static func _weaker(a: SpellCard, b: SpellCard, restant: Dictionary) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	if int(restant[a.id]) != int(restant[b.id]):
		return int(restant[a.id]) > int(restant[b.id])
	return String(a.id) < String(b.id)

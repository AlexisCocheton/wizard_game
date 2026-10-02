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
##
## Trois familles de choix vivent ici : l amelioration (upgrade_index), la carte
## a la montee (offer_index), et le GESTE — quelle carte jouer sur qui
## (try_play, deplace du banc d equilibrage). Le banc des objectifs
## (tools/objective_bench.gd) y ajoute une POLITIQUE par objectif vise
## (politique_pour, en bas du fichier).

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


# =============================================================================
# LE GESTE : quelle carte jouer, sur qui (deplace de tools/sim_balance.gd)
# =============================================================================
#
# C etait `_try_play` du banc d equilibrage. Il vit ici pour que le banc des
# objectifs (tools/objective_bench.gd) joue EXACTEMENT comme lui, a la politique
# d objectif pres : deux copies du geste auraient fini par diverger, et deux
# mesures faites par deux bots differents ne se comparent pas. Sans politique,
# le comportement est celui du banc, a l identique.


## Le monstre peut-il prendre des degats, a ce qu en voit le joueur ?
##
## Un monstre dans le HALO d un Gardien-totem est intouchable (Battlefield.
## is_shielded_by_aura) et le halo est dessine a l ecran. Le bot visait pourtant
## le plus avance, protege ou non : sur la cour des rois morts, dont toute la
## lecon est « abats d abord celui qui protege », il vidait sa main sur des
## monstres intouchables pendant que le totem avancait. `naive` rend l ancien
## comportement, pour mesurer (sim_balance --visee-naive).
static func touchable(g: GameController, e: Enemy, naive: bool = false) -> bool:
	if e == null or not is_instance_valid(e) or e.hp <= 0.0:
		return false
	return naive or not g.battlefield.is_shielded_by_aura(e)


## Joue une carte si possible. Vrai si une carte est partie.
##
## Sans politique : vise le monstre TOUCHABLE le plus avance (a defaut, le plus
## avance tout court), essaie les cartes dans l ordre de la main, et pose une
## zone la ou il y a le PLUS de monstres plutot que sur le plus avance — c est
## ce qui fait la difference entre subir et nettoyer.
##
## Avec une politique (banc des objectifs) : memes regles, mais la politique
## retire les cartes interdites, met devant les cartes demandees, choisit
## d abord les monstres a viser et ne frappe jamais ceux qu elle epargne.
static func try_play(g: GameController, p: Politique = null, naive: bool = false) -> bool:
	if RunState.hand.is_empty():
		return false
	var cible: Enemy = choose_target(g, p, naive)
	if cible == null:
		return false
	for card: SpellCard in hand_order(g, p):
		var aim: Vector2 = cible.position
		if card.targeting == GameEnums.Targeting.POSITION:
			var r: float = zone_radius(card)
			aim = best_cluster(g, r, cible.position, naive, p)
			# Une zone ne doit pas mordre ce que la politique epargne.
			if p != null and p.zone_mord_un_epargne(g, aim, r):
				continue
		if g.play_card(card, aim, cible):
			return true
	return false


## La cible : passe 0, un monstre que la politique veut viser d abord ; passe 1,
## le plus avance des monstres touchables ; passe 2, le plus avance tout court.
## Un monstre epargne par la politique n est jamais retenu : si tous le sont, le
## bot ne joue pas (il attend, comme un joueur qui laisse passer).
static func choose_target(g: GameController, p: Politique = null, naive: bool = false) -> Enemy:
	var cible: Enemy = null
	var y_max: float = -1e9
	for passe in 3:
		if passe == 0 and p == null:
			continue
		for e in g.battlefield.enemies:
			if e == null or not is_instance_valid(e) or e.hp <= 0.0:
				continue
			if p != null and p.epargne(e):
				continue
			if passe <= 1 and not touchable(g, e, naive):
				continue
			if passe == 0 and not p.vise(e):
				continue
			if e.position.y > y_max:
				y_max = e.position.y
				cible = e
		if cible != null:
			break
	return cible


## L ordre dans lequel les cartes de la main sont essayees. Sans politique,
## l ordre de la main.
static func hand_order(g: GameController, p: Politique = null) -> Array[SpellCard]:
	var main: Array[SpellCard] = []
	main.assign(RunState.hand.duplicate())
	if p == null:
		return main
	var d_abord: Array[SpellCard] = []
	var ensuite: Array[SpellCard] = []
	var pleine: bool = RunState.hand.size() >= GameConfig.MAX_HAND_SIZE
	for c: SpellCard in main:
		if c == null or p.interdit(c):
			continue
		if p.garde(g, c) and not pleine:
			continue
		if p.prefere(g, c):
			d_abord.append(c)
		else:
			ensuite.append(c)
	d_abord.append_array(ensuite)
	return d_abord


static func zone_radius(card: SpellCard) -> float:
	var r: float = 0.0
	for spec in card.effects:
		if spec != null:
			r = maxf(r, spec.radius)
	return maxf(r, 60.0)


## Centre du groupe le plus fourni. Une politique qui pose ses zones sur une
## espece (zones_sur) ne compte que cette espece, si elle est sur le terrain.
static func best_cluster(g: GameController, radius: float, defaut: Vector2,
		naive: bool = false, p: Politique = null) -> Vector2:
	var sur_espece: bool = p != null and p.zones_sur != &"" \
		and Politique.present(g, p.zones_sur)
	var best: Vector2 = defaut
	var best_n: int = 0
	for e in g.battlefield.enemies:
		if not _compte(g, e, naive, p, sur_espece):
			continue
		var n: int = 0
		for o in g.battlefield.enemies:
			if _compte(g, o, naive, p, sur_espece) and o.position.distance_to(e.position) <= radius:
				n += 1
		# A nombre egal, on prefere le groupe le plus avance.
		if n > best_n or (n == best_n and e.position.y > best.y):
			best_n = n
			best = e.position
	return best


## Le monstre compte-t-il dans un groupe vise par une zone ?
static func _compte(g: GameController, e: Enemy, naive: bool, p: Politique,
		sur_espece: bool) -> bool:
	if not touchable(g, e, naive):
		return false
	if p == null:
		return true
	if p.epargne(e):
		return false
	return not sur_espece or Politique.de_l_espece(e, p.zones_sur)


# =============================================================================
# LE BOT QUI VISE UN OBJECTIF (banc des objectifs, tools/objective_bench.gd)
# =============================================================================
#
# Mesurer « combien de parties reussissent cet objectif » avec un bot qui
# l ignore mesurerait le hasard : personne ne gagne « sans Boule de feu » en
# jouant la Boule de feu des qu elle sort. Le banc des objectifs joue donc comme
# le bot du banc (ci-dessus, et les choix d offre et d amelioration), PLUS ce que
# ferait un joueur qui VISE l objectif. Une politique par cle d objectif, et
# seulement ce qu un joueur lit a l ecran (cartes, especes, garde levee, chemin
# deja fait par un monstre), jamais l avenir.
#
# | cle                     | politique                                                    |
# |-------------------------|--------------------------------------------------------------|
# | card_casts              | joue d abord la carte, la prend aux montees ; jusqu au compte |
# | same_card_casts         | idem avec la carte la plus nombreuse du deck                 |
# | element_casts           | idem avec les cartes de l element                            |
# | no_card                 | ne joue jamais la carte, ne la prend pas aux montees         |
# | no_card_tag             | idem pour toute carte portant le tag                         |
# | no_card_key             | idem pour toute carte portant la cle d effet                 |
# | no_legendary_used       | idem pour toute legendaire                                   |
# | max_distinct_cast       | ne joue que les `count` cartes les plus nombreuses du deck   |
# | no_passive              | ne prend aucun passif aux montees                            |
# | kill_type_one_cast      | zones d abord quand l espece est la, posees sur son plus     |
# |                         | gros groupe ; jusqu au compte                                |
# | kill_type_with_card     | la carte d abord, sur l espece (zone : sur son groupe) ; la  |
# |                         | carte attend l espece, sauf main pleine ; jusqu au compte    |
# | no_hit_from             | vise l espece d abord, zones sur son groupe                  |
# | hit_from                | ne frappe jamais l espece tant qu elle n a pas touche        |
# | enemy_travel            | laisse marcher l espece jusqu a la distance, puis la vise    |
# |                         | d abord ; sans espece : bot tel quel                         |
# | kill_flying             | vise les volants d abord ; jusqu au compte                   |
# | boss_quick_after_revive | vise d abord les monstres releves                            |
# | never_hit_reflect       | ne frappe jamais une garde de renvoi levee (zones comprises) |
# |                         | : il attend qu elle retombe                                  |
# | never_dropped_speed,    | bot tel quel : il vise deja le plus avance et nettoie par    |
# | no_damage_taken,        | zones, c est ce que fait un joueur pour ne pas etre touche,  |
# | no_enemy_past,          | tenir sa vitesse ou finir vite                               |
# | win_above_speed,        |                                                              |
# | win_under_time          |                                                              |
# | multi_kill              | bot tel quel : il pose deja ses zones sur le plus gros groupe |
# | win_below_speed         | bot tel quel : le seul levier (se laisser toucher a la fin)  |
# |                         | parie la partie, un joueur ne le joue pas a coup sur         |
#
# « Jusqu au compte » : des que l objectif est ATTEINT en cours de partie
# (ObjectiveChecker.evaluate, qui ne lit que des compteurs pour ces cles), la
# preference tombe et le bot rejoue normalement — c est ce que fait un joueur
# qui a fait son compte.
#
# Le bot prend quand meme une carte interdite a la montee si l offre n a QUE des
# cartes interdites (il n y a pas de refus) ; il ne la joue jamais. Un passif,
# lui, s equipe des qu il est pris : no_passive est alors perdu, c est le cout
# reel de l offre.

## Parametre d objectif, ecrit en cle String ou StringName (`defaut` sinon).
static func _p(o: ObjectiveDef, nom: String, defaut: Variant) -> Variant:
	if o.params.has(nom):
		return o.params[nom]
	return o.params.get(StringName(nom), defaut)


## La politique du bot qui vise `o` dans le niveau `lv`. Jamais null ; neutre
## (bot du banc tel quel) pour les cles qui n en ont pas.
static func politique_pour(o: ObjectiveDef, lv: LevelDef) -> Politique:
	var p := Politique.new()
	p.objectif = o
	if o == null:
		return p
	var carte: StringName = StringName(str(_p(o, "card", "")))
	var espece: StringName = StringName(str(_p(o, "enemy", "")))
	match o.check_key:
		&"card_casts":
			p.d_abord[carte] = true
			p.jusqu_au_compte = true
			p.resume = "joue d abord %s" % carte
		&"same_card_casts":
			var plus: Array[StringName] = Politique.cartes_du_deck(lv, 1)
			if not plus.is_empty():
				p.d_abord[plus[0]] = true
				p.resume = "joue d abord %s, la plus nombreuse du deck" % plus[0]
			p.jusqu_au_compte = true
		&"element_casts":
			p.tag_d_abord = ObjectiveChecker.tag_from_name(_p(o, "element", ""))
			p.jusqu_au_compte = true
			p.resume = "joue d abord ses sorts %s" % _p(o, "element", "")
		&"no_card":
			p.interdites[carte] = true
			p.resume = "ne joue jamais %s" % carte
		&"no_card_tag":
			p.tag_interdit = ObjectiveChecker.tag_from_name(_p(o, "tag", ""))
			p.resume = "ne joue jamais de sort %s" % _p(o, "tag", "")
		&"no_card_key":
			p.cle_interdite = StringName(str(_p(o, "key", "")))
			p.resume = "ne joue jamais l effet %s" % p.cle_interdite
		&"no_legendary_used":
			p.sans_legendaire = true
			p.resume = "ne joue jamais de legendaire"
		&"max_distinct_cast":
			for id: StringName in Politique.cartes_du_deck(lv, int(_p(o, "count", 1))):
				p.seules[id] = true
			p.resume = "ne joue que %s" % [p.seules.keys()]
		&"no_passive":
			p.sans_passif = true
			p.resume = "ne prend aucun passif"
		&"kill_type_one_cast":
			p.zones_sur = espece
			p.zones_d_abord = true
			p.jusqu_au_compte = true
			p.resume = "zones d abord, sur le groupe de %s" % espece
		&"kill_type_with_card":
			p.d_abord[carte] = true
			p.garder = carte
			p.viser = espece
			p.zones_sur = espece
			p.jusqu_au_compte = true
			p.resume = "joue %s sur %s d abord, la garde pour lui" % [carte, espece]
		&"no_hit_from":
			p.viser = espece
			p.zones_sur = espece
			p.resume = "vise %s d abord" % espece
		&"hit_from":
			p.epargner = espece
			p.jusqu_au_compte = true
			p.resume = "ne frappe pas %s avant d en etre touche" % espece
		&"enemy_travel":
			if espece != &"":
				p.epargner = espece
				p.epargner_jusqu_a = float(_p(o, "distance", 0.0))
				p.viser = espece
				p.jusqu_au_compte = true
				p.resume = "laisse marcher %s %d px, puis le vise" % [espece,
					int(p.epargner_jusqu_a)]
		&"kill_flying":
			p.viser_volants = true
			p.jusqu_au_compte = true
			p.resume = "vise les volants d abord"
		&"boss_quick_after_revive":
			p.viser_releves = true
			p.resume = "vise les monstres releves d abord"
		&"never_hit_reflect":
			p.sans_renvoi = true
			p.resume = "ne frappe jamais une garde de renvoi"
	return p


## Carte retenue parmi `offer` par un bot qui vise un objectif : jamais une
## carte que la politique interdit (sauf si l offre n a que cela), d abord une
## carte qu elle demande, sinon la regle d offer_index sur ce qui reste.
## Politique nulle ou neutre : offer_index, a l identique.
static func offer_index_for(offer: Array, seen: Array, p: Politique) -> int:
	if p == null or p.neutre():
		return offer_index(offer, seen)
	var permis: Array = []
	var indices: Array[int] = []
	for i in offer.size():
		var c: SpellCard = offer[i] as SpellCard
		if c != null and not p.interdit_a_l_offre(c):
			permis.append(c)
			indices.append(i)
	if permis.is_empty():
		return offer_index(offer, seen)
	for k in permis.size():
		if p.demande_a_l_offre(permis[k]):
			return indices[k]
	return indices[offer_index(permis, seen)]


class Politique extends RefCounted:
	## L objectif vise (pour « jusqu au compte » et le rapport).
	var objectif: ObjectiveDef = null
	## Une phrase pour le rapport du banc.
	var resume: String = "bot du banc tel quel"
	## Ids de cartes a jouer d abord, et a prendre aux montees.
	var d_abord: Dictionary = {}
	## Tag a jouer d abord (element_casts), -1 sinon.
	var tag_d_abord: int = -1
	## Cartes jamais jouees, evitees aux montees.
	var interdites: Dictionary = {}
	var tag_interdit: int = -1
	var cle_interdite: StringName = &""
	var sans_legendaire: bool = false
	var sans_passif: bool = false
	## max_distinct_cast : non vide, SEULES ces cartes se jouent.
	var seules: Dictionary = {}
	## Espece a viser d abord ; volants, releves a viser d abord.
	var viser: StringName = &""
	var viser_volants: bool = false
	var viser_releves: bool = false
	## Espece jamais frappee ; avec epargner_jusqu_a > 0, seulement tant que le
	## monstre n a pas marche cette distance (enemy_travel).
	var epargner: StringName = &""
	var epargner_jusqu_a: float = 0.0
	## Ne frappe jamais une garde de renvoi levee.
	var sans_renvoi: bool = false
	## Espece sur laquelle poser les zones ; zones jouees d abord quand elle est la.
	var zones_sur: StringName = &""
	var zones_d_abord: bool = false
	## Carte gardee en main tant que l espece `viser` n est pas sur le terrain.
	var garder: StringName = &""
	## Vrai : preferences et epargne tombent une fois l objectif atteint.
	var jusqu_au_compte: bool = false

	## Aucun ecart avec le bot du banc : les objectifs a politique neutre d un
	## meme niveau se mesurent sur les MEMES parties.
	func neutre() -> bool:
		return d_abord.is_empty() and tag_d_abord < 0 and interdites.is_empty() \
			and tag_interdit < 0 and cle_interdite == &"" and not sans_legendaire \
			and not sans_passif and seules.is_empty() and viser == &"" \
			and not viser_volants and not viser_releves and epargner == &"" \
			and not sans_renvoi and zones_sur == &"" and garder == &""

	## L objectif est-il deja acquis en cours de partie ? Seulement pour les cles
	## « jusqu au compte », dont evaluate ne lit que des compteurs.
	func atteint() -> bool:
		return jusqu_au_compte and objectif != null and ObjectiveChecker.evaluate(objectif)

	func interdit(c: SpellCard) -> bool:
		if c == null:
			return true
		if interdites.has(c.id):
			return true
		if tag_interdit >= 0 and c.tags.has(tag_interdit):
			return true
		if cle_interdite != &"" and cle_interdite in c.effect_keys():
			return true
		if sans_legendaire and c.rarity == GameEnums.Rarity.LEGENDARY:
			return true
		return not seules.is_empty() and not c.is_passive and not seules.has(c.id)

	func interdit_a_l_offre(c: SpellCard) -> bool:
		return interdit(c) or (sans_passif and c.is_passive)

	func demande_a_l_offre(c: SpellCard) -> bool:
		if atteint():
			return false
		return d_abord.has(c.id) or (tag_d_abord >= 0 and c.tags.has(tag_d_abord))

	## Carte a essayer avant les autres.
	func prefere(g: GameController, c: SpellCard) -> bool:
		if atteint():
			return false
		if d_abord.has(c.id) or (tag_d_abord >= 0 and c.tags.has(tag_d_abord)):
			return true
		return zones_d_abord and c.targeting == GameEnums.Targeting.POSITION \
			and present(g, zones_sur)

	## Carte retenue en main : elle attend son espece.
	func garde(g: GameController, c: SpellCard) -> bool:
		return garder != &"" and c.id == garder and not atteint() and not present(g, viser)

	func vise(e: Enemy) -> bool:
		if e == null or e.definition == null:
			return false
		if viser_releves and e.has_revived():
			return true
		if atteint():
			return false
		if viser_volants and e.definition.flying:
			return true
		if viser != &"" and de_l_espece(e, viser):
			# enemy_travel : seulement une fois son chemin fait.
			return epargner_jusqu_a <= 0.0 or chemin(e) >= epargner_jusqu_a
		return false

	func epargne(e: Enemy) -> bool:
		if e == null or e.definition == null:
			return false
		if sans_renvoi and e.is_reflecting():
			return true
		if epargner == &"" or not de_l_espece(e, epargner) or atteint():
			return false
		return epargner_jusqu_a <= 0.0 or chemin(e) < epargner_jusqu_a

	## Une zone posee en `aim` toucherait-elle un monstre epargne ?
	func zone_mord_un_epargne(g: GameController, aim: Vector2, radius: float) -> bool:
		if epargner == &"" and not sans_renvoi:
			return false
		for e in g.battlefield.enemies:
			if e != null and is_instance_valid(e) and e.hp > 0.0 and epargne(e) \
					and e.position.distance_to(aim) <= radius + e.radius():
				return true
		return false

	static func de_l_espece(e: Enemy, espece: StringName) -> bool:
		return e != null and is_instance_valid(e) and e.definition != null \
			and e.definition.id == espece

	## Chemin deja marche par le monstre (le releve d enemy_travel).
	static func chemin(e: Enemy) -> float:
		return float(e.get_meta(RunState.TRAVEL_META, 0.0))

	static func present(g: GameController, espece: StringName) -> bool:
		if espece == &"":
			return false
		for e in g.battlefield.enemies:
			if de_l_espece(e, espece) and e.hp > 0.0:
				return true
		return false

	## Les `n` cartes (sorts) les plus nombreuses du deck du niveau, par ids ;
	## a egalite, la premiere rencontree dans le deck.
	static func cartes_du_deck(lv: LevelDef, n: int) -> Array[StringName]:
		var compte: Dictionary = {}
		var ordre: Array[StringName] = []
		if lv != null:
			for c: SpellCard in lv.exploration_deck:
				if c == null or c.is_passive:
					continue
				if not compte.has(c.id):
					ordre.append(c.id)
				compte[c.id] = int(compte.get(c.id, 0)) + 1
		var tri: Array[StringName] = ordre.duplicate()
		tri.sort_custom(func(a: StringName, b: StringName) -> bool:
			if int(compte[a]) != int(compte[b]):
				return int(compte[a]) > int(compte[b])
			return ordre.find(a) < ordre.find(b))
		return tri.slice(0, maxi(n, 0))

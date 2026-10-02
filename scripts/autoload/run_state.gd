extends Node
## Etat d'une partie : deck, main, defausse, XP, niveau, vagues, objectifs.
## Logique pure pilotable par tick(delta) : aucun noeud requis.

signal card_drawn(card: SpellCard)
signal hand_changed()
signal deck_changed()
signal xp_gained(amount: int)
signal level_up(new_level: int)
signal wave_changed(index: int)
signal objective_failed(objective_id: StringName)
signal offer_ready(cards: Array[SpellCard])
signal offer_taken(card: SpellCard)

var deck: Array[SpellCard] = []
var hand: Array[SpellCard] = []

## REGARD PETRIFIANT — les cartes de la main rendues injouables par les gorgones
## vivantes sur le terrain. Le ledger vit ICI et non dans Battlefield parce que
## c est la MAIN qui est petrifiee : le terrain ne fait que nommer un nombre.
##
## Une liste de cartes et non un compte : le joueur doit voir LESQUELLES sont
## gelees, et elles doivent rester les MEMES d une image a l autre. Un compte
## obligerait a re-tirer les victimes a chaque rafraichissement, la petrification
## sauterait de carte en carte et plus rien ne serait planifiable.
##
## UN EXEMPLAIRE, PAS UNE CARTE. Les copies d une meme carte partagent la MEME
## ressource SpellCard : un registre qui comparait les ressources gelait toutes
## les copies d un coup (vu en capture : deux regards, quatre cartes figees).
## Chaque entree retient donc la carte ET sa position dans la main — voir Tenue.
var _blocked: Array[Tenue] = []
## VOLEUR DE SORTS — exemplaires de la main tenus par un voleur vivant. Separes
## des petrifies : une gorgone gele un NOMBRE de cartes, un voleur tient UNE carte
## precise qu il va lancer. Les deux sont injouables, mais le joueur doit lire
## laquelle va lui revenir dans la figure.
var _stolen: Array[Tenue] = []


## Un exemplaire tenu (petrifie ou vole). La carte seule ne suffit pas a le
## designer — deux copies sont la meme ressource — et la position seule ne
## suffit pas a le verifier : la carte sert de controle quand la main bouge
## par un chemin que RunState ne voit pas (un test qui la reconstruit).
##
## `id` est l identite STABLE de l exemplaire tenu, celle que garde un voleur :
## la position se decale des qu une carte part a sa gauche, et la carte est
## partagee par ses copies. Seul l id designe toujours le meme exemplaire.
class Tenue:
	var card: SpellCard
	var slot: int
	var id: int

	func _init(c: SpellCard, i: int, ident: int) -> void:
		card = c
		slot = i
		id = ident


## Compteur des ids de Tenue. Jamais remis a zero, meme par reset() : un voleur
## d une partie precedente qui garderait un vieil id ne doit pas pouvoir
## designer par hasard un exemplaire de la nouvelle main.
var _next_hold_id: int = 1


func _new_hold(c: SpellCard, i: int) -> Tenue:
	var t := Tenue.new(c, i, _next_hold_id)
	_next_hold_id += 1
	return t
var discard: Array[SpellCard] = []
var exiled: Array[SpellCard] = []

var xp: int = 0
var level: int = 1
var wave_index: int = 0
var mode: GameEnums.Mode = GameEnums.Mode.EXPLORATION
var current_level_def: LevelDef = null

## Reduction de temps d'incantation active (secondes), et son reliquat de duree.
var cost_reduction: float = 0.0
var _cost_reduction_time: float = 0.0

var _draw_timer: float = 0.0
## Acceleration de pioche active et son reliquat de duree.
var _draw_boost: float = 1.0
var _draw_boost_time: float = 0.0
var draw_interval: float = GameConfig.DRAW_INTERVAL
var draw_count: int = GameConfig.DRAW_COUNT

var _rng := RandomNumberGenerator.new()

## Focalisation : multiplicateur applique au prochain sort puis remis a 1.
var next_spell_multiplier: float = 1.0
## Echo de la main : nombre de cartes qui reviendront en main apres avoir ete lancees.
var _retain_charges: int = 0
## Compteur du passif "Echo perpetuel" (une carte sur N revient en main).
var _echo_counter: int = 0
## Double incantation : reliquat de duree pendant lequel deux sorts chargent ensemble.
var _double_cast_time: float = 0.0
## Cartes proposees au joueur ; la partie est en pause tant qu il n a pas choisi.
var pending_offer: Array[SpellCard] = []

## Suivi des objectifs.
var used_legendary: bool = false
var took_any_damage: bool = false
var speed_dropped: bool = false


func _ready() -> void:
	_rng.randomize()
	world_rng.randomize()
	reset()


func reset() -> void:
	deck.clear()
	hand.clear()
	discard.clear()
	exiled.clear()
	xp = 0
	level = 1
	wave_index = 0
	cost_reduction = 0.0
	_cost_reduction_time = 0.0
	_draw_timer = 0.0
	_draw_boost = 1.0
	_draw_boost_time = 0.0
	draw_interval = GameConfig.DRAW_INTERVAL
	draw_count = GameConfig.DRAW_COUNT
	used_legendary = false
	took_any_damage = false
	hits_by_source.clear()
	speed_dropped = false
	burned_card = null
	equipped_passives.clear()
	pending_passive = null
	_casting_count = 1
	_echo_counter = 0
	next_spell_multiplier = 1.0
	_retain_charges = 0
	_double_cast_time = 0.0
	pending_offer.clear()
	_blocked.clear()
	_silenced = false
	_stolen.clear()
	# L amelioration des cartes vaut pour LA PARTIE EN COURS : sans cet effacement
	# elle franchirait la fin du niveau et l equilibrage mesure au banc ne
	# decrirait plus aucune partie reelle (voir la section AMELIORATION plus bas).
	casts_by_card.clear()
	card_xp_bonus.clear()  # CHANTIER W8 : XP de meditation
	upgrades_taken.clear()
	pending_upgrade_card = null
	pending_upgrade_paths = []
	# Un choix d Epuration oublie gelerait la partie suivante des son debut.
	pending_purge = 0
	# Compteurs du moteur d objectifs (voir la section OBJECTIFS PARAMETRES).
	_reset_objective_counters()


## Fixe la graine pour rendre les tirages deterministes (tests, replays).
## Elle fixe AUSSI le hasard du monde (world_rng) : une graine = une partie.
func set_seed(value: int) -> void:
	_rng.seed = value
	world_rng.seed = value ^ WORLD_SEED_SALT


## LE HASARD DU MONDE : couloirs et cotes d apparition (WaveSpawner), esquive
## (Enemy.take_damage), points de chute de la Pluie de meteores, place des allies
## invoques, pont d une riviere (Battlefield).
##
## POURQUOI : ces tirages passaient par le hasard GLOBAL de Godot (randf) ou par
## un generateur re-seme au hasard a chaque usage. set_seed() ne les fixait pas,
## et deux processus du banc a graine egale rendaient des resultats differents
## (chantier W7) : un objectif ne se re-mesurait pas, il se re-tirait.
##
## POURQUOI UN SECOND GENERATEUR plutot que _rng : les tirages du monde dependent
## de ce qui se passe en jeu (une esquive par coup recu). Partages avec la
## pioche, ils decaleraient les cartes tirees des que le joueur vise autrement ;
## separes, une graine donne la meme pioche quelle que soit la facon de jouer,
## et les tests semes d avant gardent exactement leurs tirages.
##
## Le jeu reel ne seme jamais : les deux generateurs partent au hasard (_ready),
## le comportement du joueur ne change pas.
var world_rng := RandomNumberGenerator.new()
## Ecarte la graine du monde de celle de la pioche : avec la meme valeur, les
## deux suites seraient identiques et correlees.
const WORLD_SEED_SALT: int = 0x5DEECE66D


## Graine d un generateur DERIVE du hasard du monde (le WaveSpawner a le sien) :
## jamais 0, qui veut dire "au hasard" pour ses consommateurs.
func world_seed() -> int:
	return int(world_rng.randi()) + 1


func total_cards() -> int:
	return deck.size() + hand.size() + discard.size()


## Construit un deck a partir des exemplaires de base (copies_in_starter).
## N obtient AUCUNE carte : copies_in_starter ne donne plus rien au livre de
## sorts (SaveData, LE LIVRE DE SORTS).
func build_starter_deck(cards: Array[SpellCard]) -> void:
	deck.clear()
	for c in cards:
		for i in c.copies_in_starter:
			deck.append(c)
	shuffle_deck()
	deck_changed.emit()


## Construit le deck a partir d une liste EXPLICITE : une entree = un exemplaire.
## Utilise par le deck pre-etabli d un niveau et par le deck Massacre du joueur.
##
## Distribuer un deck n OBTIENT plus ses cartes (regle du livre de sorts, 01/10).
## Le deck d un niveau OUVERT est deja dans le livre avant la premiere partie,
## et un deck compose ne contient que des cartes obtenues. Ecrire ici donnait
## un livre qui dependait d avoir lance une partie (le Mur de pierre restait "a
## obtenir" jusque-la), et faisait obtenir le deck d un niveau FERME a qui le
## jouait hors campagne (banc, tests).
func build_deck_from_list(cards: Array[SpellCard]) -> void:
	deck.clear()
	for c in cards:
		if c == null:
			continue
		deck.append(c)
	shuffle_deck()
	deck_changed.emit()


func shuffle_deck() -> void:
	var n: int = deck.size()
	for i in range(n - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: SpellCard = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp


## Remelange la defausse dans la pioche. Conserve le nombre total de cartes.
func reshuffle_discard() -> void:
	if discard.is_empty():
		return
	deck.append_array(discard)
	discard.clear()
	shuffle_deck()
	deck_changed.emit()


func draw(count: int = 1) -> int:
	var drawn: int = 0
	for i in count:
		if hand.size() >= GameConfig.MAX_HAND_SIZE:
			break
		if deck.is_empty():
			reshuffle_discard()
		if deck.is_empty():
			break
		var c: SpellCard = deck.pop_back()
		hand.append(c)
		drawn += 1
		card_drawn.emit(c)
	if drawn > 0:
		hand_changed.emit()
		deck_changed.emit()
	return drawn


## Temps d'incantation reel : reduction de cout puis multiplicateur de vitesse.
## Temps d incantation reel : reduction de cout ET pouvoirs passifs inclus.
##
## Le plancher de 0,1 s n est pas cosmetique : un sort instantane ne laisse rien
## a lire au joueur et la barre de charge n aurait plus aucun sens.
func effective_cast_time(card: SpellCard) -> float:
	# La reduction des passifs est RELUE a chaque appel : un passif s allume et
	# s eteint avec la vitesse, il n y a donc rien a memoriser au moment ou on
	# l equipe. Un cache ici rendrait le seuil inoperant.
	var base: float = maxf(0.1, card.base_cast_time - cost_reduction - passive_cast_cut())
	# AMELIORATION de cette carte (Puissance ralentit, Celerite accelere). Elle
	# entre AVANT le plancher de 0,1 s applique par SpeedGauge : une Celerite ne
	# doit pas pouvoir rendre un sort instantane, la barre de charge n aurait
	# plus rien a montrer.
	base = maxf(0.1, base * upgrade_cast_factor(card))
	# PASSIFS ELEMENTAIRES (vague 8) : « -X % d incantation aux sorts de vent ».
	base = maxf(0.1, base * element_cast_factor(card))
	# Le MULTIPLICATEUR GLOBAL entre ici, apres les ajustements par carte et
	# avant la division par la vitesse : il rallonge tous les sorts dans la meme
	# proportion, donc la hierarchie entre eux ne bouge pas. Le plancher de
	# 0,1 s reste applique par SpeedGauge en dernier.
	base *= GameConfig.CAST_TIME_SCALE
	return SpeedGauge.effective_cast_time(base) * passive_cast_factor()


## `slot` designe l EXEMPLAIRE touche par le joueur (sa position dans la main).
## Sans lui (-1), on lance la premiere copie LIBRE de la carte : un effet qui
## rejoue « une Boule de feu » n a pas a savoir laquelle des copies est gelee.
func play_card(card: SpellCard, slot: int = -1) -> bool:
	_heal_holds()
	# REGARD PETRIFIANT : une carte gelee ne part pas et ne quitte pas la main.
	# Le garde est pose ICI plutot que dans le HUD parce que TOUS les chemins de
	# lancement passent par cette fonction — clic, glisser, pre-cast, double
	# lancement, effets qui rejouent une carte. Un garde cote interface laisserait
	# au moins un de ces chemins ouvert, et le joueur lancerait une carte que son
	# ecran lui montre comme petrifiee.
	var idx: int = -1
	if slot >= 0:
		# Le joueur a touche UNE carte precise : si c est la gelee, on refuse,
		# meme si une copie libre attend ailleurs. Lancer l autre copie a sa place
		# ferait partir une carte qu il n a pas touchee.
		if slot >= hand.size() or hand[slot] != card or is_slot_blocked(slot):
			return false
		idx = slot
	else:
		for i in hand.size():
			if hand[i] == card and not is_slot_blocked(i):
				idx = i
				break
	if idx == -1:
		return false
	# SOMMEIL (comportements v3) : un dormeur coupe TOUTE la magie. Meme garde,
	# meme endroit, meme raison que la petrification.
	if _silenced:
		return false
	_remove_from_hand(idx)
	if card.rarity == GameEnums.Rarity.LEGENDARY:
		used_legendary = true
	# Un passif n a plus rien a faire dans la main : il est equipe hors deck.
	# Le garde reste par securite — une sauvegarde ancienne peut encore contenir
	# son id dans un deck, et le laisser passer le ferait lancer comme un sort.
	if card.is_passive:
		hand_changed.emit()
		return true
	# Echo de la main : la carte est bien LANCEE, mais elle revient aussitot en
	# main au lieu de partir. C est le seul endroit ou une carte quitte la main ;
	# intercepter ailleurs laisserait des chemins ou l echo serait ignore.
	if _retain_charges > 0:
		_retain_charges -= 1
		hand.append(card)
		hand_changed.emit()
		return true
	# PASSIF "Echo perpetuel" : une carte sur N revient en main au lieu de partir.
	# Ce n est pas un bonus de degats mais un changement de RYTHME : le deck se
	# consomme moins vite, donc le joueur garde la main pleine aux hautes vitesses,
	# la ou la pioche ne suit plus. Compteur DETERMINISTE plutot qu aleatoire :
	# une chance cachee rend le passif illisible en jeu.
	var echo: float = passive_magnitude(&"passive_echo_cast")
	if echo > 0.0:
		_echo_counter += 1
		if _echo_counter >= int(maxf(echo, 2.0)):
			_echo_counter = 0
			hand.append(card)
			hand_changed.emit()
			return true
	if card.exile_after_cast:
		exiled.append(card)
	else:
		discard.append(card)
	hand_changed.emit()
	return true


# --- REGARD PETRIFIANT ------------------------------------------------------
#
# LE PLAFOND. Une main fait MAX_HAND_SIZE (6) cartes ; on en gele au plus 5.
# Le testeur l a demande mot pour mot : « Fait en sorte que l on puisse pas
# avoir plus de 5 carte sur 6 bloquer. » La raison est la meme que celle du
# plafond d invocation : un joueur qui ne peut RIEN lancer ne perd plus sur une
# erreur de jeu, il perd mecaniquement en regardant l ecran. Une carte jouable
# de reste, c est toujours une decision — laquelle, et sur quelle cible.
#
# Exprime comme un ecart a la main REELLE et non comme le nombre 5 : avec trois
# cartes en main et trois regards, geler « 5 au plus » gelerait la main entiere.
# La regle est donc « il en reste toujours une », ce qui donne 5 sur 6 et 2 sur 3.
const MIN_PLAYABLE_CARDS: int = 1


## Les cartes actuellement petrifiees, une entree PAR EXEMPLAIRE : deux copies
## gelees d une meme carte y figurent deux fois. Copie defensive : l appelant
## (le HUD) ne doit pas pouvoir degeler une carte en modifiant ce qu il affiche.
func blocked_cards() -> Array[SpellCard]:
	_heal_holds()
	return _cards_of(_blocked)


## Injouable, pour quelque cause que ce soit : petrifiee OU volee — et ce pour
## TOUTES ses copies en main. Une carte dont une copie reste libre se joue
## encore (play_card lance la copie libre) : repondre « bloquee » ici mentirait
## au code qui demande avant de lancer.
##
## L ecran, lui, raisonne par exemplaire : voir is_slot_blocked().
func is_card_blocked(card: SpellCard) -> bool:
	if card == null:
		return false
	_heal_holds()
	var copies: int = 0
	for i in hand.size():
		if hand[i] == card:
			copies += 1
			if not is_slot_blocked(i):
				return false
	return copies > 0


## L EXEMPLAIRE en position `slot` de la main est-il injouable (petrifie ou
## vole) ? C est la question que pose le HUD, carte par carte : poser la
## question par ressource grisait toutes les copies d une carte gelee une fois.
func is_slot_blocked(slot: int) -> bool:
	_heal_holds()
	return _holds_slot(_blocked, slot) or _holds_slot(_stolen, slot)


## L exemplaire en position `slot` est-il tenu par un VOLEUR ? Distinct de la
## petrification : le HUD lui donne un autre mot et une autre teinte.
func is_slot_stolen(slot: int) -> bool:
	_heal_holds()
	return _holds_slot(_stolen, slot)


func blocked_count() -> int:
	_heal_holds()
	return _blocked.size()


## Regle le nombre de cartes petrifiees sur `wanted` regards. Appele par
## Battlefield a chaque image avec le total des gorgones VIVANTES : zero gorgone
## vivante donne zero regard, donc la main se degele d elle-meme quand la source
## tombe — il n y a aucun chemin ou un blocage survivrait a son monstre.
##
## STABILITE : on ne reconstruit pas la liste, on l AJUSTE. Les exemplaires deja
## geles le restent tant qu ils sont en main et que le nombre de regards ne
## baisse pas. C est ce qui permet au joueur de planifier autour de sa main
## mutilee au lieu de voir la petrification danser d une carte a l autre.
func set_card_block_count(wanted: int) -> void:
	# Une carte qui a quitte la main (defausse, echange, fin de vague) ne peut
	# plus etre gelee : sinon le ledger retiendrait des cartes fantomes et le
	# plafond compterait des blocages que le joueur ne voit pas.
	var change: bool = _heal_holds()
	# Les cartes volees comptent dans le plafond : une gorgone et un voleur
	# ensemble ne doivent jamais geler la derniere carte jouable.
	var plafond: int = maxi(0, hand.size() - MIN_PLAYABLE_CARDS - _stolen.size())
	var cible: int = clampi(wanted, 0, plafond)
	while _blocked.size() > cible:
		_blocked.pop_back()
		change = true
	if _blocked.size() < cible:
		# On gele en partant de la FIN de la main : la carte la plus a droite,
		# donc la plus recemment piochee. Geler la premiere carte volerait au
		# joueur celle qu il avait deja decide de lancer, ce qui se lit comme une
		# triche ; lui prendre sa derniere pioche se lit comme un cout.
		# Par POSITION et non par carte : une copie deja gelee n empeche plus de
		# geler sa jumelle, et geler l une ne gele plus l autre.
		for i in range(hand.size() - 1, -1, -1):
			if _blocked.size() >= cible:
				break
			if hand[i] != null and not is_slot_blocked(i):
				_blocked.append(_new_hold(hand[i], i))
				change = true
	if change:
		hand_changed.emit()


## SOMMEIL QUI COUPE LA MAGIE (comportements v3). Pousse par Battlefield a chaque
## image, comme le nombre de regards : aucun dormeur vivant donne aucun silence,
## il n existe pas de chemin ou le verrou survit a son monstre.
var _silenced: bool = false


func set_silenced(value: bool) -> void:
	if _silenced == value:
		return
	_silenced = value
	# La main se redessine : grisee avec le mot en clair, ou rendue au joueur.
	hand_changed.emit()


func is_silenced() -> bool:
	return _silenced


# --- VOLEUR DE SORTS ----------------------------------------------------------
#
# Le voleur (Enemy, champs steal_* d EnemyDef) tient UN exemplaire de la main,
# puis le lance contre le mage. Le ledger vit ici pour la meme raison que la
# petrification : c est la MAIN qui est touchee, et `play_card` est le seul
# passage de toutes les facons de lancer.
#
# UN VOLEUR = UN EXEMPLAIRE, designe par l id de sa Tenue. Ni la carte ni la
# position ne suffisent : deux voleurs sur deux copies d une meme carte tiennent
# la MEME ressource, et la position se decale des qu une carte part a gauche.
# Quand le voleur ne retenait que la carte, celui qui mourait rallumait la
# PREMIERE copie volee trouvee — celle de l autre — et celui qui lancait faisait
# partir la copie de son voisin : la carte sautait de place sous les yeux du
# joueur. Liberation, lancement et « tiens-tu encore ? » passent donc par l id.

## Prend un exemplaire pour un voleur et rend l id qui le designe, ou 0 s il ne
## peut rien prendre sans violer le plafond (il reste toujours
## MIN_PLAYABLE_CARDS carte jouable). 0 n est jamais un id : le compteur part de 1.
##
## LA CARTE PRISE est la plus LONGUE a incanter (a egalite, la plus a gauche) :
## c est la plus precieuse, donc le vol se lit comme un vol, et c est celle qui
## fera le plus mal — ce que le joueur doit pouvoir anticiper en regardant sa main.
func steal_hold() -> int:
	_heal_holds()
	var libres: Array[int] = []
	for i in hand.size():
		var c: SpellCard = hand[i]
		if c != null and not c.is_passive and not is_slot_blocked(i):
			libres.append(i)
	if libres.size() <= MIN_PLAYABLE_CARDS:
		return 0
	var choix: int = libres[0]
	for i in libres:
		if hand[i].base_cast_time > hand[choix].base_cast_time:
			choix = i
	var t: Tenue = _new_hold(hand[choix], choix)
	_stolen.append(t)
	hand_changed.emit()
	return t.id


## Raccourci pour qui n a besoin que de la carte (tests de la main) : le voleur
## en jeu, lui, garde l id rendu par steal_hold().
func steal_card() -> SpellCard:
	return stolen_card_of(steal_hold())


## La carte de l exemplaire vole `hold_id`, ou null s il n est plus tenu.
func stolen_card_of(hold_id: int) -> SpellCard:
	_heal_holds()
	var k: int = _find_hold_id(_stolen, hold_id)
	return _stolen[k].card if k != -1 else null


## L exemplaire `hold_id` est-il encore tenu ? Faux des qu il a quitte la main
## par un autre chemin (defausse forcee, fin de vague) : son voleur n a plus
## rien a lancer, meme si une copie jumelle est tenue par un autre.
func is_hold_stolen(hold_id: int) -> bool:
	_heal_holds()
	return _find_hold_id(_stolen, hold_id) != -1


## Position actuelle de l exemplaire `hold_id` dans la main, -1 s il n est plus
## tenu. Sert au HUD comme aux tests : c est la ou la carte grisee est dessinee.
func stolen_slot_of(hold_id: int) -> int:
	_heal_holds()
	var k: int = _find_hold_id(_stolen, hold_id)
	return _stolen[k].slot if k != -1 else -1


func is_card_stolen(card: SpellCard) -> bool:
	_heal_holds()
	return card != null and _find_hold(_stolen, card) != -1


## Copie defensive, comme blocked_cards().
func stolen_cards() -> Array[SpellCard]:
	_heal_holds()
	return _cards_of(_stolen)


## Le voleur est mort (ou a quitte le terrain) avant de lancer : SON exemplaire
## redevient jouable, a sa place dans la main. Celui d un autre voleur reste tenu.
func release_stolen_hold(hold_id: int) -> void:
	_heal_holds()
	var k: int = _find_hold_id(_stolen, hold_id)
	if k == -1:
		return
	_stolen.remove_at(k)
	hand_changed.emit()


## Le voleur LANCE son exemplaire : il quitte la main pour la defausse, comme si
## le joueur l avait joue. Renvoie false s il n etait plus tenu (parti de la
## main entre-temps) : rien n est alors lance.
func spend_stolen_hold(hold_id: int) -> bool:
	_heal_holds()
	var k: int = _find_hold_id(_stolen, hold_id)
	if k == -1:
		return false
	# C est l exemplaire TENU qui part, pas la premiere copie venue : sinon la
	# copie libre (ou celle d un autre voleur) disparaitrait a sa place.
	var t: Tenue = _stolen[k]
	_stolen.remove_at(k)
	_remove_from_hand(t.slot)
	discard.append(t.card)
	hand_changed.emit()
	return true


# --- Registre par exemplaire ---------------------------------------------------

## Retire l exemplaire `idx` de la main ET recale le registre. Toute sortie de
## main faite par RunState passe ici : un `hand.remove_at` nu laisserait les
## positions tenues a droite de la carte decalees d un cran, et la petrification
## glisserait sur la carte voisine.
func _remove_from_hand(idx: int) -> SpellCard:
	var c: SpellCard = hand[idx]
	hand.remove_at(idx)
	for ledger: Array[Tenue] in [_blocked, _stolen]:
		for k in range(ledger.size() - 1, -1, -1):
			if ledger[k].slot == idx:
				ledger.remove_at(k)
			elif ledger[k].slot > idx:
				ledger[k].slot -= 1
	return c


## Oublie les entrees qui ne designent plus leur carte : la main a ete changee
## par un chemin qui ne passe pas par _remove_from_hand (videe, reconstruite
## par un test). On ne cherche PAS a recaser l entree sur une autre copie : une
## copie piochee plus tard se retrouverait gelee ou volee sans cause visible.
## Rend vrai si quelque chose a ete oublie.
func _heal_holds() -> bool:
	var change: bool = false
	for ledger: Array[Tenue] in [_blocked, _stolen]:
		for k in range(ledger.size() - 1, -1, -1):
			var t: Tenue = ledger[k]
			if t.slot < 0 or t.slot >= hand.size() or hand[t.slot] != t.card:
				ledger.remove_at(k)
				change = true
	return change


static func _holds_slot(ledger: Array[Tenue], slot: int) -> bool:
	for t in ledger:
		if t.slot == slot:
			return true
	return false


static func _find_hold(ledger: Array[Tenue], card: SpellCard) -> int:
	if card == null:
		return -1
	for k in ledger.size():
		if ledger[k].card == card:
			return k
	return -1


static func _find_hold_id(ledger: Array[Tenue], hold_id: int) -> int:
	if hold_id <= 0:
		return -1
	for k in ledger.size():
		if ledger[k].id == hold_id:
			return k
	return -1


static func _cards_of(ledger: Array[Tenue]) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for t in ledger:
		out.append(t.card)
	return out


func discard_random(count: int) -> int:
	var n: int = 0
	for i in count:
		if hand.is_empty():
			break
		var idx: int = _rng.randi_range(0, hand.size() - 1)
		discard.append(_remove_from_hand(idx))
		n += 1
	if n > 0:
		hand_changed.emit()
	return n


func discard_hand() -> int:
	var n: int = hand.size()
	discard.append_array(hand)
	hand.clear()
	# Plus aucune carte en main, donc plus aucun exemplaire tenu. Vide ICI et pas
	# a la prochaine lecture : une copie piochee entre-temps a la meme position
	# ressemblerait a l ancienne et heriterait de son gel.
	_blocked.clear()
	_stolen.clear()
	if n > 0:
		hand_changed.emit()
	return n


# --- EPURATION : retirer des cartes AU CHOIX du joueur (vague 8) ---
#
# Epuration exilait les 2 cartes du DESSUS de la pioche : le joueur payait une
# epique pour perdre deux cartes au hasard, peut-etre ses meilleures. Il CHOISIT
# maintenant 0, 1 ou 2 cartes dans tout son deck de partie (pioche, main,
# defausse), sur l ecran DeckBrowser. La partie attend son choix
# (GameController.simulate refuse d avancer tant que `pending_purge` > 0),
# comme pour une amelioration de carte.
#
# Quand personne ne peut toucher l ecran (banc, tests headless, sort lance hors
# partie), le choix est tranche AUSSITOT par AutoPick.purge_choice : une offre
# laissee en attente gelerait la partie pour toujours (meme lecon que le banc a
# 0 victoire sur 30, voir GameController._on_upgrade_ready).

## Emis quand un choix d Epuration attend le joueur. GameController l ecoute.
signal purge_requested(max_count: int)
## Emis une fois le choix tranche, avec le nombre de cartes retirees.
signal purge_resolved(removed: int)

## Plafond du choix en attente (0 = aucun choix en attente).
var pending_purge: int = 0


## Le deck de la PARTIE regroupe par carte : une entree par carte differente,
## {card, pile, hand, discard, total}, triee par rarete puis par nom. Les copies
## d une carte sont la meme ressource : les regrouper est la seule facon de les
## montrer sans douze lignes dont trois identiques. Les cartes exilees n y sont
## plus : elles ont quitte la partie.
func run_deck_groups() -> Array[Dictionary]:
	var par_id: Dictionary = {}
	var ordre: Array[SpellCard] = []
	for zone: Array in [[deck, "pile"], [hand, "hand"], [discard, "discard"]]:
		var pile: Array[SpellCard] = zone[0]
		var cle: String = zone[1]
		for c in pile:
			if c == null:
				continue
			if not par_id.has(c.id):
				par_id[c.id] = {"card": c, "pile": 0, "hand": 0, "discard": 0, "total": 0}
				ordre.append(c)
			par_id[c.id][cle] = int(par_id[c.id][cle]) + 1
			par_id[c.id]["total"] = int(par_id[c.id]["total"]) + 1
	ordre.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.display_name < b.display_name)
	var out: Array[Dictionary] = []
	for c in ordre:
		out.append(par_id[c.id])
	return out


## Ouvre un choix d Epuration : jusqu a `max_count` cartes a retirer.
##
## Les demandes S AJOUTENT tant que le choix n est pas tranche : Debordement
## resout chaque sort deux fois, et deux Epurations resolues coup sur coup
## doivent valoir quatre cartes au plus, sur UN seul ecran (l ecran ouvert lit
## le plafond cumule dans `pending_purge`). Sans ecran, la premiere est deja
## tranchee quand la seconde arrive : quatre aussi.
func request_purge(max_count: int) -> void:
	if max_count <= 0 or total_cards() == 0:
		return
	pending_purge += max_count
	if purge_requested.get_connections().is_empty():
		# Aucune partie n ecoute (sort lance par un test, vitrine) : personne ne
		# pourrait jamais valider, on tranche tout de suite.
		resolve_purge(AutoPick.purge_choice(run_deck_groups(), pending_purge))
		return
	purge_requested.emit(max_count)


## Tranche le choix en attente : `cards` contient un element par EXEMPLAIRE a
## retirer (0 element = rien retirer, c est permis). Au plus `pending_purge`
## exemplaires partent, meme si l appelant en demande davantage : le plafond
## est une regle de la carte, pas de l ecran. Rend le nombre retire.
func resolve_purge(cards: Array) -> int:
	var budget: int = pending_purge
	pending_purge = 0
	var n: int = 0
	var main_touchee: bool = false
	for c in cards:
		if n >= budget:
			break
		if not (c is SpellCard):
			continue
		var r: int = _exile_one(c)
		if r == 0:
			continue
		n += 1
		if r == 2:
			main_touchee = true
	if n > 0:
		deck_changed.emit()
	if main_touchee:
		hand_changed.emit()
	purge_resolved.emit(n)
	return n


## Exile UN exemplaire de `card`. Ordre des piles : la DEFAUSSE d abord (la
## carte vient de servir, la retirer ne coute rien au tour en cours), puis la
## PIOCHE, puis la MAIN en dernier (c est la carte que le joueur tient). Rend 0
## si aucun exemplaire, 1 si pris en defausse ou en pioche, 2 si pris en main.
func _exile_one(card: SpellCard) -> int:
	var i: int = discard.find(card)
	if i != -1:
		discard.remove_at(i)
		exiled.append(card)
		return 1
	i = deck.find(card)
	if i != -1:
		deck.remove_at(i)
		exiled.append(card)
		return 1
	# En main, de preference un exemplaire LIBRE : un exemplaire petrifie ou
	# tenu par un voleur reste en jeu, c est lui que le monstre designe.
	var libre: int = -1
	for k in hand.size():
		if hand[k] == card:
			if libre == -1:
				libre = k
			if not is_slot_blocked(k):
				libre = k
				break
	if libre != -1:
		exiled.append(_remove_from_hand(libre))
		return 2
	return 0


## N obtient PLUS la carte (chantier P) : c est pick_offer(), le geste de
## prendre, qui l ajoute au livre. Une carte qui arriverait dans la defausse par
## un autre chemin ne doit pas rejoindre la collection sans que le joueur l ait
## choisie.
func add_card_to_discard(card: SpellCard) -> void:
	discard.append(card)
	deck_changed.emit()


func apply_cost_reduction(seconds: float, duration: float) -> void:
	cost_reduction = maxf(cost_reduction, seconds)
	_cost_reduction_time = maxf(_cost_reduction_time, duration)


## XP d'un ennemi, deja multipliee par la vitesse. Peut declencher une montee.
##
## DOUBLE PEINE ASSUMEE (26 septembre). Depuis que la vitesse EST la vie, un
## mage blesse est un mage lent, donc un mage qui gagne MOINS d XP. Se faire
## toucher coute maintenant de la vie, du temps d incantation, des passifs
## eteints ET de la progression. C est beaucoup pour un seul contact.
##
## Ce n est PAS corrige ici, et c est un choix : corriger demanderait de figer
## un multiplicateur d XP separe de la vitesse, ce qui recreerait exactement la
## seconde reserve qu on vient de supprimer. La spirale est reelle mais elle est
## lisible — le joueur voit le meme nombre porter tout — et son reglage
## (SPEED_RISE_PER_SECOND, degats de contact) appartient au testeur.
func gain_xp(base_xp: int) -> void:
	# Passif "Erudition" : l XP est deja multipliee par la vitesse, ce passif la
	# multiplie une seconde fois. Il s applique APRES pour que les deux gains se
	# composent au lieu de se remplacer.
	var amount: int = SpeedGauge.xp_for(base_xp)
	var bonus_xp: float = passive_magnitude(&"passive_xp_boost")
	if bonus_xp > 0.0:
		amount = int(round(float(amount) * (1.0 + bonus_xp * 0.01)))
	xp += amount
	xp_gained.emit(amount)
	while xp >= GameConfig.xp_required(level):
		xp -= GameConfig.xp_required(level)
		level += 1
		level_up.emit(level)


## Tire une rarete selon la table 80/15/5.
func roll_rarity() -> GameEnums.Rarity:
	var r: float = _rng.randf()
	var acc: float = 0.0
	for rarity: GameEnums.Rarity in GameConfig.RARITY_WEIGHTS:
		acc += GameConfig.RARITY_WEIGHTS[rarity]
		if r < acc:
			return rarity
	return GameEnums.Rarity.RARE


## Pioche automatique : +draw_count toutes les draw_interval secondes de TEMPS DU MONDE.
##
## L appelant (GameController.simulate) passe le delta deja multiplie par la jauge,
## comme pour les monstres et l incantation. C est indispensable : a x4 le joueur
## voit arriver quatre fois plus de monstres et lance quatre fois plus de sorts ;
## si la pioche restait en temps reel, il finirait les mains vides au pire moment
## et le multiplicateur serait une punition au lieu d un pari.
func tick(delta: float) -> void:
	if _cost_reduction_time > 0.0:
		_cost_reduction_time -= delta
		if _cost_reduction_time <= 0.0:
			cost_reduction = 0.0
	if _draw_boost_time > 0.0:
		_draw_boost_time -= delta
		if _draw_boost_time <= 0.0:
			_draw_boost = 1.0
			draw_interval = GameConfig.DRAW_INTERVAL
	if _double_cast_time > 0.0:
		_double_cast_time -= delta
	# Passif "Main leste" : la pioche accelere tant que la vitesse tient le seuil.
	# Applique ici et non sur draw_interval : le passif s eteint au premier coup
	# recu, donc l intervalle doit se RECALCULER a chaque image, pas une fois.
	var intervalle: float = draw_interval
	var haste: float = passive_magnitude(&"passive_draw_haste")
	if haste > 0.0:
		intervalle = maxf(0.5, draw_interval / (1.0 + haste * 0.01))
	_draw_timer += delta
	while _draw_timer >= intervalle:
		_draw_timer -= intervalle
		draw(draw_count)


## Accelere la pioche pendant `duration` secondes. Le cahier des charges promet
## une pioche "ameliorable" ; RunState l exposait deja mais aucune carte n y touchait.
## Avancement vers la prochaine pioche, de 0 a 1. Le joueur ne savait pas quand
## ses cartes arrivaient : il jouait a l aveugle entre deux pioches.
func draw_progress() -> float:
	if draw_interval <= 0.0:
		return 0.0
	return clampf(_draw_timer / draw_interval, 0.0, 1.0)


## Secondes reelles avant la prochaine pioche, a la vitesse courante.
func seconds_to_draw() -> float:
	var restant: float = maxf(0.0, draw_interval - _draw_timer)
	return restant / maxf(SpeedGauge.multiplier(), 0.01)


## Accelere la pioche pendant `duration` secondes.
##
## Deux accelerations ne s empilent PAS : on garde la plus forte. Sinon deux copies
## de la meme carte reduiraient l intervalle a presque zero et rempliraient la main
## instantanement, ce qui retire tout choix au joueur.
func boost_draw(factor: float, duration: float) -> void:
	var f: float = maxf(factor, 1.0)
	if f >= _draw_boost:
		_draw_boost = f
		_draw_boost_time = maxf(_draw_boost_time, duration)
	else:
		_draw_boost_time = maxf(_draw_boost_time, duration)
	draw_interval = GameConfig.DRAW_INTERVAL / _draw_boost


## --- Pouvoirs passifs (version 2) ---
##
## Un passif n est PLUS une carte du deck. Il est EQUIPE dans un des trois
## emplacements et agit des le debut du combat, mais SEULEMENT si la vitesse du
## jeu depasse son seuil (`SpellCard.speed_threshold`).
##
## Pourquoi le seuil vit ici et non dans un handler : un passif ne "s execute"
## pas, il CHANGE UNE REGLE. Et cette regle s allume et s eteint tout au long de
## la partie au rythme de la jauge. Il n y a donc rien a "appliquer" une fois :
## chaque lecteur (Caster, GameController, Battlefield) interroge RunState au
## moment ou il en a besoin.
##
## Consequence voulue : un coup recu fait retomber la vitesse, donc il ETEINT les
## passifs. Depuis que la vitesse EST la vie (26 septembre), les seuils ont pris
## un sens nouveau : un passif a 400 % ne s allume plus que quand le mage est en
## PLEINE FORME, et se faire toucher les eteint un par un en descendant le rail.
## Le joueur blesse perd donc ses regles en meme temps que sa vie — c est le
## prix du contact, et il se lit sur une seule barre.

## Les passifs equipes, dans l ordre des emplacements. Taille <= PASSIVE_SLOTS.
var equipped_passives: Array[SpellCard] = []
## Passif gagne alors que les trois emplacements etaient pleins : il ATTEND que
## le joueur designe celui qu il remplace. Null si aucun echange en attente.
var pending_passive: SpellCard = null

## Toutes les cles de passif que le jeu sait lire. Un passif dont la cle n est
## pas ici ne ferait RIEN : il occuperait un emplacement et mentirait au joueur.
## L AUDIT ne peut pas l attraper (les passifs n ont pas de handler d effet),
## d ou cette liste, verrouillee par test_passives.gd.
const PASSIVE_KEYS: Array[StringName] = [
	&"passive_cast_haste",      # incantation raccourcie d un temps fixe
	&"passive_xp_boost",        # XP multipliee
	&"passive_draw_haste",      # pioche acceleree
	&"passive_start_wall",      # un mur au debut de chaque vague
	&"passive_death_blast",     # "fire boom" : les monstres explosent en mourant
	&"passive_wave_ally",       # un allie au debut de chaque vague
	&"passive_chill_on_hit",    # tout degat ralentit la cible
	&"passive_double_cast",     # deux sorts chargent ensemble
	&"passive_echo_cast",       # les sorts lances reviennent en main
	&"passive_chain_blast",     # l explosion de mort en declenche d autres
	&"passive_shield_keeper",   # un coup coute moitie moins de vitesse
	&"passive_twin_cast",       # chaque sort est resolu deux fois
	&"passive_speed_damage",    # la vitesse multiplie aussi les degats
	&"passive_kill_speed",      # chaque mort repousse la jauge de vitesse
	&"passive_element",         # vague 8 : amplifie UN element (voir element_bonus)
]

## --- PASSIFS ELEMENTAIRES (vague 8) ---
##
## « Augmente la duree des effets de poison ; augmente les degats des sorts de
## feu ; diminue l incantation des sorts d arcane. » Une SEULE cle,
## `passive_element`, pour tous : l ELEMENT est celui de la carte passive
## (SpellCard.element), la REGLE amplifiee est le parametre `stat` de son
## effet, le pourcentage sa magnitude. Seize passifs, zero handler neuf : un
## passif de plus est un .tres de plus, comme une carte.
##
## Chaque `stat` est lue a UN endroit, au moment ou la regle s applique :
##   damage    +X % de degats             Battlefield._hit
##   duration  +X % de duree des effets   cast_specs (copies)
##   radius    +X % de rayon des effets   cast_specs (copies)
##   cast      -X % d incantation         effective_cast_time
##   sturdy    -X % de degats subis par les objets de terrain de l element
##                                        Battlefield.object_hit
##   pierce    les RESISTANCES a l element reculent de X % vers le neutre ;
##             une immunite reste une immunite (c est une decision de design,
##             pas un chiffre a eroder)  Battlefield._hit (pierce_resistance)
const ELEM_DAMAGE: StringName = &"damage"
const ELEM_DURATION: StringName = &"duration"
const ELEM_RADIUS: StringName = &"radius"
const ELEM_CAST: StringName = &"cast"
const ELEM_STURDY: StringName = &"sturdy"
const ELEM_PIERCE: StringName = &"pierce"
const ELEMENT_STATS: Array[StringName] = [
	ELEM_DAMAGE, ELEM_DURATION, ELEM_RADIUS, ELEM_CAST, ELEM_STURDY, ELEM_PIERCE,
]
## Plancher de l incantation reduite par les passifs elementaires : deux passifs
## de la meme famille ne doivent pas rendre un sort instantane.
const ELEMENT_CAST_FLOOR: float = 0.5

## Nombre de sorts qui chargent en ce moment (tenu a jour par le Caster : lui
## seul sait si la seconde place est reellement occupee).
var _casting_count: int = 1

signal passive_activated(card: SpellCard)
signal passives_changed()
## Un passif est gagne alors que les trois emplacements sont pleins :
## l interface doit demander lequel remplacer.
signal passive_swap_needed(card: SpellCard)


## Un passif donne est-il ACTIF a l instant ? Equipe ET au-dessus de son seuil.
##
## Le seuil est teste en >= : un passif annonce "a partir de 140 %" doit
## s allumer PILE a 140, pas a 141. Le joueur lit le nombre sur la barre.
func passive_active(card: SpellCard) -> bool:
	if card == null or not equipped_passives.has(card):
		return false
	return SpeedGauge.speed_percent >= card.speed_threshold


## Un passif de cette cle est-il actif ? Lu par GameController, Battlefield,
## Caster. Le seuil est deja pris en compte ICI, volontairement : si chaque
## appelant devait y penser, un seul oubli rendrait un passif actif a 100 %.
func has_passive(key: StringName) -> bool:
	for c in equipped_passives:
		if not passive_active(c):
			continue
		for spec in c.effects:
			if spec != null and spec.key == key:
				return true
	return false


## Magnitude cumulee des passifs ACTIFS portant cette cle. Zero si aucun.
## Un seul point de lecture pour les passifs chiffres : le seuil y est deja
## applique, comme dans has_passive().
func passive_magnitude(key: StringName) -> float:
	var total: float = 0.0
	for c in equipped_passives:
		if not passive_active(c):
			continue
		for spec in c.effects:
			if spec != null and spec.key == key:
				total += spec.magnitude
	return total


## Somme des pourcentages des passifs elementaires ACTIFS (seuil compris) qui
## amplifient `stat` pour `element`. Zero si aucun : chaque lecteur multiplie
## par (1 + bonus / 100) sans avoir a savoir si un passif est equipe.
func element_bonus(element: int, stat: StringName) -> float:
	if element == GameEnums.DamageTag.NONE:
		return 0.0
	var total: float = 0.0
	for c in equipped_passives:
		if c == null or c.main_element() != element or not passive_active(c):
			continue
		for spec in c.effects:
			if spec == null or spec.key != &"passive_element":
				continue
			if StringName(spec.get_param(&"stat", &"")) == stat:
				total += spec.magnitude
	return total


## Resistance `r` d un monstre a `element`, apres les passifs « perce-
## resistance » : r recule vers 1 de X %. Ni une immunite (0) ni une
## faiblesse (> 1) ne bougent.
func pierce_resistance(r: float, element: int) -> float:
	if r <= 0.0 or r >= 1.0:
		return r
	var b: float = clampf(element_bonus(element, ELEM_PIERCE) * 0.01, 0.0, 1.0)
	return r + (1.0 - r) * b


## Facteur d incantation des passifs elementaires pour cette carte (1 = rien).
func element_cast_factor(card: SpellCard) -> float:
	if card == null:
		return 1.0
	var b: float = element_bonus(card.main_element(), ELEM_CAST)
	return maxf(ELEMENT_CAST_FLOOR, 1.0 - b * 0.01)


## Equipe un passif dans un emplacement libre. Faux si la barre est pleine ou si
## ce passif y est deja — dans ce cas l appelant doit passer par swap_passive().
func equip_passive(card: SpellCard) -> bool:
	if card == null or not card.is_passive:
		return false
	if equipped_passives.has(card):
		return false
	if equipped_passives.size() >= GameConfig.PASSIVE_SLOTS:
		return false
	# Equiper n obtient rien : en combat, un passif arrive par pick_offer, qui
	# l a deja fait entrer au livre ; au depart, equip_saved_passives n equipe que
	# des passifs obtenus. Une seule porte d entree : la PRISE.
	equipped_passives.append(card)
	passive_activated.emit(card)
	passives_changed.emit()
	return true


## Remplace le passif de l emplacement `slot` par `card`. C est le geste que le
## testeur decrit : "on doit selectionner un des trois passifs a changer".
func swap_passive(slot: int, card: SpellCard) -> bool:
	if card == null or not card.is_passive:
		return false
	if slot < 0 or slot >= equipped_passives.size():
		return false
	if equipped_passives.has(card):
		return false
	equipped_passives[slot] = card
	passive_activated.emit(card)
	passives_changed.emit()
	return true


## Un passif vient d etre gagne. S il reste de la place il entre directement ;
## sinon il est MIS EN ATTENTE et l interface demande quel emplacement liberer.
## On ne choisit jamais a la place du joueur : un echange automatique pourrait
## jeter le passif sur lequel toute sa partie repose.
func gain_passive(card: SpellCard) -> bool:
	if card == null or not card.is_passive:
		return false
	if equip_passive(card):
		return true
	if equipped_passives.has(card):
		return false
	pending_passive = card
	passive_swap_needed.emit(card)
	return false


## Le joueur a designe l emplacement a sacrifier pour le passif en attente.
func resolve_pending_passive(slot: int) -> bool:
	if pending_passive == null:
		return false
	var card: SpellCard = pending_passive
	if not swap_passive(slot, card):
		return false
	pending_passive = null
	return true


## Le joueur renonce au passif en attente et garde ses trois actuels.
func decline_pending_passive() -> void:
	pending_passive = null


## Le passif ouvre une seconde place, la legendaire "Canalisation jumelle"
## l ouvre POUR UN TEMPS. Les deux passent par le meme compteur : le Caster n a
## qu une seule regle a lire, et cumuler les deux ne donne pas 3 places.
func cast_slots() -> int:
	return 2 if (has_passive(&"passive_double_cast") or double_cast_active()) else 1


## Combien de sorts chargent en ce moment. Le Caster le tient a jour : lui seul
## sait si la seconde place est reellement occupee.
func set_casting_count(n: int) -> void:
	_casting_count = maxi(1, n)


## Secondes retirees au temps de base par les passifs de celerite ACTIFS.
func passive_cast_cut() -> float:
	return passive_magnitude(&"passive_cast_haste")


## Facteur applique APRES la reduction : uniquement le malus de Double
## incantation, et seulement quand les deux places servent vraiment.
## Mesure au banc : applique en permanence, le mage passait 85 % du temps a
## incanter — il payait un prix pour un avantage qu il n utilisait pas.
func passive_cast_factor() -> float:
	if _casting_count > 1 and has_passive(&"passive_double_cast"):
		return 1.5
	return 1.0


## Multiplicateur de degats venant des passifs ACTIFS.
## "Apotheose" fait porter la vitesse sur les DEGATS, pas seulement sur l XP :
## a 400 %, le mage frappe 4 fois plus fort. C est la regle la plus bouleversante
## du catalogue, d ou son seuil legendaire.
func passive_damage_multiplier() -> float:
	var m: float = 1.0
	if has_passive(&"passive_speed_damage"):
		m *= maxf(SpeedGauge.multiplier(), 1.0)
	return m


func empower_next(multiplier: float) -> void:
	next_spell_multiplier = maxf(next_spell_multiplier, multiplier)


func take_next_spell_multiplier() -> float:
	var m: float = next_spell_multiplier
	next_spell_multiplier = 1.0
	return m


## Propose `count` cartes distinctes, TIREES DANS levelup_pool() du niveau et du
## mode en cours : la rarete est tiree (table de campagne ou 80/15/5 pour un
## sort, voir roll_spell_rarity ; table des passifs pour un passif), puis on
## complete avec d autres raretes si le pool est court.
##
## Il n y a plus d offre de rarete imposee (l ancienne recompense de boss) : TOUTE
## offre passe par ici, donc par le pool. C est ce qui rend le pool vrai — une
## seconde porte d entree proposerait des cartes que le joueur ne peut pas voir
## dans son grimoire.
func offer_choices(count: int = 3) -> Array[SpellCard]:
	var chosen: Array[SpellCard] = []
	var pool: Array[SpellCard] = levelup_pool(current_level_def, mode)
	# "Les passifs sont plus rares que les cartes durant les montees de niveau :
	# 20 pourcent de passifs." Chaque proposition tire d abord SA FAMILLE, puis sa
	# rarete. Tirer la famille une seule fois pour toute l offre donnerait des
	# montees "tout passif" ou "tout sort" : le joueur n aurait plus de choix,
	# seulement un verdict.
	# Chaque carte tire SA PROPRE rarete : les trois choix peuvent donc etre de
	# raretes differentes. Avec une seule rarete pour toute l offre, les trois
	# options se ressemblaient et le tirage n avait aucun relief.
	for i in count:
		# Le tirage de famille a TOUJOURS lieu, meme quand les passifs sont
		# exclus : une graine donnee produit alors la meme suite de tirages avec
		# ou sans passifs, et un test seme ne change pas de sens selon l acte.
		var tirage: float = _rng.randf()
		var passif: bool = tirage < GameConfig.PASSIVE_OFFER_CHANCE \
			and passives_allowed(current_level_def, mode)
		# CORRECTIF (chantier P) : un passif tire SA rarete dans la table des
		# passifs, qui connait la COMMUNE. La table des sorts ne la tire jamais et
		# le repli passait par RARE, jamais epuisee : les quatre passifs communs
		# n etaient JAMAIS proposes.
		# Meme defaut, cote SORTS, en campagne (retouche du 30/09) : voir
		# roll_spell_rarity() et CAMPAIGN_RARITY_WEIGHTS.
		var voulue: GameEnums.Rarity = roll_passive_rarity() if passif \
			else roll_spell_rarity(current_level_def, mode)
		# Replis, du plus proche au plus lointain, si la rarete voulue est epuisee.
		var order: Array = [voulue, GameEnums.Rarity.RARE, GameEnums.Rarity.EPIC,
			GameEnums.Rarity.COMMON, GameEnums.Rarity.LEGENDARY]
		for r in order:
			if chosen.size() > i:
				break
			var candidats: Array[SpellCard] = _pool_of(pool, r, passif)
			_shuffle_cards(candidats)
			for c in candidats:
				if not chosen.has(c) and not _deja_equipe(c):
					chosen.append(c)
					break
		# Repli de DERNIER recours : si la famille voulue est epuisee a toutes les
		# raretes (peu de passifs, ou tous deja equipes), on prend dans l autre.
		# Une case vide dans l offre vaut moins qu un choix hors famille. Le pool
		# ne contient deja AUCUN passif quand l acte les exclut : ce repli ne peut
		# donc pas en faire rentrer un par la bande.
		if chosen.size() <= i:
			for r2 in order:
				if chosen.size() > i:
					break
				var autre: Array[SpellCard] = _pool_of(pool, r2, not passif)
				_shuffle_cards(autre)
				for c2 in autre:
					if not chosen.has(c2) and not _deja_equipe(c2):
						chosen.append(c2)
						break
	# On garde notre propre copie : l appelant peut faire ce qu il veut de la sienne
	# sans que pick_offer() la vide sous ses pieds.
	pending_offer = chosen.duplicate()
	if not chosen.is_empty():
		offer_ready.emit(chosen.duplicate())
	return chosen


# --- POOL DE MONTEE DE NIVEAU ET PASSIFS PAR ACTE (vague 5, chantier P) -------
#
# Regle du co-auteur :
#   CAMPAGNE (Mode.EXPLORATION) : le deck du niveau + ses cartes NOUVELLES
#     (LevelDef.levelup_cards) + les cartes des objectifs DEJA REUSSIS de ce
#     niveau (SaveData.objective_rewards_unlocked). Les passifs s y ajoutent,
#     tout le catalogue, mais seulement a partir de l acte 2.
#   HORS CAMPAGNE (tout autre mode : l infini par niveau, le Massacre) : toutes
#     les cartes deja OBTENUES, passifs compris si l acte 2 est atteint.
#
# Un objectif reussi n enrichit le pool que pour les parties SUIVANTES : les
# objectifs se jugent a la victoire (voir system_objectives), il n existe donc
# aucun instant de la partie en cours ou la carte pourrait y entrer.

## Table de rarete des PASSIFS a la montee de niveau. Le haut de la table est
## celui des sorts (epique 15 %, legendaire 5 %) ; les 80 % de "rare" des sorts
## sont partages entre commune et rare, parce que les passifs communs sont les
## plus LISIBLES (un mur par vague, une pioche plus rapide) : ce sont eux qui
## doivent apprendre au joueur ce qu est un passif.
const PASSIVE_RARITY_WEIGHTS: Dictionary = {
	GameEnums.Rarity.COMMON: 0.50,
	GameEnums.Rarity.RARE: 0.30,
	GameEnums.Rarity.EPIC: 0.15,
	GameEnums.Rarity.LEGENDARY: 0.05,
}

## Table de rarete des SORTS proposes en CAMPAGNE (retouche du 30/09).
##
## LE DEFAUT : la table des sorts (GameConfig.RARITY_WEIGHTS, 80/15/5, DEC-004)
## ne tire jamais la commune. Elle a ete ecrite pour un pool qui etait TOUT le
## catalogue ; depuis que le pool de campagne se limite au niveau (son deck, ses
## cartes nouvelles, les cartes de ses objectifs), les communes de ce pool ne
## sortaient qu en REPLI, quand rare et epique etaient epuisees dans l offre :
## une commune nouvelle du niveau n etait presque jamais proposee.
##
## LE CHOIX : epique 15 % et legendaire 5 %, EXACTEMENT comme DEC-004, pour que
## le haut de la courbe de puissance ne bouge pas ; les 80 % de "rare" sont
## partages A PARTS EGALES entre commune et rare. Parts egales parce que, dans un
## pool de niveau, les communes sont les cartes du deck du niveau et ses cartes
## nouvelles : elles sont le contenu MEME du niveau, pas un fond de catalogue.
## C est la forme de la table des passifs du chantier P, pour la meme raison.
## Puis on tire UNIFORMEMENT parmi les cartes du pool de cette rarete.
##
## HORS CAMPAGNE (Infini, Massacre) et sans niveau (tests a froid, banc hors
## partie), la table de DEC-004 reste la seule : le pool y est la collection
## entiere du joueur, et c est l equilibrage qu elle a mesure.
const CAMPAIGN_RARITY_WEIGHTS: Dictionary = {
	GameEnums.Rarity.COMMON: 0.40,
	GameEnums.Rarity.RARE: 0.40,
	GameEnums.Rarity.EPIC: 0.15,
	GameEnums.Rarity.LEGENDARY: 0.05,
}


## Tire la rarete d un SORT propose. Campagne avec un niveau : table de campagne
## (qui connait la commune) ; sinon la table de DEC-004. Consomme UN seul tirage
## dans les deux cas, comme roll_rarity : une graine donnee garde la meme suite
## de tirages quel que soit le mode.
func roll_spell_rarity(level_def: LevelDef, level_mode: GameEnums.Mode) -> GameEnums.Rarity:
	if level_def == null or level_mode != GameEnums.Mode.EXPLORATION:
		return roll_rarity()
	var r: float = _rng.randf()
	var acc: float = 0.0
	for rarity: GameEnums.Rarity in CAMPAIGN_RARITY_WEIGHTS:
		acc += CAMPAIGN_RARITY_WEIGHTS[rarity]
		if r < acc:
			return rarity
	return GameEnums.Rarity.RARE


## LE pool de montee de niveau. Toutes les offres de cartes passent par ici
## (offer_choices), le grimoire et l ecran de deck aussi (SaveData.obtainable_ids)
## — un seul endroit ou la regle est ecrite.
##
## Sans niveau (tests a froid, outils du banc qui tirent hors partie), tout le
## catalogue : c est le comportement d avant la regle, et il n existe aucun
## niveau dont lire un pool. Une partie reelle a TOUJOURS un niveau.
func levelup_pool(level_def: LevelDef, level_mode: GameEnums.Mode) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	var passifs_ok: bool = passives_allowed(level_def, level_mode)
	if level_def == null:
		for c: SpellCard in ContentDB.cards.values():
			_pool_add(out, c, passifs_ok)
		return out
	if level_mode == GameEnums.Mode.EXPLORATION:
		for c: SpellCard in level_def.exploration_deck:
			_pool_add(out, c, passifs_ok)
		for c: SpellCard in level_def.levelup_cards:
			_pool_add(out, c, passifs_ok)
		for c: SpellCard in SaveData.objective_rewards_unlocked(level_def):
			_pool_add(out, c, passifs_ok)
		if passifs_ok:
			for c: SpellCard in ContentDB.cards.values():
				if c != null and c.is_passive:
					_pool_add(out, c, passifs_ok)
		return out
	for c: SpellCard in ContentDB.cards.values():
		if c != null and SaveData.is_discovered(c.id):
			_pool_add(out, c, passifs_ok)
	return out


func _pool_add(out: Array[SpellCard], c: SpellCard, passifs_ok: bool) -> void:
	if c == null or out.has(c):
		return
	if c.is_passive and not passifs_ok:
		return
	out.append(c)


## Les passifs existent-ils dans cette partie ? "Rien avant l acte 2" : en
## campagne c est l acte DU NIVEAU qui decide ; hors campagne, il faut avoir
## ouvert un niveau de l acte 2. Sans niveau (tests a froid), oui.
func passives_allowed(level_def: LevelDef, level_mode: GameEnums.Mode) -> bool:
	if level_def == null:
		return true
	if level_mode == GameEnums.Mode.EXPLORATION:
		return level_def.allows_passives()
	return SaveData.passives_unlocked()


## Tire une rarete de PASSIF (voir PASSIVE_RARITY_WEIGHTS). Consomme un seul
## tirage, comme roll_rarity : la suite des tirages ne depend pas de la famille.
func roll_passive_rarity() -> GameEnums.Rarity:
	var r: float = _rng.randf()
	var acc: float = 0.0
	for rarity: GameEnums.Rarity in PASSIVE_RARITY_WEIGHTS:
		acc += PASSIVE_RARITY_WEIGHTS[rarity]
		if r < acc:
			return rarity
	return GameEnums.Rarity.COMMON


## Equipe, au DEPART du combat, les passifs que le joueur a choisis dans l ecran
## de deck (SaveData.equipped_passive_cards). Appele par
## GameController.start_level() APRES reset(), qui vide la barre.
## Rend le nombre de passifs equipes.
##
## SEULEMENT DANS LES MODES SANS FIN (retouche du co-auteur apres test, 30/09 :
## "tres bien realise, mais ne pas rendre accessible au combat de campagne").
## Un niveau de campagne part TOUJOURS sans passif : ses passifs viennent des
## montees de niveau, a partir de l acte 2, comme avant. Raison : un niveau de
## campagne est un combat MESURE (banc, objectifs, seuils regles sur une sonde
## de parties) ; trois passifs choisis a l avance le rendraient plus facile a
## mesure que la collection grossit, et les objectifs perdraient leur sens. Le
## deck construit et ses passifs sont l affaire des modes ou le joueur compose.
## Hors campagne, la regle d acte tient toujours (passives_allowed).
func equip_saved_passives() -> int:
	if not GameEnums.is_endless(mode):
		return 0
	if not passives_allowed(current_level_def, mode):
		return 0
	var n: int = 0
	for c: SpellCard in SaveData.equipped_passive_cards():
		if equip_passive(c):
			n += 1
	return n


## Carte brulee en attente de lancement, lue par GameController. Null si aucune.
var burned_card: SpellCard = null


## BRULER une carte proposee : elle est lancee immediatement mais n entre jamais
## dans le deck. C est un choix de puissance TOUT DE SUITE contre une valeur sur
## la duree — sans ce prix, bruler serait toujours le bon choix.
## Elle n est pas non plus OBTENUE (chantier P) : la collection fait partie de la
## valeur durable a laquelle on renonce en brulant.
##
## UN PASSIF NE SE BRULE PAS (chantier W8). Bruler, c est LANCER la carte ; un
## passif ne se lance pas (EffectRegistry.cast l ignore : il change une regle, il
## ne s execute pas). Bruler un passif retirait donc la carte de l offre SANS
## AUCUN EFFET — le joueur perdait son choix. On refuse plutot que d inventer un
## effet de remplacement que rien a l ecran n annoncerait : l offre reste ouverte,
## et l ecran grise les passifs des que le mode bruler est arme.
func burn_offer(i: int) -> SpellCard:
	if i < 0 or i >= pending_offer.size():
		return null
	if not can_burn(pending_offer[i]):
		return null
	var card: SpellCard = pending_offer[i]
	pending_offer.clear()
	burned_card = card
	offer_taken.emit(card)
	return card


func take_burned() -> SpellCard:
	var c: SpellCard = burned_card
	burned_card = null
	return c


## Cette carte peut-elle etre brulee ? Seul un SORT : voir burn_offer().
static func can_burn(card: SpellCard) -> bool:
	return card != null and not card.is_passive


## MEDITER (chantier W8) : la quatrieme reponse a une montee de niveau, a cote
## des trois cartes et de BRULER. Aucune carte n entre dans le deck ; chaque
## carte EN MAIN gagne GameConfig.MEDITATE_CARD_XP point d XP de carte
## (grant_card_xp), ce qui la rapproche de sa prochaine maturation.
##
## Par CARTE DISTINCTE et non par exemplaire : deux copies d une meme carte
## partagent leur XP (casts_by_card est indexe par id). Deux Boules de feu en main
## gagnent donc +1 a elles deux, la meme chose que le lisere montre sur chacune.
## Les cartes petrifiees ou volees meditent aussi : elles sont en main, et l XP
## est un progres du SORT, pas de l exemplaire bloque.
##
## Consomme l offre comme un choix (la partie reprend) et rend le nombre de
## cartes qui ont gagne de l XP.
func meditate_offer() -> int:
	if pending_offer.is_empty():
		return 0
	pending_offer.clear()
	var vues: Dictionary = {}
	var n: int = 0
	for c: SpellCard in hand.duplicate():
		if c == null or c.is_passive or vues.has(c.id):
			continue
		vues[c.id] = true
		# L offre est deja vide AVANT la premiere XP : une maturation ouverte par
		# cette XP ne doit pas etre bloquee par un choix de carte encore « en cours ».
		if grant_card_xp(c, GameConfig.MEDITATE_CARD_XP):
			n += 1
	offer_taken.emit(null)
	return n


func pick_offer(i: int) -> SpellCard:
	if i < 0 or i >= pending_offer.size():
		return null
	var card: SpellCard = pending_offer[i]
	pending_offer.clear()
	# OBTENTION (chantier P) : la PREMIERE prise en combat fait entrer la carte
	# dans le livre, utilisable au deck. Ecrit ICI, au geste de prendre, et pas
	# dans add_card_to_discard : c est le choix du joueur qui obtient, pas le fait
	# qu une carte transite par la defausse. Un passif choisi est obtenu meme si
	# le joueur refuse ensuite l echange : il l a pris, il pourra l equiper depuis
	# l ecran de deck. Une carte BRULEE, elle, n est pas obtenue (burn_offer).
	SaveData.discover_card(card.id)
	# Un PASSIF choisi s EQUIPE, il n entre pas dans le deck. Le faire passer par
	# la defausse le rendrait piochable et annulerait tout le principe : les
	# passifs sont hors deck. S il n y a plus de place, gain_passive() le met en
	# attente d un echange decide par le joueur.
	if card.is_passive:
		gain_passive(card)
	else:
		add_card_to_discard(card)
	offer_taken.emit(card)
	return card


## Les cartes d une rarete DU POOL, dans UNE SEULE famille : sorts ou passifs.
## Les deux familles ne se melangent jamais dans un meme tirage, sinon les 20 %
## promis seraient dilues par la taille relative des deux catalogues.
func _pool_of(pool: Array[SpellCard], rarity: GameEnums.Rarity,
		passifs: bool) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in pool:
		if c != null and c.rarity == rarity and c.is_passive == passifs:
			out.append(c)
	return out


## Proposer un passif deja equipe serait un choix vide : il ne pourrait ni
## s ajouter, ni declencher d echange utile.
func _deja_equipe(c: SpellCard) -> bool:
	return c != null and c.is_passive and equipped_passives.has(c)


func _shuffle_cards(arr: Array[SpellCard]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: SpellCard = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Qui a inflige les coups, pour le bilan de defaite : {nom affichable: nombre}.
var hits_by_source: Dictionary = {}


func note_damage_taken(source: EnemyDef = null) -> void:
	took_any_damage = true
	var nom: String = source.display_name if source != null else "Projectile"
	hits_by_source[nom] = int(hits_by_source.get(nom, 0)) + 1
	# OBJECTIFS (no_hit_from, hit_from) : le meme coup, range par id d espece.
	_note_hit_from(source)


## Le monstre qui a le plus coute de vitesse sur la partie, "" si aucun coup recu.
func worst_threat() -> String:
	var pire: String = ""
	var n: int = 0
	for nom in hits_by_source:
		if int(hits_by_source[nom]) > n:
			n = int(hits_by_source[nom])
			pire = String(nom)
	return pire


func note_speed_drop() -> void:
	speed_dropped = true


# --- OBJECTIFS PARAMETRES ----------------------------------------------------
#
# Les compteurs que lit ObjectiveChecker (voir le tableau en tete de
# objective_checker.gd). Ils ne JUGENT rien : ils enregistrent des faits de la
# partie, et chaque objectif en tire sa regle avec ses propres parametres. C est
# ce qui permet a deux niveaux d exiger "5 monstres en 1 s" et "3 monstres d un
# coup" sans une ligne de code de plus.
#
# L HORLOGE est du temps REEL de combat : la somme des delta bruts passes a
# GameController.simulate(), hors pauses (choix de carte, amelioration). C est
# le seul temps que le joueur percoit et peut viser ; le temps du monde, lui,
# court cinq fois plus vite a 500 % et rendrait "gagner en moins de 3 min"
# illisible.

## Secondes de combat ecoulees (temps reel, pauses exclues).
var run_time: float = 0.0
## Instant (run_time) de chaque monstre tue, dans l ordre. Les projectiles n y
## sont pas : Battlefield n emet pas leur mort comme une victime.
var kill_times: PackedFloat64Array = PackedFloat64Array()
var flying_kills: int = 0
## Sorts lances par TAG (valeur entiere de GameEnums.DamageTag -> nombre).
var casts_by_tag: Dictionary = {}
## Sorts lances par CLE D EFFET (StringName -> nombre). Une carte a deux effets
## de meme cle ne compte qu une fois : on compte des LANCERS, pas des effets.
var casts_by_effect: Dictionary = {}
## Coups qui ont mordu un monstre en garde de renvoi (donc renvoyes au mage).
var reflect_hits: int = 0
## Point le plus bas atteint par un monstre, en fraction du chemin
## apparition -> ligne du mage (0 = en haut, 1 = au contact).
var enemy_depth_max: float = 0.0
## Monstres releves et pas encore acheves : id d instance -> run_time du releve.
var _revived_at: Dictionary = {}
## Delai releve -> mort de chaque monstre releve PUIS acheve.
var revive_kill_delays: Array[float] = []
## Photo de la fin de partie, prise a la victoire. -1 tant qu il n y en a pas :
## les objectifs lisent alors l etat courant (tests, ecran ouvert hors combat).
var victory_speed_percent: int = -1
var victory_time: float = -1.0


func _reset_objective_counters() -> void:
	run_time = 0.0
	kill_times = PackedFloat64Array()
	flying_kills = 0
	casts_by_tag.clear()
	casts_by_effect.clear()
	reflect_hits = 0
	enemy_depth_max = 0.0
	_revived_at.clear()
	revive_kill_delays.clear()
	victory_speed_percent = -1
	victory_time = -1.0
	_failed_objectives.clear()
	# Objectifs lies aux cartes et aux monstres (section du meme nom).
	_reset_card_monster_counters()


## Avance l horloge des objectifs. delta BRUT : voir l en-tete de la section.
##
## C est aussi le battement ou l on guette les objectifs PERDUS : appele une fois
## par image de combat (GameController.simulate), jamais pendant une pause.
func advance_clock(delta: float) -> void:
	run_time += maxf(delta, 0.0)
	watch_objectives()


## Objectifs du niveau deja perdus dans cette partie : id -> true.
var _failed_objectives: Dictionary = {}


## Emet `objective_failed` UNE fois par objectif, a l image ou il devient
## impossible (ObjectiveChecker.is_failed). Le signal existait depuis le debut
## et rien ne l emettait : le joueur apprenait son echec a l ecran de victoire.
##
## Par SONDAGE et non branche sur chaque evenement : dix sources differentes
## font perdre un objectif (coup recu, sort lance, renvoi, profondeur, horloge,
## passif...). Brancher chacune ouvrait dix occasions d en oublier une ; relire
## les compteurs une fois par image n en oublie aucune, pour trois objectifs.
##
## Campagne seulement : le Massacre n a pas d objectifs (voir le briefing).
func watch_objectives() -> void:
	if current_level_def == null or mode != GameEnums.Mode.EXPLORATION:
		return
	for o: ObjectiveDef in current_level_def.objectives:
		if o == null or _failed_objectives.has(o.id):
			continue
		if ObjectiveChecker.is_failed(o):
			_failed_objectives[o.id] = true
			objective_failed.emit(o.id)


func is_objective_failed(objective_id: StringName) -> bool:
	return _failed_objectives.has(objective_id)


func _note_cast_for_objectives(card: SpellCard) -> void:
	# L element du sort compte comme un tag (vague 8 : il vit dans
	# SpellCard.element, plus dans `tags`).
	for t in card.combat_tags():
		casts_by_tag[int(t)] = int(casts_by_tag.get(int(t), 0)) + 1
	var vues: Dictionary = {}
	for k: StringName in card.effect_keys():
		if vues.has(k):
			continue
		vues[k] = true
		casts_by_effect[k] = int(casts_by_effect.get(k, 0)) + 1


func casts_with_tag(tag: int) -> int:
	return int(casts_by_tag.get(tag, 0))


func casts_with_effect(key: StringName) -> int:
	return int(casts_by_effect.get(key, 0))


## Le sort le plus lance de la partie : son nombre de lancers.
func max_same_card_casts() -> int:
	var best: int = 0
	for k in casts_by_card:
		best = maxi(best, int(casts_by_card[k]))
	return best


## Nombre de sorts DIFFERENTS lances (par id : trois exemplaires = un sort).
func distinct_cards_cast() -> int:
	return casts_by_card.size()


## Un monstre vient de mourir (branche sur Battlefield.enemy_killed par le
## GameController).
func note_kill(def: EnemyDef) -> void:
	kill_times.append(run_time)
	if def != null and def.flying:
		flying_kills += 1


## Le plus grand nombre de morts tenant dans une fenetre STRICTEMENT plus courte
## que `window` secondes. Des morts de la meme image ont le meme instant : elles
## tiennent toujours ensemble, quel que soit `window` > 0.
func best_kill_burst(window: float) -> int:
	# Fenetre nulle : la boucle ci-dessous depasserait j. L AUDIT l interdit deja.
	if window <= 0.0:
		return 0
	var best: int = 0
	var i: int = 0
	for j in kill_times.size():
		while kill_times[j] - kill_times[i] >= window:
			i += 1
		best = maxi(best, j - i + 1)
	return best


## Un coup a mordu pendant une garde de renvoi. Appele d un seul endroit,
## Battlefield._reflect_to_mage(), qui ne s execute QUE dans ce cas.
func note_reflect_hit() -> void:
	reflect_hits += 1


## Un monstre vient de se relever (Enemy._try_revive).
func note_enemy_revived(instance_id: int) -> void:
	_revived_at[instance_id] = run_time


## Un monstre releve vient de mourir pour de bon (Enemy.kill).
func note_revived_enemy_killed(instance_id: int) -> void:
	if not _revived_at.has(instance_id):
		return
	revive_kill_delays.append(run_time - float(_revived_at[instance_id]))
	_revived_at.erase(instance_id)


## Monstres releves jamais acheves (partis au contact, gobes...).
func revived_still_standing() -> int:
	return _revived_at.size()


## Depuis combien de secondes le plus ancien releve encore debout l est. 0 si
## aucun. Sert a declarer boss_quick_after_revive perdu SANS attendre sa mort :
## passe le delai, il ne peut plus etre acheve a temps.
func revived_oldest_age() -> float:
	var age: float = 0.0
	for id in _revived_at:
		age = maxf(age, run_time - float(_revived_at[id]))
	return age


## Fraction du chemin parcouru a l ordonnee `y`, bornee a [0, 1].
static func depth_ratio(y: float) -> float:
	var course: float = GameConfig.MAGE_LINE_Y - GameConfig.SPAWN_LINE_Y
	if course <= 0.0:
		return 0.0
	return clampf((y - GameConfig.SPAWN_LINE_Y) / course, 0.0, 1.0)


## Releve la profondeur des monstres vivants. Appele par GameController une
## fois par image, APRES la simulation du terrain. Tableau NON type : l appelant
## passe Battlefield.enemies, et un parametre Array[Enemy] ferait dependre
## RunState de la scene de jeu pour rien.
##
## Angle mort assume : un monstre qui touche le mage est retire du terrain dans
## l image meme ou il arrive, sa derniere position n est donc pas relevee — mais
## celle de l image d avant l est, a un pas de deplacement de la ligne. C est
## pourquoi ObjectiveChecker borne le ratio de no_enemy_past a 0,95.
func note_enemy_depths(enemies: Array) -> void:
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var n: Node2D = e as Node2D
		if n == null or not n.has_method("is_dead") or n.call("is_dead"):
			continue
		var def: EnemyDef = n.get("definition") as EnemyDef
		if def != null and def.projectile:
			continue
		enemy_depth_max = maxf(enemy_depth_max, depth_ratio(n.position.y))


## Photo de fin : vitesse et temps AU MOMENT de la victoire. L ecran de victoire
## juge les objectifs apres le changement de scene ; rien ne garantit que la
## jauge n aura pas bouge d ici la.
func note_victory() -> void:
	victory_speed_percent = SpeedGauge.speed_percent
	victory_time = run_time


func final_speed_percent() -> int:
	return victory_speed_percent if victory_speed_percent >= 0 else SpeedGauge.speed_percent


func final_time() -> float:
	return victory_time if victory_time >= 0.0 else run_time


# --- OBJECTIFS LIES AUX CARTES ET AUX MONSTRES ------------------------------
#
# Les faits que lisent card_casts, no_card, kill_type_one_cast,
# kill_type_with_card, no_hit_from, hit_from et enemy_travel. Les regles
# (qu est-ce qu un lancer, un coup recu, un chemin) sont ecrites une seule fois,
# en tete de objective_checker.gd.
#
# LA SOURCE DES DEGATS. `damage_source` dit a qui appartient le coup qui part EN
# CE MOMENT : {"cast": numero de lancer, "card": id de carte}, vide si personne.
# EffectRegistry.cast() l ouvre pendant la resolution d un sort ; ce que le sort
# pose (zone, allie, autel) la recopie a sa creation et la remet en place
# chaque fois qu il frappe (Battlefield). Une mort etant SYNCHRONE du coup qui
# la cause (take_damage -> kill -> died), la source lue au moment de la mort
# est celle du coup de grace.
#
# Pourquoi une source AMBIANTE plutot qu un parametre de plus a damage_enemy() :
# les handlers, les zones et les allies frappent deja par ce chemin, et un
# parametre aurait demande de toucher chacun d eux — donc d en oublier un, et
# une carte aurait tue sans jamais etre creditee.

## Meta posee sur chaque Enemy : le chemin parcouru, en pixels (Battlefield).
const TRAVEL_META: StringName = &"obj_travel"

## Numero du dernier lancer ouvert. Jamais remis a zero entre deux parties :
## seul l ordre compte, et un numero neuf ne peut pas heriter d un vieux compte.
var _cast_serial: int = 0
var damage_source: Dictionary = {}
## Morts par lancer et par espece : {numero: {id d espece: nombre}}.
var _kills_by_cast: Dictionary = {}
## Record par espece : le plus de morts de cette espece dues a UN lancer.
var _best_kills_one_cast: Dictionary = {}
## Morts par carte et par espece : {id de carte: {id d espece: nombre}}.
var _kills_by_card: Dictionary = {}
## Coups recus par espece (id d EnemyDef). Distinct de hits_by_source, range
## par NOM affiche pour le bilan de defaite : deux especes peuvent partager un
## nom, un objectif doit viser l une sans l autre.
var hits_by_enemy_id: Dictionary = {}
## Plus long chemin d un monstre TUE : par espece, et toutes especes.
var _travel_record: Dictionary = {}
var _travel_record_any: float = 0.0
## Plus long chemin d un monstre VIVANT, releve a chaque image (affichage seul).
var _travel_live: Dictionary = {}
var _travel_live_any: float = 0.0


func _reset_card_monster_counters() -> void:
	damage_source = {}
	_kills_by_cast.clear()
	_best_kills_one_cast.clear()
	_kills_by_card.clear()
	hits_by_enemy_id.clear()
	_travel_record.clear()
	_travel_record_any = 0.0
	_travel_live.clear()
	_travel_live_any = 0.0


## Ouvre un lancer : un numero neuf devient la source courante. Rend la source
## precedente, que l appelant remet en place a la fin (swap_damage_source) : un
## sort resolu pendant un autre ne doit pas lui voler la suite de ses coups.
func open_cast_source(card: SpellCard) -> Dictionary:
	_cast_serial += 1
	var avant: Dictionary = damage_source
	damage_source = {"cast": _cast_serial, "card": card.id if card != null else &""}
	return avant


## Remplace la source courante et rend l ancienne. Vide = coup sans source.
func swap_damage_source(src: Dictionary) -> Dictionary:
	var avant: Dictionary = damage_source
	damage_source = src
	return avant


## Numero du lancer en cours, 0 hors lancer.
func current_cast_id() -> int:
	return int(damage_source.get("cast", 0))


## Un monstre vient de mourir (Battlefield._on_enemy_died, memes morts que
## note_kill) : on le credite au lancer et a la carte de la source courante.
func note_kill_by_source(def: EnemyDef) -> void:
	if def == null or damage_source.is_empty():
		return
	var espece: StringName = def.id
	var lancer: int = int(damage_source.get("cast", 0))
	if lancer > 0:
		var par_lancer: Dictionary = _kills_by_cast.get(lancer, {})
		par_lancer[espece] = int(par_lancer.get(espece, 0)) + 1
		_kills_by_cast[lancer] = par_lancer
		_best_kills_one_cast[espece] = maxi(int(_best_kills_one_cast.get(espece, 0)),
			int(par_lancer[espece]))
	var carte: StringName = damage_source.get("card", &"")
	if carte != &"":
		var par_carte: Dictionary = _kills_by_card.get(carte, {})
		par_carte[espece] = int(par_carte.get(espece, 0)) + 1
		_kills_by_card[carte] = par_carte


func best_kills_in_one_cast(enemy_id: StringName) -> int:
	return int(_best_kills_one_cast.get(enemy_id, 0))


func kills_with_card(card_id: StringName, enemy_id: StringName) -> int:
	return int((_kills_by_card.get(card_id, {}) as Dictionary).get(enemy_id, 0))


## Lancers de la carte `card_id` dans la partie (tous exemplaires).
func casts_of_id(card_id: StringName) -> int:
	return int(casts_by_card.get(card_id, 0))


## Branche dans note_damage_taken : chaque coup impute a un monstre.
func _note_hit_from(source: EnemyDef) -> void:
	if source == null:
		return
	hits_by_enemy_id[source.id] = int(hits_by_enemy_id.get(source.id, 0)) + 1


## Coups recus de l espece `enemy_id`, ses projectiles-monstres compris (une
## boule de poison touche au nom de son lanceur : voir COUP RECU).
func hits_from_enemy(enemy_id: StringName) -> int:
	var n: int = int(hits_by_enemy_id.get(enemy_id, 0))
	var def: EnemyDef = ContentDB.enemies.get(enemy_id)
	if def != null and def.summon_def != null and def.summon_def.projectile \
			and def.summon_def.id != enemy_id:
		n += int(hits_by_enemy_id.get(def.summon_def.id, 0))
	return n


## Un monstre meurt apres avoir parcouru `px` pixels de chemin.
func note_travel_at_death(def: EnemyDef, px: float) -> void:
	if def == null or def.projectile:
		return
	_travel_record[def.id] = maxf(float(_travel_record.get(def.id, 0.0)), px)
	_travel_record_any = maxf(_travel_record_any, px)


## Plus long chemin d un monstre tue (de l espece, ou toutes si &"").
func travel_record_of(enemy_id: StringName) -> float:
	if enemy_id == &"":
		return _travel_record_any
	return float(_travel_record.get(enemy_id, 0.0))


## Releve le chemin des monstres vivants (GameController, une fois par image).
## Tableau NON type, meme raison que note_enemy_depths.
func note_enemy_travel_live(enemies: Array) -> void:
	_travel_live.clear()
	_travel_live_any = 0.0
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var n: Node = e as Node
		if n == null or not n.has_meta(TRAVEL_META):
			continue
		var def: EnemyDef = n.get("definition") as EnemyDef
		if def == null or def.projectile:
			continue
		var px: float = float(n.get_meta(TRAVEL_META))
		_travel_live[def.id] = maxf(float(_travel_live.get(def.id, 0.0)), px)
		_travel_live_any = maxf(_travel_live_any, px)


func travel_live_of(enemy_id: StringName) -> float:
	if enemy_id == &"":
		return _travel_live_any
	return float(_travel_live.get(enemy_id, 0.0))


# --- Sorts demandes par le testeur : echo de la main, double incantation ---

## Les `count` prochaines cartes lancees reviennent en main au lieu de partir.
## Les charges s ADDITIONNENT : deux echos d affilee valent deux cartes gardees.
## Le multiplicateur de degats, lui, ne s empile pas (voir empower_next) — mais
## ici cumuler ne cree aucune boucle infinie, seulement un tour de main plus long.
func retain_next(count: int = 1) -> void:
	_retain_charges += maxi(count, 1)


func retained_casts() -> int:
	return _retain_charges


## Autorise deux incantations simultanees pendant `duration` secondes.
## Duree en temps REEL comme la reduction de cout : c est un avantage de mage,
## pas un evenement du monde, et l accelerer a x4 le rendrait presque gratuit.
func allow_double_cast(duration: float) -> void:
	_double_cast_time = maxf(_double_cast_time, duration)


func double_cast_active() -> bool:
	return _double_cast_time > 0.0


## --- AMELIORATION DES CARTES EN COMBAT ---
##
## "Amelioration des cartes en combat (XP par lancer, choix parmi 3)".
##
## Un sort que le joueur LANCE souvent gagne de l experience. A chaque palier
## (GameConfig.CARD_UPGRADE_CASTS lancers, puis un ecart plus long) il MURIT :
## l ecran propose trois voies TIREES dans le POOL de ce sort. Le pool est derive de ses
## effets (degats, ralentissement, PV, zone, nombre de cibles, duree, vitesse de
## lancement...), chaque axe en forme LEGERE (petit gain gratuit) ou FORTE (gros
## gain paye sur un autre axe, parfois de deux facons). Le joueur en retient une,
## POUR LA PARTIE EN COURS.
##
## POURQUOI UN POOL ET UN TIRAGE (demande du co-auteur, 30/09)
## -----------------------------------------------------------
## Le trio etait FIXE : pour un sort donne, le joueur voyait toujours les trois
## memes propositions, et au bout de trois parties le choix etait appris par
## coeur. Le pool compte toujours PLUS de voies que l ecran n en montre
## (verrouille par test_upgrades.gd), donc la proposition change d une partie a
## l autre. Le tirage passe par le RNG de la partie (_rng, fixe par set_seed) :
## une graine donnee rejoue les memes propositions, et le banc reste
## reproductible.
##
## PLUSIEURS MATURATIONS PAR SORT (GameConfig.CARD_UPGRADE_TIERS)
## --------------------------------------------------------------
## Le co-auteur parle de "montees de niveau des sorts" au pluriel. Un sort
## murit donc une fois par palier, jusqu a CARD_UPGRADE_TIERS fois par partie ;
## une voie deja prise n est plus proposee, et les voies se CUMULENT (les
## pourcentages s additionnent : +30 % puis +10 % de degats font +40 %).
## Renoncer consomme le palier sans fermer les suivants.
##
## POURQUOI PAS PERMANENT
## ----------------------
## Tout l equilibrage du jeu est mesure au banc (tools/sim_balance.gd) sur un
## depart connu : les niveaux sont rejoues depuis un deck de base. Si les
## ameliorations s accumulaient d une partie a l autre, la dixieme partie
## partirait avec un deck bien plus fort que la premiere et les taux mesures ne
## decriraient plus aucune partie reelle. Le joueur qui reprend au niveau 6
## apres dix parties n y trouverait pas la difficulte annoncee. C est la meme
## raison qui garde les passifs hors de la sauvegarde pendant un combat.
##
## OU L AMELIORATION MORD
## ----------------------
## Les EffectSpec sont des Resources PARTAGEES et mises en cache : le meme objet
## sert la carte en main, la fiche du grimoire et la partie suivante. On n ecrit
## donc JAMAIS dedans. `cast_specs()` rend des COPIES modifiees, relues a chaque
## lancement — c est le seul point par ou les valeurs d un sort sortent vers les
## handlers (voir EffectRegistry.cast). Seul le prix "carte defaussee" se paie
## ailleurs, dans note_cast : un PRIX ne doit etre paye qu une fois par lancer
## reel, alors que cast_specs est aussi lu par l apercu de visee.

## Lancers par carte SUR LA PARTIE : {id de carte -> nombre}.
## Indexe par `id` et non par l objet : la meme carte peut avoir plusieurs
## exemplaires dans le deck, et ce sont bien tous « le meme sort » aux yeux du
## joueur — trois copies de Boule de feu progressent ensemble.
var casts_by_card: Dictionary = {}
## Voies retenues par carte SUR LA PARTIE : {id de carte -> Array d ids de voie},
## une entree par maturation passee, "none" quand le joueur a renonce. Un ancien
## appelant qui y range un id seul (StringName) reste lu : voir _taken_list.
var upgrades_taken: Dictionary = {}
## Carte dont l amelioration attend un choix. Null si aucune.
var pending_upgrade_card: SpellCard = null
## Les voies TIREES pour l offre en attente. Gardees ici et non retirees au
## moment du choix : le tirage consomme le RNG de la partie, le refaire au clic
## rendrait d autres voies que celles que le joueur a lues.
var pending_upgrade_paths: Array = []

signal upgrade_ready(card: SpellCard, paths: Array)
signal upgrade_taken(card: SpellCard, path: Dictionary)


## Un sort vient d etre RESOLU. Appele depuis EffectRegistry.cast(), le point de
## passage unique de tout sort reellement lance : compter ailleurs (dans la main,
## dans le Caster) laisserait des chemins ou le compteur n avancerait pas, et le
## joueur verrait son sort favori ne jamais progresser sans comprendre pourquoi.
func note_cast(card: SpellCard) -> void:
	if card == null or card.is_passive:
		return
	var cle: StringName = card.id
	casts_by_card[cle] = int(casts_by_card.get(cle, 0)) + 1
	# Objectifs : element et effets du sort. AVANT les retours anticipes qui
	# suivent, sinon un sort deja ameliore cesserait d etre compte.
	_note_cast_for_objectives(card)
	# PRIX "carte defaussee" d une voie deja prise. Ici et non dans cast_specs :
	# l apercu de visee relit cast_specs a chaque glissement, le joueur perdrait
	# une carte a chaque fois qu il vise.
	_pay_card_price(card)
	_try_open_maturation(card)


## XP DE CARTE donnee SANS lancer (chantier W8). Une XP de carte vaut un lancer
## pour la MATURATION : meme palier, meme lisere, meme offre (card_xp). Mais ce
## n est PAS un lancer pour le reste : ni objectif (« lancer 30 fois le meme
## sort »), ni prix « carte defaussee », ni compteur du grimoire. La
## meditation de la montee de niveau l utilise ; la carte Concentration la
## reutilisera (chantier suivant) — un seul point d entree, pour que les deux
## fassent murir les sorts exactement comme un lancer.
##
## Rend vrai si la carte a gagne l XP (un passif n a pas de maturation).
func grant_card_xp(card: SpellCard, n: int = 1) -> bool:
	if card == null or card.is_passive or n <= 0:
		return false
	# Compteur A PART et non casts_by_card : les objectifs lisent casts_by_card
	# (« le meme sort 30 fois », « au plus N sorts differents »), et une
	# meditation n est pas un lancer.
	card_xp_bonus[card.id] = int(card_xp_bonus.get(card.id, 0)) + n
	_try_open_maturation(card)
	return true


## XP de carte donnee hors lancer, par id (meditation, Concentration). Remise a
## zero avec la partie, comme casts_by_card.
var card_xp_bonus: Dictionary = {}


## L XP de MATURATION d une carte : ses lancers plus l XP donnee. C est ce que
## lisent les paliers, le lisere et l ecran d amelioration.
func card_xp(card: SpellCard) -> int:
	if card == null:
		return 0
	return casts_of(card) + int(card_xp_bonus.get(card.id, 0))


## L XP donnee hors lancer a cette carte (pour l ecran : « dont N meditees »).
func card_xp_given(card: SpellCard) -> int:
	return int(card_xp_bonus.get(card.id, 0)) if card != null else 0


## Ouvre l offre de maturation de `card` si elle a atteint son palier. Le seul
## endroit ou l offre s ouvre : lancer et XP donnee y passent tous les deux.
func _try_open_maturation(card: SpellCard) -> bool:
	# Une seule offre a la fois : deux ecrans modaux empiles laisseraient le
	# second sans moyen d etre ferme, et la partie resterait en pause pour de bon.
	# Une carte qui franchit son palier PENDANT une autre offre n est pas perdue :
	# _open_next_ready_maturation() la reprend des que l offre en cours se ferme.
	if pending_upgrade_card != null:
		return false
	if not _maturation_ready(card):
		return false
	var voies: Array = draw_upgrade_offer(card)
	if voies.is_empty():
		return false
	pending_upgrade_card = card
	pending_upgrade_paths = voies.duplicate(true)
	upgrade_ready.emit(card, voies.duplicate(true))
	return true


## La carte a-t-elle franchi le palier de sa PROCHAINE maturation, et lui en
## reste-t-il une ? Sans le second garde, le sort favori ouvrirait un ecran modal
## a chaque palier jusqu a la fin de la partie.
func _maturation_ready(card: SpellCard) -> bool:
	if card == null or card.is_passive:
		return false
	if maturations_done(card) >= upgrade_tiers_for(card):
		return false
	return card_xp(card) >= next_upgrade_at(card)


## Apres un choix ou un refus : une autre carte attendait-elle son ecran ? C est
## le cas de la MEDITATION, qui donne une XP a toute la main d un coup : deux
## cartes peuvent franchir leur palier ensemble, et la seconde n aurait sinon
## muri qu a son prochain lancer, sans que le joueur sache pourquoi.
## On cherche dans les cartes de la PARTIE (main, pioche, defausse) : une carte
## exilee ou brulee n a plus d ecran a ouvrir.
func _open_next_ready_maturation() -> void:
	if pending_upgrade_card != null:
		return
	var vues: Dictionary = {}
	for pile: Array[SpellCard] in [hand, deck, discard]:
		for c: SpellCard in pile:
			if c == null or vues.has(c.id):
				continue
			vues[c.id] = true
			if _try_open_maturation(c):
				return


func casts_of(card: SpellCard) -> int:
	if card == null:
		return 0
	return int(casts_by_card.get(card.id, 0))


## Nombre de lancers qui declenche la PROCHAINE maturation de cette carte.
func next_upgrade_at(card: SpellCard) -> int:
	return upgrade_threshold(maturations_done(card))


## Lancers CUMULES qui declenchent la maturation numero `faites` + 1. L ecart
## entre deux paliers GRANDIT de GameConfig.CARD_UPGRADE_GAP_STEP a chaque
## maturation (8, 16, 24... : paliers a 8, 24, 48, 80, 120). Un ecart constant
## ouvrait jusqu a dix ecrans modaux par partie sur les niveaux longs, la cadence
## que GameConfig.CARD_UPGRADE_CASTS ecarte deja. Le lisere de la carte suit
## l ecart EN COURS (upgrade_progress), donc la jauge ne ment pas.
func upgrade_threshold(faites: int) -> int:
	var total: int = 0
	for k in faites + 1:
		total += upgrade_gap(k)
	return total


## Lancers entre la maturation `faites` et la suivante.
func upgrade_gap(faites: int) -> int:
	return maxi(1, GameConfig.CARD_UPGRADE_CASTS) \
		+ maxi(0, faites) * maxi(0, GameConfig.CARD_UPGRADE_GAP_STEP)


## Nombre de maturations que CETTE carte peut faire dans une partie : le reglage
## (GameConfig.CARD_UPGRADE_TIERS), mais jamais plus que son pool ne compte de
## voies. Une voie prise n est plus proposee : la Riviere (4 voies) n a donc que
## quatre maturations. Sans cette borne, son lisere resterait plein a jamais en
## attendant un ecran qui ne peut plus s ouvrir.
func upgrade_tiers_for(card: SpellCard) -> int:
	if card == null:
		return 0
	return mini(GameConfig.CARD_UPGRADE_TIERS, upgrade_pool_for(card).size())


## Maturations deja passees (voie prise OU refusee).
func maturations_done(card: SpellCard) -> int:
	return _taken_list(card).size()


## Avancement vers la PROCHAINE maturation, de 0 a 1, et 1 quand le sort a fait
## toutes les siennes. Lu par l interface pour poser une pastille sur la carte :
## sans ce retour, le joueur ne sait pas qu un sort progresse et le palier tombe
## comme une surprise.
func upgrade_progress(card: SpellCard) -> float:
	if card == null:
		return 0.0
	var faites: int = maturations_done(card)
	if faites >= upgrade_tiers_for(card):
		return 1.0
	var debut: int = upgrade_threshold(faites - 1) if faites > 0 else 0
	return clampf(float(card_xp(card) - debut) / float(upgrade_gap(faites)), 0.0, 1.0)


## La DERNIERE maturation de la carte (id de voie, "none" si refusee, "" si
## aucune). Le HUD s en sert pour dorer le lisere d un sort deja muri.
func upgrade_of(card: SpellCard) -> StringName:
	var l: Array = _taken_list(card)
	if l.is_empty():
		return &""
	return StringName(l[-1])


## Les voies RETENUES pour cette carte, dans l ordre, sans les refus.
func upgrade_ids_of(card: SpellCard) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _taken_list(card):
		if StringName(id) != &"none" and StringName(id) != &"":
			out.append(StringName(id))
	return out


## La liste brute des maturations de la carte. Accepte aussi un id SEUL : c est
## la forme que rangeaient l ancien systeme a une maturation et ses tests ; la
## refuser ferait disparaitre une amelioration sans un mot.
func _taken_list(card: SpellCard) -> Array:
	if card == null:
		return []
	var v: Variant = upgrades_taken.get(card.id, [])
	if v is Array:
		return v
	if StringName(v) == &"":
		return []
	return [StringName(v)]


func _append_taken(card: SpellCard, id: StringName) -> void:
	var l: Array = _taken_list(card).duplicate()
	l.append(id)
	upgrades_taken[card.id] = l


## --- Les AXES d amelioration ---
##
## Un axe est UNE grandeur du sort que l amelioration peut faire varier. Chaque
## axe se lit "plus c est haut, mieux c est" : la vitesse de lancement est donc
## l INVERSE du temps d incantation. C est ce qui permet a une voie de s ecrire
## {axe -> valeur} et au meme pourcentage de se lire pareil partout.
const UP_DAMAGE := &"damage"
const UP_SLOW := &"slow"
const UP_TEMPO := &"tempo"
const UP_FORCE := &"force"
const UP_AMPLIFY := &"amplify"
const UP_HP := &"hp"
const UP_COUNT := &"count"
const UP_AREA := &"area"
const UP_DURATION := &"duration"
const UP_CAST := &"cast"
## Axes de COMPLEMENT, pour les sorts trop simples pour un pool qui varie. Ils
## se comptent en CARTES et non en pourcentage :
##   - DRAW (gain) : cartes piochees au lancement. Seul un sort sans aucun axe
##     d effet chiffre le recoit (la Riviere) ;
##   - DISCARD (prix) : cartes de la main defaussees au lancement. C est le prix
##     de la vitesse forte d un sort qui n a RIEN d autre a payer (Riviere, sorts
##     de pioche ou de retour en main) : un nombre entier ne peut pas servir de
##     prix (15 % de 2 cartes s arrondit a zero), et une voie forte sans prix
##     serait un bonus deguise.
const UP_DRAW := &"draw"
const UP_DISCARD := &"discard"
const UP_LIGHT := &"light"
const UP_STRONG := &"strong"

## Ordre de PRIORITE des axes d effet : le premier axe present est "l identite"
## du sort. Les degats passent avant tout, sauf sur un sort qui RALENTIT (voir
## _effect_axes).
const _UP_ORDER: Array[StringName] = [&"damage", &"slow", &"tempo", &"force",
	&"amplify", &"hp", &"count", &"area", &"duration"]

## Cles dont `magnitude` est un DEGAT (par coup ou par seconde). Toute autre
## magnitude est autre chose : un pourcentage, une vitesse, un facteur — ou meme
## un DESAVANTAGE (haste_enemies_boon accelere les monstres). La lire comme des
## degats ferait grossir ce que le joueur paie.
const _UP_DAMAGE_KEYS: Array[StringName] = [&"damage_single", &"pierce_line",
	&"ground_zone", &"damage_per_enemy", &"summon_ally", &"knockback",
	&"meteor_storm", &"stun_zone", &"place_terrain", &"taunt_prop", &"poison_dot"]
## Cles dont la duree n est PAS un bienfait a allonger :
##   - meteor_storm etale la MEME pluie sur plus longtemps (plus lente, pas plus
##     forte) ;
##   - haste_enemies_boon : sa duree est celle de l acceleration des MONSTRES,
##     l allonger serait un malus deguise en amelioration.
const _UP_NO_DURATION_KEYS: Array[StringName] = [&"meteor_storm", &"haste_enemies_boon"]
## Cles dont le rayon n est pas une zone a elargir. Le mur : sa longueur est
## verifiee par la garantie de chemin sur les effets du .tres au moment de viser
## (EffectHandlers.placement_allowed) — un mur ameliore plus long que l apercu
## serait accepte a la visee puis refuse a la resolution, carte payee pour rien.
const _UP_NO_AREA_KEYS: Array[StringName] = [&"build_wall", &"terrain_river"]
## Cles qui PIOCHENT deja : leur nombre de cartes est leur axe NOMBRE, leur
## proposer en plus "+1 carte piochee" ferait deux fois la meme voie sous deux noms.
const _UP_DRAWING_KEYS: Array[StringName] = [&"draw_cards", &"discard_draw",
	&"haste_enemies_boon"]
## Parametre ENTIER qui compte des cibles, des impacts ou des cartes, par cle.
const _UP_COUNT_PARAM: Dictionary = {
	&"pierce_line": &"max_targets",
	&"meteor_storm": &"impacts",
	&"discard_draw": &"count",
	&"draw_cards": &"count",
	&"remove_cards": &"count",
	&"haste_enemies_boon": &"draw",
}


## Le POOL de voies de ce sort : tout ce que ses maturations peuvent proposer.
##
## Les voies sont DERIVEES des effets de la carte, pas ecrites a la main dans
## chaque .tres. Trois raisons :
##   - 50 cartes x une dizaine de voies = des centaines d entrees a maintenir, et
##     chaque nouveau sort ajoute par un autre chantier arriverait SANS
##     amelioration ;
##   - une voie ecrite a la main peut contredire l effet reel du sort ; derivee,
##     elle ne peut pas : un sort sans zone n a pas d axe `area`, donc aucune voie
##     "+zone" ne peut lui etre proposee ;
##   - le libelle affiche les vrais pourcentages de GameConfig, il reste juste
##     quand l equilibrage bouge.
##
## CE QUE CONTIENT LE POOL, axe par axe (axes d effet puis vitesse de lancement) :
##   - la forme LEGERE ;
##   - la forme FORTE payee sur son prix naturel (voir _price_axes) ;
##   - pour l IDENTITE du sort et pour la VITESSE, une seconde forme forte payee
##     AILLEURS : "+30 % degats contre -15 % vitesse" ou "contre -15 % zone". Ce
##     sont les deux voies que le joueur veut le plus souvent ; lui laisser
##     choisir ce qu il sacrifie est le vrai choix. Pas sur les autres axes : le
##     pool doublerait sans rien apprendre de plus au joueur.
## Un sort trop simple pour que le pool depasse ce que l ecran montre (la
## Riviere, qui n a rien de chiffre) le complete par la pioche au lancement.
##
## Ordre STABLE, groupe par axe : c est l ordre du grimoire.
func upgrade_pool_for(card: SpellCard) -> Array:
	var out: Array = []
	if card == null:
		return out
	var axes: Array[StringName] = _effect_axes(card)
	var gains: Array[StringName] = axes.duplicate()
	gains.append(UP_CAST)
	var vus: Dictionary = {}
	for g in gains:
		_upgrade_pool_add(out, vus, _make_path(card, g, UP_LIGHT, axes))
		for p in _price_axes(card, g, axes):
			_upgrade_pool_add(out, vus, _make_path(card, g, UP_STRONG, axes, p))
	if out.size() <= GameConfig.LEVEL_UP_CHOICES and _may_draw_more(card):
		_upgrade_pool_add(out, vus, _make_path(card, UP_DRAW, UP_LIGHT, axes))
		_upgrade_pool_add(out, vus, _make_path(card, UP_DRAW, UP_STRONG, axes))
	return out


func _upgrade_pool_add(out: Array, vus: Dictionary, voie: Dictionary) -> void:
	if voie.is_empty() or vus.has(voie["id"]):
		return
	vus[voie["id"]] = true
	out.append(voie)


## Vrai si le sort peut recevoir l axe de complement "pioche au lancement".
func _may_draw_more(card: SpellCard) -> bool:
	for spec in card.effects:
		if spec != null and _UP_DRAWING_KEYS.has(spec.key):
			return false
	return true


## Les voies que la PROCHAINE maturation peut proposer : le pool, moins les voies
## deja prises, moins celles que le cumul rendrait intenables (un ralentissement
## deja monte qui depasserait le plafond).
func upgrade_offerable_for(card: SpellCard) -> Array:
	var out: Array = []
	if card == null:
		return out
	var prises: Array[StringName] = upgrade_ids_of(card)
	var deja: Dictionary = _summed_mods(taken_paths(card))
	var base_lent: float = _slow_max(card)
	for v in upgrade_pool_for(card):
		if prises.has(StringName(v["id"])):
			continue
		var gain_lent: float = float((v["mods"] as Dictionary).get(UP_SLOW, 0.0))
		if gain_lent > 0.0 and base_lent * (1.0 + float(deja.get(UP_SLOW, 0.0)) + gain_lent) \
				> GameConfig.UPGRADE_SLOW_CAP:
			continue
		out.append(v)
	return out


## TIRE les voies d une maturation (au plus GameConfig.LEVEL_UP_CHOICES) dans ce
## que la carte peut encore recevoir, avec le RNG de la partie.
##
## Le tirage n est pas uniforme, il garantit la forme de l ecran :
##   1. une voie LEGERE (un bonus sur, que le joueur peut prendre sans lire) ;
##   2. une voie FORTE sur un AUTRE axe que la legere (le pari) ;
##   3. une troisieme, de preference sur un axe encore absent de l ecran.
## Trois voies du meme axe ("+10 % degats", "+30 % degats contre vitesse", "+30 %
## degats contre zone") seraient trois fois la meme question.
## Puis l ordre est MELANGE : une legere toujours en tete aurait ete la voie
## sous le pouce du joueur presse. (Le banc ne prend plus la premiere voie depuis
## que l offre est melangee : il choisit par une regle, AutoPick.upgrade_index.)
##
## Un pool pas plus grand que l ecran est rendu tel quel, sans consommer le RNG.
func draw_upgrade_offer(card: SpellCard) -> Array:
	var libres: Array = upgrade_offerable_for(card)
	var n: int = GameConfig.LEVEL_UP_CHOICES
	if libres.size() <= n:
		return libres
	var tirees: Array = []
	var legeres: Array = libres.filter(func(v: Dictionary) -> bool:
		return StringName(v["form"]) == UP_LIGHT)
	if not legeres.is_empty():
		tirees.append(_pick_one(legeres))
	var fortes: Array = libres.filter(func(v: Dictionary) -> bool:
		return StringName(v["form"]) == UP_STRONG and not _offer_has_axis(tirees, v))
	if fortes.is_empty():
		fortes = libres.filter(func(v: Dictionary) -> bool:
			return StringName(v["form"]) == UP_STRONG)
	if not fortes.is_empty():
		tirees.append(_pick_one(fortes))
	var garde: int = libres.size()
	while tirees.size() < n and garde > 0:
		garde -= 1
		var reste: Array = libres.filter(func(v: Dictionary) -> bool:
			return not tirees.has(v))
		if reste.is_empty():
			break
		var neufs: Array = reste.filter(func(v: Dictionary) -> bool:
			return not _offer_has_axis(tirees, v))
		tirees.append(_pick_one(neufs if not neufs.is_empty() else reste))
	for i in range(tirees.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var t: Variant = tirees[i]
		tirees[i] = tirees[j]
		tirees[j] = t
	return tirees


func _pick_one(voies: Array) -> Dictionary:
	return voies[_rng.randi_range(0, voies.size() - 1)]


func _offer_has_axis(voies: Array, v: Dictionary) -> bool:
	for w in voies:
		if StringName(w["axis"]) == StringName(v["axis"]):
			return true
	return false


## L axe d IDENTITE du sort : le premier de ses axes d effet (degats pour une
## Boule de feu, ralentissement pour un Champ de givre), la vitesse de lancement
## pour un sort qui n a rien de chiffre. C est l axe que le grimoire presente en
## tete, et celui que le choix automatique du banc renforce (AutoPick).
func upgrade_identity_axis(card: SpellCard) -> StringName:
	if card == null:
		return UP_CAST
	var axes: Array[StringName] = _effect_axes(card)
	return axes[0] if not axes.is_empty() else UP_CAST


## Les axes d EFFET de la carte (sans la vitesse de lancement, que tout sort a),
## dans l ordre de priorite.
##
## Sur un sort qui RALENTIT, les degats passent apres la zone et la duree : le
## Champ de givre inflige 1 degat par seconde, en faire son identite ferait de
## son amelioration phare un chiffre sans effet visible.
func _effect_axes(card: SpellCard) -> Array[StringName]:
	var presents: Dictionary = {}
	for spec in card.effects:
		if spec == null:
			continue
		for a in _spec_axes(spec):
			presents[a] = true
	var out: Array[StringName] = []
	for a in _UP_ORDER:
		if presents.has(a):
			out.append(a)
	if presents.has(UP_SLOW) and out.has(UP_DAMAGE):
		out.erase(UP_DAMAGE)
		out.append(UP_DAMAGE)
	return out


## Les axes qu UN effet porte. C est la table qui decide ce qui a un sens : on ne
## touche qu a une valeur ECRITE dans la carte (param present, magnitude non
## nulle), jamais a un defaut du handler — un defaut modifie serait un chiffre
## que le joueur n a jamais vu.
func _spec_axes(spec: EffectSpec) -> Array[StringName]:
	var out: Array[StringName] = []
	var k: StringName = spec.key
	if (_UP_DAMAGE_KEYS.has(k) and spec.magnitude > 0.0) \
			or float(spec.params.get(&"ally_damage", 0.0)) > 0.0:
		out.append(UP_DAMAGE)
	if float(spec.params.get(&"slow_pct", 0.0)) > 0.0 \
			or (k == &"slow_enemy_gauge" and spec.magnitude > 0.0):
		out.append(UP_SLOW)
	if (k in [&"self_haste", &"cost_reduction", &"draw_boost"] and spec.magnitude > 0.0) \
			or float(spec.params.get(&"seconds_per_card", 0.0)) > 0.0:
		out.append(UP_TEMPO)
	if (k in [&"vortex_pull", &"water_flood"] and spec.magnitude > 0.0) \
			or float(spec.params.get(&"push", 0.0)) > 0.0:
		out.append(UP_FORCE)
	if float(spec.params.get(&"vuln_mult", 1.0)) > 1.0 \
			or (k == &"empower_next" and spec.magnitude > 1.0):
		out.append(UP_AMPLIFY)
	if float(spec.params.get(&"prop_hp", 0.0)) > 0.0 \
			or float(spec.params.get(&"wall_hp", 0.0)) > 0.0:
		out.append(UP_HP)
	var n: int = _spec_count(spec)
	if n > 0 and n < GameConfig.UPGRADE_COUNT_UNLIMITED:
		out.append(UP_COUNT)
	if spec.radius > 0.0 and not _UP_NO_AREA_KEYS.has(k):
		out.append(UP_AREA)
	if spec.duration >= GameConfig.UPGRADE_MIN_DURATION \
			and not _UP_NO_DURATION_KEYS.has(k):
		out.append(UP_DURATION)
	return out


## Le nombre (cibles, impacts, cartes) porte par cet effet, 0 s il n en a pas.
func _spec_count(spec: EffectSpec) -> int:
	if spec.key == &"retain_next":
		return int(spec.magnitude)
	var p: StringName = StringName(_UP_COUNT_PARAM.get(spec.key, &""))
	if p == &"" or not spec.params.has(p):
		return 0
	return int(spec.params[p])


## Ce qu ajoute une voie de NOMBRE. Un nombre est entier : "+10 %" de 5 cibles
## s arrondit a zero, donc la forme legere donne toujours au moins +1, et la
## forte toujours au moins un de plus que la legere — sans quoi, sur un sort a
## deux cartes, les deux formes rendraient la meme chose pour deux prix.
func upgrade_count_bonus(n: int, pct: float) -> int:
	if pct <= 0.0 or n <= 0:
		return 0
	var leger: int = maxi(1, int(round(n * GameConfig.UPGRADE_LIGHT_GAIN)))
	if pct <= GameConfig.UPGRADE_LIGHT_GAIN + 0.0001:
		return maxi(1, int(round(n * pct)))
	return maxi(leger + 1, int(round(n * pct)))


## Construit une voie, ou {} si elle n a pas de sens pour cette carte.
## `price` choisit le prix d une voie forte ; vide = son prix NATUREL, le
## premier de _price_axes. Un prix hors de _price_axes est refuse : sans ce
## garde, un id fabrique ("damage_strong_count") ferait payer un nombre entier.
func _make_path(card: SpellCard, axis: StringName, form: StringName,
		axes: Array[StringName], price: StringName = &"") -> Dictionary:
	if axis != UP_CAST and axis != UP_DRAW and not axes.has(axis):
		return {}
	# Les degats d un sort qui RALENTIT sont un a-cote (1 par seconde sur le Champ
	# de givre) : "+10 % degats" y serait un chiffre sans effet visible. Ni gain
	# ici, ni prix (voir _price_axes) : l identite de ces sorts est le ralentissement.
	if axis == UP_DAMAGE and axes.has(UP_SLOW):
		return {}
	var gain: float = _gain_of(axis, form)
	# Un ralentissement trop pres du plafond ne peut pas tenir la promesse du
	# libelle : la voie n est pas proposee plutot que de mentir.
	if axis == UP_SLOW and _slow_max(card) * (1.0 + gain) > GameConfig.UPGRADE_SLOW_CAP:
		return {}
	var mods: Dictionary = {axis: gain}
	var prix: StringName = &""
	var naturel: bool = true
	if form == UP_STRONG:
		var possibles: Array[StringName] = _price_axes(card, axis, axes)
		if possibles.is_empty():
			return {}
		prix = possibles[0] if price == &"" else price
		if not possibles.has(prix):
			return {}
		naturel = prix == possibles[0]
		mods[prix] = _price_of(prix)
	var titre: String = _axis_title(card, axis)
	var gain_txt: String = _mod_text(card, axis, gain)
	var prix_txt: String = _mod_text(card, prix, float(mods[prix])) if prix != &"" else ""
	var forme: String = "forte" if form == UP_STRONG else "legere"
	var texte: String = "%s, %s : %s" % [titre, forme, gain_txt]
	if prix_txt != "":
		texte += ", " + prix_txt
	# L id nomme le prix seulement quand ce n est pas le naturel : "damage_strong"
	# garde le sens qu il avait avant les variantes de prix (banc, tests).
	var id: String = "%s_%s" % [axis, form]
	if not naturel:
		id += "_" + String(prix)
	return {
		"id": StringName(id),
		"axis": axis,
		"form": form,
		"price_axis": prix,
		"mods": mods,
		"title": titre,
		"gain_text": gain_txt,
		"cost_text": prix_txt,
		"text": texte,
	}


## Le gain d une forme. En CARTES pour la pioche de complement, en pourcentage
## partout ailleurs.
func _gain_of(axis: StringName, form: StringName) -> float:
	if axis == UP_DRAW:
		return float(GameConfig.UPGRADE_DRAW_LIGHT if form == UP_LIGHT
			else GameConfig.UPGRADE_DRAW_STRONG)
	return GameConfig.UPGRADE_LIGHT_GAIN if form == UP_LIGHT else GameConfig.UPGRADE_STRONG_GAIN


## Le prix d une voie forte, signe (negatif = ce que le joueur perd).
func _price_of(axis: StringName) -> float:
	if axis == UP_DISCARD:
		return -float(GameConfig.UPGRADE_DISCARD_PRICE)
	return -GameConfig.UPGRADE_STRONG_COST


## Les axes qui peuvent PAYER une voie forte, le naturel en tete.
##   - gagner en vitesse se paie sur l identite du sort, ou sur son second axe ;
##     un sort sans rien d autre a payer la paie d une carte defaussee ;
##   - elargir la zone ou multiplier les coups DILUE : ca se paie en degats quand
##     le sort en fait ;
##   - le reste se paie en vitesse de lancement, comme l exemple du co-auteur
##     (+30 % degats, -15 % vitesse) — et, pour l IDENTITE du sort seulement, en
##     sacrifiant un autre de ses axes.
## Jamais un NOMBRE : un entier ne se reduit pas de 15 % (2 cartes deviendraient
## 2), le prix serait nul. Jamais les degats d un sort qui ralentit : ils sont
## symboliques (1 par seconde sur le Champ de givre), les payer ne couterait rien.
func _price_axes(card: SpellCard, gain: StringName, axes: Array[StringName]) -> Array[StringName]:
	var payables: Array[StringName] = []
	for a in axes:
		if a == UP_COUNT or a == gain:
			continue
		if a == UP_DAMAGE and axes.has(UP_SLOW):
			continue
		payables.append(a)
	var out: Array[StringName] = []
	if gain == UP_CAST:
		for a in payables:
			if out.size() < 2:
				out.append(a)
		if out.is_empty():
			out.append(UP_DISCARD)
		return out
	if gain == UP_DRAW:
		out.append(UP_CAST)
		return out
	var dilue: bool = (gain == UP_AREA or gain == UP_COUNT) and payables.has(UP_DAMAGE)
	out.append(UP_DAMAGE if dilue else UP_CAST)
	if axes.is_empty() or gain != axes[0]:
		return out
	if out[0] != UP_CAST:
		out.append(UP_CAST)
	elif not payables.is_empty():
		out.append(payables[0])
	return out


## Le plus fort ralentissement ecrit dans la carte, en %.
func _slow_max(card: SpellCard) -> float:
	var m: float = 0.0
	for spec in card.effects:
		if spec == null:
			continue
		m = maxf(m, float(spec.params.get(&"slow_pct", 0.0)))
		if spec.key == &"slow_enemy_gauge":
			m = maxf(m, spec.magnitude)
	return m


## Le premier effet de la carte qui porte cet axe : c est lui qui nomme l axe
## (aspiration, courant ou recul pour la FORCE) et qui chiffre un NOMBRE.
func _first_spec_with(card: SpellCard, axis: StringName) -> EffectSpec:
	for spec in card.effects:
		if spec != null and _spec_axes(spec).has(axis):
			return spec
	return null


## Le mot qui designe l axe dans le libelle, au plus pres du sort.
func _axis_word(card: SpellCard, axis: StringName) -> String:
	var s: EffectSpec = _first_spec_with(card, axis)
	var k: StringName = s.key if s != null else &""
	match axis:
		UP_DAMAGE:
			return "degats"
		UP_SLOW:
			return "ralentissement"
		UP_TEMPO:
			if k == &"draw_boost":
				return "vitesse de pioche"
			if k == &"self_haste":
				return "hate"
			# Reduction de cout (Faille temporelle) et main defaussee contre du
			# temps (Concentration) : les deux retirent des secondes d incantation.
			return "baisse de cout"
		UP_FORCE:
			if k == &"vortex_pull":
				return "aspiration"
			if k == &"water_flood":
				return "courant"
			return "recul"
		UP_AMPLIFY:
			return "vulnerabilite" if k != &"empower_next" else "bonus"
		UP_HP:
			return "PV"
		UP_COUNT:
			if k == &"pierce_line":
				return "cible"
			if k == &"meteor_storm":
				return "impact"
			return "carte"
		UP_AREA:
			return "zone"
		UP_DURATION:
			return "duree"
		UP_CAST:
			return "vitesse de lancement"
		UP_DRAW:
			return "carte piochee"
		UP_DISCARD:
			return "carte defaussee"
	return String(axis)


## Le titre de la voie : ce qui change, dans les mots du sort. Un titre generique
## ("Force", "Acceleration") obligeait a lire la ligne du dessous pour savoir si
## le Maelstrom aspirait plus fort ou repoussait plus loin.
func _axis_title(card: SpellCard, axis: StringName) -> String:
	match axis:
		UP_DAMAGE: return "Degats"
		UP_SLOW: return "Ralentissement"
		UP_TEMPO, UP_FORCE: return _majuscule(_axis_word(card, axis))
		UP_AMPLIFY:
			return "Focalisation" if _axis_word(card, axis) == "bonus" else "Vulnerabilite"
		UP_HP: return "Solidite"
		UP_COUNT: return _majuscule(_axis_word(card, axis)) + "s"
		UP_AREA: return "Zone"
		UP_DURATION: return "Duree"
		UP_CAST: return "Vitesse"
		UP_DRAW: return "Inspiration"
	return String(axis)


## Premiere lettre en majuscule, le reste intact. String.capitalize() met une
## majuscule a CHAQUE mot ("Baisse De Cout").
func _majuscule(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)


## "+30 % degats", "-15 % vitesse de lancement", "+2 impacts", "-1 carte
## defaussee au lancement". Le SIGNE est toujours ecrit : l ecran le double
## d une couleur, mais la couleur seule ne se lit pas pour tout le monde.
func _mod_text(card: SpellCard, axis: StringName, v: float) -> String:
	if axis == UP_COUNT:
		var s: EffectSpec = _first_spec_with(card, axis)
		var d: int = upgrade_count_bonus(_spec_count(s) if s != null else 0, v)
		var mot: String = _axis_word(card, axis)
		return "+%d %s%s" % [d, mot, "s" if d > 1 else ""]
	if axis == UP_DRAW or axis == UP_DISCARD:
		var n: int = int(round(absf(v)))
		var pluriel: String = "s" if n > 1 else ""
		var verbe: String = "piochee" if axis == UP_DRAW else "defaussee"
		return "%s%d carte%s %s%s au lancement" % ["+" if v >= 0.0 else "-", n, pluriel,
			verbe, pluriel]
	var signe: String = "+" if v >= 0.0 else "-"
	return "%s%s %s" % [signe, _pct(absf(v)), _axis_word(card, axis)]


## Un pourcentage PRET A AFFICHER. Le caractere pourcent n est ecrit qu ici :
## dans une chaine de format il devrait etre double, et un seul oubli afficherait
## "+45 d" au joueur. L espace avant % est la typographie francaise.
func _pct(f: float) -> String:
	return "%d %%" % int(round(f * 100.0))


## La voie `id` ("<axe>_<forme>" ou "<axe>_<forme>_<prix>") pour cette carte, ou
## {} si elle n a pas de sens pour elle. Reconstruite a partir de l id et non
## cherchee dans un tirage : la voie retenue reste lisible quel que soit l ordre
## du pool, et les tests peuvent verifier l application de chaque axe.
func upgrade_path_by_id(card: SpellCard, id: StringName) -> Dictionary:
	if card == null:
		return {}
	var morceaux: PackedStringArray = String(id).split("_")
	if morceaux.size() < 2 or morceaux.size() > 3:
		return {}
	var axe: StringName = StringName(morceaux[0])
	var forme: StringName = StringName(morceaux[1])
	if forme != UP_LIGHT and forme != UP_STRONG:
		return {}
	var prix: StringName = StringName(morceaux[2]) if morceaux.size() == 3 else &""
	if prix != &"" and forme != UP_STRONG:
		return {}
	# La pioche de COMPLEMENT n existe que pour les sorts qui en ont besoin : sans
	# ce garde, un id fabrique donnerait "+1 carte" a une Boule de feu.
	if axe == UP_DRAW:
		for v in upgrade_pool_for(card):
			if StringName(v["id"]) == id:
				return v
		return {}
	return _make_path(card, axe, forme, _effect_axes(card), prix)


## Les voies RETENUES pour cette carte, dans l ordre des maturations.
func taken_paths(card: SpellCard) -> Array:
	var out: Array = []
	for id in upgrade_ids_of(card):
		var v: Dictionary = upgrade_path_by_id(card, id)
		if not v.is_empty():
			out.append(v)
	return out


## La DERNIERE voie retenue pour cette carte, ou {} (aucune, ou refusee).
func taken_path(card: SpellCard) -> Dictionary:
	var v: Array = taken_paths(card)
	return v[-1] if not v.is_empty() else {}


## LE CUMUL LISIBLE des voies retenues (chantier W8) : une ligne par axe, dans
## l ordre du pool, avec le total — « +40 % degats », « -15 % vitesse de
## lancement », « +2 cibles ». Avec cinq maturations, recopier les voies une a
## une (« +30 % degats, -15 % vitesse ; +10 % degats ; ... ») obligeait le joueur
## a faire l addition lui-meme au moment de choisir la suivante. Un axe dont gain
## et prix s annulent n est pas ecrit : « +0 % » ne dit rien.
func upgrade_cumul_lines(card: SpellCard) -> Array[String]:
	var out: Array[String] = []
	if card == null:
		return out
	var voies: Array = taken_paths(card)
	if voies.is_empty():
		return out
	var sommes: Dictionary = _summed_mods(voies)
	var nombre: float = 0.0
	for v in voies:
		nombre += float((v.get("mods", {}) as Dictionary).get(UP_COUNT, 0.0))
	var ordre: Array[StringName] = _UP_ORDER.duplicate()
	for a in [UP_CAST, UP_DRAW, UP_DISCARD]:
		ordre.append(a)
	for a: StringName in ordre:
		if a == UP_COUNT:
			if nombre > 0.0:
				out.append(_count_cumul_text(card, voies))
			continue
		var val: float = float(sommes.get(a, 0.0))
		if absf(val) < 0.005:
			continue
		out.append(_mod_text(card, a, val))
	return out


## Le cumul d un axe de NOMBRE : la somme de ce que chaque voie a annonce (voir
## _apply_count), pas l arrondi de la somme des pourcentages.
func _count_cumul_text(card: SpellCard, voies: Array) -> String:
	var s: EffectSpec = _first_spec_with(card, UP_COUNT)
	var n: int = _spec_count(s) if s != null else 0
	var d: int = 0
	for v in voies:
		var p: float = float((v.get("mods", {}) as Dictionary).get(UP_COUNT, 0.0))
		if p > 0.0:
			d += upgrade_count_bonus(n, p)
	var mot: String = _axis_word(card, UP_COUNT)
	return "+%d %s%s" % [d, mot, "s" if d > 1 else ""]


## Les modificateurs CUMULES de plusieurs voies, axe par axe. Les pourcentages
## s ADDITIONNENT (+30 % puis +10 % font +40 %, pas +43 %) : c est ce que le
## joueur lit en additionnant les lignes de ses deux voies. Le NOMBRE n est pas
## somme ici — un entier se calcule voie par voie, voir _apply_count.
func _summed_mods(voies: Array) -> Dictionary:
	var out: Dictionary = {}
	for v in voies:
		var mods: Dictionary = v.get("mods", {})
		for a in mods:
			if StringName(a) == UP_COUNT:
				continue
			out[StringName(a)] = float(out.get(StringName(a), 0.0)) + float(mods[a])
	return out


## Les voies telles que le GRIMOIRE les affiche : [{text, unlocked, form}], TOUT
## le pool et non les seules voies d un tirage : la fiche dit au joueur tout ce
## que ce sort peut devenir, c est ce qui lui donne envie de le faire murir.
## Contrat fixe par GalleryPanel.upgrades_of() ({text, unlocked}), ecrit AVANT le
## systeme d amelioration pour que la fiche n ait pas a etre retouchee. Ne pas le
## rompre ; `form` est un ajout que la fiche peut ignorer.
func upgrade_lines_for(card: SpellCard) -> Array:
	var prises: Array[StringName] = upgrade_ids_of(card)
	var out: Array = []
	for v in upgrade_pool_for(card):
		out.append({
			"text": String(v.get("text", "")),
			"unlocked": prises.has(StringName(v.get("id", &""))),
			"form": StringName(v.get("form", &"")),
		})
	return out


## Le joueur retient la voie `i` de l offre en attente.
func pick_upgrade(i: int) -> Dictionary:
	var card: SpellCard = pending_upgrade_card
	if card == null:
		return {}
	if i < 0 or i >= pending_upgrade_paths.size():
		return {}
	var voie: Dictionary = pending_upgrade_paths[i]
	# On vide l attente AVANT d emettre : un ecouteur qui relance un sort dans la
	# foulee ne doit pas retomber sur une offre deja consommee.
	pending_upgrade_card = null
	pending_upgrade_paths = []
	_append_taken(card, StringName(voie.get("id", &"")))
	upgrade_taken.emit(card, voie.duplicate(true))
	# Une autre carte attendait peut-etre son ecran (meditation, chantier W8).
	_open_next_ready_maturation()
	return voie.duplicate(true)


## Le joueur renonce : le sort reste tel quel POUR CE PALIER.
## Renoncer DOIT consommer la maturation ("none"), sinon l ecran se rouvrirait au
## lancer suivant et le refus ne servirait a rien. Les paliers suivants restent
## ouverts : refuser un compromis n est pas renoncer a faire murir le sort.
func decline_upgrade() -> void:
	if pending_upgrade_card == null:
		return
	_append_taken(pending_upgrade_card, &"none")
	pending_upgrade_card = null
	pending_upgrade_paths = []
	_open_next_ready_maturation()


## Les EffectSpec a appliquer POUR CE LANCEMENT, ameliorations comprises.
##
## Rend des COPIES des que l amelioration change quelque chose : les EffectSpec
## du .tres sont partages et mis en cache par Godot (meme objet pour la main, le
## grimoire et la partie suivante). Ecrire dedans ferait fuir l amelioration hors
## de la partie et jusque dans le catalogue du menu principal. Verrouille par
## test_upgrades.gd/_test_l_amelioration_ne_modifie_jamais_la_ressource_partagee.
##
## Les `params` sont RECOPIES EN PROFONDEUR, explicitement. Godot 4.4 copie deja
## le Dictionary au duplicate() (verifie : retirer cette ligne ne fait rougir
## aucun test), mais seulement en surface, et ce comportement a change d une
## version a l autre. Les voies ecrivent dans les params ("+1 cible", "+30 % de
## PV") : si la copie partageait le Dictionary de la carte, chaque amelioration
## s ecrirait dans le catalogue. On ne confie pas ca au moteur.
##
## La pioche de complement est un effet AJOUTE (draw_cards, verbe existant) : elle
## passe par le meme chemin que tout effet, Debordement compris.
func cast_specs(card: SpellCard) -> Array[EffectSpec]:
	var out: Array[EffectSpec] = []
	if card == null:
		return out
	var voies: Array = taken_paths(card)
	var sommes: Dictionary = _summed_mods(voies)
	var nombres: Array[float] = []
	for v in voies:
		var mods: Dictionary = v.get("mods", {})
		if mods.has(UP_COUNT):
			nombres.append(float(mods[UP_COUNT]))
	var touche: bool = not nombres.is_empty()
	for a in sommes:
		if not [UP_CAST, UP_DRAW, UP_DISCARD].has(StringName(a)):
			touche = true
	for spec in card.effects:
		if spec == null:
			continue
		if not touche:
			out.append(spec)
			continue
		var c: EffectSpec = spec.duplicate() as EffectSpec
		c.params = spec.params.duplicate(true)
		for a in sommes:
			_apply_axis(c, StringName(a), float(sommes[a]))
		_apply_count(c, nombres)
		out.append(c)
	_apply_element_passives(card, out)
	var pioche: int = int(round(float(sommes.get(UP_DRAW, 0.0))))
	if pioche > 0:
		var d := EffectSpec.new()
		d.key = &"draw_cards"
		d.params = {&"count": pioche}
		out.append(d)
	return out


## PASSIFS ELEMENTAIRES de duree et de rayon (vague 8), appliques sur des
## COPIES pour la meme raison que les ameliorations : les EffectSpec du .tres
## sont partages. Sans passif actif, `out` n est pas touche (aucune copie).
## Une duree nulle (objet PERMANENT) reste nulle : il n y a rien a allonger.
func _apply_element_passives(card: SpellCard, out: Array[EffectSpec]) -> void:
	var el: int = card.main_element()
	var dur: float = element_bonus(el, ELEM_DURATION)
	var ray: float = element_bonus(el, ELEM_RADIUS)
	if dur <= 0.0 and ray <= 0.0:
		return
	for i in out.size():
		var sp: EffectSpec = out[i]
		var c: EffectSpec = sp.duplicate() as EffectSpec
		c.params = sp.params.duplicate(true)
		if dur > 0.0 and c.duration > 0.0 and is_finite(c.duration):
			c.duration *= 1.0 + dur * 0.01
		if ray > 0.0 and c.radius > 0.0:
			c.radius *= 1.0 + ray * 0.01
		out[i] = c


## Applique `pct` (signe : + ameliore, - coute) a un axe d un effet COPIE.
## Meme table que _spec_axes : un effet qui ne porte pas l axe n est pas touche.
## Les axes en CARTES (pioche, defausse) et la vitesse ne vivent pas dans les
## effets : ils sont ignores ici.
func _apply_axis(c: EffectSpec, axis: StringName, pct: float) -> void:
	var f: float = 1.0 + pct
	var k: StringName = c.key
	match axis:
		UP_DAMAGE:
			if _UP_DAMAGE_KEYS.has(k) and c.magnitude > 0.0:
				c.magnitude *= f
			if float(c.params.get(&"ally_damage", 0.0)) > 0.0:
				c.params[&"ally_damage"] = float(c.params[&"ally_damage"]) * f
		UP_SLOW:
			if float(c.params.get(&"slow_pct", 0.0)) > 0.0:
				c.params[&"slow_pct"] = minf(float(c.params[&"slow_pct"]) * f,
					GameConfig.UPGRADE_SLOW_CAP)
			if k == &"slow_enemy_gauge" and c.magnitude > 0.0:
				c.magnitude = minf(c.magnitude * f, GameConfig.UPGRADE_SLOW_CAP)
		UP_TEMPO:
			if k in [&"self_haste", &"cost_reduction", &"draw_boost"] and c.magnitude > 0.0:
				c.magnitude *= f
			if float(c.params.get(&"seconds_per_card", 0.0)) > 0.0:
				c.params[&"seconds_per_card"] = float(c.params[&"seconds_per_card"]) * f
		UP_FORCE:
			if k in [&"vortex_pull", &"water_flood"] and c.magnitude > 0.0:
				c.magnitude *= f
			if float(c.params.get(&"push", 0.0)) > 0.0:
				c.params[&"push"] = float(c.params[&"push"]) * f
		UP_AMPLIFY:
			# On amplifie l EXCEDENT au-dessus de 1 : "x2" ameliore de 30 % donne
			# x2,3 et non x2,6. Multiplier le facteur entier doublerait la promesse.
			if float(c.params.get(&"vuln_mult", 1.0)) > 1.0:
				c.params[&"vuln_mult"] = 1.0 + (float(c.params[&"vuln_mult"]) - 1.0) * f
			if k == &"empower_next" and c.magnitude > 1.0:
				c.magnitude = 1.0 + (c.magnitude - 1.0) * f
		UP_HP:
			for p in [&"prop_hp", &"wall_hp"]:
				if float(c.params.get(p, 0.0)) > 0.0:
					c.params[p] = float(c.params[p]) * f
		UP_AREA:
			if c.radius > 0.0 and not _UP_NO_AREA_KEYS.has(k):
				c.radius *= f
		UP_DURATION:
			if c.duration >= GameConfig.UPGRADE_MIN_DURATION \
					and not _UP_NO_DURATION_KEYS.has(k):
				c.duration *= f


## Ajoute a un effet COPIE les nombres de plusieurs voies. Chaque voie compte ce
## qu ELLE annoncait sur le nombre de la carte ("+1 carte", puis "+2 cartes") :
## sommer d abord les pourcentages puis arrondir donnerait un total different de
## la somme des deux lignes que le joueur a lues.
func _apply_count(c: EffectSpec, pcts: Array[float]) -> void:
	if pcts.is_empty():
		return
	var n: int = _spec_count(c)
	if n <= 0 or n >= GameConfig.UPGRADE_COUNT_UNLIMITED:
		return
	var d: int = 0
	for p in pcts:
		d += upgrade_count_bonus(n, p)
	if c.key == &"retain_next":
		c.magnitude = float(n + d)
	else:
		c.params[_UP_COUNT_PARAM[c.key]] = n + d


## Paie le prix "cartes defaussees" des voies retenues pour ce sort, a chaque
## lancer reel. Defausse au hasard, comme discard_random partout ailleurs : un
## prix que le joueur choisirait carte par carte serait un tri gratuit de sa main.
func _pay_card_price(card: SpellCard) -> void:
	if upgrade_ids_of(card).is_empty():
		return
	var n: int = int(round(-float(_summed_mods(taken_paths(card)).get(UP_DISCARD, 0.0))))
	if n > 0:
		discard_random(n)


## Facteur de TEMPS d incantation venant des ameliorations de CETTE carte.
## La voie parle en VITESSE (+10 %) : le temps est son inverse, 1 / 1,10. Un
## prix de -15 % de vitesse allonge donc le temps de 1 / 0,85, et deux voies
## s additionnent avant l inversion (+30 % puis -15 % = +15 %).
## Applique dans effective_cast_time() : c est le seul endroit que lisent le
## Caster et le HUD, donc la barre de charge et le sort partent toujours d accord.
func upgrade_cast_factor(card: SpellCard) -> float:
	if card == null or upgrade_ids_of(card).is_empty():
		return 1.0
	var mods: Dictionary = _summed_mods(taken_paths(card))
	if not mods.has(UP_CAST):
		return 1.0
	return 1.0 / maxf(0.05, 1.0 + float(mods[UP_CAST]))

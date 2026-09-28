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
	upgrades_taken.clear()
	pending_upgrade_card = null
	# Compteurs du moteur d objectifs (voir la section OBJECTIFS PARAMETRES).
	_reset_objective_counters()


## Fixe la graine pour rendre les tirages deterministes (tests, replays).
func set_seed(value: int) -> void:
	_rng.seed = value


func total_cards() -> int:
	return deck.size() + hand.size() + discard.size()


## Construit le deck de depart a partir des cartes communes.
func build_starter_deck(cards: Array[SpellCard]) -> void:
	deck.clear()
	for c in cards:
		for i in c.copies_in_starter:
			deck.append(c)
		SaveData.discover_card(c.id)
	shuffle_deck()
	deck_changed.emit()


## Construit le deck a partir d une liste EXPLICITE : une entree = un exemplaire.
## Utilise par le deck pre-etabli d un niveau et par le deck Massacre du joueur.
func build_deck_from_list(cards: Array[SpellCard]) -> void:
	deck.clear()
	for c in cards:
		if c == null:
			continue
		deck.append(c)
		SaveData.discover_card(c.id)
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


func exile_from_deck(count: int) -> int:
	var n: int = 0
	for i in count:
		if deck.is_empty():
			break
		exiled.append(deck.pop_back())
		n += 1
	if n > 0:
		deck_changed.emit()
	return n


func add_card_to_discard(card: SpellCard) -> void:
	discard.append(card)
	SaveData.discover_card(card.id)
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
]

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


## Equipe un passif dans un emplacement libre. Faux si la barre est pleine ou si
## ce passif y est deja — dans ce cas l appelant doit passer par swap_passive().
func equip_passive(card: SpellCard) -> bool:
	if card == null or not card.is_passive:
		return false
	if equipped_passives.has(card):
		return false
	if equipped_passives.size() >= GameConfig.PASSIVE_SLOTS:
		return false
	equipped_passives.append(card)
	SaveData.discover_card(card.id)
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
	SaveData.discover_card(card.id)
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


## Propose `count` cartes distinctes : la rarete est tiree (80/15/5), puis on
## complete avec d autres raretes si le pool est trop petit.
func offer_choices(count: int = 3) -> Array[SpellCard]:
	var chosen: Array[SpellCard] = []
	# "Les passifs sont plus rares que les cartes durant les montees de niveau :
	# 20 pourcent de passifs." Chaque proposition tire d abord SA FAMILLE, puis sa
	# rarete. Tirer la famille une seule fois pour toute l offre donnerait des
	# montees "tout passif" ou "tout sort" : le joueur n aurait plus de choix,
	# seulement un verdict.
	# Chaque carte tire SA PROPRE rarete : les trois choix peuvent donc etre de
	# raretes differentes. Avec une seule rarete pour toute l offre, les trois
	# options se ressemblaient et le tirage n avait aucun relief.
	for i in count:
		var passif: bool = _rng.randf() < GameConfig.PASSIVE_OFFER_CHANCE
		var voulue: GameEnums.Rarity = roll_rarity()
		# Replis, du plus proche au plus lointain, si la rarete voulue est epuisee.
		var order: Array = [voulue, GameEnums.Rarity.RARE, GameEnums.Rarity.EPIC,
			GameEnums.Rarity.COMMON, GameEnums.Rarity.LEGENDARY]
		for r in order:
			if chosen.size() > i:
				break
			var pool: Array[SpellCard] = _pool_of(r, passif)
			_shuffle_cards(pool)
			for c in pool:
				if not chosen.has(c) and not _deja_equipe(c):
					chosen.append(c)
					break
		# Repli de DERNIER recours : si la famille voulue est epuisee a toutes les
		# raretes (peu de passifs, ou tous deja equipes), on prend dans l autre.
		# Une case vide dans l offre vaut moins qu un choix hors famille.
		if chosen.size() <= i:
			for r2 in order:
				if chosen.size() > i:
					break
				var autre: Array[SpellCard] = _pool_of(r2, not passif)
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


## Offre d une rarete IMPOSEE : recompense de boss. A la difference de
## offer_choices(), la rarete n est pas tiree au sort — le cahier des charges
## promet de l epique au mini-boss et de la legendaire au boss final.
## Si la rarete demandee est vide, on descend d un cran plutot que de ne rien
## donner : un boss vaincu doit toujours rapporter quelque chose.
func offer_of_rarity(rarity: GameEnums.Rarity, count: int = 3) -> Array[SpellCard]:
	var chosen: Array[SpellCard] = []
	var repli: Array = [rarity, GameEnums.Rarity.EPIC, GameEnums.Rarity.RARE,
		GameEnums.Rarity.COMMON]
	for r in repli:
		if chosen.size() >= count:
			break
		# Un boss recompense en SORTS : l offre de rarete imposee promet une carte
		# forte a jouer tout de suite, pas un passif qui dort sous son seuil.
		var pool: Array[SpellCard] = _pool_of(r, false)
		_shuffle_cards(pool)
		for c in pool:
			if chosen.size() >= count:
				break
			if not chosen.has(c):
				chosen.append(c)
	pending_offer = chosen.duplicate()
	if not chosen.is_empty():
		offer_ready.emit(chosen.duplicate())
	return chosen


## Carte brulee en attente de lancement, lue par GameController. Null si aucune.
var burned_card: SpellCard = null


## BRULER une carte proposee : elle est lancee immediatement mais n entre jamais
## dans le deck. C est un choix de puissance TOUT DE SUITE contre une valeur sur
## la duree — sans ce prix, bruler serait toujours le bon choix.
func burn_offer(i: int) -> SpellCard:
	if i < 0 or i >= pending_offer.size():
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


func pick_offer(i: int) -> SpellCard:
	if i < 0 or i >= pending_offer.size():
		return null
	var card: SpellCard = pending_offer[i]
	pending_offer.clear()
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


## Les cartes d une rarete, dans UNE SEULE famille : sorts ou passifs. Les deux
## familles ne se melangent jamais dans un meme tirage, sinon les 20 % promis
## seraient dilues par la taille relative des deux catalogues.
func _pool_of(rarity: GameEnums.Rarity, passifs: bool) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards_of_rarity(rarity):
		if c != null and c.is_passive == passifs:
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
	for t in card.tags:
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
## Un sort que le joueur LANCE souvent gagne de l experience ; au palier
## (GameConfig.CARD_UPGRADE_CASTS lancers) il propose trois voies, et la voie
## choisie vaut POUR LA PARTIE EN COURS.
##
## POURQUOI PAS PERMANENT
## ----------------------
## Tout l equilibrage du jeu est mesure au banc (tools/sim_balance.gd) sur un
## depart connu : les sept niveaux sont rejoues depuis un deck de base. Si les
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
## handlers (voir EffectRegistry.cast).

## Lancers par carte SUR LA PARTIE : {id de carte -> nombre}.
## Indexe par `id` et non par l objet : la meme carte peut avoir plusieurs
## exemplaires dans le deck, et ce sont bien tous « le meme sort » aux yeux du
## joueur — trois copies de Boule de feu progressent ensemble.
var casts_by_card: Dictionary = {}
## Voie retenue par carte SUR LA PARTIE : {id de carte -> id de voie}.
var upgrades_taken: Dictionary = {}
## Carte dont l amelioration attend un choix. Null si aucune.
var pending_upgrade_card: SpellCard = null

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
	# Une carte DEJA amelioree ne redemande rien : sans ce garde, le sort favori
	# ouvrirait un ecran modal toutes les huit incantations jusqu a la fin de la
	# partie. Une seule amelioration par sort et par partie.
	if upgrades_taken.has(cle):
		return
	# Une seule offre a la fois : deux ecrans modaux empiles laisseraient le
	# second sans moyen d etre ferme, et la partie resterait en pause pour de bon.
	if pending_upgrade_card != null:
		return
	if int(casts_by_card[cle]) < GameConfig.CARD_UPGRADE_CASTS:
		return
	var voies: Array = upgrade_paths_for(card)
	if voies.is_empty():
		return
	pending_upgrade_card = card
	upgrade_ready.emit(card, voies.duplicate())


func casts_of(card: SpellCard) -> int:
	if card == null:
		return 0
	return int(casts_by_card.get(card.id, 0))


## Avancement vers l amelioration, de 0 a 1. Lu par l interface pour poser une
## pastille sur la carte : sans ce retour, le joueur ne sait pas qu un sort
## progresse et le palier tombe comme une surprise.
func upgrade_progress(card: SpellCard) -> float:
	if card == null:
		return 0.0
	if upgrades_taken.has(card.id):
		return 1.0
	var seuil: int = maxi(1, GameConfig.CARD_UPGRADE_CASTS)
	return clampf(float(casts_of(card)) / float(seuil), 0.0, 1.0)


func upgrade_of(card: SpellCard) -> StringName:
	if card == null:
		return &""
	return StringName(upgrades_taken.get(card.id, &""))


## Les trois voies proposees pour ce sort.
##
## Elles sont DERIVEES des effets de la carte, pas ecrites a la main dans chaque
## .tres. Trois raisons :
##   - 45 cartes x 3 voies = 135 entrees a maintenir, et chaque nouveau sort
##     ajoute par un autre chantier arriverait SANS amelioration : le systeme
##     mentirait au joueur sur la moitie du catalogue.
##   - une voie ecrite a la main peut contredire l effet reel du sort ; derivee,
##     elle ne peut pas.
##   - le libelle affiche les vrais pourcentages de reglage, donc il reste juste
##     quand l equilibrage bouge.
##
## La voie AMPLEUR n a de sens que sur un sort qui a un RAYON. Sans rayon, elle
## est remplacee par ENDURANCE (l effet dure plus longtemps) : la promesse reste
## vraie, seul son nom change.
func upgrade_paths_for(card: SpellCard) -> Array:
	if card == null:
		return []
	var out: Array = []

	# PUISSANCE — frappe plus fort, se charge plus lentement.
	# Sur un sort utilitaire (pioche, mur, reduction de cout) c est son EFFET qui
	# grossit : la magnitude est ce que sa carte promet, secondes ou cartes.
	var titre_puissance: String = "Puissance" if card.has_damage() else "Ferveur"
	var quoi: String = "de degats" if card.has_damage() else "d effet"
	out.append({
		"id": &"power",
		"text": "%s : +%s %s, incantation +%s" % [titre_puissance,
			_pct(GameConfig.UPGRADE_POWER_GAIN), quoi,
			_pct(GameConfig.UPGRADE_POWER_COST)],
		"damage": 1.0 + GameConfig.UPGRADE_POWER_GAIN,
		"cast": 1.0 + GameConfig.UPGRADE_POWER_COST,
		"area": 1.0,
	})

	# CELERITE — part vite, tape moins. La seule voie qui RACCOURCIT
	# l incantation : aux hautes vitesses, c est elle qui permet de repondre.
	out.append({
		"id": &"haste",
		"text": "Celerite : incantation -%s, -%s %s" % [
			_pct(GameConfig.UPGRADE_HASTE_GAIN),
			_pct(GameConfig.UPGRADE_HASTE_COST), quoi],
		"damage": 1.0 - GameConfig.UPGRADE_HASTE_COST,
		"cast": 1.0 - GameConfig.UPGRADE_HASTE_GAIN,
		"area": 1.0,
	})

	# AMPLEUR — couvre large, un peu plus lentement. Sans rayon a elargir, la
	# voie serait un mensonge : on lui substitue ENDURANCE (l effet dure plus).
	var titre_ampleur: String = "Ampleur" if card.has_area() else "Endurance"
	var gagne: String = "rayon et duree" if card.has_area() else "duree"
	out.append({
		"id": &"area",
		"text": "%s : +%s de %s, incantation +%s" % [titre_ampleur,
			_pct(GameConfig.UPGRADE_AREA_GAIN), gagne,
			_pct(GameConfig.UPGRADE_AREA_COST)],
		"damage": 1.0,
		"cast": 1.0 + GameConfig.UPGRADE_AREA_COST,
		"area": 1.0 + GameConfig.UPGRADE_AREA_GAIN,
	})
	return out


## Un pourcentage PRET A AFFICHER, signe compris. Le caractere pourcent n est
## ecrit qu ici : dans une chaine de format il devrait etre double, et un seul
## oubli afficherait "+45 d" au joueur.
func _pct(f: float) -> String:
	return "%d%%" % int(round(f * 100.0))


## Les voies telles que le GRIMOIRE les affiche : [{text, unlocked}].
## Contrat fixe par GalleryPanel.upgrades_of(), ecrit AVANT ce chantier pour que
## la fiche du grimoire n ait pas a etre retouchee. Ne pas le rompre.
func upgrade_lines_for(card: SpellCard) -> Array:
	var prise: StringName = upgrade_of(card)
	var out: Array = []
	for v in upgrade_paths_for(card):
		out.append({
			"text": String(v.get("text", "")),
			"unlocked": prise != &"" and StringName(v.get("id", &"")) == prise,
		})
	return out


## Le joueur retient la voie `i` pour la carte en attente.
func pick_upgrade(i: int) -> Dictionary:
	var card: SpellCard = pending_upgrade_card
	if card == null:
		return {}
	var voies: Array = upgrade_paths_for(card)
	if i < 0 or i >= voies.size():
		return {}
	var voie: Dictionary = voies[i]
	# On vide l attente AVANT d emettre : un ecouteur qui relance un sort dans la
	# foulee ne doit pas retomber sur une offre deja consommee.
	pending_upgrade_card = null
	upgrades_taken[card.id] = StringName(voie.get("id", &""))
	upgrade_taken.emit(card, voie.duplicate())
	return voie.duplicate()


## Le joueur renonce : le sort reste tel quel.
## Renoncer DOIT fermer la porte (voie "none"), sinon l ecran se rouvrirait au
## lancer suivant et le refus ne servirait a rien.
func decline_upgrade() -> void:
	if pending_upgrade_card == null:
		return
	upgrades_taken[pending_upgrade_card.id] = &"none"
	pending_upgrade_card = null


## Les EffectSpec a appliquer POUR CE LANCEMENT, amelioration comprise.
##
## Rend des COPIES des que l amelioration change quelque chose : les EffectSpec
## du .tres sont partages et mis en cache par Godot (meme objet pour la main, le
## grimoire et la partie suivante). Ecrire dedans ferait fuir l amelioration hors
## de la partie et jusque dans le catalogue du menu principal. Verrouille par
## test_upgrades.gd/_test_l_amelioration_ne_modifie_jamais_la_ressource_partagee.
func cast_specs(card: SpellCard) -> Array[EffectSpec]:
	var out: Array[EffectSpec] = []
	if card == null:
		return out
	var d_mult: float = 1.0
	var a_mult: float = 1.0
	match upgrade_of(card):
		&"power":
			d_mult = 1.0 + GameConfig.UPGRADE_POWER_GAIN
		&"haste":
			d_mult = 1.0 - GameConfig.UPGRADE_HASTE_COST
		&"area":
			a_mult = 1.0 + GameConfig.UPGRADE_AREA_GAIN
	for spec in card.effects:
		if spec == null:
			continue
		if is_equal_approx(d_mult, 1.0) and is_equal_approx(a_mult, 1.0):
			out.append(spec)
			continue
		var c: EffectSpec = spec.duplicate() as EffectSpec
		c.magnitude = spec.magnitude * d_mult
		c.radius = spec.radius * a_mult
		c.duration = spec.duration * a_mult
		out.append(c)
	return out


## Facteur de temps d incantation venant de l amelioration de CETTE carte.
## Applique dans effective_cast_time() : c est le seul endroit que lisent le
## Caster et le HUD, donc la barre de charge et le sort partent toujours d accord.
func upgrade_cast_factor(card: SpellCard) -> float:
	match upgrade_of(card):
		&"power":
			return 1.0 + GameConfig.UPGRADE_POWER_COST
		&"haste":
			return 1.0 - GameConfig.UPGRADE_HASTE_GAIN
		&"area":
			return 1.0 + GameConfig.UPGRADE_AREA_COST
	return 1.0

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
	return SpeedGauge.effective_cast_time(base) * passive_cast_factor()


func play_card(card: SpellCard) -> bool:
	var idx: int = hand.find(card)
	if idx == -1:
		return false
	hand.remove_at(idx)
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


func discard_random(count: int) -> int:
	var n: int = 0
	for i in count:
		if hand.is_empty():
			break
		var idx: int = _rng.randi_range(0, hand.size() - 1)
		discard.append(hand[idx])
		hand.remove_at(idx)
		n += 1
	if n > 0:
		hand_changed.emit()
	return n


func discard_hand() -> int:
	var n: int = hand.size()
	discard.append_array(hand)
	hand.clear()
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
## passifs. Le prix d un contact devient visible sur la barre de vitesse, pas
## seulement dans la barre de PV.

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
	&"passive_shield_keeper",   # un coup ne ramene plus la vitesse a 100 %
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


## Le monstre qui a le plus coute de PV sur la partie, "" si aucun coup recu.
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

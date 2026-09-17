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
var draw_interval: float = GameConfig.DRAW_INTERVAL
var draw_count: int = GameConfig.DRAW_COUNT

var _rng := RandomNumberGenerator.new()

## Focalisation : multiplicateur applique au prochain sort puis remis a 1.
var next_spell_multiplier: float = 1.0
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
	draw_interval = GameConfig.DRAW_INTERVAL
	draw_count = GameConfig.DRAW_COUNT
	used_legendary = false
	took_any_damage = false
	speed_dropped = false
	next_spell_multiplier = 1.0
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
func effective_cast_time(card: SpellCard) -> float:
	var base: float = maxf(0.1, card.base_cast_time - cost_reduction)
	return SpeedGauge.effective_cast_time(base)


func play_card(card: SpellCard) -> bool:
	var idx: int = hand.find(card)
	if idx == -1:
		return false
	hand.remove_at(idx)
	if card.rarity == GameEnums.Rarity.LEGENDARY:
		used_legendary = true
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
	var amount: int = SpeedGauge.xp_for(base_xp)
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
	_draw_timer += delta
	while _draw_timer >= draw_interval:
		_draw_timer -= draw_interval
		draw(draw_count)


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
	var rarity: GameEnums.Rarity = roll_rarity()
	var order: Array = [rarity, GameEnums.Rarity.RARE, GameEnums.Rarity.EPIC,
		GameEnums.Rarity.COMMON, GameEnums.Rarity.LEGENDARY]
	for r in order:
		if chosen.size() >= count:
			break
		var pool: Array[SpellCard] = ContentDB.cards_of_rarity(r)
		_shuffle_cards(pool)
		for c in pool:
			if chosen.size() >= count:
				break
			if not chosen.has(c):
				chosen.append(c)
	# On garde notre propre copie : l appelant peut faire ce qu il veut de la sienne
	# sans que pick_offer() la vide sous ses pieds.
	pending_offer = chosen.duplicate()
	if not chosen.is_empty():
		offer_ready.emit(chosen.duplicate())
	return chosen


func pick_offer(i: int) -> SpellCard:
	if i < 0 or i >= pending_offer.size():
		return null
	var card: SpellCard = pending_offer[i]
	pending_offer.clear()
	add_card_to_discard(card)
	offer_taken.emit(card)
	return card


func _shuffle_cards(arr: Array[SpellCard]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: SpellCard = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func note_damage_taken() -> void:
	took_any_damage = true


func note_speed_drop() -> void:
	speed_dropped = true

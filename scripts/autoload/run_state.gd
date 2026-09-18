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
	active_passives.clear()
	_passive_cast_cut = 0.0
	_passive_cast_factor = 1.0
	_cast_slots = 1
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
	var base: float = maxf(0.1, card.base_cast_time - cost_reduction - _passive_cast_cut)
	return SpeedGauge.effective_cast_time(base) * _passive_cast_factor


func play_card(card: SpellCard) -> bool:
	var idx: int = hand.find(card)
	if idx == -1:
		return false
	hand.remove_at(idx)
	if card.rarity == GameEnums.Rarity.LEGENDARY:
		used_legendary = true
	# Un passif quitte definitivement le deck : son effet est deja acquis.
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
	if _draw_boost_time > 0.0:
		_draw_boost_time -= delta
		if _draw_boost_time <= 0.0:
			_draw_boost = 1.0
			draw_interval = GameConfig.DRAW_INTERVAL
	if _double_cast_time > 0.0:
		_double_cast_time -= delta
	_draw_timer += delta
	while _draw_timer >= draw_interval:
		_draw_timer -= draw_interval
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


## --- Pouvoirs passifs ---
## Joues une fois, actifs jusqu a la fin du combat. Consultables en pause.
var active_passives: Array[SpellCard] = []
## Secondes retirees a chaque incantation, et facteur applique ensuite.
var _passive_cast_cut: float = 0.0
var _passive_cast_factor: float = 1.0
## Nombre de sorts pouvant charger en meme temps.
var _cast_slots: int = 1

signal passive_activated(card: SpellCard)


## Le passif ouvre une seconde place DEFINITIVEMENT, la legendaire "Canalisation
## jumelle" l ouvre POUR UN TEMPS. Les deux passent par le meme compteur : le
## Caster n a qu une seule regle a lire, et cumuler les deux ne donne pas 3 places.
func cast_slots() -> int:
	return 2 if (_cast_slots > 1 or double_cast_active()) else 1


## Applique un pouvoir passif. Les cles vivent ici et non dans EffectRegistry :
## un passif ne "s execute" pas, il CHANGE UNE REGLE pour tout le combat.
func activate_passive(card: SpellCard) -> void:
	if card == null or active_passives.has(card):
		return
	active_passives.append(card)
	for spec in card.effects:
		if spec == null:
			continue
		match spec.key:
			&"passive_cast_haste":
				_passive_cast_cut += maxf(spec.magnitude, 0.0)
			&"passive_double_cast":
				_cast_slots = 2
				# Deux sorts a la fois, mais chacun 50 % plus lent : sans ce prix
				# le passif doublerait purement la puissance du mage.
				_passive_cast_factor *= 1.5
			&"passive_wave_ally":
				pass  # lu par GameController au debut de chaque vague
	passive_activated.emit(card)


## Un passif de cette cle est-il actif ? (lu par GameController)
func has_passive(key: StringName) -> bool:
	for c in active_passives:
		for spec in c.effects:
			if spec != null and spec.key == key:
				return true
	return false


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
	# Chaque carte tire SA PROPRE rarete : les trois choix peuvent donc etre de
	# raretes differentes. Avec une seule rarete pour toute l offre, les trois
	# options se ressemblaient et le tirage n avait aucun relief.
	for i in count:
		var voulue: GameEnums.Rarity = roll_rarity()
		# Replis, du plus proche au plus lointain, si la rarete voulue est epuisee.
		var order: Array = [voulue, GameEnums.Rarity.RARE, GameEnums.Rarity.EPIC,
			GameEnums.Rarity.COMMON, GameEnums.Rarity.LEGENDARY]
		for r in order:
			if chosen.size() > i:
				break
			var pool: Array[SpellCard] = ContentDB.cards_of_rarity(r)
			_shuffle_cards(pool)
			for c in pool:
				if not chosen.has(c):
					chosen.append(c)
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
		var pool: Array[SpellCard] = ContentDB.cards_of_rarity(r)
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
	add_card_to_discard(card)
	offer_taken.emit(card)
	return card


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

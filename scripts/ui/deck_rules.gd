class_name DeckRules
extends RefCounted
## Regles de composition du deck en mode Massacre. Logique pure, testee a froid.
## Le deck est stocke dans SaveData comme une liste d ids : un id par exemplaire.

const MIN_CARDS: int = 8
const MAX_CARDS: int = 20


## Exemplaires maximum d une meme carte selon sa rarete.
static func max_copies(rarity: int) -> int:
	match rarity:
		GameEnums.Rarity.COMMON: return 4
		GameEnums.Rarity.RARE: return 3
		GameEnums.Rarity.EPIC: return 2
		GameEnums.Rarity.LEGENDARY: return 1
	return 1


static func count_of(deck_ids: Array, card_id: StringName) -> int:
	var n: int = 0
	for id in deck_ids:
		if StringName(id) == card_id:
			n += 1
	return n


static func can_add(deck_ids: Array, card: SpellCard, discovered: bool) -> bool:
	if card == null or not discovered:
		return false
	if deck_ids.size() >= MAX_CARDS:
		return false
	return count_of(deck_ids, card.id) < max_copies(card.rarity)


static func is_valid(deck_ids: Array) -> bool:
	return deck_ids.size() >= MIN_CARDS and deck_ids.size() <= MAX_CARDS


## Message affiche sous le bouton JOUER quand le deck est injouable. Vide si valide.
static func validation_message(deck_ids: Array) -> String:
	if deck_ids.size() < MIN_CARDS:
		return "Il manque %d carte(s) au deck (minimum %d)" % [MIN_CARDS - deck_ids.size(), MIN_CARDS]
	if deck_ids.size() > MAX_CARDS:
		return "Trop de cartes dans le deck (maximum %d)" % MAX_CARDS
	return ""


## Convertit une liste d ids en cartes. Les ids inconnus sont ignores,
## les doublons conserves (un id par exemplaire).
static func resolve(deck_ids: Array) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for id in deck_ids:
		var c: SpellCard = ContentDB.cards.get(StringName(id))
		if c != null:
			out.append(c)
	return out


## Deck de depart propose quand le joueur n en a jamais compose :
## les communes, au nombre de leurs exemplaires de base.
static func default_deck_ids() -> Array:
	var out: Array = []
	for c: SpellCard in ContentDB.cards.values():
		for i in c.copies_in_starter:
			out.append(String(c.id))
	return out

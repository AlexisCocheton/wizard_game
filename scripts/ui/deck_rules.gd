class_name DeckRules
extends RefCounted
## Regles de composition du deck en mode Massacre ET en campagne. Logique pure,
## testee a froid. Le deck est une liste d ids : un id par exemplaire.
##
## POURQUOI UNE TAILLE EXACTE ET NON UN INTERVALLE
## -----------------------------------------------
## Le deck acceptait de 8 a 20 cartes. Deux joueurs ne jouaient alors pas au meme
## jeu : celui qui en mettait 8 revoyait sa meilleure carte deux fois plus souvent
## que celui qui en mettait 20, donc la cadence de pioche, la courbe d XP et
## l equilibrage des vagues n avaient plus de reference commune. Le testeur a
## tranche : "ni une de plus ni une de moins" — 15 cartes, toujours.
##
## POURQUOI DES PLAFONDS PAR RARETE EN PLUS DES EXEMPLAIRES
## --------------------------------------------------------
## Le plafond d EXEMPLAIRES (1 legendaire par id) n empeche pas un deck de 15
## cartes compose de 12 legendaires DIFFERENTES : la contrainte ne mordait que
## sur les doublons. Le plafond par RARETE (3 epiques, 3 legendaires) est ce qui
## garde une colonne vertebrale de communes et de rares dans le deck.
##
## POURQUOI LES PASSIFS N Y SONT PLUS
## ----------------------------------
## Les pouvoirs passifs s EQUIPENT a part, de 0 a 3 emplacements (chantier F) :
## ils ne se piochent plus. Un deck de 15 cartes ne contient donc que des sorts,
## et can_add() refuse explicitement un passif — sinon l ecran de deck offrirait
## de composer avec des cartes que la partie ne distribuera jamais.

## La taille exacte, l unique reference de tout le jeu.
const DECK_SIZE: int = 15

## Alias conserves : le reste du code (GameController, smoke, campagne) parle
## encore en MIN/MAX. Les deux valent DECK_SIZE, donc les bornes se referment
## sur la taille exacte sans qu aucun appelant n ait a changer.
const MIN_CARDS: int = DECK_SIZE
const MAX_CARDS: int = DECK_SIZE

## Plafonds par rarete DANS UN MEME DECK, toutes cartes confondues.
const MAX_EPIC: int = 3
const MAX_LEGENDARY: int = 3

## Emplacements de pouvoirs passifs. Ils sont HORS du deck de 15 : le joueur en
## equipe de 0 a 3 dans une zone distincte.
const MAX_PASSIVES: int = 3


## Exemplaires maximum d une meme carte selon sa rarete. Inchange (demande du
## testeur : "garde le meme nombre d exemplaires").
static func max_copies(rarity: int) -> int:
	match rarity:
		GameEnums.Rarity.COMMON: return 4
		GameEnums.Rarity.RARE: return 3
		GameEnums.Rarity.EPIC: return 2
		GameEnums.Rarity.LEGENDARY: return 1
	return 1


## Plafond de la rarete dans le deck entier, ou -1 quand elle n en a pas
## (communes et rares : seul le plafond d exemplaires les limite).
static func max_of_rarity(rarity: int) -> int:
	match rarity:
		GameEnums.Rarity.EPIC: return MAX_EPIC
		GameEnums.Rarity.LEGENDARY: return MAX_LEGENDARY
	return -1


static func count_of(deck_ids: Array, card_id: StringName) -> int:
	var n: int = 0
	for id in deck_ids:
		if StringName(id) == card_id:
			n += 1
	return n


## Combien de cartes d une rarete donnee dans le deck.
##
## Les ids absents de ContentDB comptent par leur PREFIXE d identifiant en repli
## ("epi_", "leg_") : les tests composent des decks synthetiques sans passer par
## le contenu reel, et un compteur qui les ignorerait validerait silencieusement
## un deck de 12 legendaires.
static func count_rarity(deck_ids: Array, rarity: int) -> int:
	var n: int = 0
	for id in deck_ids:
		var c: SpellCard = ContentDB.cards.get(StringName(id))
		if c != null:
			if c.rarity == rarity:
				n += 1
		elif _rarity_hint(String(id)) == rarity:
			n += 1
	return n


## Rarete devinee a partir de l identifiant, pour les ids inconnus du contenu.
static func _rarity_hint(id: String) -> int:
	if id.begins_with("leg"):
		return GameEnums.Rarity.LEGENDARY
	if id.begins_with("epi"):
		return GameEnums.Rarity.EPIC
	if id.begins_with("rare"):
		return GameEnums.Rarity.RARE
	return GameEnums.Rarity.COMMON


static func can_add(deck_ids: Array, card: SpellCard, discovered: bool) -> bool:
	if card == null or not discovered:
		return false
	# Un passif ne se met pas dans le deck : il s equipe (chantier F).
	if card.is_passive:
		return false
	if deck_ids.size() >= DECK_SIZE:
		return false
	if count_of(deck_ids, card.id) >= max_copies(card.rarity):
		return false
	# Le plafond de rarete BLOQUE des l ajout plutot que d invalider apres coup :
	# un joueur qui remplit 15 cases puis apprend que son deck est injouable a
	# perdu son temps, et ne sait pas laquelle retirer.
	var plafond: int = max_of_rarity(card.rarity)
	if plafond >= 0 and count_rarity(deck_ids, card.rarity) >= plafond:
		return false
	return true


static func is_valid(deck_ids: Array) -> bool:
	if deck_ids.size() != DECK_SIZE:
		return false
	if count_rarity(deck_ids, GameEnums.Rarity.EPIC) > MAX_EPIC:
		return false
	if count_rarity(deck_ids, GameEnums.Rarity.LEGENDARY) > MAX_LEGENDARY:
		return false
	return true


## Les passifs EQUIPES, de 0 a 3. Separe de is_valid() : un deck reste jouable
## sans aucun passif, ils ne sont pas une condition de depart.
static func passives_valid(passive_ids: Array) -> bool:
	return passive_ids.size() <= MAX_PASSIVES


## Message affiche sous le bouton JOUER quand le deck est injouable. Vide si
## valide. C est le SEUL texte que le joueur lit quand il ne peut pas jouer :
## il doit nommer le nombre exact qui manque ou qui deborde, jamais se contenter
## de "deck invalide".
static func validation_message(deck_ids: Array) -> String:
	var n: int = deck_ids.size()
	if n < DECK_SIZE:
		var manque: int = DECK_SIZE - n
		return "Ajoute %d carte%s  -  un deck en compte %d" % [
			manque, "s" if manque > 1 else "", DECK_SIZE]
	if n > DECK_SIZE:
		var trop: int = n - DECK_SIZE
		return "Retire %d carte%s  -  un deck en compte %d" % [
			trop, "s" if trop > 1 else "", DECK_SIZE]
	var epiques: int = count_rarity(deck_ids, GameEnums.Rarity.EPIC)
	if epiques > MAX_EPIC:
		return "Trop d epiques : %d sur %d autorisees" % [epiques, MAX_EPIC]
	var legendaires: int = count_rarity(deck_ids, GameEnums.Rarity.LEGENDARY)
	if legendaires > MAX_LEGENDARY:
		return "Trop de legendaires : %d sur %d autorisees" % [legendaires, MAX_LEGENDARY]
	return ""


## Convertit une liste d ids en cartes. Les ids inconnus sont ignores,
## les doublons conserves (un id par exemplaire).
## Les POUVOIRS PASSIFS ne sont PLUS dans le deck (demande du testeur du
## 21 septembre) : ils sont equipes hors deck et actifs des le debut du combat.
## with_passives() a donc ete SUPPRIMEE plutot que videe — la laisser aurait
## garde un chemin par lequel un passif retombe dans la pioche.
## Voir RunState.equip_passive() / gain_passive().


static func resolve(deck_ids: Array) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for id in deck_ids:
		var c: SpellCard = ContentDB.cards.get(StringName(id))
		if c != null:
			out.append(c)
	return out


## Deck de depart propose quand le joueur n en a jamais compose : les cartes de
## depart, au nombre de leurs exemplaires de base, completees ou rognees pour
## tomber EXACTEMENT sur DECK_SIZE.
##
## L arrondi est necessaire : la somme des copies_in_starter du contenu vaut 16,
## et un deck de depart invalide interdirait de jouer au premier lancement. On
## trie par id pour que le deck propose soit le meme d un demarrage a l autre
## (ContentDB.cards est un Dictionary, son ordre n est pas une promesse).
static func default_deck_ids() -> Array:
	var cartes: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and c.copies_in_starter > 0:
			cartes.append(c)
	cartes.sort_custom(func(a: SpellCard, b: SpellCard) -> bool: return a.id < b.id)

	var out: Array = []
	# Tour par tour plutot que carte par carte : si le contenu de depart depasse
	# 15, on rogne le DERNIER exemplaire de chacune au lieu d amputer une carte
	# entiere, et le deck garde toute sa variete.
	var tour: int = 0
	var reste: bool = true
	while out.size() < DECK_SIZE and reste:
		reste = false
		for c in cartes:
			if c.copies_in_starter > tour and can_add(out, c, true):
				out.append(String(c.id))
				reste = true
				if out.size() >= DECK_SIZE:
					break
		tour += 1

	# Contenu de depart trop maigre : on complete avec n importe quelle carte
	# ajoutable, pour ne jamais rendre un deck de base injouable.
	if out.size() < DECK_SIZE:
		var toutes: Array[SpellCard] = []
		for c2: SpellCard in ContentDB.cards.values():
			if c2 != null and not c2.is_passive:
				toutes.append(c2)
		toutes.sort_custom(func(a: SpellCard, b: SpellCard) -> bool: return a.id < b.id)
		var progres: bool = true
		while out.size() < DECK_SIZE and progres:
			progres = false
			for c3 in toutes:
				if can_add(out, c3, true):
					out.append(String(c3.id))
					progres = true
					if out.size() >= DECK_SIZE:
						break
	return out

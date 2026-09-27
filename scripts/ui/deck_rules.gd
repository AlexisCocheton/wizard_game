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
## POURQUOI SIX CARTES DIFFERENTES AU MAXIMUM, ET PLUS DE PLAFOND PAR RARETE
## --------------------------------------------------------------------------
## Demande du co-auteur : "il ne peut y avoir que 6 cartes differentes maximum",
## en campagne comme dans le deck que le joueur construit. Un deck de 15 cartes
## en 11 ids differents se pioche comme une loterie : on ne revoit jamais deux
## fois le meme sort dans une partie, donc on n apprend pas a le placer.
##
## Cette regle suffit a limiter la rarete, et c est pourquoi les anciens
## plafonds MAX_EPIC = 3 et MAX_LEGENDARY = 3 ont ete RETIRES. Avec au plus 6
## ids et 4/3/2/1 exemplaires, il faut que les copies autorisees atteignent 15 :
##   - 3 legendaires au plus : 3 x 1 + 3 communes x 4 = 15 tout juste ; une 4e
##     legendaire laisse 2 ids, soit 4 + 2 x 4 = 12 < 15 ;
##   - 4 epiques au plus : 4 x 2 + 2 communes x 4 = 16 ; une 5e epique laisse un
##     seul id, soit 5 x 2 + 4 = 14 < 15.
## Plus une carte est rare, plus elle coute de "places d ids" pour peu de
## copies : la rarete se paie d elle-meme. test_deck_rules.gd le verifie en
## ENUMERANT les compositions contre is_valid(), pas en recopiant ces chiffres.
##
## UNE SEULE SOURCE POUR "PEUT-ON AJOUTER CETTE CARTE"
## ---------------------------------------------------
## refusal_reason() dit POURQUOI un ajout est refuse, et can_add() n est que
## `refusal_reason(...) == ""`. Deux fonctions qui recopieraient les memes tests
## finiraient par diverger : l ecran griserait un bouton en affichant une raison
## fausse, ou pire accepterait une carte que la validation refuse ensuite.
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

## Nombre d ids DIFFERENTS dans un deck, tous exemplaires confondus. C est la
## seule limite de composition en plus des exemplaires (voir l en-tete).
const MAX_DISTINCT: int = 6

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


## COMPATIBILITE : il n y a plus de plafond par rarete dans le deck entier, la
## regle des 6 cartes differentes le remplace (voir l en-tete). Rend toujours -1
## ("pas de plafond") pour que l ecran de deck, qui l interroge encore, compile
## et ne refuse rien a tort. A supprimer quand il passera par refusal_reason().
static func max_of_rarity(_rarity: int) -> int:
	return -1


static func count_of(deck_ids: Array, card_id: StringName) -> int:
	var n: int = 0
	for id in deck_ids:
		if StringName(id) == card_id:
			n += 1
	return n


## Nombre d ids differents dans le deck.
static func count_distinct(deck_ids: Array) -> int:
	var vus: Dictionary = {}
	for id in deck_ids:
		vus[StringName(id)] = true
	return vus.size()


## Combien de cartes d une rarete donnee dans le deck.
##
## Les ids absents de ContentDB comptent par leur PREFIXE d identifiant en repli
## ("epi_", "leg_") : les tests composent des decks synthetiques sans passer par
## le contenu reel, et un compteur qui les ignorerait validerait silencieusement
## un deck de 12 legendaires.
static func count_rarity(deck_ids: Array, rarity: int) -> int:
	var n: int = 0
	for id in deck_ids:
		if rarity_of(StringName(id)) == rarity:
			n += 1
	return n


## Rarete d un id : celle du contenu s il est connu, sinon devinee par son
## prefixe (meme raison que count_rarity : les decks synthetiques des tests).
static func rarity_of(card_id: StringName) -> int:
	var c: SpellCard = ContentDB.cards.get(card_id)
	if c != null:
		return c.rarity
	return _rarity_hint(String(card_id))


## Rarete devinee a partir de l identifiant, pour les ids inconnus du contenu.
static func _rarity_hint(id: String) -> int:
	if id.begins_with("leg"):
		return GameEnums.Rarity.LEGENDARY
	if id.begins_with("epi"):
		return GameEnums.Rarity.EPIC
	if id.begins_with("rare"):
		return GameEnums.Rarity.RARE
	return GameEnums.Rarity.COMMON


## Pourquoi `card` ne peut pas entrer dans `deck_ids`, en une phrase courte que
## le joueur lit sous la carte ; "" si l ajout est possible.
##
## Chaque raison appelle un geste different (retirer une carte, retirer un id
## entier, jouer pour decouvrir...), d ou une phrase par cas et jamais un
## "ajout impossible" generique. L ordre va du plus definitif au plus
## corrigeable : une carte non decouverte ne s ajoutera pas meme deck vide.
##
## Toute regle se REFUSE des l ajout plutot que d invalider apres coup : un
## joueur qui remplit 15 cases puis apprend que son deck est injouable a perdu
## son temps, et ne sait pas laquelle retirer.
static func refusal_reason(deck_ids: Array, card: SpellCard, discovered: bool) -> String:
	if card == null:
		return "Carte inconnue"
	if not discovered:
		return "Carte pas encore decouverte"
	# Un passif ne se met pas dans le deck : il s equipe (chantier F).
	if card.is_passive:
		return "Les passifs s equipent a part"
	if deck_ids.size() >= DECK_SIZE:
		return "Deck complet : %d cartes" % DECK_SIZE
	var copies: int = max_copies(card.rarity)
	if count_of(deck_ids, card.id) >= copies:
		return "%s : %d exemplaire%s au maximum" % [
			GameEnums.rarity_name(card.rarity).capitalize(), copies,
			"s" if copies > 1 else ""]
	# Un exemplaire de plus d une carte deja presente ne cree pas d id nouveau :
	# seule une carte ABSENTE du deck bute sur la limite des 6.
	if count_of(deck_ids, card.id) == 0 and count_distinct(deck_ids) >= MAX_DISTINCT:
		return "%d cartes differentes au maximum" % MAX_DISTINCT
	return ""


## Strictement `refusal_reason(...) == ""` : les deux ne peuvent pas diverger.
static func can_add(deck_ids: Array, card: SpellCard, discovered: bool) -> bool:
	return refusal_reason(deck_ids, card, discovered) == ""


## Taille, exemplaires ET nombre de cartes differentes. Les exemplaires etaient
## verifies par can_add() SEULEMENT : un deck sauvegarde ou fabrique a la main
## avec cinq Traits passait is_valid() sans broncher.
static func is_valid(deck_ids: Array) -> bool:
	return validation_message(deck_ids) == ""


## Les passifs EQUIPES, de 0 a 3. Separe de is_valid() : un deck reste jouable
## sans aucun passif, ils ne sont pas une condition de depart.
static func passives_valid(passive_ids: Array) -> bool:
	return passive_ids.size() <= MAX_PASSIVES


## Message affiche sous le bouton JOUER quand le deck est injouable. Vide si
## valide. C est le SEUL texte que le joueur lit quand il ne peut pas jouer :
## il doit nommer le nombre exact qui manque ou qui deborde, jamais se contenter
## de "deck invalide". is_valid() en DERIVE, pour qu un deck refuse ait toujours
## une raison affichee et qu une raison affichee bloque toujours.
##
## Les exces de composition passent AVANT la taille : un deck de 12 cartes en 7
## ids doit de toute facon perdre un id, et lui dire "ajoute 3 cartes" l enverrait
## chercher des cartes que l ecran refuserait.
##
## C est aussi ce qui protege les decks SAUVEGARDES avant la regle des 6 : ils
## ne sont ni tronques ni effaces, le Massacre les refuse (GameController ne
## joue qu un deck is_valid) et l ecran de campagne affiche ce message a la
## place du bouton JOUER. Le joueur decide lui-meme quelle carte retirer.
static func validation_message(deck_ids: Array) -> String:
	var differentes: int = count_distinct(deck_ids)
	if differentes > MAX_DISTINCT:
		var en_trop: int = differentes - MAX_DISTINCT
		return "%d cartes differentes, %d au maximum  -  retire-en %d" % [
			differentes, MAX_DISTINCT, en_trop]
	# Ordre stable (ordre d apparition dans le deck) pour nommer la meme carte
	# d un affichage a l autre.
	var vus: Dictionary = {}
	for id in deck_ids:
		var sid: StringName = StringName(id)
		if vus.has(sid):
			continue
		vus[sid] = true
		var n_id: int = count_of(deck_ids, sid)
		var plafond: int = max_copies(rarity_of(sid))
		if n_id > plafond:
			var c: SpellCard = ContentDB.cards.get(sid)
			var nom: String = c.display_name if c != null else String(sid)
			return "%s : %d exemplaires, %d au maximum" % [nom, n_id, plafond]
	var n: int = deck_ids.size()
	if n < DECK_SIZE:
		var manque: int = DECK_SIZE - n
		return "Ajoute %d carte%s  -  un deck en compte %d" % [
			manque, "s" if manque > 1 else "", DECK_SIZE]
	if n > DECK_SIZE:
		var trop: int = n - DECK_SIZE
		return "Retire %d carte%s  -  un deck en compte %d" % [
			trop, "s" if trop > 1 else "", DECK_SIZE]
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
## L arrondi est necessaire : le contenu de depart ne tombe pas pile sur 15
## cartes en 6 ids au plus, et un deck de depart invalide interdirait de jouer
## au premier lancement. On trie pour que le deck propose soit le meme d un
## demarrage a l autre (ContentDB.cards est un Dictionary, son ordre n est pas
## une promesse). can_add() porte toutes les regles, donc le resultat est
## valide par construction : test_deck_rules le verifie contre is_valid().
static func default_deck_ids() -> Array:
	var cartes: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and c.copies_in_starter > 0:
			cartes.append(c)
	# Les cartes de depart les plus DOTEES d abord : quand le contenu de depart
	# compte plus de MAX_DISTINCT cartes (7 aujourd hui), ce sont les moins
	# representees qui restent dehors, pas les dernieres de l alphabet. Comparaison
	# sur String : le tri de StringName n est pas fiable en 4.4 (voir gotchas).
	cartes.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		if a.copies_in_starter != b.copies_in_starter:
			return a.copies_in_starter > b.copies_in_starter
		return String(a.id) < String(b.id))

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
		toutes.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
			return String(a.id) < String(b.id))
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

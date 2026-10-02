class_name CollectionStyle
extends RefCounted
## L ETAT "A OBTENIR / A RENCONTRER", dessine d UNE SEULE FACON.
##
## Retouche du co-auteur apres test (30/09) : "cartes a 3 etats MAL realise".
## Le grimoire et l ecran de deck montraient le meme etat de deux facons : le
## deck voilait TOUTE la vignette (texte compris, puis un pied de vignette
## assombri une seconde fois : illisible sur capture), le grimoire ne grisait
## que le fond et l icone. Les deux ecrans, et le bestiaire, passent maintenant
## par ici : fond et image grises, texte INTACT. Grise veut dire "pas encore a
## toi", jamais "illisible".
##
## Les regles (qui est obtenu, obtenable, invisible ; qui est rencontre, a
## rencontrer) vivent dans SaveData. Ce fichier ne decide rien : il dessine et
## il ecrit les phrases.

## Teinte du FOND d une vignette grisee (self_modulate : ne descend pas au texte).
const GREY_TILE: Color = Color(0.62, 0.62, 0.66, 0.9)
## Teinte de l IMAGE d une entree grisee : assez sombre pour se distinguer d un
## coup d oeil de l entree acquise, assez claire pour que l image se reconnaisse.
const GREY_ART: Color = Color(0.42, 0.42, 0.46, 0.85)

## Pieds de vignette des entrees grisees : les memes mots partout.
const FOOT_OBTAINABLE: String = "a obtenir"
const FOOT_REACHABLE: String = "a rencontrer"


## Grise une vignette : son FOND et son IMAGE, pas son texte.
## `art` peut etre nul (carte sans icone) : le fond suffit alors.
static func grey(tile: Control, art: Control) -> void:
	if tile != null:
		tile.self_modulate = GREY_TILE
	if art == null:
		return
	# Une icone de carte porte depuis la vague 5 son SCEAU DE TYPE : elle arrive
	# dans un Control qui tient l icone et le sceau (CardView.with_type_badge).
	# On grise alors chaque image, pas le porteur : le gris MULTIPLIE, et
	# l appliquer aux deux niveaux assombrirait deux fois.
	if art is TextureRect or art.get_child_count() == 0:
		art.modulate = GREY_ART
		return
	for c in art.get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate = GREY_ART


## Le compteur d en-tete, le meme mot a mot sur les trois ecrans :
## "8 / 14 obtenues". `counts` = [acquis, visibles] (SaveData.card_counts ou
## enemy_counts) : le denominateur est ce que les pages montrent, jamais le
## catalogue.
static func counter(counts: Array, word: String) -> String:
	return "%d / %d %s" % [int(counts[0]), int(counts[1]), word]


## OU OBTENIR une carte grisee : la montee de niveau des niveaux ouverts qui la
## proposent (cartes nouvelles, cartes d objectifs reussis).
##
## Il y avait un second chemin, "joue tel niveau, elle est dans son deck" : il
## n existe plus depuis la regle du livre de sorts (SaveData, 01/10). Une carte
## du deck d un niveau ouvert est deja OBTENUE, elle n est donc jamais grisee ;
## seule la montee de niveau reste a dire.
static func where_to_obtain(card: SpellCard) -> String:
	if card == null:
		return ""
	if card.is_passive:
		return "A OBTENIR : prends-le a une montee de niveau, en campagne, des l acte %d" \
			% LevelDef.PASSIVES_FROM_ACT
	var prendre: Array[String] = []
	for lv: LevelDef in SaveData.levels_offering(card.id):
		prendre.append(lv.display_name)
	if prendre.is_empty():
		return "A OBTENIR en combat"
	return "A OBTENIR : prends-la a la montee de niveau de %s" % ", ".join(prendre)


## OU RENCONTRER un monstre grise : les niveaux ouverts ou il descend.
static func where_to_meet(def: EnemyDef) -> String:
	if def == null:
		return ""
	var noms: Array[String] = []
	for lv: LevelDef in SaveData.levels_with_enemy(def.id):
		noms.append(lv.display_name)
	if noms.is_empty():
		return "A RENCONTRER en combat"
	return "A RENCONTRER dans %s" % ", ".join(noms)

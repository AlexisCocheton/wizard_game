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
	if art != null:
		art.modulate = GREY_ART


## Le compteur d en-tete, le meme mot a mot sur les trois ecrans :
## "8 / 14 obtenues". `counts` = [acquis, visibles] (SaveData.card_counts ou
## enemy_counts) : le denominateur est ce que les pages montrent, jamais le
## catalogue.
static func counter(counts: Array, word: String) -> String:
	return "%d / %d %s" % [int(counts[0]), int(counts[1]), word]


## OU OBTENIR une carte grisee. Deux chemins, dits differemment parce que le
## geste n est pas le meme :
##   - elle est dans le DECK d un niveau ouvert : il suffit de JOUER ce niveau
##     (jouer un deck obtient ses cartes) ;
##   - sinon elle est dans son pool de montee de niveau (cartes nouvelles,
##     cartes d objectifs reussis) : il faut la PRENDRE a une montee.
## L ancienne phrase disait "prends-la a la montee de niveau" pour les deux, et
## envoyait le joueur guetter une offre pour une carte que le niveau lui donne.
static func where_to_obtain(card: SpellCard) -> String:
	if card == null:
		return ""
	if card.is_passive:
		return "A OBTENIR : prends-le a une montee de niveau, en campagne, des l acte %d" \
			% LevelDef.PASSIVES_FROM_ACT
	var jouer: Array[String] = []
	var prendre: Array[String] = []
	var donnent: Array[LevelDef] = SaveData.levels_dealing(card.id)
	for lv: LevelDef in SaveData.levels_offering(card.id):
		if donnent.has(lv):
			jouer.append(lv.display_name)
		else:
			prendre.append(lv.display_name)
	var morceaux: Array[String] = []
	if not jouer.is_empty():
		morceaux.append("joue %s, elle est dans son deck" % ", ".join(jouer))
	if not prendre.is_empty():
		morceaux.append("prends-la a la montee de niveau de %s" % ", ".join(prendre))
	if morceaux.is_empty():
		return "A OBTENIR en combat"
	return "A OBTENIR : " + " ; ou ".join(morceaux)


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

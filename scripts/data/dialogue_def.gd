class_name DialogueDef
extends Resource
## Une scene de visual novel : un fond, une suite de repliques.
##
## POURQUOI une Resource et pas un script par scene : le texte de l histoire est
## du CONTENU, au meme titre qu une carte ou un monstre (DEC-003). Il se genere
## par `tools/make_story.gd`, se relit dans docs/histoire.md, et un test peut
## verifier a froid que chaque scene referencee par un niveau existe et que
## chaque portrait se resout. Un script par scene rendrait tout cela invisible.
##
## Chaque replique est un Dictionary :
##   speaker  : nom affiche ("" = narrateur, pas de portrait ni de nom)
##   portrait : cle de portrait (voir StoryScene.portrait_texture) ; "" = aucun
##   text     : la replique, SANS ACCENTS (la police du jeu n en a pas)
##   side     : "left" ou "right", cote ou se pose le portrait
## On garde un Dictionary plutot qu une sous-Resource par ligne : neuf scenes de
## dix lignes feraient quatre-vingt-dix fichiers pour rien.

const DIR: String = "res://resources/story/"

@export var id: StringName = &""
## Fond de la scene : cle dans assets/backdrops/ sans extension ("act1_sky").
@export var scene_background: String = ""
@export var lines: Array[Dictionary] = []


static func path_for(story_id: StringName) -> String:
	return DIR + String(story_id) + ".tres"


## Charge une scene par son id. Null si elle n existe pas : l appelant decide
## s il saute la scene (le jeu) ou s il echoue (les tests).
static func load_by_id(story_id: StringName) -> DialogueDef:
	if String(story_id) == "":
		return null
	var path: String = path_for(story_id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as DialogueDef


func line_count() -> int:
	return lines.size()


## Acces tolerant : une ligne mal formee ne fait pas planter la scene, elle
## s affiche vide et le test unitaire la signale.
func line(index: int) -> Dictionary:
	if index < 0 or index >= lines.size():
		return {}
	return lines[index]

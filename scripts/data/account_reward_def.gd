class_name AccountRewardDef
extends Resource
## Une recompense de niveau de compte.
##
## Uniquement COSMETIQUE, jamais de puissance : un compte qui rendrait le mage
## plus fort perimerait l equilibrage mesure des 7 niveaux, et avantagerait qui
## joue beaucoup plutot que qui joue bien.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Niveau de compte auquel la recompense se debloque.
@export var at_level: int = 2
@export var kind: GameEnums.RewardKind = GameEnums.RewardKind.TITLE

## Ce que la recompense designe, selon son type :
##   AVATAR      -> un portrait de WardrobeData.AVATARS (avatar_monk_blue...) ;
##   MAGE_COLOR  -> une TENUE : la feuille AnimCatalog d une robe du mage
##                  (monk_blue, monk_red...) ou, si `for_character` nomme un
##                  apprenti, d une de ses teintes (bluewitch_ember...) ;
##   HAT         -> un chapeau de WardrobeData.HATS (hat_wizard...), calque pose
##                  sur la tete image par image ; HAT_NONE = tete nue ;
##   TOWER       -> une cle de WardrobeData.TOWERS (tower_sand, tower_tree...) ;
##   CHARACTER   -> la cle AnimCatalog de l apprenti (bluewitch...), ou
##                  CHARACTER_MAGE pour revenir au mage.
##
## Un seul champ pour tous : ce qui est EQUIPE est toujours une chaine, et
## `SaveData.equipped_cosmetic()` la rend telle quelle. Les deux fichiers de jeu
## qui la lisent (mage_view, battle_backdrop) n ont ainsi rien a interpreter.
##
## AJOUTER UN APPRENTI = un .tres CHARACTER + une cle dans AnimCatalog, sans une
## ligne de code : la taille, la pose d incantation et la vignette se deduisent
## de la feuille (UiTheme.hero_*). L AUDIT refuse une feuille partagee avec un
## monstre — le joueur ne doit jamais tirer sur son propre personnage.
@export var texture_name: String = ""

## Pour une TENUE (MAGE_COLOR) : le personnage qu elle habille. Vide = le mage
## (ses robes). Sinon la cle AnimCatalog d un apprenti : la tenue est alors une
## teinte de SA feuille (meme silhouette, palette remappee). Chaque personnage a
## sa propre tenue equipee : passer du mage a l apprentie et retour ne perd rien.
@export var for_character: String = ""

## La valeur CHARACTER qui designe le mage lui-meme. Ce n est pas une cle
## d AnimCatalog : le mage est fait de deux cosmetiques (robe et chapeau), que
## UiTheme.mage_frames() assemble. Une chaine distincte plutot que "" parce que
## "" veut deja dire "rien de choisi, prends le defaut" dans SaveData.
const CHARACTER_MAGE: String = "mage"

## La valeur HAT de la tete nue (aucun calque). Les anciens profils stockaient
## "monk_blue" pour dire la meme chose : SaveData.LEGACY_HATS les traduit.
const HAT_NONE: String = "none"


## Ce cosmetique s EQUIPE-t-il ? Tout sauf le titre, qui se deduit du niveau.
## Le portrait (AVATAR) s equipe depuis la vague 8 : avant, c etaient des icones
## d outils que rien n affichait.
func is_equippable() -> bool:
	return kind in [GameEnums.RewardKind.MAGE_COLOR, GameEnums.RewardKind.HAT,
		GameEnums.RewardKind.TOWER, GameEnums.RewardKind.CHARACTER,
		GameEnums.RewardKind.AVATAR]


## Un APPRENTI : un personnage qui remplace le mage en combat.
func is_apprentice() -> bool:
	return kind == GameEnums.RewardKind.CHARACTER and texture_name != CHARACTER_MAGE


## Une TENUE d apprenti (teinte de sa feuille), et non une robe du mage.
func is_apprentice_outfit() -> bool:
	return kind == GameEnums.RewardKind.MAGE_COLOR and for_character != "" \
		and for_character != CHARACTER_MAGE


## Le personnage que cette tenue habille : CHARACTER_MAGE ou la cle d un apprenti.
func outfit_owner() -> String:
	return for_character if is_apprentice_outfit() else CHARACTER_MAGE

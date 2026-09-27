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
##   AVATAR      -> le nom du fichier dans assets/ui/ (icon_02...) ;
##   MAGE_COLOR  -> la cle d animation du mage (monk_blue, monk_purple...) ;
##   HAT         -> la cle d animation du mage chapeaute (monk_hat_gold...) ;
##   TOWER       -> le nom du fichier dans assets/terrain/ (tower_sand...) ;
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

## La valeur CHARACTER qui designe le mage lui-meme. Ce n est pas une cle
## d AnimCatalog : le mage est fait de deux cosmetiques (robe et chapeau), que
## UiTheme.mage_frames() assemble. Une chaine distincte plutot que "" parce que
## "" veut deja dire "rien de choisi, prends le defaut" dans SaveData.
const CHARACTER_MAGE: String = "mage"


## Ce cosmetique s EQUIPE-t-il ? Un titre et un avatar se portent sur le profil
## et sont geres ailleurs ; les autres se choisissent dans l onglet Cosmetiques
## et changent ce qu on voit en combat.
func is_equippable() -> bool:
	return kind in [GameEnums.RewardKind.MAGE_COLOR, GameEnums.RewardKind.HAT,
		GameEnums.RewardKind.TOWER, GameEnums.RewardKind.CHARACTER]


## Un APPRENTI : un personnage qui remplace le mage en combat.
func is_apprentice() -> bool:
	return kind == GameEnums.RewardKind.CHARACTER and texture_name != CHARACTER_MAGE

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
##   TOWER       -> le nom du fichier dans assets/terrain/ (tower_sand...).
##
## Un seul champ pour les quatre : ce qui est EQUIPE est toujours une chaine, et
## `SaveData.equipped_cosmetic()` la rend telle quelle. Les deux fichiers de jeu
## qui la lisent (mage_view, battle_backdrop) n ont ainsi rien a interpreter.
@export var texture_name: String = ""


## Ce cosmetique s EQUIPE-t-il ? Un titre et un avatar se portent sur le profil
## et sont geres ailleurs ; les trois autres se choisissent dans l onglet
## Cosmetiques et changent ce qu on voit en combat.
func is_equippable() -> bool:
	return kind in [GameEnums.RewardKind.MAGE_COLOR, GameEnums.RewardKind.HAT,
		GameEnums.RewardKind.TOWER]

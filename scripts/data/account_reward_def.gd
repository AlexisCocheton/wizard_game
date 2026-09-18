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
## Pour un avatar : le nom du fichier dans assets/ui/.
@export var texture_name: String = ""

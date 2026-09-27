class_name ObjectiveDef
extends Resource
## Un objectif optionnel de niveau. Les 3 objectifs debloquent la legendaire.

@export var id: StringName = &""
## Note d auteur. Le joueur voit ObjectiveChecker.label(), GENERE depuis la cle
## et les parametres : un texte ecrit a la main finirait par dire "30 fois" la
## ou les parametres disent 20. Sert de repli pour une cle inconnue.
@export var description: String = ""
## Doit correspondre a un checker enregistre dans ObjectiveChecker.
@export var check_key: StringName = &""
## Parametres du controle, cles en String : voir le tableau en tete de
## objective_checker.gd (noms, types, bornes). L AUDIT refuse un parametre
## manquant, en trop ou mal type.
@export var params: Dictionary = {}

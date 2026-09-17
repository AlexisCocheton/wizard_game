class_name ObjectiveDef
extends Resource
## Un objectif optionnel de niveau. Les 3 objectifs debloquent la legendaire.

@export var id: StringName = &""
@export var description: String = ""
## Doit correspondre a un checker enregistre dans ObjectiveChecker.
@export var check_key: StringName = &""
@export var params: Dictionary = {}

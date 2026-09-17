class_name EffectSpec
extends Resource
## Une brique d'effet elementaire.
## Une carte est une LISTE de EffectSpec appliquee dans l'ordre.
## Ajouter un sort = composer des cles existantes dans un .tres, PAS ecrire un script.

## Doit correspondre a un handler enregistre dans EffectRegistry.
@export var key: StringName = &""
## Intensite principale (degats, % de ralentissement, ...). Sens defini par le handler.
@export var magnitude: float = 0.0
## Duree en secondes pour les effets persistants (zones, buffs). 0 = instantane.
@export var duration: float = 0.0
## Rayon en pixels pour les effets de zone. 0 = non surfacique.
@export var radius: float = 0.0
## Parametres libres specifiques au handler.
@export var params: Dictionary = {}


func get_param(name: StringName, default_value: Variant) -> Variant:
	return params.get(name, default_value)

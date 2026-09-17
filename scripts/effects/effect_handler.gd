class_name EffectHandler
extends RefCounted
## Classe de base des handlers d'effet. Sans etat : tout passe par le contexte.

func get_key() -> StringName:
	return &""


func apply(_spec: EffectSpec, _ctx: CastContext) -> void:
	pass

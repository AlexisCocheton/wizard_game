class_name ObjectiveChecker
extends RefCounted
## Evaluation des objectifs de niveau. Une cle -> une regle lisible dans RunState.
## L etage AUDIT verifie que chaque ObjectiveDef.check_key existe bien ici.

const KEYS: Array[StringName] = [
	&"never_dropped_speed",
	&"no_legendary_used",
	&"no_damage_taken",
]


static func has_key(key: StringName) -> bool:
	return key in KEYS


static func evaluate(objective: ObjectiveDef) -> bool:
	if objective == null:
		return false
	match objective.check_key:
		&"never_dropped_speed":
			# La jauge n est jamais retombee : aucun ennemi n a atteint le mage.
			return not RunState.speed_dropped
		&"no_legendary_used":
			return not RunState.used_legendary
		&"no_damage_taken":
			return not RunState.took_any_damage
	return false

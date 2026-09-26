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
			# DEUX CONDITIONS, et c est nouveau. Depuis que la vitesse EST la vie
			# (26 septembre), "la jauge n est jamais retombee" et "aucun degat
			# subi" sont devenus le MEME evenement : les deux objectifs du jeu
			# se seraient valides ensemble, et l un des deux n aurait plus rien
			# signifie.
			#
			# Celui-ci demande donc ce que son libelle a toujours promis —
			# "en gardant la vitesse AU MAXIMUM" — : finir intact ET a plein
			# regime. C est strictement plus dur que "sans subir de degats",
			# puisqu il faut en plus avoir eu le temps de monter jusqu en haut.
			return not RunState.speed_dropped and SpeedGauge.is_at_max()
		&"no_legendary_used":
			return not RunState.used_legendary
		&"no_damage_taken":
			# Aucun coup encaisse. La vitesse n a donc jamais baisse non plus,
			# mais elle n a pas eu besoin d atteindre le maximum : c est ce qui
			# distingue cet objectif de never_dropped_speed.
			return not RunState.took_any_damage
	return false

class_name EnemyDef
extends Resource
## Definition d un type de monstre.
##
## `power` est la brique de la hierarchie : une vague de puissance 8 est une
## combinaison de monstres dont les puissances totalisent 8 (voir WaveBudget).

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: GameEnums.EnemyKind = GameEnums.EnemyKind.NORMAL
## Niveau de puissance 1..4 (boss et mini-boss au-dela, hors budget).
@export_range(1, 12) var power: int = 1
@export var max_hp: float = 10.0
## Vitesse de descente en pixels/seconde A x1.
@export var base_speed: float = 60.0
## XP de base ; multipliee par le multiplicateur de vitesse a la mort.
@export var base_xp: int = 1
## Degats infliges au mage au contact (passe par le bouclier avant les PV).
@export var contact_damage: int = 1

@export_group("Apparence")
## Cle dans AnimCatalog (feuille animee des packs). Vide = forme dessinee de secours.
@export var anim_key: StringName = &""
## Multiplicateur d echelle du sprite par rapport au rayon logique.
@export var sprite_scale: float = 1.0
@export var shape: GameEnums.Shape = GameEnums.Shape.SQUARE
@export var color: Color = Color(0.75, 0.30, 0.35)
## Rayon logique en pixels : portee de gobage, taille des barres, echelle du sprite.
@export var base_radius: float = 32.0
## Texture fixe optionnelle (prioritaire sur la forme, pas sur anim_key).
@export var sprite: Texture2D

@export_group("Comportements de base")
## Tags de sorts auxquels ce monstre est totalement immunise.
@export var immune_tags: Array[GameEnums.DamageTag] = []
## Probabilite d esquiver un sort (0..1), pour les EVASIVE.
@export var dodge_chance: float = 0.0
## Nombre d unites apparaissant ensemble, pour les SWARM.
@export var swarm_count: int = 1
## Entre par le cote de l ecran au lieu du haut.
@export var entry_side: bool = false
## Intervalle de disparition temporaire en secondes, pour les PHASER. 0 = jamais.
@export var phase_interval: float = 0.0
## Bonus de vitesse (%) accorde aux autres monstres, pour les BUFFER.
@export var buff_speed_pct: float = 0.0

@export_group("Comportements speciaux")
## Gobe les monstres plus faibles qu il croise et grossit.
@export var devours: bool = false
## Gain de vitesse (%) a chaque coup recu, et plafond total.
@export var enrage_speed_pct: float = 0.0
@export var enrage_cap: float = 1.5
## Rayon de l aura qui protege les AUTRES monstres des degats. 0 = aucune.
@export var aura_shield_radius: float = 0.0
## Avance par a-coups : fonce puis marque une pause.
@export var burst_move: bool = false
@export var burst_dash_time: float = 0.6
@export var burst_pause_time: float = 0.7
## Ondulation laterale : amplitude en px et frequence en Hz. 0 = tout droit.
@export var wave_amplitude: float = 0.0
@export var wave_frequency: float = 0.5
## A la mort, engendre `split_count` exemplaires de `split_into` (recursif).
@export var split_into: EnemyDef
@export var split_count: int = 0
## Encaisse le premier coup sans degat (halo visible tant qu il tient).
@export var first_hit_shield: bool = false
## Soigne tous les autres monstres de N PV par seconde tant qu il est en vie.
@export var heal_per_second: float = 0.0
## Tire un projectile sur le mage toutes les N secondes. 0 = ne tire pas.
@export var shoot_interval: float = 0.0
@export var shot_damage: int = 1


func is_immune_to(tag: GameEnums.DamageTag) -> bool:
	return tag in immune_tags


func is_boss() -> bool:
	return kind == GameEnums.EnemyKind.BOSS or kind == GameEnums.EnemyKind.MINIBOSS

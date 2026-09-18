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
## 0 = deduit de la puissance (voir GameConfig.CONTACT_DAMAGE_BY_POWER).
## Une valeur explicite l emporte, pour un monstre volontairement hors bareme.
@export var contact_damage: int = 0

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
## Les tirs font PEU de degats : ils harcelent, ils ne tuent pas. Un archer qui
## fait aussi mal qu une charge rend la distance plus dangereuse que le contact.
@export var shot_damage: int = 2

@export_group("Mecaniques de boss")
## MORCELE — le boss porte `parts_count` parties a detruire separement. Tant
## qu une partie tient, le coeur n encaisse RIEN : le joueur doit changer de
## cible au lieu d empiler ses degats sur la masse centrale.
@export var parts_count: int = 0
## PV de CHAQUE partie. Le surplus d un coup ne coule pas sur la partie suivante :
## sinon un gros sort balaierait toutes les parties d un coup et la mecanique
## redeviendrait « plus de PV ».
@export var part_hp: float = 0.0
## Ralentissement (%) inflige au boss par partie detruite. C est la recompense
## immediate : sans elle, le joueur tape dans le vide pendant la moitie du combat.
@export var part_slow_pct: float = 0.0

## CANONNIER — distance au mage (px) a laquelle le boss s arrete pour tirer.
## 0 = il descend jusqu au contact comme tout le monde. Un boss qui campe ne
## peut pas etre attendu sur la ligne de defense : il faut aller le chercher.
@export var keeps_distance_at: float = 0.0

## INVOCATEUR — engendre `summon_count` exemplaires de `summon_def` toutes les
## `summon_interval` secondes, tant qu il est en vie. Tuer la source coupe le
## flux : c est la reponse que ce boss exige.
@export var summon_interval: float = 0.0
@export var summon_def: EnemyDef
@export var summon_count: int = 1
## Plafond de sbires VIVANTS issus de ce boss. Sans plafond, un joueur qui traine
## perd par accumulation mecanique, ce qui n est plus une decision de jeu.
@export var summon_max_alive: int = 6


func is_immune_to(tag: GameEnums.DamageTag) -> bool:
	return tag in immune_tags


func is_boss() -> bool:
	return kind == GameEnums.EnemyKind.BOSS or kind == GameEnums.EnemyKind.MINIBOSS


## Degats infliges au mage au contact. Le bareme vit dans GameConfig pour qu un
## reglage d equilibrage ne demande pas de rouvrir 22 fichiers de contenu.
func contact_hit() -> int:
	if contact_damage > 0:
		return contact_damage
	if kind == GameEnums.EnemyKind.BOSS:
		return GameConfig.CONTACT_DAMAGE_BOSS
	if kind == GameEnums.EnemyKind.MINIBOSS:
		return GameConfig.CONTACT_DAMAGE_MINIBOSS
	return int(GameConfig.CONTACT_DAMAGE_BY_POWER.get(power, 5))

class_name ChallengeDef
extends Resource
## Un DEFI de compte : un objectif nomme, valable une seule fois, qui rapporte de
## l XP de compte.
##
## A la difference des ObjectiveDef, qui appartiennent a un niveau et se rejouent,
## un defi est global et definitif. C est ce qui en fait une progression de compte
## et non une performance de partie.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## XP de compte verse a l accomplissement.
@export var xp_reward: int = 100
## Cle lue par ChallengeTracker pour savoir quoi compter.
@export var track_key: StringName = &""
## Seuil a atteindre (monstres tues, niveaux finis, vagues survecues...).
@export var target: int = 1

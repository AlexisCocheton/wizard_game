class_name ChallengeDef
extends Resource
## Un SUCCES de compte : un objectif nomme, valable une seule fois, qui rapporte
## de l XP de compte.
##
## A la difference des ObjectiveDef, qui appartiennent a un niveau et se rejouent,
## un succes est global et definitif. C est ce qui en fait une progression de
## compte et non une performance de partie.
##
## Le nom de CLASSE reste ChallengeDef alors que la vitrine dit "SUCCES". C est
## volontaire : renommer la classe invaliderait les .tres deja references par les
## profils enregistres (`completed_challenges`), et ferait perdre au joueur tout
## ce qu il a accompli. Le mot change a l ecran, la plomberie ne bouge pas.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

## RARETE du succes. Elle n est pas decorative : c est elle qui fixe l XP verse
## et la couleur du contour affiche. Un legendaire qui rapporterait autant qu un
## commun rendrait le classement mensonger.
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON

## XP de compte verse a l accomplissement. Toujours ecrit par `xp_for_rarity()`
## dans `tools/make_account.gd` : le champ reste exporte pour rester lisible dans
## l inspecteur, mais il n a pas a diverger du bareme.
@export var xp_reward: int = 100
## Cle lue par ChallengeTracker pour savoir quoi compter.
@export var track_key: StringName = &""
## Seuil a atteindre (monstres tues, niveaux finis, vagues survecues...).
@export var target: int = 1


## Le bareme d XP par rarete. Un seul endroit, pour que la rarete affichee et
## l XP verse ne puissent jamais se contredire ; verrouille par test_account.
static func xp_for_rarity(r: int) -> int:
	match r:
		GameEnums.Rarity.COMMON: return 250
		GameEnums.Rarity.RARE: return 500
		GameEnums.Rarity.EPIC: return 900
		GameEnums.Rarity.LEGENDARY: return 1600
	return 250

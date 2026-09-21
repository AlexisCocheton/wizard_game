extends Node
## Suivi des DEFIS de compte.
##
## Un seul endroit compte les statistiques durables (monstres tues, niveaux finis,
## vitesse atteinte...) et valide les defis qui les atteignent. Disperser ces
## compteurs dans l interface les rendrait faux des qu un ecran serait saute.
##
## Les compteurs vivent dans SaveData, pas ici : ils doivent survivre a la
## fermeture du jeu. Ce noeud n est que la plomberie qui les met a jour.

## Emis quand un defi vient d etre accompli, pour que l interface puisse le feter.
signal challenge_reached(challenge: ChallengeDef)


func _ready() -> void:
	# ContentDB et SaveData sont charges avant : l ordre des autoloads le garantit.
	SaveData.challenge_completed.connect(_on_completed)
	rattraper()


## Valide les succes DEJA MERITES mais jamais valides.
##
## Le defaut que ceci repare : _check() n etait appele qu au moment ou un
## compteur FRANCHIT le seuil. Un succes ajoute apres coup ne se declenchait donc
## jamais, meme chez un joueur tres au-dela de la cible — il restait affiche avec
## sa barre pleine, dans la liste des non accomplis, indefiniment. Le chantier L
## venant d ajouter six succes, tout profil existant aurait perdu ce qu il avait
## deja gagne.
##
## Appele au demarrage : c est le seul moment ou le catalogue et la sauvegarde
## sont tous deux charges, et ou un ecart entre les deux peut exister.
func rattraper() -> void:
	for c: ChallengeDef in ContentDB.challenges_list():
		if c == null or c.target <= 0:
			continue
		if value_of(c.track_key) >= c.target:
			SaveData.complete_challenge(c.id)


func _on_completed(c: ChallengeDef) -> void:
	challenge_reached.emit(c)


## Ajoute `amount` a un compteur et revalide les defis qui le lisent.
func bump(key: StringName, amount: int = 1) -> void:
	if amount == 0:
		return
	var stats: Dictionary = SaveData.challenge_stats()
	stats[String(key)] = int(stats.get(String(key), 0)) + amount
	SaveData.set_challenge_stats(stats)
	_check(key, int(stats[String(key)]))


## Pose une valeur ATTEINTE plutot qu un cumul : une vitesse maximale ou une
## vague atteinte ne s additionne pas d une partie a l autre, elle se bat.
func record_best(key: StringName, value: int) -> void:
	var stats: Dictionary = SaveData.challenge_stats()
	if value <= int(stats.get(String(key), 0)):
		return
	stats[String(key)] = value
	SaveData.set_challenge_stats(stats)
	_check(key, value)


func value_of(key: StringName) -> int:
	return int(SaveData.challenge_stats().get(String(key), 0))


## Avancement d un defi, de 0 a 1 : ce que la barre affiche dans l ecran des defis.
func progress_of(c: ChallengeDef) -> float:
	if c == null or c.target <= 0:
		return 0.0
	return clampf(float(value_of(c.track_key)) / float(c.target), 0.0, 1.0)


func _check(key: StringName, value: int) -> void:
	for c: ChallengeDef in ContentDB.challenges_list():
		if c.track_key == key and value >= c.target:
			SaveData.complete_challenge(c.id)


## Revalide TOUS les defis. Utile apres une migration de profil ou l ajout de
## nouveaux defis a un compte deja avance : sans cela, un joueur qui a deja tue
## 1000 monstres ne verrait jamais le defi correspondant s accomplir.
func recheck_all() -> void:
	var stats: Dictionary = SaveData.challenge_stats()
	for c: ChallengeDef in ContentDB.challenges_list():
		if int(stats.get(String(c.track_key), 0)) >= c.target:
			SaveData.complete_challenge(c.id)

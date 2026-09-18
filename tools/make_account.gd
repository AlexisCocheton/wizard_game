extends Node
## Generateur des DEFIS et des RECOMPENSES DE COMPTE.
##
## Fichier separe de make_content.gd : la progression de compte est une couche
## a part, et ce decoupage permet de la regenerer sans toucher aux cartes, aux
## monstres ni aux niveaux.
##
## Usage : Godot --headless --path . tools/make_account.tscn

const CH := "res://resources/challenges/"
const RW := "res://resources/rewards/"


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RW))
	_challenges()
	_rewards()
	print("ACCOUNT_OK")
	get_tree().quit(0)


func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Sauvegarde impossible : %s (err %d)" % [path, err])
	else:
		print("  ecrit ", path)


func _challenge(id: String, nom: String, desc: String, key: String,
		cible: int, xp: int) -> ChallengeDef:
	var c := ChallengeDef.new()
	c.id = StringName(id)
	c.display_name = nom
	c.description = desc
	c.track_key = StringName(key)
	c.target = cible
	c.xp_reward = xp
	return c


## Les defis guident le joueur vers des facons de jouer qu il ne trouverait pas
## seul : viser les groupes, tenir en Massacre, finir sans encaisser.
func _challenges() -> void:
	var liste: Array[ChallengeDef] = [
		# --- Premiers pas : tombent vite, pour que la mecanique se voie bouger ---
		_challenge("ch_first_win", "Premier souffle",
			"Terminer un niveau.", "levels_cleared", 1, 250),
		_challenge("ch_slayer_100", "Chasseur",
			"Tuer 100 monstres, toutes parties confondues.", "enemies_killed", 100, 250),
		_challenge("ch_cards_25", "Collectionneur",
			"Decouvrir 25 cartes differentes.", "cards_discovered", 25, 300),

		# --- Maitrise : demandent de jouer autrement ---
		_challenge("ch_flawless", "Intouchable",
			"Terminer un niveau sans subir le moindre degat.", "flawless_clears", 1, 600),
		_challenge("ch_speed_500", "Course du temps",
			"Atteindre 500 pourcent de vitesse dans une partie.", "max_speed_reached", 500, 500),
		_challenge("ch_massacre_10", "Sans fin",
			"Survivre a 10 vagues en Massacre.", "massacre_wave", 10, 500),

		# --- Long terme : la campagne et le bestiaire ---
		_challenge("ch_act_one", "Le Monde volant",
			"Terminer les deux niveaux du premier acte.", "levels_cleared", 2, 400),
		_challenge("ch_bestiary_20", "Naturaliste",
			"Rencontrer 20 especes de monstres.", "enemies_discovered", 20, 400),
		_challenge("ch_slayer_1000", "Fleau des monstres",
			"Tuer 1000 monstres.", "enemies_killed", 1000, 900),
		_challenge("ch_campaign", "Jusqu a la source",
			"Terminer les sept niveaux de la campagne.", "levels_cleared", 7, 1200),
	]
	for c in liste:
		_save(c, CH + String(c.id) + ".tres")


func _reward(id: String, nom: String, desc: String, niveau: int,
		kind: GameEnums.RewardKind, texture: String = "") -> AccountRewardDef:
	var r := AccountRewardDef.new()
	r.id = StringName(id)
	r.display_name = nom
	r.description = desc
	r.at_level = niveau
	r.kind = kind
	r.texture_name = texture
	return r


## Uniquement des titres et des avatars : aucune recompense ne touche a la
## puissance, sinon l equilibrage mesure des sept niveaux ne vaudrait plus rien.
func _rewards() -> void:
	var K := GameEnums.RewardKind
	var liste: Array[AccountRewardDef] = [
		_reward("rw_title_apprenti", "Apprenti",
			"Titre affiche sur ton profil.", 2, K.TITLE),
		_reward("rw_avatar_02", "Portrait du veilleur",
			"Un nouveau portrait pour ton profil.", 3, K.AVATAR, "icon_02"),
		_reward("rw_title_remonteur", "Remonteur de temps",
			"Titre affiche sur ton profil.", 4, K.TITLE),
		_reward("rw_avatar_05", "Portrait de l archiviste",
			"Un nouveau portrait pour ton profil.", 5, K.AVATAR, "icon_05"),
		_reward("rw_title_briseur", "Briseur de cycles",
			"Titre affiche sur ton profil.", 6, K.TITLE),
		_reward("rw_avatar_09", "Portrait du dernier mage",
			"Un nouveau portrait pour ton profil.", 8, K.AVATAR, "icon_09"),
		_reward("rw_title_origine", "Temoin de l Origine",
			"Titre affiche sur ton profil.", 10, K.TITLE),
	]
	for r in liste:
		_save(r, RW + String(r.id) + ".tres")

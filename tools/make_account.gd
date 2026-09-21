extends Node
## Generateur des SUCCES et des RECOMPENSES DE COMPTE.
##
## Fichier separe de make_content.gd : la progression de compte est une couche
## a part, et ce decoupage permet de la regenerer sans toucher aux cartes, aux
## monstres ni aux niveaux.
##
## Usage : Godot --headless --path . tools/make_account.tscn   (PAS --script :
## ce script etend Node, et --script n enregistre pas les autoloads.)

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


## L XP n est JAMAIS passe a la main : il decoule de la rarete. C est ce qui
## garantit qu un succes legendaire paie toujours plus qu un epique, meme si
## quelqu un ajoute un succes sans regarder le bareme.
func _challenge(id: String, nom: String, desc: String, key: String,
		cible: int, rarete: GameEnums.Rarity) -> ChallengeDef:
	var c := ChallengeDef.new()
	c.id = StringName(id)
	c.display_name = nom
	c.description = desc
	c.track_key = StringName(key)
	c.target = cible
	c.rarity = rarete
	c.xp_reward = ChallengeDef.xp_for_rarity(rarete)
	return c


## Les SUCCES, ranges par rarete.
##
## La rarete dit le COUT en temps de jeu, pas la difficulte d un geste : un
## commun tombe dans la premiere heure, un legendaire demande d avoir fini le
## jeu. C est ce qui rend la couleur du contour informative d un coup d oeil —
## le joueur voit tout de suite ce qui est a sa portee.
##
## Les succes guident aussi vers des facons de jouer qu on ne trouve pas seul :
## viser les groupes, tenir en Massacre, finir sans encaisser.
func _challenges() -> void:
	var R := GameEnums.Rarity
	var liste: Array[ChallengeDef] = [
		# --- COMMUNS : tombent dans la premiere heure, pour que la mecanique
		#     de compte se voie bouger tout de suite ---
		_challenge("ch_first_win", "Premier souffle",
			"Terminer un niveau.", "levels_cleared", 1, R.COMMON),
		_challenge("ch_slayer_100", "Chasseur",
			"Tuer 100 monstres, toutes parties confondues.", "enemies_killed", 100, R.COMMON),
		_challenge("ch_cards_25", "Collectionneur",
			"Decouvrir 25 cartes differentes.", "cards_discovered", 25, R.COMMON),
		_challenge("ch_bestiary_10", "Curieux",
			"Rencontrer 10 especes de monstres.", "enemies_discovered", 10, R.COMMON),

		# --- RARES : demandent quelques soirees, ou de jouer autrement ---
		_challenge("ch_act_one", "Le Monde volant",
			"Terminer les deux niveaux du premier acte.", "levels_cleared", 2, R.RARE),
		_challenge("ch_bestiary_20", "Naturaliste",
			"Rencontrer 20 especes de monstres.", "enemies_discovered", 20, R.RARE),
		_challenge("ch_massacre_10", "Sans fin",
			"Survivre a 10 vagues en Massacre.", "massacre_wave", 10, R.RARE),
		_challenge("ch_speed_500", "Course du temps",
			"Atteindre 500 pourcent de vitesse dans une partie.", "max_speed_reached", 500, R.RARE),
		_challenge("ch_slayer_500", "Moissonneur",
			"Tuer 500 monstres.", "enemies_killed", 500, R.RARE),

		# --- EPIQUES : une maitrise reelle, pas du temps passe ---
		_challenge("ch_flawless", "Intouchable",
			"Terminer un niveau sans subir le moindre degat.", "flawless_clears", 1, R.EPIC),
		_challenge("ch_speed_1000", "Hors du temps",
			"Atteindre 1000 pourcent de vitesse dans une partie.", "max_speed_reached", 1000, R.EPIC),
		_challenge("ch_massacre_25", "Le mur",
			"Survivre a 25 vagues en Massacre.", "massacre_wave", 25, R.EPIC),
		_challenge("ch_slayer_1000", "Fleau des monstres",
			"Tuer 1000 monstres.", "enemies_killed", 1000, R.EPIC),

		# --- LEGENDAIRES : la fin du jeu, ou tres au-dela ---
		_challenge("ch_campaign", "Jusqu a la source",
			"Terminer les sept niveaux de la campagne.", "levels_cleared", 7, R.LEGENDARY),
		_challenge("ch_flawless_3", "Sans une egratignure",
			"Terminer trois niveaux sans subir le moindre degat.", "flawless_clears", 3, R.LEGENDARY),
		_challenge("ch_massacre_50", "Le temps n existe plus",
			"Survivre a 50 vagues en Massacre.", "massacre_wave", 50, R.LEGENDARY),
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


## Uniquement des titres, des avatars et des COSMETIQUES : aucune recompense ne
## touche a la puissance, sinon l equilibrage mesure des sept niveaux ne vaudrait
## plus rien et jouer beaucoup vaudrait mieux que jouer bien.
##
## Les trois axes cosmetiques s ouvrent en alternance, un palier sur deux environ :
## le joueur a toujours quelque chose de NOUVEAU a essayer au niveau suivant, et
## jamais trois choix du meme genre d un coup.
##
## Chaque axe a son entree de niveau 1 : c est ce que porte un profil neuf, et
## c est ce qui permet a l onglet Cosmetiques d afficher une grille complete des
## le depart plutot qu une case vide.
func _rewards() -> void:
	var K := GameEnums.RewardKind
	var liste: Array[AccountRewardDef] = [
		# --- Les defauts, disponibles des le niveau 1 ---
		_reward("rw_mage_blue", "Robe d azur",
			"La robe bleue des gardiens du temps.", 1, K.MAGE_COLOR, "monk_blue"),
		_reward("rw_hat_straw", "Chapeau de paille",
			"Le chapeau du voyageur.", 1, K.HAT, "monk_blue"),
		_reward("rw_tower_blue", "Tour d azur",
			"La tour de pierre bleue.", 1, K.TOWER, "tower_blue"),

		# --- Paliers ---
		_reward("rw_title_apprenti", "Apprenti",
			"Titre affiche sur ton profil.", 2, K.TITLE),
		_reward("rw_hat_crimson", "Chapeau carmin",
			"Un chapeau rouge sang, qu on repere de loin.", 2, K.HAT, "monk_hat_crimson"),

		_reward("rw_avatar_02", "Portrait du veilleur",
			"Un nouveau portrait pour ton profil.", 3, K.AVATAR, "icon_02"),
		_reward("rw_mage_black", "Robe d encre",
			"La robe noire des mages sans nom.", 3, K.MAGE_COLOR, "monk_black"),

		_reward("rw_title_remonteur", "Remonteur de temps",
			"Titre affiche sur ton profil.", 4, K.TITLE),
		_reward("rw_tower_sand", "Tour de gres",
			"Une tour de pierre chaude, taillee dans le desert.", 4, K.TOWER, "tower_sand"),

		_reward("rw_avatar_05", "Portrait de l archiviste",
			"Un nouveau portrait pour ton profil.", 5, K.AVATAR, "icon_05"),
		_reward("rw_hat_emerald", "Chapeau d emeraude",
			"Un chapeau vert profond, couleur des forets d avant.", 5, K.HAT, "monk_hat_emerald"),

		_reward("rw_title_briseur", "Briseur de cycles",
			"Titre affiche sur ton profil.", 6, K.TITLE),
		_reward("rw_mage_purple", "Robe d amethyste",
			"La robe violette des briseurs de cycles.", 6, K.MAGE_COLOR, "monk_purple"),

		_reward("rw_tower_obsidian", "Tour d obsidienne",
			"Une tour de verre noir, nee d un ancien incendie.", 7, K.TOWER, "tower_obsidian"),

		_reward("rw_avatar_09", "Portrait du dernier mage",
			"Un nouveau portrait pour ton profil.", 8, K.AVATAR, "icon_09"),
		_reward("rw_hat_violet", "Chapeau d amethyste",
			"Un chapeau violet, assorti aux robes des anciens.", 8, K.HAT, "monk_hat_violet"),

		_reward("rw_title_origine", "Temoin de l Origine",
			"Titre affiche sur ton profil.", 10, K.TITLE),
		_reward("rw_tower_ember", "Tour de braise",
			"Une tour qui rougeoie encore de la derniere bataille.", 10, K.TOWER, "tower_ember"),

		# --- Le bout de la progression : le chapeau d or, le plus voyant ---
		_reward("rw_hat_gold", "Chapeau d or",
			"L or des mages qui ont vu la source du temps.", 12, K.HAT, "monk_hat_gold"),
	]
	for r in liste:
		_save(r, RW + String(r.id) + ".tres")

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
			"Obtenir 25 cartes differentes.", "cards_discovered", 25, R.COMMON),
		_challenge("ch_bestiary_10", "Curieux",
			"Rencontrer 10 especes de monstres.", "enemies_discovered", 10, R.COMMON),

		# --- RARES : demandent quelques soirees, ou de jouer autrement ---
		_challenge("ch_act_one", "La foret de Nuri",
			"Terminer les %d niveaux du premier acte." % _niveaux_acte(1),
			"levels_cleared", _niveaux_acte(1), R.RARE),
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
			"Terminer les %d niveaux de la campagne." % _niveaux_total(),
			"levels_cleared", _niveaux_total(), R.LEGENDARY),
		_challenge("ch_flawless_3", "Sans une egratignure",
			"Terminer trois niveaux sans subir le moindre degat.", "flawless_clears", 3, R.LEGENDARY),
		_challenge("ch_massacre_50", "Le temps n existe plus",
			"Survivre a 50 vagues en Massacre.", "massacre_wave", 50, R.LEGENDARY),
	]
	for c in liste:
		_save(c, CH + String(c.id) + ".tres")


## LES CIBLES SE DEDUISENT DU CONTENU, elles ne sont plus ecrites a la main.
##
## Le defaut que ceci empeche : "Jusqu a la source" demandait 7 niveaux termines
## pour recompenser la FIN de la campagne. La campagne passe a 21 niveaux — le
## succes legendaire se serait valide au tiers du jeu, et le joueur aurait recu
## sa plus haute recompense en plein acte 2. Rien n aurait plante, rien n aurait
## rougi : un nombre en dur qui devient faux ne se voit pas.
##
## Meme raison pour l acte 1, passe de 2 a 4 niveaux.
func _niveaux_total() -> int:
	return maxi(1, ContentDB.levels.size())


func _niveaux_acte(acte: int) -> int:
	var n: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		if lv != null and lv.act == acte:
			n += 1
	return maxi(1, n)


func _reward(id: String, nom: String, desc: String, niveau: int,
		kind: GameEnums.RewardKind, texture: String = "",
		pour: String = "") -> AccountRewardDef:
	var r := AccountRewardDef.new()
	r.id = StringName(id)
	r.display_name = nom
	r.description = desc
	r.at_level = niveau
	r.kind = kind
	r.texture_name = texture
	r.for_character = pour
	return r


## Uniquement des titres, des portraits et des COSMETIQUES : aucune recompense ne
## touche a la puissance, sinon l equilibrage mesure ne vaudrait plus rien et
## jouer beaucoup vaudrait mieux que jouer bien.
##
## LA GARDE-ROBE DE LA VAGUE 8 (assets : tools/assets/make_wardrobe.py).
## Trois a six pieces par palier, de genres MELANGES : le joueur a toujours
## quelque chose de nouveau a essayer au niveau suivant, jamais trois choix du
## meme genre d un coup.
##
## TOUT TIENT DANS LES DOUZE PREMIERS NIVEAUX. Seuls les succes donnent de l XP
## (11 900 au total aujourd hui), ce qui plafonne le compte au niveau 12 : une
## piece posee au 13 n arriverait jamais. test_wardrobe le verrouille contre le
## catalogue des succes, pas contre un nombre ecrit ici.
##
## Les apprentis arrivent avant leurs teintes ; une teinte n est jamais donnee
## avant son apprenti (verifie par test_wardrobe).
##
## Chaque axe a son entree de niveau 1 : c est ce que porte un profil neuf.
func _rewards() -> void:
	var K := GameEnums.RewardKind
	var NU := AccountRewardDef.HAT_NONE
	var liste: Array[AccountRewardDef] = [
		# --- Les defauts, disponibles des le niveau 1 ---
		_reward("rw_mage_blue", "Robe d azur",
			"La robe bleue des gardiens du temps.", 1, K.MAGE_COLOR, "monk_blue"),
		# L id historique est garde : c est la tete nue, la tonsure du voyageur.
		_reward("rw_hat_straw", "Tete nue",
			"La tonsure du voyageur, au vent.", 1, K.HAT, NU),
		_reward("rw_tower_blue", "Tour d azur",
			"La tour de pierre bleue.", 1, K.TOWER, "tower_blue"),
		# Le mage est un choix comme un autre dans la grille PERSONNAGE : sans
		# cette entree, un joueur qui a pris un apprenti ne pourrait plus
		# revenir a lui.
		_reward("rw_char_mage", "Le mage",
			"Le gardien du temps en personne.", 1, K.CHARACTER,
			AccountRewardDef.CHARACTER_MAGE),
		_reward("rw_avatar_warrior", "Le veilleur",
			"Le portrait du profil.", 1, K.AVATAR, "avatar_warrior_red"),

		# --- 2 ---
		_reward("rw_title_apprenti", "Apprenti",
			"Titre affiche sur ton profil.", 2, K.TITLE),
		_reward("rw_hat_feather", "Chapeau a plume",
			"Un feutre carmin et une plume blanche, qu on repere de loin.", 2, K.HAT, "hat_feather"),
		_reward("rw_avatar_monk_blue", "Le mage d azur",
			"Un portrait du gardien du temps.", 2, K.AVATAR, "avatar_monk_blue"),

		# --- 3 ---
		_reward("rw_mage_black", "Robe d encre",
			"La robe noire des mages sans nom.", 3, K.MAGE_COLOR, "monk_black"),
		_reward("rw_hat_wizard", "Chapeau pointu",
			"Bleu nuit, seme d etoiles : le chapeau des mages d avant.", 3, K.HAT, "hat_wizard"),
		_reward("rw_tower_red", "Tour carmin",
			"Une tour aux creneaux rouges.", 3, K.TOWER, "tower_red"),

		# --- 4 ---
		_reward("rw_title_remonteur", "Remonteur de temps",
			"Titre affiche sur ton profil.", 4, K.TITLE),
		_reward("rw_tower_sand", "Tour de gres",
			"Une tour de pierre chaude, taillee dans le desert.", 4, K.TOWER, "tower_sand"),
		# APPRENTIS PROVISOIRES : en attendant le Witches Pack, des personnages
		# animes deja sur le disque, qu aucun monstre ne porte (AUDIT).
		_reward("rw_char_soldier", "L ecuyer",
			"Un soldat qui a pose l epee pour l arc. Il combat a la place du mage.",
			4, K.CHARACTER, "soldier"),
		_reward("rw_avatar_pawn_blue", "La paysanne",
			"Un portrait pour ton profil.", 4, K.AVATAR, "avatar_pawn_blue"),

		# --- 5 ---
		_reward("rw_hat_hood", "Capuche des bois",
			"Une capuche verte, couleur des forets d avant.", 5, K.HAT, "hat_hood"),
		_reward("rw_mage_red", "Robe de braise",
			"La robe rouge des moines de la vallee.", 5, K.MAGE_COLOR, "monk_red"),
		_reward("rw_tower_tree", "L arbre-nid",
			"Un vieux bouleau ou percher. Il se balance avec le vent.", 5, K.TOWER, "tower_tree"),
		_reward("rw_avatar_monk_red", "Le moine de braise",
			"Un portrait pour ton profil.", 5, K.AVATAR, "avatar_monk_red"),

		# --- 6 ---
		_reward("rw_title_briseur", "Briseur de cycles",
			"Titre affiche sur ton profil.", 6, K.TITLE),
		_reward("rw_mage_purple", "Robe d amethyste",
			"La robe violette des briseurs de cycles.", 6, K.MAGE_COLOR, "monk_purple"),
		_reward("rw_char_fairy", "La fee",
			"Elle ne pose jamais pied a terre. Elle combat a la place du mage.",
			6, K.CHARACTER, "fairy"),
		_reward("rw_outfit_soldier_azure", "Ecuyer d azur",
			"Une tunique bleue pour l ecuyer.", 6, K.MAGE_COLOR, "soldier_azure", "soldier"),
		_reward("rw_hat_beanie", "Bonnet de laine",
			"Rouge, avec un pompon. Pour les sieges d hiver.", 6, K.HAT, "hat_beanie"),

		# --- 7 ---
		_reward("rw_tower_obsidian", "Tour d obsidienne",
			"Une tour de verre noir, nee d un ancien incendie.", 7, K.TOWER, "tower_obsidian"),
		_reward("rw_hat_turban", "Turban",
			"Des lieues de tissu creme et un joyau turquoise.", 7, K.HAT, "hat_turban"),
		_reward("rw_mage_yellow", "Robe d ocre",
			"La robe jaune des moines du desert.", 7, K.MAGE_COLOR, "monk_yellow"),
		_reward("rw_tower_yellow", "Tour d ambre",
			"Une tour aux creneaux dores.", 7, K.TOWER, "tower_yellow"),
		_reward("rw_avatar_knight_blue", "Le chevalier",
			"Un portrait pour ton profil.", 7, K.AVATAR, "avatar_knight_blue"),

		# --- 8 ---
		_reward("rw_hat_witch", "Chapeau de sorciere",
			"Un large bord, une pointe tordue, une boucle d or.", 8, K.HAT, "hat_witch"),
		_reward("rw_outfit_fairy_sun", "Fee solaire",
			"Des ailes d or et une robe rouge.", 8, K.MAGE_COLOR, "fairy_sun", "fairy"),
		_reward("rw_tower_ruins", "Sanctuaire des ruines",
			"Un edifice de brique a toit plat, rescape d une cite oubliee.",
			8, K.TOWER, "tower_ruins"),
		_reward("rw_mage_forest", "Robe de mousse",
			"Le vert des sous-bois.", 8, K.MAGE_COLOR, "monk_forest"),
		_reward("rw_avatar_lancer_yellow", "Le lancier",
			"Un portrait pour ton profil.", 8, K.AVATAR, "avatar_lancer_yellow"),

		# --- 9 ---
		# Le niveau 9 etait un palier VIDE : le joueur montait sans rien recevoir.
		_reward("rw_char_bluewitch", "Apprentie d azur",
			"La premiere apprentie du mage. Elle combat a sa place ; il garde la parole dans les histoires.",
			9, K.CHARACTER, "bluewitch"),
		_reward("rw_hat_helm", "Heaume",
			"Acier poli et cimier rouge.", 9, K.HAT, "hat_helm"),
		_reward("rw_tower_purple", "Tour d amethyste",
			"Une tour aux creneaux violets.", 9, K.TOWER, "tower_purple"),
		_reward("rw_outfit_soldier_royal", "Ecuyer royal",
			"Un casque dore et une tunique pourpre.", 9, K.MAGE_COLOR, "soldier_royal", "soldier"),
		_reward("rw_avatar_monk_yellow", "Le moine d ocre",
			"Un portrait pour ton profil.", 9, K.AVATAR, "avatar_monk_yellow"),

		# --- 10 ---
		_reward("rw_title_origine", "Temoin de l Origine",
			"Titre affiche sur ton profil.", 10, K.TITLE),
		_reward("rw_tower_ember", "Tour de braise",
			"Une tour qui rougeoie encore de la derniere bataille.", 10, K.TOWER, "tower_ember"),
		_reward("rw_hat_laurel", "Couronne de laurier",
			"Le laurier des vainqueurs.", 10, K.HAT, "hat_laurel"),
		_reward("rw_outfit_bluewitch_ember", "Apprentie de braise",
			"Cheveux de flamme et robe de cendre.", 10, K.MAGE_COLOR, "bluewitch_ember", "bluewitch"),
		_reward("rw_outfit_fairy_moss", "Fee des mousses",
			"Des ailes vertes et une robe violette.", 10, K.MAGE_COLOR, "fairy_moss", "fairy"),
		_reward("rw_avatar_knight_purple", "Le chevalier pourpre",
			"Un portrait pour ton profil.", 10, K.AVATAR, "avatar_knight_purple"),

		# --- 11 ---
		_reward("rw_hat_horns", "Cornes",
			"Ramenees du monde demoniaque. Elles ne poussent pas, promis.", 11, K.HAT, "hat_horns"),
		_reward("rw_tower_black", "Tour d encre",
			"Une tour aux creneaux d ardoise.", 11, K.TOWER, "tower_black"),
		_reward("rw_outfit_bluewitch_frost", "Apprentie de givre",
			"Une robe pale et des cheveux d argent.", 11, K.MAGE_COLOR, "bluewitch_frost", "bluewitch"),
		_reward("rw_mage_dawn", "Robe d aube",
			"Ivoire et lilas : la couleur du ciel avant le premier cycle.", 11, K.MAGE_COLOR, "monk_dawn"),
		_reward("rw_avatar_monk_purple", "Le moine d amethyste",
			"Un portrait pour ton profil.", 11, K.AVATAR, "avatar_monk_purple"),

		# --- 12 : le bout de la progression, les pieces les plus voyantes ---
		_reward("rw_hat_crown", "Couronne d or",
			"L or des mages qui ont vu la source du temps.", 12, K.HAT, "hat_crown"),
		_reward("rw_hat_halo", "Aureole",
			"Elle flotte toute seule. Personne ne sait pourquoi.", 12, K.HAT, "hat_halo"),
		_reward("rw_hat_tophat", "Haut-de-forme du temps",
			"Un cadran sur le ruban : il retarde toujours un peu.", 12, K.HAT, "hat_tophat"),
		_reward("rw_tower_monastery", "Le monastere",
			"Le mage se tient sur le seuil de la maison des moines.", 12, K.TOWER, "tower_monastery"),
		_reward("rw_outfit_bluewitch_moss", "Apprentie des mousses",
			"Une robe de foret et des cheveux de ble.", 12, K.MAGE_COLOR, "bluewitch_moss", "bluewitch"),
		_reward("rw_avatar_monk_black", "Le moine d encre",
			"Un portrait pour ton profil.", 12, K.AVATAR, "avatar_monk_black"),
	]
	for r in liste:
		_save(r, RW + String(r.id) + ".tres")

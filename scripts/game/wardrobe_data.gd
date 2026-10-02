class_name WardrobeData
extends RefCounted
## GENERE par tools/assets/make_wardrobe.py -- NE PAS EDITER A LA MAIN.
## Relancer le script apres tout changement de feuille de robe, de chapeau ou
## de tour : les nombres ci-dessous sont MESURES sur les PNG.

## --- CHAPEAUX (assets/cosmetics/hats.png, une case par chapeau) ---
const HAT_SHEET: String = "res://assets/cosmetics/hats.png"
const HAT_CELL: Vector2i = Vector2i(96, 104)
## Point de la case pose sur le SOMMET DE LA TETE.
const HAT_PIVOT: Vector2 = Vector2(48, 64)
const HATS: Array[String] = ["hat_feather", "hat_wizard", "hat_beanie", "hat_hood", "hat_turban", "hat_witch", "hat_helm", "hat_laurel", "hat_horns", "hat_crown", "hat_halo", "hat_tophat"]

## Sommet de la tete IMAGE PAR IMAGE, en px de la case de la feuille (192 px
## pour le moine). Cle = gabarit ; HAT_RIGS dit quelle feuille utilise lequel.
## Mesure : centre de la tonsure, premier pixel opaque au-dessus dans les
## colonnes de la tete (les mains levees de l incantation sont a cote).
const HAT_ANCHORS: Dictionary = {
	"monk": {
		"idle": [[96.5, 65.0], [97.5, 66.0], [96.5, 67.0], [95.5, 67.0], [94.5, 67.0], [95.5, 66.0]],
		"walk": [[94.5, 65.0], [95.5, 63.0], [94.5, 65.0], [93.5, 63.0]],
		"cast": [[96.5, 66.0], [98.0, 72.0], [96.0, 71.0], [95.0, 70.0], [95.0, 70.0], [95.0, 70.0], [95.0, 70.0], [95.0, 70.0], [95.0, 70.0], [95.0, 71.0], [94.5, 67.0]],
	},
}
## Feuille jouee -> gabarit de tete. Les sept robes du mage sont la MEME
## silhouette (assertion alpha dans le script) ; les apprentis n en ont pas :
## chacun porte deja son couvre-chef dessine (chapeau de sorciere, casque,
## antennes de fee), un second chapeau par-dessus serait un non-sens.
const HAT_RIGS: Dictionary = {"monk_blue": "monk", "monk_black": "monk", "monk_purple": "monk", "monk_red": "monk", "monk_yellow": "monk", "monk_dawn": "monk", "monk_forest": "monk"}
const HAT_RIG_CELL: Dictionary = {"monk": 192}

## --- TOURS (assets/terrain/<cle>.png) ---
## frame = taille d une case ; frames > 1 = bande animee ; feet = point de la
## case ou se posent les PIEDS du personnage ; scale = echelle a l ecran ;
## crop = region opaque de la premiere case (vignette de l onglet).
const TOWERS: Dictionary = {
	"tower_blue": {"frame": [128, 256], "frames": 1, "feet": [64.0, 123.4], "scale": 1.6, "crop": [4, 46, 120, 184]},
	"tower_sand": {"frame": [128, 256], "frames": 1, "feet": [64.0, 123.4], "scale": 1.6, "crop": [4, 46, 120, 184]},
	"tower_obsidian": {"frame": [128, 256], "frames": 1, "feet": [64.0, 123.4], "scale": 1.6, "crop": [4, 46, 120, 184]},
	"tower_ember": {"frame": [128, 256], "frames": 1, "feet": [64.0, 123.4], "scale": 1.6, "crop": [4, 46, 120, 184]},
	"tower_red": {"frame": [128, 256], "frames": 1, "feet": [64.0, 123.4], "scale": 1.6, "crop": [4, 46, 120, 184]},
	"tower_black": {"frame": [128, 256], "frames": 1, "feet": [64.0, 123.4], "scale": 1.6, "crop": [4, 46, 120, 184]},
	"tower_yellow": {"frame": [128, 256], "frames": 1, "feet": [64.0, 123.4], "scale": 1.6, "crop": [4, 46, 120, 184]},
	"tower_purple": {"frame": [128, 256], "frames": 1, "feet": [64.0, 123.4], "scale": 1.6, "crop": [4, 46, 120, 184]},
	"tower_tree": {"frame": [192, 192], "frames": 8, "feet": [95.6, 91.6], "scale": 2.2, "fps": 6, "crop": [51, 24, 90, 146]},
	"tower_ruins": {"frame": [144, 189], "frames": 1, "feet": [71.5, 37.1], "scale": 1.4, "crop": [0, 0, 144, 189]},
	"tower_monastery": {"frame": [192, 320], "frames": 1, "feet": [96.0, 292.0], "scale": 1.1, "crop": [16, 45, 160, 265]},
}

## --- PORTRAITS (assets/cosmetics/avatars.png, grille) ---
const AVATAR_SHEET: String = "res://assets/cosmetics/avatars.png"
const AVATAR_CELL: int = 256
const AVATAR_COLS: int = 5
## Region utile commune a tous les portraits (union des boites opaques).
const AVATAR_CROP: Rect2i = Rect2i(22, 29, 197, 184)
## Le portrait PAR DEFAUT : la tete du mage, decoupee dans la planche du
## casting (UiTheme.mage_head), pas une case de AVATAR_SHEET. C est le visage de
## tout profil neuf (niveau 1) ; un portrait equipe le remplace. Hors de AVATARS
## parce que AVATARS decrit la GRILLE de la planche (une cle = une case).
const AVATAR_MAGE: String = "avatar_mage"
const AVATARS: Array[String] = ["avatar_warrior_red", "avatar_monk_blue", "avatar_pawn_blue", "avatar_knight_blue", "avatar_monk_red", "avatar_lancer_yellow", "avatar_monk_yellow", "avatar_knight_purple", "avatar_monk_purple", "avatar_monk_black"]

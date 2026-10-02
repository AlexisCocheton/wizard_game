class_name UiTheme
extends RefCounted
## Theme partage par tous les ecrans. Les fonds, boutons et panneaux sont les
## textures d UI de Tiny Swords (papier, boutons bleus/rouges, bois, bannieres).
## Le code ne dessine plus de rectangles : il decoupe et etire des textures.

const BG := Color(0.08, 0.06, 0.12)
const PANEL := Color(0.13, 0.10, 0.19)
const PANEL_LIGHT := Color(0.20, 0.16, 0.29)
const PANEL_HOVER := Color(0.26, 0.21, 0.37)
const GOLD := Color(0.95, 0.80, 0.35)
const TEAL := Color(0.35, 0.75, 0.72)
const TEXT := Color(0.96, 0.94, 0.90)
const TEXT_DARK := Color(0.28, 0.18, 0.10)
const TEXT_DIM := Color(0.62, 0.58, 0.70)
const RED := Color(0.85, 0.25, 0.28)
const BLUE := Color(0.35, 0.65, 0.95)
const GREEN := Color(0.40, 0.80, 0.45)

## TAILLES DE POLICE — remontees le 2026-09-21.
##
## Retour du testeur : "la police n est pas assez lisible en petit, augmente un
## peu la taille de toutes les ecritures". Le probleme n etait pas que la police
## soit petite dans l absolu (30 px sur 1920, c est correct) mais que le CONTOUR
## sombre de 6 px, pose pour rendre le HUD lisible sur un fond peint, ronge
## l interieur des lettres : a 24 px, le "e" de Planes_ValMore se bouche.
##
## Deux corrections ensemble, car separees elles ne suffisent pas :
##   - +6 px sur chaque palier (24->30, 30->36, 34->40, 52->60) ;
##   - contour ramene de 6 a 4 px dans le theme (voir make()), les ecrans de
##     MENU ayant un fond maitrise ; le HUD garde son contour epais via
##     label_hud(), la ou le fond est un decor peint.
##
## Juge sur capture : a 24 px les sous-titres des tuiles etaient des paves gris.
const FONT_BODY: int = 36
const FONT_BUTTON: int = 40
const FONT_TITLE: int = 60
const FONT_SMALL: int = 30

const UI := "res://assets/ui/"

## Police du jeu. Le projet tournait sur la police par defaut de Godot (Open Sans) :
## un caractere a traits FINS, concu pour du papier, qui se delave sur un fond
## peint des qu on descend sous 30 px. Retour du testeur : "les polices d ecriture
## ca ne va pas du tout, c est tres peu lisible".
##
## Planes_ValMore est la police du pack "free pixel magic sprite effects"
## (craftpix) : GRASSE par construction, hauteur d x elevee, formes de pixel art.
## Comparee cote a cote avec Silkscreen (l autre police des packs), elle gagne sur
## les deux points qui comptent ici : Silkscreen n a pas de vraies minuscules (elle
## rend des petites capitales) et ses traits font 1 px, donc elle est PIRE que
## l existant sur un fond charge.
##
## Le contenu du jeu est ecrit SANS ACCENTS (verifie sur les 44 cartes et les
## descriptions) : l absence de e-accent dans la fonte n a donc aucun effet.
const FONT_PATH := "res://assets/ui/planes_valmore.ttf"

## Chargee une seule fois : un FontFile porte son propre cache de rendu, en
## recreer un par label rendrait le cache inutile et multiplierait la memoire.
static var _font: FontFile = null


## La police du jeu, ou null si le fichier manque (on retombe alors sur la police
## par defaut de Godot plutot que d afficher un ecran vide).
static func font() -> Font:
	if _font == null and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile
	return _font

## Marges 9-tranches des textures recomposees (gauche, haut, droite, bas).
const NINE: Dictionary = {
	"banner9": [100, 68, 84, 111],
	"bar_base9": [24, 0, 24, 0],
	# Page du grimoire : bois a gauche/droite, reliure epaisse en bas. Mesure sur
	# les pixels creme de la planche (tools/assets/extract_book.py).
	"book_page9": [12, 6, 12, 22],
	"bar_fill9": [24, 0, 24, 0],
	# Meme barre, reteintee en or (tools/assets/make_gold_bar.py). Le pack ne
	# fournit qu une barre ROUGE — la couleur de la vie dans tout le reste du
	# jeu. Un modulate dore ne la sauve pas : multiplier du rouge par de l or
	# rend du rouge orange. Les 4 couleurs sont donc remplacees une a une, ce
	# qui garde l ombrage du pack. Reservee aux barres d AVANCEMENT (profil) ;
	# la vie et le combat gardent le rouge.
	"bar_fill_gold9": [24, 0, 24, 0],
	"btn_blue9": [45, 47, 45, 47],
	"btn_blue_pressed9": [50, 36, 50, 49],
	"btn_red9": [45, 47, 45, 47],
	"btn_red_pressed9": [50, 36, 50, 49],
	"btn_round_red9": [0, 0, 0, 0],
	"btn_small9": [0, 0, 0, 0],
	"btn_small_pressed9": [0, 0, 0, 0],
	"paper9": [52, 44, 52, 45],
	"paper_special9": [55, 44, 55, 43],
	"smallbar_base9": [15, 0, 15, 0],
	"smallbar_fill9": [15, 0, 15, 0],
	# Meme barre, reteintee en OR par remplacement exact
	# (tools/assets/make_gold_bar.py). Un modulate ne suffit PAS : multiplier
	# le rouge (255,62,62) par de l or (0.94,0.78,0.28) rend (240,48,17), du
	# rouge orange — mesure a l ecran. C est le meme piege que la barre de vie.
	"smallbar_fill_gold9": [15, 0, 15, 0],
	"wood9": [84, 85, 84, 103],
}


static func rarity_color(rarity: int) -> Color:
	match rarity:
		GameEnums.Rarity.COMMON: return Color(0.72, 0.72, 0.78)
		GameEnums.Rarity.RARE: return Color(0.40, 0.65, 0.95)
		GameEnums.Rarity.EPIC: return Color(0.70, 0.45, 0.95)
		GameEnums.Rarity.LEGENDARY: return GOLD
	return TEXT_DIM


## Plancher de contraste du projet pour du texte (WCAG AA, texte courant).
const CONTRAST_MIN: float = 4.5

## ENCRES DE RARETE, lisibles SUR LE PAPIER (plus sombres que rarity_color).
## Ce sont des CONSTANTES pour que les ecrans qui veulent la meme teinte hors de
## toute rarete (le bleu d une incantation, l or d un compteur) la NOMMENT au lieu
## de la recopier : une teinte recopiee ne suit pas la correction suivante. C est
## ce qui s est passe le 30/09 : l or legendaire corrige ici restait ecrit en dur
## a quatre endroits. L AUDIT (_check_rarity_colors) interdit desormais toute
## couleur de rarete ecrite en dur hors de ce fichier.
##
## LE PAPIER LE PLUS SOMBRE DECIDE. Une encre se lit sur trois papiers : le
## papier creme (briefing, victoire), la page du grimoire, et le papier d une
## carte en main ou en detail, TEINTE par rarity_bg de sa propre rarete — le
## plus sombre des trois. Mesures sur capture le 30/09, papier teinte : commune
## 3,96:1, rare 3,05:1, epique 3,36:1, legendaire 4,34:1, et la commune a 4,19:1
## sur la page du grimoire. Toutes sous le plancher de 4,5:1.
##
## Les quatre encres ont donc ete assombries SANS perdre ce qui les distingue :
## chacune garde la teinte de son contour (rarity_color), la commune reste la
## seule encre grise (saturation minimale), et l epaisseur du contour
## (rarity_border_width) porte la rarete meme sans la couleur. Verrouille par
## test_card_view.gd, qui lit les papiers dans les textures du jeu.
const INK_COMMON := Color(0.32, 0.32, 0.38)
## Bleu nuit : l ancien bleu (0.15, 0.38, 0.75) faisait 4,08:1 sur la page du
## grimoire et 3,05:1 sur le papier bleute d une carte rare en main.
const INK_RARE := Color(0.08, 0.26, 0.60)
const INK_EPIC := Color(0.36, 0.13, 0.58)
## Bronze : se lit encore comme de l or. L or d origine (0.62, 0.45, 0.05) ne
## faisait que 3,3:1 sur le papier creme.
const INK_LEGENDARY := Color(0.44, 0.31, 0.02)
## Encres RETIREES parce qu elles ne tenaient pas le contraste sur le papier.
## L AUDIT les interdit dans tout script et toute scene hors de ce fichier : les
## voir revenir voudrait dire qu un ecran a recopie une ancienne valeur au lieu
## de nommer l encre.
const RETIRED_INKS: Array[Color] = [
	Color(0.62, 0.45, 0.05),  # or legendaire d origine, 3,3:1 sur le creme
	Color(0.48, 0.34, 0.02),  # bronze legendaire, 4,34:1 en main
	Color(0.15, 0.38, 0.75),  # bleu rare, 4,08:1 sur la page du grimoire
	Color(0.38, 0.38, 0.44),  # gris commun, 3,96:1 en main, 4,19:1 sur le grimoire
	Color(0.48, 0.22, 0.72),  # violet epique, 3,36:1 en main
]


## Couleur de rarete lisible SUR LE PAPIER (plus sombre que rarity_color).
static func rarity_ink(rarity: int) -> Color:
	match rarity:
		GameEnums.Rarity.COMMON: return INK_COMMON
		GameEnums.Rarity.RARE: return INK_RARE
		GameEnums.Rarity.EPIC: return INK_EPIC
		GameEnums.Rarity.LEGENDARY: return INK_LEGENDARY
	return TEXT_DARK


## Contour de RARETE, a poser sur n importe quel panneau (carte, monstre, succes).
##
## Demande du testeur : "applique une couleur de contour claire a chaque rarete,
## pour toutes cartes, monstres ou defis". Jusqu ici la rarete ne se lisait que
## par la teinte du papier (`rarity_bg`), qui est PALE par construction : sur la
## capture du profil, rien ne distinguait un succes commun d un legendaire.
##
## Un contour resout cela sans toucher au fond : il encadre, donc il se voit meme
## quand l interieur du panneau est deja occupe par du texte. La largeur monte
## avec la rarete (4 -> 7 px) pour que le classement se lise aussi du coin de
## l oeil, sans lire la couleur.
##
## `fill` sert aux panneaux poses sur un fond sombre (le menu) ; laisse a
## TRANSPARENT, le contour se superpose a ce qui est deja dessine.
static func rarity_border(rarity: int, fill: Color = Color.TRANSPARENT,
		radius: int = 10, margin: float = 16.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.border_color = rarity_color(rarity)
	sb.set_border_width_all(rarity_border_width(rarity))
	return sb


## Epaisseur du contour par rarete. Separee pour que les ecrans qui dessinent
## leur propre cadre (la galerie du chantier C) puissent s y accorder.
static func rarity_border_width(rarity: int) -> int:
	match rarity:
		GameEnums.Rarity.COMMON: return 4
		GameEnums.Rarity.RARE: return 5
		GameEnums.Rarity.EPIC: return 6
		GameEnums.Rarity.LEGENDARY: return 7
	return 4


## --- BANNIERE DE TITRE selon le NIVEAU DE COMPTE ---
##
## Demande du testeur : "change le fond de la barre du dessus du menu, ou il y a
## le titre du jeu, en fonction du niveau du joueur". C est la recompense la plus
## visible du compte : elle se voit des l ouverture du jeu, sans ouvrir d ecran.
##
## Quatre paliers, materiaux de plus en plus precieux. Les variantes sont des
## reteintures de `ribbon_title9.png` fabriquees par tools/assets/make_cosmetics.py.
## Le suffixe `9` est obligatoire : l AUDIT prend pour une planche brute toute
## texture d UI qui ne le porte pas (piege documente).
const BANNER_TIERS: Array = [
	[1, "ribbon_title9"],           ## bois : le depart
	[4, "ribbon_title_silver9"],    ## argent
	[8, "ribbon_title_gold9"],      ## or
	[14, "ribbon_title_crystal9"],  ## cristal : le dernier palier, tenu pour toujours
]


## La banniere correspondant a un niveau de compte. Au-dela du dernier palier
## elle ne change plus : un joueur de niveau 40 garde le cristal, il ne retombe
## pas au bois par debordement de la liste.
static func banner_for_level(level: int) -> String:
	var choix: String = String(BANNER_TIERS[0][1])
	for tier: Array in BANNER_TIERS:
		if level >= int(tier[0]):
			choix = String(tier[1])
	return choix


## Le prochain palier de banniere, ou 0 si le dernier est atteint. Sert a dire au
## joueur ce qu il gagne au niveau suivant plutot que de le lui laisser deviner.
static func next_banner_level(level: int) -> int:
	for tier: Array in BANNER_TIERS:
		if level < int(tier[0]):
			return int(tier[0])
	return 0


## Teinte du papier de carte selon la rarete (modulation d une texture).
static func rarity_bg(rarity: int) -> Color:
	match rarity:
		GameEnums.Rarity.COMMON: return Color(0.92, 0.92, 0.95)
		GameEnums.Rarity.RARE: return Color(0.72, 0.84, 1.0)
		GameEnums.Rarity.EPIC: return Color(0.88, 0.76, 1.0)
		GameEnums.Rarity.LEGENDARY: return Color(1.0, 0.92, 0.62)
	return Color.WHITE


## --- APPARENCE DU PERSONNAGE (cosmetiques equipes) ---
##
## Depuis la vague 8, quatre couches qui se CUMULENT :
##   - le PERSONNAGE : le mage, ou un de ses apprentis (cle AnimCatalog) ;
##   - sa TENUE : une robe du mage (monk_*) ou une teinte de l apprenti
##     (bluewitch_ember...). Une feuille entiere, meme silhouette que l originale ;
##   - le CHAPEAU : un CALQUE dessine (assets/cosmetics/hats.png) pose sur le
##     sommet de la tete IMAGE PAR IMAGE (WardrobeData.HAT_ANCHORS, mesure par
##     tools/assets/make_wardrobe.py). Avant, chapeau et robe etaient deux
##     reteintures de la meme feuille : il fallait choisir l un OU l autre ;
##   - la TOUR sous ses pieds (WardrobeData.TOWERS).
##
## mage_view.gd ne lit que hero_*() et hat_*() : il ne sait pas qui il affiche.
## Ajouter un apprenti, une teinte, un chapeau ou une tour reste du CONTENU.
const MAGE_FRAME: int = 192
const MAGE_DEFAULT := "monk_blue"
## Region reellement occupee par le mage dans une case de MAGE_FRAME px.
## MESUREE sur la couche alpha des feuilles de robe : toutes rendent exactement
## (67, 65) -> (125, 134), ce qui confirme que ce sont des palettes echangees
## d une meme planche. On garde 1 px de marge de chaque cote pour ne pas raser
## le contour noir du sprite.
const MAGE_CROP := Rect2i(66, 64, 60, 71)

## Echelle et hauteur du mage d origine, reprises telles quelles de mage_view.gd :
## c est l etalon sur lequel chaque apprenti est aligne.
const MAGE_SCALE: float = 1.35
const MAGE_Y: float = -20.0

## L APPRENTI EST PLUS GROS QUE LE MAGE (demande du co-auteur, vague 8).
## Ramene a la hauteur du mage, il paraissait chetif sur sa tour : une sorciere
## de 48 px ou une fee de 32 px n a pas la masse d un moine de 192 px, meme a
## hauteur egale. 1,5 fois la hauteur du mage = 144 px a l ecran au lieu de 96.
## Les PIEDS restent ou sont ceux du mage : l agrandissement se fait vers le haut,
## donc loin de la main (en dessous) ; et la tour est au centre de l ecran, loin
## de la jauge (bord gauche). Verifie en capture de combat.
const APPRENTICE_SCALE: float = 1.5

## Mesures de silhouette deja faites (get_image() coute : on ne le fait qu une
## fois par feuille).
static var _visible_cache: Dictionary = {}
## Vignettes composees (robe + chapeau) deja calculees.
static var _preview_cache: Dictionary = {}


## La robe du mage, d apres le profil. Rend toujours une cle du catalogue : un
## mage sans feuille ne s afficherait pas.
static func mage_sheet_key() -> String:
	var robe: String = SaveData.equipped_cosmetic(GameEnums.RewardKind.MAGE_COLOR)
	return robe if AnimCatalog.has(StringName(robe)) else MAGE_DEFAULT


## Les animations du mage dans la robe equipee (le chapeau est un calque a part).
static func mage_frames() -> SpriteFrames:
	var sf: SpriteFrames = AnimCatalog.frames(StringName(mage_sheet_key()))
	if sf == null or not sf.has_animation("idle") or sf.get_frame_count("idle") == 0:
		return AnimCatalog.frames(&"monk_blue")
	return sf


## --- CHAPEAUX ---

## Le chapeau equipe, ou HAT_NONE. Une cle inconnue (chapeau retire du jeu) rend
## la tete nue plutot qu un calque vide.
static func hat_key() -> String:
	var k: String = SaveData.equipped_cosmetic(GameEnums.RewardKind.HAT)
	return k if WardrobeData.HATS.has(k) else AccountRewardDef.HAT_NONE


## Le gabarit de tete d une feuille ("monk"), ou "" si elle n en a pas.
static func hat_rig(sheet: String) -> String:
	return String(WardrobeData.HAT_RIGS.get(sheet, ""))


## La case d un chapeau dans l atlas, ou null.
static func hat_texture(key: String) -> Texture2D:
	var i: int = WardrobeData.HATS.find(key)
	if i < 0:
		return null
	var sheet: Texture2D = SheetLib.texture(WardrobeData.HAT_SHEET)
	if sheet == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(Vector2(i * WardrobeData.HAT_CELL.x, 0), Vector2(WardrobeData.HAT_CELL))
	return at


## Ou poser le PIVOT du chapeau dans le repere d un AnimatedSprite2D CENTRE qui
## joue `sheet`, a l image `frame` de `anim`. Vector2.INF si la feuille n a pas de
## gabarit de tete ou si l animation n a pas ete mesuree.
static func hat_offset(sheet: String, anim: StringName, frame: int) -> Vector2:
	var rig: String = hat_rig(sheet)
	if rig == "" or not WardrobeData.HAT_ANCHORS.has(rig):
		return Vector2.INF
	var pts: Array = (WardrobeData.HAT_ANCHORS[rig] as Dictionary).get(String(anim), [])
	if pts.is_empty():
		return Vector2.INF
	var p: Array = pts[clampi(frame, 0, pts.size() - 1)]
	var demi: float = float(WardrobeData.HAT_RIG_CELL.get(rig, MAGE_FRAME)) * 0.5
	return Vector2(float(p[0]) - demi, float(p[1]) - demi)


## Le chapeau que porte le personnage JOUE : celui du profil si sa feuille a un
## gabarit de tete, sinon aucun. Les apprentis portent deja un couvre-chef
## dessine (chapeau de sorciere, casque, fee) : le chapeau choisi est garde pour
## le mage, pas pose par-dessus.
static func hero_hat_key() -> String:
	var h: String = hat_key()
	if h == AccountRewardDef.HAT_NONE or hat_rig(hero_sheet_key()) == "":
		return AccountRewardDef.HAT_NONE
	return h


## --- VIGNETTES DE L ONGLET COSMETIQUES ---

## VIGNETTE d une piece de cosmetique DONNEE — pas de celle qui est equipee.
##
## L ecran de choix montre chaque piece de la grille ; sans image, le joueur
## choisirait "Robe d encre" sans voir la couleur. Rend null quand la feuille
## manque : l appelant retombe alors sur le texte seul.
##
## LE RECADRAGE COMPTE AUTANT QUE LA VIGNETTE : une case de 192 px ou le mage
## tient dans 58 donne un point au milieu du vide. Chaque vignette est donc
## recadree sur ce qu elle montre (MAGE_CROP, silhouette mesuree, chapeau).
static func cosmetic_preview(kind: int, texture_name: String) -> Texture2D:
	if texture_name == "":
		return null
	match kind:
		GameEnums.RewardKind.TOWER:
			return tower_preview(texture_name)
		GameEnums.RewardKind.MAGE_COLOR:
			if hat_rig(texture_name) != "":
				return _robe_preview(texture_name)
			return _apprentice_preview(texture_name)
		GameEnums.RewardKind.HAT:
			# Le chapeau SUR le mage tel qu il est habille : c est ce qu on verra.
			if texture_name != AccountRewardDef.HAT_NONE and hat_texture(texture_name) == null:
				return null
			return _dressed_preview(mage_sheet_key(), texture_name)
		GameEnums.RewardKind.CHARACTER:
			# Le mage se montre TEL QU IL EST HABILLE (robe et chapeau) ; un
			# apprenti dans la tenue qu il porte.
			if texture_name == AccountRewardDef.CHARACTER_MAGE:
				return _dressed_preview(mage_sheet_key(), hat_key())
			if not AnimCatalog.has(StringName(texture_name)):
				return null
			return _apprentice_preview(SaveData.equipped_outfit(texture_name))
		GameEnums.RewardKind.AVATAR:
			return avatar_texture(texture_name)
	return null


## La robe seule, premiere image d attente recadree sur le mage.
static func _robe_preview(sheet: String) -> Texture2D:
	var tex: Texture2D = SheetLib.texture("res://assets/units/%s_idle.png" % sheet)
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(MAGE_CROP.position, MAGE_CROP.size)
	return at


## Le mage dans `robe` coiffe de `hat`, en UNE texture : un Button n a qu une
## icone. Composee une fois par paire et gardee en cache.
##
## La composition lit les pixels (get_image) : possible en jeu et a l etage
## visual, pas toujours en headless. A defaut, on rend le chapeau seul (ou la
## robe pour la tete nue) — une vignette juste, a defaut d etre complete.
static func _dressed_preview(robe: String, hat: String) -> Texture2D:
	var base: Texture2D = _robe_preview(robe)
	if hat == AccountRewardDef.HAT_NONE or base == null:
		return base
	var cle: String = robe + "|" + hat
	if _preview_cache.has(cle):
		return _preview_cache[cle]
	var chapeau: Texture2D = hat_texture(hat)
	var corps_img: Image = _pixels((base as AtlasTexture).atlas)
	var chap_img: Image = _pixels(SheetLib.texture(WardrobeData.HAT_SHEET))
	var ancre: Vector2 = hat_offset(robe, &"idle", 0)
	if corps_img == null or chap_img == null or ancre == Vector2.INF:
		return chapeau
	var i: int = WardrobeData.HATS.find(hat)
	var case_chap := Rect2i(Vector2i(i * WardrobeData.HAT_CELL.x, 0), WardrobeData.HAT_CELL)
	var utile: Rect2i = chap_img.get_region(case_chap).get_used_rect()
	# Tout en px de la CASE du mage (0..192) : le chapeau y est pose a l ancre.
	var pivot_case: Vector2 = ancre + Vector2.ONE * MAGE_FRAME * 0.5
	var chap_pos := Vector2i((pivot_case - WardrobeData.HAT_PIVOT).round()) + utile.position
	var cadre := Rect2i(MAGE_CROP).merge(Rect2i(chap_pos, utile.size))
	var img := Image.create(cadre.size.x, cadre.size.y, false, Image.FORMAT_RGBA8)
	var corps_src := Rect2i(cadre.position, cadre.size).intersection(
		Rect2i(0, 0, MAGE_FRAME, MAGE_FRAME))
	img.blend_rect(corps_img, corps_src, corps_src.position - cadre.position)
	img.blend_rect(chap_img, Rect2i(case_chap.position + utile.position, utile.size),
		chap_pos - cadre.position)
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_preview_cache[cle] = tex
	return tex


## Les pixels d une texture en RGBA8, ou null si le moteur ne les rend pas.
static func _pixels(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## --- LE PERSONNAGE EN COMBAT : le mage ou un de ses apprentis ---
##
## mage_view.gd ne lit que ces fonctions : il ne sait pas qui il affiche. C est
## ce qui rend un apprenti purement DECLARATIF — une recompense CHARACTER et une
## cle d AnimCatalog suffisent, la taille, la hauteur des pieds et la pose
## d incantation se deduisent de la feuille.

## La cle reellement jouee : celle du profil, SAUF si sa feuille ne donne pas de
## pose d attente — un personnage invisible est pire que le retour au mage.
static func hero_key() -> String:
	var key: String = SaveData.equipped_character()
	if key == AccountRewardDef.CHARACTER_MAGE:
		return key
	var sf: SpriteFrames = AnimCatalog.frames(StringName(key))
	if sf == null or not sf.has_animation(&"idle") or sf.get_frame_count(&"idle") == 0:
		return AccountRewardDef.CHARACTER_MAGE
	return key


static func hero_is_apprentice() -> bool:
	return hero_key() != AccountRewardDef.CHARACTER_MAGE


## La FEUILLE jouee : la robe du mage, ou la tenue de l apprenti (sa teinte, ou
## sa feuille d origine si la teinte manque de pose d attente).
static func hero_sheet_key() -> String:
	var key: String = hero_key()
	if key == AccountRewardDef.CHARACTER_MAGE:
		return mage_sheet_key()
	var tenue: String = SaveData.equipped_outfit(key)
	var sf: SpriteFrames = AnimCatalog.frames(StringName(tenue))
	if sf == null or not sf.has_animation(&"idle") or sf.get_frame_count(&"idle") == 0:
		return key
	return tenue


## Les animations du personnage joue, dans sa tenue.
static func hero_frames() -> SpriteFrames:
	if not hero_is_apprentice():
		return mage_frames()
	return AnimCatalog.frames(StringName(hero_sheet_key()))


## La pose d incantation. Le mage a une feuille "cast" ; les apprentis du disque
## n ont qu une "attack" (charge de la sorciere, arc de l ecuyer, vol de la fee).
## A defaut, l attente : mieux vaut un personnage immobile qu une animation absente.
static func hero_cast_anim(sf: SpriteFrames) -> StringName:
	for a: StringName in [&"cast", &"attack"]:
		if sf != null and sf.has_animation(a) and sf.get_frame_count(a) > 0:
			return a
	return &"idle"


## Ou tombent les PIEDS du mage, sous la position du noeud MageView : bas de sa
## silhouette (MAGE_CROP) moins la demi-case, a son echelle. C est la ligne sur
## laquelle se posent les apprentis ET les tours.
static func hero_feet_y() -> float:
	return MAGE_Y + (float(MAGE_CROP.end.y) - MAGE_FRAME * 0.5) * MAGE_SCALE


## Echelle et position du sprite : le mage tel quel ; un apprenti a
## APPRENTICE_SCALE fois la HAUTEUR du mage a l ecran, PIEDS au meme endroit.
##
## POURQUOI PAS UN SIMPLE RAPPORT DE CASES. La case du mage fait 192 px et il en
## occupe 71 de haut ; celle de la sorciere bleue fait 48 px et elle en occupe
## une quarantaine. Reprendre l echelle du mage donnerait une apprentie deux fois
## plus petite que lui. L occupation du catalogue ne suffit pas non plus : elle
## est mesuree sur la plus grande dimension de la MARCHE, qui chez le mage est sa
## largeur (83 px, les bras qui balancent). On compare donc les hauteurs
## reellement opaques de la pose d attente.
static func hero_pose(key: String = "") -> Dictionary:
	if key == "":
		key = hero_key()
	if key == AccountRewardDef.CHARACTER_MAGE:
		return {"scale": MAGE_SCALE, "y": MAGE_Y}
	var etalon := Rect2(MAGE_CROP)
	var r: Rect2 = hero_visible_rect(key)
	if r.size.y <= 0.0:
		return {"scale": MAGE_SCALE, "y": MAGE_Y}
	var s: float = MAGE_SCALE * etalon.size.y / r.size.y * APPRENTICE_SCALE
	# Le sprite est centre sur sa case : les pieds tombent a (bas de la
	# silhouette - demi-case) * echelle sous la position du sprite.
	var demi_case: float = AnimCatalog.frame_px(StringName(key)) * 0.5
	return {"scale": s, "y": hero_feet_y() - (r.end.y - demi_case) * s}


## Region opaque de la premiere image d attente, en pixels DE LA CASE.
##
## Mesuree sur l image quand le moteur la rend (jeu, etage visual). En headless
## get_image() peut ne rien rendre : on retombe sur un carre centre de la part
## occupee (AnimCatalog.occupancy), ce qui garde des proportions justes pour les
## tests sans rien afficher de faux a l ecran.
static func hero_visible_rect(key: String) -> Rect2:
	if key == AccountRewardDef.CHARACTER_MAGE:
		return Rect2(MAGE_CROP)
	if _visible_cache.has(key):
		return _visible_cache[key]
	var cell: float = float(AnimCatalog.frame_px(StringName(key)))
	var side: float = cell * clampf(AnimCatalog.occupancy(StringName(key)), 0.05, 1.0)
	var r := Rect2(Vector2.ONE * (cell - side) * 0.5, Vector2.ONE * side)
	var frame: Texture2D = _hero_idle_frame(key)
	if frame != null:
		var img: Image = frame.get_image()
		if img != null and not img.is_empty():
			var used: Rect2i = img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				r = Rect2(used)
	_visible_cache[key] = r
	return r


static func _hero_idle_frame(key: String) -> Texture2D:
	var sf: SpriteFrames = AnimCatalog.frames(StringName(key))
	if sf == null or not sf.has_animation(&"idle") or sf.get_frame_count(&"idle") == 0:
		return null
	return sf.get_frame_texture(&"idle", 0)


## Vignette d un apprenti (ou d une de ses teintes) : sa premiere image d attente
## RECADREE sur la silhouette. L atlas reste la feuille d origine, aucune texture
## n est creee.
static func _apprentice_preview(key: String) -> Texture2D:
	var frame: AtlasTexture = _hero_idle_frame(key) as AtlasTexture
	if frame == null:
		return null
	var r: Rect2 = hero_visible_rect(key)
	var at := AtlasTexture.new()
	at.atlas = frame.atlas
	at.region = Rect2(frame.region.position + r.position, r.size)
	return at


## --- TOURS ---

## La tour equipee, avec repli sur celle d origine (cle inconnue, tour retiree).
static func tower_key() -> String:
	var key: String = SaveData.equipped_cosmetic(GameEnums.RewardKind.TOWER)
	return key if WardrobeData.TOWERS.has(key) else "tower_blue"


## Geometrie d une tour : {"frame": [w, h], "frames": n, "feet": [x, y], "scale"}.
static func tower_spec(key: String = "") -> Dictionary:
	if key == "":
		key = tower_key()
	return WardrobeData.TOWERS.get(key, WardrobeData.TOWERS["tower_blue"])


## La FEUILLE de la tour (une bande pour l arbre qui se balance).
static func tower_texture(key: String = "") -> Texture2D:
	if key == "":
		key = tower_key()
	var t: Texture2D = SheetLib.texture("res://assets/terrain/%s.png" % key)
	return t if t != null else SheetLib.texture("res://assets/terrain/tower_blue.png")


## Les animations d une tour animee (l arbre), ou null pour une tour fixe.
static func tower_frames(key: String = "") -> SpriteFrames:
	if key == "":
		key = tower_key()
	var spec: Dictionary = tower_spec(key)
	if int(spec.get("frames", 1)) <= 1:
		return null
	var taille: Array = spec["frame"]
	return SheetLib.frames("tower:" + key, {"sway": {
		"path": "res://assets/terrain/%s.png" % key,
		"frame": int(taille[0]), "frame_h": int(taille[1]),
		"fps": float(spec.get("fps", 6)), "loop": true}})


## Vignette d une tour : la premiere case RECADREE sur ses pixels opaques
## (spec "crop", mesure a l extraction). Une tour de 128x256 n en occupe que
## 120x184 : la case entiere donnait une tour minuscule dans son bouton.
static func tower_preview(key: String) -> Texture2D:
	if not WardrobeData.TOWERS.has(key):
		return null
	var tex: Texture2D = SheetLib.texture("res://assets/terrain/%s.png" % key)
	if tex == null:
		return null
	var spec: Dictionary = tower_spec(key)
	var c: Array = spec.get("crop", [0, 0, spec["frame"][0], spec["frame"][1]])
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	return at


## --- PORTRAITS ---

## Le portrait equipe (WardrobeData.AVATARS), avec repli sur le premier.
static func avatar_key() -> String:
	var key: String = SaveData.equipped_cosmetic(GameEnums.RewardKind.AVATAR)
	return key if WardrobeData.AVATARS.has(key) else WardrobeData.AVATARS[0]


## Le portrait du profil, a afficher sur la carte d identite et le bouton PROFIL.
## Sans argument : celui que le joueur a choisi.
static func avatar_texture(key: String = "") -> Texture2D:
	if key == "":
		key = avatar_key()
	var i: int = WardrobeData.AVATARS.find(key)
	if i < 0:
		return null
	var sheet: Texture2D = SheetLib.texture(WardrobeData.AVATAR_SHEET)
	if sheet == null:
		return null
	var c: int = WardrobeData.AVATAR_CELL
	var at := AtlasTexture.new()
	at.atlas = sheet
	var ligne: int = floori(float(i) / float(WardrobeData.AVATAR_COLS))
	# Recadre sur la region utile COMMUNE (mesuree) : les portraits n occupent
	# que ~150 px de leur case de 256, la meme taille de tete pour tous.
	var utile: Rect2i = WardrobeData.AVATAR_CROP
	at.region = Rect2(Vector2((i % WardrobeData.AVATAR_COLS) * c, ligne * c) + Vector2(utile.position),
		Vector2(utile.size))
	return at


static func tex(name: String) -> Texture2D:
	return SheetLib.texture(UI + name + ".png")


## Boite 9-tranches a partir d une texture du pack.
static func tex_box(name: String, _margin: int = 48, content: float = 18.0,
		tint: Color = Color.WHITE) -> StyleBox:
	# On utilise la version recomposee (<nom>9.png) et ses marges mesurees.
	var key: String = name + "9" if NINE.has(name + "9") else name
	var t: Texture2D = tex(key)
	if t == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PANEL_LIGHT
		return sb
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var m: Array = NINE.get(key, [0, 0, 0, 0])
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.set_content_margin_all(content)
	sb.modulate_color = tint
	return sb


## Page du grimoire (onglet Galerie), en 9-tranches.
##
## Marges internes calees sur le DESSIN de la page : le bois de la reliure fait
## une trentaine de pixels une fois la planche etiree a la largeur de l ecran.
## En dessous, les vignettes de bord chevauchent le cadre ; bien au-dessus, on
## gaspille la largeur, qui est la ressource rare d un ecran portrait.
static func book_page_box() -> StyleBox:
	var t: Texture2D = tex("book_page9")
	if t == null:
		# Repli : le papier deja present. Un panneau sans fond laisserait le
		# texte sombre sur le bois sombre du menu, donc illisible.
		return tex_box("paper", 44, 26.0)
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var m: Array = NINE.get("book_page9", [12, 6, 12, 22])
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = 42.0
	sb.content_margin_right = 42.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 44.0
	return sb


## Conserve pour les fonds discrets (ombres) — pas de forme visible.
static func flat_box(color: Color, radius: int = 18, margin: float = 16.0,
		border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border_width > 0:
		sb.set_border_width_all(border_width)
		sb.border_color = border
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY

	# La police s applique au THEME, donc a tous les Control sous le theme d un
	# coup : c est le seul reglage qui touche aussi les boutons, les curseurs et
	# les panneaux des autres agents sans y toucher fichier par fichier.
	var f: Font = font()
	if f != null:
		t.default_font = f
		for cls in [&"Label", &"Button", &"CheckButton", &"LineEdit", &"RichTextLabel", &"OptionButton"]:
			t.set_font(&"font", cls, f)

	t.set_font_size(&"font_size", &"Label", FONT_BODY)
	t.set_color(&"font_color", &"Label", TEXT)
	# Contour sombre : le HUD ecrit par-dessus un fond PEINT (ciel, cimetiere,
	# salle du trone). Sans contour, un texte clair disparait sur une zone claire
	# et un texte sombre sur une zone sombre — quelle que soit sa taille. Deux
	# pixels d ombre garantissent le contraste partout.
	t.set_color(&"font_outline_color", &"Label", Color(0.04, 0.03, 0.06, 0.85))
	# 4 px et non 6 : un contour de 6 px sur une lettre de 30 px bouche les
	# contre-formes (le o, le e) et rend le texte PIRE, pas meilleur. Le HUD,
	# qui ecrit sur un fond peint, garde 8 px via label_hud().
	t.set_constant(&"outline_size", &"Label", 4)

	t.set_font_size(&"font_size", &"Button", FONT_BUTTON)
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_outline_color", &"Button", Color(0.04, 0.03, 0.06, 0.85))
	t.set_constant(&"outline_size", &"Button", 4)
	t.set_color(&"font_hover_color", &"Button", GOLD)
	t.set_color(&"font_pressed_color", &"Button", GOLD)
	t.set_color(&"font_disabled_color", &"Button", TEXT_DIM)
	t.set_stylebox(&"normal", &"Button", tex_box("btn_blue", 40, 20.0))
	t.set_stylebox(&"hover", &"Button", tex_box("btn_blue", 40, 20.0, Color(1.1, 1.1, 1.1)))
	t.set_stylebox(&"pressed", &"Button", tex_box("btn_blue_pressed", 40, 20.0))
	t.set_stylebox(&"disabled", &"Button", tex_box("btn_blue", 40, 20.0, Color(0.55, 0.55, 0.6)))
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())

	# Panneaux : papier du pack, texte sombre dessus.
	t.set_stylebox(&"panel", &"PanelContainer", tex_box("paper", 44, 26.0))

	t.set_font_size(&"font_size", &"CheckButton", FONT_BODY)
	t.set_color(&"font_color", &"CheckButton", TEXT)

	# Barres : base et remplissage recomposes du pack.
	t.set_stylebox(&"background", &"ProgressBar", tex_box("bar_base", 0, 0.0))
	t.set_stylebox(&"fill", &"ProgressBar", tex_box("bar_fill_gold", 0, 0.0))

	# Curseurs : petite barre du pack en rail, remplissage en zone parcourue,
	# bouton rond rouge reduit en poignee.
	t.set_stylebox(&"slider", &"HSlider", tex_box("smallbar_base", 0, 10.0))
	# OR et non rouge. `smallbar_fill9` est un aplat ROUGE uni — la couleur de la
	# VIE dans tout le reste du jeu — et les curseurs de volume s affichaient
	# donc comme des barres de vie. Ici une simple teinte suffit, contrairement
	# a la barre d avancement du profil : cette texture n a pas d ombrage a
	# preserver, une seule couleur la remplit (verifie, 1 seule valeur de pixel).
	t.set_stylebox(&"grabber_area", &"HSlider", slider_fill(Color.WHITE))
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", slider_fill(Color(1.12, 1.08, 0.95)))
	var knob: Texture2D = scaled_tex("btn_round_red9", 52)
	if knob != null:
		t.set_icon(&"grabber", &"HSlider", knob)
		t.set_icon(&"grabber_highlight", &"HSlider", scaled_tex("btn_round_red9", 58))
		t.set_icon(&"grabber_disabled", &"HSlider", knob)
	return t


## Zone parcourue d un curseur : la bande coloree de la petite barre du pack, etiree
## sur la hauteur du rail (la feuille de remplissage ne fait que 3 px de haut).
static func slider_fill(tint: Color) -> StyleBox:
	# La planche DOREE : la version d origine est un aplat rouge, la couleur de
	# la vie, et les curseurs de volume se lisaient comme des barres de vie.
	var t: Texture2D = tex("smallbar_fill_gold9")
	if t == null:
		t = tex("smallbar_fill9")
	if t == null:
		return flat_box(RED, 4, 0.0)
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.region_rect = Rect2(15, 8, 64, 3)
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.modulate_color = tint
	return sb


## Copie reduite d une texture du pack (poignees, petites icones), filtre nearest.
static func scaled_tex(name: String, height: int) -> Texture2D:
	var t: Texture2D = tex(name)
	if t == null:
		return null
	var img: Image = t.get_image()
	if img == null:
		return t
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	var w: int = maxi(1, int(round(float(img.get_width()) * float(height) / float(img.get_height()))))
	img.resize(w, height, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Bouton d action principal (JOUER) : le gros bouton rouge du pack.
static func style_primary(b: Button) -> void:
	b.add_theme_stylebox_override(&"normal", tex_box("btn_red", 40, 22.0))
	b.add_theme_stylebox_override(&"hover", tex_box("btn_red", 40, 22.0, Color(1.1, 1.1, 1.1)))
	b.add_theme_stylebox_override(&"pressed", tex_box("btn_red_pressed", 40, 22.0))
	b.add_theme_stylebox_override(&"disabled", tex_box("btn_red", 40, 22.0, Color(0.5, 0.5, 0.55)))
	b.add_theme_color_override(&"font_color", TEXT)
	b.add_theme_font_size_override(&"font_size", 44)


## Panneau papier, teinte optionnelle (cartes par rarete).
##
## `special` employait la planche `paper_special`, qui est un papier SOMBRE
## (82,91,102 au centre). Teintee en or pour une legendaire, elle donnait un brun
## olive tres fonce sur lequel l encre sombre des cartes devenait invisible : sur
## la capture a 8 cartes, les legendaires etaient les seules illisibles.
##
## La legendaire garde donc le papier CLAIR et son identite passe par la teinte
## doree, deja portee par rarity_bg. La planche sombre reste disponible pour un
## panneau a texte clair, ou elle fonctionne.
static func style_paper(c: Control, tint: Color = Color.WHITE, dark: bool = false) -> void:
	c.add_theme_stylebox_override(&"panel", tex_box("paper_special" if dark else "paper", 44, 22.0, tint))


## Un Label du jeu. `wrap = false` coupe l autowrap : dans une colonne etroite,
## AUTOWRAP_WORD_SMART replie un mot LETTRE PAR LETTRE, ce qui est le defaut le
## plus visible de l ancienne main de cartes ("Double incantatio / n").
static func label(text: String, size: int = FONT_BODY, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	var f: Font = font()
	if f != null:
		l.add_theme_font_override(&"font", f)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


## Label lisible SUR LE CHAMP DE BATAILLE : meme texte, plus un contour sombre.
## A utiliser des que le fond derriere le texte n est pas maitrise.
static func label_hud(text: String, size: int = FONT_BODY, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var l: Label = label(text, size, color, align, wrap)
	l.add_theme_color_override(&"font_outline_color", Color(0.04, 0.03, 0.06, 0.9))
	l.add_theme_constant_override(&"outline_size", 8)
	return l


## Icone du pack (icon_01..icon_12).
static func icon(index: int, size: float = 48.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex("icon_%02d" % index)
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# --- Planche du CASTING (portraits peints) ---
#
# Le decoupage vivait dans story_scene.gd seule. Le menu (onglet PROFIL) et la
# carte d identite du profil montrent maintenant la TETE DU MAGE : trois
# endroits qui decoupent la meme planche avec trois copies de l arithmetique
# auraient fini par viser trois cases differentes. Une seule fonction ici.

const PORTRAITS_DIR := "res://assets/portraits/"
const CAST_SHEET := PORTRAITS_DIR + "story_cast.png"
## Cote d une case de la planche, en px. La planche est generee hors jeu : chaque
## personnage y est detoure puis mis a l echelle dans une case carree identique.
const CAST_PX: int = 512
## La case du mage dans la planche ([ligne, colonne], a partir de 1).
const MAGE_CAST_CELL: Array[int] = [1, 1]
## La TETE du mage DANS sa case, en px de la case. Mesuree sur la planche : le
## crane commence vers y = 22, la barbe finit vers y = 330, le visage et le col
## tiennent entre x = 96 et x = 416. Le BUSTE entier (la case) ne laisse a 100 px
## qu un visage de 40 px perdu au-dessus d une cape violette : a la taille d un
## onglet, on ne reconnaissait plus un personnage mais une tache. Carre, pour
## qu aucun conteneur ne le deforme.
const MAGE_HEAD_CROP := Rect2(96, 8, 320, 320)


## Une case de la planche du casting, ou un morceau de case (`sub`, en px de la
## case). Null si la planche manque ou si la case sort de la planche : un
## rectangle vide a l ecran se lirait comme « pas de portrait » alors que c est
## une faute de frappe dans une table, on prefere que l appelant le sache.
static func cast_cell(row: int, col: int, sub: Rect2 = Rect2(),
		sheet: String = CAST_SHEET) -> Texture2D:
	if sheet == "" or not ResourceLoader.exists(sheet):
		return null
	var planche: Texture2D = load(sheet)
	if planche == null:
		return null
	var ligne: int = row - 1
	var colonne: int = col - 1
	if ligne < 0 or colonne < 0:
		return null
	if (colonne + 1) * CAST_PX > planche.get_width():
		return null
	if (ligne + 1) * CAST_PX > planche.get_height():
		return null
	var region := Rect2(colonne * CAST_PX, ligne * CAST_PX, CAST_PX, CAST_PX)
	if sub.has_area():
		# Le morceau reste DANS sa case : deborder montrerait le voisin.
		var dans: Rect2 = Rect2(Vector2.ZERO, Vector2(CAST_PX, CAST_PX)).intersection(sub)
		if not dans.has_area():
			return null
		region = Rect2(region.position + dans.position, dans.size)
	var at := AtlasTexture.new()
	at.atlas = planche
	at.region = region
	return at


## La tete du mage, lisible a la taille d un onglet ou d un bouton.
static func mage_head() -> Texture2D:
	return cast_cell(MAGE_CAST_CELL[0], MAGE_CAST_CELL[1], MAGE_HEAD_CROP)

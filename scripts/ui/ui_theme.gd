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
	"wood9": [84, 85, 84, 103],
}


static func rarity_color(rarity: int) -> Color:
	match rarity:
		GameEnums.Rarity.COMMON: return Color(0.72, 0.72, 0.78)
		GameEnums.Rarity.RARE: return Color(0.40, 0.65, 0.95)
		GameEnums.Rarity.EPIC: return Color(0.70, 0.45, 0.95)
		GameEnums.Rarity.LEGENDARY: return GOLD
	return TEXT_DIM


## Couleur de rarete lisible SUR LE PAPIER (plus sombre que rarity_color).
static func rarity_ink(rarity: int) -> Color:
	match rarity:
		GameEnums.Rarity.COMMON: return Color(0.38, 0.38, 0.44)
		GameEnums.Rarity.RARE: return Color(0.15, 0.38, 0.75)
		GameEnums.Rarity.EPIC: return Color(0.48, 0.22, 0.72)
		GameEnums.Rarity.LEGENDARY: return Color(0.62, 0.45, 0.05)
	return TEXT_DARK


## Teinte du papier de carte selon la rarete (modulation d une texture).
static func rarity_bg(rarity: int) -> Color:
	match rarity:
		GameEnums.Rarity.COMMON: return Color(0.92, 0.92, 0.95)
		GameEnums.Rarity.RARE: return Color(0.72, 0.84, 1.0)
		GameEnums.Rarity.EPIC: return Color(0.88, 0.76, 1.0)
		GameEnums.Rarity.LEGENDARY: return Color(1.0, 0.92, 0.62)
	return Color.WHITE


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
	t.set_stylebox(&"fill", &"ProgressBar", tex_box("bar_fill", 0, 0.0, Color(0.95, 0.80, 0.35)))

	# Curseurs : petite barre du pack en rail, remplissage en zone parcourue,
	# bouton rond rouge reduit en poignee.
	t.set_stylebox(&"slider", &"HSlider", tex_box("smallbar_base", 0, 10.0))
	t.set_stylebox(&"grabber_area", &"HSlider", slider_fill(Color.WHITE))
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", slider_fill(Color(1.15, 1.15, 1.0)))
	var knob: Texture2D = scaled_tex("btn_round_red9", 52)
	if knob != null:
		t.set_icon(&"grabber", &"HSlider", knob)
		t.set_icon(&"grabber_highlight", &"HSlider", scaled_tex("btn_round_red9", 58))
		t.set_icon(&"grabber_disabled", &"HSlider", knob)
	return t


## Zone parcourue d un curseur : la bande coloree de la petite barre du pack, etiree
## sur la hauteur du rail (la feuille de remplissage ne fait que 3 px de haut).
static func slider_fill(tint: Color) -> StyleBox:
	var t: Texture2D = tex("smallbar_fill9")
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

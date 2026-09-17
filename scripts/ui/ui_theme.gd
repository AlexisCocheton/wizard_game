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

const FONT_BODY: int = 30
const FONT_BUTTON: int = 34
const FONT_TITLE: int = 52
const FONT_SMALL: int = 24

const UI := "res://assets/ui/"

## Marges 9-tranches des textures recomposees (gauche, haut, droite, bas).
const NINE: Dictionary = {
	"banner9": [100, 68, 84, 111],
	"bar_base9": [24, 0, 24, 0],
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

	t.set_font_size(&"font_size", &"Label", FONT_BODY)
	t.set_color(&"font_color", &"Label", TEXT)

	t.set_font_size(&"font_size", &"Button", FONT_BUTTON)
	t.set_color(&"font_color", &"Button", TEXT)
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

	# Barres : base et remplissage du pack.
	var under: Texture2D = tex("bar_base")
	if under != null:
		var sb_bg := StyleBoxTexture.new()
		sb_bg.texture = under
		sb_bg.set_texture_margin_all(20)
		t.set_stylebox(&"background", &"ProgressBar", sb_bg)
		var sb_fill := StyleBoxTexture.new()
		sb_fill.texture = tex("bar_fill")
		sb_fill.set_texture_margin_all(20)
		sb_fill.set_content_margin_all(0.0)
		sb_fill.modulate_color = Color(0.95, 0.80, 0.35)
		t.set_stylebox(&"fill", &"ProgressBar", sb_fill)
	return t


## Bouton d action principal (JOUER) : le gros bouton rouge du pack.
static func style_primary(b: Button) -> void:
	b.add_theme_stylebox_override(&"normal", tex_box("btn_red", 40, 22.0))
	b.add_theme_stylebox_override(&"hover", tex_box("btn_red", 40, 22.0, Color(1.1, 1.1, 1.1)))
	b.add_theme_stylebox_override(&"pressed", tex_box("btn_red_pressed", 40, 22.0))
	b.add_theme_stylebox_override(&"disabled", tex_box("btn_red", 40, 22.0, Color(0.5, 0.5, 0.55)))
	b.add_theme_color_override(&"font_color", TEXT)
	b.add_theme_font_size_override(&"font_size", 44)


## Panneau papier, teinte optionnelle (cartes par rarete).
static func style_paper(c: Control, tint: Color = Color.WHITE, special: bool = false) -> void:
	c.add_theme_stylebox_override(&"panel", tex_box("paper_special" if special else "paper", 44, 22.0, tint))


static func label(text: String, size: int = FONT_BODY, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

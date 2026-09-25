extends Control
## Scene de visual novel : un fond, deux portraits, une boite de texte papier.
##
## POURQUOI un seul ecran pour toute l histoire : les scenes sont du CONTENU
## (`DialogueDef` dans `resources/story/`), pas des scripts. Cet ecran ne sait
## rien de l histoire, il sait seulement afficher une replique et passer a la
## suivante. Ajouter un acte n ajoute pas une ligne ici.
##
## POURQUOI il ne decide pas de la suite : c est `SceneRouter` qui enchaine les
## scenes puis reprend la route (briefing ou ecran de victoire). Cet ecran lui
## dit seulement "j ai fini".
##
## Lisibilite mobile (1080x1920, portrait) :
## - texte SOMBRE sur la boite papier : un texte clair sur papier clair etait
##   illisible en plein soleil, c est la raison de `UiTheme.TEXT_DARK` ;
## - AUTOWRAP_WORD_SMART sur la replique seulement. Le nom du locuteur ne doit
##   JAMAIS se couper sur deux lignes : la boite du nom grandirait a chaque
##   replique longue et le texte sauterait (gotcha verifie sur le briefing).

const BACKDROPS: String = "res://assets/backdrops/"
const PORTRAITS: String = "res://assets/portraits/"
## Le personnage qui parle est en pleine lumiere, l autre recule dans l ombre.
const DIM: Color = Color(0.45, 0.42, 0.52)

## Le pack fournit AUSSI les 32 visages en gros plan, ranges par
## `extract_portraits.py` dans une grille unique : 8 lignes (un personnage) x 4
## colonnes (une expression). Ils n avaient jamais ete branches.
##
## POURQUOI LE VISAGE PLUTOT QUE LE CORPS ENTIER. Compare a la taille reelle
## d affichage (620 x 960 px) : le corps entier montre des PATTES D ARAIGNEE et
## un visage de 40 px perdu tout en haut — c est ce qui faisait dire que "le mage
## est un demon cornu". Le meme personnage en gros plan remplit le cadre, son
## expression se lit, et les pattes sortent du champ. La tete de 64 px agrandie
## ~10x reste NETTE en pixel art, la ou un filtrage lisse l aurait floutee
## (le projet est en filtre "nearest", verifie en capture).
const HEADS: String = PORTRAITS + "demon_heads.png"
const HEAD_PX: int = 64
const HEAD_COLS: int = 4

## Cle de portrait -> [personnage 1..8, expression 1..4] dans la grille.
## Meme casting que FACES ci-dessous, et il doit le RESTER : les deux tables
## decrivent les memes personnages, l une en gros plan, l autre en repli.
## LES QUATRE EXPRESSIONS DU PACK, verifiees sur planche : 1 neutre, 2 colere,
## 3 grand sourire, 4 sourire leger. Le casting les suit — la premiere capture
## montrait le mage SOURIANT LARGEMENT en disant "je n ai pas su les arreter",
## ce qui rendait la scene absurde. Une expression qui contredit la replique est
## pire que pas de portrait du tout.
const HEAD_FACES: Dictionary = {
	&"mage": [6, 1],          # neutre : il raconte, il ne joue pas
	&"mage_grave": [6, 2],    # colere : les moments ou il s en veut
	&"child": [5, 4],         # sourire leger : un enfant, pas un rictus
	&"child_god": [5, 2],     # colere : le retournement de l acte V
	&"rat": [3, 1],
	&"mayor": [2, 1],
	&"skeleton_king": [7, 2], # colere : un roi mort qui ordonne
	&"guardian": [8, 2],      # colere : il se bat
	&"demon": [4, 2],         # colere : c est un demon
}

## Cles de portrait -> fichier. Les personnages du pack craftpix "demons" servent
## de bustes de PNJ : ce sont les seuls corps entiers humanoides disponibles
## (voir assets.md). Un personnage garde TOUJOURS le meme corps et sa palette
## d expressions (_1 neutre .. _4 marquee) : c est ce qui le rend reconnaissable
## alors qu aucun n a ete dessine pour lui.
##
## Casting : le mage sur demon6 — silhouette maigre, crane nu, robe bleue, bras
## croises : le seul du pack qui lit comme un vieil homme use, ce que le prologue
## demande. Le maire en robe et lance (demon2, le plus "notable"), le rat pilote
## en fourrure (demon3, le seul velu), le roi squelette en cape et flamme (demon7,
## le seul couronne), le Gardien (demon8), l enfant sur demon5, le plus maigre.
const FACES: Dictionary = {
	&"mage": PORTRAITS + "demon6_1.png",
	&"mage_grave": PORTRAITS + "demon6_3.png",
	&"child": PORTRAITS + "demon5_1.png",
	&"child_god": PORTRAITS + "demon5_4.png",
	&"rat": PORTRAITS + "demon3_1.png",
	&"mayor": PORTRAITS + "demon2_1.png",
	&"skeleton_king": PORTRAITS + "demon7_1.png",
	&"guardian": PORTRAITS + "demon8_1.png",
	&"demon": PORTRAITS + "demon4_1.png",
}

## Portraits pris sur une FEUILLE animee du jeu plutot que sur un fichier.
## POURQUOI : un monstre qui parle doit etre EXACTEMENT celui qu on vient de
## combattre, sinon la scene parle d un autre. Le pack de portraits ne contient
## aucun monstre, mais le jeu a deja leurs feuilles. On y decoupe la premiere case
## d "idle" — pas une pose de plus a dessiner ni a maintenir.
## Le mage, lui, reste sur un portrait dessine : sa feuille de combat est une vue
## de DESSUS, illisible en buste. REVERIFIE le 21 septembre sur les sept feuilles
## de cosmetique ajoutees depuis (monk_blue/black/purple et les quatre chapeaux) :
## toutes montrent le SOMMET du chapeau et aucun visage. Aucune ne peut donc
## remplacer le portrait, et le mage reste un demon cornu dans les scenes tant
## qu un vrai buste humain n est pas sur le disque.
const SHEET_FACES: Dictionary = {
	&"guardian_beast": &"chaosknight",
}

@onready var _backdrop: TextureRect = %Backdrop
@onready var _left: TextureRect = %PortraitLeft
@onready var _right: TextureRect = %PortraitRight
@onready var _box: PanelContainer = %Box
@onready var _name_label: Label = %SpeakerName
@onready var _text_label: Label = %LineText
@onready var _hint: Label = %Hint
@onready var _skip_btn: Button = %SkipButton

var _def: DialogueDef = null
var _index: int = 0
var _finished: bool = false
## Vrai quand un test construit l ecran hors jeu : on affiche tout, mais on ne
## previent pas le routeur a la fin (il changerait la scene du lanceur de tests).
var _test_mode: bool = false


func _ready() -> void:
	theme = UiTheme.make()
	UiTheme.style_paper(_box)
	UiTheme.style_primary(_skip_btn)
	_skip_btn.pressed.connect(_on_skip)

	_test_mode = bool(SceneRouter.payload.get("test_mode", false))
	var story_id: StringName = SceneRouter.payload.get("story_id", &"")
	_def = DialogueDef.load_by_id(story_id)
	if _def == null:
		# Une scene nommee mais absente ne doit pas bloquer la campagne : on
		# passe la main tout de suite. test_story.gd, lui, echoue dessus.
		_finished = true
		if not _test_mode:
			SceneRouter.story_finished(story_id)
		return

	_apply_backdrop()
	_style_text()
	_show_line()


## Le fond de l acte, etire en "couvrir" : les fonds sont en paysage, l ecran est
## en portrait, un KEEP_ASPECT_CENTERED laisserait deux bandes noires.
func _apply_backdrop() -> void:
	var path: String = BACKDROPS + _def.scene_background + ".png"
	if ResourceLoader.exists(path):
		_backdrop.texture = load(path)
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Le fond est un decor de combat : assombri, il ne mange pas les portraits.
	_backdrop.modulate = Color(0.48, 0.46, 0.58)


func _style_text() -> void:
	var f: Font = UiTheme.font()
	for l: Label in [_name_label, _text_label, _hint]:
		if f != null:
			l.add_theme_font_override(&"font", f)
	_name_label.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
	_name_label.add_theme_color_override(&"font_color", UiTheme.GOLD)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text_label.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY)
	_text_label.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	_hint.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	_hint.text = "touche l ecran pour continuer"


func _show_line() -> void:
	var line: Dictionary = _def.line(_index)
	var speaker: String = String(line.get("speaker", ""))
	var portrait: StringName = StringName(line.get("portrait", ""))
	var side: String = String(line.get("side", "left"))

	_text_label.text = String(line.get("text", ""))
	# Narrateur : pas de nom, pas de cadre autour du vide. La boite du nom
	# disparait pour que le texte remonte et occupe la place.
	_name_label.text = speaker
	_name_label.visible = speaker != ""

	var target: TextureRect = _right if side == "right" else _left
	var other: TextureRect = _left if side == "right" else _right
	_set_portrait(target, portrait)
	# Le portrait d en face reste a l ecran mais recule : c est ce qui fait lire
	# QUI parle sans avoir a suivre le nom.
	other.modulate = DIM
	target.modulate = Color.WHITE
	if portrait == &"":
		target.visible = false

	_hint.text = "touche pour continuer" if _index < _def.line_count() - 1 else "touche pour commencer"


func _set_portrait(rect: TextureRect, key: StringName) -> void:
	if key == &"":
		return
	var tex: Texture2D = _portrait_texture(key)
	if tex == null:
		rect.visible = false
		return
	rect.texture = tex
	rect.visible = true
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Le portrait de droite regarde vers la gauche : sans ce miroir, les deux
	# personnages regardent dans la meme direction et ne se parlent pas.
	rect.flip_h = rect == _right


## Un fichier de `assets/portraits/`, ou la premiere case d une feuille animee
## du jeu. Null quand la cle est inconnue : le personnage parle sans visage
## plutot que de faire planter la scene.
func _portrait_texture(key: StringName) -> Texture2D:
	# Le VISAGE d abord : c est ce que le joueur doit lire.
	var tete: Texture2D = _head_texture(key)
	if tete != null:
		return tete
	# Repli sur le corps entier du meme personnage. Il vaut mieux un buste
	# maladroit que pas de personnage du tout.
	var path: String = String(FACES.get(key, ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	if SHEET_FACES.has(key):
		return _sheet_frame(SHEET_FACES[key])
	return null


## Une case de la grille des visages. Null si la cle est inconnue ou si la
## planche manque — l appelant retombe alors sur le corps entier.
func _head_texture(key: StringName) -> Texture2D:
	if not HEAD_FACES.has(key) or not ResourceLoader.exists(HEADS):
		return null
	var grille: Texture2D = load(HEADS)
	if grille == null:
		return null
	var rc: Array = HEAD_FACES[key]
	var ligne: int = int(rc[0]) - 1
	var colonne: int = int(rc[1]) - 1
	if ligne < 0 or colonne < 0 or colonne >= HEAD_COLS:
		return null
	var at := AtlasTexture.new()
	at.atlas = grille
	at.region = Rect2(colonne * HEAD_PX, ligne * HEAD_PX, HEAD_PX, HEAD_PX)
	return at


## Premiere case d "idle" d une feuille d AnimCatalog, RECADREE sur le personnage.
##
## Le recadrage n est pas cosmetique : une case de 192 px n est occupee qu a 43 %
## par le mage (`AnimCatalog.occupancy`), le reste est du vide transparent reserve
## au balayage des animations. Affichee telle quelle dans un rectangle de portrait,
## la case fait tenir le personnage dans un tiers de la place — c est exactement ce
## qu on voyait a la premiere capture. On mesure donc la zone reellement opaque et
## on n affiche qu elle.
func _sheet_frame(anim_key: StringName) -> Texture2D:
	if not AnimCatalog.has(anim_key):
		return null
	var frames: SpriteFrames = AnimCatalog.frames(anim_key)
	if frames == null or not frames.has_animation(&"idle"):
		return null
	if frames.get_frame_count(&"idle") <= 0:
		return null
	var frame: Texture2D = frames.get_frame_texture(&"idle", 0)
	return _cropped(frame)


## Recadre une texture sur ses pixels non transparents. Renvoie l originale si la
## mesure echoue (headless : get_image() peut ne rien rendre) — mieux vaut un
## portrait mal cadre qu un portrait absent.
func _cropped(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return tex
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(img)
	atlas.region = Rect2(used)
	return atlas


# --- Avancement ---
##
## `advance()` est public et sans effet de bord graphique obligatoire : c est le
## point d entree du test unitaire, qui deroule la scene sans toucher l ecran.

func advance() -> void:
	if _finished or _def == null:
		return
	_index += 1
	if _index >= _def.line_count():
		_end()
		return
	_show_line()


func line_index() -> int:
	return _index


func total_lines() -> int:
	return 0 if _def == null else _def.line_count()


func is_finished() -> bool:
	return _finished


func _end() -> void:
	if _finished:
		return
	_finished = true
	if _test_mode:
		return
	SceneRouter.story_finished(_def.id if _def != null else &"")


func _on_skip() -> void:
	# "Passer" saute la scene entiere, pas la replique : un joueur qui rejoue la
	# campagne veut sortir du dialogue, pas taper vingt fois.
	_index = total_lines()
	_end()


## Tout l ecran est une zone de touche : sur mobile, viser une petite fleche au
## pouce est penible. Seul le bouton "Passer" attrape son propre clic avant.
func _gui_input(event: InputEvent) -> void:
	var touched: bool = false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		touched = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		touched = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if touched:
		accept_event()
		advance()

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

## LA PLANCHE DU CASTING. Un seul fichier, une case par personnage, decoupe en
## AtlasTexture a l affichage.
##
## POURQUOI UNE PLANCHE ET PAS HUIT FICHIERS : un personnage doit etre CADRE de
## la meme facon que les autres, sinon l un remplit la boite et son voisin flotte
## au milieu. La planche est generee hors jeu, chaque source est detouree puis
## mise a l echelle dans une case carree identique — le cadrage est decide une
## fois, a la fabrication, pas a chaque affichage.
##
## POURQUOI LE VISAGE PLUTOT QUE LE CORPS ENTIER. Compare a la taille reelle
## d affichage (620 x 960 px), un corps entier montre un visage de 40 px perdu au
## sommet d une silhouette a pattes. Les sources retenues sont donc des BUSTES
## (dossier `Faceset` du pack TTRPG), pas des corps entiers ; le seul corps entier
## du lot, le rat, est recadre sur sa tete a la fabrication.
##
## D OU VIENNENT LES VISAGES. Le defaut corrige ici a survecu a trois vagues de
## travail : le seul pack de portraits disponible ne contenait que HUIT GUERRIERS
## DEMONS, et le heros du jeu — un vieux mage humain chauve — etait affiche en
## demon cornu a peau orange et yeux bleus. Le pack `TTRPG LEGEND [TOO MANY
## CHARACTERS]` (Ddant1100, itch.io) fournit 100 personnages nommes par classe et
## par race : il y a enfin de VRAIS humains, et un mage qui ressemble a un mage.
## `demon_heads.png` reste sur le disque mais n est plus la source de personne.
const CAST_SHEET: String = PORTRAITS + "story_cast.png"
const CAST_PX: int = 512

## Cle de portrait -> sa case dans la planche, et la source dont elle vient.
##
## `sheet` n est pas decoratif : c est ce que `test_story.gd` lit pour verifier
## qu aucun personnage humain n est redescendu sur la planche de demons. Une
## table qui documente sa provenance est une table qu une machine peut auditer.
##
## L EXPRESSION DOIT COLLER A LA REPLIQUE. La premiere version du casting
## montrait le mage SOURIANT LARGEMENT en disant "je n ai pas su les arreter",
## ce qui rendait la scene absurde. Le pack ne donne qu UNE expression par
## personnage : on a donc choisi des visages dont l expression ne contredit
## AUCUNE de leurs repliques. Le mage est las et neutre — il raconte, il ne joue
## pas ; c est pour ca que `mage_grave` partage sa case au lieu de sourire.
const CAST: Dictionary = {
	# Le heros. Chauve, vieux, col de mage : docs/histoire.md dit que ses
	# cheveux sont partis avec ses pouvoirs. Le seul du pack qui soit a la fois
	# chauve, age et manifestement mage. Paupieres lourdes, bouche fermee :
	# l expression tient aussi bien sur un aveu que sur une consigne.
	&"mage": {"cell": [1, 1], "sheet": CAST_SHEET, "from": "wizard_human_man_04"},
	# Meme homme, memes traits : le pack ne fournit pas de seconde expression et
	# lui en preter le visage d un AUTRE ferait deux mages a l ecran. On assume
	# un seul visage plutot qu un contresens.
	&"mage_grave": {"cell": [1, 1], "sheet": CAST_SHEET, "from": "wizard_human_man_04"},
	# L enfant : le seul jeune garcon du pack (le pack le nomme "boy"). Grands
	# yeux, chemise usee, aucune arme.
	&"child": {"cell": [1, 2], "sheet": CAST_SHEET, "from": "unknow_darkelve_boy_01"},
	# Le retournement de l acte V : l enfant est une divinite. Un masque de
	# dragon d or, rien d humain dedans — c est la meme creature, vue enfin.
	&"child_god": {"cell": [1, 3], "sheet": CAST_SHEET, "from": "deity_man_01"},
	# Le rat pilote, mecanicien : un rat debout, capuche, besace d outils et de
	# fioles. C est le SEUL vrai rat de tous les packs ; il vient d un autre
	# pack et d un autre style, ce qui se voit — mais un nain etiquete "Le Rat
	# pilote" serait un contresens, et un contresens se voit davantage.
	&"rat": {"cell": [1, 4], "sheet": CAST_SHEET, "from": "cogabushi_A_18"},
	# Le maire : couronne, lorgnons, fraise de notable et un document a la main.
	# Un homme de papiers — exactement celui qui "savait depuis des mois".
	&"mayor": {"cell": [2, 1], "sheet": CAST_SHEET, "from": "noble_human_man_02"},
	# Le roi squelette : crane decharne, chair grise recousue, yeux jaunes. Un
	# mort qui parle encore, pas un squelette de dessin anime.
	&"skeleton_king": {"cell": [2, 2], "sheet": CAST_SHEET, "from": "demon_human_man_01"},
	# Le Gardien de la foret : un heaume vert et or SANS VISAGE dedans, plumet
	# sombre. Le pack le nomme "raceless" — sans race. Un colosse mu par autre
	# chose que lui-meme : c est exactement ce que l acte 1 revele de lui.
	&"guardian": {"cell": [2, 3], "sheet": CAST_SHEET, "from": "knight_raceless_man_01"},
	# Le demon, lui, a le droit d avoir une tete de demon.
	&"demon": {"cell": [2, 4], "sheet": CAST_SHEET, "from": "demon_elve_man_01"},
}

## Portraits pris sur une FEUILLE animee du jeu plutot que sur un fichier.
## POURQUOI : un monstre qui parle doit etre EXACTEMENT celui qu on vient de
## combattre, sinon la scene parle d un autre. Le pack de portraits ne contient
## aucun monstre, mais le jeu a deja leurs feuilles. On y decoupe la premiere case
## d "idle" — pas une pose de plus a dessiner ni a maintenir.
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


## Le decor de la scene, etire en "couvrir" : les decors sont en paysage
## (1792 x 1024), l ecran est en portrait, un KEEP_ASPECT_CENTERED laisserait
## deux bandes noires.
##
## POURQUOI UN DECOR ET PAS LE FOND DE COMBAT. Les scenes reutilisaient la
## texture que le champ de bataille affiche derriere les monstres, assombrie de
## moitie pour qu elle ne mange pas les portraits. Resultat : chaque dialogue se
## jouait devant la meme pelouse verte delavee, et le joueur ne pouvait pas dire
## ou il se trouvait. Le pack `Wood Elves` fournit des decors PEINTS, un par
## lieu de l acte 1 — le prologue a son sanctuaire, le village a ses maisons,
## le Gardien a son arbre.
##
## Ils sont a peine assombris (0.78 et pas 0.48) : un decor peint qu on eteint
## de moitie redevient la bouillie qu on voulait quitter. Ce qui protege la
## lisibilite du texte, c est la boite papier opaque, pas l obscurcissement.
func _apply_backdrop() -> void:
	var path: String = BACKDROPS + _def.scene_background + ".png"
	if ResourceLoader.exists(path):
		_backdrop.texture = load(path)
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.modulate = Color(0.78, 0.78, 0.82)


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


## Le visage d un personnage du casting, ou la premiere case d une feuille
## animee du jeu. Null quand la cle est inconnue : le personnage parle sans
## visage plutot que de faire planter la scene.
func _portrait_texture(key: StringName) -> Texture2D:
	var visage: Texture2D = _cast_texture(key)
	if visage != null:
		return visage
	if SHEET_FACES.has(key):
		return _sheet_frame(SHEET_FACES[key])
	return null


## Une case de la planche du casting. Null si la cle est inconnue ou si la
## planche manque — l appelant essaie alors les feuilles animees du jeu.
func _cast_texture(key: StringName) -> Texture2D:
	if not CAST.has(key):
		return null
	var fiche: Dictionary = CAST[key]
	var chemin: String = String(fiche.get("sheet", ""))
	if chemin == "" or not ResourceLoader.exists(chemin):
		return null
	var planche: Texture2D = load(chemin)
	if planche == null:
		return null
	var rc: Array = fiche.get("cell", [])
	if rc.size() < 2:
		return null
	var ligne: int = int(rc[0]) - 1
	var colonne: int = int(rc[1]) - 1
	if ligne < 0 or colonne < 0:
		return null
	# Une case hors planche donnerait un rectangle vide a l ecran, ce qui se lit
	# comme "ce personnage n a pas de portrait" alors que c est une faute de
	# frappe dans la table. On refuse plutot que d afficher du vide.
	if (colonne + 1) * CAST_PX > planche.get_width():
		return null
	if (ligne + 1) * CAST_PX > planche.get_height():
		return null
	var at := AtlasTexture.new()
	at.atlas = planche
	at.region = Rect2(colonne * CAST_PX, ligne * CAST_PX, CAST_PX, CAST_PX)
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

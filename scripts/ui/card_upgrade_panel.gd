class_name CardUpgradePanel
extends Control
## ECRAN DE CHOIX D AMELIORATION — "XP par lancer, choix parmi 3".
##
## Un sort lance GameConfig.CARD_UPGRADE_CASTS fois propose trois voies. Le
## joueur en retient une, POUR LA PARTIE EN COURS.
##
##   +--------------------------------------------------+
##   |                                                  |
##   |             CE SORT A MURI                       |  <- titre
##   |         Boule de feu  -  8 lancers               |  <- de quel sort on parle
##   |                                                  |
##   |   +------------------------------------------+   |
##   |   |  PUISSANCE                               |   |  <- 3 voies empilees
##   |   |  +45% de degats, incantation +30%        |   |     (190 px de haut)
##   |   +------------------------------------------+   |
##   |   +------------------------------------------+   |
##   |   |  CELERITE                                |   |
##   |   |  incantation -35%, -20% de degats        |   |
##   |   +------------------------------------------+   |
##   |   +------------------------------------------+   |
##   |   |  AMPLEUR                                 |   |
##   |   |  +40% de rayon et duree, incantation +10%|   |
##   |   +------------------------------------------+   |
##   |                                                  |
##   |              [ garder tel quel ]                 |  <- renoncer
##   +--------------------------------------------------+
##
## POURQUOI EMPILE ET NON TROIS COLONNES
## -------------------------------------
## Le choix de CARTE (HUD._show_choice) pose trois CardView cote a cote, parce
## qu une carte est une vignette : on la reconnait a son icone. Une voie
## d amelioration est une PHRASE, avec un gain et un prix. Sur 1080 px de large,
## trois colonnes laissent 340 px par voie, soit sept ou huit caracteres par
## ligne : le prix se retrouve a la ligne, detache de son gain, et le joueur
## compare des bouts de phrases. Empilees, chaque voie dispose de toute la
## largeur et se lit d un trait — et la cible tactile fait 190 px de haut, bien
## au-dela des 90 px exiges.
##
## POURQUOI UN ECRAN MODAL QUI ARRETE LE JEU
## -----------------------------------------
## Le jeu est en TEMPS REEL, et couper le temps est une decision a justifier.
##   - Le jeu a DEJA cette grammaire : le choix de carte de montee de niveau met
##     la partie en pause (GameController.simulate sort tot sur pending_offer).
##     Une seconde facon d interrompre, non modale, obligerait le joueur a
##     apprendre deux langages pour deux decisions de meme nature.
##   - Il y a trois compromis a LIRE, chacun avec un gain et un prix. Les lire
##     pendant que les monstres descendent, c est soit choisir au hasard, soit
##     prendre un coup en lisant. Les deux gachent le choix.
##   - La cadence mesuree au banc (seuil 8 lancers) donne 4,7 a 6,4 ameliorations
##     sur une partie de 160 s, soit une toutes les 25 a 35 secondes : c est
##     l ordre de grandeur des montees de niveau. Une respiration, pas un hoquet.
## Le bouton "garder tel quel" existe pour cette raison : si le joueur ne veut
## pas s arreter, il ferme d un doigt sans rien lire.

signal path_chosen(index: int)
signal declined()

## Hauteur d une voie. Trois fois cette valeur plus les titres tiennent dans
## 1920 px de haut, et chaque cible depasse largement les 90 px tactiles.
const PATH_HEIGHT: float = 190.0
const MIN_TOUCH: float = 90.0

var _box: VBoxContainer = null


func _ready() -> void:
	# L ecran doit repondre meme quand l arbre est en pause : sinon son propre
	# bouton ne reagit plus et la partie reste bloquee pour de bon. C est le
	# defaut deja rencontre sur le bouton de pause du HUD.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ANCRES **ET** OFFSETS. set_anchors_preset() seul pose les ancres sans
	# toucher aux offsets : le panneau restait de taille (0,0), le VBox heritait
	# de zero et tout le contenu se dessinait a sa taille naturelle depuis le coin
	# haut-gauche. Sur la capture, le titre etait colle au bord superieur et la
	# moitie basse de l ecran restait vide — un defaut qu aucun etage du harnais
	# ne voit, puisque rien ne plante.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# STOP : l ecran avale les evenements, sinon un glissement de carte passerait
	# a travers et lancerait un sort pendant que le joueur lit ses trois voies.
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


## Affiche les voies de `card`. `paths` vient de RunState.upgrade_paths_for().
func show_paths(card: SpellCard, paths: Array) -> void:
	if _box != null and is_instance_valid(_box):
		_box.queue_free()
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = 50.0
	_box.offset_right = -50.0
	# La boite prend TOUTE la hauteur et se centre dedans. Avec un offset haut de
	# 300 et bas de -300, le contenu se tassait dans le tiers superieur et laissait
	# 45 % de l ecran vide sous les boutons (vu sur capture) : sur un telephone
	# tenu a une main, les trois voies tombaient hors de portee du pouce.
	_box.offset_top = 0.0
	_box.offset_bottom = 0.0
	_box.add_theme_constant_override(&"separation", 26)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)

	_box.add_child(_ressort())
	_box.add_child(UiTheme.label("CE SORT A MURI", UiTheme.FONT_TITLE, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, false))
	var nom: String = card.display_name if card != null else "?"
	var lancers: int = RunState.casts_of(card)
	_box.add_child(UiTheme.label("%s  -  %d lancers" % [nom, lancers],
		UiTheme.FONT_BODY, UiTheme.TEAL, HORIZONTAL_ALIGNMENT_CENTER, false))
	_box.add_child(UiTheme.label("Une seule voie, et seulement pour cette partie.",
		UiTheme.FONT_SMALL, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false))

	for i in paths.size():
		_box.add_child(_path_button(paths[i], i))

	# RESSORTS HAUT ET BAS. BoxContainer.ALIGNMENT_CENTER ne centre que l espace
	# LIBRE ; des que les boutons demandent a s etendre (size_flags EXPAND par
	# defaut sur un Button dans un VBox), il n y a plus d espace libre et tout se
	# colle en haut — sur la capture, le titre etait coupe par le bord superieur
	# et la moitie basse de l ecran restait vide. Deux Controls vides qui prennent
	# la place restante, un de chaque cote, centrent pour de bon.

	# RENONCER. Sans ce bouton, un joueur qui ne veut pas d un compromis serait
	# force d en prendre un : les trois voies coutent quelque chose, donc aucune
	# n est gratuite et refuser est un choix legitime.
	var garder := Button.new()
	garder.text = "GARDER TEL QUEL"
	garder.custom_minimum_size = Vector2(0, MIN_TOUCH)
	garder.size_flags_vertical = Control.SIZE_FILL
	garder.add_theme_font_override(&"font", UiTheme.font())
	garder.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
	# Un CADRE, sinon le bouton flotte sans repere au-dessus du combat : ce
	# panneau est cree par code, il n herite donc pas du theme de la scene, et
	# un Button sans style est un texte nu. Vu sur capture — les trois voies
	# avaient leur cadre, le refus n en avait aucun et ne se lisait plus comme
	# un bouton.
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Color(0.20, 0.17, 0.24, 0.92)
	cadre.border_color = Color(0.62, 0.58, 0.52)
	cadre.set_border_width_all(3)
	cadre.set_corner_radius_all(10)
	cadre.content_margin_left = 18.0
	cadre.content_margin_right = 18.0
	for etat in [&"normal", &"hover", &"pressed", &"focus"]:
		garder.add_theme_stylebox_override(etat, cadre)
	garder.add_theme_color_override(&"font_color", Color(0.88, 0.86, 0.82))
	garder.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"card_pick")
		declined.emit())
	_box.add_child(garder)
	_box.add_child(_ressort())
	visible = true


## Une voie : un bouton haut, titre en gras au-dessus du compromis en clair.
##
## Le titre est extrait du libelle (tout ce qui precede le deux-points) pour que
## RunState reste la SEULE source du texte : dupliquer les noms ici les ferait
## divergerdu jour ou une voie serait renommee.
func _path_button(path: Dictionary, index: int) -> Control:
	var texte: String = String(path.get("text", ""))
	var titre: String = texte
	var detail: String = ""
	var coupe: int = texte.find(":")
	if coupe > 0:
		titre = texte.substr(0, coupe).strip_edges()
		detail = texte.substr(coupe + 1).strip_edges()

	var b := Button.new()
	b.custom_minimum_size = Vector2(0, PATH_HEIGHT)
	# FILL et non EXPAND_FILL : la hauteur d une voie est une CIBLE TACTILE, elle
	# ne doit pas varier avec la place disponible. C est ce qui laisse aux deux
	# ressorts de quoi centrer le bloc.
	b.size_flags_vertical = Control.SIZE_FILL
	# Le Button porte le fond et la zone tactile ; le texte est pose par-dessus
	# en deux Labels, parce qu un Button n a qu une seule taille de police et
	# qu il faut deux niveaux de lecture (le nom, puis le compromis).
	b.text = ""
	# TEINTE PAR VOIE. UiTheme.style_paper() ne convient pas ici : il teinte une
	# planche de papier deja coloree, et les trois voies sortaient IDENTIQUES sur
	# la capture — le code couleur annonce n existait tout simplement pas. Un
	# StyleBoxFlat pose sur les quatre etats donne la couleur voulue, et seulement
	# elle.
	var couleur: Color = _teinte(path)
	for etat: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var facteur: float = 1.0
		if etat == &"hover":
			facteur = 1.08
		elif etat == &"pressed":
			facteur = 0.90
		b.add_theme_stylebox_override(etat, _fond(couleur * facteur))
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"card_pick")
		path_chosen.emit(index))

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 34.0
	inner.offset_right = -34.0
	inner.offset_top = 22.0
	inner.offset_bottom = -22.0
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override(&"separation", 10)
	# IGNORE partout a l interieur : un Label en MOUSE_FILTER_STOP avalerait le
	# clic et le bouton ne se declencherait jamais. Piege deja rencontre sur la
	# barre de vitesse du HUD.
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)

	inner.add_child(UiTheme.label(titre.to_upper(), UiTheme.FONT_BUTTON,
		Color(0.10, 0.07, 0.14), HORIZONTAL_ALIGNMENT_CENTER, false))
	# Le compromis est LE contenu de la decision : sur la premiere capture il etait
	# en FONT_SMALL et en brun sombre sur fond colore, donc le texte le MOINS
	# lisible de l ecran alors que c est le seul qu il faut lire. FONT_BODY, et une
	# encre tres sombre qui tient sur les trois teintes.
	var l: Label = UiTheme.label(detail, UiTheme.FONT_BODY,
		Color(0.12, 0.09, 0.16), HORIZONTAL_ALIGNMENT_CENTER, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(l)
	return b


## Un espace vide qui prend toute la place restante. Deux d entre eux, un de
## chaque cote du bloc, le centrent verticalement quel que soit le nombre de voies.
func _ressort() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Chaque voie porte sa couleur : le joueur reconnait le compromis avant de lire.
## Rouge = frappe fort, bleu = va vite, vert = couvre large. Ce sont les teintes
## deja employees par le jeu pour les degats, la vitesse et les zones.
func _teinte(path: Dictionary) -> Color:
	match StringName(path.get("id", &"")):
		&"power":
			return UiTheme.RED.lightened(0.62)
		&"haste":
			return UiTheme.BLUE.lightened(0.62)
		&"area":
			return UiTheme.GREEN.lightened(0.62)
	return Color(0.88, 0.86, 0.90)


## Le fond d une voie : une couleur pleine, bordee d or comme les panneaux du jeu.
func _fond(couleur: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = couleur
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = UiTheme.GOLD.darkened(0.25)
	sb.set_content_margin_all(18.0)
	return sb

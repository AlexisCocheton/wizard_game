class_name CardUpgradePanel
extends Control
## ECRAN DE CHOIX D AMELIORATION — "XP par lancer, choix parmi 3".
##
## Un sort lance GameConfig.CARD_UPGRADE_CASTS fois MURIT : l ecran propose trois
## voies TIREES dans le pool PROPRE A CE SORT (RunState.draw_upgrade_offer). Le
## joueur en retient une, POUR LA PARTIE EN COURS. Un sort peut murir plusieurs
## fois (GameConfig.CARD_UPGRADE_TIERS) : l ecran dit alors quelle maturation
## c est et ce que le sort a deja acquis, pour que le cumul se lise.
##
##   +--------------------------------------------------+
##   |             CE SORT A MURI                       |  <- titre
##   |         Boule de feu  -  8 lancers               |  <- de quel sort on parle
##   |                                                  |
##   |   +------------------------------------------+   |
##   |   |  DEGATS                           FORTE  |   |  <- 3 voies empilees
##   |   |  +30 % degats                    (vert)  |   |     gain en VERT, signe +
##   |   |  -15 % vitesse de lancement      (rouge) |   |     prix en ROUGE, signe -
##   |   +------------------------------------------+   |
##   |   +------------------------------------------+   |
##   |   |  ZONE                            LEGERE  |   |
##   |   |  +10 % zone                      (vert)  |   |
##   |   |  sans contrepartie               (gris)  |   |
##   |   +------------------------------------------+   |
##   |   +------------------------------------------+   |
##   |   |  VITESSE                          FORTE  |   |
##   |   |  +30 % vitesse de lancement      (vert)  |   |
##   |   |  -15 % degats                    (rouge) |   |
##   |   +------------------------------------------+   |
##   |              [ garder tel quel ]                 |  <- renoncer
##   +--------------------------------------------------+
##
## LE SIGNE ET LA COULEUR, PAS LA COULEUR SEULE
## --------------------------------------------
## Un joueur sur douze distingue mal le vert du rouge. Le gain porte donc son "+"
## et le prix son "-" : la couleur double l information, elle ne la porte pas.
## Une voie legere ECRIT qu elle ne coute rien : sans cette ligne, le joueur
## cherche un prix qu il croit avoir mal lu.
##
## POURQUOI EMPILE ET NON TROIS COLONNES
## -------------------------------------
## Le choix de CARTE (HUD._show_choice) pose trois CardView cote a cote, parce
## qu une carte est une vignette : on la reconnait a son icone. Une voie
## d amelioration est une PHRASE, avec un gain et un prix. Sur 1080 px de large,
## trois colonnes laissent 340 px par voie, soit sept ou huit caracteres par
## ligne : le prix se retrouve a la ligne, detache de son gain, et le joueur
## compare des bouts de phrases. Empilees, chaque voie dispose de toute la
## largeur et se lit d un trait — et la cible tactile fait 200 px de haut, bien
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
##   - La cadence mesuree au banc (paliers a 8 puis 24 lancers, deux maturations
##     par sort) donne 3,1 a 8,7 ameliorations par partie, mediane 5,5, soit une
##     toutes les 20 a 50 secondes : c est l ordre de grandeur des montees de
##     niveau. Une respiration, pas un hoquet. Avec deux paliers a ecart egal (8
##     et 16), les niveaux longs montaient a 10,5 : c est pour cela que l ecart
##     grandit (GameConfig.CARD_UPGRADE_GAP_GROWTH).
## Le bouton "garder tel quel" existe pour cette raison : si le joueur ne veut
## pas s arreter, il ferme d un doigt sans rien lire.

signal path_chosen(index: int)
signal declined()

## Hauteur d une voie. Trois fois cette valeur plus les titres tiennent dans
## 1920 px de haut, et chaque cible depasse largement les 90 px tactiles.
## 200 et non plus 190 : une voie porte maintenant TROIS lignes (titre, gain,
## prix) au lieu de deux.
const PATH_HEIGHT: float = 200.0
const MIN_TOUCH: float = 90.0
## Encres du gain et du prix, eclaircies pour tenir sur le fond sombre d une voie.
const COULEUR_GAIN := Color(0.52, 0.92, 0.56)
const COULEUR_PRIX := Color(1.0, 0.52, 0.52)
## Fond commun aux voies. SOMBRE, et non plus une teinte pastel par voie : le vert
## du gain et le rouge du prix doivent se lire sur le meme fond, et sur un aplat
## clair l un des deux disparaissait toujours.
const FOND_VOIE := Color(0.14, 0.11, 0.19, 0.97)

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


## Affiche les voies de `card`. `paths` vient de RunState.draw_upgrade_offer()
## (le signal upgrade_ready les porte deja tirees).
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

	# RESSORTS HAUT ET BAS. BoxContainer.ALIGNMENT_CENTER ne centre que l espace
	# LIBRE ; des que les boutons demandent a s etendre (size_flags EXPAND par
	# defaut sur un Button dans un VBox), il n y a plus d espace libre et tout se
	# colle en haut — sur la capture, le titre etait coupe par le bord superieur
	# et la moitie basse de l ecran restait vide. Deux Controls vides qui prennent
	# la place restante, un de chaque cote, centrent pour de bon.
	_box.add_child(_ressort())
	_box.add_child(UiTheme.label("CE SORT A MURI", UiTheme.FONT_TITLE, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, false))
	var nom: String = card.display_name if card != null else "?"
	var lancers: int = RunState.casts_of(card)
	_box.add_child(UiTheme.label("%s  -  %d lancers" % [nom, lancers],
		UiTheme.FONT_BODY, UiTheme.TEAL, HORIZONTAL_ALIGNMENT_CENTER, false))
	# QUELLE maturation, et parmi combien de voies : sans le compte, le joueur
	# croit que les trois voies montrees sont tout ce que le sort peut devenir,
	# et ne sait pas qu une autre partie lui en proposera d autres.
	var rang: int = RunState.maturations_done(card) + 1
	var pool: int = RunState.upgrade_offerable_for(card).size()
	var entete: String = "Une voie parmi %d, pour cette partie seulement." % pool
	if GameConfig.CARD_UPGRADE_TIERS > 1:
		entete = "Maturation %d sur %d  -  %s" % [rang, GameConfig.CARD_UPGRADE_TIERS,
			entete.to_lower()]
	_box.add_child(UiTheme.label(entete, UiTheme.FONT_SMALL, UiTheme.TEXT_DIM,
		HORIZONTAL_ALIGNMENT_CENTER, true))
	# LE CUMUL. A la seconde maturation, la nouvelle voie s AJOUTE a la premiere :
	# le joueur doit voir ce qu il a deja pour juger ce qu il ajoute (un second
	# "-15 % vitesse" se lit tout autrement quand le premier est sous ses yeux).
	var acquis: Array[String] = []
	for v in RunState.taken_paths(card):
		var ligne: String = String(v.get("gain_text", ""))
		if String(v.get("cost_text", "")) != "":
			ligne += ", " + String(v.get("cost_text", ""))
		acquis.append(ligne)
	if not acquis.is_empty():
		var l_acquis: Label = UiTheme.label("Deja acquis : " + " ; ".join(acquis),
			UiTheme.FONT_SMALL, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
		l_acquis.name = "Acquis"
		_box.add_child(l_acquis)

	for i in paths.size():
		_box.add_child(_path_button(paths[i], i))

	# RENONCER. Sans ce bouton, un joueur qui ne veut pas d un compromis serait
	# force d en prendre un. Meme face a une voie legere gratuite, refuser reste
	# legitime : le joueur peut vouloir garder le sort qu il connait.
	var garder := Button.new()
	garder.name = "Garder"
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


## Une voie : un bouton haut. Titre et forme sur la premiere ligne, puis le GAIN
## (vert, "+") et le PRIX (rouge, "-") chacun sur sa ligne.
##
## Les textes viennent tout faits de RunState (title, gain_text, cost_text) :
## RunState reste la SEULE source des libelles, l ecran ne fait que les poser.
## Si un appelant ne fournit que `text`, on retombe sur le decoupage au
## deux-points, pour ne jamais afficher un bouton vide.
func _path_button(path: Dictionary, index: int) -> Control:
	var titre: String = String(path.get("title", ""))
	var gain: String = String(path.get("gain_text", ""))
	var prix: String = String(path.get("cost_text", ""))
	var forte: bool = StringName(path.get("form", &"")) == &"strong"
	if titre == "":
		var texte: String = String(path.get("text", ""))
		var coupe: int = texte.find(":")
		titre = texte.substr(0, coupe).strip_edges() if coupe > 0 else texte
		gain = texte.substr(coupe + 1).strip_edges() if coupe > 0 else ""

	var b := Button.new()
	b.name = "Voie%d" % index
	b.custom_minimum_size = Vector2(0, PATH_HEIGHT)
	# FILL et non EXPAND_FILL : la hauteur d une voie est une CIBLE TACTILE, elle
	# ne doit pas varier avec la place disponible. C est ce qui laisse aux deux
	# ressorts de quoi centrer le bloc.
	b.size_flags_vertical = Control.SIZE_FILL
	# Le Button porte le fond et la zone tactile ; le texte est pose par-dessus en
	# Labels, parce qu un Button n a qu une taille et qu une couleur de police, et
	# qu il faut ici trois lignes de trois couleurs.
	b.text = ""
	# La FORME se lit au cadre : or pour une voie forte, bleu-vert pour une
	# legere. Un StyleBoxFlat pose sur les quatre etats : UiTheme.style_paper()
	# teinte une planche deja coloree, et les voies en sortaient identiques.
	var bord: Color = UiTheme.GOLD if forte else UiTheme.TEAL
	for etat: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var fond: Color = FOND_VOIE
		if etat == &"hover":
			fond = FOND_VOIE.lightened(0.08)
		elif etat == &"pressed":
			fond = FOND_VOIE.darkened(0.25)
		b.add_theme_stylebox_override(etat, _fond(fond, bord))
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"card_pick")
		path_chosen.emit(index))

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 34.0
	inner.offset_right = -34.0
	inner.offset_top = 14.0
	inner.offset_bottom = -14.0
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override(&"separation", 4)
	# IGNORE partout a l interieur : un Label en MOUSE_FILTER_STOP avalerait le
	# clic et le bouton ne se declencherait jamais. Piege deja rencontre sur la
	# barre de vitesse du HUD.
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)

	# Ligne de titre : le NOM de l axe a gauche, la FORME a droite, en toutes
	# lettres pour ne pas dependre de la couleur du cadre.
	var tete := HBoxContainer.new()
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(tete)
	var l_titre: Label = UiTheme.label(titre.to_upper(), UiTheme.FONT_BUTTON,
		UiTheme.GOLD if forte else Color(0.92, 0.90, 0.95), HORIZONTAL_ALIGNMENT_LEFT, false)
	l_titre.name = "Titre"
	l_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tete.add_child(l_titre)
	var l_forme: Label = UiTheme.label("FORTE" if forte else "LEGERE", UiTheme.FONT_SMALL,
		bord, HORIZONTAL_ALIGNMENT_RIGHT, false)
	l_forme.name = "Forme"
	l_forme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tete.add_child(l_forme)

	var l_gain: Label = UiTheme.label(gain, UiTheme.FONT_BODY, COULEUR_GAIN,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	l_gain.name = "Gain"
	l_gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(l_gain)
	var l_prix: Label = UiTheme.label(prix if prix != "" else "sans contrepartie",
		UiTheme.FONT_BODY, COULEUR_PRIX if prix != "" else UiTheme.TEXT_DIM,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	l_prix.name = "Prix"
	l_prix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(l_prix)
	return b


## Un espace vide qui prend toute la place restante. Deux d entre eux, un de
## chaque cote du bloc, le centrent verticalement quel que soit le nombre de voies.
func _ressort() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Le fond d une voie : une couleur pleine, bordee selon sa forme.
func _fond(couleur: Color, bord: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = couleur
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = bord
	sb.set_content_margin_all(18.0)
	return sb

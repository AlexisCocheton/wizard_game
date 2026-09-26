class_name SettingsPanel
extends VBoxContainer
## Onglet Parametres — volumes, vibrations, remise a zero.

var _reset_btn: Button
var _reset_armed: bool = false

## Le bloc MODE TESTEUR. Reconstruit a chaque bascule plutot que rafistole : son
## libelle, son encre ET son avertissement changent tous les trois d un etat a
## l autre, et trois mises a jour manuelles finissent toujours par diverger.
var _tester_box: VBoxContainer
var _tester_btn: Button
var _tester_armed: bool = false


## La colonne des reglages, posee DANS la page de livre.
##
## LES ENCRES SONT CALCULEES, pas choisies a l oeil. Le papier du livre a une
## luminance de 0,84 ; pour atteindre le seuil de lisibilite de 4,5:1 il faut
## donc une encre sous 0,147 de luminance (formule WCAG). L or du theme, meme
## assombri de 45 %, plafonnait a 3,14:1 — un titre en petites capitales sur
## fond clair ne pardonne rien.
var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override(&"separation", 0)
	# UNE PAGE DE LIVRE, comme les autres onglets. Les reglages ecrivaient
	# directement sur le fond de bois : mesure du contraste, 3,65:1 et 3,71:1
	# pour les libelles et les titres, sous le seuil de 4,5:1. Le bois est un
	# fond decoratif, pas une surface de lecture.
	var page := PanelContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override(&"panel", UiTheme.book_page_box())
	add_child(page)
	var marge := MarginContainer.new()
	for cote in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		marge.add_theme_constant_override(cote, 26)
	page.add_child(marge)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override(&"separation", 22)
	marge.add_child(_body)
	_build()


func _slider(title: String, key: String) -> void:
	_body.add_child(UiTheme.label(title, UiTheme.FONT_BODY, Color(0.20, 0.13, 0.07)))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(SaveData.get_setting(key, 1.0))
	s.custom_minimum_size = Vector2(0, 70)
	s.value_changed.connect(func(v: float) -> void:
		SaveData.set_setting(key, v)
		AudioBus.apply_settings()
		SaveData.save_profile())
	_body.add_child(s)


func _build() -> void:
	_body.add_child(UiTheme.label("AUDIO", UiTheme.FONT_BODY, Color(0.20, 0.13, 0.02)))
	_slider("Volume general", "master_volume")
	_slider("Effets", "sfx_volume")
	_slider("Musique", "music_volume")

	_body.add_child(UiTheme.label("JEU", UiTheme.FONT_BODY, Color(0.20, 0.13, 0.02)))
	var haptics := CheckButton.new()
	haptics.text = "Vibrations"
	haptics.button_pressed = bool(SaveData.get_setting("haptics", true))
	haptics.toggled.connect(func(on: bool) -> void:
		SaveData.set_setting("haptics", on)
		SaveData.save_profile())
	_body.add_child(haptics)

	_body.add_child(UiTheme.label("CREDITS", UiTheme.FONT_BODY,
		Color(0.20, 0.13, 0.02)))
	_credits()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)

	# Le mode testeur est pose JUSTE AU-DESSUS de la remise a zero : ce sont les
	# deux seules actions de cet ecran qui touchent la progression, et le testeur
	# qui cherche l une trouve l autre au meme endroit.
	_tester_box = VBoxContainer.new()
	_tester_box.add_theme_constant_override(&"separation", 10)
	_body.add_child(_tester_box)
	_build_tester()

	# Remise a zero en deux touchers : le premier arme, le second confirme.
	_reset_btn = Button.new()
	_reset_btn.text = "Reinitialiser la progression"
	_reset_btn.custom_minimum_size = Vector2(0, 100)
	# BLANC et non UiTheme.RED, et c est une MESURE, pas un gout : sur la tuile
	# teal du bouton (luminance 0,158), ce rouge tombe a 2,88:1 — sous le seuil
	# de lisibilite de 4,5:1, mesure sur capture. Le reflexe "rouge = danger" se
	# retourne ici contre lui-meme : le bouton le plus destructeur de l ecran
	# etait le moins lisible. Le blanc y donne 5,05:1.
	#
	# Le DANGER est porte par le texte du bouton, qui demande une confirmation
	# ("Confirmer ? Tout sera efface"), pas par une couleur qu on ne lit pas.
	_reset_btn.add_theme_color_override(&"font_color", Color(0.97, 0.95, 0.95))
	_reset_btn.pressed.connect(_on_reset)
	_body.add_child(_reset_btn)

	# Le jeu s appelle "Time Wizard" depuis le 2026-09-21 (demande du testeur).
	# Verrouille par un test sur le titre du menu : ce pied de page etait la
	# derniere occurrence de l ancien nom dans l interface.
	# Encre SOMBRE et non TEXT_DIM : ce violet pale est fait pour un fond
	# sombre, il disparait sur le papier creme.
	_body.add_child(UiTheme.label("Time Wizard  -  prototype", UiTheme.FONT_SMALL,
		Color(0.18, 0.14, 0.08), HORIZONTAL_ALIGNMENT_CENTER))


## LES CREDITS OBLIGATOIRES.
##
## Ce ne sont pas des remerciements : deux licences EXIGENT ces lignes, et le
## jeu ne peut pas etre publie sans elles (voir docs/assets_index.md, audit du
## 26 septembre).
##
## La formulation de xDeviruchi est IMPOSEE MOT POUR MOT par le
## "DOCUMENTATION & LICENSE.pdf" embarque dans le pack — la reformuler, meme en
## francais, ne respecterait pas la clause. Les resumes qui trainent sur le web
## disent "credit non obligatoire" ; c est faux pour la version 2025, celle que
## le projet utilise.
##
## La liste est DANS LE CODE et non dans un fichier de donnees : un ecran de
## credits qui depend d un .tres peut se retrouver vide si le fichier manque, et
## un ecran de credits vide est un manquement a une licence, pas un defaut
## d affichage.
const CREDITS: Array[Array] = [
	["Musiques", "Original music by Marllon Silva (xDeviruchi)"],
	["Personnages", "Ddant1100 - ddant1100.itch.io"],
	["Voix du mage", "John Carroll - johncarroll.itch.io"],
	["Decors, monstres et effets", "craftpix.net, Pixel Frog, luizmelo,"],
	["", "elthen, Pipoya, chierit, darkpixel-kronovi,"],
	["", "creativekind, lornn, cogabushi, batareya"],
]


func _credits() -> void:
	for ligne in CREDITS:
		var titre: String = String(ligne[0])
		var texte: String = String(ligne[1])
		if titre != "":
			_body.add_child(UiTheme.label(titre, UiTheme.FONT_SMALL,
				Color(0.42, 0.30, 0.10)))
		# Encre sombre : meme calcul que le reste de l ecran, le papier a une
		# luminance de 0,84 donc il faut passer sous 0,147 pour etre lisible.
		var l: Label = UiTheme.label(texte, UiTheme.FONT_SMALL,
			Color(0.20, 0.15, 0.09))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(l)


## --- MODE TESTEUR ---
##
## POURQUOI UN INTERRUPTEUR ET NON UN BOUTON "TOUT DEBLOQUER". Un bouton
## ecrirait les deblocages dans la sauvegarde : le testeur y perdrait sa
## progression reelle, sans retour possible. Ici rien n est ecrit — SaveData pose
## un calque au-dessus du profil. L eteindre rend la partie a l identique, ce qui
## est la seule raison pour laquelle le testeur osera l allumer sur son telephone
## de jeu. Il n a donc besoin ni d un second profil, ni d un avertissement de
## perte de donnees : il n y a rien a perdre.
##
## DEUX TOUCHERS POUR ALLUMER, UN SEUL POUR ETEINDRE. Allumer change ce que
## montrent quatre ecrans d un coup : cela merite la meme confirmation que la
## remise a zero, dont ce bloc reprend exactement le modele. Eteindre remet le
## jeu dans son etat normal, et on n arme pas un retour a la normale.
##
## LES ENCRES SONT CALCULEES, comme le reste de cet ecran, et il y a DEUX fonds.
##
## Sur le PAPIER (titre et explication), luminance 0,84 : il faut une encre sous
## 0,147 pour tenir 4,5:1. UiTheme.RED y plafonne a 3,74:1 — c est un rouge fait
## pour le fond sombre du jeu, pas pour ce papier. Le rouge ci-dessous est a
## 8,61:1, l encre neutre a 13,0:1.
##
## Sur le BOUTON (tuile teal du theme, luminance 0,158), le calcul donne
## l inverse : UiTheme.RED y tombe a 1,15:1, c est-a-dire illisible. C etait le
## premier choix, fait a l oeil parce que "rouge = attention" ; la mesure l a
## refuse. Le libelle de l etat ACTIF doit etre la chose la plus lisible de
## l ecran, donc BLANC (5,05:1). Le test le verrouille : une regression vers une
## encre sombre sur ce bouton rendrait le mode indetectable, exactement le
## defaut qu on cherche a empecher.
const TESTER_INK: Color = Color(0.52, 0.06, 0.06)

## L encre neutre du corps de l ecran, reprise a l identique (13,0:1).
const TESTER_INK_OFF: Color = Color(0.20, 0.13, 0.07)

## Encre du libelle ACTIF, sur la tuile du bouton. Blanc : 5,05:1.
const TESTER_BTN_INK_ON: Color = Color(1.0, 1.0, 1.0)

## Le seuil WCAG AA pour du texte de ce corps. Nomme, pour que le test parle de
## la regle et non d un nombre magique.
const CONTRAST_MIN: float = 4.5


func _build_tester() -> void:
	# Retrait AVANT liberation, et sur une copie de la liste : muter
	# get_children() pendant qu on le parcourt saute un enfant sur deux, et un
	# noeud seulement queue_free() reste dans l arbre jusqu a la fin de la frame,
	# donc le test qui relit les boutons en verrait deux.
	for c in _tester_box.get_children().duplicate():
		_tester_box.remove_child(c)
		c.free()
	var actif: bool = SaveData.tester_mode()

	_tester_box.add_child(UiTheme.label("MODE TESTEUR", UiTheme.FONT_BODY,
		TESTER_INK if actif else Color(0.20, 0.13, 0.02)))

	_tester_btn = Button.new()
	_tester_btn.text = _tester_label(actif)
	# Cible tactile : 100 px comme la remise a zero. Jamais de taille de police
	# litterale ici — elle echapperait au theme.
	_tester_btn.custom_minimum_size = Vector2(0, 100)
	if actif:
		_tester_btn.add_theme_color_override(&"font_color", TESTER_BTN_INK_ON)
	_tester_btn.pressed.connect(_on_tester)
	_tester_box.add_child(_tester_btn)

	# CE QUE LE MODE FAIT, a l ecran et non dans une note de commit : le testeur
	# doit savoir ce qu il vient d ouvrir avant de juger une difficulte.
	var explication: String = ""
	if actif:
		explication = ("Tout le contenu est ouvert : %d niveaux, %d cartes, %d monstres, "
			+ "%d succes, compte niveau %d. La progression reelle est INTACTE et "
			+ "revient en eteignant. La difficulte vue ici n est pas celle d un joueur.") % [
				ContentDB.levels.size(), ContentDB.cards.size(),
				ContentDB.enemies.size(), ContentDB.challenges.size(),
				SaveData.tester_account_level()]
	else:
		explication = ("Ouvre tout le contenu pour l inspecter sans rejouer la campagne. "
			+ "N efface rien : la progression reelle revient en eteignant.")
	var l: Label = UiTheme.label(explication, UiTheme.FONT_SMALL,
		TESTER_INK if actif else TESTER_INK_OFF)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tester_box.add_child(l)


func _tester_label(actif: bool) -> String:
	if actif:
		return "Mode testeur : ACTIF - toucher pour eteindre"
	if _tester_armed:
		return "Mode testeur : confirmer ? Tout sera ouvert"
	return "Activer le mode testeur"


func _on_tester() -> void:
	if SaveData.tester_mode():
		# Eteindre : immediat, un seul toucher.
		_tester_armed = false
		SaveData.set_tester_mode(false)
		SaveData.save_profile()
		_rebuild_tester_later()
		return
	if not _tester_armed:
		_tester_armed = true
		_tester_btn.text = _tester_label(false)
		return
	_tester_armed = false
	SaveData.set_tester_mode(true)
	SaveData.save_profile()
	_rebuild_tester_later()


## Reconstruire le bloc DEPUIS le signal du bouton libererait le bouton pendant
## sa propre emission : Godot verrouille l objet le temps de l appel et refuse
## ("Attempted to free a locked object"). On differe donc d une frame d idle.
## `call_deferred` et non `queue_free` : il faut que le nouveau bouton existe
## avant que quiconque relise l arbre.
func _rebuild_tester_later() -> void:
	if is_inside_tree():
		_build_tester.call_deferred()
	else:
		_build_tester()


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Confirmer ? Tout sera efface"
		return
	_reset_armed = false
	_reset_btn.text = "Reinitialiser la progression"
	SaveData.reset_profile()
	ContentDB.discover_starters()
	SaveData.save_profile()


func refresh() -> void:
	_reset_armed = false
	if _reset_btn != null:
		_reset_btn.text = "Reinitialiser la progression"
	# Le bloc testeur est reconstruit et non seulement desarme : une remise a
	# zero eteint le mode (elle recree les reglages par defaut), et le bouton
	# afficherait sinon "ACTIF" sur un profil qui ne l est plus.
	_tester_armed = false
	if _tester_box != null:
		_build_tester()

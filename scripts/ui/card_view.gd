class_name CardView
extends PanelContainer
## Une carte de sort a l ecran, en DEUX presentations tres differentes.
##
## Retour du testeur, mot pour mot : "la pioche est un peu trop rapide, on n a pas
## le temps de lire le texte des cartes en jeu" et "il faut simplifier au plus
## possible pour que les cartes soient reconnaissables et lancables le plus
## rapidement possible".
##
## La conclusion est que la carte en main ne doit PAS etre lue. Une carte de main
## fait 120 px de large : tout ce qu on y ecrit est soit trop petit pour etre lu en
## pleine vague, soit assez gros pour ne plus tenir. On a donc arrete d y ecrire.
##
##   MAIN (mode HAND)     : icone GRANDE, nom court sur une ligne, temps d incantation.
##   DETAIL (mode DETAIL) : la carte entiere, description comprise — en PAUSE, et
##                          dans le choix de sort, les deux moments ou le temps est arrete.
##
## Ce qui a DISPARU de la main et pourquoi :
##   - la description : illisible a 15 px, et c est justement ce qu on ne doit pas
##     avoir a lire pendant une vague. Elle est en pause.
##   - le nom de rarete ecrit en toutes lettres ("commune", "epique") : la COULEUR
##     du papier porte deja la rarete, le mot occupait une ligne pour rien.
##   - l indice de ciblage ("glisser pour viser") : il est identique pour la
##     moitie des cartes, donc il ne distingue rien.
##
## LE TEMPS D INCANTATION AFFICHE (audit independant, vague 9). La carte ecrivait
## `base_cast_time`, le chiffre brut du .tres : une carte marquee « 1.4s » prenait
## 2,66 s a x1, parce que le jeu applique GameConfig.CAST_TIME_SCALE (x1,9), les
## passifs, les ameliorations et la vitesse. Deux regles, et deux seulement :
##   - EN COMBAT (main, carte de detail du choix et de l echange de passif) : le
##     temps REEL, RunState.effective_cast_time, le meme calcul que le Caster.
##     Choisi plutot que « le temps a x1 » : la vitesse monte et descend sans
##     cesse, et le chiffre qui aide a decider (lancer maintenant ou attendre ?)
##     est la duree que la barre d incantation va REELLEMENT mettre. Le joueur
##     voit le temps raccourcir quand il accelere et s allonger quand il prend un
##     coup : c est la mecanique signature, lue sur la carte. Le HUD le
##     rafraichit a chaque image (refresh_cast_time), sans reconstruire la carte.
##   - HORS COMBAT (grimoire, ecran de deck) : base x CAST_TIME_SCALE, le temps
##     a 100 % de vitesse sans passif ni amelioration (menu_cast_seconds). Le
##     chiffre brut du .tres ne s affiche nulle part (verrouille par
##     test_card_view : balayage de scripts/ui).

signal pressed(card: SpellCard)

const HOVER_SCALE: float = 1.18

## Presentation de la carte.
enum Mode {
	HAND,    ## en main, pendant le jeu : icone + nom court + temps. Rien d autre.
	DETAIL,  ## temps arrete (pause, choix) : tout, description comprise.
}

## Mots de liaison retires pour fabriquer le nom court. "Boule de feu" -> "Boule feu",
## qui tient sur une carte de main la ou le nom complet se repliait sur trois lignes.
const LIAISONS: PackedStringArray = ["de", "du", "des", "d", "la", "le", "les", "l", "a", "au", "aux", "en"]

## Marge interne du papier du pack (UiTheme.style_paper -> tex_box(..., 22.0)).
## Elle est retiree de chaque cote avant de dimensionner l icone et le nom.
const PAPER_MARGIN: float = 22.0

## Taille de police plancher du nom en main. En dessous, le nom n est plus lisible
## du tout : mieux vaut tronquer que d afficher une bouillie (voir _fit_name).
const NAME_MIN_SIZE: int = 20

## Ce qu affiche une carte de main qui part SANS incantation (la carte BRULEE de
## la montee de niveau, chantier W8). Son temps d incantation y etait ecrit
## (« 1.4s ») alors qu elle part a l instant ou on la lache : le chiffre mentait.
const INSTANT_TEXT: String = "instantane"

var card: SpellCard = null
## Vrai si la carte part sans incantation (voir INSTANT_TEXT).
var _instant: bool = false
## Ligne du temps d une carte de MAIN, rafraichie par refresh_cast_time().
var _cast_label: Label = null
var _hovered: bool = false
var _tween: Tween = null


## Carte de MAIN : le strict minimum, dimensionne pour etre reconnu, pas lu.
## `instant` : la carte part sans incantation (carte brulee) ; la ligne du temps
## dit alors INSTANT_TEXT au lieu d un temps qu elle ne subira pas.
func setup_hand(c: SpellCard, width: float, height: float, instant: bool = false) -> void:
	_instant = instant
	_setup(c, width, height, Mode.HAND, 0, 0)


## Carte de DETAIL : tout le contenu. Reservee aux ecrans ou le temps est arrete.
func setup_detail(c: SpellCard, width: float, height: float,
		name_size: int = 30, body_size: int = 24) -> void:
	_setup(c, width, height, Mode.DETAIL, name_size, body_size)


func _setup(c: SpellCard, width: float, height: float, mode: int,
		name_size: int, body_size: int) -> void:
	card = c
	custom_minimum_size = Vector2(width, height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Toutes les raretes sur le papier CLAIR : la rarete se lit a la teinte du
	# papier (rarity_bg). Le papier sombre reserve aux legendaires les rendait
	# illisibles, c est-a-dire l inverse de ce qu on voulait signaler.
	UiTheme.style_paper(self, UiTheme.rarity_bg(c.rarity))
	for ch in get_children():
		ch.queue_free()

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4 if mode == Mode.HAND else 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	if mode == Mode.HAND:
		_build_hand(box, c, width, height)
	else:
		_build_detail(box, c, width, name_size, body_size)

	if not mouse_entered.is_connected(_on_enter):
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)
		resized.connect(_on_resized)
		gui_input.connect(_on_gui_input)


## MAIN : trois elements, dans l ordre de ce que l oeil cherche.
##   1. l icone, qui identifie le sort sans lecture
##   2. le nom court, pour confirmer
##   3. le temps d incantation, la seule donnee de jeu qui change une decision
##      dans la seconde (lancer maintenant ou attendre ?)
func _build_hand(box: VBoxContainer, c: SpellCard, width: float, height: float) -> void:
	# L icone prend tout ce que le texte ne prend pas. C est l inverse de l ancienne
	# carte, ou l icone faisait 52 px et le texte trois lignes.
	#
	# Le papier du pack applique une marge interne (content_margin) de 22 px de
	# chaque cote : la largeur REELLEMENT disponible est donc width - 2*22, pas
	# width. Sans cette soustraction l icone est demandee plus large que la place
	# qu elle a, le VBox la comprime, et elle finit plus petite qu avant.
	var interieur: float = width - 2.0 * PAPER_MARGIN
	# 104 px reserves au nom (deux lignes au plus) et au temps, separations comprises.
	var reste: float = height - 2.0 * PAPER_MARGIN - 104.0
	# Minimum 64 px : sous cette taille l icone redevient le point indistinct que
	# le testeur ne pouvait pas reconnaitre. Elle a le droit de deborder un peu
	# sur la largeur du papier, c est une image, pas du texte.
	var taille: float = clampf(minf(interieur, reste), 64.0, 104.0)
	var icone: TextureRect = CardIcons.make_rect(c, taille)
	if icone != null:
		var centre := HBoxContainer.new()
		centre.alignment = BoxContainer.ALIGNMENT_CENTER
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centre.add_child(with_type_badge(icone, c, taille))
		box.add_child(centre)

	# Nom court, autowrap COUPE : c est ce repli qui produisait "Double
	# incantatio / n" sur la capture du testeur. Un nom de deux mots est donc
	# coupe par nos soins, mot par mot, sur deux lignes au plus.
	var court: String = short_name(c)
	var interne: float = width - 2.0 * PAPER_MARGIN
	for ligne in _wrap_deux_lignes(court, interne):
		var title := UiTheme.label(ligne, _fit_name(ligne, interne), UiTheme.TEXT_DARK,
			HORIZONTAL_ALIGNMENT_CENTER, false)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Si un mot seul ne tient pas a la taille plancher, on le coupe avec des
		# points de suspension plutot que de le laisser deborder sur la voisine.
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(title)

	# Le temps d incantation en DORE et en gros : c est la donnee de decision.
	# Une carte qui part sans incantation ne montre pas un temps qu elle ne
	# subira pas : elle dit qu elle est instantanee, a une taille qui tient.
	# Le temps REEL (voir l en-tete) : celui que la barre d incantation mettra.
	var texte_temps: String = INSTANT_TEXT if _instant else hand_cast_text(c)
	var taille_temps: int = _fit_name(texte_temps, interne) if _instant else 26
	var temps := UiTheme.label(texte_temps, taille_temps,
		UiTheme.rarity_ink(c.rarity), HORIZONTAL_ALIGNMENT_CENTER, false)
	temps.name = "CastTime"
	temps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	temps.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(temps)
	_cast_label = temps


## Remet a jour le temps d une carte de MAIN : la vitesse change sans cesse, la
## carte n est pas reconstruite pour autant. N ecrit que si le texte change (au
## dixieme de seconde), donc rien a l image ou rien n a bouge. Une carte
## instantanee garde son mot.
func refresh_cast_time() -> void:
	if card == null or _instant or _cast_label == null or not is_instance_valid(_cast_label):
		return
	var t: String = hand_cast_text(card)
	if _cast_label.text != t:
		_cast_label.text = t


## « 2.7s » : le temps REEL d incantation, tel que l ecrit la carte de main.
static func hand_cast_text(c: SpellCard) -> String:
	return "%ss" % seconds_text(RunState.effective_cast_time(c))


## Temps d incantation HORS COMBAT (grimoire, deck) : base x CAST_TIME_SCALE, a
## 100 % de vitesse, sans passif ni amelioration. Le meme plancher que
## RunState.effective_cast_time, donc egal a lui a x1 sur une partie neuve.
## C est le SEUL endroit de scripts/ui qui lit base_cast_time (test_card_view).
static func menu_cast_seconds(c: SpellCard) -> float:
	return maxf(0.1, c.base_cast_time) * GameConfig.CAST_TIME_SCALE


## « 2.7 s » : le temps hors combat, pour les fiches du grimoire et du deck.
static func menu_cast_text(c: SpellCard) -> String:
	return "%s s" % seconds_text(menu_cast_seconds(c))


## Une duree au dixieme, sans « .0 » final : « 2.7 », « 3 ».
static func seconds_text(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


## DETAIL : la carte telle qu on la lit quand on a le temps.
func _build_detail(box: VBoxContainer, c: SpellCard, width: float,
		name_size: int, body_size: int) -> void:
	var icone: TextureRect = CardIcons.make_rect(c, 84.0)
	if icone != null:
		var centre := HBoxContainer.new()
		centre.alignment = BoxContainer.ALIGNMENT_CENTER
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centre.add_child(with_type_badge(icone, c, 84.0))
		# Le NOM du type, A COTE de l icone : c est en pause, carte en grand, que
		# le joueur apprend a quoi correspond le logo pose dessus. A cote et non
		# sur une ligne de plus : une ligne ajoutait ~47 px a des cartes de choix
		# deja pleines (mesure par sonde), et en tete de la ligne de rarete
		# « Ralentissement - rare - 2s » debordait des 300 px de la carte.
		var type_l := UiTheme.label(" + ".join(ElementIcons.card_type_names(c)),
			maxi(body_size - 4, 16), Color(0.30, 0.23, 0.15), HORIZONTAL_ALIGNMENT_LEFT, false)
		type_l.name = "TypeName"
		type_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		type_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centre.add_child(type_l)
		box.add_child(centre)

	# Ici le nom COMPLET : c est l ecran ou on apprend a quoi correspond l icone
	# qu on verra en main. Autowrap actif, la carte est assez large pour lui.
	var title := UiTheme.label(c.display_name, name_size, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override(&"font_size",
		_fit_size(c.display_name, name_size, width - 30.0))
	box.add_child(title)

	# La carte de detail ne s ouvre qu EN COMBAT (choix, echange de passif) : le
	# temps reel. Un PASSIF ne s incante pas : il dit a quelle vitesse il
	# s allume, ce que « 0s » ne disait pas.
	var meta_txt: String = ("%s  -  des %d %%" % [GameEnums.rarity_name(c.rarity),
		c.speed_threshold]) if c.is_passive \
		else "%s  -  %s" % [GameEnums.rarity_name(c.rarity), hand_cast_text(c)]
	var meta := UiTheme.label(meta_txt,
		body_size, UiTheme.rarity_ink(c.rarity), HORIZONTAL_ALIGNMENT_CENTER, false)
	meta.name = "Meta"
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)

	# Les ELEMENTS cites en majuscules (« degats de FEU ») recoivent leur logo
	# dans la phrase (vague 8) : le meme que le sceau de la carte et que celui
	# de la fiche du monstre. Toujours par le helper, meme sans element : une
	# seule voie pour un texte de carte (verrouille par test_text_logos).
	var riche: RichTextLabel = ElementIcons.decorated_label(c.description, body_size,
		Color(0.30, 0.23, 0.15), true)
	riche.name = "Description"
	riche.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(riche)

	if c.targeting != GameEnums.Targeting.NONE:
		var aim := UiTheme.label(_targeting_hint(c.targeting), body_size - 2,
			Color(0.18, 0.36, 0.70), HORIZONTAL_ALIGNMENT_CENTER)
		aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(aim)


## LOGO DE TYPE (vague 5), pose EN SURIMPRESSION dans le coin haut-gauche de
## l icone. Pas une ligne de plus : la carte de main fait 118 px et chaque ligne
## y a ete gagnee de haute lutte (voir l en-tete). Le coin haut-gauche est celui
## que les icones du pack laissent le plus souvent vide, et celui que l oeil lit
## en premier.
##
## Taille : la moitie de l icone, jamais sous 40 px (relu en capture : a 32 px le
## sceau se lisait mal sur une carte de main) — en dessous la FORME du cadre,
## qui porte l information pour un joueur daltonien, ne se lit plus.
const BADGE_RATIO: float = 0.5
const BADGE_MIN: float = 40.0


## Statique : le grimoire pose le meme sceau sur ses vignettes.
static func with_type_badge(icone: TextureRect, c: SpellCard, taille: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(taille, taille)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ancres ET marges : `set_anchors_preset` seul garde les anciennes marges, et
	# l icone deborderait d une largeur entiere.
	icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icone)
	var cote: float = maxf(taille * BADGE_RATIO, BADGE_MIN)
	var badge: TextureRect = ElementIcons.make(c.spell_type(), cote)
	if badge != null:
		badge.name = "TypeBadge"
		# Deborde legerement du coin : colle a l icone, il la recouvrirait
		# davantage ; decale, il se lit comme un sceau pose SUR la carte.
		# Marges ecrites une a une : c est la seule forme que la mise en page ne
		# reecrit pas dans un Control qui n est pas un conteneur.
		badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge.offset_left = -cote * 0.22
		badge.offset_top = -cote * 0.22
		badge.offset_right = badge.offset_left + cote
		badge.offset_bottom = badge.offset_top + cote
		holder.add_child(badge)
	return holder


## Nom court d une carte, pour la main. On retire les mots de liaison, qui ne
## distinguent aucune carte des autres mais coutent une ligne entiere sur 120 px.
## "Boule de feu" -> "Boule feu", "Mur de pierre" -> "Mur pierre".
##
## Le nom reste DERIVE et non stocke : SpellCard est une Resource partagee avec le
## reste du jeu, lui ajouter un champ obligerait a regenerer les 44 .tres.
static func short_name(c: SpellCard) -> String:
	if c == null:
		return ""
	var mots: PackedStringArray = []
	for mot in c.display_name.split(" ", false):
		if LIAISONS.has(String(mot).to_lower()):
			continue
		mots.append(String(mot))
	# Un nom entierement fait de liaisons n existe pas, mais un nom d un seul mot
	# qui EST une liaison le ferait disparaitre : on garde alors l original.
	if mots.is_empty():
		return c.display_name
	return " ".join(mots)


## Coupe un nom court sur DEUX lignes au plus, aux espaces. Godot ne sait replier
## qu en AUTOWRAP, qui coupe LETTRE PAR LETTRE quand un seul mot depasse — c est
## le defaut qu on corrige. On decide donc nous-memes ou couper.
##
## Une ligne si le nom entier tient a une taille correcte ; sinon un mot par
## ligne, et au-dela de deux mots les suivants rejoignent la seconde ligne.
func _wrap_deux_lignes(text: String, width: float) -> PackedStringArray:
	var mots: PackedStringArray = text.split(" ", false)
	if mots.size() <= 1:
		return PackedStringArray([text])
	# Le nom entier sur une ligne, s il y tient sans descendre sous le plancher.
	if _fit_name(text, width) > NAME_MIN_SIZE:
		return PackedStringArray([text])
	var premiere: String = mots[0]
	var seconde: String = " ".join(mots.slice(1))
	return PackedStringArray([premiere, seconde])


## Plus grande taille pour laquelle le nom court tient sur UNE ligne dans `width`.
## Borne en bas par NAME_MIN_SIZE : sous cette taille le texte n est plus lisible,
## et on prefere le tronquer (OVERRUN_TRIM_ELLIPSIS) plutot que de le miniaturiser.
func _fit_name(text: String, width: float) -> int:
	var font: Font = UiTheme.font()
	if font == null:
		font = get_theme_default_font()
	if font == null or text == "":
		return NAME_MIN_SIZE
	var depart: int = 26
	var largeur: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, depart).x
	if largeur <= width or largeur <= 0.0:
		return depart
	# La largeur d une chaine est proportionnelle a la taille de police.
	return clampi(int(floor(float(depart) * width / largeur)), NAME_MIN_SIZE, depart)


## Plus grande taille de police pour laquelle le nom tient en deux lignes dans
## `width` (mode DETAIL, ou l autowrap est actif).
func _fit_size(text: String, wanted: int, width: float) -> int:
	var font: Font = UiTheme.font()
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return wanted
	var longest: float = 0.0
	for word in text.split(" ", false):
		longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, wanted).x)
	if longest <= width or longest <= 0.0:
		return wanted
	return clampi(int(floor(float(wanted) * width / longest)), 16, wanted)


func _targeting_hint(t: int) -> String:
	match t:
		GameEnums.Targeting.POSITION: return "glisser sur une zone"
		GameEnums.Targeting.DIRECTION: return "glisser pour viser"
		GameEnums.Targeting.TARGET: return "glisser sur un monstre"
	return ""


func _on_resized() -> void:
	pivot_offset = size * 0.5


func _on_enter() -> void:
	_hovered = true
	z_index = 20
	_animate(Vector2(HOVER_SCALE, HOVER_SCALE))


func _on_exit() -> void:
	_hovered = false
	z_index = 0
	_animate(Vector2.ONE)


func _animate(target: Vector2) -> void:
	if not Fx.enabled():
		scale = target
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, 0.10).set_trans(Tween.TRANS_QUAD)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit(card)

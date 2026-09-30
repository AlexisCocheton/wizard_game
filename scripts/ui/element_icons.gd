class_name ElementIcons
extends RefCounted
## LOGOS D ELEMENT ET DE TYPE (vague 5) — le seul endroit qui repond a « quelle
## image pour cet element » et « quel nom pour ce type ».
##
## Le bestiaire ecrivait « Resiste : feu (-15 %) » et la carte ne disait jamais
## son element : le joueur devait retenir des mots et les rapprocher de memoire.
## Le meme logo est maintenant pose aux deux endroits — sur la carte, et devant
## le pourcentage de la fiche du monstre — et c est l IMAGE qu on rapproche.
##
## Chaque logo porte FORME + COULEUR + image (tools/assets/extract_elements.py) :
## la forme du cadre suffit a un joueur daltonien, la couleur suffit aux autres,
## et deux elements ne partagent jamais une forme (verifie par test_elements).
##
## Cles : celles de SpellCard.spell_type() et SpellCard.type_of_tag().

const DIR := "res://assets/icons/element_"

## Les six elements, le ralentissement, puis les types non elementaires.
const KEYS: Array[StringName] = [
	&"physique", &"feu", &"givre", &"arcane", &"poison", &"foudre",
	&"ralentissement", &"invocation", &"terrain", &"grimoire", &"passif",
]

## Forme du cadre de chaque logo. Donnee ici en clair (et pas seulement dans le
## PNG) pour que test_elements verifie que deux elements ne partagent jamais la
## meme : c est la promesse faite aux joueurs daltoniens. Les types non
## elementaires partagent l ECU expres : ils ne se confondent pas avec un
## element, et le joueur apprend une regle au lieu de onze formes.
const SHAPES: Dictionary = {
	&"physique": "carre", &"feu": "triangle", &"givre": "hexagone",
	&"arcane": "losange", &"poison": "cercle", &"foudre": "etoile",
	&"ralentissement": "sablier",
	&"invocation": "ecu", &"terrain": "ecu", &"grimoire": "ecu", &"passif": "ecu",
}


## Chemin du logo, "" si la cle est inconnue ou le fichier absent.
static func path(key: StringName) -> String:
	if key == &"":
		return ""
	var p: String = DIR + String(key) + ".png"
	return p if ResourceLoader.exists(p) else ""


static func texture(key: StringName) -> Texture2D:
	var p: String = path(key)
	return SheetLib.texture(p) if p != "" else null


static func texture_for_tag(tag: int) -> Texture2D:
	return texture(SpellCard.type_of_tag(tag))


## Nom joueur du type, avec majuscule : c est un titre, pas un mot de phrase.
static func type_name(key: StringName) -> String:
	match key:
		&"physique": return "Physique"
		&"feu": return "Feu"
		&"givre": return "Givre"
		&"arcane": return "Arcane"
		&"poison": return "Poison"
		&"foudre": return "Foudre"
		&"ralentissement": return "Ralentissement"
		&"invocation": return "Invocation"
		&"terrain": return "Terrain"
		&"grimoire": return "Grimoire"
		&"passif": return "Passif"
	return ""


## Tous les noms de type d une carte : le premier element, puis les suivants
## (le Meteore est Feu et Physique, et la resistance lue est la PIRE des deux —
## la fiche doit donc les nommer toutes les deux).
static func card_type_names(card: SpellCard) -> Array[String]:
	var out: Array[String] = []
	if card == null:
		return out
	var principal: StringName = card.spell_type()
	if principal != &"":
		out.append(type_name(principal))
	for t in card.tags:
		if t in GameEnums.ELEMENTS:
			var nom: String = type_name(SpellCard.type_of_tag(t))
			if not out.has(nom):
				out.append(nom)
	return out


## Logo pret a poser dans une interface. Le nom du type est porte en info-bulle :
## l image suffit a jouer, le mot sert a l apprendre.
static func make(key: StringName, px: float) -> TextureRect:
	var tex: Texture2D = texture(key)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(px, px)
	tr.size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.tooltip_text = type_name(key)
	return tr


## Une resistance : logo de l element + pourcentage signe (« -53 % », « +58 % »).
## Une IMMUNITE n a pas de chiffre : le mot du groupe (« Immunise ») le dit deja,
## et « -100 % » se lirait comme une erreur de calcul.
static func resistance_chip(tag: int, mult: float, px: float, ink: Color,
		font_size: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo: TextureRect = make(SpellCard.type_of_tag(tag), px)
	if logo != null:
		h.add_child(logo)
	var txt: String = percent_text(mult)
	if txt != "":
		var l: Label = UiTheme.label(txt, font_size, ink, HORIZONTAL_ALIGNMENT_LEFT, false)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
	return h


## « -53 % » / « +58 % » / "" (immunite ou neutre).
static func percent_text(mult: float) -> String:
	if mult <= 0.0 or is_equal_approx(mult, 1.0):
		return ""
	if mult < 1.0:
		return "-%d %%" % int(round((1.0 - mult) * 100.0))
	return "+%d %%" % int(round((mult - 1.0) * 100.0))

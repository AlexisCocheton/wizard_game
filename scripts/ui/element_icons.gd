class_name ElementIcons
extends RefCounted
## LOGOS D ELEMENT ET DE TYPE (vague 5, huit elements en vague 8) — le seul
## endroit qui repond a « quelle image pour cet element » et « quel nom pour ce
## type ».
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
## LOGOS DANS LE TEXTE (vague 8, demande du co-auteur) : « feu -30 %  eau
## +60 % » s ecrit avec les logos DANS la phrase (`inline`, `resist_bbcode`,
## `decorate`) et s affiche dans un RichTextLabel (`rich_label`). Un seul
## helper pour toute l interface : bestiaire, legende du Cameleon, description
## des cartes. Ecrire le BBCode a la main a cote ferait diverger les tailles.
##
## Cles : celles de SpellCard.spell_type() et SpellCard.type_of_tag().

const DIR := "res://assets/icons/element_"

## Les huit elements dans l ordre du co-auteur, le ralentissement, puis les
## types non elementaires (repli d une carte sans element, passif sans element).
const KEYS: Array[StringName] = [
	&"feu", &"eau", &"nature", &"vent", &"foudre", &"glace", &"arcane", &"poison",
	&"ralentissement", &"invocation", &"terrain", &"grimoire", &"passif",
]

## Forme du cadre de chaque logo. Donnee ici en clair (et pas seulement dans le
## PNG) pour que test_elements verifie que deux elements ne partagent jamais la
## meme : c est la promesse faite aux joueurs daltoniens. Les types non
## elementaires partagent l ECU expres : ils ne se confondent pas avec un
## element, et le joueur apprend une regle au lieu de treize formes.
##
## Vague 8 : la glace garde l hexagone de l ancien givre (meme element), la
## NATURE prend le carre de l ancien physique (la pierre, le bloc), l EAU une
## goutte et le VENT une capsule couchee (une rafale) — deux silhouettes qu aucun
## autre cadre n a, lisibles a 28 px.
const SHAPES: Dictionary = {
	&"feu": "triangle", &"eau": "goutte", &"nature": "carre", &"vent": "capsule",
	&"foudre": "etoile", &"glace": "hexagone", &"arcane": "losange", &"poison": "cercle",
	&"ralentissement": "sablier",
	&"invocation": "ecu", &"terrain": "ecu", &"grimoire": "ecu", &"passif": "ecu",
}

## Taille des logos DANS le texte, en pixels, relative a la police : un logo
## plus petit que la hauteur d une majuscule ne se lit plus sur telephone, un
## logo plus grand decale les lignes. 1,5 x la taille de police, verifie en
## capture a FONT_SMALL et FONT_BODY.
const INLINE_RATIO: float = 1.5
## Espace entre deux resistances d une meme ligne : deux espaces insecables, le
## « feu -30 %  eau +60 % » du co-auteur. Deux insecables puis une espace
## ordinaire : la ligne ne peut se couper QU ENTRE deux resistances (vu en
## capture : sans espace ordinaire, Godot coupait apres le « + » de « +27 % »).
const INLINE_GAP: String = "\u00a0\u00a0 "


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
		&"feu": return "Feu"
		&"eau": return "Eau"
		&"nature": return "Nature"
		&"vent": return "Vent"
		&"foudre": return "Foudre"
		&"glace": return "Glace"
		&"arcane": return "Arcane"
		&"poison": return "Poison"
		&"ralentissement": return "Ralentissement"
		&"invocation": return "Invocation"
		&"terrain": return "Terrain"
		&"grimoire": return "Grimoire"
		&"passif": return "Passif"
	return ""


## Les noms de type d une carte. Depuis la vague 8 une carte n a qu UN element,
## donc un seul nom ; la forme en tableau reste pour les ecrans qui la joignent.
static func card_type_names(card: SpellCard) -> Array[String]:
	var out: Array[String] = []
	if card == null:
		return out
	var principal: StringName = card.spell_type()
	if principal != &"":
		out.append(type_name(principal))
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


## Une ligne de fiche de monstre : logo + ce que la resistance fait EN CLAIR.
## Voir `effect_text` ; c est la version longue de `resistance_chip`, pour la
## fiche du bestiaire ou l on a le temps de lire.
static func resistance_row(tag: int, mult: float, px: float, ink: Color,
		font_size: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo: TextureRect = make(SpellCard.type_of_tag(tag), px)
	if logo != null:
		h.add_child(logo)
	var l: Label = UiTheme.label(effect_text(tag, mult), font_size, ink,
		HORIZONTAL_ALIGNMENT_LEFT, false)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return h


## Ce qu une resistance fait, en clair, avec le NOM de l element (le logo seul ne
## s apprend pas sans lui) :
##   element resiste    « Glace : -53 % degats et effets »
##   element immunise   « Poison : ni degats ni effets »
##   element faible     « Feu : +58 % degats » — une faiblesse ne renforce pas
##                      le controle (EnemyDef.control_factor, plafond a 1)
##   ralentissement     « Ralentissement : jamais ralenti ni fige » / « -70 % »
## Les seuils suivent Enemy.STUN_RESIST_THRESHOLD : a partir de la, le monstre
## n est plus fige par cet element, et la ligne le dit.
static func effect_text(tag: int, mult: float) -> String:
	var nom: String = type_name(SpellCard.type_of_tag(tag))
	if tag == GameEnums.DamageTag.SLOW:
		if mult <= 0.0:
			return "%s : jamais ralenti ni fige" % nom
		var txt: String = "%s : %s" % [nom, percent_text(mult)]
		if mult <= Enemy.STUN_RESIST_THRESHOLD:
			txt += ", jamais fige"
		return txt
	if mult <= 0.0:
		return "%s : ni degats ni effets" % nom
	if mult < 1.0:
		var t: String = "%s : %s degats et effets" % [nom, percent_text(mult)]
		if mult <= Enemy.STUN_RESIST_THRESHOLD:
			t += ", jamais fige"
		return t
	return "%s : %s degats" % [nom, percent_text(mult)]


## « -53 % » / « +58 % » / "" (immunite ou neutre).
static func percent_text(mult: float) -> String:
	if mult <= 0.0 or is_equal_approx(mult, 1.0):
		return ""
	if mult < 1.0:
		return "-%d %%" % int(round((1.0 - mult) * 100.0))
	return "+%d %%" % int(round((mult - 1.0) * 100.0))


# --- LOGOS DANS LE TEXTE (vague 8) ------------------------------------------

## Taille en pixels d un logo pose dans un texte de cette police.
static func inline_px(font_size: int) -> int:
	return int(round(float(font_size) * INLINE_RATIO))


## Le logo d un tag (ou d une cle de type) en BBCode, "" si aucun logo.
## `[img=LxH]` : largeur ET hauteur imposees, sinon le PNG de 128 px s afficherait
## a sa taille et ferait exploser la ligne.
static func inline(tag_or_key: Variant, px: int) -> String:
	var key: StringName = tag_or_key if tag_or_key is StringName \
		else SpellCard.type_of_tag(int(tag_or_key))
	var p: String = path(key)
	if p == "":
		return ""
	return "[img=%dx%d]%s[/img]" % [px, px, p]


## Le logo suivi du nom de l element en minuscules : « [logo] feu ». Le mot reste
## a cote du logo, pour apprendre l image (meme raison que `effect_text`).
static func inline_named(tag: int, px: int) -> String:
	var logo: String = inline(tag, px)
	var nom: String = GameEnums.tag_name(tag)
	return (logo + "\u00a0" + nom) if logo != "" else nom


## « [logo] feu -30 %   [logo] eau +60 % » : une suite de resistances sur UNE
## ligne, la forme demandee par le co-auteur. `items` = [{tag, mult}] (la forme
## de BestiaryLore.resistance_groups). Une immunite s ecrit sans chiffre : le
## titre du groupe le dit deja.
static func resist_bbcode(items: Array, px: int) -> String:
	var parts: PackedStringArray = []
	for it in items:
		var tag: int = int(it.get("tag", -1))
		var mult: float = float(it.get("mult", 1.0))
		var morceau: String = inline_named(tag, px)
		var pct: String = percent_text(mult)
		if pct != "":
			# Insecable entre le nom et le chiffre, et un « gluon » (U+2060) apres
			# le signe : « + » est une occasion de coupure pour le moteur de texte.
			morceau += "\u00a0" + pct.substr(0, 1) + "\u2060" + pct.substr(1).replace(" ", "\u00a0")
		parts.append(morceau)
	return INLINE_GAP.join(parts)


## Toutes les resistances d un monstre en une ligne, de la plus dangereuse pour
## le joueur (immunite) a la plus avantageuse (faiblesse), elements puis
## ralentissement. "" si le monstre n a aucun ecart.
static func resist_line(def: EnemyDef, px: int) -> String:
	var items: Array = []
	for g in BestiaryLore.resistance_groups(def):
		items.append_array(g["items"])
	return resist_bbcode(items, px)


## Les mots d ELEMENT ecrits en majuscules dans un texte de carte (« degats de
## FEU ») recoivent leur logo devant eux. Seules les MAJUSCULES sont visees :
## c est la convention des descriptions pour nommer un element, et un « feu »
## en minuscules dans une phrase n est pas une annonce d element.
const _ELEMENT_WORDS: Dictionary = {
	"FEU": GameEnums.DamageTag.FIRE, "EAU": GameEnums.DamageTag.WATER,
	"NATURE": GameEnums.DamageTag.NATURE, "VENT": GameEnums.DamageTag.WIND,
	"FOUDRE": GameEnums.DamageTag.LIGHTNING, "GLACE": GameEnums.DamageTag.ICE,
	"ARCANE": GameEnums.DamageTag.ARCANE, "POISON": GameEnums.DamageTag.POISON,
}


static func decorate(text: String, px: int) -> String:
	var re := RegEx.new()
	re.compile("\\b(FEU|EAU|NATURE|VENT|FOUDRE|GLACE|ARCANE|POISON)\\b")
	var out: String = ""
	var debut: int = 0
	for m in re.search_all(text):
		var mot: String = m.get_string(1)
		out += text.substr(debut, m.get_start(1) - debut)
		var logo: String = inline(int(_ELEMENT_WORDS[mot]), px)
		out += (logo + "\u00a0" + mot) if logo != "" else mot
		debut = m.get_end(1)
	out += text.substr(debut)
	return out


## Le texte d origine d une phrase passee par `decorate` / `inline_named` : les
## logos et l espace insecable qui les suit retires. Sert aux tests et a tout
## lecteur qui veut comparer une phrase affichee a sa source.
static func strip_inline(bbcode: String) -> String:
	var re := RegEx.new()
	re.compile("\\[img=[^\\]]*\\][^\\[]*\\[/img\\]\u00a0?")
	var s: String = re.sub(bbcode, "", true)
	return s.trim_prefix("[center]").trim_suffix("[/center]")


## Un RichTextLabel pret a recevoir ces logos : BBCode actif, hauteur ajustee au
## contenu (sinon il s ecrase a 0 dans un VBox), retour a la ligne, aucune
## interaction, la police et la taille du theme (jamais un nombre en dur : voir
## gotchas, « une taille de police ecrite en dur echappe au theme »).
## Le centrage passe par la balise [center] : c est la seule forme que le
## RichTextLabel de Godot 4.4 respecte pour une ligne qui contient des images.
static func rich_label(bbcode: String, font_size: int, ink: Color,
		center: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override(&"normal_font_size", font_size)
	r.add_theme_color_override(&"default_color", ink)
	var f: Font = UiTheme.font()
	if f != null:
		r.add_theme_font_override(&"normal_font", f)
	r.text = ("[center]%s[/center]" % bbcode) if center else bbcode
	return r

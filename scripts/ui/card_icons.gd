class_name CardIcons
extends RefCounted
## Icone de chaque carte : une image reconnaissable au premier coup d oeil.
##
## Les cartes ne se distinguaient que par leur nom, ecrit petit sur une carte de
## 120 px de large. En pleine vague, le joueur ne pouvait pas reconnaitre un sort
## sans le lire, ce qui est exactement le moment ou il n a pas le temps de lire.
##
## Les icones sont les FEUILLES D EFFETS deja embarquees : chaque sort porte ainsi
## sa propre signature visuelle, la meme qu il affichera sur le terrain. Aucune
## image nouvelle a produire, et la carte annonce ce qu elle va faire.

const FX := "res://assets/fx/"

## Carte -> feuille. Il y a plus de cartes que de feuilles : deux cartes peuvent
## donc partager une feuille, mais JAMAIS avec la meme teinte (voir TINTS). C est
## le couple feuille+teinte qui doit etre unique.
const BY_CARD: Dictionary = {
	# Communes
	&"arcane_bolt": "magic8",
	&"spark": "magickahit",
	&"fireball": "explosion_d",
	&"ember_pool": "fire",
	&"frost_field": "freezing",
	&"frost_rain": "magicbubbles",
	&"piercing_arrow": "arrow",
	# Rares
	&"stone_wall": "ts_dust_01",
	&"brazier": "firespin",
	&"meteor": "explosion_e",
	&"temporal_drag": "midnight",
	&"cycle_of_thought": "casting",
	&"about_face": "vortex",
	&"focus": "protectioncircle",
	&"quickening": "brightfire",
	&"mana_flow": "bluefire",
	# Epiques
	&"weakness_mark": "felspell",
	&"resonance": "weaponhit",
	&"deep_freeze": "ts_fire_02",
	&"deep_focus": "protectioncircle",  # distingue de focus par sa teinte
	&"mirror_apprentice": "heal_effect",
	&"deck_purge": "explosion_c",
	&"reckless_bargain": "ts_explosion_01",
	# Legendaires
	&"time_rift": "magicspell",
	&"hourglass_shard": "midnight",
	# Passifs
	&"pass_celerity": "brightfire",
	&"pass_companion": "heal_effect",
	&"pass_dual": "magic8",
}

## Repli par element, pour toute carte ajoutee apres coup : mieux vaut une icone
## coherente avec le type de degats qu aucune icone du tout.
const BY_TAG: Dictionary = {
	GameEnums.DamageTag.FIRE: "fire",
	GameEnums.DamageTag.FROST: "freezing",
	GameEnums.DamageTag.ARCANE: "magic8",
	GameEnums.DamageTag.PHYSICAL: "arrow",
	GameEnums.DamageTag.SLOW: "midnight",
}


## Teinte par carte, quand plusieurs cartes partagent une feuille. Blanc par defaut.
const TINTS: Dictionary = {
	# Famille arcane : meme feuille, teintes distinctes.
	&"maelstrom": Color(0.60, 0.45, 1.00),
	&"echo_of_the_hand": Color(1.00, 0.85, 0.45),
	&"pass_dual": Color(0.55, 1.00, 0.90),
	# Famille feu.
	&"meteor_storm": Color(1.00, 0.55, 0.25),
	&"venom_mire": Color(0.55, 1.00, 0.40),
	# Famille physique.
	&"bastion": Color(0.70, 0.75, 0.85),
	&"repulsion_wave": Color(0.85, 0.95, 1.00),
	# Famille soin / lumiere.
	&"purifying_light": Color(1.00, 1.00, 0.70),
	&"pass_companion": Color(0.70, 1.00, 0.75),
	# Famille temps.
	&"hourglass_shard": Color(1.00, 0.80, 0.35),
	&"twin_channeling": Color(0.75, 0.85, 1.00),
	&"arcane_insight": Color(0.90, 0.70, 1.00),
	&"deep_focus": Color(0.65, 0.80, 1.00),
	&"pass_celerity": Color(1.00, 0.95, 0.60),
}


## Teinte de l icone : c est elle qui distingue deux cartes partageant une feuille.
##
## Sans entree explicite, la teinte est DERIVEE de l identifiant. Le contenu du jeu
## grandit (histoire, actes, cartes liees aux monstres) et lister chaque carte a la
## main condamnerait toute nouvelle carte a l icone d une autre.
static func tint_for(card: SpellCard) -> Color:
	if card == null:
		return Color.WHITE
	if TINTS.has(card.id):
		return TINTS[card.id]
	return _derived_tint(String(card.id))


## Teinte stable et lisible tiree du nom : meme carte, meme couleur a chaque
## lancement. Saturation et luminosite bornees pour rester visible sur le papier.
static func _derived_tint(id: String) -> Color:
	if id == "":
		return Color.WHITE
	var h: int = 0
	for i in id.length():
		h = (h * 31 + id.unicode_at(i)) % 100003
	var teinte: float = float(h % 360) / 360.0
	return Color.from_hsv(teinte, 0.45, 1.0)


## Signature unique d une carte : feuille + teinte.
static func signature(card: SpellCard) -> String:
	var t: Color = tint_for(card)
	return "%s@%d,%d,%d" % [for_card(card), int(t.r * 255), int(t.g * 255), int(t.b * 255)]


## Nom de feuille pour une carte, "" si rien ne convient.
static func for_card(card: SpellCard) -> String:
	if card == null:
		return ""
	if BY_CARD.has(card.id):
		return String(BY_CARD[card.id])
	for tag in card.tags:
		if BY_TAG.has(tag):
			return String(BY_TAG[tag])
	return "magicspell"


## Premiere case de la feuille : une icone est une image fixe, pas une animation.
static func texture(sheet: String) -> Texture2D:
	if sheet == "":
		return null
	var tex: Texture2D = SheetLib.texture(FX + sheet + ".png")
	if tex == null:
		return null
	var cell: int = _cell_of(sheet, tex)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, cell, mini(cell, int(tex.get_height())))
	return at


## Les feuilles d effets sont soit des grilles de 100 px, soit des bandes dont la
## case fait la hauteur de l image.
static func _cell_of(sheet: String, tex: Texture2D) -> int:
	if Fx.STRIPS.has(sheet):
		return int(Fx.STRIPS[sheet][1])
	var w: int = int(tex.get_width())
	var h: int = int(tex.get_height())
	if w % 100 == 0 and h % 100 == 0:
		return 100
	return mini(w, h)


## Vignette prete a poser dans une interface.
static func make_rect(card: SpellCard, size: float) -> TextureRect:
	var tex: Texture2D = texture(for_card(card))
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = tint_for(card)
	return tr

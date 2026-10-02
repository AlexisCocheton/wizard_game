class_name TesterSheet
extends VBoxContainer
## LA FICHE EDITABLE d une carte, d un monstre ou d un niveau.
##
## Generique : les champs viennent de TesterOverrides.exported_properties()
## (get_property_list), dans l ordre du script et avec ses groupes
## (@export_group), comme l inspecteur de l editeur Godot. Un champ ajoute
## demain a EnemyDef apparait ici sans une ligne de plus.
##
## Ce qui n est PAS generique, et pourquoi :
##   - les EFFETS d une carte : une section par brique, avec le SENS de sa
##     magnitude (un total, un debit, un pourcentage selon le verbe — le piege
##     documente dans docs/outil_donnees.md) ;
##   - les RESISTANCES d un monstre : un dictionnaire DamageTag -> facteur, montre
##     element par element, avec la valeur JOUEE (deja accentuee) ;
##   - les VAGUES d un niveau : TesterWaveEditor ;
##   - les OBJECTIFS d un niveau : leurs parametres sont ceux d un ObjectiveDef
##     PARTAGE entre niveaux (DEC-023), on le dit a l ecran.
##
## Les groupes "lourds" (mecaniques de boss...) sont REPLIES par defaut : un
## monstre ordinaire a cent champs, dont quatre-vingts a zero. Ouvrir un groupe
## est un toucher.

const INK: Color = TesterField.INK
const INK_NOTE: Color = TesterField.INK_NOTE

## Groupes ouverts d office : ce qu on regle le plus souvent.
const OPEN_GROUPS: Array[String] = ["", "Apparence", "Resistances", "Effets", "Vagues"]

## Sens de `magnitude` par verbe (repris de tools/data_sheet.gd).
const MAGNITUDE_SENS: Dictionary = {
	"damage_single": "degats au total", "pierce_line": "degats par cible touchee",
	"knockback": "degats au total", "stun_zone": "degats au total",
	"damage_per_enemy": "degats par monstre", "meteor_storm": "degats par impact",
	"summon_ally": "degats de l allie", "taunt_prop": "degats au total",
	"ground_zone": "degats PAR SECONDE (x duree = total)",
	"slow_enemy_gauge": "pourcentage de ralentissement", "draw_cards": "nombre de cartes",
}

var res: Resource = null
var target: String = ""
var host: Node = null
## Groupe -> conteneur de ses champs (pour plier / deplier).
var _groups: Dictionary = {}
var _preview_box: Control = null


func setup(p_res: Resource, p_host: Node) -> TesterSheet:
	res = p_res
	host = p_host
	target = TesterOverrides.target_of(res)
	add_theme_constant_override(&"separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	return self


func _build() -> void:
	for c in get_children().duplicate():
		remove_child(c)
		c.free()
	_groups.clear()
	_build_header()
	if res is SpellCard:
		_build_generic(["effects"])
		_build_effects()
	elif res is EnemyDef:
		_build_generic(["resistances"])
		_build_resistances()
	elif res is LevelDef:
		_build_generic(["waves"])
		_build_waves()
		_build_objectives()


## --- EN-TETE + APERCU ------------------------------------------------------

func _build_header() -> void:
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override(&"separation", 18)
	add_child(tete)
	_preview_box = CenterContainer.new()
	_preview_box.custom_minimum_size = Vector2(240, 240)
	tete.add_child(_preview_box)
	_refresh_preview()
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(col)
	var nom: Variant = res.get("display_name")
	col.add_child(UiTheme.label(String(nom), UiTheme.FONT_BODY, INK))
	col.add_child(UiTheme.label(target, UiTheme.FONT_SMALL, INK_NOTE))
	var n: int = 0
	for e in TesterOverrides.entries():
		if e["target"] == target:
			n += 1
	if n > 0:
		col.add_child(UiTheme.label("%d reglage%s sur cette fiche" % [n, "s" if n > 1 else ""],
			UiTheme.FONT_SMALL, TesterField.INK_CHANGED))
		var tout := Button.new()
		tout.text = "TOUT REMETTRE A L ORIGINE"
		tout.custom_minimum_size = Vector2(0, TesterField.TOUCH)
		tout.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		tout.pressed.connect(func() -> void:
			TesterOverrides.remove_all_for(target)
			_build.call_deferred())
		col.add_child(tout)
	if not TesterOverrides.is_active():
		col.add_child(UiTheme.label("Mode testeur ETEINT : ces reglages ne sont pas joues.",
			UiTheme.FONT_SMALL, TesterField.INK_CHANGED))


## Apercu : le monstre tel que le bestiaire le dessine (apparence et teinte
## comprises), l icone telle que la main l affiche.
func _refresh_preview() -> void:
	if _preview_box == null:
		return
	for c in _preview_box.get_children():
		c.queue_free()
	var art: Control = null
	if res is EnemyDef:
		art = BestiaryLore.portrait_of(res as EnemyDef, 230.0, true)
	elif res is SpellCard:
		art = CardIcons.make_rect(res as SpellCard, 200.0)
	if art != null:
		_preview_box.add_child(art)


## --- CHAMPS GENERIQUES ------------------------------------------------------

func _build_generic(skip: Array) -> void:
	var groupe: String = ""
	var box: VBoxContainer = _group_box("")
	for p: Dictionary in TesterOverrides.exported_properties(res):
		if p.has("group"):
			groupe = String(p["group"])
			box = _group_box(groupe)
			continue
		var name: String = p["name"]
		if name in skip or name in TesterOverrides.SKIP_FIELDS:
			continue
		# Seuil de vitesse : n a de sens que pour un passif (voir spell_card.gd).
		if name == "speed_threshold" and res is SpellCard and not (res as SpellCard).is_passive:
			continue
		if TesterOverrides.resolve_field(res, name).is_empty():
			continue
		_add_field(box, name, TesterOverrides.label_of(name))
		# La teinte du sprite se regle a cote de l apparence (champ virtuel).
		if name == "anim_key" and res is EnemyDef:
			_add_field(box, "tint", "teinte du sprite")


func _add_field(box: VBoxContainer, field: String, label: String) -> TesterField:
	var f: TesterField = TesterField.new().setup(target, field, label, host)
	f.changed.connect(_on_field_changed)
	box.add_child(f)
	return f


func _on_field_changed() -> void:
	_refresh_preview.call_deferred()


## Un groupe = un bouton titre qui plie / deplie, puis ses champs.
func _group_box(groupe: String) -> VBoxContainer:
	if _groups.has(groupe):
		return _groups[groupe]
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	if groupe != "":
		var titre := Button.new()
		titre.toggle_mode = true
		var ouvert: bool = groupe in OPEN_GROUPS
		titre.button_pressed = ouvert
		titre.text = ("v  " if ouvert else ">  ") + groupe.to_upper()
		titre.alignment = HORIZONTAL_ALIGNMENT_LEFT
		titre.custom_minimum_size = Vector2(0, TesterField.TOUCH)
		titre.toggled.connect(func(on: bool) -> void:
			box.visible = on
			titre.text = ("v  " if on else ">  ") + groupe.to_upper())
		add_child(titre)
		box.visible = ouvert
	add_child(box)
	_groups[groupe] = box
	return box


## --- CARTE : EFFETS -----------------------------------------------------------

func _build_effects() -> void:
	var card: SpellCard = res
	var box: VBoxContainer = _group_box("Effets")
	if card.effects.is_empty():
		box.add_child(UiTheme.label("Aucun effet.", UiTheme.FONT_SMALL, INK_NOTE))
	for i in card.effects.size():
		var e: EffectSpec = card.effects[i]
		if e == null:
			continue
		var titre: Label = UiTheme.label("EFFET %d : %s" % [i + 1, e.key], UiTheme.FONT_BODY, INK)
		box.add_child(titre)
		box.add_child(UiTheme.label("magnitude = %s" % MAGNITUDE_SENS.get(String(e.key),
			"intensite (sens selon le verbe)"), UiTheme.FONT_SMALL, INK_NOTE))
		var base: String = "effects/%d/" % i
		_add_field(box, base + "key", "verbe")
		_add_field(box, base + "magnitude", "magnitude")
		_add_field(box, base + "duration", "duree (s)")
		_add_field(box, base + "radius", "rayon (px)")
		var cles: Array = e.params.keys()
		cles.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for k in cles:
			_add_field(box, base + "params/" + String(k), "parametre %s" % k)


## --- MONSTRE : RESISTANCES ----------------------------------------------------

func _build_resistances() -> void:
	var box: VBoxContainer = _group_box("Resistances")
	box.add_child(UiTheme.label("Facteur de degats JOUE : 1 = normal, 0,5 = moitie, 0 = immunite, "
		+ "2 = double. C est la valeur deja accentuee (EnemyDef.accentuate).",
		UiTheme.FONT_SMALL, INK_NOTE))
	for t in TesterOverrides.RESIST_TAGS:
		var nom: String = GameEnums.tag_name(t)
		_add_field(box, "resistances/" + nom, nom)


## --- NIVEAU : VAGUES ET OBJECTIFS ---------------------------------------------

func _build_waves() -> void:
	var box: VBoxContainer = _group_box("Vagues")
	var ed: TesterWaveEditor = TesterWaveEditor.new().setup(res as LevelDef, host)
	box.add_child(ed)


func _build_objectives() -> void:
	var lvl: LevelDef = res
	var box: VBoxContainer = _group_box("Parametres des objectifs")
	for i in lvl.objectives.size():
		var o: ObjectiveDef = lvl.objectives[i]
		if o == null:
			continue
		var partages: int = 0
		for l2: LevelDef in ContentDB.levels.values():
			if l2.objectives.has(o):
				partages += 1
		box.add_child(UiTheme.label("OBJECTIF %d : %s" % [i + 1, ObjectiveChecker.label(o)],
			UiTheme.FONT_SMALL, INK))
		if partages > 1:
			box.add_child(UiTheme.label("Partage par %d niveaux : le regler les change tous."
				% partages, UiTheme.FONT_SMALL, TesterField.INK_CHANGED))
		var cles: Array = o.params.keys()
		cles.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		var t: String = TesterOverrides.target_of(o)
		for k in cles:
			var f: TesterField = TesterField.new().setup(t, "params/" + String(k),
				"parametre %s" % k, host)
			box.add_child(f)

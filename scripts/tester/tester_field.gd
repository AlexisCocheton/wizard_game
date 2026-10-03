class_name TesterField
extends VBoxContainer
## UNE LIGNE EDITABLE de l atelier du testeur : un champ d une Resource.
##
## Pilotee par TesterOverrides.resolve_field() : le genre du champ (nombre,
## booleen, enum, reference, liste...) decide du controle. Rien n est ecrit par
## nom de champ ici, sauf le PAS des boutons +/- : c est l introspection qui
## fait que chaque nouveau champ d EnemyDef apparait sans retoucher l ecran.
##
## ERGONOMIE TACTILE (le co-auteur joue sur telephone) :
##   - toute cible fait au moins TOUCH px ;
##   - un nombre se regle aux boutons - / + OU se tape au clavier numerique ;
##   - pas d infobulle (il n y a pas de survol sur un ecran tactile) : l origine
##     est ECRITE sous le champ des qu il differe, avec un bouton ORIGINE.

signal changed()

const TOUCH: float = 90.0

## Encres calculees pour le papier du livre (luminance 0,84, seuil 4,5:1), les
## memes que l ecran des reglages : neutre 13,0:1, rouge 8,61:1.
const INK: Color = Color(0.20, 0.13, 0.07)
const INK_CHANGED: Color = Color(0.52, 0.06, 0.06)
const INK_NOTE: Color = Color(0.30, 0.22, 0.12)

var target: String = ""
var field: String = ""
var label_text: String = ""
## L ecran hote : il porte le selecteur plein ecran (pour les longues listes).
var host: Node = null

var _error: String = ""


func setup(p_target: String, p_field: String, p_label: String, p_host: Node) -> TesterField:
	target = p_target
	field = p_field
	label_text = p_label
	host = p_host
	add_theme_constant_override(&"separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	return self


## Le champ resolu A NEUF a chaque construction : un reglage de vague remplace
## le tableau du niveau, un ancien porteur ne serait plus le bon.
func spec() -> Dictionary:
	var res: Resource = TesterOverrides.resolve_target(target)
	if res == null:
		return {}
	return TesterOverrides.resolve_field(res, field)


func value() -> Variant:
	if TesterOverrides.has_override(target, field):
		return TesterOverrides.override_value(target, field)
	return TesterOverrides.current_value(target, field)


func is_modified() -> bool:
	return TesterOverrides.has_override(target, field)


func commit(v: Variant) -> void:
	_error = TesterOverrides.set_override(target, field, v)
	_rebuild_later()
	changed.emit()


func revert() -> void:
	_error = ""
	TesterOverrides.remove_override(target, field)
	_rebuild_later()
	changed.emit()


## Differe : on ne libere pas le controle dont le signal est en cours d emission
## (Godot refuse, "Attempted to free a locked object").
func _rebuild_later() -> void:
	if is_inside_tree():
		_build.call_deferred()
	else:
		_build()


func _build() -> void:
	for c in get_children().duplicate():
		remove_child(c)
		c.free()
	var f: Dictionary = spec()
	if f.is_empty():
		add_child(UiTheme.label("%s : champ indisponible" % label_text, UiTheme.FONT_SMALL, INK_NOTE))
		return
	var modifie: bool = is_modified()
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override(&"separation", 10)
	add_child(tete)
	var nom: Label = UiTheme.label(label_text + (" *" if modifie else ""), UiTheme.FONT_SMALL,
		INK_CHANGED if modifie else INK)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(nom)
	if modifie:
		var orig := Button.new()
		orig.text = "ORIGINE"
		orig.custom_minimum_size = Vector2(170, TOUCH)
		orig.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		orig.pressed.connect(revert)
		tete.add_child(orig)
	add_child(_editor(f))
	if modifie:
		var o: Variant = TesterOverrides.original_value(target, field)
		add_child(UiTheme.label("origine : %s" % TesterDocument.value_text(o),
			UiTheme.FONT_SMALL, INK_CHANGED))
	if _error != "":
		add_child(UiTheme.label("refuse : %s" % _error, UiTheme.FONT_SMALL, INK_CHANGED))


func _editor(f: Dictionary) -> Control:
	var v: Variant = value()
	match String(f["kind"]):
		"int", "float", "dict_value", "wave_count":
			if String(f["kind"]) == "dict_value" and int(f.get("value_type", TYPE_FLOAT)) == TYPE_BOOL:
				return _bool_editor(bool(v))
			if String(f["kind"]) == "dict_value" and int(f.get("value_type", TYPE_FLOAT)) in [TYPE_STRING, TYPE_STRING_NAME]:
				return _text_editor(String(v), false)
			var entier: bool = String(f["kind"]) in ["int", "wave_count"] \
				or int(f.get("value_type", TYPE_FLOAT)) == TYPE_INT
			return number_row(v, entier, step_for(field, float(v) if v != null else 0.0, entier),
				f.get("bounds", TesterOverrides.DEFAULT_BOUNDS), commit)
		"bool":
			return _bool_editor(bool(v))
		"string", "name":
			var ch: Array = f.get("choices_extra", [])
			if not ch.is_empty():
				return _choice_button(String(v), ch, true)
			return _text_editor(String(v), false)
		"text":
			return _text_editor(String(v), true)
		"enum":
			return _option(String(v), f["choices"])
		"color", "tint":
			var cp := ColorPickerButton.new()
			cp.custom_minimum_size = Vector2(0, TOUCH)
			cp.color = Color.html(String(v)) if Color.html_is_valid(String(v)) else Color.WHITE
			cp.popup_closed.connect(func() -> void:
				commit("#" + cp.color.to_html(true)))
			return cp
		"ref":
			return _ref_button(v, String(f["ref"]))
		"ref_list", "name_list":
			return _list_editor(v if v is Array else [], f)
		"enum_list":
			return _toggles(v if v is Array else [], f["choices"])
	return UiTheme.label(str(v), UiTheme.FONT_SMALL, INK)


## --- BRIQUES -----------------------------------------------------------------

## Une rangee [-] [champ] [+]. Statique : l onglet TEST et l editeur de vagues
## s en servent pour des valeurs qui ne sont pas des surcharges.
static func number_row(v: Variant, entier: bool, step: float, bounds: Array,
		on_commit: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var moins := Button.new()
	moins.text = "-"
	moins.custom_minimum_size = Vector2(TOUCH + 20, TOUCH)
	row.add_child(moins)
	var champ := LineEdit.new()
	champ.text = TesterOverrides._fmt(v) if v != null else ""
	champ.custom_minimum_size = Vector2(200, TOUCH)
	champ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	champ.alignment = HORIZONTAL_ALIGNMENT_CENTER
	champ.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY)
	champ.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER if entier \
		else LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	champ.select_all_on_focus = true
	row.add_child(champ)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(TOUCH + 20, TOUCH)
	row.add_child(plus)
	var lire := func() -> float:
		var t: String = champ.text.strip_edges().replace(",", ".")
		return t.to_float() if t.is_valid_float() else float(v if v != null else 0.0)
	var envoyer := func(x: float) -> void:
		x = clampf(x, float(bounds[0]), float(bounds[1]))
		if entier:
			on_commit.call(int(roundf(x)))
		else:
			on_commit.call(snappedf(x, 0.001))
	moins.pressed.connect(func() -> void: envoyer.call(lire.call() - step))
	plus.pressed.connect(func() -> void: envoyer.call(lire.call() + step))
	commit_on_leave(champ, func(t: String) -> void:
		# Une saisie illisible n est pas un reglage : le champ reprend la valeur
		# en cours sous les yeux du testeur, rien n est enregistre.
		if not t.strip_edges().replace(",", ".").is_valid_float():
			champ.text = TesterOverrides._fmt(v) if v != null else ""
			return
		envoyer.call(lire.call()))
	return row


## VALIDER EN QUITTANT LE CHAMP (vague 9, audit : sur telephone on ferme le
## clavier sans toucher Entree, et la valeur tapee etait perdue SANS message).
## Une saisie part donc par Entree (text_submitted), a la fermeture de l edition
## (editing_toggled a faux : clavier virtuel ferme) ET a la perte du focus (doigt
## pose ailleurs, bouton - / + touche). Seul un texte DIFFERENT du dernier envoye
## part : Entree puis la perte du focus qui la suit n enregistrent pas deux fois,
## et la reconstruction du champ apres l envoi ne relance rien.
static func commit_on_leave(champ: Control, envoyer: Callable) -> void:
	var dernier: Array = [_saisie(champ)]
	var valider := func() -> void:
		if not is_instance_valid(champ):
			return
		var t: String = _saisie(champ)
		if t == String(dernier[0]):
			return
		dernier[0] = t
		envoyer.call(t)
		# Relu APRES l envoi : l envoi peut reecrire le champ (saisie illisible
		# remise a la valeur en cours), et ce texte-la n est pas a renvoyer.
		if is_instance_valid(champ):
			dernier[0] = _saisie(champ)
	if champ is LineEdit:
		(champ as LineEdit).text_submitted.connect(func(_t: String) -> void: valider.call())
	if champ.has_signal(&"editing_toggled"):
		champ.connect(&"editing_toggled", func(on: bool) -> void:
			if not on:
				valider.call())
	champ.focus_exited.connect(valider)


static func _saisie(champ: Control) -> String:
	if champ is LineEdit:
		return (champ as LineEdit).text
	if champ is TextEdit:
		return (champ as TextEdit).text
	return ""


## Le pas des boutons : une "jolie" fraction de la valeur, pour qu un PV de 12
## avance de 1 et un PV de 900 de 50. Quelques champs ont une echelle propre.
static func step_for(name: String, v: float, entier: bool) -> float:
	var fin: Dictionary = {
		"resistances": 0.05, "dodge_chance": 0.05, "sprite_scale": 0.05,
		"difficulty": 0.05, "base_cast_time": 0.1, "spawn_delay": 0.1,
		"speed_threshold": 10.0,
	}
	for k in fin.keys():
		if name.begins_with(k) or name.ends_with("/" + k) or name == k:
			return fin[k]
	var a: float = absf(v)
	var pas: float = 1.0
	if a >= 10.0:
		pas = pow(10.0, floorf(log(a) / log(10.0)) - 1.0)
		if a / pas > 50.0:
			pas *= 5.0
	elif a > 0.0 and a < 1.0:
		pas = 0.05
	elif not entier and a < 10.0:
		pas = 0.5 if a >= 2.0 else 0.1
	return maxf(pas, 1.0) if entier else pas


func _bool_editor(on: bool) -> Control:
	var b := CheckButton.new()
	b.text = "oui" if on else "non"
	b.button_pressed = on
	b.custom_minimum_size = Vector2(0, TOUCH)
	b.toggled.connect(func(x: bool) -> void: commit(x))
	return b


func _text_editor(t: String, multiline: bool) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	var ok := Button.new()
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(TOUCH + 30, TOUCH)
	if multiline:
		var te := TextEdit.new()
		te.text = t
		te.custom_minimum_size = Vector2(0, 220)
		te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		box.add_child(te)
		commit_on_leave(te, func(x: String) -> void: commit(x))
		ok.pressed.connect(func() -> void: commit(te.text))
	else:
		var le := LineEdit.new()
		le.text = t
		le.custom_minimum_size = Vector2(0, TOUCH)
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		box.add_child(le)
		commit_on_leave(le, func(x: String) -> void: commit(x))
		ok.pressed.connect(func() -> void: commit(le.text))
	box.add_child(ok)
	return box


func _option(current: String, choices: Array) -> Control:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(0, TOUCH)
	o.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	for i in choices.size():
		o.add_item(String(choices[i]), i)
	o.selected = maxi(choices.find(current), 0)
	o.item_selected.connect(func(i: int) -> void: commit(String(choices[i])))
	return o


## Un bouton qui ouvre le SELECTEUR plein ecran (recherche + grande liste) :
## une liste deroulante de 80 apparences est inutilisable au doigt.
func _choice_button(current: String, choices: Array, allow_empty: bool) -> Control:
	var b := Button.new()
	b.text = current if current != "" else "(aucun)"
	b.custom_minimum_size = Vector2(0, TOUCH)
	b.pressed.connect(func() -> void:
		var items: Array = []
		if allow_empty:
			items.append({"id": "", "label": "(aucun)"})
		for c in choices:
			items.append({"id": String(c), "label": String(c)})
		if host != null and host.has_method("open_picker"):
			host.call("open_picker", label_text, items, func(id: String) -> void: commit(id)))
	return b


func _ref_button(id: Variant, kind: String) -> Control:
	var b := Button.new()
	b.text = TesterField.ref_label(kind, id)
	b.custom_minimum_size = Vector2(0, TOUCH)
	b.pressed.connect(func() -> void:
		var items: Array = [{"id": "", "label": "(aucun)"}]
		items.append_array(TesterField.ref_items(kind))
		if host != null and host.has_method("open_picker"):
			host.call("open_picker", label_text, items, func(x: String) -> void:
				commit(null if x == "" else x)))
	return b


## Une LISTE d ids (deck, pool, niveaux suivants) : une ligne par element avec
## RETIRER, puis AJOUTER. Les doublons sont permis (un deck en porte).
func _list_editor(ids: Array, f: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	var kind: String = String(f.get("ref", ""))
	for i in ids.size():
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override(&"separation", 8)
		var l: Label = UiTheme.label(TesterField.ref_label(kind, ids[i]), UiTheme.FONT_SMALL, INK,
			HORIZONTAL_ALIGNMENT_LEFT, false)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		ligne.add_child(l)
		var retirer := Button.new()
		retirer.text = "RETIRER"
		retirer.custom_minimum_size = Vector2(190, TOUCH)
		retirer.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		var idx: int = i
		retirer.pressed.connect(func() -> void:
			var copie: Array = ids.duplicate()
			copie.remove_at(idx)
			commit(copie))
		ligne.add_child(retirer)
		box.add_child(ligne)
	var ajouter := Button.new()
	ajouter.text = "AJOUTER"
	ajouter.custom_minimum_size = Vector2(0, TOUCH)
	ajouter.pressed.connect(func() -> void:
		var items: Array = []
		if kind != "":
			items = TesterField.ref_items(kind)
		else:
			for c in f.get("choices_extra", []):
				items.append({"id": String(c), "label": String(c)})
		if host != null and host.has_method("open_picker"):
			host.call("open_picker", label_text, items, func(x: String) -> void:
				var copie: Array = ids.duplicate()
				copie.append(x)
				commit(copie)))
	box.add_child(ajouter)
	return box


func _toggles(noms: Array, choices: Array) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 8)
	flow.add_theme_constant_override(&"v_separation", 8)
	for c in choices:
		var b := Button.new()
		b.toggle_mode = true
		b.text = String(c)
		b.button_pressed = noms.has(c)
		b.custom_minimum_size = Vector2(200, TOUCH)
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		b.toggled.connect(func(on: bool) -> void:
			var copie: Array = []
			for x in choices:
				if (x == c and on) or (x != c and noms.has(x)):
					copie.append(x)
			commit(copie))
		flow.add_child(b)
	return flow


## --- LIBELLES DES REFERENCES ------------------------------------------------

static func ref_label(kind: String, id: Variant) -> String:
	if id == null or String(id) == "":
		return "(aucun)"
	if kind == "":
		return String(id)
	var res: Resource = TesterOverrides.resolve_target("%s:%s" % [kind, id])
	if res == null:
		return "%s (inconnu)" % id
	var n: Variant = res.get("display_name")
	if n == null or String(n) == "":
		n = res.get("description")
	return "%s (%s)" % [String(n), id] if n != null and String(n) != "" else String(id)


## Tous les elements d un genre, tries pour qu une recherche visuelle marche :
## monstres par puissance, cartes par rarete, puis par nom.
static func ref_items(kind: String) -> Array:
	var out: Array = []
	var dict_name: String = TesterOverrides.TARGET_KINDS.get(kind, "")
	if dict_name == "":
		return out
	var dict: Dictionary = ContentDB.get(dict_name)
	var liste: Array = dict.values()
	liste.sort_custom(func(a: Resource, b: Resource) -> bool:
		return sort_key(a) < sort_key(b))
	for r: Resource in liste:
		out.append({"id": String(r.get("id")), "label": ref_label(kind, r.get("id")),
			"res": r})
	return out


static func sort_key(r: Resource) -> String:
	if r is EnemyDef:
		return "%02d %s" % [(r as EnemyDef).power, (r as EnemyDef).display_name]
	if r is SpellCard:
		return "%d %s" % [(r as SpellCard).rarity, (r as SpellCard).display_name]
	return String(r.get("id"))

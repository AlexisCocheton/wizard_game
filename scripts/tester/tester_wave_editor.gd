class_name TesterWaveEditor
extends VBoxContainer
## L EDITEUR DES VAGUES DE CAMPAGNE d un niveau.
##
## "Faire en sorte que je puisse modifier le contenu et la difficulte des vagues
## de la campagne."
##
## Les vagues de campagne sont EMBARQUEES dans le LevelDef (sous-ressources) :
## les fichiers resources/waves/ ne sont lus par aucun code de jeu. On regle
## donc `level:<id>` / "waves/<i>", une vague ENTIERE par surcharge (entrees :
## monstre, nombre, delai, depart ; difficulte ; duree ; palier). Une vague par
## surcharge et non un champ par entree : ajouter ou retirer une entree change
## les indices, et un "entries/3/count" pointerait alors sur un autre monstre.
##
## Ajouter une vague = "waves/#" + 1 (copie de la derniere, sans le drapeau de
## boss). Retirer la vague k = decaler les suivantes d un cran puis "waves/#" - 1 :
## le document dit alors exactement ce qui a bouge.

const TOUCH: float = TesterField.TOUCH
const INK: Color = TesterField.INK

var level: LevelDef = null
var target: String = ""
var host: Node = null


func setup(p_level: LevelDef, p_host: Node) -> TesterWaveEditor:
	level = p_level
	host = p_host
	target = TesterOverrides.target_of(level)
	add_theme_constant_override(&"separation", 16)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	return self


func _rebuild() -> void:
	_build.call_deferred()


## Lit `level.waves` tel qu il est EN JEU : l atelier ne s ouvre qu en mode
## testeur, donc surcharges appliquees. Mode eteint, la fiche le signale.
func _build() -> void:
	for c in get_children().duplicate():
		remove_child(c)
		c.free()
	var n: int = level.waves.size()
	add_child(UiTheme.label("%d vague%s. Chaque reglage vaut pour ce niveau seulement."
		% [n, "s" if n > 1 else ""], UiTheme.FONT_SMALL, TesterField.INK_NOTE))
	for i in n:
		add_child(_wave_panel(i))
	var ajouter := Button.new()
	ajouter.text = "AJOUTER UNE VAGUE (copie de la derniere)"
	ajouter.custom_minimum_size = Vector2(0, TOUCH)
	ajouter.pressed.connect(func() -> void:
		_set_wave("waves/#", level.waves.size() + 1))
	add_child(ajouter)
	if TesterOverrides.has_override(target, "waves/#"):
		add_child(UiTheme.label("nombre de vagues d origine : %s"
			% TesterDocument.value_text(TesterOverrides.original_value(target, "waves/#")),
			UiTheme.FONT_SMALL, TesterField.INK_CHANGED))


func _set_wave(field: String, v: Variant) -> void:
	var err: String = TesterOverrides.set_override(target, field, v)
	if err != "" and host != null and host.has_method("toast"):
		host.call("toast", "Refuse : " + err)
	_rebuild()


func _wave_panel(i: int) -> Control:
	var field: String = "waves/%d" % i
	var w: Dictionary = TesterOverrides.encode_wave(level.waves[i])
	var modifie: bool = TesterOverrides.has_override(target, field)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiTheme.flat_box(
		Color(0.0, 0.0, 0.0, 0.07), 14, 14.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	panel.add_child(box)

	var titre: String = "VAGUE %d" % (i + 1)
	if bool(w.get("is_boss", false)):
		titre += "  - BOSS"
	elif bool(w.get("is_miniboss", false)):
		titre += "  - MINI-BOSS"
	if modifie:
		titre += "  *"
	box.add_child(UiTheme.label(titre, UiTheme.FONT_BODY,
		TesterField.INK_CHANGED if modifie else INK))

	var entrees: Array = w.get("entries", [])
	for j in entrees.size():
		box.add_child(_entry_row(i, w, j))
	var plus := Button.new()
	plus.text = "AJOUTER UN MONSTRE"
	plus.custom_minimum_size = Vector2(0, TOUCH)
	plus.pressed.connect(func() -> void:
		_pick_enemy(func(id: String) -> void:
			var w2: Dictionary = w.duplicate(true)
			var dernier: float = 0.0
			for e in w2["entries"]:
				dernier = maxf(dernier, float(e.get("start_offset", 0.0)))
			(w2["entries"] as Array).append({"enemy": id, "count": 1,
				"spawn_delay": 1.0, "start_offset": dernier + 2.0})
			_set_wave(field, w2)))
	box.add_child(plus)

	box.add_child(_num_line("difficulte (PV et vitesse)", float(w["difficulty"]), false,
		0.05, TesterOverrides.BOUNDS["difficulty"], func(x: Variant) -> void:
			var w2: Dictionary = w.duplicate(true)
			w2["difficulty"] = x
			_set_wave(field, w2)))
	box.add_child(_num_line("duree (s)", float(w["duration"]), false, 1.0,
		TesterOverrides.BOUNDS["wave_duration"], func(x: Variant) -> void:
			var w2: Dictionary = w.duplicate(true)
			w2["duration"] = x
			_set_wave(field, w2)))
	var drapeaux := HBoxContainer.new()
	for cle in ["is_miniboss", "is_boss"]:
		var cb := CheckButton.new()
		cb.text = "mini-boss" if cle == "is_miniboss" else "boss"
		cb.button_pressed = bool(w.get(cle, false))
		cb.custom_minimum_size = Vector2(0, TOUCH)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c2: String = cle
		cb.toggled.connect(func(on: bool) -> void:
			var w2: Dictionary = w.duplicate(true)
			w2[c2] = on
			_set_wave(field, w2))
		drapeaux.add_child(cb)
	box.add_child(drapeaux)

	var bas := HBoxContainer.new()
	bas.add_theme_constant_override(&"separation", 10)
	if modifie:
		var orig := Button.new()
		orig.text = "ORIGINE"
		orig.custom_minimum_size = Vector2(0, TOUCH)
		orig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orig.pressed.connect(func() -> void:
			TesterOverrides.remove_override(target, field)
			_rebuild())
		bas.add_child(orig)
	if level.waves.size() > 1:
		var retirer := Button.new()
		retirer.text = "RETIRER CETTE VAGUE"
		retirer.custom_minimum_size = Vector2(0, TOUCH)
		retirer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		retirer.pressed.connect(func() -> void: remove_wave(i))
		bas.add_child(retirer)
	box.add_child(bas)
	if modifie:
		var o: Variant = TesterOverrides.original_value(target, field)
		var l: Label = UiTheme.label("origine : " + TesterDocument.wave_text(o),
			UiTheme.FONT_SMALL, TesterField.INK_CHANGED)
		box.add_child(l)
	return panel


func _entry_row(i: int, w: Dictionary, j: int) -> Control:
	var field: String = "waves/%d" % i
	var e: Dictionary = (w["entries"] as Array)[j]
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 10)
	box.add_child(ligne)
	var def: EnemyDef = ContentDB.enemies.get(StringName(String(e.get("enemy", ""))))
	if def != null:
		ligne.add_child(BestiaryLore.portrait_of(def, 90.0, true))
	var nom := Button.new()
	nom.text = TesterField.ref_label("enemy", e.get("enemy"))
	nom.custom_minimum_size = Vector2(0, TOUCH)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.clip_text = true
	nom.pressed.connect(func() -> void:
		_pick_enemy(func(id: String) -> void:
			var w2: Dictionary = w.duplicate(true)
			w2["entries"][j]["enemy"] = id
			_set_wave(field, w2)))
	ligne.add_child(nom)
	var retirer := Button.new()
	retirer.text = "X"
	retirer.custom_minimum_size = Vector2(TOUCH, TOUCH)
	retirer.disabled = (w["entries"] as Array).size() <= 1
	retirer.pressed.connect(func() -> void:
		var w2: Dictionary = w.duplicate(true)
		(w2["entries"] as Array).remove_at(j)
		_set_wave(field, w2))
	ligne.add_child(retirer)
	for champ in [["count", "nombre", true, 1.0], ["spawn_delay", "delai entre deux (s)", false, 0.1],
			["start_offset", "depart (s)", false, 1.0]]:
		var c: String = champ[0]
		box.add_child(_num_line(champ[1], float(e.get(c, 0.0)), champ[2], champ[3],
			TesterOverrides.BOUNDS[c], func(x: Variant) -> void:
				var w2: Dictionary = w.duplicate(true)
				w2["entries"][j][c] = x
				_set_wave(field, w2)))
	return box


func _num_line(label: String, v: float, entier: bool, step: float, bounds: Array,
		cb: Callable) -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 10)
	var l: Label = UiTheme.label(label, UiTheme.FONT_SMALL, INK)
	l.custom_minimum_size = Vector2(300, 0)
	ligne.add_child(l)
	var row: HBoxContainer = TesterField.number_row(v, entier, step, bounds, cb)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(row)
	return ligne


func _pick_enemy(cb: Callable) -> void:
	if host != null and host.has_method("open_picker"):
		host.call("open_picker", "Monstre", TesterField.ref_items("enemy"), cb)


## Retire la vague k : les suivantes descendent d un cran (chacune devient une
## surcharge de la position du dessous), puis le nombre baisse d un.
func remove_wave(k: int) -> void:
	TesterWaveEditor.remove_wave_of(level, k)
	_rebuild()


static func remove_wave_of(lvl: LevelDef, k: int) -> String:
	var t: String = TesterOverrides.target_of(lvl)
	var n: int = lvl.waves.size()
	if n <= 1 or k < 0 or k >= n:
		return "rien a retirer"
	var suivantes: Array = []
	for i in range(k + 1, n):
		suivantes.append(TesterOverrides.encode_wave(lvl.waves[i]))
	# Les surcharges de la DERNIERE position n auront plus de vague ou s appliquer.
	TesterOverrides.remove_override(t, "waves/%d" % (n - 1))
	for i in suivantes.size():
		var err: String = TesterOverrides.set_override(t, "waves/%d" % (k + i), suivantes[i])
		if err != "":
			return err
	return TesterOverrides.set_override(t, "waves/#", n - 1)

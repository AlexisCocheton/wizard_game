class_name TesterTestTab
extends VBoxContainer
## L ONGLET TEST de l atelier : composer une vague, choisir les cartes et la
## vitesse de depart, puis JOUER dans une vraie partie (TesterRun).
##
## La composition vit dans TesterRun.composition (statique) : elle survit a la
## partie, et "rejouer apres une retouche de fiche" est un seul toucher.
## Les surcharges de l atelier s appliquent a cette partie comme a toutes les
## autres (mode testeur) : c est l usage vise, regler un monstre puis le tester.

const TOUCH: float = TesterField.TOUCH
const INK: Color = TesterField.INK

var host: Node = null
var play_button: Button = null


func setup(p_host: Node) -> TesterTestTab:
	host = p_host
	add_theme_constant_override(&"separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	return self


func comp() -> Dictionary:
	return TesterRun.current()


func _rebuild() -> void:
	_build.call_deferred()


func _titre(t: String) -> void:
	add_child(UiTheme.label(t, UiTheme.FONT_BODY, INK))


func _build() -> void:
	for c in get_children().duplicate():
		remove_child(c)
		c.free()
	var c: Dictionary = comp()
	var bilan: String = TesterRun.result_text()
	if bilan != "":
		add_child(UiTheme.label(bilan, UiTheme.FONT_SMALL, TesterField.INK_CHANGED))

	_titre("MONSTRES DE LA VAGUE")
	var entrees: Array = c["entries"]
	for i in entrees.size():
		add_child(_entry_row(i))
	var plus := Button.new()
	plus.text = "AJOUTER UN MONSTRE"
	plus.custom_minimum_size = Vector2(0, TOUCH)
	plus.disabled = entrees.size() >= TesterRun.MAX_ENTRIES
	plus.pressed.connect(func() -> void:
		_pick("Monstre", TesterField.ref_items("enemy"), func(id: String) -> void:
			(comp()["entries"] as Array).append({"enemy": id, "count": 3})
			_rebuild()))
	add_child(plus)
	add_child(_num("difficulte de la vague (PV et vitesse)", float(c.get("difficulty", 1.0)),
		false, 0.05, TesterOverrides.BOUNDS["difficulty"], func(x: Variant) -> void:
			comp()["difficulty"] = x
			_rebuild()))

	_titre("CARTES DE LA PARTIE")
	var decks := HBoxContainer.new()
	decks.add_theme_constant_override(&"separation", 10)
	add_child(decks)
	var depart := Button.new()
	depart.text = "DECK DE DEPART"
	depart.custom_minimum_size = Vector2(0, TOUCH)
	depart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depart.pressed.connect(func() -> void:
		comp()["cards"] = TesterRun.default_composition()["cards"]
		_rebuild())
	decks.add_child(depart)
	var niveau := Button.new()
	niveau.text = "DECK D UN NIVEAU"
	niveau.custom_minimum_size = Vector2(0, TOUCH)
	niveau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	niveau.pressed.connect(func() -> void:
		_pick("Niveau", TesterField.ref_items("level"), func(id: String) -> void:
			var lvl: LevelDef = ContentDB.levels.get(StringName(id))
			if lvl == null:
				return
			var ids: Array = []
			for card in lvl.exploration_deck:
				if card != null:
					ids.append(String(card.id))
			comp()["cards"] = ids
			_rebuild()))
	decks.add_child(niveau)
	var cartes: Array = c["cards"]
	add_child(UiTheme.label("%d carte%s dans la pioche" % [cartes.size(),
		"s" if cartes.size() > 1 else ""], UiTheme.FONT_SMALL, TesterField.INK_NOTE))
	for id in _unique(cartes):
		add_child(_card_row(id))
	var ajouter := Button.new()
	ajouter.text = "AJOUTER UNE CARTE"
	ajouter.custom_minimum_size = Vector2(0, TOUCH)
	ajouter.disabled = cartes.size() >= TesterRun.MAX_CARDS
	ajouter.pressed.connect(func() -> void:
		var items: Array = []
		for it in TesterField.ref_items("card"):
			if not (it["res"] as SpellCard).is_passive:
				items.append(it)
		_pick("Carte", items, func(id: String) -> void:
			(comp()["cards"] as Array).append(id)
			_rebuild()))
	add_child(ajouter)

	_titre("PARTIE")
	add_child(_num("vitesse de depart (%)", float(c.get("speed", TesterRun.DEFAULT_SPEED)),
		true, 10.0, [101.0, float(GameConfig.SPEED_MAX_PERCENT)], func(x: Variant) -> void:
			comp()["speed"] = x
			_rebuild()))
	add_child(_num("graine (0 = au hasard)", float(c.get("seed", 0)), true, 1.0,
		[0.0, 999999.0], func(x: Variant) -> void:
			comp()["seed"] = x
			_rebuild()))
	var fonds := OptionButton.new()
	fonds.custom_minimum_size = Vector2(0, TOUCH)
	var liste: Array = TesterOverrides.choices_for(LevelDef.new(), "backdrop")
	for i in liste.size():
		fonds.add_item("fond : " + String(liste[i]), i)
	fonds.selected = maxi(liste.find(String(c.get("backdrop", ""))), 0)
	fonds.item_selected.connect(func(i: int) -> void:
		comp()["backdrop"] = String(liste[i]))
	add_child(fonds)

	var soucis: Array[String] = TesterRun.problems(c)
	for s in soucis:
		add_child(UiTheme.label("A faire : " + s, UiTheme.FONT_SMALL, TesterField.INK_CHANGED))
	play_button = Button.new()
	play_button.text = "JOUER LA VAGUE"
	play_button.custom_minimum_size = Vector2(0, 150)
	UiTheme.style_primary(play_button)
	play_button.disabled = not soucis.is_empty()
	play_button.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		TesterRun.start(comp()))
	add_child(play_button)
	add_child(UiTheme.label("La partie utilise les reglages de l atelier. A la fin, retour ici "
		+ "avec le bilan (abandonner depuis la pause ramene au menu).", UiTheme.FONT_SMALL,
		TesterField.INK_NOTE))


func _entry_row(i: int) -> Control:
	var e: Dictionary = (comp()["entries"] as Array)[i]
	var box := VBoxContainer.new()
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
		_pick("Monstre", TesterField.ref_items("enemy"), func(id: String) -> void:
			e["enemy"] = id
			_rebuild()))
	ligne.add_child(nom)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(TOUCH, TOUCH)
	x.pressed.connect(func() -> void:
		(comp()["entries"] as Array).remove_at(i)
		_rebuild())
	ligne.add_child(x)
	box.add_child(_num("nombre", float(e.get("count", 1)), true, 1.0,
		[1.0, float(TesterRun.MAX_COUNT)], func(v: Variant) -> void:
			e["count"] = v
			_rebuild()))
	return box


func _card_row(id: String) -> Control:
	var cartes: Array = comp()["cards"]
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 10)
	var card: SpellCard = ContentDB.cards.get(StringName(id))
	if card != null:
		var art: Control = CardIcons.make_rect(card, 80.0)
		if art != null:
			ligne.add_child(art)
	var l: Label = UiTheme.label(TesterField.ref_label("card", id), UiTheme.FONT_SMALL, INK,
		HORIZONTAL_ALIGNMENT_LEFT, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	ligne.add_child(l)
	var row: HBoxContainer = TesterField.number_row(cartes.count(id), true, 1.0,
		[0.0, float(TesterRun.MAX_CARDS)], func(v: Variant) -> void:
			var n: int = int(v)
			var garde: Array = []
			for x in cartes:
				if x != id:
					garde.append(x)
			for k in n:
				garde.append(id)
			comp()["cards"] = garde
			_rebuild())
	row.custom_minimum_size = Vector2(460, 0)
	ligne.add_child(row)
	return ligne


func _unique(ids: Array) -> Array:
	var out: Array = []
	for i in ids:
		if not out.has(i):
			out.append(i)
	return out


func _num(label: String, v: float, entier: bool, step: float, bounds: Array, cb: Callable) -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 10)
	var l: Label = UiTheme.label(label, UiTheme.FONT_SMALL, INK)
	l.custom_minimum_size = Vector2(330, 0)
	ligne.add_child(l)
	var row: HBoxContainer = TesterField.number_row(v, entier, step, bounds, cb)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(row)
	return ligne


func _pick(title: String, items: Array, cb: Callable) -> void:
	if host != null and host.has_method("open_picker"):
		host.call("open_picker", title, items, cb)

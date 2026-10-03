class_name TesterDocTab
extends VBoxContainer
## L ONGLET DOCUMENT de l atelier : la liste des reglages et le document de
## changement a nous transmettre.
##
##   EXPORTER   ecrit le document dans user://changements/ et l affiche ;
##   COPIER     le met dans le presse-papiers, a coller dans un message depuis
##              le telephone (le dossier user:// d Android n est pas accessible
##              sans cable, le presse-papiers si) ;
##   IMPORTER   recharge un jeu de reglages colle depuis le presse-papiers ;
##   REINITIALISER  efface tous les reglages.
## Importer et reinitialiser REMPLACENT ce qui existe : deux touchers, comme la
## remise a zero de la progression.
##
## SUR TELEPHONE (audit vague 9) : EXPORTER ecrivait dans user://changements,
## c est-a-dire /data/data/<jeu>/files/... sur Android, un dossier PRIVE que le
## testeur ne peut ni ouvrir ni partager, et l ecran affichait ce chemin
## inutilisable. Sur mobile, COPIER est donc LA voie : un grand bouton dore en
## tete, et un message qui dit quoi faire ensuite (« colle-le dans un
## message »). L export fichier n y est pas propose ; une ligne explique
## pourquoi. Sur PC rien ne change : EXPORTER, COPIER, OUVRIR LE DOSSIER.

const TOUCH: float = TesterField.TOUCH
const INK: Color = TesterField.INK
## Mode d emploi sur telephone, avant la copie.
const COPY_HOWTO: String = "Touche COPIER, puis colle-le dans un message (SMS, mail, " \
	+ "Discord...) : appui long dans le champ de texte, puis Coller."
## Apres la copie, sur telephone.
const COPIED_HOWTO: String = "Copie ! Ouvre ta messagerie et colle-le dans un message " \
	+ "(appui long dans le champ de texte, puis Coller). %d reglage%s."
## Pourquoi il n y a pas d EXPORTER sur telephone.
const NO_EXPORT_NOTE: String = "Pas d export en fichier sur telephone : le fichier " \
	+ "resterait dans un dossier prive du jeu, que tu ne peux pas ouvrir."

var host: Node = null
var last_path: String = ""
var _apercu: TextEdit = null
var _import_btn: Button = null
var _reset_btn: Button = null
var _import_armed: bool = false
var _reset_armed: bool = false
var _message: String = ""
## Vrai sur telephone : COPIER est la seule voie proposee. Pose a la creation
## d apres l OS ; les tests le forcent par set_mobile().
var mobile: bool = is_mobile_os()


## Android, iOS, ou toute plateforme qui se dit mobile (web sur telephone).
static func is_mobile_os() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Force la presentation telephone ou PC (tests, captures) et reconstruit.
func set_mobile(on: bool) -> void:
	mobile = on
	_message = ""
	_build()


func setup(p_host: Node) -> TesterDocTab:
	host = p_host
	add_theme_constant_override(&"separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	return self


func _rebuild() -> void:
	_build.call_deferred()
	if host != null and host.has_method("refresh_status"):
		host.call_deferred("refresh_status")


func _build() -> void:
	for c in get_children().duplicate():
		remove_child(c)
		c.free()
	var n: int = TesterOverrides.count()
	add_child(UiTheme.label("DOCUMENT DE CHANGEMENT", UiTheme.FONT_BODY, INK))
	if mobile:
		_build_copy_first(n)
	else:
		add_child(UiTheme.label(TesterDocument.summary(_par_genre(), n) + ". Exporte-le puis "
			+ "colle-le dans un message : il dit, pour chaque reglage, la cible, le champ, "
			+ "l avant et l apres.", UiTheme.FONT_SMALL, TesterField.INK_NOTE))
		var l1 := HBoxContainer.new()
		l1.add_theme_constant_override(&"separation", 10)
		add_child(l1)
		var exporter: Button = _button("EXPORTER", export_now)
		exporter.name = "ExportButton"
		l1.add_child(exporter)
		var cop: Button = _button("COPIER", copy_now)
		cop.name = "CopyButton"
		l1.add_child(cop)
	var l2 := HBoxContainer.new()
	l2.add_theme_constant_override(&"separation", 10)
	add_child(l2)
	_import_btn = _button("IMPORTER (presse-papiers)", _on_import)
	if _import_armed:
		_import_btn.text = "CONFIRMER : remplace %d reglage%s" % [n, "s" if n > 1 else ""]
	l2.add_child(_import_btn)
	_reset_btn = _button("REINITIALISER", _on_reset)
	if _reset_armed:
		_reset_btn.text = "CONFIRMER : tout effacer"
	_reset_btn.disabled = n == 0 and TesterOverrides.rejected().is_empty()
	l2.add_child(_reset_btn)
	if not mobile and OS.has_feature("pc"):
		add_child(_button("OUVRIR LE DOSSIER DES DOCUMENTS", func() -> void:
			DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(TesterOverrides.DOC_DIR))
			OS.shell_open(ProjectSettings.globalize_path(TesterOverrides.DOC_DIR))))
	if _message != "" and not mobile:
		var m: Label = UiTheme.label(_message, UiTheme.FONT_SMALL, TesterField.INK_CHANGED)
		m.name = "DocMessage"
		add_child(m)

	add_child(UiTheme.label("REGLAGES (%d)" % n, UiTheme.FONT_BODY, INK))
	if n == 0:
		add_child(UiTheme.label("Aucun reglage. Ouvre une fiche (SORTS, MONSTRES, NIVEAUX) "
			+ "et change une valeur.", UiTheme.FONT_SMALL, TesterField.INK_NOTE))
	for e: Dictionary in TesterOverrides.entries():
		add_child(_entry_row(e))
	var rejetes: Array = TesterOverrides.rejected()
	if not rejetes.is_empty():
		add_child(UiTheme.label("IGNORES (%d)" % rejetes.size(), UiTheme.FONT_BODY,
			TesterField.INK_CHANGED))
		for r: Dictionary in rejetes:
			var l: Label = UiTheme.label("%s / %s : %s" % [r["target"], r["field"], r["reason"]],
				UiTheme.FONT_SMALL, TesterField.INK_CHANGED)
			add_child(l)

	_apercu = TextEdit.new()
	_apercu.editable = false
	_apercu.custom_minimum_size = Vector2(0, 520)
	_apercu.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	_apercu.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_apercu.text = TesterDocument.build()
	add_child(UiTheme.label("APERCU", UiTheme.FONT_BODY, INK))
	add_child(_apercu)


## TELEPHONE : le bouton COPIER en tete, grand et dore, le mode d emploi en
## clair juste dessous, puis pourquoi il n y a pas d export.
func _build_copy_first(n: int) -> void:
	add_child(UiTheme.label(TesterDocument.summary(_par_genre(), n) + ". Il dit, pour "
		+ "chaque reglage, la cible, le champ, l avant et l apres.",
		UiTheme.FONT_SMALL, TesterField.INK_NOTE))
	var cop: Button = _button("COPIER LE DOCUMENT", copy_now)
	cop.name = "CopyButton"
	cop.custom_minimum_size = Vector2(0, 140)
	cop.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY)
	UiTheme.style_primary(cop)
	add_child(cop)
	# Le message : ce qu il faut faire APRES la copie. Toujours affiche, plus
	# visible encore une fois la copie faite.
	var aide: Label = UiTheme.label(_message if _message != "" else COPY_HOWTO,
		UiTheme.FONT_SMALL if _message == "" else UiTheme.FONT_BODY,
		TesterField.INK_CHANGED if _message != "" else INK)
	aide.name = "DocMessage"
	add_child(aide)
	var note: Label = UiTheme.label(NO_EXPORT_NOTE, UiTheme.FONT_SMALL, TesterField.INK_NOTE)
	note.name = "NoExportNote"
	add_child(note)


func _par_genre() -> Dictionary:
	var out: Dictionary = {}
	for e in TesterOverrides.entries():
		var g: String = String(e["target"]).split(":")[0]
		out[g] = int(out.get(g, 0)) + 1
	return out


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 110)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	b.clip_text = true
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		cb.call())
	return b


func _entry_row(e: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	var avant: Variant = TesterOverrides.original_value(e["target"], e["field"])
	var texte: String = TesterDocument.sentence(e["target"], e["field"], avant, e["value"])
	var l: Label = UiTheme.label(texte, UiTheme.FONT_SMALL, INK)
	box.add_child(l)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 10)
	box.add_child(ligne)
	var t: String = e["target"]
	var f: String = e["field"]
	ligne.add_child(_button("OUVRIR LA FICHE", func() -> void:
		if host != null and host.has_method("open_sheet"):
			host.call("open_sheet", t)))
	ligne.add_child(_button("ANNULER CE REGLAGE", func() -> void:
		TesterOverrides.remove_override(t, f)
		_rebuild()))
	return box


## `dir` : le SMOKE ecrit ailleurs que dans le dossier du testeur, puis efface.
func export_now(dir: String = TesterOverrides.DOC_DIR) -> String:
	last_path = TesterDocument.write_file(dir)
	_message = ("Enregistre : " + last_path) if last_path != "" \
		else "Ecriture impossible dans " + TesterOverrides.DOC_DIR
	_rebuild()
	return last_path


func copy_now() -> void:
	DisplayServer.clipboard_set(TesterDocument.build())
	var n: int = TesterOverrides.count()
	_message = (COPIED_HOWTO % [n, "s" if n > 1 else ""]) if mobile \
		else "Document copie dans le presse-papiers (%d reglages)." % n
	_rebuild()


func _on_import() -> void:
	if TesterOverrides.count() > 0 and not _import_armed:
		_import_armed = true
		_rebuild()
		return
	_import_armed = false
	_message = import_text(DisplayServer.clipboard_get())
	_rebuild()


## Rend le message affiche. Separe du presse-papiers pour etre testable.
func import_text(text: String) -> String:
	if text.strip_edges() == "":
		return "Presse-papiers vide : copie d abord un document."
	var r: Dictionary = TesterDocument.import_text(text)
	if r["error"] != "":
		return "Import refuse : " + String(r["error"])
	var msg: String = "%d reglage%s importe%s" % [r["imported"], "s" if r["imported"] > 1 else "",
		"s" if r["imported"] > 1 else ""]
	if not (r["rejected"] as Array).is_empty():
		msg += ", %d ignore%s (voir plus bas)" % [r["rejected"].size(),
			"s" if r["rejected"].size() > 1 else ""]
	return msg + "."


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_rebuild()
		return
	_reset_armed = false
	TesterOverrides.clear_all()
	_message = "Tous les reglages sont effaces : le jeu est revenu a l origine."
	_rebuild()

extends TestCase
## ATELIER DU TESTEUR : une valeur tapee au clavier est validee meme sans Entree
## (vague 9). Sur telephone on ferme le clavier ou on touche ailleurs ; avant,
## seule la touche Entree enregistrait, et la valeur etait perdue sans message.

func get_suite_name() -> String:
	return "tester_field_commit"


func run() -> void:
	_test_la_perte_du_focus_valide()
	_test_entree_puis_perte_du_focus_n_envoie_qu_une_fois()
	_test_fermer_le_clavier_valide()
	_test_une_saisie_illisible_n_est_pas_un_reglage()
	_test_un_champ_de_l_atelier_retient_la_valeur()
	TesterOverrides.reset_for_tests()
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


## Une rangee [-] [champ] [+] dans l arbre, et ce qu elle a envoye.
func _rangee(depart: float, recu: Array) -> HBoxContainer:
	var row: HBoxContainer = TesterField.number_row(depart, true, 1.0, [0.0, 1000.0],
		func(x: Variant) -> void: recu.append(x))
	attach(row)
	return row


func _champ(row: Node) -> LineEdit:
	for c in row.get_children():
		if c is LineEdit:
			return c as LineEdit
	return null


func _test_la_perte_du_focus_valide() -> void:
	var recu: Array = []
	var row := _rangee(5.0, recu)
	var champ: LineEdit = _champ(row)
	ok(champ != null, "la rangee porte un champ de saisie")
	if champ == null:
		detach(row)
		return
	champ.grab_focus()
	champ.text = "12"
	champ.release_focus()
	eq(recu, [12], "le doigt pose ailleurs enregistre la valeur tapee")
	champ.grab_focus()
	champ.release_focus()
	eq(recu.size(), 1, "quitter sans rien changer n envoie rien de plus")
	detach(row)


func _test_entree_puis_perte_du_focus_n_envoie_qu_une_fois() -> void:
	var recu: Array = []
	var row := _rangee(5.0, recu)
	var champ: LineEdit = _champ(row)
	champ.grab_focus()
	champ.text = "8"
	champ.text_submitted.emit(champ.text)
	champ.release_focus()
	eq(recu, [8], "Entree puis la perte du focus : un seul envoi")
	detach(row)


func _test_fermer_le_clavier_valide() -> void:
	var recu: Array = []
	var row := _rangee(5.0, recu)
	var champ: LineEdit = _champ(row)
	ok(champ.has_signal(&"editing_toggled"), "le champ sait quand l edition se ferme")
	champ.text = "21"
	champ.emit_signal(&"editing_toggled", false)
	eq(recu, [21], "fermer le clavier enregistre la valeur tapee")
	detach(row)


func _test_une_saisie_illisible_n_est_pas_un_reglage() -> void:
	var recu: Array = []
	var row := _rangee(5.0, recu)
	var champ: LineEdit = _champ(row)
	champ.grab_focus()
	champ.text = "abc"
	champ.release_focus()
	eq(recu.size(), 0, "une saisie illisible n envoie rien")
	eq(champ.text, TesterOverrides._fmt(5.0), "et le champ reprend la valeur en cours")
	detach(row)


## De bout en bout : un champ de l atelier (PV d un monstre), une valeur tapee,
## le doigt pose ailleurs -> le monstre en jeu a change.
func _test_un_champ_de_l_atelier_retient_la_valeur() -> void:
	SaveData.reset_profile()
	TesterOverrides.reset_for_tests()
	SaveData.set_tester_mode(true)
	var d: EnemyDef = null
	var ids: Array = ContentDB.enemies.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var e: EnemyDef = ContentDB.enemies[id]
		if not e.is_boss() and e.max_hp > 1.0:
			d = e
			break
	ok(d != null, "un monstre ordinaire au catalogue")
	if d == null:
		return
	var avant: float = d.max_hp
	var f := TesterField.new()
	attach(f)
	f.setup(TesterOverrides.target_of(d), "max_hp", "PV", null)
	var champs: Array = []
	_lignes(f, champs)
	ok(champs.size() == 1, "le champ PV porte une saisie (%d)" % champs.size())
	if champs.size() == 1:
		var champ: LineEdit = champs[0]
		var voulu: int = int(avant) + 1
		champ.grab_focus()
		champ.text = str(voulu)
		champ.release_focus()
		feq(d.max_hp, float(voulu), "la valeur tapee est appliquee sans Entree")
		ok(f.is_modified(), "et le champ se lit comme modifie")
	f.revert()
	feq(d.max_hp, avant, "ORIGINE rend la valeur")
	detach(f)
	TesterOverrides.reset_for_tests()
	SaveData.set_tester_mode(false)


func _lignes(n: Node, out: Array) -> void:
	if n is LineEdit:
		out.append(n)
	for c in n.get_children():
		_lignes(c, out)

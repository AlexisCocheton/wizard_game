extends TestCase
## ECRAN DE DECK, vague 8 :
##   - les passifs se LISENT avant de s equiper (double toucher, comme les sorts) ;
##   - la grille du deck ne presente plus de cases « vide » comme une obligation ;
##   - aucun compte de deck ecrit en dur : tout lit DeckRules.DECK_SIZE (les decks
##     vont passer de 15 a 12 cartes, un « 15 » oublie mentirait au joueur).

func get_suite_name() -> String:
	return "deck_screens"


func run() -> void:
	SaveData.reset_profile()
	_test_un_passif_se_lit_avant_de_s_equiper()
	_test_pas_de_case_vide_dans_le_deck()
	_test_le_compteur_lit_deck_size()
	_test_aucun_compte_de_deck_en_dur()
	SaveData.reset_profile()


func _passifs() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return String(a.id) < String(b.id))
	return out


func _ouvrir_les_passifs() -> void:
	for lv: LevelDef in ContentDB.levels.values():
		if lv.allows_passives():
			SaveData.unlock_level(lv.id)
			break


func _tous(racine: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in racine.get_children():
		out.append(c)
		out.append_array(_tous(c))
	return out


func _textes(racine: Node) -> String:
	var t: String = ""
	for n in _tous(racine):
		if n is Label and (n as Label).is_visible_in_tree():
			t += (n as Label).text + "\n"
		# L effet d une carte est un texte a logos (ElementIcons.decorated_label) :
		# on le relit sans ses logos, tel que le joueur le lit.
		elif n is RichTextLabel and (n as RichTextLabel).is_visible_in_tree():
			t += ElementIcons.strip_inline((n as RichTextLabel).text) + "\n"
	return t


func _test_un_passif_se_lit_avant_de_s_equiper() -> void:
	SaveData.reset_profile()
	_ouvrir_les_passifs()
	var p: Array[SpellCard] = _passifs()
	SaveData.discover_card(p[0].id)
	SaveData.discover_card(p[1].id)
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	panel.open_passive_picker(0)
	eq(panel.picker_slot(), 0, "le choix du premier emplacement est ouvert")

	# Le VRAI toucher sur la vignette, pas un appel direct.
	var vignette: Button = null
	for n in _tous(panel):
		if n is Button and n.get_meta(&"tile_card_id", &"") == p[0].id:
			vignette = n
	ok(vignette != null, "la vignette du passif est dans le choix")
	if vignette == null:
		detach(panel)
		return
	ok(vignette.tooltip_text == "", "plus d infobulle : rien ne se lit au survol sur un telephone")
	vignette.pressed.emit()
	eq(panel.passive_detail(), p[0], "le premier toucher ouvre la FICHE")
	eq(SaveData.equipped_passives().size(), 0, "et n equipe rien")
	var texte: String = _textes(panel)
	ok(texte.contains(p[0].display_name), "la fiche porte le nom")
	ok(texte.contains(p[0].description), "la fiche porte l effet en entier")
	ok(texte.contains(DeckPanel.passive_sheet_line(p[0])), "la rarete et le seuil")
	ok(DeckPanel.passive_sheet_line(p[0]).contains("%d %%" % p[0].speed_threshold),
		"le seuil de vitesse est ecrit (%s)" % DeckPanel.passive_sheet_line(p[0]))
	var equiper: Button = panel.find_child("EquipPassive", true, false) as Button
	ok(equiper != null and equiper.custom_minimum_size.y >= 90.0, "EQUIPER est une cible de pouce")

	# Toucher un AUTRE passif depuis la fiche : on ne l equipe pas non plus.
	panel.tap_passive(p[1])
	eq(panel.passive_detail(), p[1], "un autre passif ouvre sa propre fiche")
	eq(SaveData.equipped_passives().size(), 0, "toujours rien d equipe")

	if equiper != null:
		(panel.find_child("EquipPassive", true, false) as Button).pressed.emit()
	eq(SaveData.equipped_passives(), [String(p[1].id)], "EQUIPER equipe le passif lu")
	eq(panel.picker_slot(), -1, "et referme le choix")
	ok(panel.passive_detail() == null, "la fiche est refermee")

	# Le double toucher direct sur la vignette fait la meme chose.
	panel.open_passive_picker(1)
	panel.tap_passive(p[0])
	panel.tap_passive(p[0])
	eq(SaveData.equipped_passives(), [String(p[1].id), String(p[0].id)],
		"deux touchers sur le meme passif l equipent")
	detach(panel)
	SaveData.reset_profile()


func _test_pas_de_case_vide_dans_le_deck() -> void:
	SaveData.reset_profile()
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	# Un deck de deux sorts differents : deux vignettes, pas six cases.
	# La grille du deck montre ce que le profil contient, obtenu ou non : deux
	# sorts quelconques suffisent, tries pour que le test ne depende pas du disque.
	var tous: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if not c.is_passive:
			tous.append(c)
	tous.sort_custom(func(a: SpellCard, b: SpellCard) -> bool: return String(a.id) < String(b.id))
	var sorts: Array[SpellCard] = tous.slice(0, 2)
	eq(sorts.size(), 2, "deux sorts pour composer le deck")
	var ids: Array = []
	for c in sorts:
		for i in DeckRules.max_copies(c.rarity):
			ids.append(String(c.id))
	SaveData.set_massacre_deck(ids)
	panel.refresh()
	eq(panel.deck_grid_cards(), sorts.size(), "une vignette par sort du deck")
	eq(panel.deck_grid_cells(), sorts.size(), "et aucune case de plus")
	for n in _tous(panel):
		if n is Button:
			not_ok((n as Button).text.strip_edges().to_lower() == "vide",
				"aucun bouton « vide » ne reclame d etre rempli")
	# Un deck vide garde une phrase, pas une page blanche.
	panel.create_deck()
	eq(panel.deck_grid_cards(), 0, "deck vide : aucune vignette")
	ok(panel.find_child("EmptyDeckHint", true, false) != null, "mais une phrase qui dit quoi faire")
	panel.delete_current_deck()
	detach(panel)
	SaveData.reset_profile()


func _test_le_compteur_lit_deck_size() -> void:
	SaveData.reset_profile()
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	var attendu: String = "/ %d" % DeckRules.DECK_SIZE
	ok(panel.header_text().contains(attendu),
		"le compteur du deck lit DeckRules.DECK_SIZE (%s)" % panel.header_text())
	detach(panel)


## Aucune chaine affichee ne doit porter un compte de deck ecrit en chiffres :
## « 14 / 15 », « 15 cartes ». On lit le SOURCE des ecrans (hors commentaires) et
## on cherche, DANS LES CHAINES, un nombre litteral colle a « / » ou a « cartes ».
## Le motif ne connait aucune valeur : il attrape un 15 oublie comme un 12.
func _test_aucun_compte_de_deck_en_dur() -> void:
	var motif := RegEx.new()
	# « 12 / 15 » comme « %d / 15 » : le numerateur est souvent un %d.
	motif.compile("\"[^\"]*((\\b\\d+|%[ds])\\s*/\\s*\\d+\\b|\\b\\d+\\s+cartes?\\b)[^\"]*\"")
	var fichiers: Array[String] = _scripts("res://scripts/ui")
	ok(fichiers.size() > 5, "les ecrans sont lus (%d fichiers)" % fichiers.size())
	var fautes: Array[String] = []
	for chemin in fichiers:
		var f := FileAccess.open(chemin, FileAccess.READ)
		if f == null:
			continue
		var n: int = 0
		while not f.eof_reached():
			var ligne: String = f.get_line()
			n += 1
			var code: String = _sans_commentaire(ligne)
			var m: RegExMatch = motif.search(code)
			if m != null:
				fautes.append("%s:%d %s" % [chemin.get_file(), n, m.get_string()])
	eq(fautes, [] as Array[String], "aucun compte de deck ecrit en dur dans les ecrans")


func _scripts(dossier: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dossier)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dossier.path_join(f))
	for sous in d.get_directories():
		out.append_array(_scripts(dossier.path_join(sous)))
	return out


## La ligne sans son commentaire. Un « # » dans une chaine n est pas un
## commentaire : on suit les guillemets.
func _sans_commentaire(ligne: String) -> String:
	var dans: bool = false
	for i in ligne.length():
		var ch: String = ligne[i]
		if ch == "\"":
			dans = not dans
		elif ch == "#" and not dans:
			return ligne.substr(0, i)
	return ligne

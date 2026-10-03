extends TestCase
## LOGOS D ELEMENT DANS TOUS LES TEXTES DE CARTE (retouche W8).
##
## Le helper ElementIcons (decorate + rich_label) avait ete branche sur la
## CardView de detail, le grimoire et la pause ; la fiche du deck (sort et
## passif) et l onglet DECK de la pause posaient encore la description dans un
## Label NU : « degats de FEU » sans le logo du feu, a un ecran du grimoire qui
## le montrait. Deux verrous :
##   - un balayage du code de scripts/ui : aucune description (ni sortie BBCode
##     d ElementIcons) passee a un Label ;
##   - les ecrans eux-memes, construits : la description d une carte qui cite un
##     element y est un texte a logos, relu identique sans eux.
##
## Aucune carte nommee en dur : on prend la premiere (par id) dont le texte
## cite un element en majuscules.

func get_suite_name() -> String:
	return "text_logos"


func run() -> void:
	SaveData.reset_profile()
	_test_aucun_texte_de_carte_dans_un_label_nu()
	_test_la_fiche_de_sort_du_deck_porte_les_logos()
	_test_la_fiche_de_passif_du_deck_porte_les_logos()
	_test_l_onglet_deck_de_la_pause_porte_les_logos()
	_test_la_carte_brulee_ne_ment_pas_sur_son_temps()
	SaveData.reset_profile()
	RunState.reset()


# --- Balayage du code ---

## Descriptions d objets qui NE SONT PAS des cartes, et qui ne citent aucun
## element : la cle est « fichier|expression ». Chaque entree dit pourquoi.
const EXEMPTES: Dictionary = {
	# ChallengeDef (succes du profil) : « Terminer les 4 niveaux du premier acte ».
	"profile_panel.gd|d.description": true,
}


func _test_aucun_texte_de_carte_dans_un_label_nu() -> void:
	# Le premier argument d un Label est une description, ou un `.text =` qui en
	# recoit une. `\s*` traverse les retours a la ligne : un appel coupe sur deux
	# lignes ne s echappe pas (piege deja paye avec les tailles de police).
	var desc_label := RegEx.new()
	desc_label.compile("UiTheme\\.label(?:_hud)?\\(\\s*([A-Za-z_][\\w\\.\\[\\]]*\\.description)\\b")
	var desc_text := RegEx.new()
	desc_text.compile("\\.text\\s*=\\s*([A-Za-z_][\\w\\.\\[\\]]*\\.description)\\b")
	# Une sortie BBCode du helper dans un Label afficherait « [img=42x42]... ».
	var bbcode_label := RegEx.new()
	bbcode_label.compile("UiTheme\\.label(?:_hud)?\\(\\s*(?:\"[^\"]*\"\\s*\\+\\s*)?"
		+ "(ElementIcons\\.(?:resist_bbcode|resist_line|inline|inline_named|decorate)\\b"
		+ "|BestiaryLore\\.behaviours\\([^)]*true)")
	var fichiers: Array[String] = _scripts("res://scripts/ui")
	ok(fichiers.size() > 5, "les ecrans sont lus (%d fichiers)" % fichiers.size())
	var fautes: Array[String] = []
	var exemptes_vus: int = 0
	for chemin in fichiers:
		var code: String = _code_sans_commentaires(chemin)
		for motif: RegEx in [desc_label, desc_text, bbcode_label]:
			for m in motif.search_all(code):
				var cle: String = "%s|%s" % [chemin.get_file(), m.get_string(1)]
				if EXEMPTES.has(cle):
					exemptes_vus += 1
					continue
				fautes.append("%s : %s" % [chemin.get_file(), m.get_string().replace("\n", " ")])
	eq(fautes, [] as Array[String],
		"aucun texte de carte ni BBCode d element pose dans un Label nu")
	# Une exemption qui ne correspond plus a rien doit disparaitre de la liste.
	eq(exemptes_vus, EXEMPTES.size(), "chaque exemption correspond encore a du code")


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


## Le fichier entier, chaque ligne privee de son commentaire. Un « # » dans une
## chaine n est pas un commentaire : on suit les guillemets.
func _code_sans_commentaires(chemin: String) -> String:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return ""
	var lignes: PackedStringArray = []
	while not f.eof_reached():
		var ligne: String = f.get_line()
		var dans: bool = false
		var coupe: int = ligne.length()
		for i in ligne.length():
			var ch: String = ligne[i]
			if ch == "\"":
				dans = not dans
			elif ch == "#" and not dans:
				coupe = i
				break
		lignes.append(ligne.substr(0, coupe))
	return "\n".join(lignes)


# --- Les ecrans construits ---

## La premiere carte (par id) dont la description cite un element en majuscules.
func _carte_qui_cite_un_element(passif: bool) -> SpellCard:
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	var px: int = ElementIcons.inline_px(UiTheme.FONT_BODY)
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if c == null or c.is_passive != passif:
			continue
		if ElementIcons.decorate(c.description, px) != c.description:
			return c
	return null


func _tous(racine: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in racine.get_children():
		out.append(c)
		out.append_array(_tous(c))
	return out


## Verifie qu un ecran montre la description de `card` en texte a logos, et
## jamais dans un Label nu.
func _verifie_logos(racine: Node, card: SpellCard, ecran: String) -> void:
	var riche: RichTextLabel = null
	for n in _tous(racine):
		if n is Label:
			not_ok((n as Label).text == card.description,
				"%s : la description de %s n est pas dans un Label nu" % [ecran, card.id])
		elif n is RichTextLabel:
			if ElementIcons.strip_inline((n as RichTextLabel).text) == card.description:
				riche = n
	ok(riche != null, "%s : la description de %s est un texte a logos" % [ecran, card.id])
	if riche != null:
		ok(riche.text.contains("[img="), "%s : %s porte un logo dans sa phrase" % [ecran, card.id])


func _test_la_fiche_de_sort_du_deck_porte_les_logos() -> void:
	SaveData.reset_profile()
	var carte: SpellCard = _carte_qui_cite_un_element(false)
	ok(carte != null, "(un sort cite un element en majuscules)")
	if carte == null:
		return
	SaveData.discover_card(carte.id)
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	# Le premier toucher sur la vignette ouvre la fiche (double toucher du deck).
	panel._on_collection_tap(carte)
	_verifie_logos(panel, carte, "fiche de sort du deck")
	detach(panel)


func _test_la_fiche_de_passif_du_deck_porte_les_logos() -> void:
	SaveData.reset_profile()
	var passif: SpellCard = _carte_qui_cite_un_element(true)
	ok(passif != null, "(un passif cite un element en majuscules)")
	if passif == null:
		return
	for lv: LevelDef in ContentDB.levels.values():
		if lv.allows_passives():
			SaveData.unlock_level(lv.id)
			break
	SaveData.discover_card(passif.id)
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	panel.open_passive_picker(0)
	panel.tap_passive(passif)
	eq(panel.passive_detail(), passif, "(la fiche du passif est ouverte)")
	_verifie_logos(panel, passif, "fiche de passif du deck")
	detach(panel)


func _test_l_onglet_deck_de_la_pause_porte_les_logos() -> void:
	var carte: SpellCard = _carte_qui_cite_un_element(false)
	if carte == null:
		return
	RunState.reset()
	RunState.deck.append(carte)
	var nav := DeckBrowser.new()
	attach(nav)
	_verifie_logos(nav, carte, "onglet DECK de la pause")
	ok(nav.row_text(carte).contains(carte.description),
		"la ligne se relit avec sa description entiere")
	detach(nav)
	RunState.reset()


# --- La carte brulee ---

## La carte brulee part SANS incantation (GameController.cast_burned) : son
## plateau de visee ne doit pas afficher le temps d incantation de la carte.
func _test_la_carte_brulee_ne_ment_pas_sur_son_temps() -> void:
	var boule: SpellCard = null
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and c.base_cast_time > 0.0:
			boule = c
			break
	ok(boule != null, "(un sort avec un temps d incantation)")
	if boule == null:
		return
	# Le temps REEL (audit vague 9) : celui que la carte de main affiche.
	var temps: String = ("%.1f" % RunState.effective_cast_time(boule)).trim_suffix(".0") + "s"

	# Une carte de main ordinaire garde son temps : c est la donnee de decision.
	var main := CardView.new()
	main.setup_hand(boule, 200.0, 230.0)
	var l_main: Label = main.find_child("CastTime", true, false) as Label
	ok(l_main != null and l_main.text == temps, "en main, le temps d incantation reste ecrit")
	main.free()

	# La meme carte, instantanee : plus aucun temps, le mot qui dit pourquoi.
	var instant := CardView.new()
	instant.setup_hand(boule, 200.0, 230.0, true)
	var l_inst: Label = instant.find_child("CastTime", true, false) as Label
	ok(l_inst != null and l_inst.text == CardView.INSTANT_TEXT,
		"instantanee, la carte dit %s" % CardView.INSTANT_TEXT)
	for n in _tous(instant):
		if n is Label:
			not_ok((n as Label).text == temps, "instantanee, la carte n affiche pas %s" % temps)
	instant.free()

	# Et c est bien ce que pose le plateau de visee du HUD.
	var g: GameController = (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	g.set_process(false)
	reset_gauge_with_survivable_mage()
	var visee: SpellCard = null
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and c.base_cast_time > 0.0 and g.requires_aim(c):
			visee = c
			break
	ok(visee != null, "(un sort a viser avec un temps d incantation)")
	var hud: Node = g.get_node_or_null("HUD")
	if visee != null and hud != null:
		var t_visee: String = ("%.1f" % RunState.effective_cast_time(visee)).trim_suffix(".0") + "s"
		RunState.pending_offer = [visee]
		eq(g.burn_card(0), visee, "(la carte est brulee)")
		var cv: CardView = hud.find_child("CarteBrulee", true, false) as CardView
		ok(cv != null, "le plateau de visee presente la carte brulee")
		if cv != null:
			var l: Label = cv.find_child("CastTime", true, false) as Label
			ok(l != null and l.text == CardView.INSTANT_TEXT,
				"le plateau dit %s, pas un temps d incantation" % CardView.INSTANT_TEXT)
			for n in _tous(cv):
				if n is Label:
					not_ok((n as Label).text == t_visee,
						"le plateau n affiche pas le temps %s de la carte" % t_visee)
		g.cast_burned(Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y * 0.5))
	detach(g)
	RunState.reset()

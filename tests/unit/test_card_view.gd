extends TestCase
## LISIBILITE DE LA CARTE EN JEU — retours du testeur.
##
##   "la pioche est un peu trop rapide, on n a pas le temps de lire le texte des
##    cartes en jeu"
##   "la carte doit avoir le strict minimum quand on l a en main, et on peut mettre
##    pause pour lire dans le detail"
##   "les polices d ecriture ca ne va pas du tout, c est tres peu lisible"
##
## Ces regles sont invisibles en headless (le rendu ne s execute pas) : on teste
## donc la STRUCTURE produite, qui est ce qui decide de la lisibilite.

func get_suite_name() -> String:
	return "card_view"


func run() -> void:
	_test_la_police_du_jeu_existe()
	_test_la_main_ne_contient_aucune_description()
	_test_la_main_montre_icone_nom_et_temps()
	_test_le_detail_contient_la_description()
	_test_le_nom_court_reste_distinctif()
	_test_le_nom_de_main_ne_se_replie_jamais()
	_test_la_main_tient_pleine()
	_test_le_nom_de_main_ne_depasse_pas_deux_lignes()
	_test_l_icone_corrige_l_occupation_de_la_case()


## La police est le point le plus important du retour. Un fichier absent ferait
## silencieusement retomber tout le jeu sur la police par defaut de Godot — celle
## que le testeur a jugee illisible — sans qu aucune erreur n apparaisse.
func _test_la_police_du_jeu_existe() -> void:
	ok(FileAccess.file_exists(UiTheme.FONT_PATH),
		"le fichier de police %s est present" % UiTheme.FONT_PATH)
	var f: Font = UiTheme.font()
	ok(f != null, "UiTheme.font() charge la police")
	if f == null:
		return
	# Une police qui se charge mais ne mesure rien ne rendrait rien non plus.
	ok(f.get_string_size("Trait arcanique", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x > 0.0,
		"la police mesure un texte")
	# Le theme doit REELLEMENT la porter : sans cela chaque label la reprendrait
	# une par une et le moindre oubli ramenerait la police par defaut.
	var t: Theme = UiTheme.make()
	ok(t.default_font == f, "le theme porte la police du jeu")
	ok(t.get_font(&"font", &"Button") == f, "les boutons portent la police du jeu")


## LA regle du retour numero 3 : rien a lire sur une carte de main.
func _test_la_main_ne_contient_aucune_description() -> void:
	for card: SpellCard in _echantillon():
		var cv := CardView.new()
		cv.setup_hand(card, 125.0, 230.0)
		var textes: Array[String] = _textes(cv)
		not_ok(textes.has(card.description),
			"%s : la description n est PAS sur la carte en main" % card.id)
		# Le nom de rarete en toutes lettres coutait une ligne entiere : la couleur
		# du papier (UiTheme.rarity_bg) porte deja cette information.
		var rarete: String = GameEnums.rarity_name(card.rarity)
		for t in textes:
			not_ok(t.to_lower().contains(rarete.to_lower()),
				"%s : la rarete '%s' n est pas ecrite en main" % [card.id, rarete])
		cv.free()


## Ce qui RESTE doit y etre : sinon la carte devient anonyme.
func _test_la_main_montre_icone_nom_et_temps() -> void:
	for card: SpellCard in _echantillon():
		var cv := CardView.new()
		cv.setup_hand(card, 125.0, 230.0)
		ok(_compte_textures(cv) >= 1, "%s : la carte en main porte son icone" % card.id)
		var textes: Array[String] = _textes(cv)
		# Le nom court peut etre reparti sur DEUX labels : Godot ne sait replier
		# qu en autowrap, qui casse un mot lettre par lettre, donc la carte coupe
		# elle-meme aux espaces. On verifie donc le nom RECOLLE.
		var recolle: String = " ".join(textes)
		ok(recolle.contains(CardView.short_name(card)),
			"%s : la carte en main porte son nom court ('%s' dans '%s')"
			% [card.id, CardView.short_name(card), recolle])
		var attendu: String = ("%.1f" % card.base_cast_time).trim_suffix(".0") + "s"
		ok(textes.has(attendu),
			"%s : la carte en main porte son temps d incantation (%s)" % [card.id, attendu])
		cv.free()


## Le detail est l endroit ou l on lit : il doit tout montrer.
func _test_le_detail_contient_la_description() -> void:
	for card: SpellCard in _echantillon():
		var cv := CardView.new()
		cv.setup_detail(card, 300.0, 440.0)
		var textes: Array[String] = _textes(cv)
		ok(textes.has(card.description), "%s : le detail porte la description" % card.id)
		ok(textes.has(card.display_name), "%s : le detail porte le nom complet" % card.id)
		cv.free()


## Le nom court retire les mots de liaison. Il doit rester NON VIDE et rester
## DIFFERENT d une carte a l autre : deux cartes qui se reduiraient au meme nom
## court redeviendraient impossibles a distinguer, ce qui est le probleme d origine.
func _test_le_nom_court_reste_distinctif() -> void:
	var vus: Dictionary = {}
	for card: SpellCard in ContentDB.cards.values():
		var court: String = CardView.short_name(card)
		ok(court.strip_edges() != "", "%s : le nom court n est pas vide" % card.id)
		not_ok(vus.has(court),
			"le nom court '%s' de %s n est pas deja pris par %s"
			% [court, card.id, vus.get(court, "")])
		vus[court] = String(card.id)


## Le piege connu du projet : UiTheme.label active l autowrap par defaut, et dans
## une colonne de 120 px un mot se replie LETTRE PAR LETTRE ("Double incantatio/n"
## sur la capture du testeur). Tout ce qui doit tenir sur une ligne coupe l autowrap.
func _test_le_nom_de_main_ne_se_replie_jamais() -> void:
	for card: SpellCard in _echantillon():
		var cv := CardView.new()
		cv.setup_hand(card, 125.0, 230.0)
		for l: Label in _labels(cv):
			eq(l.autowrap_mode, TextServer.AUTOWRAP_OFF,
				"%s : '%s' ne se replie pas" % [card.id, l.text])
		cv.free()
	# Et la fabrique doit savoir produire les deux comportements.
	var sans: Label = UiTheme.label("Double incantation", 24, UiTheme.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	eq(sans.autowrap_mode, TextServer.AUTOWRAP_OFF, "UiTheme.label(wrap=false) coupe l autowrap")
	var avec: Label = UiTheme.label("phrase", 24)
	eq(avec.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "UiTheme.label replie par defaut")
	sans.free()
	avec.free()


## La main PLEINE est le pire cas. A cette largeur, le nom doit encore etre ecrit
## assez GROS pour se lire sur un telephone : c est la contrainte qui a fait
## disparaitre la description.
##
## Le nombre vient de GameConfig : ecrire 8 en dur ici a deja empeche de passer la
## main a 6, alors que le test etait cense proteger la LISIBILITE, pas le chiffre.
func _test_la_main_tient_pleine() -> void:
	var n: int = GameConfig.MAX_HAND_SIZE
	var largeur: float = (1052.0 - 6.0 * float(n - 1)) / float(n)
	between(largeur, 118.0, 220.0,
		"%d cartes tiennent dans la largeur de l ecran" % n)
	# Cible tactile : un doigt, pas une souris.
	ok(largeur >= 90.0, "une carte de main reste une cible tactile (>= 90 px)")
	for card: SpellCard in ContentDB.cards.values():
		var cv := CardView.new()
		cv.setup_hand(card, largeur, 230.0)
		for l: Label in _labels(cv):
			var taille: int = l.get_theme_font_size(&"font_size")
			ok(taille >= CardView.NAME_MIN_SIZE,
				"%s : '%s' est ecrit a %d px, au moins %d"
				% [card.id, l.text, taille, CardView.NAME_MIN_SIZE])
		cv.free()


## Le nom tient sur DEUX lignes au plus. Au-dela, la carte redevient un pave de
## texte — exactement ce que le retour du testeur demande de supprimer.
func _test_le_nom_de_main_ne_depasse_pas_deux_lignes() -> void:
	for card: SpellCard in ContentDB.cards.values():
		var cv := CardView.new()
		cv.setup_hand(card, 126.0, 230.0)
		# Les labels de la carte de main : le nom (1 ou 2) plus le temps (1).
		ok(_labels(cv).size() <= 3,
			"%s : la carte en main n a pas plus de 3 lignes de texte (%d)"
			% [card.id, _labels(cv).size()])
		cv.free()


## L icone doit etre recadree sur la partie REELLEMENT dessinee de la case.
## Les feuilles d effets sont loin d etre pleines (cercle de protection 34 %) :
## sans ce recadrage l icone est dessinee sur un tiers de sa vignette, ce qui
## la rend indistincte — le probleme d origine.
func _test_l_icone_corrige_l_occupation_de_la_case() -> void:
	for card: SpellCard in ContentDB.cards.values():
		var sheet: String = CardIcons.for_card(card)
		if sheet == "":
			continue
		var occ: float = CardIcons.occupancy(sheet)
		between(occ, 0.05, 1.0, "%s : occupation de '%s' plausible" % [card.id, sheet])
		var tex: Texture2D = CardIcons.texture(sheet)
		if tex == null or not (tex is AtlasTexture):
			continue
		var at := tex as AtlasTexture
		if at.atlas == null:
			continue
		# La taille de case vient de la FEUILLE, jamais de la region : la deduire
		# de la region rendrait l assertion tautologique (verifie par sabotage —
		# elle restait verte alors que le recadrage etait retire).
		var cell: float = float(at.atlas.get_width())
		if not Fx.STRIPS.has(sheet):
			var w: int = at.atlas.get_width()
			var h: int = at.atlas.get_height()
			cell = 100.0 if (w % 100 == 0 and h % 100 == 0) else float(mini(w, h))
		else:
			cell = float(Fx.STRIPS[sheet][1])
		# La region gardee est la part occupee de la case, pas la case entiere.
		feq(at.region.size.x, cell * occ,
			"%s : la region de '%s' suit l occupation (%.2f)" % [card.id, sheet, occ], 1.0)
		# Une feuille qui n occupe pas toute sa case DOIT etre recadree, sinon
		# l icone se dessine sur une fraction de la vignette.
		if occ < 0.95:
			ok(at.region.size.x < cell - 1.0,
				"%s : '%s' (occ %.2f) est recadree, pas prise en entier"
				% [card.id, sheet, occ])
		ok(at.region.position.x >= 0.0 and at.region.position.y >= 0.0,
			"%s : la region reste dans la feuille" % card.id)


# --- outils ---

## Un echantillon couvrant les 4 raretes et les 4 modes de ciblage : parcourir les
## 44 cartes pour chaque assertion rendrait la suite lente sans rien attraper de plus.
func _echantillon() -> Array[SpellCard]:
	var sortie: Array[SpellCard] = []
	var raretes: Dictionary = {}
	var ciblages: Dictionary = {}
	var ids: Array = ContentDB.cards.keys()
	ids.sort()   # ordre stable : un echec doit etre reproductible
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if raretes.has(c.rarity) and ciblages.has(c.targeting):
			continue
		raretes[c.rarity] = true
		ciblages[c.targeting] = true
		sortie.append(c)
	return sortie


func _labels(root: Node) -> Array[Label]:
	var sortie: Array[Label] = []
	for n in _descendants(root):
		if n is Label:
			sortie.append(n as Label)
	return sortie


func _textes(root: Node) -> Array[String]:
	var sortie: Array[String] = []
	for l: Label in _labels(root):
		sortie.append(l.text)
	return sortie


func _compte_textures(root: Node) -> int:
	var n: int = 0
	for d in _descendants(root):
		if d is TextureRect and (d as TextureRect).texture != null:
			n += 1
	return n


func _descendants(root: Node) -> Array[Node]:
	var sortie: Array[Node] = []
	for child in root.get_children():
		sortie.append(child)
		sortie.append_array(_descendants(child))
	return sortie

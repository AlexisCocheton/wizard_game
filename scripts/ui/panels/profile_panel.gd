class_name ProfilePanel
extends VBoxContainer
## Onglet Profil — la progression du joueur en un coup d oeil.
## Uniquement des donnees reelles de SaveData : pas de statistique inventee.
##
## MISE EN PAGE (refaite le 2026-09-21). Retour du testeur : "tout est ecrit trop
## petit, rends plus lisible et agreable" — et l ecran etait un MUR DE TEXTE :
## seize lignes de la meme taille, de la meme couleur, empilees sans respiration.
## Grossir la police n y suffisait pas ; c est la hierarchie qui manquait.
##
##   +--------------------------------------------------+
##   |  [ SUCCES ] [ COSMETIQUES ] [ STATS ]            |  <- 3 sections, 110 px
##   +--------------------------------------------------+
##   |  +--------------------------------------------+  |
##   |  | [avatar]  NIVEAU 5                         |  |  <- carte d identite
##   |  |           Remonteur de temps               |  |
##   |  |  [============ XP ==============]          |  |
##   |  |  700 / 850 vers le niveau 6                |  |
##   |  +--------------------------------------------+  |
##   |  SUCCES   7 / 16                                 |
##   |  +==========================================+    |  <- contour de RARETE,
##   |  | Intouchable                     EPIQUE   |    |     4 a 7 px selon le rang
##   |  | Terminer un niveau sans subir de degat.  |    |
##   |  | [=========== 0 / 1 ==========]   +900 XP |    |
##   |  +==========================================+    |
##   +--------------------------------------------------+
##
## Trois changements qui font le gros du travail :
##   - couper en SECTIONS : on ne lit plus seize blocs a la fois, mais un sujet ;
##   - un CONTOUR de rarete par succes : la couleur porte l information que le
##     texte portait seul, donc on peut survoler sans lire ;
##   - des tailles prises dans UiTheme, jamais ecrites en dur. L ancienne version
##     passait 19 et 17 a UiTheme.label() : une taille litterale echappe au
##     theme, et c est exactement pourquoi cet ecran etait reste illisible quand
##     tous les autres avaient grossi (piege documente dans gotchas).

enum Section { ACHIEVEMENTS, COSMETICS, STATS }

const SECTIONS: Array[String] = ["SUCCES", "COSMETIQUES", "STATS"]

var _box: VBoxContainer
var _section: int = Section.ACHIEVEMENTS
var _section_buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override(&"separation", 14)
	_build_section_bar()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 18 px entre les blocs : en dessous, les cadres de rarete se touchent et le
	# contour ne se lit plus comme un cadre mais comme une rayure.
	_box.add_theme_constant_override(&"separation", 18)
	scroll.add_child(_box)
	refresh()


## Les trois sections. Cible tactile de 110 px : au pouce, une barre de 60 px se
## rate une fois sur trois.
func _build_section_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 8)
	add_child(bar)
	for i in SECTIONS.size():
		var b := Button.new()
		b.text = SECTIONS[i]
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		b.clip_text = true
		var idx: int = i
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			show_section(idx))
		bar.add_child(b)
		_section_buttons.append(b)


## Pilotable par les tests et par le SMOKE, qui doit capturer chaque section sans
## simuler un toucher.
func show_section(index: int) -> void:
	_section = clampi(index, 0, SECTIONS.size() - 1)
	refresh()


func current_section() -> int:
	return _section


func refresh() -> void:
	for i in _section_buttons.size():
		_section_buttons[i].add_theme_color_override(&"font_color",
			UiTheme.GOLD if i == _section else UiTheme.TEXT)
	if _box == null:
		return
	for c in _box.get_children():
		c.queue_free()
		# Retire tout de suite de l arbre : queue_free() ne prend effet qu a la
		# fin de la frame, et le SMOKE reconstruit deux fois dans la meme frame.
		_box.remove_child(c)

	_build_identity()
	match _section:
		Section.ACHIEVEMENTS: _build_achievements()
		Section.COSMETICS: _build_cosmetics()
		Section.STATS: _build_stats()


## --- CARTE D IDENTITE ---
##
## Toujours affichee, quelle que soit la section : c est le niveau de compte qui
## debloque tout le reste, le joueur doit l avoir sous les yeux quand il regarde
## ce qui lui manque.
func _build_identity() -> void:
	var carte := PanelContainer.new()
	# Contour dore : la carte d identite est le seul bloc qui ne soit pas une
	# liste, elle doit se distinguer de ce qui la suit.
	carte.add_theme_stylebox_override(&"panel",
		UiTheme.flat_box(Color(0.99, 0.96, 0.88), 14, 22.0, UiTheme.GOLD, 5))
	_box.add_child(carte)

	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 18)
	carte.add_child(ligne)

	var avatar := TextureRect.new()
	avatar.texture = UiTheme.tex("avatar")
	avatar.custom_minimum_size = Vector2(120, 120)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ligne.add_child(avatar)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 6)
	ligne.add_child(col)

	var niveau: int = SaveData.account_level()
	col.add_child(UiTheme.label("NIVEAU %d" % niveau, UiTheme.FONT_TITLE,
		Color(0.55, 0.40, 0.05)))

	# Le titre courant : la recompense de type TITRE la plus haute deja obtenue.
	var titre: String = ""
	for r: AccountRewardDef in SaveData.unlocked_rewards():
		if r.kind == GameEnums.RewardKind.TITLE:
			titre = r.display_name
	if titre != "":
		col.add_child(UiTheme.label(titre, UiTheme.FONT_BODY, Color(0.18, 0.42, 0.40)))

	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(0, 40)
	barre.show_percentage = false
	barre.value = SaveData.account_progress() * 100.0
	col.add_child(barre)

	var bas: int = SaveData.account_xp_for_level(niveau)
	var haut: int = SaveData.account_xp_for_level(niveau + 1)
	col.add_child(UiTheme.label("%d / %d XP vers le niveau %d"
		% [SaveData.account_xp() - bas, haut - bas, niveau + 1],
		UiTheme.FONT_SMALL, UiTheme.TEXT_DARK))

	# Ce que le prochain palier de BANNIERE apporte : la banniere change toute
	# seule en haut de l ecran, autant dire au joueur quand elle changera.
	var suivant: int = UiTheme.next_banner_level(niveau)
	if suivant > 0:
		col.add_child(UiTheme.label("Nouvelle banniere au niveau %d" % suivant,
			UiTheme.FONT_SMALL, Color(0.45, 0.35, 0.22)))


## --- SUCCES ---
##
## Les anciens "defis" sont devenus des SUCCES ranges par RARETE, et l XP suit la
## rarete (bareme dans ChallengeDef.xp_for_rarity). Le contour de couleur est ce
## qui permet de voir d un coup d oeil ce qui est a sa portee, sans rien lire.
func _build_achievements() -> void:
	var succes: Array[ChallengeDef] = ContentDB.challenges_list()
	if succes.is_empty():
		return
	var faits: int = SaveData.completed_challenges().size()
	_box.add_child(UiTheme.label("SUCCES   %d / %d" % [faits, succes.size()],
		UiTheme.FONT_BUTTON, UiTheme.GOLD))

	# Ranges du plus rare au plus commun : ce qui reste a viser d abord. A
	# rarete egale, les accomplis descendent en bas — la liste montre donc le
	# travail qui reste, pas le travail deja fait.
	var ordonnes: Array[ChallengeDef] = succes.duplicate()
	ordonnes.sort_custom(func(a: ChallengeDef, b: ChallengeDef) -> bool:
		var fa: bool = SaveData.is_challenge_done(a.id)
		var fb: bool = SaveData.is_challenge_done(b.id)
		if fa != fb:
			return fb
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return a.xp_reward < b.xp_reward)

	for d in ordonnes:
		_achievement_card(d)


func _achievement_card(d: ChallengeDef) -> void:
	var fait: bool = SaveData.is_challenge_done(d.id)
	var p := PanelContainer.new()
	# LE contour de rarete demande par le testeur. Un succes accompli s eclaircit
	# (papier presque blanc) : il reste lisible, mais ne tire plus l oeil.
	p.add_theme_stylebox_override(&"panel", UiTheme.rarity_border(d.rarity,
		Color(0.98, 0.97, 0.93) if fait else Color(0.99, 0.95, 0.85), 12, 20.0))
	_box.add_child(p)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	p.add_child(col)

	var entete := HBoxContainer.new()
	entete.add_theme_constant_override(&"separation", 12)
	col.add_child(entete)

	var nom := UiTheme.label(d.display_name, UiTheme.FONT_BODY,
		UiTheme.GREEN.darkened(0.45) if fait else UiTheme.TEXT_DARK)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Pas de retour a la ligne dans une HBox : un mot s y replierait lettre par
	# lettre (defaut deja paye sur la main de cartes).
	nom.autowrap_mode = TextServer.AUTOWRAP_OFF
	entete.add_child(nom)

	# Le nom de la rarete EN PLUS de la couleur : un joueur daltonien ne lit pas
	# le contour, et une couleur seule n est jamais une information suffisante.
	var rang := UiTheme.label(GameEnums.rarity_name(d.rarity).to_upper(),
		UiTheme.FONT_SMALL, UiTheme.rarity_ink(d.rarity), HORIZONTAL_ALIGNMENT_RIGHT)
	rang.autowrap_mode = TextServer.AUTOWRAP_OFF
	entete.add_child(rang)

	col.add_child(UiTheme.label(d.description, UiTheme.FONT_SMALL,
		Color(0.42, 0.33, 0.24)))

	var bas := HBoxContainer.new()
	bas.add_theme_constant_override(&"separation", 12)
	col.add_child(bas)

	if fait:
		var ok_lab := UiTheme.label("ACCOMPLI", UiTheme.FONT_SMALL,
			UiTheme.GREEN.darkened(0.4))
		ok_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok_lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		bas.add_child(ok_lab)
	else:
		# Une BARRE plutot qu un "0 / 1" perdu dans le texte : l avancement est la
		# seule chose qui bouge d une session a l autre, il doit se voir de loin.
		var vu: int = ChallengeTracker.value_of(d.track_key)
		var barre := ProgressBar.new()
		barre.custom_minimum_size = Vector2(0, 30)
		barre.show_percentage = false
		barre.value = ChallengeTracker.progress_of(d) * 100.0
		barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bas.add_child(barre)
		var chiffre := UiTheme.label("%d / %d" % [mini(vu, d.target), d.target],
			UiTheme.FONT_SMALL, UiTheme.TEAL.darkened(0.35))
		chiffre.autowrap_mode = TextServer.AUTOWRAP_OFF
		bas.add_child(chiffre)

	var xp := UiTheme.label("+%d XP" % d.xp_reward, UiTheme.FONT_SMALL,
		Color(0.62, 0.45, 0.05), HORIZONTAL_ALIGNMENT_RIGHT)
	xp.autowrap_mode = TextServer.AUTOWRAP_OFF
	bas.add_child(xp)


## --- COSMETIQUES ---
##
## Trois axes : la robe du mage, son chapeau, sa tour. Uniquement de l apparence
## — le compte ne donne JAMAIS de puissance, sinon l equilibrage mesure des sept
## niveaux ne vaudrait plus rien et jouer beaucoup vaudrait mieux que jouer bien.
##
## Les verrouilles restent VISIBLES, avec leur niveau : c est ce qui donne envie
## de monter. Les cacher rendrait la progression muette.
func _build_cosmetics() -> void:
	var K := GameEnums.RewardKind
	_box.add_child(UiTheme.label("APPARENCE DU MAGE", UiTheme.FONT_BUTTON, UiTheme.GOLD))
	_box.add_child(UiTheme.label(
		"Change ce que tu vois en combat. Aucun cosmetique ne rend plus fort.",
		UiTheme.FONT_SMALL, Color(0.45, 0.35, 0.22)))

	_cosmetic_group("ROBE", K.MAGE_COLOR)
	_cosmetic_group("CHAPEAU", K.HAT)
	_cosmetic_group("TOUR", K.TOWER)


func _cosmetic_group(titre: String, kind: int) -> void:
	_box.add_child(UiTheme.label(titre, UiTheme.FONT_BODY, Color(0.35, 0.26, 0.15)))

	var porte: String = SaveData.equipped_cosmetic(kind)
	var niveau: int = SaveData.account_level()
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override(&"h_separation", 12)
	grille.add_theme_constant_override(&"v_separation", 12)
	_box.add_child(grille)

	for r: AccountRewardDef in ContentDB.rewards_list():
		if r == null or r.kind != kind:
			continue
		var acquis: bool = r.at_level <= niveau
		var equipe: bool = r.texture_name == porte

		var b := Button.new()
		# 170 px de haut depuis qu une VIGNETTE s y trouve : le nom seul tenait
		# dans 130, l image demande sa place. On choisit ici en regardant.
		b.custom_minimum_size = Vector2(0, 170)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		b.clip_text = true
		b.text = r.display_name if acquis else "Niveau %d" % r.at_level
		b.disabled = not acquis
		# L APERCU. Un ecran dont l objet est l apparence ne peut pas se lire en
		# texte seul : "Robe d encre" ne dit pas sa couleur. La vignette est
		# posee EN HAUT du bouton et le texte dessous, via l alignement vertical
		# du Button — c est ce qui evite d imbriquer un conteneur qui volerait
		# le clic.
		var vignette: Texture2D = UiTheme.cosmetic_preview(kind, r.texture_name)
		if vignette != null:
			# `expand_icon` seul laissait un timbre-poste : le Button ne donne a
			# l icone que la place que le texte lui laisse, et une robe de 20 px
			# ne montre plus sa couleur. Une taille MINIMALE force la vignette a
			# occuper le haut du bouton, et c est le texte qui se serre.
			b.icon = vignette
			b.expand_icon = true
			b.add_theme_constant_override(&"icon_max_width", 104)
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			# Le sprite d un mage verrouille reste VISIBLE mais terne : cacher
			# ce qu on n a pas encore retire au palier toute envie de l atteindre.
			if not acquis:
				b.modulate = Color(0.62, 0.60, 0.58)
		# Le jeton EQUIPE porte un contour dore : dans une grille, c est le seul
		# moyen de dire "celui-la" sans ajouter une ligne de texte par case.
		var cadre: StyleBoxFlat = UiTheme.flat_box(
			Color(1.0, 0.95, 0.78) if equipe else Color(0.96, 0.93, 0.86),
			12, 14.0,
			UiTheme.GOLD if equipe else Color(0.62, 0.54, 0.42),
			6 if equipe else 3)
		b.add_theme_stylebox_override(&"normal", cadre)
		b.add_theme_stylebox_override(&"hover", cadre)
		b.add_theme_stylebox_override(&"pressed", cadre)
		b.add_theme_stylebox_override(&"disabled", UiTheme.flat_box(
			Color(0.86, 0.84, 0.80), 12, 14.0, Color(0.66, 0.62, 0.58), 3))
		b.add_theme_color_override(&"font_color",
			Color(0.45, 0.32, 0.05) if equipe else UiTheme.TEXT_DARK)
		b.add_theme_color_override(&"font_disabled_color", Color(0.52, 0.48, 0.44))

		if acquis and not equipe:
			var rid: StringName = r.id
			b.pressed.connect(func() -> void:
				AudioBus.play_sfx(&"ui_tap")
				SaveData.equip_cosmetic(rid)
				# On se reconstruit : le cadre dore doit sauter sur le nouveau.
				refresh())
		grille.add_child(b)


## --- STATS ---
##
## Ce que le joueur a vraiment fait, en lignes courtes. Rien d invente : chaque
## chiffre vient de SaveData ou de ContentDB.
func _build_stats() -> void:
	var total_cards: int = ContentDB.cards.size()
	var legendaries: int = ContentDB.cards_of_rarity(GameEnums.Rarity.LEGENDARY).size()
	var cleared: int = 0
	for level: LevelDef in ContentDB.levels.values():
		if SaveData.is_level_cleared(level.id):
			cleared += 1

	_box.add_child(UiTheme.label("PROGRESSION", UiTheme.FONT_BUTTON, UiTheme.GOLD))
	_row("Cartes decouvertes", "%d / %d" % [SaveData.discovered_count(), total_cards])
	_row("Legendaires obtenues", "%d / %d"
		% [SaveData.unlocked_legendaries().size(), legendaries], Color(0.62, 0.45, 0.05))
	_row("Monstres rencontres", "%d" % SaveData.discovered_enemies_count())
	_row("Niveaux termines", "%d / %d" % [cleared, ContentDB.levels.size()],
		UiTheme.GREEN.darkened(0.4))

	_box.add_child(UiTheme.label("PAR NIVEAU", UiTheme.FONT_BUTTON, UiTheme.GOLD))
	var ids: Array = ContentDB.levels.keys()
	ids.sort()
	for id in ids:
		var level: LevelDef = ContentDB.levels[id]
		if not SaveData.is_level_unlocked(level.id):
			_row(level.display_name, "verrouille", Color(0.55, 0.50, 0.46))
			continue
		var rec: Dictionary = SaveData.level_record(level.id)
		var objs: int = SaveData.objectives_done_count(level)
		_row(level.display_name, "vague %d   -   objectifs %d/%d" % [
			int(rec.get("best_wave", 0)), objs, level.objectives.size()],
			UiTheme.GREEN.darkened(0.4) if SaveData.is_level_cleared(level.id)
			else UiTheme.TEXT_DARK)


func _row(title: String, value: String, color: Color = UiTheme.TEXT_DARK) -> void:
	var p := PanelContainer.new()
	_box.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	p.add_child(h)
	var l := UiTheme.label(title, UiTheme.FONT_BODY, Color(0.45, 0.35, 0.22))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	# Pas de retour a la ligne : dans une HBox, la valeur se plierait lettre par lettre.
	var v := UiTheme.label(value, UiTheme.FONT_BODY, color, HORIZONTAL_ALIGNMENT_RIGHT)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(v)

class_name ProfilePanel
extends VBoxContainer
## Onglet Profil — la progression du joueur en un coup d oeil.
## Uniquement des donnees reelles de SaveData : pas de statistique inventee.

var _box: VBoxContainer


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override(&"separation", 14)
	scroll.add_child(_box)
	refresh()


func _row(title: String, value: String, color: Color = UiTheme.TEXT_DARK) -> void:
	var p := PanelContainer.new()
	_box.add_child(p)
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := UiTheme.label(title, UiTheme.FONT_BODY, UiTheme.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	# Pas de retour a la ligne : dans une HBox, la valeur se plierait lettre par lettre.
	var v := UiTheme.label(value, UiTheme.FONT_BODY, color, HORIZONTAL_ALIGNMENT_RIGHT)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(v)


func refresh() -> void:
	for c in _box.get_children():
		c.queue_free()

	_build_account()
	_build_challenges()
	_build_rewards()

	var total_cards: int = ContentDB.cards.size()
	var legendaries: int = ContentDB.cards_of_rarity(GameEnums.Rarity.LEGENDARY).size()
	var cleared: int = 0
	for level: LevelDef in ContentDB.levels.values():
		if SaveData.is_level_cleared(level.id):
			cleared += 1

	_box.add_child(UiTheme.label("PROGRESSION", UiTheme.FONT_BODY, UiTheme.GOLD))
	_row("Cartes decouvertes", "%d / %d" % [SaveData.discovered_count(), total_cards])
	_row("Legendaires obtenues", "%d / %d" % [SaveData.unlocked_legendaries().size(), legendaries], UiTheme.GOLD)
	_row("Niveaux termines", "%d / %d" % [cleared, ContentDB.levels.size()], UiTheme.GREEN)
	_row("Deck Massacre", "%d cartes" % SaveData.massacre_deck().size())

	_box.add_child(UiTheme.label("PAR NIVEAU", UiTheme.FONT_BODY, UiTheme.GOLD))
	var ids: Array = ContentDB.levels.keys()
	ids.sort()
	for id in ids:
		var level: LevelDef = ContentDB.levels[id]
		if not SaveData.is_level_unlocked(level.id):
			_row(level.display_name, "verrouille", UiTheme.TEXT_DIM)
			continue
		var rec: Dictionary = SaveData.level_record(level.id)
		var objs: int = SaveData.objectives_done_count(level)
		_row(level.display_name, "vague %d   -   objectifs %d/%d" % [
			int(rec.get("best_wave", 0)), objs, level.objectives.size()],
			UiTheme.GREEN if SaveData.is_level_cleared(level.id) else UiTheme.TEXT_DARK)


## --- Progression de COMPTE ---
##
## Le joueur voyait ses cartes et ses niveaux, mais rien qui grandisse avec lui
## d une partie a l autre. Le compte donne ce fil : un palier atteint, des defis
## a viser, des titres a debloquer. Uniquement du cosmetique — aucune recompense
## ne touche a la puissance, sinon l equilibrage mesure des niveaux ne vaudrait
## plus rien et jouer beaucoup vaudrait mieux que jouer bien.
func _build_account() -> void:
	var niveau: int = SaveData.account_level()
	_box.add_child(UiTheme.label("NIVEAU DE COMPTE  %d" % niveau,
		UiTheme.FONT_BODY, UiTheme.GOLD))

	# Le titre courant : la recompense la plus haute deja obtenue.
	var titre: String = ""
	for r: AccountRewardDef in SaveData.unlocked_rewards():
		if r.kind == GameEnums.RewardKind.TITLE:
			titre = r.display_name
	if titre != "":
		_box.add_child(UiTheme.label(titre, 24, UiTheme.TEAL, HORIZONTAL_ALIGNMENT_CENTER))

	# Barre d avancement vers le palier suivant.
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(0, 34)
	barre.show_percentage = false
	barre.value = SaveData.account_progress() * 100.0
	_box.add_child(barre)

	var bas: int = SaveData.account_xp_for_level(niveau)
	var haut: int = SaveData.account_xp_for_level(niveau + 1)
	_box.add_child(UiTheme.label(
		"%d / %d XP vers le niveau %d" % [SaveData.account_xp() - bas, haut - bas, niveau + 1],
		19, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))


## Les defis : ce qu il reste a viser, avec leur avancement reel.
func _build_challenges() -> void:
	var defis: Array[ChallengeDef] = ContentDB.challenges_list()
	if defis.is_empty():
		return
	var faits: int = SaveData.completed_challenges().size()
	_box.add_child(UiTheme.label("DEFIS  (%d / %d)" % [faits, defis.size()],
		UiTheme.FONT_BODY, UiTheme.GOLD))

	for d in defis:
		var fait: bool = SaveData.is_challenge_done(d.id)
		var p := PanelContainer.new()
		_box.add_child(p)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 2)
		p.add_child(col)

		var ligne := HBoxContainer.new()
		col.add_child(ligne)
		var nom := UiTheme.label("%s %s" % ["[OK]" if fait else "[   ]", d.display_name],
			22, Color(0.2, 0.5, 0.25) if fait else UiTheme.TEXT_DARK)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nom.autowrap_mode = TextServer.AUTOWRAP_OFF
		ligne.add_child(nom)
		var xp := UiTheme.label("+%d XP" % d.xp_reward, 19, UiTheme.GOLD,
			HORIZONTAL_ALIGNMENT_RIGHT)
		xp.autowrap_mode = TextServer.AUTOWRAP_OFF
		ligne.add_child(xp)

		col.add_child(UiTheme.label(d.description, 17, Color(0.42, 0.33, 0.24)))
		if not fait:
			# L avancement chiffre : un defi sans progres visible n en est pas un.
			var vu: int = ChallengeTracker.value_of(d.track_key)
			col.add_child(UiTheme.label("%d / %d" % [mini(vu, d.target), d.target],
				17, UiTheme.TEAL))


## Ce que le compte a deja debloque, et ce qui vient ensuite.
func _build_rewards() -> void:
	var toutes: Array[AccountRewardDef] = ContentDB.rewards_list()
	if toutes.is_empty():
		return
	_box.add_child(UiTheme.label("RECOMPENSES", UiTheme.FONT_BODY, UiTheme.GOLD))
	var niveau: int = SaveData.account_level()
	for r in toutes:
		var acquis: bool = r.at_level <= niveau
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override(&"separation", 10)
		_box.add_child(ligne)

		# Un avatar debloque montre son image ; verrouille, il reste anonyme.
		if r.kind == GameEnums.RewardKind.AVATAR and acquis and r.texture_name != "":
			var ico := TextureRect.new()
			ico.texture = UiTheme.tex(r.texture_name)
			ico.custom_minimum_size = Vector2(44, 44)
			ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ligne.add_child(ico)

		var texte: String = r.display_name if acquis else "Niveau %d  -  ???" % r.at_level
		var lab := UiTheme.label(texte, 21,
			UiTheme.TEXT_DARK if acquis else UiTheme.TEXT_DIM)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		ligne.add_child(lab)

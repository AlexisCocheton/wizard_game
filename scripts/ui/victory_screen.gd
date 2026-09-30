extends Control
## Ecran de victoire : resume, badges d objectifs, cartes debloquees par les
## objectifs (chantier P : chaque objectif ajoute sa carte au pool du niveau).
## Toute la logique de progression vit dans SaveData.record_victory() — testee
## a froid — cet ecran ne fait que l afficher.

@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _objectives: VBoxContainer = %Objectives
@onready var _menu_btn: Button = %MenuButton

## Meme pastille que la carte de campagne : le pack n a pas d icone d etoile, et
## la piece d or est la seule forme ronde qui se lit a cette taille (DEC-012).
const STAR_ICON: int = 3


func _ready() -> void:
	theme = UiTheme.make()
	_menu_btn.pressed.connect(func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))
	_title.text = "NIVEAU TERMINE"
	_title.add_theme_color_override(&"font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE)

	var level_id: StringName = SceneRouter.payload.get("level_id", &"lvl_01")
	var level: LevelDef = ContentDB.levels.get(level_id)
	_summary.text = "Niveau joueur %d   -   %d vagues survecues" % [
		RunState.level, RunState.wave_index]
	_summary.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	if level == null:
		return

	var done: Dictionary = {}
	for obj in level.objectives:
		if obj != null:
			done[obj.id] = ObjectiveChecker.evaluate(obj)

	# Defis de compte : un niveau fini, et la performance s il n a rien encaisse.
	var cleared: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		if SaveData.is_level_cleared(lv.id):
			cleared += 1
	ChallengeTracker.record_best(&"levels_cleared", cleared + 1)
	if not RunState.took_any_damage:
		ChallengeTracker.bump(&"flawless_clears")
	# Succes de COLLECTION : ils comptent ce que le grimoire compte (retouche du
	# 30/09). `cards_discovered` (« Collectionneur ») lit les cartes OBTENUES,
	# sorts et passifs, par le compteur honnete de SaveData — le numerateur de
	# la barre du menu. Il lisait discovered_count(), la liste brute du profil :
	# un id perime la gonflait, et le succes pouvait tomber a un chiffre que
	# le grimoire n affichait pas. Meme regle pour les monstres : le numerateur
	# du bestiaire, qui ne compte pas les munitions (projectiles) comme des
	# especes. record_best garde le maximum : un ancien profil ne perd rien.
	ChallengeTracker.record_best(&"cards_discovered", cards_obtained())
	ChallengeTracker.record_best(&"enemies_discovered", enemies_met())

	# Ce que les objectifs avaient deja ouvert AVANT cette victoire : la
	# difference avec l apres est ce qui vient de s ouvrir, et seul cela se fete.
	var avant: Array[SpellCard] = SaveData.objective_rewards_unlocked(level)
	SaveData.record_victory(level, RunState.mode, done, RunState.wave_index)
	SaveData.save_profile()
	var nouvelles: Array[SpellCard] = []
	for c in SaveData.objective_rewards_unlocked(level):
		if not avant.has(c):
			nouvelles.append(c)

	_remplir(level, done, nouvelles)


## Le chiffre du succes « Collectionneur » : les cartes OBTENUES (sorts et
## passifs), le numerateur de SaveData.card_counts() — celui du grimoire, du
## deck, du profil et de la barre du menu. Statique pour le test.
static func cards_obtained() -> int:
	return int(SaveData.card_counts()[0])


## Le chiffre des succes du bestiaire : les especes rencontrees, le numerateur
## de SaveData.enemy_counts() — celui du grimoire et du profil.
static func enemies_met() -> int:
	return int(SaveData.enemy_counts()[0])


## L ecran de victoire est le moment de RECOMPENSE, et il ressemblait a un
## journal d erreurs : des prefixes "[OK]" / "[   ]" en tete de ligne, aucune
## etoile alors que la carte de campagne en compte trois par niveau, aucune
## trace de l XP de compte gagnee, et un grand vide au milieu de la page.
## L ecran de DEFAITE en disait davantage au joueur que celui de victoire.
##
## Trois blocs, dans l ordre de ce qui compte : les ETOILES obtenues, ce qui
## vient de S OUVRIR, puis l avancement du COMPTE.
func _remplir(level: LevelDef, done: Dictionary, nouvelles: Array[SpellCard]) -> void:
	var gagnees: int = 0
	for obj in level.objectives:
		if obj != null and bool(done.get(obj.id, false)):
			gagnees += 1

	# --- Les etoiles, en gros, avant tout le reste ---
	# La liste respire : sans separation, les trois blocs se collaient en haut
	# de la page et laissaient la moitie basse vide (vu sur capture).
	_objectives.add_theme_constant_override(&"separation", 14)
	_objectives.alignment = BoxContainer.ALIGNMENT_CENTER

	var rangee := HBoxContainer.new()
	rangee.alignment = BoxContainer.ALIGNMENT_CENTER
	rangee.add_theme_constant_override(&"separation", 26)
	_objectives.add_child(rangee)
	for i in level.objectives.size():
		# Grandes : c est l image que le joueur retient de sa partie.
		var s: TextureRect = UiTheme.icon(STAR_ICON, 132.0 if i < gagnees else 92.0)
		# Meme regle que sur la carte de campagne : acquise = pleine, doree et
		# GRANDE ; manquante = un creux sombre et reduit. La forme porte
		# l information autant que la couleur.
		s.modulate = Color(1.0, 0.88, 0.35) if i < gagnees 			else Color(0.30, 0.26, 0.22, 0.45)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(s)

	_objectives.add_child(UiTheme.label(
		"%d objectif%s sur %d" % [gagnees, "s" if gagnees > 1 else "",
			level.objectives.size()],
		UiTheme.FONT_BODY, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

	# --- Le detail : ce qui est pris, ce qui reste a prendre ---
	for i in level.objectives.size():
		var obj: ObjectiveDef = level.objectives[i]
		if obj == null:
			continue
		var pris: bool = bool(done.get(obj.id, false))
		# Plus de prefixe entre crochets : la couleur et le mot disent l etat.
		# "[   ]" se lisait comme une case a cocher cassee.
		_objectives.add_child(UiTheme.label(
			"%s  -  %s" % ["Reussi" if pris else "A refaire", ObjectiveChecker.label(obj)],
			UiTheme.FONT_SMALL,
			Color(0.16, 0.46, 0.22) if pris else Color(0.52, 0.42, 0.30)))
		# CE QUE L OBJECTIF RAPPORTE, sous lui : sans cette ligne, rater un
		# objectif ne coute rien de visible et le reussir ne promet rien.
		var carte: SpellCard = level.objective_reward(i)
		if carte != null:
			_objectives.add_child(UiTheme.label("      %s : %s (%s)" % [
				"rapporte" if pris or SaveData.is_objective_done(level.id, obj.id) 					else "rapporterait", carte.display_name,
				GameEnums.rarity_name(carte.rarity)],
				UiTheme.FONT_SMALL, UiTheme.rarity_ink(carte.rarity)))

	# --- Ce qui vient de s ouvrir ---
	# La carte n est pas DONNEE : elle entre dans le pool de montee de niveau du
	# niveau, et s obtient en la prenant en combat. Le texte le dit, sinon le
	# joueur la cherche dans son deck et croit a un bug.
	for c in nouvelles:
		_objectives.add_child(UiTheme.label(
			"Nouvelle carte a gagner ici : %s" % c.display_name,
			UiTheme.FONT_BODY, UiTheme.rarity_ink(c.rarity), HORIZONTAL_ALIGNMENT_CENTER))
	if not nouvelles.is_empty():
		_objectives.add_child(UiTheme.label(
			"Elle pourra t etre proposee a la montee de niveau de ce niveau",
			UiTheme.FONT_SMALL, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))
	if not level.next_levels.is_empty():
		_objectives.add_child(UiTheme.label("Niveau suivant debloque",
			UiTheme.FONT_BODY, UiTheme.TEAL, HORIZONTAL_ALIGNMENT_CENTER))

	# --- Le compte : la progression qui SURVIT a la partie ---
	# Sans ce bloc, le joueur finit un niveau sans jamais voir bouger la seule
	# chose qui le suit d une partie a l autre.
	_objectives.add_child(UiTheme.label("COMPTE  -  niveau %d"
		% SaveData.account_level(), UiTheme.FONT_BODY, UiTheme.GOLD.darkened(0.25),
		HORIZONTAL_ALIGNMENT_CENTER))
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(0, 34)
	barre.show_percentage = false
	barre.value = SaveData.account_progress() * 100.0
	_objectives.add_child(barre)
	var bas: int = SaveData.account_xp_for_level(SaveData.account_level())
	var haut: int = SaveData.account_xp_for_level(SaveData.account_level() + 1)
	_objectives.add_child(UiTheme.label("%d / %d XP vers le niveau %d"
		% [SaveData.account_xp() - bas, haut - bas, SaveData.account_level() + 1],
		UiTheme.FONT_SMALL, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

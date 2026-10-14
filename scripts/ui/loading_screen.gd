class_name LoadingScreen
extends Control
## Ecran de briefing, entre le menu et la partie.
##
## Le joueur choisissait un niveau et se retrouvait immediatement au combat, sans
## savoir ce qui l attendait : ni le nombre de vagues, ni le boss, ni les monstres.
## Cet ecran montre ce qu il va affronter et avec quoi, pour qu il puisse penser
## son deck avant et non apres.
##
## Il n affiche QUE des donnees reelles lues dans les .tres du niveau. Rien n est
## invente ici : si une information manque, la ligne disparait.
##
## REFAIT A LA VAGUE 10 (demande du co-auteur : « plus clair, lisible et
## ergonomique, notamment sur les monstres et leurs effets, les nouvelles cartes
## obtenables, les objectifs »). Ce qui manquait, constate sur le contenu :
##   - aucune mecanique de monstre : un nom et une silhouette, rien de ce qu il
##     FAIT ; et UN SEUL boss affiche (la variable etait ecrasee : lvl_02 en a deux) ;
##   - les cartes de la montee de niveau absentes, `intro_text` jamais lu, le deck
##     en texte ;
##   - pas de defilement : lvl_02, lvl_07 et lvl_13 debordaient sous les boutons.
## Quatre sections, dans l ordre ou le joueur en a besoin, sous l intro du niveau :
##   MONSTRES        boss et mini-boss en tete (avec leur vague), puis les autres
##                   dans l ordre d arrivee ; portrait, nom, UNE ligne de mecanique
##                   (ThreatLore.mechanic_line), resistances en logos ;
##   CARTES A GAGNER ce que la montee de niveau et les objectifs peuvent donner,
##                   avec rarete et etat (a gagner, obtenue, objectif N) ;
##   OBJECTIFS       du plus facile au plus dur (leur position EST leur rang) ;
##   TON DECK        en vignettes, une par carte, avec le nombre de copies.
## Tout defile au doigt (TouchScroll) ; COMMENCER et RETOUR restent en bas, hors
## defilement, sous le pouce.

const HOLD_SECONDS: float = 0.35   ## laisse le temps de lire avant que le bouton reponde

## Portraits des monstres (px de page) : un boss se reconnait d abord a sa taille.
const MONSTER_PX: float = 104.0
const BOSS_PX: float = 132.0
## Vignettes de cartes : trois par rangee pour les cartes a gagner, quatre pour
## le deck. Largeur utile de la page : 1080 - 2 x 56 = 968 px.
const CARD_TILE_W: float = 290.0
const CARD_ART_PX: float = 96.0
const CARDS_PER_ROW: int = 3
## Au-dela, les cartes restantes tiennent en une ligne de texte. Le pool de
## montee de niveau peut contenir toutes les cartes obtenues (chantier
## progression) : trente vignettes noieraient les trois nouvelles.
const MAX_CARD_TILES: int = 9
const DECK_TILE_W: float = 220.0
const DECK_ART_PX: float = 80.0
const DECK_PER_ROW: int = 4
## Le rang d un objectif en un mot, de 1 (le plus facile) a 3.
const RANK_WORDS: Array[String] = ["Facile", "Moyen", "Difficile"]

## Etat d une carte a gagner.
enum Etat { A_GAGNER, OBJECTIF, OBTENUE }

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _body: VBoxContainer = %Body
@onready var _waves: VBoxContainer = %Waves
@onready var _deck: VBoxContainer = %Deck
@onready var _start_btn: Button = %StartButton
@onready var _back_btn: Button = %BackButton

var _level: LevelDef = null
var _mode: GameEnums.Mode = GameEnums.Mode.EXPLORATION
var _armed: bool = false


func _ready() -> void:
	theme = UiTheme.make()
	UiTheme.style_primary(_start_btn)
	_start_btn.pressed.connect(_on_start)
	_back_btn.pressed.connect(func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))
	# Le corps defile au doigt ; titre et boutons restent fixes.
	TouchScroll.wrap(_body)

	var level_id: StringName = SceneRouter.payload.get("level_id", &"lvl_01")
	_mode = SceneRouter.payload.get("mode", GameEnums.Mode.EXPLORATION)
	# MODES (chantier M) : le Massacre n est pas dans ContentDB, son niveau est
	# fabrique par MassacreMode.
	_level = MassacreMode.resolve_level(level_id, _mode)
	_build()

	# Le bouton ne repond pas instantanement : sans ce delai, un double appui sur
	# "JOUER" dans le menu traversait cet ecran sans qu on le voie.
	await get_tree().create_timer(HOLD_SECONDS).timeout
	_armed = true


func _build() -> void:
	if _level == null:
		_title.text = "NIVEAU INTROUVABLE"
		return
	_title.text = _level.display_name.to_upper()
	_title.add_theme_color_override(&"font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Le nom du mode vient de GameEnums.mode_name (Campagne, Libre, Massacre).
	var nom_mode: String = GameEnums.mode_name(_mode)
	if _mode == GameEnums.Mode.MASSACRE:
		_subtitle.text = "%s  -  tous les mondes a la fois, ton deck" % nom_mode
	elif _mode == GameEnums.Mode.FREE:
		_subtitle.text = "%s  -  %d vagues, ton deck : seuls les objectifs comptent" \
			% [nom_mode, _level.waves.size()]
	else:
		_subtitle.text = "%s  -  %d vagues, deck de campagne" % [nom_mode, _level.waves.size()]
	_subtitle.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_intro()
	_build_threats()
	show_cards_to_win(cards_to_win(_level, _mode, _deck_list()))
	_build_objectives()
	_build_deck()


## Le texte d ouverture du niveau (LevelDef.intro_text) : ecrit depuis la
## campagne, il n etait lu nulle part. En tete du corps, a l encre douce : c est
## le decor, pas une consigne.
func _build_intro() -> void:
	if _level == null or _level.intro_text.strip_edges() == "":
		return
	var intro: Label = UiTheme.label(_level.intro_text.strip_edges(), UiTheme.FONT_SMALL,
		UiTheme.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	intro.name = "Intro"
	_body.add_child(intro)
	_body.move_child(intro, 0)


## Une section : son titre et une colonne. Rend la colonne.
func _section(parent: VBoxContainer, titre: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(col)
	col.add_child(BattleReport.heading(titre))
	return col


# --- MONSTRES -------------------------------------------------------------------

## Ce qui arrive : boss et mini-boss d abord, puis les autres.
func _build_threats() -> void:
	if _mode == GameEnums.Mode.MASSACRE:
		_build_massacre_threats(_section(_waves, "MONSTRES"))
		return
	var liste: Array[Dictionary] = threat_list(_level, _mode)
	var col: VBoxContainer = _section(_waves, "MONSTRES  (%d)" % liste.size())
	col.name = "Monsters"
	for e in liste:
		col.add_child(_monster_row(e))


## LES MONSTRES DU NIVEAU, sans doublon ni projectile : [{def, role, wave}].
##   role : &"boss", &"miniboss" ou &"" ; wave : premiere vague (1 = la premiere),
##   0 dans les modes sans fin (le pool n a pas de vagues ecrites).
## Ordre : TOUS les boss, puis TOUS les mini-boss (l ancien ecran n en gardait
## qu un de chaque : la variable etait ecrasee), puis les autres dans l ordre
## d arrivee ; a vague egale, le plus puissant d abord. Statique : le test le lit.
static func threat_list(level: LevelDef, mode: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if level == null:
		return out
	var premiere: Dictionary = {}
	var ordre: Array[EnemyDef] = []
	if GameEnums.is_endless(mode) and not level.enemy_pool.is_empty():
		for d in level.enemy_pool:
			if d != null and not d.projectile and not premiere.has(d):
				premiere[d] = 0
				ordre.append(d)
	else:
		for i in level.waves.size():
			var w: WaveDef = level.waves[i]
			if w == null:
				continue
			for entry: WaveEntry in w.entries:
				if entry == null or entry.enemy == null or entry.enemy.projectile:
					continue
				if not premiere.has(entry.enemy):
					premiere[entry.enemy] = i + 1
					ordre.append(entry.enemy)
	for d in ordre:
		out.append({"def": d, "role": role_of(d), "wave": int(premiere[d])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = _role_rank(a["role"])
		var rb: int = _role_rank(b["role"])
		if ra != rb:
			return ra < rb
		if int(a["wave"]) != int(b["wave"]):
			return int(a["wave"]) < int(b["wave"])
		var da: EnemyDef = a["def"]
		var db: EnemyDef = b["def"]
		if da.power != db.power:
			return da.power > db.power
		return String(da.display_name) < String(db.display_name))
	return out


static func role_of(def: EnemyDef) -> StringName:
	if def.kind == GameEnums.EnemyKind.BOSS:
		return &"boss"
	if def.kind == GameEnums.EnemyKind.MINIBOSS:
		return &"miniboss"
	return &""


static func _role_rank(role: StringName) -> int:
	match role:
		&"boss": return 0
		&"miniboss": return 1
	return 2


## Une ligne de monstre : [portrait]  BOSS - vague 6 / Nom / mecanique / logos.
func _monster_row(e: Dictionary) -> Control:
	var def: EnemyDef = e["def"]
	var role: StringName = e["role"]
	var row := HBoxContainer.new()
	row.name = "MonsterRow_%s" % def.id
	row.set_meta(&"briefing_enemy", def.id)
	row.add_theme_constant_override(&"separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(BestiaryLore.portrait_of(def, BOSS_PX if role != &"" else MONSTER_PX, true))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	if role != &"":
		var quoi: String = "BOSS" if role == &"boss" else "MINI-BOSS"
		var ou: String = ("  -  vague %d" % int(e["wave"])) if int(e["wave"]) > 0 else ""
		var tag: Label = UiTheme.label(quoi + ou, UiTheme.FONT_SMALL, UiTheme.INK_DANGER)
		tag.name = "Role"
		col.add_child(tag)
	col.add_child(UiTheme.label(def.display_name, UiTheme.FONT_BODY, UiTheme.TEXT_DARK))
	var meca: Label = UiTheme.label(ThreatLore.mechanic_line(def), UiTheme.FONT_SMALL,
		UiTheme.INK_SOFT)
	meca.name = "Mechanic"
	col.add_child(meca)
	var res: String = ElementIcons.resist_compact(def,
		ElementIcons.inline_px(UiTheme.FONT_SMALL), true)
	if res != "":
		var r: RichTextLabel = ElementIcons.rich_label(res, UiTheme.FONT_SMALL, UiTheme.TEXT_DARK)
		r.name = "Resist"
		col.add_child(r)
	return row


## MASSACRE : tout le bestiaire des niveaux, trop pour une ligne par monstre
## (plus de soixante). On DIT l ampleur en chiffres reels, et on montre un
## echantillon : les plus puissants, soit ce qui fait peur, pas les gnomes.
const MASSACRE_SAMPLE: int = 10


func _build_massacre_threats(col: VBoxContainer) -> void:
	var pool: Array[EnemyDef] = MassacreMode.enemy_pool()
	var boss: Array[EnemyDef] = MassacreMode.boss_pool()
	col.add_child(UiTheme.label(
		"%d monstres de tous les mondes, melanges  -  %d boss et mini-boss aux paliers" % [
			pool.size(), boss.size()], UiTheme.FONT_SMALL, UiTheme.TEXT_DARK))
	var tries: Array[EnemyDef] = pool.duplicate()
	tries.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool:
		if a.power != b.power:
			return a.power > b.power
		return String(a.id) < String(b.id))
	var wrap := HFlowContainer.new()
	wrap.add_theme_constant_override(&"h_separation", 14)
	wrap.add_theme_constant_override(&"v_separation", 10)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n: int = 0
	for d in tries:
		if n >= MASSACRE_SAMPLE:
			break
		# Sans feuille d animation, pas de vignette : un nom seul dans la rangee
		# se lirait comme un trou.
		if d.anim_key == &"" or not AnimCatalog.has(d.anim_key):
			continue
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(176.0, 0.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait: Control = BestiaryLore.portrait_of(d, MONSTER_PX, true)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(portrait)
		var nom: Label = UiTheme.label(d.display_name, UiTheme.FONT_SMALL, UiTheme.TEXT_DARK,
			HORIZONTAL_ALIGNMENT_CENTER)
		# WORD, pas WORD_SMART : "smart" coupe un mot trop long au milieu.
		nom.autowrap_mode = TextServer.AUTOWRAP_WORD
		cell.add_child(nom)
		wrap.add_child(cell)
		n += 1
	# Jamais orpheline : un noeud cree hors de l arbre fuit a la sortie.
	if n > 0:
		col.add_child(wrap)
	else:
		wrap.free()


# --- CARTES A GAGNER --------------------------------------------------------------

## LES CARTES QUE CE NIVEAU PEUT FAIRE GAGNER. La regle du pool n est PAS ecrite
## ici : elle vient de RunState.levelup_pool (le chantier progression la redefinit,
## cet ecran suit sans changer). On y ajoute les recompenses d objectif, qui
## n entrent au pool qu une fois l objectif reussi, et on retire le deck : il est
## deja dans la main du joueur. Ordre : les SORTS avant les passifs (des l acte 2,
## le pool porte tous les passifs : trente vignettes repoussaient les recompenses
## d objectif hors de la page, mesure sur lvl_07) ; puis a gagner, recompenses
## encore fermees (par rang), obtenu ; rarete decroissante ; nom.
static func cards_to_win(level: LevelDef, mode: int, deck: Array) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	if level == null:
		return out
	var dans_deck: Dictionary = {}
	for c in deck:
		if c != null:
			dans_deck[(c as SpellCard).id] = true
	var pool: Array[SpellCard] = RunState.levelup_pool(level, mode)
	for c in pool:
		if c != null and not dans_deck.has(c.id) and not out.has(c):
			out.append(c)
	if not GameEnums.is_endless(mode):
		for i in level.objectives.size():
			var r: SpellCard = level.objective_reward(i)
			if r != null and not dans_deck.has(r.id) and not out.has(r):
				out.append(r)
	var etats: Dictionary = {}
	var rangs: Dictionary = {}
	for c in out:
		var st: Dictionary = card_state(c, level, pool)
		etats[c.id] = int(st["etat"])
		rangs[c.id] = int(st["rank"])
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		if a.is_passive != b.is_passive:
			return not a.is_passive
		if int(etats[a.id]) != int(etats[b.id]):
			return int(etats[a.id]) < int(etats[b.id])
		if int(rangs[a.id]) != int(rangs[b.id]):
			return int(rangs[a.id]) < int(rangs[b.id])
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return String(a.display_name) < String(b.display_name))
	return out


## L ETAT d une carte a gagner : {etat: Etat, rank: rang de l objectif (0 sinon)}.
##   OBTENUE  : deja dans le livre (SaveData.is_discovered) ;
##   A_GAGNER : dans le pool de montee de niveau, a prendre en combat ;
##   OBJECTIF : recompense d un objectif pas encore reussi, fermee pour l instant.
static func card_state(card: SpellCard, level: LevelDef, pool: Array) -> Dictionary:
	if SaveData.is_discovered(card.id):
		return {"etat": Etat.OBTENUE, "rank": 0}
	for c in pool:
		if c != null and (c as SpellCard).id == card.id:
			return {"etat": Etat.A_GAGNER, "rank": 0}
	if level != null:
		for i in level.objectives.size():
			var r: SpellCard = level.objective_reward(i)
			if r != null and r.id == card.id:
				return {"etat": Etat.OBJECTIF, "rank": LevelDef.objective_rank(i)}
	return {"etat": Etat.A_GAGNER, "rank": 0}


## LA FONCTION D AFFICHAGE : pose la section CARTES A GAGNER a partir d une
## LISTE calculee ailleurs (cards_to_win, ou toute regle future). Rien n y est
## decide sur le pool : elle montre, dans l ordre recu, l etat de chaque carte.
func show_cards_to_win(cartes: Array[SpellCard]) -> void:
	var col: VBoxContainer = _section(_waves, "CARTES A GAGNER")
	col.name = "CardsToWin"
	var pool: Array[SpellCard] = RunState.levelup_pool(_level, _mode)
	var montrables: Array[SpellCard] = []
	var obtenues_seules: bool = true
	for c in cartes:
		if c == null:
			continue
		montrables.append(c)
		if int(card_state(c, _level, pool)["etat"]) != Etat.OBTENUE:
			obtenues_seules = false
	if montrables.is_empty() or obtenues_seules:
		# Rien de neuf : on le dit, avec ce que la montee de niveau va puiser.
		col.add_child(UiTheme.label(
			"Rien de nouveau ici : la montee de niveau puise dans %d carte%s deja obtenue%s"
				% [pool.size(), "s" if pool.size() > 1 else "", "s" if pool.size() > 1 else ""],
			UiTheme.FONT_SMALL, UiTheme.INK_SOFT))
		return
	col.add_child(UiTheme.label("Proposees a la montee de niveau, ou gagnees par les objectifs",
		UiTheme.FONT_SMALL, UiTheme.INK_SOFT))
	var grille := GridContainer.new()
	grille.columns = CARDS_PER_ROW
	grille.add_theme_constant_override(&"h_separation", 14)
	grille.add_theme_constant_override(&"v_separation", 18)
	grille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grille)
	for i in mini(montrables.size(), MAX_CARD_TILES):
		var c: SpellCard = montrables[i]
		var st: Dictionary = card_state(c, _level, pool)
		grille.add_child(_card_tile(c, st))
	if montrables.size() > MAX_CARD_TILES:
		col.add_child(UiTheme.label(overflow_text(montrables.slice(MAX_CARD_TILES), _level, pool),
			UiTheme.FONT_SMALL, UiTheme.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))


## La ligne des cartes qui ne tiennent pas en vignettes : « et 2 sorts, 27 passifs
## de plus (27 a gagner) ». Sorts et passifs comptes a part : ce ne sont pas les
## memes cartes pour le joueur.
static func overflow_text(reste: Array, level: LevelDef, pool: Array) -> String:
	var sorts: int = 0
	var passifs: int = 0
	var a_gagner: int = 0
	for c in reste:
		var carte: SpellCard = c as SpellCard
		if carte == null:
			continue
		if carte.is_passive:
			passifs += 1
		else:
			sorts += 1
		if int(card_state(carte, level, pool)["etat"]) != Etat.OBTENUE:
			a_gagner += 1
	var parts: PackedStringArray = []
	if sorts > 0:
		parts.append("%d sort%s" % [sorts, "s" if sorts > 1 else ""])
	if passifs > 0:
		parts.append("%d passif%s" % [passifs, "s" if passifs > 1 else ""])
	return "et %s de plus (%d a gagner)" % [", ".join(parts), a_gagner]


## Une vignette : icone et sceau, nom, rarete, etat.
func _card_tile(c: SpellCard, st: Dictionary) -> Control:
	var tile := VBoxContainer.new()
	tile.name = "CardTile_%s" % c.id
	tile.set_meta(&"win_card", c.id)
	tile.set_meta(&"etat", int(st["etat"]))
	tile.custom_minimum_size = Vector2(CARD_TILE_W, 0)
	tile.add_theme_constant_override(&"separation", 0)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_art(tile, c, CARD_ART_PX)
	tile.add_child(UiTheme.label(c.display_name, UiTheme.FONT_SMALL, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER))
	var rarete: String = GameEnums.rarity_name(c.rarity)
	if c.is_passive:
		rarete = "passif " + rarete
	tile.add_child(UiTheme.label(rarete, UiTheme.FONT_SMALL, UiTheme.rarity_ink(c.rarity),
		HORIZONTAL_ALIGNMENT_CENTER))
	var etat: int = int(st["etat"])
	var mot: String = "a gagner"
	var encre: Color = UiTheme.INK_SUCCESS
	if etat == Etat.OBTENUE:
		mot = "obtenue"
		encre = UiTheme.INK_SOFT
	elif etat == Etat.OBJECTIF:
		mot = "objectif %d" % int(st["rank"])
		encre = UiTheme.INK_HINT
	var l: Label = UiTheme.label(mot, UiTheme.FONT_SMALL, encre, HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "State"
	tile.add_child(l)
	return tile


## L icone de la carte et son sceau, centres (CardView.with_type_badge).
func _add_art(parent: Control, c: SpellCard, px: float) -> void:
	var icone: TextureRect = CardIcons.make_rect(c, px)
	if icone == null:
		return
	var art: Control = CardView.with_type_badge(icone, c, px)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Le sceau deborde du coin haut-gauche : une marge au-dessus le garde visible.
	var marge := MarginContainer.new()
	marge.add_theme_constant_override(&"margin_top", 12)
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_child(art)
	parent.add_child(marge)


# --- OBJECTIFS -------------------------------------------------------------------

## Pourquoi : les trois objectifs du niveau et la carte que chacun debloque,
## DU PLUS FACILE AU PLUS DUR — leur position est leur rang (LevelDef.objective_rank,
## classes par taux mesure au banc). Le joueur doit les connaitre AVANT de
## jouer, sinon il ne peut pas les viser.
func _build_objectives() -> void:
	if _level == null or GameEnums.is_endless(_mode) or _level.objectives.is_empty():
		return
	var col: VBoxContainer = _section(_waves, "OBJECTIFS")
	col.name = "Objectives"
	col.add_child(UiTheme.label("du plus facile au plus dur", UiTheme.FONT_SMALL,
		UiTheme.INK_SOFT))
	for i in _level.objectives.size():
		var obj: ObjectiveDef = _level.objectives[i]
		if obj == null:
			continue
		var fait: bool = SaveData.is_objective_done(_level.id, obj.id)
		var bloc := VBoxContainer.new()
		bloc.name = "Objective_%d" % i
		bloc.set_meta(&"objective_id", obj.id)
		bloc.add_theme_constant_override(&"separation", 0)
		bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rang: int = LevelDef.objective_rank(i)
		var mot_rang: String = RANK_WORDS[clampi(rang - 1, 0, RANK_WORDS.size() - 1)]
		bloc.add_child(UiTheme.label("%d. %s  -  %s" % [rang, mot_rang, ObjectiveChecker.label(obj)],
			UiTheme.FONT_BODY, UiTheme.TEXT_DARK))
		# Le MOT dit l etat, la couleur le confirme : un joueur daltonien lit
		# quand meme « Acquis » ou « A faire ».
		var bb: String = "[color=#%s]%s[/color]" % [
			(UiTheme.INK_SUCCESS if fait else UiTheme.INK_SOFT).to_html(false),
			"Acquis" if fait else "A faire"]
		var carte: SpellCard = _level.objective_reward(i)
		if carte != null:
			bb += "  -  rapporte [color=#%s]%s[/color], %s" % [
				UiTheme.rarity_ink(carte.rarity).to_html(false), carte.display_name,
				GameEnums.rarity_name(carte.rarity)]
			if SaveData.is_discovered(carte.id):
				bb += " (obtenue)"
		bloc.add_child(ElementIcons.rich_label(bb, UiTheme.FONT_SMALL, UiTheme.INK_SOFT))
		col.add_child(bloc)


# --- TON DECK ----------------------------------------------------------------------

## Avec quoi : le deck en VIGNETTES, une par carte, et son nombre de copies.
## Aucune taille de police LITTERALE dans cet ecran : elles echappent au theme.
func _build_deck() -> void:
	var cartes: Array = _deck_list()
	if cartes.is_empty():
		return
	_deck.add_child(BattleReport.heading("TON DECK  (%d cartes)" % cartes.size()))
	var copies: Dictionary = {}
	var ordre: Array[SpellCard] = []
	for c in cartes:
		var carte: SpellCard = c as SpellCard
		if carte == null:
			continue
		if not copies.has(carte.id):
			copies[carte.id] = 0
			ordre.append(carte)
		copies[carte.id] = int(copies[carte.id]) + 1
	var grille := GridContainer.new()
	grille.name = "DeckGrid"
	grille.columns = DECK_PER_ROW
	grille.add_theme_constant_override(&"h_separation", 12)
	grille.add_theme_constant_override(&"v_separation", 14)
	grille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in ordre:
		var tile := VBoxContainer.new()
		tile.name = "DeckTile_%s" % c.id
		tile.set_meta(&"deck_card", c.id)
		tile.custom_minimum_size = Vector2(DECK_TILE_W, 0)
		tile.add_theme_constant_override(&"separation", 0)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_art(tile, c, DECK_ART_PX)
		tile.add_child(UiTheme.label(CardView.short_name(c), UiTheme.FONT_SMALL,
			UiTheme.rarity_ink(c.rarity), HORIZONTAL_ALIGNMENT_CENTER))
		var n: Label = UiTheme.label("x%d" % int(copies[c.id]), UiTheme.FONT_BODY,
			UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER)
		n.name = "Copies"
		tile.add_child(n)
		grille.add_child(tile)
	_deck.add_child(grille)


## Rend des SpellCard. Attention : SaveData.massacre_deck() stocke des IDENTIFIANTS
## texte, pas des cartes — les melanger faisait planter la boucle typee.
## C est le SEUL endroit qui dit quel deck le briefing montre. Vague 10 (A3) :
## la MEME fonction que la partie (GameController.run_deck), pour ne jamais
## annoncer un deck que la partie ne distribue pas (deck de campagne qui evolue
## avec les objectifs, deck du joueur en Libre et en Massacre).
func _deck_list() -> Array:
	if _level == null:
		return []
	return GameController.run_deck(_level, _mode)


func _on_start() -> void:
	if not _armed or _level == null:
		return
	SceneRouter.goto(SceneRouter.GAME, {"level_id": _level.id, "mode": _mode})


## Pour les tests : l ecran est-il pret a lancer la partie ?
func is_armed() -> bool:
	return _armed


func arm_now() -> void:
	_armed = true

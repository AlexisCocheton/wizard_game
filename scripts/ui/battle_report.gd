class_name BattleReport
extends RefCounted
## BILAN DE FIN DE NIVEAU (vague 10) : la vitesse perdue, monstre par monstre,
## et un conseil contre celui qui en a coute le plus.
##
## Demande du co-auteur du 14/10 : « a la fin des niveaux, affiche les DEGATS
## infliges par chaque monstre et donne un CONSEIL pour le monstre qui a fait le
## plus de degats ». La defaite comptait des COUPS (un contact de boss et une
## fleche de gnome valaient un chacun) et finissait sur un conseil generique ; la
## victoire n avait rien. Les deux ecrans posent maintenant ce meme bloc.
##
## LES DEGATS sont les points de vitesse REELLEMENT retires (RunState.
## damage_by_enemy_id, alimente par GameController._on_mage_hit) : la vitesse est
## la vie du mage, c est donc la seule mesure qui dise ce qui a fait mal. Un
## projectile-monstre (la boule du Planogo) est range sous son LANCEUR, comme
## RunState.hits_from_enemy le fait pour les coups : le joueur ne peut rien
## contre la boule, il peut tout contre celui qui la lance.
##
## Ce fichier decide de l ordre et dessine ; le CONSEIL vit dans ThreatLore.

## Au-dela, les especes restantes tiennent en une ligne : la page doit rester
## lisible au pouce, le conseil ne doit pas finir hors de l ecran.
const MAX_ROWS: int = 6
## Portrait d une ligne du bilan (px de page).
const PORTRAIT_PX: float = 96.0


## Le monstre qui LANCE un projectile-monstre, celui qui figure au bilan. Un
## monstre ordinaire se rend lui-meme. Plusieurs lanceurs possibles : celui du
## niveau d abord, puis le premier par id (un bilan ne depend pas du disque).
static func launcher_of(def: EnemyDef, level: LevelDef = null) -> EnemyDef:
	if def == null or not def.projectile:
		return def
	var candidats: Array[EnemyDef] = []
	if level != null:
		for d in ObjectiveChecker.level_enemies(level):
			if _lance(d, def):
				candidats.append(d)
	if candidats.is_empty():
		var ids: Array = ContentDB.enemies.keys()
		ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for id in ids:
			var d: EnemyDef = ContentDB.enemies[id]
			if _lance(d, def):
				candidats.append(d)
	return candidats[0] if not candidats.is_empty() else def


static func _lance(d: EnemyDef, projectile: EnemyDef) -> bool:
	return d != null and not d.projectile and d.summon_def != null \
		and d.summon_def.id == projectile.id


## LES LIGNES DU BILAN, de la plus couteuse a la moins couteuse :
##   [{def: EnemyDef, damage: int, hits: int}]
## `damage` et `hits` : {id d espece: nombre} (RunState.damage_by_enemy_id et
## hits_by_enemy_id). Seules les especes qui ont retire de la vitesse figurent ;
## si AUCUNE n en a retire (ancien appel sans montant), on retombe sur les coups,
## pour que l ecran nomme quand meme les coupables. A egalite de degats, le plus
## de coups, puis le nom.
static func rows(damage: Dictionary, hits: Dictionary, level: LevelDef = null) -> Array[Dictionary]:
	var par_coups: bool = true
	for id in damage:
		if int(damage[id]) > 0:
			par_coups = false
			break
	var cles: Array = hits.keys() if par_coups else damage.keys()
	var lignes: Dictionary = {}  # id du lanceur -> ligne
	for id in cles:
		var brut: EnemyDef = ContentDB.enemies.get(StringName(id))
		if brut == null:
			continue
		var def: EnemyDef = launcher_of(brut, level)
		var d: int = int(damage.get(id, 0))
		var h: int = int(hits.get(id, 0))
		if not par_coups and d <= 0:
			continue
		if not lignes.has(def.id):
			lignes[def.id] = {"def": def, "damage": 0, "hits": 0}
		lignes[def.id]["damage"] = int(lignes[def.id]["damage"]) + d
		lignes[def.id]["hits"] = int(lignes[def.id]["hits"]) + h
	var out: Array[Dictionary] = []
	for k in lignes:
		out.append(lignes[k])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["damage"]) != int(b["damage"]):
			return int(a["damage"]) > int(b["damage"])
		if int(a["hits"]) != int(b["hits"]):
			return int(a["hits"]) > int(b["hits"])
		return String((a["def"] as EnemyDef).display_name) \
			< String((b["def"] as EnemyDef).display_name))
	return out


## Les lignes de la partie qui vient de finir.
static func current_rows() -> Array[Dictionary]:
	return rows(RunState.damage_by_enemy_id, RunState.hits_by_enemy_id,
		RunState.current_level_def)


# --- LE DESSIN -----------------------------------------------------------------

## Pose le bilan dans `box` : titre, une ligne par monstre (portrait, nom,
## coups, barre, vitesse perdue), puis le conseil contre le premier. `victoire` :
## sans aucun coup recu, une ligne de felicitations au lieu d un bloc vide.
## Rend le monstre conseille (null s il n y en a pas), pour les tests.
static func build(box: VBoxContainer, victoire: bool) -> EnemyDef:
	var lignes: Array[Dictionary] = current_rows()
	# Un souffle avant le bloc : sur la victoire il suit les objectifs de pres.
	var souffle := Control.new()
	souffle.custom_minimum_size = Vector2(0, 10)
	souffle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(souffle)
	box.add_child(heading("VITESSE PERDUE, PAR MONSTRE"))
	if lignes.is_empty():
		box.add_child(UiTheme.label(
			"Aucun coup recu : ta vitesse est intacte" if victoire
				else "Aucun monstre ne t a touche",
			UiTheme.FONT_SMALL, UiTheme.INK_SUCCESS))
		return null
	var haut: int = maxi(1, int(lignes[0]["damage"]))
	var par_coups: bool = int(lignes[0]["damage"]) <= 0
	for i in mini(lignes.size(), MAX_ROWS):
		box.add_child(_row(lignes[i], haut, par_coups))
	if lignes.size() > MAX_ROWS:
		var reste: int = 0
		for i in range(MAX_ROWS, lignes.size()):
			reste += int(lignes[i]["damage"])
		box.add_child(UiTheme.label("et %d autre%s : -%d de vitesse" % [
			lignes.size() - MAX_ROWS, "s" if lignes.size() - MAX_ROWS > 1 else "", reste],
			UiTheme.FONT_SMALL, UiTheme.INK_SOFT))
	var cible: EnemyDef = lignes[0]["def"]
	add_advice(box, cible, ThreatLore.run_deck(),
		second_source(RunState.mode, RunState.current_level_def),
		second_source_text(RunState.mode))
	return cible


## LA SECONDE SOURCE DU CONSEIL, apres le deck de la partie (C7a, audit du
## 17/10). Le conseil proposait une carte « dans ton livre » meme en CAMPAGNE,
## ou le deck est IMPOSE (SaveData.campaign_deck) : le joueur ne pouvait pas la
## prendre. En campagne, la seconde source est donc ce que les objectifs NON
## reussis du niveau feraient entrer au deck (une recompense deja gagnee y est
## deja, elle vient avec le deck) ; en LIBRE et au Massacre, ou le joueur compose
## son deck, c est le LIVRE.
static func second_source(mode: int, level: LevelDef) -> Array:
	if not GameEnums.advances_campaign(mode):
		return ThreatLore.book_cards()
	var out: Array = []
	if level == null:
		return out
	for i in level.objectives.size():
		var obj: ObjectiveDef = level.objectives[i]
		var carte: SpellCard = level.objective_reward(i)
		if obj == null or carte == null or carte.is_passive or out.has(carte):
			continue
		if SaveData.is_objective_done(level.id, obj.id):
			continue
		out.append(carte)
	return out


## Comment se dit la seconde source : « a debloquer par un objectif » en
## campagne, « dans ton livre » ailleurs.
static func second_source_text(mode: int) -> String:
	return ThreatLore.OBJECTIVE_SOURCE_TEXT if GameEnums.advances_campaign(mode) \
		else ThreatLore.BOOK_SOURCE_TEXT


## Titre de section, le meme sur le briefing et le bilan.
static func heading(texte: String) -> Label:
	var l: Label = UiTheme.label(texte, UiTheme.FONT_BODY, UiTheme.INK_HEADING)
	l.name = "Heading"
	return l


## Une ligne : [portrait] Nom / N coups / barre  ...  -42
static func _row(ligne: Dictionary, haut: int, par_coups: bool) -> Control:
	var def: EnemyDef = ligne["def"]
	var d: int = int(ligne["damage"])
	var h: int = int(ligne["hits"])
	var row := HBoxContainer.new()
	row.name = "DamageRow_%s" % def.id
	row.set_meta(&"enemy_id", def.id)
	row.set_meta(&"damage", d)
	row.add_theme_constant_override(&"separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Un porteur Control, jamais un TextureRect pose a nu dans la rangee : le
	# smoke compte les etoiles de la victoire comme des TextureRect d un HBox.
	row.add_child(BestiaryLore.portrait_of(def, PORTRAIT_PX, true))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UiTheme.label(def.display_name, UiTheme.FONT_BODY, UiTheme.TEXT_DARK))
	col.add_child(UiTheme.label("%d coup%s" % [h, "s" if h > 1 else ""],
		UiTheme.FONT_SMALL, UiTheme.INK_SOFT))
	# La barre n existe que s il y a des degats a mesurer : creee pour rien, elle
	# restait orpheline et ses textures fuyaient a la sortie (vu a l etage visual).
	if not par_coups:
		var barre := ProgressBar.new()
		barre.show_percentage = false
		barre.custom_minimum_size = Vector2(0, 20)
		barre.max_value = float(haut)
		barre.value = float(d)
		# Le ROUGE du pack : la vitesse perdue est de la vie perdue (DEC du 26/09).
		# L or des barres d avancement dirait « progres », l inverse du propos.
		barre.add_theme_stylebox_override(&"background", UiTheme.tex_box("bar_base", 0, 0.0))
		barre.add_theme_stylebox_override(&"fill", UiTheme.tex_box("bar_fill", 0, 0.0))
		barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(barre)
	var chiffre := UiTheme.label("-%d" % d if not par_coups else "", UiTheme.FONT_TITLE,
		UiTheme.INK_DANGER, HORIZONTAL_ALIGNMENT_RIGHT, false)
	chiffre.name = "Damage"
	chiffre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chiffre.custom_minimum_size = Vector2(150, 0)
	row.add_child(chiffre)
	return row


## Le CONSEIL contre `def` : titre, puis une ligne par regle de ThreatLore. La
## ligne d element porte le LOGO de l element ; la carte conseillee est ecrite a
## l encre de sa rarete. Statique : le briefing pourrait la reprendre.
## `book` / `book_text` : la seconde source et sa facon de la dire
## (second_source, second_source_text).
static func add_advice(box: VBoxContainer, def: EnemyDef, deck: Array, book: Array,
		book_text: String = ThreatLore.BOOK_SOURCE_TEXT) -> void:
	var titre: Label = heading("CONSEIL CONTRE %s" % def.display_name.to_upper())
	titre.name = "AdviceHeading"
	box.add_child(titre)
	var px: int = ElementIcons.inline_px(UiTheme.FONT_SMALL)
	for ligne in ThreatLore.advice(def, deck, book, book_text):
		var bb: String = ""
		var tag: int = int(ligne["tag"])
		if tag >= 0:
			bb += ElementIcons.inline(tag, px) + " "
		bb += String(ligne["phrase"])
		var carte: SpellCard = ligne["card"]
		if carte != null:
			bb += " : [color=#%s]%s[/color] (%s)" % [
				UiTheme.rarity_ink(carte.rarity).to_html(false), carte.display_name,
				String(ligne["source"])]
		var r: RichTextLabel = ElementIcons.rich_label(bb, UiTheme.FONT_SMALL, UiTheme.INK_HINT)
		r.name = "Advice_%s" % String(ligne["kind"])
		r.set_meta(&"advice", ligne)
		box.add_child(r)

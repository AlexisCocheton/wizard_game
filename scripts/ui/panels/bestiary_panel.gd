class_name BestiaryPanel
extends Control
## Onglet Bestiaire — les monstres DEJA RENCONTRES, avec leurs competences.
##
## Racine en Control (pas en conteneur), meme raison que la Galerie : la fiche
## detaillee doit se SUPERPOSER a la grille ; un VBoxContainer la placerait
## dessous et il faudrait faire defiler pour la lire.
##
## Un monstre jamais croise reste en silhouette "???" : le bestiaire est une
## recompense d exploration, pas une fiche technique offerte d emblee.

## Hauteur de tuile : le portrait + DEUX lignes de texte (nom, chiffres) +
## les marges du bouton. Calibree en lisant les captures : a 250 px le nom
## sortait de la tuile qui rogne, et le monstre s affichait anonyme.
const TILE_H: float = 300.0   ## cible tactile : 3 colonnes de ~336x300, bien au-dela des 90 px
const SPRITE_PX: float = 120.0
const SPRITE_PX_BIG: float = 240.0

var _grid: GridContainer
var _counter: Label
var _detail: PanelContainer


func _ready() -> void:
	_build()
	refresh()


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override(&"separation", 16)
	add_child(vbox)

	_counter = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_counter)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	scroll.add_child(_grid)

	_detail = PanelContainer.new()
	_detail.visible = false
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_detail)


## Les monstres du bestiaire, tries du plus faible au plus fort : le joueur lit
## la hierarchie de puissance dans l ordre de la grille.
static func listed_enemies() -> Array:
	var out: Array = []
	for e: EnemyDef in ContentDB.enemies.values():
		out.append(e)
	out.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool:
		if a.power != b.power:
			return a.power < b.power
		return a.display_name < b.display_name)
	return out


func refresh() -> void:
	_detail.visible = false
	for c in _grid.get_children():
		c.queue_free()
	var defs: Array = listed_enemies()
	var seen: int = 0
	for def: EnemyDef in defs:
		var known: bool = SaveData.is_enemy_discovered(def.id)
		if known:
			seen += 1
		_grid.add_child(_tile(def, known))
	_counter.text = "Monstres rencontres : %d / %d" % [seen, defs.size()]


func _tile(def: EnemyDef, known: bool) -> Control:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(0, TILE_H)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.clip_contents = true

	# Le sprite se pose PAR-DESSUS le bouton, en ignorant la souris : sinon il
	# avalerait le toucher et la tuile ne reagirait plus.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 4)
	tile.add_child(box)

	var art: Control = _portrait(def, SPRITE_PX, known)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)

	if known:
		# Le nom en TEXT clair et non en couleur de puissance : la tuile est le
		# bouton bleu du pack, les teintes vives (teal, or) s y noyaient — la
		# couleur de puissance ne sert que sur la ligne chiffree et la fiche.
		# Nom sur UNE ligne, tronque par des points de suspension. En autowrap
		# (le defaut de UiTheme.label) un nom long prenait deux lignes et
		# poussait la ligne chiffree hors de la tuile, qui rogne.
		var nom := UiTheme.label(def.display_name, UiTheme.FONT_SMALL,
			UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		nom.autowrap_mode = TextServer.AUTOWRAP_OFF
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(nom)
		box.add_child(UiTheme.label("P%d   %d PV" % [def.power, int(def.max_hp)],
			UiTheme.FONT_SMALL, _power_color(def.power), HORIZONTAL_ALIGNMENT_CENTER))
		tile.pressed.connect(_show_detail.bind(def))
	else:
		box.add_child(UiTheme.label("???", UiTheme.FONT_BODY, UiTheme.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UiTheme.label("jamais croise", UiTheme.FONT_SMALL,
			UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		tile.disabled = true
	return tile


## Portrait du monstre : premiere image de sa feuille de MARCHE, son etat
## permanent (DEC assets : l attaque et la mort sont des poses etirees).
## Non rencontre = meme image noircie : la silhouette, pas un carre vide.
##
## La case est AGRANDIE de 1/occupancy : les feuilles des packs sont loin d etre
## pleines (le Blood Monster n occupe que 31 % de sa case). Sans cette
## correction, mise a l echelle de la case entiere, les gros monstres
## s affichaient minuscules — le piege deja mesure dans [[assets]].
func _portrait(def: EnemyDef, px: float, known: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = _portrait_texture(def)

	# On centre une zone de dessin plus grande que le cadre : la partie occupee
	# de la case remplit alors la vignette, le vide deborde et est rogne.
	var occ: float = 0.55
	if def != null and AnimCatalog.has(def.anim_key):
		occ = clampf(AnimCatalog.occupancy(def.anim_key), 0.20, 1.0)
	var draw: float = px / occ
	tr.size = Vector2(draw, draw)
	tr.position = Vector2((px - draw) * 0.5, (px - draw) * 0.5)

	if known:
		tr.modulate = AnimCatalog.modulate_for(def.id)
	else:
		# Silhouette : la forme reste lisible, les details disparaissent.
		tr.modulate = Color(0.0, 0.0, 0.0, 0.55)
	holder.add_child(tr)
	return holder


## Une AtlasTexture sur la premiere case de la feuille de marche. On ne passe pas
## par AnimatedSprite2D : une grille de 21 lecteurs animes pour une consultation
## couterait plus que l ecran ne rapporte.
func _portrait_texture(def: EnemyDef) -> Texture2D:
	if def == null or String(def.anim_key) == "":
		return def.sprite if def != null else null
	var key: StringName = def.anim_key
	if not AnimCatalog.has(key):
		return def.sprite
	if AnimCatalog.is_static(key):
		return AnimCatalog.static_texture(key)
	var frames: SpriteFrames = AnimCatalog.frames(key)
	if frames == null:
		return def.sprite
	var anim: String = "walk" if frames.has_animation(&"walk") else ""
	if anim == "":
		var names: PackedStringArray = frames.get_animation_names()
		if names.is_empty():
			return def.sprite
		anim = names[0]
	if frames.get_frame_count(StringName(anim)) <= 0:
		return def.sprite
	return frames.get_frame_texture(StringName(anim), 0)


## Couleur de la puissance : meme hierarchie P1..P4 que le catalogue.
## Teintes calibrees sur la tuile CLAIRE (bouton actif du pack) : le teal et le
## violet d origine y etaient delaves, verifie sur capture.
static func power_color(power: int) -> Color:
	if power >= 8:
		return Color(0.80, 0.15, 0.18)
	if power >= 5:
		return Color(0.55, 0.25, 0.85)
	if power >= 3:
		return Color(0.85, 0.62, 0.10)
	return Color(0.10, 0.35, 0.40)


func _power_color(power: int) -> Color:
	return power_color(power)


## Version lisible sur PAPIER (fond clair) : les teintes vives ci-dessus y
## deviennent illisibles, comme le blanc. Meme logique que UiTheme.rarity_ink().
static func power_ink(power: int) -> Color:
	if power >= 8:
		return Color(0.62, 0.12, 0.14)
	if power >= 5:
		return Color(0.48, 0.22, 0.72)
	if power >= 3:
		return Color(0.62, 0.45, 0.05)
	return Color(0.10, 0.42, 0.40)


## Famille du monstre en un mot, pour la ligne de sous-titre.
static func kind_name(kind: int) -> String:
	match kind:
		GameEnums.EnemyKind.NORMAL: return "Monstre commun"
		GameEnums.EnemyKind.FAST: return "Rapide"
		GameEnums.EnemyKind.TANK: return "Colosse"
		GameEnums.EnemyKind.EVASIVE: return "Insaisissable"
		GameEnums.EnemyKind.SWARM: return "Nuee"
		GameEnums.EnemyKind.BUFFER: return "Meneur"
		GameEnums.EnemyKind.PHASER: return "Spectre"
		GameEnums.EnemyKind.MINIBOSS: return "Mini-boss"
		GameEnums.EnemyKind.BOSS: return "BOSS"
		GameEnums.EnemyKind.DEVOURER: return "Devoreur"
		GameEnums.EnemyKind.ENRAGER: return "Enrage"
		GameEnums.EnemyKind.GUARDIAN: return "Gardien"
		GameEnums.EnemyKind.BURSTER: return "Sprinteur"
		GameEnums.EnemyKind.WAVER: return "Ondulant"
		GameEnums.EnemyKind.SPLITTER: return "Diviseur"
		GameEnums.EnemyKind.SHIELDED: return "Protege"
		GameEnums.EnemyKind.HEALER: return "Soigneur"
		GameEnums.EnemyKind.BOMBER: return "Bombe vivante"
		GameEnums.EnemyKind.SHOOTER: return "Tireur"
	return "Monstre"


static func _tag_name(tag: int) -> String:
	match tag:
		GameEnums.DamageTag.PHYSICAL: return "aux degats physiques"
		GameEnums.DamageTag.FIRE: return "au feu"
		GameEnums.DamageTag.FROST: return "au givre"
		GameEnums.DamageTag.ARCANE: return "aux arcanes"
		GameEnums.DamageTag.SLOW: return "au ralentissement"
		GameEnums.DamageTag.SUMMON: return "aux invocations"
	return "a certains sorts"


## LE COEUR DE L ECRAN : traduire les champs d EnemyDef en phrases.
##
## On lit les CHAMPS et non le `kind` : un monstre peut cumuler des
## comportements (le Behemoth est un TANK qui encaisse aussi le premier coup),
## et le `kind` n en nomme qu un seul. Se fier au kind mentirait au joueur sur
## ce qui va reellement lui arriver.
static func behaviours(def: EnemyDef) -> Array[String]:
	var out: Array[String] = []
	if def == null:
		return out

	if def.split_into != null and def.split_count > 0:
		var child_name: String = def.split_into.display_name
		if def.split_count == 2:
			out.append("Se divise en deux a sa mort (%s)" % child_name)
		else:
			out.append("Engendre %d %s a sa mort" % [def.split_count, child_name])
	if def.first_hit_shield:
		out.append("Encaisse le premier coup sans aucun degat")
	if def.aura_shield_radius > 0.0:
		# Pas de pixels dans une fiche de joueur : "240 px" ne veut rien dire
		# manette en main. On qualifie la portee par rapport a la largeur de
		# l ecran, la seule echelle que le joueur percoit.
		var part: float = def.aura_shield_radius / float(GameConfig.BATTLEFIELD_WIDTH)
		var portee: String = "large" if part >= 0.25 else ("moyenne" if part >= 0.12 else "courte")
		out.append("Protege de tout degat les monstres autour de lui (aura %s)" % portee)
	if def.heal_per_second > 0.0:
		out.append("Soigne tous les autres monstres (%s PV par seconde)"
			% _num(def.heal_per_second))
	if def.shoot_interval > 0.0:
		out.append("Tire a distance sur le mage toutes les %s s (%d degats)"
			% [_num(def.shoot_interval), def.shot_damage])
	if def.devours:
		out.append("Gobe les monstres plus faibles et grossit")
	if def.enrage_speed_pct > 0.0:
		out.append("Accelere de %d %% a chaque coup recu" % int(round(def.enrage_speed_pct)))
	if def.dodge_chance > 0.0:
		out.append("Esquive %d %% des sorts" % int(round(def.dodge_chance * 100.0)))
	if def.phase_interval > 0.0:
		out.append("Disparait puis reapparait toutes les %s s" % _num(def.phase_interval))
	if def.burst_move:
		out.append("Avance par a-coups : fonce puis marque une pause")
	if def.wave_amplitude > 0.0:
		out.append("Ondule lateralement : difficile a viser")
	if def.buff_speed_pct > 0.0:
		out.append("Accelere les autres monstres de %d %%" % int(round(def.buff_speed_pct)))
	if def.swarm_count > 1:
		out.append("Arrive en groupe de %d" % def.swarm_count)
	if def.entry_side:
		out.append("Entre par le cote de l ecran, pas par le haut")
	for tag in def.immune_tags:
		out.append("Immunise %s" % _tag_name(tag))

	# Toujours une ligne, meme pour un monstre sans particularite : un encadre
	# vide laisserait croire que la fiche est cassee.
	if out.is_empty():
		out.append("Descend tout droit vers le mage, sans ruse")
	return out


static func _num(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


## La vitesse en MOT et non en px/s : le joueur ne compte pas des pixels, il
## compare des monstres entre eux. Les seuils sont relatifs a la vitesse de
## reference du contenu, donc un reglage d equilibrage ne les perime pas.
static func speed_word(base_speed: float) -> String:
	if base_speed >= 100.0:
		return "tres vive"
	if base_speed >= 75.0:
		return "vive"
	if base_speed >= 55.0:
		return "normale"
	if base_speed >= 35.0:
		return "lente"
	return "tres lente"


func _show_detail(def: EnemyDef) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 14)
	scroll.add_child(box)

	var art: Control = _portrait(def, SPRITE_PX_BIG, true)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)

	# Encre SOMBRE partout : le panneau est un papier clair du pack, le blanc y
	# est illisible (bug deja signale par le testeur).
	box.add_child(UiTheme.label(def.display_name, UiTheme.FONT_TITLE,
		power_ink(def.power), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("%s   -   puissance %d" % [kind_name(def.kind), def.power],
		UiTheme.FONT_BODY, Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override(&"separation", 28)
	box.add_child(stats)
	stats.add_child(_stat("PV", str(int(def.max_hp)), Color(0.62, 0.12, 0.14)))
	stats.add_child(_stat("Vitesse", speed_word(def.base_speed), Color(0.15, 0.38, 0.75)))
	stats.add_child(_stat("Degats", "%d" % def.contact_hit(), Color(0.45, 0.30, 0.10)))
	stats.add_child(_stat("XP", str(def.base_xp), Color(0.62, 0.45, 0.05)))

	box.add_child(UiTheme.label("COMPETENCES", UiTheme.FONT_BODY,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	for line in behaviours(def):
		box.add_child(UiTheme.label("- " + line, UiTheme.FONT_BODY, UiTheme.TEXT_DARK))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)
	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(0, 110)   # cible tactile confortable
	close.pressed.connect(func() -> void: _detail.visible = false)
	box.add_child(close)
	_detail.visible = true


func _stat(title: String, value: String, ink: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	var t := UiTheme.label(title, UiTheme.FONT_SMALL, Color(0.45, 0.35, 0.25),
		HORIZONTAL_ALIGNMENT_CENTER)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var l := UiTheme.label(value, UiTheme.FONT_BUTTON, ink, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(l)
	return v

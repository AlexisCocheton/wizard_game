class_name BestiaryLore
extends RefCounted
## Le SAVOIR sur les monstres : traduire un EnemyDef en phrases et en couleurs
## lisibles par le joueur, et en tirer un portrait.
##
## C etait un PANNEAU d onglet (BestiaryPanel). Le bestiaire a fusionne avec la
## galerie dans le grimoire a pages (`gallery_panel.gd`, section BESTIAIRE) :
## un seul ecran de consultation au lieu de deux onglets voisins qui faisaient
## la meme chose. Ce qui restait ici — la traduction des champs en competences,
## les couleurs de puissance, le portrait — n avait aucune raison de disparaitre
## avec l ecran : c est de la CONNAISSANCE du domaine, pas de l affichage.
##
## En RefCounted et non en Control : plus rien ici ne se place a l ecran, et un
## Control inutilise dans l arbre est un piege a `queue_free` oublie.

## Portrait du monstre : premiere image de sa feuille de MARCHE, son etat
## permanent (DEC assets : l attaque et la mort sont des poses etirees).
## Non rencontre = meme image noircie : la silhouette, pas un carre vide.
##
## La case est AGRANDIE de 1/occupancy : les feuilles des packs sont loin d etre
## pleines (le Blood Monster n occupe que 31 % de sa case). Sans cette
## correction, mise a l echelle de la case entiere, les gros monstres
## s affichaient minuscules — le piege deja mesure dans [[assets]].
static func portrait_of(def: EnemyDef, px: float, known: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = portrait_texture(def)

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
static func portrait_texture(def: EnemyDef) -> Texture2D:
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

extends Node
## INVENTAIRE DU CONTENU — monstres, sorts, niveaux, en tableaux triables.
##
## CE QU IL FAIT
## -------------
## Il lit tout ContentDB et ecrit six fichiers CSV dans `.testout/data/`, plus un
## resume et une liste d ANOMALIES sur la console. Les CSV s ouvrent dans un
## tableur : c est la seule sortie ou l on peut trier par PV, filtrer sur un
## element et comparer deux monstres cote a cote sans les lire un par un.
##
## CE QU IL NE FAIT PAS
## --------------------
## - Il n ECRIT AUCUNE donnee de jeu. Il ouvre les .tres en lecture, point.
## - Il ne JOUE pas. Un taux de victoire se mesure au banc (tools/sim_balance.gd) ;
##   ici on inventorie ce qui EST ecrit, pas ce que ca donne en partie. Les deux
##   sont complementaires : le banc dit "le niveau 6 est dur", l inventaire dit
##   "parce que sa vague 5 pese 34 points de puissance contre 19 a la 4".
## - Il n est PAS dans le harnais. C est un outil de jugement, comme
##   tools/ui_preview.gd. Les regles dures (3 objectifs par niveau, une cle
##   d effet connue) restent verrouillees par l etage `audit`. Les ANOMALIES
##   signalees ici sont des ODEURS, pas des fautes : un monstre sans resistance
##   est peut-etre voulu.
##
## COMMENT LE LANCER
## -----------------
##   Godot --headless --path . tools/data_sheet.tscn
##
## JAMAIS avec --script : sur 4.4.stable les autoloads ne sont alors pas
## enregistres, ContentDB est vide, et l inventaire sort a zero ligne sans
## prevenir. Piege connu, meme raison que pour les etages du harnais.
##
## LES COLONNES CALCULEES
## ----------------------
## Un inventaire des seuls champs bruts raterait justement ce qui interesse :
## plusieurs chiffres du jeu ne sont ECRITS nulle part.
##
##   `degats_contact` : vaut 0 dans presque tous les .tres. Le vrai chiffre sort
##       du bareme GameConfig.CONTACT_DAMAGE_BY_POWER, ou du bareme boss. La
##       colonne donne la valeur JOUEE, et `contact_source` dit d ou elle vient.
##   `vitesse_reelle` : base_speed x ENEMY_SPEED_SCALE. Le reglage global vaut
##       0.52, donc un monstre ecrit a 60 descend a 31 px/s en partie. Afficher
##       base_speed seul se tromperait du double.
##   `pv_x1 / vitesse_x1` des vagues : PV et vitesse APRES l echelle
##       `difficulty` de la vague, qui multiplie les PV a l apparition.
##   `puissance` d une vague : somme des puissances, NUEES comptees en corps
##       (une entree de 3 rat_swarm a swarm_count 4 pese 12 corps), boss exclu du
##       budget comme le fait WaveBudget.
##   `res_*` : le multiplicateur par element, avec 1.00 la ou rien n est declare,
##       et le repli sur l ancien champ `immune_tags` deja applique. Lire la
##       table brute du .tres afficherait des trous.
##   `degats_total` d un sort : PAS la somme des magnitudes. Selon le handler,
##       `magnitude` est un total, un debit par seconde, ou un pourcentage qui
##       n est pas un degat du tout — voir MAGNITUDE_SENS plus bas, qui explique
##       pourquoi le Meteore affichait 200 au lieu de 60. Quand un effet de la
##       carte n exprime pas des degats, `degats_partiels` vaut oui : le total ne
##       raconte alors qu une partie du sort.
##   `degats_par_seconde` d un sort : degats reels / temps d incantation. C est LE
##       chiffre de comparaison entre deux cartes ; les degats bruts trient a
##       l envers (60 degats sur 2,8 s rendent moins que 26 sur 1,4 s).
##   `acces` d un sort : par quel chemin il arrive en main (deck de depart, deck
##       de niveau, tirage de montee de niveau). Aucun champ ne le dit.
##   `saut_max` d un niveau : le plus gros rapport de puissance entre deux vagues
##       consecutives. La regle maison le veut sous x2.
##   `pv_par_seconde` d une vague : la PRESSION reelle. Les memes PV etales sur
##       40 s ou concentres sur 20 s ne se jouent pas pareil.
##
## PAR FAMILLE, LES FICHIERS
## -------------------------
##   monstres.csv   une ligne par type, stats + 6 resistances + comportements
##                  + les niveaux et vagues ou il apparait
##   sorts.csv      une ligne par carte, rarete/incantation/degats/elements
##                  + les decks de niveau qui la fournissent
##   niveaux.csv    une ligne par niveau, vagues/puissance/PV/boss/deck/objectifs
##   vagues.csv     une ligne par vague DE NIVEAU (la granularite ou se lit la
##                  courbe de difficulte ; un niveau resume la cache)
##   effets.csv     une ligne par brique d effet portee par une carte
##   massacre.csv   les 18 premieres vagues du mode infini, budget calcule
##
## Les separateurs sont des POINTS-VIRGULES et les decimaux des VIRGULES : c est
## ce qu attend un Excel en locale francaise, et sans ca toutes les colonnes
## atterrissent dans la premiere cellule.

const OUT_DIR := "res://.testout/data"
## Les 18 premieres vagues du Massacre : trois tours complets de la cadence
## boss (WaveBudget.BOSS_EVERY = 6), assez pour voir la courbe et les creux de
## palier sans noyer le fichier.
const MASSACRE_WAVES: int = 18

## Tous les elements, dans l ordre de l enum, pour des colonnes stables.
var _elements: Array[int] = GameEnums.ELEMENTS

## CE QUE `magnitude` VEUT DIRE, HANDLER PAR HANDLER.
##
## C est le piege central de cet outil, et il a failli produire un inventaire
## faux. `EffectSpec.magnitude` est documente comme "intensite principale, sens
## defini par le handler" — et les handlers en font trois choses differentes :
##
##   "total" : des degats, une fois. damage_single, pierce_line, knockback...
##   "dps"   : des degats PAR SECONDE sur la duree de la zone. C est le cas de
##             `ground_zone`, ou le parametre de battlefield.spawn_ground_zone()
##             s appelle litteralement `dps`. Le Meteore porte magnitude 200 sur
##             0,3 s de zone, soit 60 degats reels — exactement ce qu annonce sa
##             description. Sommer les magnitudes brutes le faisait passer pour
##             la carte la plus violente du jeu, devant la Pluie de meteorites.
##   "autre" : ce n est pas un degat du tout. slow_enemy_gauge y met un
##             POURCENTAGE de ralentissement (40 = 40 %), self_haste un gain
##             d incantation, draw_cards un nombre de cartes. Les additionner a
##             des degats ne produit aucune grandeur.
##
## Un handler absent de cette table est traite en "autre" : mieux vaut une
## colonne vide qu un chiffre invente.
const MAGNITUDE_SENS: Dictionary = {
	&"damage_single": "total",
	&"pierce_line": "total",
	&"knockback": "total",
	&"stun_zone": "total",
	&"damage_per_enemy": "total_par_monstre",
	&"meteor_storm": "total_par_impact",
	&"summon_ally": "degats_allie",
	&"taunt_prop": "total",
	&"ground_zone": "dps",
}

var _anomalies: Array[String] = []
## Cartes de zone dont le texte annonce le DEBIT et non le total encaisse. Ce
## n est pas une faute par carte mais UNE convention a trancher : voir
## `_verifie_description()`. Listees a part pour ne pas noyer les vraies alertes.
var _zones_ambigues: Array[String] = []
## id de monstre -> Array[String] de "niveau/vague"
var _enemy_sites: Dictionary = {}
## id de carte -> Array[String] de niveaux qui la fournissent
var _card_decks: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	if ContentDB.cards.is_empty() and ContentDB.enemies.is_empty():
		printerr("[INVENTAIRE] ContentDB est VIDE. Lance la SCENE, pas --script.")
		get_tree().quit(1)
		return

	_index_cross_references()

	var dir: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)

	print("=== INVENTAIRE DU CONTENU — Wizard Story ===")
	print("Sortie : %s" % dir)
	print("")

	_write(dir, "monstres.csv", _table_enemies())
	_write(dir, "sorts.csv", _table_cards())
	_write(dir, "niveaux.csv", _table_levels())
	_write(dir, "vagues.csv", _table_waves())
	_write(dir, "effets.csv", _table_effects())
	_write(dir, "massacre.csv", _table_massacre())

	print("")
	_print_digest()
	print("")
	_print_anomalies()
	print("")
	_print_zones_ambigues()
	print("")
	print("=== FIN ===")
	get_tree().quit(0)


# --------------------------------------------------------------------------
# CROISEMENTS : ou un monstre apparait, quel deck fournit une carte.
# C est la moitie de la valeur de l outil. Un .tres de monstre ne sait pas dans
# quels niveaux il descend — l information n existe que dans l autre sens.
# --------------------------------------------------------------------------
func _index_cross_references() -> void:
	for level: LevelDef in _levels_sorted():
		for i in level.waves.size():
			var w: WaveDef = level.waves[i]
			if w == null:
				continue
			for e: WaveEntry in w.entries:
				if e == null or e.enemy == null:
					continue
				var key: StringName = e.enemy.id
				if not _enemy_sites.has(key):
					_enemy_sites[key] = []
				var site: String = "%s/v%d" % [level.id, i + 1]
				if not (site in _enemy_sites[key]):
					_enemy_sites[key].append(site)
			# Un boss engendre des sbires : ils apparaissent dans la vague sans y
			# etre ecrits. Sans cette passe, summon_def et split_into passent pour
			# des monstres qu aucun niveau n utilise.
			for e2: WaveEntry in w.entries:
				if e2 == null or e2.enemy == null:
					continue
				_index_spawned(e2.enemy, "%s/v%d" % [level.id, i + 1], 0)
		# Le pool procedural n est pas une vague ecrite, mais un monstre qui y
		# figure PEUT descendre dans le niveau. On le note a part.
		for def: EnemyDef in level.enemy_pool:
			if def == null:
				continue
			if not _enemy_sites.has(def.id):
				_enemy_sites[def.id] = []
			var p: String = "%s/pool" % level.id
			if not (p in _enemy_sites[def.id]):
				_enemy_sites[def.id].append(p)
		for c: SpellCard in level.exploration_deck:
			if c == null:
				continue
			if not _card_decks.has(c.id):
				_card_decks[c.id] = []
			if not (String(level.id) in _card_decks[c.id]):
				_card_decks[c.id].append(String(level.id))
		if level.legendary_reward != null:
			var lid: StringName = level.legendary_reward.id
			if not _card_decks.has(lid):
				_card_decks[lid] = []
			var tag: String = "%s(recompense)" % level.id
			if not (tag in _card_decks[lid]):
				_card_decks[lid].append(tag)


## Monstres engendres par un autre (invocation, division), en profondeur bornee.
## La borne evite la boucle infinie d une gelee qui se divise en elle-meme.
func _index_spawned(def: EnemyDef, site: String, depth: int) -> void:
	if depth > 4:
		return
	for enfant in [def.summon_def, def.split_into]:
		if enfant == null:
			continue
		if not _enemy_sites.has(enfant.id):
			_enemy_sites[enfant.id] = []
		var s: String = "%s(engendre)" % site
		if not (s in _enemy_sites[enfant.id]):
			_enemy_sites[enfant.id].append(s)
		_index_spawned(enfant, site, depth + 1)


# --------------------------------------------------------------------------
# MONSTRES
# --------------------------------------------------------------------------
func _table_enemies() -> Array:
	var rows: Array = []
	var head: Array = ["id", "nom", "famille", "puissance", "pv", "vitesse_ecrite",
		"vitesse_reelle", "xp", "degats_contact", "contact_source", "rayon"]
	for t in _elements:
		head.append("res_%s" % GameEnums.tag_name(t))
	head.append("res_ralentissement")
	head.append_array(["comportements", "niveaux", "nb_sites"])
	rows.append(head)

	for def: EnemyDef in _enemies_sorted():
		var row: Array = [
			String(def.id), def.display_name, _kind_name(def.kind), def.power,
			def.max_hp, def.base_speed,
			def.base_speed * GameConfig.ENEMY_SPEED_SCALE,
			def.base_xp, def.contact_hit(), _contact_source(def), def.base_radius,
		]
		for t in _elements:
			row.append(def.resistance_to(t))
		row.append(def.resistance_to(GameEnums.DamageTag.SLOW))
		var sites: Array = _enemy_sites.get(def.id, [])
		row.append_array([_behaviours(def), " ".join(sites), sites.size()])
		rows.append(row)

		# --- ANOMALIES par monstre ---
		if def.projectile:
			continue  # un projectile n est pas une creature : il echappe aux regles
		if sites.is_empty():
			_anomalies.append("MONSTRE ORPHELIN : %s (%s) n apparait dans AUCUN niveau, aucun pool, et n est engendre par personne"
				% [def.id, def.display_name])
		if def.resistances.is_empty() and def.immune_tags.is_empty():
			_anomalies.append("SANS RESISTANCE : %s — tous les elements l entament pareil, changer de deck contre lui ne sert a rien"
				% def.id)
		if def.kind != GameEnums.EnemyKind.BOSS and def.kind != GameEnums.EnemyKind.MINIBOSS \
				and not GameConfig.CONTACT_DAMAGE_BY_POWER.has(def.power) and def.contact_damage <= 0:
			_anomalies.append("CONTACT HORS BAREME : %s a puissance %d, absente de CONTACT_DAMAGE_BY_POWER, et pas de contact_damage explicite -> retombe sur 5 par defaut"
				% [def.id, def.power])
		# Regle ecrite en commentaire dans enemy_def.gd : la garde doit retomber.
		if def.reflect_interval > 0.0 and def.reflect_window >= def.reflect_interval:
			_anomalies.append("RENVOI PERMANENT : %s — fenetre %.1fs >= intervalle %.1fs, la garde ne retombe jamais"
				% [def.id, def.reflect_window, def.reflect_interval])
		# Regle ecrite dans enemy_def.gd : un boss a onde doit rester en place.
		if def.shockwave_interval > 0.0 and def.base_speed > 0.0 and def.keeps_distance_at <= 0.0:
			_anomalies.append("ZONE INTERDITE MOBILE : %s a une onde de choc ET avance (%.0f px/s) sans distance de garde — aucun endroit sur"
				% [def.id, def.base_speed])
		if def.split_count > 0 and def.split_into == null:
			_anomalies.append("DIVISION VIDE : %s a split_count %d mais aucun split_into"
				% [def.id, def.split_count])
		if def.summon_interval > 0.0 and def.summon_def == null:
			_anomalies.append("INVOCATION VIDE : %s invoque toutes les %.1fs mais summon_def est nul"
				% [def.id, def.summon_interval])
	return rows


## D ou vient le chiffre de contact : c est la question que le .tres ne repond pas.
## LA DESCRIPTION DIT-ELLE LA VERITE ?
##
## Le joueur ne lit pas le .tres, il lit la carte. Une description qui annonce un
## chiffre que le sort n applique pas n est pas un defaut d equilibrage, c est un
## mensonge, et aucun test ne l attrape.
##
## ON NE CONTROLE QUE LES SORTS A COUP UNIQUE. Sur une zone au sol, il n existe
## pas UN chiffre de degats : la magnitude est un DEBIT (voir MAGNITUDE_SENS) et
## ce qu un monstre encaisse depend du temps qu il passe dedans. La Boule de feu
## annonce 26, applique 26 par seconde sur 0,6 s de zone, donc 16 a qui reste
## jusqu au bout et moins a qui traverse. Aucune des deux valeurs n est "la"
## bonne, donc crier au mensonge serait un faux signalement — et une liste
## d alertes a moitie fausse est une liste qu on cesse de lire.
##
## Les zones sont donc signalees a part, comme une AMBIGUITE a trancher une fois
## pour toutes (le chiffre des descriptions est-il un debit ou un total ?), et
## non comme une faute par carte.
##
## Tolerance de 15 % sur les coups uniques : les textes arrondissent.
func _verifie_description(c: SpellCard, degats: float, zone: bool) -> void:
	if degats <= 0.0 or c.description == "":
		return
	var re := RegEx.create_from_string("([0-9]+)\\s*(?:degats|degat)")
	var m: RegExMatch = re.search(c.description.to_lower())
	if m == null:
		return
	var annonce: float = float(m.get_string(1))
	if annonce <= 0.0:
		return
	if zone:
		# Le texte colle-t-il au DEBIT plutot qu au total ? Si oui, la convention
		# est "par seconde" — et il faut alors verifier qu elle est ECRITE.
		#
		# Le premier jet signalait les SEPT cartes de zone, dont six qui disent
		# deja "par seconde" dans leur description. Une alerte qui se declenche
		# sur du contenu correct est du bruit, et une liste a moitie fausse est
		# une liste qu on cesse de lire : on ne garde que les cartes ou la
		# convention est reelle mais TUE.
		var debit: float = degats / maxf(_duree_zone(c), 0.1)
		if absf(debit - annonce) / annonce <= 0.15:
			var texte: String = c.description.to_lower()
			var dit_le_debit: bool = texte.contains("par seconde") 				or texte.contains("/s") or texte.contains("par sec")
			if not dit_le_debit:
				_zones_ambigues.append("%s : le texte annonce %d SANS dire \"par seconde\", or c est un DEBIT ; un monstre reste %.1f s dans la zone et encaisse %.0f"
					% [c.id, int(annonce), _duree_zone(c), degats])
		return
	var ecart: float = absf(degats - annonce) / annonce
	if ecart > 0.15:
		_anomalies.append("DESCRIPTION TROMPEUSE : %s annonce %d degats au joueur, le .tres en applique %.0f (ecart %.0f %%)"
			% [c.id, int(annonce), degats, ecart * 100.0])


## Duree cumulee des briques de zone d une carte.
func _duree_zone(c: SpellCard) -> float:
	var d: float = 0.0
	for e: EffectSpec in c.effects:
		if e != null and String(MAGNITUDE_SENS.get(e.key, "autre")) == "dps":
			d = maxf(d, e.duration)
	return d


## Combien de fois la brique frappe le terrain. Une pluie de meteorites tombe
## `impacts` fois ; tout le reste ne frappe qu une.
func _multiplicite(e: EffectSpec) -> float:
	if String(MAGNITUDE_SENS.get(e.key, "autre")) == "total_par_impact":
		return float(e.get_param(&"impacts", 12))
	return 1.0


## Les degats REELS d une brique, magnitude convertie selon son handler.
## Zero pour tout ce qui n inflige pas de degats : un pourcentage de
## ralentissement additionne a des degats ne veut rien dire.
func _degats_reels(e: EffectSpec) -> float:
	match String(MAGNITUDE_SENS.get(e.key, "autre")):
		"total", "total_par_monstre", "taunt_prop":
			return e.magnitude
		"total_par_impact":
			# UN impact, et non la somme des 18. Un monstre ne se tient pas sous
			# toute la pluie a la fois : ce qu il encaisse, c est un impact (plus
			# un second avec de la malchance). Sommer donnait 1260 pour la Pluie
			# de meteorites, chiffre qui n arrive a personne et qui ecrasait la
			# colonne de toutes les autres cartes.
			return e.magnitude
		"dps":
			# La zone frappe `magnitude` par seconde pendant `duration`.
			return e.magnitude * maxf(e.duration, 0.1)
		"degats_allie":
			# Un allie frappe pendant sa vie ; ce n est pas un degat direct du
			# sort, donc hors total, mais on ne l invente pas non plus.
			return 0.0
	return 0.0


func _contact_source(def: EnemyDef) -> String:
	if def.contact_damage > 0:
		return "tres"
	if def.kind == GameEnums.EnemyKind.BOSS:
		return "bareme_boss"
	if def.kind == GameEnums.EnemyKind.MINIBOSS:
		return "bareme_miniboss"
	if GameConfig.CONTACT_DAMAGE_BY_POWER.has(def.power):
		return "bareme_puissance"
	return "DEFAUT_5"


## Les comportements ACTIFS, en mots. Un booleen `false` dans une colonne ne se
## lit pas ; une liste courte de ce qui est allume se lit d un coup d oeil.
func _behaviours(d: EnemyDef) -> String:
	var b: Array[String] = []
	if d.flying: b.append("vol")
	if d.projectile: b.append("projectile")
	if d.entry_side: b.append("entree_laterale")
	if d.swarm_count > 1: b.append("nuee=%d" % d.swarm_count)
	if d.dodge_chance > 0.0: b.append("esquive=%d%%" % int(d.dodge_chance * 100.0))
	if d.phase_interval > 0.0: b.append("phase=%.1fs" % d.phase_interval)
	if d.buff_speed_pct > 0.0: b.append("buff_vitesse=%.0f%%" % d.buff_speed_pct)
	if d.devours: b.append("gobe")
	if d.enrage_speed_pct > 0.0: b.append("enrage=%.0f%%" % d.enrage_speed_pct)
	if d.aura_shield_radius > 0.0: b.append("aura=%.0fpx" % d.aura_shield_radius)
	if d.burst_move: b.append("a_coups")
	if d.wave_amplitude > 0.0: b.append("ondule=%.0fpx" % d.wave_amplitude)
	if d.split_count > 0:
		b.append("divise=%dx%s" % [d.split_count,
			String(d.split_into.id) if d.split_into != null else "?"])
	if d.first_hit_shield: b.append("bouclier_1er_coup")
	if d.heal_per_second > 0.0: b.append("soigne=%.0f/s" % d.heal_per_second)
	if d.shoot_interval > 0.0:
		b.append("tire=%.1fs/%ddeg" % [d.shoot_interval, d.shot_damage])
	if d.blocks_cards > 0: b.append("bloque_cartes=%d" % d.blocks_cards)
	if d.shockwave_interval > 0.0:
		b.append("onde=%.1fs/%.0fpx/%ddeg" % [d.shockwave_interval,
			d.shockwave_radius, d.shockwave_damage])
	if d.parts_count > 0:
		b.append("morcele=%dx%.0fpv" % [d.parts_count, d.part_hp])
	if d.keeps_distance_at > 0.0: b.append("campe=%.0fpx" % d.keeps_distance_at)
	if d.summon_interval > 0.0:
		b.append("invoque=%dx%s/%.1fs(max%d)" % [d.summon_count,
			String(d.summon_def.id) if d.summon_def != null else "?",
			d.summon_interval, d.summon_max_alive])
	if d.revive_hp_pct > 0.0: b.append("ressuscite=%.0f%%" % d.revive_hp_pct)
	if d.hits_immune > 0: b.append("immune_%d_coups" % d.hits_immune)
	if d.reflect_pct > 0.0:
		b.append("renvoi=%.0f%%/%.1fs_sur_%.1fs" % [d.reflect_pct,
			d.reflect_window, d.reflect_interval])
	return " ".join(b)


# --------------------------------------------------------------------------
# SORTS
# --------------------------------------------------------------------------
func _table_cards() -> Array:
	var rows: Array = []
	rows.append(["id", "nom", "rarete", "passif", "seuil_vitesse", "incantation_s",
		"ciblage", "elements", "degats_total", "degats_tout_terrain",
		"degats_partiels", "degats_par_seconde", "rayon_max",
		"duree_max", "nb_effets", "effets", "exil", "copies_depart", "acces",
		"decks", "fx", "sfx", "description"])

	for c: SpellCard in _cards_sorted():
		var degats: float = 0.0
		## Ce que le sort deverse sur TOUT le terrain, impacts multiplies. Un
		## monstre n encaisse que `degats`, mais la valeur d une legendaire de
		## zone est justement sa couverture : les deux colonnes disent deux
		## choses vraies et differentes.
		var terrain: float = 0.0
		var rayon: float = 0.0
		var duree: float = 0.0
		var cles: Array[String] = []
		# Vrai des qu un effet de la carte n exprime PAS des degats : la colonne
		# `degats_total` ne dit alors qu une partie de ce que fait la carte, et il
		# faut le signaler plutot que de laisser croire au total.
		var partiel: bool = false
		for e: EffectSpec in c.effects:
			if e == null:
				continue
			cles.append(String(e.key))
			degats += _degats_reels(e)
			terrain += _degats_reels(e) * _multiplicite(e)
			if String(MAGNITUDE_SENS.get(e.key, "autre")) == "autre" and e.magnitude > 0.0:
				partiel = true
			rayon = maxf(rayon, e.radius)
			duree = maxf(duree, e.duration)
		var elements: Array[String] = []
		for t in c.tags:
			elements.append(GameEnums.tag_name(t))
		var decks: Array = _card_decks.get(c.id, [])
		# LE chiffre de comparaison. Les degats bruts mentent : la Traction
		# temporelle a 40 de magnitude sur 3,2 s d incantation rend moins qu une
		# Boule de feu a 26 sur 1,4 s. Un tableau de degats bruts trie a l envers.
		var dps: float = 0.0
		if not c.is_passive and c.base_cast_time > 0.0:
			dps = degats / c.base_cast_time
		# Comment cette carte arrive DANS la main. C est la question que le .tres
		# ne repond pas, et celle qui decide si son equilibrage compte.
		var acces: Array[String] = []
		if c.copies_in_starter > 0:
			acces.append("depart")
		if not decks.is_empty():
			acces.append("deck_niveau")
		acces.append("montee_passif" if c.is_passive else "montee_niveau")
		rows.append([
			String(c.id), c.display_name, GameEnums.rarity_name(c.rarity),
			"oui" if c.is_passive else "non",
			c.speed_threshold if c.is_passive else "",
			c.base_cast_time, _targeting_name(c.targeting),
			" ".join(elements), degats, terrain,
			"oui" if partiel else "non", dps, rayon, duree,
			c.effects.size(), " ".join(cles),
			"oui" if c.exile_after_cast else "non",
			c.copies_in_starter, " ".join(acces), " ".join(decks),
			String(c.fx_key), String(c.sfx_key),
			c.description,
		])

		# --- ANOMALIES par carte ---
		# JAMAIS DE DEPART, et non "injouable" : RunState.offer_choices() tire
		# dans TOUT le catalogue de la rarete, donc ces cartes sortent bien aux
		# montees de niveau. Ce qui leur manque, c est d etre garanties : le
		# joueur ne peut pas compter sur elles pour composer un plan, et leur
		# equilibrage n est jamais mesure au banc sur un niveau precis.
		if not c.is_passive and decks.is_empty() and c.copies_in_starter <= 0:
			_anomalies.append("JAMAIS GARANTIE : %s (%s, %s) n est dans aucun deck d exploration ni recompense — elle n arrive que par le tirage aleatoire des montees de niveau"
				% [c.id, c.display_name, GameEnums.rarity_name(c.rarity)])
		# UN PASSIF N EST PAS UN SORT. Il ne s incante pas, ne touche pas de
		# cible, et sa cle est lue par RunState.PASSIVE_KEYS et non par
		# EffectRegistry. Trois des regles ci-dessous ne s appliquent donc pas a
		# lui : les appliquer quand meme remplissait la liste de 42 fausses
		# alertes, ce qui est le meilleur moyen de faire ignorer les vraies.
		if c.is_passive:
			for ep: EffectSpec in c.effects:
				if ep == null:
					_anomalies.append("EFFET NUL : %s porte une entree d effet vide" % c.id)
				elif not (ep.key in RunState.PASSIVE_KEYS):
					_anomalies.append("CLE DE PASSIF INCONNUE : %s porte '%s', absente de RunState.PASSIVE_KEYS — il occuperait un emplacement sans rien faire"
						% [c.id, ep.key])
			continue

		# `degats` et non `c.has_damage()` : la methode du SpellCard repond vrai
		# des qu une magnitude est non nulle, or la magnitude d un
		# `slow_enemy_gauge` est un POURCENTAGE. L Entrave temporelle ressortait
		# ainsi comme "40 degats sans element" alors qu elle n inflige aucun
		# degat — elle ralentit de 40 %.
		if degats > 0.0:
			var a_element: bool = false
			for t in c.tags:
				if t in GameEnums.ELEMENTS:
					a_element = true
			if not a_element:
				_anomalies.append("DEGATS SANS ELEMENT : %s inflige %.0f degats sans porter d element — aucune resistance ne s applique"
					% [c.id, degats])
		# La description annonce un chiffre au joueur ; si le .tres en applique un
		# autre, c est le joueur qui a tort de faire confiance a sa carte.
		_verifie_description(c, degats, _duree_zone(c) > 0.0)
		for e2: EffectSpec in c.effects:
			if e2 == null:
				_anomalies.append("EFFET NUL : %s porte une entree d effet vide" % c.id)
				continue
			if not EffectRegistry.has_key(e2.key):
				_anomalies.append("CLE D EFFET INCONNUE : %s porte '%s', absente d EffectRegistry"
					% [c.id, e2.key])
		if c.fx_key == &"":
			_anomalies.append("SANS FEUILLE D EFFET : %s retombe sur l animation generique de son element — indistinguable des autres sorts du meme element"
				% c.id)
	return rows


# --------------------------------------------------------------------------
# NIVEAUX
# --------------------------------------------------------------------------
func _table_levels() -> Array:
	var rows: Array = []
	rows.append(["id", "nom", "acte", "sous_titre", "decor", "nb_vagues",
		"duree_vagues_s", "puissance_totale", "pv_cumules", "nb_monstres",
		"puissance_max_vague", "saut_max", "boss", "minibosses",
		"taille_deck", "deck", "elements_deck", "nb_objectifs", "objectifs",
		"recompense", "suivants"])

	for level: LevelDef in _levels_sorted():
		var puissance: int = 0
		var pv: float = 0.0
		var corps: int = 0
		var duree: float = 0.0
		var pmax: int = 0
		var boss: Array[String] = []
		var minis: Array[String] = []
		var courbe: Array[int] = []
		for w: WaveDef in level.waves:
			if w == null:
				continue
			var m: Dictionary = _wave_metrics(w)
			puissance += int(m["puissance"])
			pv += float(m["pv"])
			corps += int(m["corps"])
			duree += w.duration
			pmax = maxi(pmax, int(m["puissance"]))
			courbe.append(int(m["puissance"]))
			if w.is_boss:
				boss.append(String(m["boss_ids"]))
			if w.is_miniboss:
				minis.append(String(m["boss_ids"]))

		var deck: Array[String] = []
		var elements: Dictionary = {}
		for c: SpellCard in level.exploration_deck:
			if c == null:
				continue
			deck.append(String(c.id))
			for t in c.tags:
				if t in GameEnums.ELEMENTS:
					elements[GameEnums.tag_name(t)] = true
		var objs: Array[String] = []
		for o: ObjectiveDef in level.objectives:
			if o != null:
				objs.append(String(o.id))
		var suivants: Array[String] = []
		for n in level.next_levels:
			suivants.append(String(n))

		# Le SAUT MAXIMAL entre deux vagues consecutives. La regle maison (ecrite
		# dans wave_budget.gd) veut qu il reste sous x2 : au-dela le joueur passe
		# d une vague tenable a une vague qui le balaie sans transition.
		#
		# MESURE ENTRE VAGUES ORDINAIRES SEULEMENT. Une vague de palier porte
		# volontairement MOINS de troupes (le boss occupe la place), donc sortir
		# du creux remonte forcement : au niveau 1 le 6 du mini-boss suivi du 19
		# affichait un faux x3,17 alors que la vraie montee est 16 -> 19, soit
		# x1,19. Compter les paliers ferait sonner l alarme sur tous les niveaux
		# correctement construits, ce qui la rendrait inutile.
		var saut: float = 0.0
		var prec_ord: int = -1
		for i in courbe.size():
			var wi: WaveDef = level.waves[i]
			if wi != null and (wi.is_boss or wi.is_miniboss):
				continue
			if prec_ord > 0:
				saut = maxf(saut, float(courbe[i]) / float(prec_ord))
			prec_ord = courbe[i]

		rows.append([
			String(level.id), level.display_name, level.act, level.subtitle,
			level.backdrop if level.backdrop != "" else level.terrain,
			level.waves.size(), duree, puissance, pv, corps, pmax, saut,
			" ".join(boss), " ".join(minis),
			level.exploration_deck.size(), " ".join(deck),
			" ".join(elements.keys()),
			level.objectives.size(), " ".join(objs),
			String(level.legendary_reward.id) if level.legendary_reward != null else "",
			" ".join(suivants),
		])

		# --- ANOMALIES par niveau ---
		if saut > 2.0:
			_anomalies.append("SAUT DE DIFFICULTE : %s monte de x%.2f entre deux vagues ordinaires (limite maison x2) — courbe %s"
				% [level.id, saut, str(courbe)])
		# Un creux est NORMAL sur une vague de palier (le boss occupe la place),
		# et la vague qui SUIT un palier se compare a la derniere vague ordinaire,
		# pas au creux. On ne compare donc qu ordinaire a ordinaire.
		var p_ord: int = -1
		var p_num: int = 0
		for i in courbe.size():
			var w2: WaveDef = level.waves[i]
			if w2 != null and (w2.is_boss or w2.is_miniboss):
				continue
			if p_ord > 0 and courbe[i] < p_ord:
				_anomalies.append("COURBE QUI RECULE : %s vague %d pese %d points contre %d a la vague ordinaire %d — la difficulte redescend sans palier de boss pour l expliquer"
					% [level.id, i + 1, courbe[i], p_ord, p_num])
			p_ord = courbe[i]
			p_num = i + 1
		if level.objectives.size() != 3:
			_anomalies.append("OBJECTIFS : %s en porte %d au lieu de 3"
				% [level.id, level.objectives.size()])
		if level.legendary_reward == null:
			_anomalies.append("SANS RECOMPENSE : %s ne debloque aucune legendaire" % level.id)
		if level.exploration_deck.is_empty():
			_anomalies.append("DECK VIDE : %s n impose aucun deck d exploration" % level.id)
		# Un deck qui ne couvre pas un element ne peut rien faire contre un
		# monstre qui resiste a tout le reste.
		var manquants: Array[String] = []
		for t in GameEnums.ELEMENTS:
			if not elements.has(GameEnums.tag_name(t)):
				manquants.append(GameEnums.tag_name(t))
		if manquants.size() >= 4:
			_anomalies.append("DECK ETROIT : %s ne couvre que %d element(s) sur 6 (absents : %s)"
				% [level.id, 6 - manquants.size(), ", ".join(manquants)])
	return rows


# --------------------------------------------------------------------------
# VAGUES DE NIVEAU — la granularite ou la courbe se lit vraiment.
# --------------------------------------------------------------------------
func _table_waves() -> Array:
	var rows: Array = []
	rows.append(["niveau", "acte", "n", "vague_id", "duree_s", "difficulte",
		"palier", "puissance", "pv_x1", "pv_echelle", "nb_corps",
		"pv_par_seconde", "elements_resistes", "boss", "composition"])

	for level: LevelDef in _levels_sorted():
		for i in level.waves.size():
			var w: WaveDef = level.waves[i]
			if w == null:
				continue
			var m: Dictionary = _wave_metrics(w)
			var palier: String = "boss" if w.is_boss else ("miniboss" if w.is_miniboss else "")
			# Le seul chiffre qui dit la PRESSION : des PV etales sur 40 s ne
			# valent pas les memes PV en 20 s.
			var pps: float = float(m["pv_echelle"]) / maxf(w.duration, 0.001)
			rows.append([
				String(level.id), level.act, i + 1, String(w.id), w.duration,
				w.difficulty, palier, m["puissance"], m["pv"], m["pv_echelle"],
				m["corps"], pps, m["resistes"], m["boss_ids"], m["composition"],
			])
	return rows


## Tout ce qui se calcule sur une vague. Une seule source, pour que le tableau
## des niveaux et celui des vagues ne puissent pas se contredire.
func _wave_metrics(w: WaveDef) -> Dictionary:
	var puissance: int = 0
	var pv: float = 0.0
	var corps: int = 0
	var comp: Array[String] = []
	var boss_ids: Array[String] = []
	# Elements auxquels TOUTE la vague resiste (multiplicateur < 1) : c est ce
	# qui rend un deck mono-element inutilisable sur une vague precise.
	var resistes: Dictionary = {}
	for t in GameEnums.ELEMENTS:
		resistes[t] = true

	for e: WaveEntry in w.entries:
		if e == null or e.enemy == null:
			continue
		var d: EnemyDef = e.enemy
		# Une NUEE descend swarm_count corps par exemplaire : compter les entrees
		# sous-estimait la vague d un facteur 4 sur les rats.
		var n: int = e.count * maxi(1, d.swarm_count)
		corps += n
		pv += d.max_hp * float(n)
		comp.append("%dx%s(p%d)" % [e.count, d.id, d.power])
		if d.is_boss():
			boss_ids.append(String(d.id))
		else:
			# Le boss est HORS budget, comme dans WaveBudget : l inclure ferait
			# passer une vague de palier pour la plus lourde du niveau alors
			# qu elle porte MOINS de troupes.
			puissance += d.power * e.count
		for t in GameEnums.ELEMENTS:
			if d.resistance_to(t) >= 1.0:
				resistes[t] = false

	var res_list: Array[String] = []
	for t in GameEnums.ELEMENTS:
		if resistes[t] and corps > 0:
			res_list.append(GameEnums.tag_name(t))

	return {
		"puissance": puissance,
		"pv": pv,
		"pv_echelle": pv * w.difficulty,
		"corps": corps,
		"composition": " ".join(comp),
		"boss_ids": " ".join(boss_ids),
		"resistes": " ".join(res_list),
	}


# --------------------------------------------------------------------------
# EFFETS — une ligne par brique. C est la vue qui repond a "quelles cartes
# utilisent ground_zone, et avec quels chiffres" : impossible a lire autrement
# qu en ouvrant les 48 .tres un par un.
# --------------------------------------------------------------------------
func _table_effects() -> Array:
	var rows: Array = []
	rows.append(["cle", "connue", "carte", "rarete", "rang", "magnitude",
		"duree_s", "rayon_px", "params"])
	for c: SpellCard in _cards_sorted():
		for i in c.effects.size():
			var e: EffectSpec = c.effects[i]
			if e == null:
				continue
			rows.append([String(e.key),
				"oui" if EffectRegistry.has_key(e.key) else "NON",
				String(c.id), GameEnums.rarity_name(c.rarity), i + 1,
				e.magnitude, e.duration, e.radius, str(e.params)])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		if String(a[0]) == "cle":
			return true
		if String(b[0]) == "cle":
			return false
		return String(a[0]) < String(b[0]))

	# Une cle enregistree qu AUCUNE carte n utilise : du code mort, ou une brique
	# ecrite pour un sort jamais livre.
	var utilisees: Dictionary = {}
	for c2: SpellCard in ContentDB.cards.values():
		for e2: EffectSpec in c2.effects:
			if e2 != null:
				utilisees[e2.key] = true
	for k in EffectRegistry.keys():
		if not utilisees.has(k):
			_anomalies.append("EFFET SANS CARTE : la cle '%s' est enregistree dans EffectRegistry mais aucune carte ne l utilise"
				% k)
	return rows


# --------------------------------------------------------------------------
# MASSACRE — les budgets ne sont ECRITS nulle part, ils sont calcules par
# WaveBudget. C est la seule facon de les lire sans lancer une partie.
# --------------------------------------------------------------------------
func _table_massacre() -> Array:
	var rows: Array = []
	rows.append(["vague", "monde", "acte", "decor", "tour", "palier",
		"budget_brut", "budget_troupes", "difficulte", "saut_vs_precedente"])
	var prec: int = 0
	for n in range(1, MASSACRE_WAVES + 1):
		var palier: String = ""
		if WaveBudget.is_boss_wave(n):
			palier = "boss"
		elif WaveBudget.is_miniboss_wave(n):
			palier = "miniboss"
		var b: int = WaveBudget.budget_for(n)
		var saut: float = float(b) / float(prec) if prec > 0 else 0.0
		rows.append([n, WaveBudget.world_name_for(n), WaveBudget.act_for(n),
			WaveBudget.backdrop_for(n), WaveBudget.cycle_for(n), palier,
			WaveBudget.raw_budget_for(n), b, WaveBudget.difficulty_for(n), saut])
		if saut > 2.0:
			_anomalies.append("MASSACRE, SAUT : vague %d passe de %d a %d points de troupes (x%.2f, limite maison x2)"
				% [n, prec, b, saut])
		prec = b
	return rows


# --------------------------------------------------------------------------
# RESUME CONSOLE — ce qu on veut voir sans ouvrir un tableur.
# --------------------------------------------------------------------------
func _print_digest() -> void:
	print("-- RESUME --")
	var par_rarete: Dictionary = {}
	var passifs: int = 0
	for c: SpellCard in ContentDB.cards.values():
		var r: String = GameEnums.rarity_name(c.rarity)
		par_rarete[r] = int(par_rarete.get(r, 0)) + 1
		if c.is_passive:
			passifs += 1
	var detail: Array[String] = []
	for r in ["commune", "rare", "epique", "legendaire"]:
		detail.append("%s %d" % [r, int(par_rarete.get(r, 0))])
	print("  Cartes    : %d  (%s)  dont %d passifs"
		% [ContentDB.cards.size(), ", ".join(detail), passifs])

	var creatures: int = 0
	var boss: int = 0
	var minis: int = 0
	var projectiles: int = 0
	for d: EnemyDef in ContentDB.enemies.values():
		if d.projectile:
			projectiles += 1
			continue
		creatures += 1
		if d.kind == GameEnums.EnemyKind.BOSS:
			boss += 1
		elif d.kind == GameEnums.EnemyKind.MINIBOSS:
			minis += 1
	print("  Monstres  : %d creatures (%d boss, %d mini-boss) + %d projectiles"
		% [creatures, boss, minis, projectiles])
	print("  Niveaux   : %d  |  Vagues ecrites : %d  |  Effets : %d cles"
		% [ContentDB.levels.size(), ContentDB.waves.size(), EffectRegistry.keys().size()])
	print("  Defis     : %d  |  Recompenses : %d"
		% [ContentDB.challenges.size(), ContentDB.rewards.size()])

	print("")
	print("-- COURBE DE LA CAMPAGNE (puissance de troupes par vague) --")
	for level: LevelDef in _levels_sorted():
		var courbe: Array[String] = []
		var total: int = 0
		var pv: float = 0.0
		for w: WaveDef in level.waves:
			if w == null:
				continue
			var m: Dictionary = _wave_metrics(w)
			var marque: String = ""
			if w.is_boss:
				marque = "B"
			elif w.is_miniboss:
				marque = "m"
			courbe.append("%d%s" % [int(m["puissance"]), marque])
			total += int(m["puissance"])
			pv += float(m["pv_echelle"])
		print("  %-7s acte %d : %-34s  total %3d pts, %6.0f PV"
			% [level.id, level.act, " ".join(courbe), total, pv])
	print("  (B = vague de boss, m = mini-boss ; le boss est hors budget de troupes)")


## UNE decision a prendre, pas N fautes a corriger. Toutes ces cartes suivent la
## MEME convention : leur texte donne le debit par seconde. Soit c est voulu et il
## faut l ecrire ("8 degats par seconde"), soit ce ne l est pas et ce sont les
## chiffres qu il faut revoir. Dans les deux cas la reponse est la meme pour
## toutes, d ou une section et non huit alertes.
func _print_zones_ambigues() -> void:
	if _zones_ambigues.is_empty():
		return
	print("-- ZONES AU SOL : DEBIT OU TOTAL ? (%d cartes) --" % _zones_ambigues.size())
	print("   Ces cartes annoncent un nombre SANS dire \"par seconde\", alors que")
	print("   c en est un. Les autres cartes de zone l ecrivent, elles.")
	print("   Soit on l ajoute ici, soit on releve la magnitude pour que le")
	print("   total annonce soit le vrai.")
	for z in _zones_ambigues:
		print("     - %s" % z)


func _print_anomalies() -> void:
	if _anomalies.is_empty():
		print("-- ANOMALIES : aucune --")
		return
	print("-- ANOMALIES (%d) --" % _anomalies.size())
	print("   Des ODEURS, pas des fautes : a chacune il peut y avoir une bonne raison.")
	# Groupees par prefixe : lues une par une, trente lignes en desordre ne se
	# hierarchisent pas.
	var groupes: Dictionary = {}
	for a in _anomalies:
		var famille: String = a.split(" : ")[0]
		if not groupes.has(famille):
			groupes[famille] = []
		groupes[famille].append(a)
	var noms: Array = groupes.keys()
	noms.sort()
	for f in noms:
		print("  [%s] x%d" % [f, groupes[f].size()])
		for a in groupes[f]:
			print("     - %s" % a.substr(String(f).length() + 3))


# --------------------------------------------------------------------------
# TRIS STABLES — sans eux l ordre suit la lecture du disque, et deux executions
# donnent deux fichiers qu on ne peut pas comparer avec un diff.
# --------------------------------------------------------------------------
func _enemies_sorted() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		out.append(d)
	out.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool:
		if a.power != b.power:
			return a.power < b.power
		return String(a.id) < String(b.id))
	return out


func _cards_sorted() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return String(a.id) < String(b.id))
	return out


func _levels_sorted() -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for l: LevelDef in ContentDB.levels.values():
		out.append(l)
	out.sort_custom(func(a: LevelDef, b: LevelDef) -> bool:
		return String(a.id) < String(b.id))
	return out


func _kind_name(k: int) -> String:
	match k:
		GameEnums.EnemyKind.NORMAL: return "normal"
		GameEnums.EnemyKind.FAST: return "rapide"
		GameEnums.EnemyKind.TANK: return "tank"
		GameEnums.EnemyKind.EVASIVE: return "esquiveur"
		GameEnums.EnemyKind.SWARM: return "nuee"
		GameEnums.EnemyKind.BUFFER: return "meneur"
		GameEnums.EnemyKind.PHASER: return "phaseur"
		GameEnums.EnemyKind.MINIBOSS: return "MINIBOSS"
		GameEnums.EnemyKind.BOSS: return "BOSS"
		GameEnums.EnemyKind.DEVOURER: return "gobeur"
		GameEnums.EnemyKind.ENRAGER: return "enrage"
		GameEnums.EnemyKind.GUARDIAN: return "gardien"
		GameEnums.EnemyKind.BURSTER: return "a_coups"
		GameEnums.EnemyKind.WAVER: return "onduleur"
		GameEnums.EnemyKind.SPLITTER: return "diviseur"
		GameEnums.EnemyKind.SHIELDED: return "bouclier"
		GameEnums.EnemyKind.HEALER: return "soigneur"
		GameEnums.EnemyKind.BOMBER: return "bombe"
		GameEnums.EnemyKind.SHOOTER: return "tireur"
	return "?"


func _targeting_name(t: int) -> String:
	match t:
		GameEnums.Targeting.NONE: return "aucun"
		GameEnums.Targeting.POSITION: return "position"
		GameEnums.Targeting.DIRECTION: return "direction"
		GameEnums.Targeting.TARGET: return "ennemi"
	return "?"


# --------------------------------------------------------------------------
# ECRITURE CSV
# --------------------------------------------------------------------------
func _write(dir: String, nom: String, rows: Array) -> void:
	var chemin: String = "%s/%s" % [dir, nom]
	var f: FileAccess = FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		printerr("[INVENTAIRE] ecriture impossible : %s" % chemin)
		return
	# BOM UTF-8 : sans elle Excel lit les accents des descriptions en mojibake.
	f.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	for row: Array in rows:
		var cells: Array[String] = []
		for v in row:
			cells.append(_cell(v))
		f.store_line(";".join(cells))
	f.close()
	print("  %-14s %4d lignes" % [nom, rows.size() - 1])


## Une cellule CSV en locale francaise : separateur point-virgule, decimal
## virgule, guillemets doubles echappes par doublement.
func _cell(v: Variant) -> String:
	var s: String = ""
	if v is float:
		# Deux decimales suffisent partout (PV, multiplicateurs, secondes) et
		# %f seul produirait "26.000000", illisible dans une colonne.
		s = ("%.2f" % v).replace(".", ",")
	elif v is int or v is bool:
		s = str(v)
	else:
		s = String(v)
	s = s.replace("\n", " ").replace("\r", " ")
	if s.contains(";") or s.contains("\"") or s.contains(","):
		s = "\"%s\"" % s.replace("\"", "\"\"")
	return s

extends TestCase
## LE BESTIAIRE DU 27 SEPTEMBRE EST-IL JOUE ? (chantier W2)
##
## La vague 1 a livre douze mecaniques (EnemyDef, groupes « v3 ») et onze
## silhouettes (AnimCatalog) sans monstre pour les porter. Ce chantier les met en
## jeu. Cette suite verifie ce que le contenu doit TENIR, pas les regles du moteur
## (test_monster_mechanics_v3 et test_boss_mechanics_v3 s en chargent) :
##
##   1. chaque mecanique a un porteur, rencontre en campagne ET tire en Massacre ;
##   2. les niveaux prives de tete (lvl_12 a lvl_15) ont leur palier ;
##   3. un boss qui se divise pese sa CHAINE, pas son seul corps ;
##   4. le trio de mages arrive ensemble, et ses trois membres different ;
##   5. le Slime colossal est le plus grand du jeu et tient entier a l ecran ;
##   6. un boss promu en vermine est un .tres DERIVE, plus leger que le boss ;
##   7. deux tetes qui partagent une feuille se distinguent par leur teinte.
##
## Le piege qui a coute le plus cher au projet est le contenu qui existe et ne
## sort jamais : chaque sonde ci-dessous JOUE des vagues de Massacre au lieu de
## se fier au catalogue.

func get_suite_name() -> String:
	return "bestiaire_w2"


## Silhouettes extraites le 27/09 (tools/assets/extract_bestiaire_2026_09_27.py),
## plus les deux feuilles anciennes que ce chantier a enfin mises en jeu.
const SILHOUETTES_2026_09_27: Array[StringName] = [
	&"mageguardian_red", &"mageguardian_magenta", &"mechagolem", &"slime_big",
	&"slime_colossal", &"slime_ghost", &"slime_skeleton", &"fox", &"cacodaemon",
	&"demonlord", &"pawn_black", &"demon",
]

## LES DEMANDES DU CO-AUTEUR, et non des reglages : « un boss qui revient a la
## vie TROIS fois », « un boss immunise aux DIX premiers coups ». Si ces nombres
## changent, c est la demande qui a change, pas l equilibrage.
const VIES_DEMANDEES: int = 3
const COUPS_DEMANDES: int = 10

## Une tete de boss, chaine comprise, ne pese pas plus de 1,5 fois le boss le plus
## lourd SANS chaine. Au-dela, la mecanique de division (ou de vies) devient un
## sac de PV sous un autre nom — exactement ce qu un boss a mecanique ne doit pas
## etre. C est un RAPPORT, pas une valeur : il suit les PV du catalogue.
const CHAINE_MAX_RAPPORT: float = 1.5

## Les niveaux que le chantier devait combler en priorite (voir l en-tete de
## `_enemies_v3` dans tools/make_content.gd et docs/histoire.md).
const SANS_MINI_BOSS_AVANT: Array[StringName] = [&"lvl_12", &"lvl_13", &"lvl_14", &"lvl_15"]
const SANS_BOSS_AVANT: Array[StringName] = [&"lvl_15"]

## Feuilles partagees entre deux tetes que le joueur croise dans la meme campagne.
## La teinte doit les distinguer (AnimCatalog.MODULATE).
const PAIRES_A_DISTINGUER: Array = [
	[&"pit_witch", &"gravecaller"],
	[&"tombol_seal", &"trio_frost"],
	[&"clockmaker", &"forge_colossus"],
	[&"season_chameleon", &"wraith_lord"],
	[&"spell_clerk", &"dark_mage"],
]

var _tires: Dictionary = {}
var _tetes: Dictionary = {}
var _en_campagne: Dictionary = {}
var _membership: Dictionary = {}


func run() -> void:
	_preparer_sondes()
	_test_chaque_mecanique_a_son_porteur()
	_test_les_silhouettes_du_27_sont_jouees()
	_test_les_niveaux_sans_tete_ont_leur_palier()
	_test_la_chaine_d_un_boss_reste_dans_le_catalogue()
	_test_une_vague_de_palier_pese_sa_chaine()
	_test_le_colosse_se_brise_en_deux_enormes()
	_test_le_trio_arrive_ensemble()
	_test_le_trio_revient_en_adeptes()
	_test_le_colosse_tient_a_l_ecran()
	_test_les_promus_sont_des_derives_alleges()
	_test_les_feuilles_partagees_se_distinguent()
	_test_les_jumeaux_descendent_par_paire()


# --------------------------------------------------------------------------
# Sondes communes : campagne, mondes, Massacre.
# --------------------------------------------------------------------------

func _preparer_sondes() -> void:
	_en_campagne.clear()
	for lv: LevelDef in ContentDB.levels.values():
		for w: WaveDef in lv.waves:
			if w == null:
				continue
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					_en_campagne[e.enemy.id] = lv.id
	_membership = WaveSpawner.build_membership()

	# 64 graines de 30 vagues : 64 paliers de boss et 64 de mini-boss par monde.
	# Le Grand Cimetiere compte sept mini-boss depuis ce chantier ; sur 24 paliers
	# (l echantillon de test_wave_budget) l un d eux reste au banc une fois sur
	# quarante par pur hasard, et la sonde dirait « injoignable » d un monstre
	# simplement rare. A 64, un monstre qui ne sort pas est injoignable.
	var pool: Array[EnemyDef] = []
	var bosses: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.projectile:
			continue
		if d.is_boss():
			bosses.append(d)
		else:
			pool.append(d)
	_tires.clear()
	_tetes.clear()
	var rng := RandomNumberGenerator.new()
	for graine in 64:
		rng.seed = 2709 + graine
		for n in range(1, 31):
			var w: WaveDef = WaveBudget.build_wave(n, pool, rng, bosses, _membership)
			if w == null:
				continue
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					_tires[e.enemy.id] = true
			if (w.is_boss or w.is_miniboss) and not w.entries.is_empty() \
					and w.entries[0].enemy != null:
				_tetes[w.entries[0].enemy.id] = true


## Un monstre est JOUE s il descend dans une vague ecrite, s il appartient a un
## monde, et si le Massacre le tire vraiment. Les trois, pas un seul.
func _verifier_joue(d: EnemyDef, quoi: String) -> void:
	ok(_en_campagne.has(d.id),
		"%s (%s) n apparait dans AUCUNE vague ecrite : invisible en campagne" % [d.id, quoi])
	ok(_membership.has(d.id),
		"%s (%s) n est rattache a aucun monde : le Massacre l ignore" % [d.id, quoi])
	if d.is_boss():
		ok(_tetes.has(d.id),
			"%s (%s) ne mene jamais un palier de Massacre" % [d.id, quoi])
	else:
		ok(_tires.has(d.id),
			"%s (%s) ne sort jamais dans les troupes du Massacre" % [d.id, quoi])


# --------------------------------------------------------------------------
# 1. Chaque mecanique a son porteur.
# --------------------------------------------------------------------------

func _test_chaque_mecanique_a_son_porteur() -> void:
	var E := EnemyDef.MovePattern
	# nom -> [predicat, exige une tete (boss ou mini-boss)]
	var noms: Array[String] = [
		"plusieurs vies", "boss a trois vies", "renaissance differee", "reanimateur",
		"laser de riposte", "sommeil qui coupe la magie", "zigzag", "rebond", "sauts",
		"mini-boss entre par le cote", "l Horloger", "les Jumeaux", "le Cameleon",
		"le Voleur de sorts", "le Devoreur-invocateur", "le Miroir du mage",
		"immunise aux dix premiers coups",
	]
	for nom: String in noms:
		var porteurs: Array[EnemyDef] = []
		for d: EnemyDef in ContentDB.enemies.values():
			if d != null and not d.projectile and _porte(d, nom):
				porteurs.append(d)
		ok(not porteurs.is_empty(), "la mecanique « %s » n a AUCUN porteur" % nom)
		for d in porteurs:
			_verifier_joue(d, nom)


## Les mecaniques de BOSS doivent etre portees par une tete (boss ou mini-boss) :
## elles sont ecrites pour un combat, pas pour un figurant.
func _porte(d: EnemyDef, nom: String) -> bool:
	var P := EnemyDef.MovePattern
	match nom:
		"plusieurs vies": return d.extra_lives > 0
		"boss a trois vies": return d.is_boss() and d.extra_lives >= VIES_DEMANDEES
		"renaissance differee": return d.rebirth_def != null and d.rebirth_count > 0
		"reanimateur": return d.reanimate_max > 0
		"laser de riposte": return d.laser_damage > 0
		"sommeil qui coupe la magie": return d.sleep_interval > 0.0
		"zigzag": return d.move_pattern == P.ZIGZAG
		"rebond": return d.move_pattern == P.BOUNCE
		"sauts": return d.move_pattern == P.HOP
		"mini-boss entre par le cote":
			return d.entry_side and d.kind == GameEnums.EnemyKind.MINIBOSS
		"l Horloger": return d.is_boss() and d.rewind_interval > 0.0
		"les Jumeaux": return d.is_boss() and d.twin_group != &""
		"le Cameleon": return d.is_boss() and d.chameleon_interval > 0.0
		"le Voleur de sorts": return d.is_boss() and d.steal_interval > 0.0
		"le Devoreur-invocateur":
			return d.is_boss() and d.devour_heal_pct > 0.0 and d.summon_def != null
		"le Miroir du mage": return d.is_boss() and d.mirror_speed_ref > 0
		"immunise aux dix premiers coups":
			return d.is_boss() and d.hits_immune >= COUPS_DEMANDES
	return false


func _test_les_silhouettes_du_27_sont_jouees() -> void:
	var portees: Dictionary = {}
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.projectile or not (d.anim_key in SILHOUETTES_2026_09_27):
			continue
		portees[d.anim_key] = true
		_verifier_joue(d, "feuille %s" % d.anim_key)
	for cle: StringName in SILHOUETTES_2026_09_27:
		ok(portees.has(cle), "la feuille %s ne porte aucun monstre : extraite pour rien" % cle)


# --------------------------------------------------------------------------
# 2. Les niveaux sans tete.
# --------------------------------------------------------------------------

func _test_les_niveaux_sans_tete_ont_leur_palier() -> void:
	for id: StringName in SANS_MINI_BOSS_AVANT:
		ok(_tete_de(id, false) != null,
			"%s n a toujours pas de vague de mini-boss menee par une tete" % id)
	for id: StringName in SANS_BOSS_AVANT:
		var t: EnemyDef = _tete_de(id, true)
		ok(t != null and t.kind == GameEnums.EnemyKind.BOSS,
			"%s n a toujours pas de vague de boss menee par un BOSS" % id)


## La tete (premiere entree, de classe boss) de la vague de boss ou de mini-boss.
func _tete_de(level_id: StringName, boss: bool) -> EnemyDef:
	var lv: LevelDef = ContentDB.levels.get(level_id)
	if lv == null:
		return null
	for w: WaveDef in lv.waves:
		if w == null or w.entries.is_empty() or w.entries[0] == null:
			continue
		if (boss and w.is_boss) or (not boss and w.is_miniboss):
			var d: EnemyDef = w.entries[0].enemy
			if d != null and d.is_boss():
				return d
	return null


# --------------------------------------------------------------------------
# 3. La chaine de PV.
# --------------------------------------------------------------------------

## PV d UN exemplaire, tout ce qu il faudra lui retirer compris : ses vies, son
## releve, ses parties, ses retours de jumeau, et recursivement ce qu il lache en
## se divisant ou en renaissant. Les soins et les invocations n y sont pas : ils
## dependent du jeu du joueur, pas de la fiche.
func _pv_de_chaine(d: EnemyDef, profondeur: int = 0) -> float:
	if d == null or profondeur > 6:
		return 0.0
	var pv: float = d.max_hp
	pv += d.max_hp * d.extra_lives * d.extra_life_hp_pct / 100.0
	pv += d.max_hp * d.revive_hp_pct / 100.0
	pv += d.parts_count * d.part_hp
	if d.twin_group != &"":
		pv += d.max_hp * d.twin_max_returns * d.twin_revive_hp_pct / 100.0
	if d.split_into != null and d.split_count > 0:
		pv += d.split_count * _pv_de_chaine(d.split_into, profondeur + 1)
	if d.rebirth_def != null and d.rebirth_count > 0:
		pv += d.rebirth_count * _pv_de_chaine(d.rebirth_def, profondeur + 1)
	return pv


func _vague_chaine(w: WaveDef) -> float:
	var pv: float = 0.0
	for e: WaveEntry in w.entries:
		if e != null and e.enemy != null:
			pv += _pv_de_chaine(e.enemy) * e.count * maxi(1, e.enemy.swarm_count)
	return pv * w.difficulty


## Une tete de classe boss ne pese pas, chaine comprise, plus de CHAINE_MAX_RAPPORT
## fois la tete la plus lourde de sa classe SANS chaine. Le Slime colossal fait
## 150 PV de croute : sans la chaine il passerait pour le plus leger des boss
## alors qu il lache deux mini-boss et six corps.
func _test_la_chaine_d_un_boss_reste_dans_le_catalogue() -> void:
	for genre in [GameEnums.EnemyKind.BOSS, GameEnums.EnemyKind.MINIBOSS]:
		var plus_lourd: float = 0.0
		for d: EnemyDef in ContentDB.enemies.values():
			if d != null and d.kind == genre:
				plus_lourd = maxf(plus_lourd, d.max_hp)
		for d: EnemyDef in ContentDB.enemies.values():
			if d == null or d.kind != genre:
				continue
			var chaine: float = _pv_de_chaine(d)
			ok(chaine <= plus_lourd * CHAINE_MAX_RAPPORT,
				"%s pese %.0f PV chaine comprise, plus de x%.1f la tete la plus lourde (%.0f)"
				% [d.id, chaine, CHAINE_MAX_RAPPORT, plus_lourd])
	# Et la chaine du colosse est bien COMPTEE : sa croute seule ne dit rien.
	var c: EnemyDef = ContentDB.enemies.get(&"slime_colossal")
	ok(c != null and _pv_de_chaine(c) > c.max_hp * 2.0,
		"le Slime colossal pese sa chaine, pas sa seule croute")


## La regle maison (x2 d une vague a la suivante, test_balance) appliquee AVEC la
## chaine aux paliers dont la tete se divise, renait ou revient : un boss hors
## budget ne doit pas cacher un mur derriere son premier corps.
func _test_une_vague_de_palier_pese_sa_chaine() -> void:
	for lv: LevelDef in ContentDB.levels.values():
		for i in range(1, lv.waves.size()):
			var w: WaveDef = lv.waves[i]
			if w == null or not (w.is_boss or w.is_miniboss):
				continue
			var a_chaine: bool = false
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null \
						and _pv_de_chaine(e.enemy) > e.enemy.max_hp:
					a_chaine = true
			if not a_chaine:
				continue
			var avant: float = _vague_chaine(lv.waves[i - 1])
			var pv: float = _vague_chaine(w)
			ok(pv <= avant * 2.0,
				"%s / %s : %.0f PV de chaine apres %.0f, le saut depasse x2"
				% [lv.id, w.id, pv, avant])


func _test_le_colosse_se_brise_en_deux_enormes() -> void:
	var c: EnemyDef = ContentDB.enemies.get(&"slime_colossal")
	ok(c != null and c.kind == GameEnums.EnemyKind.BOSS, "le Slime colossal est un boss")
	if c == null:
		return
	ok(c.split_into != null and c.split_count == 2,
		"le Slime colossal se divise en DEUX (demande du co-auteur)")
	if c.split_into == null:
		return
	var enorme: EnemyDef = c.split_into
	eq(enorme.id, &"slime_huge", "ses enfants sont les Slimes enormes")
	ok(enorme.kind == GameEnums.EnemyKind.MINIBOSS, "le Slime enorme est un mini-boss")
	ok(enorme.split_into != null and enorme.split_count > 0,
		"le Slime enorme se divise a son tour")
	# Et le Slime enorme mene lui-meme un palier : le joueur l a vu seul avant
	# de le voir sortir du colosse.
	var mene: bool = false
	for lv: LevelDef in ContentDB.levels.values():
		for w: WaveDef in lv.waves:
			if w != null and w.is_miniboss and not w.entries.is_empty() \
					and w.entries[0].enemy != null and w.entries[0].enemy.id == enorme.id:
				mene = true
	ok(mene, "le Slime enorme mene une vague de mini-boss avant d etre un eclat de boss")


# --------------------------------------------------------------------------
# 4. Le trio.
# --------------------------------------------------------------------------

func _mages_du_trio(w: WaveDef) -> Array[WaveEntry]:
	var out: Array[WaveEntry] = []
	for e: WaveEntry in w.entries:
		if e != null and e.enemy != null and e.enemy.is_boss() \
				and String(e.enemy.anim_key).begins_with("mageguardian"):
			out.append(e)
	return out


func _test_le_trio_arrive_ensemble() -> void:
	var vague: WaveDef = null
	for lv: LevelDef in ContentDB.levels.values():
		for w: WaveDef in lv.waves:
			if w != null and w.is_boss and _mages_du_trio(w).size() >= 3:
				vague = w
	ok(vague != null, "une vague de boss porte le trio de mages")
	if vague == null:
		return
	var mages: Array[WaveEntry] = _mages_du_trio(vague)
	eq(mages.size(), 3, "trois mages, pas plus")
	ok(vague.entries[0] in mages, "c est un mage du trio qui mene la vague")

	# ENSEMBLE : les trois sont poses avant la premiere piece d escorte, et chacun
	# a un seul exemplaire (trois sprites, trois monstres).
	var dernier_mage: float = 0.0
	for e in mages:
		dernier_mage = maxf(dernier_mage, e.start_offset)
		eq(e.count, 1, "%s arrive seul de son espece" % e.enemy.id)
	for e: WaveEntry in vague.entries:
		if e != null and not (e in mages):
			ok(e.start_offset > dernier_mage,
				"l escorte (%s) arrive APRES les trois mages" % e.enemy.id)

	# TROIS DIFFERENTS : feuille, element faible, element resiste, pouvoir.
	var feuilles: Dictionary = {}
	var faibles: Dictionary = {}
	var forts: Dictionary = {}
	var pouvoirs: Dictionary = {}
	for e in mages:
		var d: EnemyDef = e.enemy
		feuilles[d.anim_key] = true
		faibles[_element_extreme(d, true)] = true
		forts[_element_extreme(d, false)] = true
		pouvoirs[_pouvoir(d)] = true
	eq(feuilles.size(), 3, "trois feuilles differentes (bleu, rouge, magenta)")
	eq(faibles.size(), 3, "trois faiblesses elementaires differentes")
	eq(forts.size(), 3, "trois resistances elementaires differentes")
	eq(pouvoirs.size(), 3, "trois pouvoirs personnels differents")
	ok(not pouvoirs.has(""), "chaque mage porte un pouvoir")


func _element_extreme(d: EnemyDef, faible: bool) -> int:
	var choix: int = -1
	var val: float = 0.0
	for t in GameEnums.ELEMENTS:
		var r: float = d.resistance_to(t)
		if choix < 0 or (faible and r > val) or (not faible and r < val):
			choix = t
			val = r
	return choix


func _pouvoir(d: EnemyDef) -> String:
	if d.mirror_speed_ref > 0:
		return "miroir"
	if d.extra_lives > 0:
		return "vies"
	if d.hits_immune > 0:
		return "sceaux"
	if d.steal_interval > 0.0:
		return "voleur"
	if d.rewind_interval > 0.0:
		return "horloger"
	if d.chameleon_interval > 0.0:
		return "cameleon"
	return ""


## « Puis ces trois mages reviennent comme MONSTRES ORDINAIRES dans les actes de
## fin. » Chaque feuille du trio porte un monstre ordinaire, plus leger, qui
## descend dans une vague ecrite d un acte POSTERIEUR a celui du trio.
func _test_le_trio_revient_en_adeptes() -> void:
	var acte_du_trio: int = 0
	var trio: Array[EnemyDef] = []
	for lv: LevelDef in ContentDB.levels.values():
		for w: WaveDef in lv.waves:
			if w != null and w.is_boss and _mages_du_trio(w).size() >= 3:
				acte_du_trio = lv.act
				for e in _mages_du_trio(w):
					trio.append(e.enemy)
	ok(not trio.is_empty(), "le trio existe")
	for mage in trio:
		var adepte: EnemyDef = null
		for d: EnemyDef in ContentDB.enemies.values():
			if d != null and not d.is_boss() and d.anim_key == mage.anim_key:
				adepte = d
		ok(adepte != null, "%s revient en monstre ordinaire" % mage.id)
		if adepte == null:
			continue
		ok(adepte.max_hp < mage.max_hp, "%s est plus leger que %s" % [adepte.id, mage.id])
		var plus_tard: bool = false
		for lv: LevelDef in ContentDB.levels.values():
			if lv.act <= acte_du_trio:
				continue
			for w: WaveDef in lv.waves:
				if w == null or w.is_boss or w.is_miniboss:
					continue
				for e: WaveEntry in w.entries:
					if e != null and e.enemy == adepte:
						plus_tard = true
		ok(plus_tard, "%s descend dans une vague normale d un acte de fin" % adepte.id)


# --------------------------------------------------------------------------
# 5. Le colosse a l ecran.
# --------------------------------------------------------------------------

func _largeur_affichee(d: EnemyDef) -> float:
	return d.base_radius * Enemy.VISUAL_FACTOR * 2.0 * maxf(d.sprite_scale, 0.1)


func _test_le_colosse_tient_a_l_ecran() -> void:
	var c: EnemyDef = ContentDB.enemies.get(&"slime_colossal")
	if c == null:
		ok(false, "le Slime colossal existe")
		return
	var largeur: float = _largeur_affichee(c)
	ok(largeur < GameConfig.BATTLEFIELD_WIDTH,
		"le Slime colossal (%.0f px) tient dans la largeur du terrain (%.0f px)"
		% [largeur, GameConfig.BATTLEFIELD_WIDTH])
	# Il nait ENTIER dans le cadre : sa marge d apparition couvre sa demi-largeur.
	ok(WaveSpawner.spawn_margin(c) * 2.0 >= largeur - 0.5,
		"sa marge d apparition le fait naitre entier a l ecran")
	# « Tres grand » : le plus grand sprite du jeu.
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d != c:
			ok(_largeur_affichee(d) < largeur,
				"%s (%.0f px) ne depasse pas le Slime colossal (%.0f px)"
				% [d.id, _largeur_affichee(d), largeur])


# --------------------------------------------------------------------------
# 6. Les promus.
# --------------------------------------------------------------------------

## Un monstre ORDINAIRE qui porte la feuille d une tete (boss ou mini-boss) est
## un promu, un adepte ou le sujet d un seigneur : il doit etre plus LEGER que
## toute tete de sa feuille. L inverse — rejouer le .tres du boss dans une vague
## de troupes — enverrait ses PV et son contact de boss dans la vermine.
func _test_les_promus_sont_des_derives_alleges() -> void:
	var tetes_par_feuille: Dictionary = {}
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.is_boss() and d.anim_key != &"":
			if not tetes_par_feuille.has(d.anim_key):
				tetes_par_feuille[d.anim_key] = []
			tetes_par_feuille[d.anim_key].append(d)
	var promus: int = 0
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.is_boss() or not tetes_par_feuille.has(d.anim_key):
			continue
		for tete: EnemyDef in tetes_par_feuille[d.anim_key]:
			promus += 1
			ok(_pv_de_chaine(d) < tete.max_hp,
				"%s (ordinaire, %.0f PV de chaine) doit rester sous %s (%.0f PV)"
				% [d.id, _pv_de_chaine(d), tete.id, tete.max_hp])
			ok(d.resource_path != tete.resource_path, "%s est un .tres a part" % d.id)
	ok(promus > 0, "des tetes ont leur version ordinaire")


# --------------------------------------------------------------------------
# 7. Les feuilles partagees.
# --------------------------------------------------------------------------

func _test_les_feuilles_partagees_se_distinguent() -> void:
	for paire in PAIRES_A_DISTINGUER:
		var a: EnemyDef = ContentDB.enemies.get(paire[0])
		var b: EnemyDef = ContentDB.enemies.get(paire[1])
		ok(a != null and b != null, "%s et %s existent" % paire)
		if a == null or b == null:
			continue
		if a.anim_key != b.anim_key:
			continue   # plus de feuille partagee : plus rien a distinguer
		ok(not AnimCatalog.modulate_for(a.id).is_equal_approx(AnimCatalog.modulate_for(b.id)),
			"%s et %s partagent la feuille %s sans teinte pour les distinguer"
			% [a.id, b.id, a.anim_key])


# --------------------------------------------------------------------------
# Les Jumeaux.
# --------------------------------------------------------------------------

## Une paire, et UNE definition : le Massacre tire une tete par palier, donc des
## jumeaux ecrits en deux definitions y descendraient seuls.
func _test_les_jumeaux_descendent_par_paire() -> void:
	var trouve: bool = false
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.twin_group == &"":
			continue
		trouve = true
		ok(d.swarm_count >= 2, "%s descend par paire depuis une seule entree" % d.id)
		ok(d.twin_max_returns > 0, "%s a un plafond de retours" % d.id)
	ok(trouve, "des jumeaux existent")

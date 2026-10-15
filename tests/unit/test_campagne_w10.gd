extends TestCase
## LA STRUCTURE DE LA CAMPAGNE DE LA VAGUE 10 (chantier B2, regles du co-auteur du
## 14/10). Tout se lit dans le CONTENU livre (ContentDB) : un niveau refait a la
## main qui oublie une regle fait rougir ce test.
##
##   1. LE DECK DE BASE : trois communes distinctes, la premiere est la commune
##      NOUVELLE du niveau (jamais vue avant lui, et nouvelle d un seul niveau),
##      les deux autres sont deja vues ; un sort qui blesse au moins ; le deck
##      sans objectif (exploration_deck) est 4/4/4 ; plus de cartes nouvelles.
##   2. UN VRAI BOSS dans la derniere vague, UN MINI-BOSS dans une autre, chacun
##      avec une mecanique.
##   3. L ARRIVEE DES MONSTRES : 5 ordinaires neufs a l ouverture d un acte, 1 ou
##      2 ensuite, qui restent dans la suite de l acte.
##   4. LES PROMOTIONS : allegees (PV coupes), au bon delai ; chaque mini-boss
##      revient en ordinaire a l acte suivant.
##   5. UN PASSIF par niveau a partir de l acte 2, aucun avant ; la reserve des
##      quetes annexes est exactement le reste.
##   6. LES RECOMPENSES : rare / epique / legendaire par rang, jamais la meme a
##      deux niveaux qui peuvent se suivre.
##   7. L OUVERTURE DE lvl_13 apres les QUATRE demons, et la fourche qui reste
##      une fourche.
##   8. LE BUDGET : les PV d une vague (boss et chaines compris) ne font jamais
##      plus que doubler d une vague a la suivante.

func get_suite_name() -> String:
	return "campagne_w10"


## Les cles d effet qui BLESSENT (ObjectiveChecker.KILLING_EFFECTS, plus les
## cles de la vague 10 qu il ne connait pas encore).
const CLES_QUI_BLESSENT: Array[StringName] = [
	&"electric_mark", &"global_rain", &"quicksand", &"water_jet",
]

## Le trio des fosses est UN boss a trois tetes (trio_ember porte le rang BOSS
## pour la mesure, ses deux freres sont mini-boss). Ses adeptes reviennent donc
## comme ceux d un mini-boss, a l acte suivant : la regle « boss -> ordinaire
## trois actes plus tard » les renverrait a l acte 6, qui n existe pas.
const TRIO: Array[StringName] = [&"trio_ember", &"trio_frost", &"trio_arcane"]

## Le plafond des PV d un promu, par rapport a sa source : la moitie pour un
## ordinaire, les deux tiers pour un mini-boss (un mini-boss reste une tete).
const PROMU_ORDINAIRE_MAX: float = 0.5
const PROMU_MINI_MAX: float = 0.67

## LES PASSIFS DES QUETES ANNEXES (chantier B3) : les 24 passifs qui ne sont pas
## de base, moins les 17 que debloque la campagne. Liste ECRITE : un passif qui
## quitte la campagne doit venir ici, et B3 sait ce qui lui revient.
const RESERVE_PASSIFS_ANNEXES: Array[StringName] = [
	&"pass_chain", &"pass_ice_bite", &"pass_overflow", &"pass_poison_corrode",
	&"pass_storm_reflex", &"pass_storm_surge", &"pass_timelock",
]


func run() -> void:
	_test_les_communes_de_base()
	_test_boss_et_mini_boss()
	_test_l_arrivee_des_monstres()
	_test_les_promotions()
	_test_chaque_mini_boss_revient_a_l_acte_suivant()
	_test_les_passifs()
	_test_les_recompenses()
	_test_lvl_13_s_ouvre_apres_les_quatre_demons()
	_test_le_budget_des_vagues()


# --- Outils ---

func _campagne() -> Array[LevelDef]:
	return ContentDB.campaign_levels()


## L ordre de jeu : parcours en largeur de next_levels depuis le premier niveau.
func _ordre() -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	var file: Array[StringName] = [SaveData.FIRST_LEVEL]
	var vus: Dictionary = {}
	var garde: int = 2000
	while not file.is_empty() and garde > 0:
		garde -= 1
		var id: StringName = file.pop_front()
		if vus.has(id):
			continue
		var lv: LevelDef = ContentDB.levels.get(id)
		if lv == null or not lv.is_campaign_level():
			continue
		# Un niveau n entre dans l ordre qu une fois tous ses parents places :
		# lvl_21 apres les deux branches de la fourche, lvl_13 apres les demons.
		var pret: bool = true
		for p: LevelDef in _parents(lv):
			if not vus.has(p.id):
				pret = false
		if not pret:
			file.append(id)
			continue
		vus[id] = true
		out.append(lv)
		for n in lv.next_levels:
			file.append(StringName(n))
	return out


func _parents(lv: LevelDef) -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for p: LevelDef in _campagne():
		if p.next_levels.has(lv.id):
			out.append(p)
	return out


## Tous les niveaux depuis lesquels `lv` est atteignable (ses ancetres).
func _ancetres(lv: LevelDef) -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	var pile: Array[LevelDef] = _parents(lv)
	while not pile.is_empty():
		var p: LevelDef = pile.pop_back()
		if out.has(p):
			continue
		out.append(p)
		pile.append_array(_parents(p))
	return out


## Tous les niveaux atteignables depuis `lv` (ses descendants).
func _descendants(lv: LevelDef) -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	var pile: Array[StringName] = []
	pile.assign(lv.next_levels)
	while not pile.is_empty():
		var id: StringName = pile.pop_back()
		var n: LevelDef = ContentDB.levels.get(id)
		if n == null or out.has(n):
			continue
		out.append(n)
		pile.append_array(n.next_levels)
	return out


## Les especes ORDINAIRES posees dans les vagues (entrees, hors tetes).
func _ordinaires(lv: LevelDef) -> Dictionary:
	var out: Dictionary = {}
	for w: WaveDef in lv.waves:
		for e: WaveEntry in w.entries:
			if e != null and e.enemy != null and not e.enemy.is_boss() and not e.enemy.projectile:
				out[e.enemy.id] = true
	return out


## Tout ce que le niveau fait VOIR (entrees, divisions, invocations, renaissances).
func _vus(lv: LevelDef) -> Dictionary:
	var out: Dictionary = {}
	for d: EnemyDef in ObjectiveChecker.level_enemies(lv):
		out[d.id] = true
	return out


func _blesse(c: SpellCard) -> bool:
	for spec: EffectSpec in c.effects:
		if spec == null or spec.magnitude <= 0.0:
			continue
		if spec.key in ObjectiveChecker.KILLING_EFFECTS or spec.key in CLES_QUI_BLESSENT:
			return true
	return false


## Une mecanique, au sens de la fiche : une ligne du bestiaire qui n est ni le
## repli « sans ruse » ni la filiation d un ancien boss.
func _mecaniques(d: EnemyDef) -> Array[String]:
	var out: Array[String] = []
	for l: String in BestiaryLore.behaviours(d):
		if l.begins_with("Descend tout droit") or l.begins_with("Ancien "):
			continue
		out.append(l)
	return out


## L acte de la premiere apparition d un monstre en ENTREE de vague de campagne
## (99 s il n en a aucune).
func _premier_acte(id: StringName) -> int:
	var acte: int = 99
	for lv: LevelDef in _campagne():
		for w: WaveDef in lv.waves:
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null and e.enemy.id == id:
					acte = mini(acte, lv.act)
	return acte


func _pv_de_chaine(d: EnemyDef, profondeur: int = 0) -> float:
	if d == null or profondeur > 6:
		return 0.0
	var pv: float = d.max_hp
	pv += d.max_hp * d.extra_lives * d.extra_life_hp_pct * 0.01
	pv += d.max_hp * d.revive_hp_pct * 0.01
	pv += d.parts_count * d.part_hp
	if d.twin_group != &"":
		pv += d.max_hp * d.twin_max_returns * d.twin_revive_hp_pct * 0.01
	if d.split_into != null and d.split_count > 0:
		pv += d.split_count * _pv_de_chaine(d.split_into, profondeur + 1)
	if d.rebirth_def != null and d.rebirth_count > 0:
		pv += d.rebirth_count * _pv_de_chaine(d.rebirth_def, profondeur + 1)
	return pv


func _pv_de_vague(w: WaveDef) -> float:
	var pv: float = 0.0
	for e: WaveEntry in w.entries:
		if e != null and e.enemy != null:
			pv += _pv_de_chaine(e.enemy) * e.count * maxi(1, e.enemy.swarm_count)
	return pv * w.difficulty


# --- 1. Le deck de base ---

func _test_les_communes_de_base() -> void:
	var ordre: Array[LevelDef] = _ordre()
	eq(ordre.size(), _campagne().size(), "l ordre de jeu passe par tous les niveaux de campagne")
	var toutes: Dictionary = {}
	for c: SpellCard in ContentDB.cards_of_rarity(GameEnums.Rarity.COMMON):
		if not c.is_passive:
			toutes[c.id] = true
	var nouvelles: Dictionary = {}
	for lv: LevelDef in ordre:
		ok(lv.has_base_commons(), "%s a ses trois communes de base" % lv.id)
		if not lv.has_base_commons():
			continue
		var ids: Dictionary = {}
		var blesse: bool = false
		for c: SpellCard in lv.base_commons:
			ok(c.rarity == GameEnums.Rarity.COMMON and not c.is_passive,
				"%s : %s est une commune" % [lv.id, c.id])
			ids[c.id] = true
			blesse = blesse or _blesse(c)
		eq(ids.size(), 3, "%s : trois communes DIFFERENTES" % lv.id)
		ok(blesse, "%s : jamais un deck sans degats" % lv.id)
		eq(lv.exploration_deck.size(), 12, "%s : le deck sans objectif fait 12 cartes" % lv.id)
		for c2: SpellCard in lv.base_commons:
			eq(lv.exploration_deck.count(c2), 4, "%s : %s x4 sans objectif" % [lv.id, c2.id])
		eq(lv.levelup_cards.size(), 0,
			"%s : plus de cartes nouvelles (le pool est obtenues + communes de l acte)" % lv.id)
		# Les communes vues AVANT ce niveau : dans tous ses ancetres.
		var avant: Dictionary = {}
		for a: LevelDef in _ancetres(lv):
			for c3: SpellCard in a.base_commons:
				avant[c3.id] = true
		var nouvelle: SpellCard = lv.new_common()
		var reste_inedite: bool = avant.size() < toutes.size()
		if lv.id == SaveData.FIRST_LEVEL:
			eq(avant.size(), 0, "le premier niveau n a pas de precedent")
		elif reste_inedite:
			not_ok(avant.has(nouvelle.id),
				"%s : sa commune nouvelle %s n a jamais ete vue avant lui" % [lv.id, nouvelle.id])
		else:
			# Toutes les communes sont vues (21 communes, trois au premier niveau) :
			# la « nouvelle » est une reprise, et seulement alors.
			ok(avant.has(nouvelle.id), "%s : plus aucune commune inedite, la sienne est une reprise" % lv.id)
		if lv.id != SaveData.FIRST_LEVEL:
			for i in [1, 2]:
				ok(avant.has(lv.base_commons[i].id),
					"%s : %s (communes 2 et 3) a deja ete vue" % [lv.id, lv.base_commons[i].id])
		if not avant.has(nouvelle.id):
			not_ok(nouvelles.has(nouvelle.id), "%s : %s n est la nouvelle que d un seul niveau (deja %s)"
				% [lv.id, nouvelle.id, nouvelles.get(nouvelle.id, "")])
			nouvelles[nouvelle.id] = lv.id
	# Toutes les communes du catalogue sont nouvelles quelque part (ou de depart).
	var depart: Dictionary = {}
	var l1: LevelDef = ContentDB.levels.get(SaveData.FIRST_LEVEL)
	if l1 != null:
		for c4: SpellCard in l1.base_commons:
			depart[c4.id] = true
	for id in toutes:
		ok(nouvelles.has(id) or depart.has(id),
			"la commune %s est la nouvelle d un niveau (ou du deck de depart)" % id)


# --- 2. Boss et mini-boss ---

func _test_boss_et_mini_boss() -> void:
	for lv: LevelDef in _campagne():
		ok(lv.waves.size() >= 2, "%s a au moins deux vagues" % lv.id)
		if lv.waves.size() < 2:
			continue
		var derniere: WaveDef = lv.waves[lv.waves.size() - 1]
		ok(derniere.is_boss, "%s : sa DERNIERE vague est une vague de boss" % lv.id)
		var boss: EnemyDef = derniere.entries[0].enemy if not derniere.entries.is_empty() else null
		ok(boss != null and boss.kind == GameEnums.EnemyKind.BOSS,
			"%s : la tete de sa vague de boss est un VRAI boss (%s)" % [lv.id, boss.id if boss else "rien"])
		if boss != null:
			ok(not _mecaniques(boss).is_empty(), "%s : son boss %s a une mecanique" % [lv.id, boss.id])
		var minis: int = 0
		for i in lv.waves.size() - 1:
			var w: WaveDef = lv.waves[i]
			not_ok(w.is_boss, "%s / %s : une seule vague de boss, la derniere" % [lv.id, w.id])
			if not w.is_miniboss:
				continue
			minis += 1
			var tete: EnemyDef = w.entries[0].enemy if not w.entries.is_empty() else null
			ok(tete != null and tete.kind == GameEnums.EnemyKind.MINIBOSS,
				"%s / %s : la tete est un mini-boss (%s)" % [lv.id, w.id, tete.id if tete else "rien"])
			if tete != null:
				ok(not _mecaniques(tete).is_empty(), "%s : son mini-boss %s a une mecanique" % [lv.id, tete.id])
		eq(minis, 1, "%s : un mini-boss, dans une autre vague que le boss" % lv.id)


# --- 3. L arrivee des monstres ---

func _test_l_arrivee_des_monstres() -> void:
	for lv: LevelDef in _campagne():
		var vus_avant: Dictionary = {}
		for a: LevelDef in _ancetres(lv):
			vus_avant.merge(_vus(a))
		var neufs: Array = []
		for id in _ordinaires(lv):
			if not vus_avant.has(id):
				neufs.append(id)
		neufs.sort()
		var ouvre: bool = true
		for p: LevelDef in _parents(lv):
			if p.act == lv.act:
				ouvre = false
		if ouvre:
			eq(neufs.size(), 5, "%s ouvre l acte %d : 5 ordinaires neufs %s" % [lv.id, lv.act, str(neufs)])
		else:
			between(neufs.size(), 1, 2, "%s ajoute 1 ou 2 ordinaires neufs %s" % [lv.id, str(neufs)])
		# Ils RESTENT dans la suite de l acte.
		for d: LevelDef in _descendants(lv):
			if d.act != lv.act:
				continue
			var la: Dictionary = _ordinaires(d)
			for id2 in neufs:
				ok(la.has(id2), "%s, venu au %s, descend encore au %s" % [id2, lv.id, d.id])


# --- 4. Les promotions ---

func _test_les_promotions() -> void:
	var promus: int = 0
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.demoted_from == &"":
			continue
		promus += 1
		var src: EnemyDef = ContentDB.enemies.get(d.demoted_from)
		ok(src != null and src.is_boss(), "%s vient d une tete (%s)" % [d.id, d.demoted_from])
		if src == null:
			continue
		ok(d.resource_path != src.resource_path, "%s a son propre .tres" % d.id)
		var gap: int = 1
		if d.is_boss():
			ok(d.kind == GameEnums.EnemyKind.MINIBOSS and src.kind == GameEnums.EnemyKind.BOSS,
				"%s : seul un BOSS revient en tete, et en MINI-BOSS" % d.id)
			ok(d.max_hp <= src.max_hp * PROMU_MINI_MAX, "%s : %.0f PV sur les %.0f de %s, les deux tiers au plus"
				% [d.id, d.max_hp, src.max_hp, src.id])
			gap = 2
		else:
			ok(d.max_hp <= src.max_hp * PROMU_ORDINAIRE_MAX, "%s : %.0f PV sur les %.0f de %s, la moitie au plus"
				% [d.id, d.max_hp, src.max_hp, src.id])
			if src.kind == GameEnums.EnemyKind.BOSS and not TRIO.has(src.id):
				gap = 3
		ok(d.contact_hit() < src.contact_hit(), "%s frappe moins fort que %s" % [d.id, src.id])
		var acte_src: int = _premier_acte(src.id)
		var acte_promu: int = _premier_acte(d.id)
		ok(acte_promu < 99, "%s descend dans une vague de campagne" % d.id)
		if acte_src < 99 and acte_promu < 99:
			ok(acte_promu >= acte_src + gap, "%s revient a l acte %d, %d au plus tot (%s : acte %d)"
				% [d.id, acte_promu, acte_src + gap, src.id, acte_src])
	ok(promus >= 20, "les promus de la vague 10 existent (%d)" % promus)


## « Un mini-boss devient un monstre ordinaire a l acte suivant » : chaque tete de
## palier des actes 1 a 4 (sauf un promu, qui est deja un retour) a sa version
## ordinaire, qui descend des l acte suivant.
func _test_chaque_mini_boss_revient_a_l_acte_suivant() -> void:
	for lv: LevelDef in _campagne():
		if lv.act >= 5:
			continue
		for w: WaveDef in lv.waves:
			if not w.is_miniboss or w.entries.is_empty():
				continue
			var tete: EnemyDef = w.entries[0].enemy
			if tete == null or tete.demoted_from != &"":
				continue
			var retour: EnemyDef = null
			for d: EnemyDef in ContentDB.enemies.values():
				if d != null and d.demoted_from == tete.id and not d.is_boss():
					retour = d
			ok(retour != null, "le mini-boss %s (%s) revient en ordinaire" % [tete.id, lv.id])
			if retour != null:
				eq(_premier_acte(retour.id), lv.act + 1,
					"%s (le retour de %s) descend a l acte suivant" % [retour.id, tete.id])


# --- 5. Les passifs ---

func _test_les_passifs() -> void:
	var vus: Dictionary = {}
	for lv: LevelDef in _campagne():
		if lv.act < LevelDef.PASSIVES_FROM_ACT:
			eq(lv.passive_unlocks.size(), 0, "%s (acte %d) ne debloque aucun passif" % [lv.id, lv.act])
			continue
		eq(lv.passive_unlocks.size(), 1, "%s debloque UN passif" % lv.id)
		for p: SpellCard in lv.passive_unlocks:
			ok(p != null and p.is_passive, "%s : son passif est un passif" % lv.id)
			if p == null:
				continue
			not_ok(GameConfig.BASE_PASSIVES.has(p.id), "%s : %s n est pas un passif de base" % [lv.id, p.id])
			not_ok(vus.has(p.id), "%s : %s n est debloque que par un niveau" % [lv.id, p.id])
			not_ok(RESERVE_PASSIFS_ANNEXES.has(p.id), "%s : %s n est pas dans la reserve des annexes" % [lv.id, p.id])
			vus[p.id] = true
	for c: SpellCard in ContentDB.cards.values():
		if c == null or not c.is_passive or GameConfig.BASE_PASSIVES.has(c.id):
			continue
		ok(vus.has(c.id) or RESERVE_PASSIFS_ANNEXES.has(c.id),
			"le passif %s est debloque par la campagne ou reserve aux annexes" % c.id)
	for id: StringName in RESERVE_PASSIFS_ANNEXES:
		var c2: SpellCard = ContentDB.cards.get(id)
		ok(c2 != null and c2.is_passive, "la reserve nomme un passif existant (%s)" % id)


# --- 6. Les recompenses ---

## Les niveaux qui peuvent se SUIVRE : voisins dans l ordre de jeu, plus les
## groupes ou l ordre est libre (la fourche de Tombol, les quatre demons).
func _groupes_libres() -> Array:
	return [
		[&"lvl_20", &"lvl_05", &"lvl_06", &"lvl_21"],
		[&"lvl_21", &"lvl_07", &"lvl_10", &"lvl_11", &"lvl_12", &"lvl_13"],
	]


func _test_les_recompenses() -> void:
	for lv: LevelDef in _campagne():
		eq(lv.objective_rewards.size(), 3, "%s : une recompense par objectif" % lv.id)
		for i in lv.objective_rewards.size():
			var r: SpellCard = lv.objective_rewards[i]
			ok(r != null and r.rarity == LevelDef.reward_rarity_for_rank(i + 1) and not r.is_passive,
				"%s : la recompense du rang %d est %s" % [lv.id, i + 1,
					GameEnums.rarity_name(LevelDef.reward_rarity_for_rank(i + 1))])
	var paires: Array = []
	var ordre: Array[LevelDef] = _ordre()
	for i in range(1, ordre.size()):
		paires.append([ordre[i - 1], ordre[i]])
	for g: Array in _groupes_libres():
		for a in g:
			for b in g:
				if String(a) < String(b):
					paires.append([ContentDB.levels.get(a), ContentDB.levels.get(b)])
	for p: Array in paires:
		var a2: LevelDef = p[0]
		var b2: LevelDef = p[1]
		if a2 == null or b2 == null:
			continue
		for r2: SpellCard in a2.objective_rewards:
			not_ok(b2.objective_rewards.has(r2), "%s et %s peuvent se suivre : pas tous deux %s"
				% [a2.id, b2.id, r2.id if r2 else "?"])


# --- 7. L ouverture de lvl_13 ---

func _test_lvl_13_s_ouvre_apres_les_quatre_demons() -> void:
	var pentacle: LevelDef = ContentDB.levels.get(&"lvl_13")
	ok(pentacle != null and pentacle.requires_all_previous, "lvl_13 attend tous ses precedents")
	if pentacle == null:
		return
	var demons: Array[LevelDef] = _parents(pentacle)
	eq(demons.size(), 4, "quatre niveaux menent au pentacle")
	SaveData.reset_profile()
	var sans: Dictionary = {}
	for i in demons.size():
		SaveData.unlock_level(demons[i].id)
		SaveData.record_victory(demons[i], GameEnums.Mode.EXPLORATION, sans, 1)
		if i < demons.size() - 1:
			not_ok(SaveData.is_level_unlocked(&"lvl_13"),
				"apres %d demon(s) sur 4, le pentacle reste ferme" % (i + 1))
	ok(SaveData.is_level_unlocked(&"lvl_13"), "apres les QUATRE demons, le pentacle s ouvre")
	# Une victoire en LIBRE ne compte pas pour la campagne : elle n ouvre rien.
	SaveData.reset_profile()
	for d: LevelDef in demons:
		SaveData.unlock_level(d.id)
		SaveData.record_victory(d, GameEnums.Mode.FREE, sans, 1)
	not_ok(SaveData.is_level_unlocked(&"lvl_13"), "quatre victoires en LIBRE n ouvrent pas le pentacle")
	# LA FOURCHE reste une fourche : lvl_21 s ouvre apres UNE seule de ses branches.
	SaveData.reset_profile()
	var forge: LevelDef = ContentDB.levels.get(&"lvl_05")
	var cour: LevelDef = ContentDB.levels.get(&"lvl_06")
	ok(forge != null and cour != null and forge.next_levels.has(&"lvl_21")
		and cour.next_levels.has(&"lvl_21"), "les deux branches menent a lvl_21")
	if forge != null:
		SaveData.unlock_level(forge.id)
		SaveData.record_victory(forge, GameEnums.Mode.EXPLORATION, sans, 1)
		ok(SaveData.is_level_unlocked(&"lvl_21"), "une seule branche de la fourche ouvre lvl_21")
	# Aucun autre niveau de campagne n attend tous ses precedents.
	for lv: LevelDef in _campagne():
		if lv.id != &"lvl_13":
			not_ok(lv.requires_all_previous, "%s s ouvre a la premiere victoire d un precedent" % lv.id)
	SaveData.reset_profile()


# --- 8. Le budget ---

func _test_le_budget_des_vagues() -> void:
	for lv: LevelDef in _campagne():
		var avant: float = 0.0
		for w: WaveDef in lv.waves:
			var pv: float = _pv_de_vague(w)
			ok(pv > 0.0, "%s / %s a des PV" % [lv.id, w.id])
			if avant > 0.0:
				ok(pv <= avant * 2.0, "%s / %s : %.0f PV (boss et chaines compris) apres %.0f, sous x2"
					% [lv.id, w.id, pv, avant])
			avant = pv

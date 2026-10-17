extends TestCase
## LES QUETES ANNEXES ET LEURS BOSS DORES (vague 10, chantier B3).
##
## Le contenu vient de tools/make_side_quests.gd (appele par make_content) ; le
## moteur des annexes (ouverture, page de la carte, hors progression) vient du
## chantier A3 et a ses tests dans test_campaign_progression. Ici : ce que le
## CONTENU livre doit tenir.
##   - huit annexes : cinq rattachees a un acte, trois a un apprenti ;
##   - structure_errors() vide, hors campaign_progress, aucune commune d acte ;
##   - un boss DORE en tete de la derniere vague de chacune, plus fort que son
##     monstre de base, jamais sur une feuille dont la licence interdit la
##     teinte, et qui porte bien la teinte d or ;
##   - chaque rare et chaque passif s obtient (base + campagne + annexes), et les
##     annexes donnent D ABORD le surplus de la campagne — quelle que soit la
##     table de la campagne, le test relit le contenu ;
##   - une annexe d apprenti est fermee tant que l apprenti n est pas gagne ;
##   - chaque annexe a son intro et son outro, et l apprenti y parle ;
##   - les objectifs sont classes du plus facile au plus dur, au banc (MESURES).
##
## Chaque regle est une fonction STATIQUE qui rend la liste des defauts :
## _test_les_detecteurs_mordent la sabote sur des donnees fabriquees (un
## detecteur qui ne verrait rien passerait sinon en silence).

func get_suite_name() -> String:
	return "side_quests"


## LICENCES (licences.md) : feuilles dont la licence interdit la MODIFICATION.
## Ecrites EN DUR ici (gotchas : un test qui relit la constante qu il contraint
## ne mord pas) : golems (golem, Behemoth, Vharn, Briseur), insecte volant (Feu
## follet), paon (Oiseau mirage).
const FEUILLES_SANS_TEINTE: Array[StringName] = [
	&"golem_blue", &"golem_orange", &"flyer", &"peacock",
]

## La demande d Alexis (14/10) : environ huit annexes, une par acte, une par
## apprenti. Les cles d AnimCatalog des trois apprentis.
const ANNEXES: int = 8
const ACTES: Array[int] = [1, 2, 3, 4, 5]
const APPRENTIS: Array[String] = ["soldier", "fairy", "bluewitch"]

## Repliques par scene (demande : « 3 a 6 repliques »).
const REPLIQUES_MIN: int = 3
const REPLIQUES_MAX: int = 6

## Vagues par annexe (demande : « 3 a 5 vagues »).
const VAGUES_MIN: int = 3
const VAGUES_MAX: int = 5

## Parties jouees par objectif au banc (tools/objective_bench.tscn), comme
## test_level_progression.PARTIES_DU_BANC.
const PARTIES_DU_BANC: int = 60

## VARIETE : un meme controle sur plus de cinq des huit annexes, et elles se
## liraient comme une seule quete recopiee (la campagne a sa propre borne,
## test_level_objectives). Ecrit en dur.
const MAX_ANNEXES_PAR_CLE: int = 5

## Le detecteur de la campagne : « N monstres d un seul sort » et un objet
## permanent qui tue ne vont pas ensemble.
const Progression = preload("res://tests/unit/test_level_progression.gd")
## LES RESERVES ECRITES PAR LE CHANTIER DE LA CAMPAGNE (B2) : ce qu elle laisse
## aux annexes, sorts (Progression.RESERVE_SORTS_ANNEXES) et passifs
## (Campagne.RESERVE_PASSIFS_ANNEXES). Le surplus que calcule
## tools/make_side_quests.gd et ces listes doivent dire la MEME chose.
const Campagne = preload("res://tests/unit/test_campagne_w10.gd")

## LES TAUX MESURES des objectifs des annexes (tools/objective_bench.tscn --
## --niveaux=<annexe> --parties=60, graines 1000 + 37 i, bot qui VISE
## l objectif ; le banc place chaque annexe juste apres son niveau d ouverture,
## SimBalance._inserer_annexes). Meme regle que la campagne : chaque objectif
## reussi ET rate au moins une fois, taux strictement decroissant du rang 1 au
## rang 3. Un objectif retouche change d identifiant (DEC-023) : sa ligne est
## alors refusee jusqu a la re-mesure.
##
## Mesure du 17/10, APRES LA FUSION DE B2 ET C1 (main 9e571ac : 21 niveaux refaits,
## leurs decks de base et leurs passifs) : les 24 objectifs re-joues, 60 parties
## chacun. Les seuils viennent d une sonde qui joue les memes graines et compte,
## pour chaque seuil candidat, les victoires qui le valident. Les decks de base
## de B2 ont change les communes possedees a l ouverture, donc les decks des
## annexes : six objectifs sur 24 ont change de seuil ou de rang a cette
## re-mesure. A RE-MESURER a chaque changement des decks de la campagne
## (`tools/objective_bench.tscn -- --niveaux=side_... --parties=60`, coller les
## lignes « MESURES » ici).
const MESURES: Dictionary = {
	"side_a1_mesure": [["obj_no_hit_from_hornblower_gold", 59], ["obj_kill_type_one_cast_3_hopper", 15], ["obj_win_above_speed_160", 8]],
	"side_a2_atelier": [["obj_kill_flying_8", 39], ["obj_win_under_time_130", 30], ["obj_win_above_speed_240", 10]],
	"side_a3_tresor": [["obj_win_under_time_150", 28], ["obj_multi_kill_5_1", 22], ["obj_never_hit_reflect", 4]],
	"side_a4_champion": [["obj_kill_type_one_cast_2_berserker", 25], ["obj_multi_kill_4_1", 23], ["obj_win_under_time_100", 12]],
	"side_a5_vitrine": [["obj_hit_from_sleepy_fox", 38], ["obj_multi_kill_6_1", 15], ["obj_win_above_speed_240", 9]],
	"side_bluewitch": [["obj_element_casts_40_lightning", 25], ["obj_win_under_time_140", 15], ["obj_no_hit_from_void_knight_gold", 3]],
	"side_fairy": [["obj_element_casts_30_fire", 29], ["obj_kill_type_one_cast_3_mushroom", 7], ["obj_win_above_speed_260", 3]],
	"side_squire": [["obj_kill_type_one_cast_2_nacelle_raider", 41], ["obj_win_above_speed_140", 25], ["obj_multi_kill_3_1", 5]],
}


func run() -> void:
	SaveData.reset_profile()
	_test_huit_annexes()
	_test_structure()
	_test_hors_de_la_progression()
	_test_un_boss_dore_ferme_chaque_annexe()
	_test_aucun_dore_sur_une_feuille_interdite()
	_test_la_teinte_doree()
	_test_rares_et_passifs_obtenables()
	_test_le_surplus_d_abord()
	_test_le_deck_d_une_annexe()
	_test_annexe_d_apprenti_fermee()
	_test_chaque_annexe_a_ses_scenes()
	_test_objectifs_classes_par_difficulte()
	_test_le_bestiaire_dit_l_or()
	_test_les_detecteurs_mordent()
	SaveData.reset_profile()


# --- Detecteurs (statiques, pour etre sabotes) --------------------------------

## Cinq annexes d acte (une par acte, ouverte apres un niveau de CAMPAGNE de cet
## acte) et trois d apprenti (une par apprenti), huit en tout.
static func defauts_repartition(annexes: Array[LevelDef], campagne: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if annexes.size() != ANNEXES:
		out.append("%d annexes, %d attendues" % [annexes.size(), ANNEXES])
	var actes: Dictionary = {}
	var apprentis: Dictionary = {}
	for lv: LevelDef in annexes:
		if not lv.side_quest:
			out.append("%s n est pas marquee annexe" % lv.id)
		var ouvre: LevelDef = campagne.get(lv.side_quest_after)
		if ouvre == null:
			out.append("%s : s ouvre apres '%s', qui n est pas un niveau de campagne"
				% [lv.id, lv.side_quest_after])
		if lv.side_quest_character == "":
			if actes.has(lv.act):
				out.append("%s : deux annexes d acte pour l acte %d (%s)" % [lv.id, lv.act, actes[lv.act]])
			actes[lv.act] = lv.id
			if ouvre != null and ouvre.act != lv.act:
				out.append("%s (acte %d) s ouvre apres %s, un niveau de l acte %d"
					% [lv.id, lv.act, ouvre.id, ouvre.act])
		else:
			if apprentis.has(lv.side_quest_character):
				out.append("%s : deux annexes pour l apprenti %s" % [lv.id, lv.side_quest_character])
			apprentis[lv.side_quest_character] = lv.id
	for a: int in ACTES:
		if not actes.has(a):
			out.append("aucune annexe pour l acte %d" % a)
	for p: String in APPRENTIS:
		if not apprentis.has(p):
			out.append("aucune annexe pour l apprenti %s" % p)
	return out


## La derniere vague est une vague de boss, menee (premiere entree, la ou
## test_bosses lit la tete) par un BOSS DORE : un boss dont le monstre de base
## existe, n est ni un boss ni un autre dore, et qui le depasse en PV ET en
## mecanique (BestiaryLore.gilded_gains, la definition unique de « plus fort »).
static func defauts_boss_dore(lv: LevelDef) -> Array[String]:
	var out: Array[String] = []
	if lv.waves.size() < VAGUES_MIN or lv.waves.size() > VAGUES_MAX:
		out.append("%d vagues, de %d a %d attendues" % [lv.waves.size(), VAGUES_MIN, VAGUES_MAX])
	if lv.waves.is_empty():
		return out
	var derniere: WaveDef = lv.waves[lv.waves.size() - 1]
	if derniere == null or not derniere.is_boss:
		out.append("la derniere vague n est pas une vague de boss")
		return out
	if derniere.entries.is_empty() or derniere.entries[0] == null or derniere.entries[0].enemy == null:
		out.append("la vague de boss n a pas de tete")
		return out
	var dore: EnemyDef = derniere.entries[0].enemy
	out.append_array(defauts_dore(dore))
	for w: WaveDef in lv.waves:
		if w == derniere or w == null:
			continue
		for e: WaveEntry in w.entries:
			if e != null and e.enemy != null and e.enemy.is_gilded():
				out.append("%s : le boss dore %s descend avant la derniere vague" % [w.id, e.enemy.id])
	return out


## Un boss dore pris seul : sa base, sa force, sa feuille.
static func defauts_dore(dore: EnemyDef) -> Array[String]:
	var out: Array[String] = []
	if dore == null:
		return ["aucun boss dore"]
	if not dore.is_gilded():
		out.append("%s mene la vague de boss mais n est pas dore (gilded_from vide)" % dore.id)
		return out
	if dore.kind != GameEnums.EnemyKind.BOSS:
		out.append("%s est dore mais n est pas un BOSS" % dore.id)
	var base: EnemyDef = ContentDB.enemies.get(dore.gilded_from)
	if base == null:
		out.append("%s : monstre de base %s introuvable" % [dore.id, dore.gilded_from])
		return out
	if base.is_boss() or base.is_gilded() or base.demoted_from != &"":
		out.append("%s : sa base %s n est pas un monstre de base (boss, dore ou echo)" % [dore.id, base.id])
	if dore.max_hp <= base.max_hp:
		out.append("%s : %d PV, pas plus que sa base %s (%d)"
			% [dore.id, int(dore.max_hp), base.id, int(base.max_hp)])
	if BestiaryLore.gilded_gains(dore, base).is_empty():
		out.append("%s : aucune mecanique en plus ni plus forte que %s" % [dore.id, base.id])
	if dore.anim_key != base.anim_key:
		out.append("%s : feuille %s, sa base porte %s" % [dore.id, dore.anim_key, base.anim_key])
	if dore.anim_key in FEUILLES_SANS_TEINTE:
		out.append("%s : la feuille %s interdit la modification, pas de teinte doree"
			% [dore.id, dore.anim_key])
	return out


## LES ROUTES D OBTENTION, regle du jeu ecrite ici sans relire le generateur.
## Un SORT : le deck de base d un niveau (campagne ou annexe, regle du livre),
## les recompenses de ses objectifs, ses cartes nouvelles tant qu il est au
## format d avant la vague 10 (RunState.levelup_pool_to_obtain).
static func sorts_obtenables(niveaux: Array) -> Dictionary:
	var out: Dictionary = {}
	for lv: LevelDef in niveaux:
		var listes: Array = [lv.campaign_base_cards(), lv.objective_rewards]
		if not lv.has_base_commons():
			listes.append(lv.levelup_cards)
		for liste: Array in listes:
			for c in liste:
				if c != null and not (c as SpellCard).is_passive:
					out[String((c as SpellCard).id)] = true
	return out


## Un PASSIF : la base, ou la victoire d un niveau qui le debloque. Tant que
## AUCUN niveau n en ecrit (contenu d avant la vague 10), le repli les propose
## tous a la montee de niveau des l acte 2 (SaveData._passive_unlocked_by_progress
## et RunState.levelup_pool_to_obtain).
static func passifs_obtenables(niveaux: Array, catalogue: Array) -> Dictionary:
	var out: Dictionary = {}
	var ecrits: bool = false
	var acte_2: bool = false
	for lv: LevelDef in niveaux:
		ecrits = ecrits or not lv.passive_unlocks.is_empty()
		acte_2 = acte_2 or lv.allows_passives()
	if not ecrits:
		if acte_2:
			for c: SpellCard in catalogue:
				if c.is_passive:
					out[String(c.id)] = true
		return out
	for id: StringName in GameConfig.BASE_PASSIVES:
		out[String(id)] = true
	for lv: LevelDef in niveaux:
		if not lv.allows_passives():
			continue
		for p in lv.passive_unlocks:
			if p != null:
				out[String((p as SpellCard).id)] = true
	return out


## Chaque rare (et chaque sort) et chaque passif du catalogue s obtient.
static func defauts_obtention(niveaux: Array, catalogue: Array) -> Array[String]:
	var out: Array[String] = []
	var sorts: Dictionary = sorts_obtenables(niveaux)
	var passifs: Dictionary = passifs_obtenables(niveaux, catalogue)
	for c: SpellCard in catalogue:
		if c.is_passive and not passifs.has(String(c.id)):
			out.append("le passif %s ne s obtient nulle part" % c.id)
		elif not c.is_passive and not sorts.has(String(c.id)):
			out.append("le sort %s (%s) ne s obtient nulle part"
				% [c.id, GameEnums.rarity_name(c.rarity)])
	return out


## LE SURPLUS D ABORD. Pour chaque rarete de recompense (rare, epique,
## legendaire) : le surplus est ce que la CAMPAGNE ne donne pas. Si une annexe
## donne une carte hors surplus (une reprise) alors que du surplus de cette
## rarete reste sans annexe, la distribution n a pas donne le surplus d abord.
## Les passifs : une annexe ne debloque QUE du surplus (ni la base ni la
## campagne), et n en ecrit aucun tant que la campagne n en ecrit pas (le repli
## d avant la vague 10 tomberait pour tout le jeu).
static func defauts_surplus(campagne: Array, annexes: Array, catalogue: Array) -> Array[String]:
	var out: Array[String] = []
	var donnes: Dictionary = sorts_obtenables(campagne)
	for rang in LevelDef.REWARD_RARITY_BY_RANK.size():
		var rarete: int = LevelDef.REWARD_RARITY_BY_RANK[rang]
		var surplus: Dictionary = {}
		for c: SpellCard in catalogue:
			if not c.is_passive and c.rarity == rarete and not donnes.has(String(c.id)):
				surplus[String(c.id)] = true
		var places: Dictionary = {}
		var reprises: Array[String] = []
		for lv: LevelDef in annexes:
			var r: SpellCard = lv.objective_reward(rang)
			if r == null:
				continue
			if surplus.has(String(r.id)):
				places[String(r.id)] = true
			else:
				reprises.append("%s:%s" % [lv.id, r.id])
		var oublies: Array = []
		for id in surplus:
			if not places.has(id):
				oublies.append(id)
		if not oublies.is_empty() and not reprises.is_empty():
			out.append("%s : le surplus %s attend alors que des annexes reprennent %s"
				% [GameEnums.rarity_name(rarete), oublies, reprises])
	var ecrits: bool = false
	var debloques: Dictionary = {}
	for id: StringName in GameConfig.BASE_PASSIVES:
		debloques[String(id)] = true
	for lv: LevelDef in campagne:
		for p in lv.passive_unlocks:
			if p != null:
				ecrits = true
				debloques[String((p as SpellCard).id)] = true
	for lv: LevelDef in annexes:
		if not ecrits and not lv.passive_unlocks.is_empty():
			out.append("%s debloque des passifs alors que la campagne n en ecrit aucun :"
				% lv.id + " le repli de tout le jeu tomberait")
		for p in lv.passive_unlocks:
			if p != null and debloques.has(String((p as SpellCard).id)):
				out.append("%s debloque %s, que la base ou la campagne debloquent deja"
					% [lv.id, (p as SpellCard).id])
	return out


## LES COMMUNES QU UNE ANNEXE PEUT PRENDRE SANS LES DONNER EN AVANCE, ecrites EN
## DUR : la Lumiere purifiante de l atelier du rat, qui y affronte un porteur
## d AURA (DEC-057 : la dissipation garantie, meme avant que la campagne ne
## l ait donnee). Toute autre commune d un deck d annexe doit etre DEJA donnee
## par la campagne quand l annexe s ouvre.
const COMMUNES_HORS_CAMPAGNE: Dictionary = {
	&"side_a2_atelier": [&"purifying_light"],
}

## Les niveaux de CAMPAGNE ouverts a coup sur au moment ou une annexe ouverte
## apres `apres` s ouvre, AVANT la victoire qui l ouvre : la regle du jeu
## (SaveData : une victoire ouvre ses next_levels ; un niveau marque
## requires_all_previous attend tous ses precedents) jouee sur le profil le plus
## court qui finit `apres`. Les niveaux qu on ne peut PAS contourner pour finir
## `apres` sont finis ; ce qu ils ouvrent est ouvert ; `apres` lui-meme l est.
## Ecrite ici sans relire le generateur (tools/make_side_quests.gd).
static func ouverts_a_l_ouverture(apres: StringName) -> Array[StringName]:
	var campagne: Array[LevelDef] = ContentDB.campaign_levels()
	# Les precedents de chaque niveau (ceux qui le citent dans next_levels).
	var precedents: Dictionary = {}
	for lv: LevelDef in campagne:
		precedents[lv.id] = []
	for p: LevelDef in campagne:
		for s in p.next_levels:
			if precedents.has(StringName(s)):
				(precedents[StringName(s)] as Array).append(p.id)
	var finis: Dictionary = {}
	for lv: LevelDef in campagne:
		if lv.id != apres and not _atteignable_sans(apres, lv.id, campagne, precedents):
			finis[lv.id] = true
	var out: Array[StringName] = [apres]
	for lv: LevelDef in campagne:
		if lv.id != apres and _ouvert_si(lv, finis, precedents):
			out.append(lv.id)
	return out


## `cible` peut-elle etre FINIE sans jamais finir `exclu` ? Point fixe : on finit
## tout ce qui s ouvre, sauf `exclu`.
static func _atteignable_sans(cible: StringName, exclu: StringName,
		campagne: Array[LevelDef], precedents: Dictionary) -> bool:
	var finis: Dictionary = {}
	var change: bool = true
	while change:
		change = false
		for lv: LevelDef in campagne:
			if lv.id == exclu or finis.has(lv.id) or not _ouvert_si(lv, finis, precedents):
				continue
			finis[lv.id] = true
			change = true
	return finis.has(cible)


## Un niveau de campagne est-il ouvert quand les niveaux `finis` le sont ? Le
## premier niveau toujours ; sinon un precedent fini, ou TOUS s il le demande.
static func _ouvert_si(lv: LevelDef, finis: Dictionary, precedents: Dictionary) -> bool:
	if lv.id == SaveData.FIRST_LEVEL:
		return true
	var siens: Array = precedents.get(lv.id, [])
	var finis_siens: int = 0
	for p in siens:
		if finis.has(p):
			finis_siens += 1
	if lv.requires_all_previous:
		return not siens.is_empty() and finis_siens == siens.size()
	return finis_siens > 0


## Le deck de base d une annexe : trois communes distinctes, dont une au moins
## TUE son boss dore ; une dissipation s il descend un porteur d aura (DEC-057) ;
## chaque commune DEJA DONNEE par la campagne a l ouverture de l annexe (sauf
## COMMUNES_HORS_CAMPAGNE) : ouvrir l annexe ne doit pas faire posseder en avance
## la commune nouvelle d un niveau a venir (regle du livre : le deck d un niveau
## ouvert est obtenu, et une annexe ouverte en est un).
static func defauts_deck(lv: LevelDef) -> Array[String]:
	var out: Array[String] = []
	if not lv.has_base_commons():
		out.append("pas de deck de base complet (%d communes)" % lv.base_commons.size())
		return out
	if lv.side_quest_after != &"":
		var donnees: Array[StringName] = SaveData.cards_owned_by_decks(
			ouverts_a_l_ouverture(lv.side_quest_after))
		var permises: Array = COMMUNES_HORS_CAMPAGNE.get(lv.id, [])
		for c: SpellCard in lv.base_commons:
			if not donnees.has(c.id) and not permises.has(c.id):
				out.append("la commune %s n est pas encore donnee par la campagne a l ouverture (apres %s)"
					% [c.id, lv.side_quest_after])
	else:
		out.append("aucun niveau d ouverture : les communes donnees ne se jugent pas")
	var dore: EnemyDef = null
	if not lv.waves.is_empty() and lv.waves[-1] != null and not lv.waves[-1].entries.is_empty():
		dore = lv.waves[-1].entries[0].enemy
	var tueuse: bool = false
	var dissipe: bool = false
	for c: SpellCard in lv.base_commons:
		tueuse = tueuse or ObjectiveChecker.card_can_kill(c, dore)
		dissipe = dissipe or &"dispel_zone" in c.effect_keys()
	if not tueuse:
		out.append("aucune commune du deck ne peut tuer le boss %s"
			% (dore.id if dore != null else &"?"))
	var aura: bool = false
	for d: EnemyDef in ObjectiveChecker.level_enemies(lv):
		aura = aura or d.aura_shield_radius > 0.0
	if aura and not dissipe:
		out.append("un porteur d aura descend, aucune dissipation au deck de base")
	return out


## Les scenes : intro et outro sur le disque, de REPLIQUES_MIN a REPLIQUES_MAX
## repliques ; dans une annexe d apprenti, l apprenti PARLE (son nom de compte
## est dans un locuteur).
static func defauts_scenes(lv: LevelDef) -> Array[String]:
	var out: Array[String] = []
	var nom: String = ""
	if lv.side_quest_character != "":
		for r: AccountRewardDef in ContentDB.rewards_list():
			if r != null and r.kind == GameEnums.RewardKind.CHARACTER \
					and r.texture_name == lv.side_quest_character:
				nom = r.display_name.to_lower()
	var parle: bool = false
	for sid: StringName in [lv.intro_story, lv.outro_story]:
		var d: DialogueDef = DialogueDef.load_by_id(sid)
		if d == null:
			out.append("la scene '%s' n existe pas" % sid)
			continue
		if d.line_count() < REPLIQUES_MIN or d.line_count() > REPLIQUES_MAX:
			out.append("%s : %d repliques, de %d a %d attendues"
				% [sid, d.line_count(), REPLIQUES_MIN, REPLIQUES_MAX])
		for i in d.line_count():
			if nom != "" and String(d.line(i).get("speaker", "")).to_lower().contains(nom):
				parle = true
	if nom != "" and not parle:
		out.append("l apprenti (%s) ne parle dans aucune de ses deux scenes" % nom)
	return out


## « N monstres d un seul sort » : aucune carte de la quete (deck de base,
## recompenses qui y entrent) ne pose un objet PERMANENT qui tue, sinon toutes
## ses morts sont UN lancer et l objectif devient gratuit.
static func defauts_un_seul_sort(lv: LevelDef) -> Array[String]:
	var out: Array[String] = []
	var vise: bool = false
	for o: ObjectiveDef in lv.objectives:
		vise = vise or (o != null and o.check_key == &"kill_type_one_cast")
	if not vise:
		return out
	for liste: Array in [lv.base_commons, lv.objective_rewards]:
		for c in liste:
			if c != null and Progression.pose_un_tueur_permanent(c):
				out.append("%s pose un tueur permanent" % (c as SpellCard).id)
	return out


## Le classement mesure (meme regle que test_level_progression).
static func defauts_classement(lv: LevelDef, mesure: Variant) -> Array[String]:
	var out: Array[String] = []
	if not mesure is Array or (mesure as Array).size() != lv.objectives.size():
		out.append("pas de mesure pour les %d objectifs" % lv.objectives.size())
		return out
	var precedent: int = PARTIES_DU_BANC + 1
	for i in lv.objectives.size():
		var ligne: Array = mesure[i]
		if lv.objectives[i] == null or StringName(ligne[0]) != lv.objectives[i].id:
			out.append("rang %d : mesure de %s, le niveau porte %s" % [i + 1, ligne[0],
				lv.objectives[i].id if lv.objectives[i] != null else &"rien"])
			continue
		var n: int = int(ligne[1])
		if n < 1:
			out.append("%s jamais reussi au banc" % ligne[0])
		if n > PARTIES_DU_BANC - 1:
			out.append("%s jamais rate au banc" % ligne[0])
		if n >= precedent:
			out.append("%s (%d) pas plus dur que le rang precedent (%d)" % [ligne[0], n, precedent])
		precedent = n
	return out


# --- Outils -------------------------------------------------------------------

static func _annexes() -> Array[LevelDef]:
	return ContentDB.side_quests()


static func _campagne_par_id() -> Dictionary:
	var out: Dictionary = {}
	for lv: LevelDef in ContentDB.campaign_levels():
		out[lv.id] = lv
	return out


static func _catalogue() -> Array:
	var out: Array = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null:
			out.append(c)
	return out


static func _dore_de(lv: LevelDef) -> EnemyDef:
	if lv.waves.is_empty() or lv.waves[-1] == null or lv.waves[-1].entries.is_empty():
		return null
	return lv.waves[-1].entries[0].enemy


# --- Tests du contenu -----------------------------------------------------------

func _test_huit_annexes() -> void:
	var d: Array[String] = defauts_repartition(_annexes(), _campagne_par_id())
	ok(d.is_empty(), "huit annexes, une par acte et une par apprenti %s" % [d])


func _test_structure() -> void:
	for lv: LevelDef in _annexes():
		eq(lv.structure_errors(), [] as Array[String], "%s : structure_errors() vide" % lv.id)
		eq(lv.progression_errors(), [] as Array[String], "%s : progression sans erreur" % lv.id)
		eq(lv.objectives.size(), 3, "%s : trois objectifs" % lv.id)
		var raretes: Array = []
		for r: SpellCard in lv.objective_rewards:
			raretes.append(int(r.rarity) if r != null else -1)
		eq(raretes, Array(LevelDef.REWARD_RARITY_BY_RANK), "%s : une rare, une epique, une legendaire" % lv.id)
		for o: ObjectiveDef in lv.objectives:
			if o != null:
				eq(ObjectiveChecker.impossible_reasons(o, lv), [] as Array[String],
					"%s / %s : possible" % [lv.id, o.id])
				eq(ObjectiveChecker.trivial_reasons(o, lv), [] as Array[String],
					"%s / %s : pas gratuit" % [lv.id, o.id])
		var d: Array[String] = defauts_un_seul_sort(lv)
		ok(d.is_empty(), "%s : « d un seul sort » sans objet permanent qui tue %s" % [lv.id, d])
		ok(lv.backdrop != "" and FileAccess.file_exists("res://assets/backdrops/%s.png" % lv.backdrop),
			"%s : son fond de combat %s existe" % [lv.id, lv.backdrop])
		not_ok(lv.backdrop.begins_with("talk_"), "%s : un fond de COMBAT, pas de dialogue" % lv.id)
	# La variete entre annexes.
	var par_cle: Dictionary = {}
	for lv: LevelDef in _annexes():
		for o: ObjectiveDef in lv.objectives:
			if o != null:
				par_cle[o.check_key] = int(par_cle.get(o.check_key, 0)) + 1
	for cle in par_cle:
		ok(int(par_cle[cle]) <= MAX_ANNEXES_PAR_CLE, "%s porte par %d annexes (au plus %d)"
			% [cle, par_cle[cle], MAX_ANNEXES_PAR_CLE])


## Hors campaign_progress (une annexe finie ne fait pas avancer la campagne,
## et la campagne finie sans elles ouvre le Massacre) ; aucune commune d acte
## (ContentDB.act_commons est le meme avec ou sans les annexes).
func _test_hors_de_la_progression() -> void:
	SaveData.reset_profile()
	var avant: Array = SaveData.campaign_progress()
	for lv: LevelDef in _annexes():
		not_ok(lv.is_campaign_level(), "%s n est pas un niveau de campagne" % lv.id)
		not_ok(ContentDB.campaign_levels().has(lv), "%s n est pas dans campaign_levels()" % lv.id)
		SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {}, lv.waves.size())
	eq(SaveData.campaign_progress(), avant, "les huit annexes finies : la campagne n a pas avance")
	SaveData.reset_profile()
	for lv: LevelDef in ContentDB.campaign_levels():
		SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {}, lv.waves.size())
	ok(SaveData.campaign_cleared(), "la campagne finie sans aucune annexe est finie (Massacre ouvert)")
	SaveData.reset_profile()
	# Les communes d acte, avec puis sans les annexes au catalogue.
	var avec: Dictionary = {}
	for a: int in ACTES:
		avec[a] = _ids(ContentDB.act_commons(a))
	var retirees: Dictionary = {}
	for lv: LevelDef in _annexes():
		retirees[lv.id] = lv
		ContentDB.levels.erase(lv.id)
	for a: int in ACTES:
		eq(_ids(ContentDB.act_commons(a)), avec[a], "acte %d : les annexes ne fournissent aucune commune d acte" % a)
	for id in retirees:
		ContentDB.levels[id] = retirees[id]
	eq(_annexes().size(), retirees.size(), "les annexes sont remises au catalogue")


func _test_un_boss_dore_ferme_chaque_annexe() -> void:
	var dores: Dictionary = {}
	for lv: LevelDef in _annexes():
		var d: Array[String] = defauts_boss_dore(lv)
		ok(d.is_empty(), "%s : un boss dore ferme la derniere vague %s" % [lv.id, d])
		var dore: EnemyDef = _dore_de(lv)
		if dore != null:
			ok(not dores.has(dore.id), "%s : le boss dore %s ferme aussi %s"
				% [lv.id, dore.id, dores.get(dore.id, &"")])
			dores[dore.id] = lv.id
	# Aucun boss dore mort : chacun ferme une annexe.
	for e: EnemyDef in ContentDB.enemies.values():
		if e != null and e.is_gilded():
			ok(dores.has(e.id), "le boss dore %s ferme une annexe" % e.id)


func _test_aucun_dore_sur_une_feuille_interdite() -> void:
	var vus: int = 0
	for e: EnemyDef in ContentDB.enemies.values():
		if e == null or not e.is_gilded():
			continue
		vus += 1
		not_ok(e.anim_key in FEUILLES_SANS_TEINTE,
			"%s : la feuille %s interdit la modification (licences.md)" % [e.id, e.anim_key])
		not_ok(Enemy.shown_sheet(e) in FEUILLES_SANS_TEINTE,
			"%s : la feuille affichee n est pas interdite de teinte" % e.id)
	eq(vus, ANNEXES, "un boss dore par annexe au catalogue")


## La teinte d or est posee sur la feuille du boss dore (AnimCatalog), et
## seulement la : sa base garde sa couleur.
func _test_la_teinte_doree() -> void:
	for e: EnemyDef in ContentDB.enemies.values():
		if e == null or not e.is_gilded():
			continue
		eq(AnimCatalog.modulate_for(e.id), AnimCatalog.GOLD_TINT, "%s porte la teinte d or" % e.id)
		ok(AnimCatalog.modulate_for(e.gilded_from) != AnimCatalog.GOLD_TINT,
			"%s, sa base, ne la porte pas" % e.gilded_from)
	# L or doit se VOIR : du rouge et du vert pousses, du bleu eteint.
	ok(AnimCatalog.GOLD_TINT.r > 1.0 and AnimCatalog.GOLD_TINT.g > AnimCatalog.GOLD_TINT.b,
		"la teinte d or eclaircit le rouge et le vert, eteint le bleu")


func _test_rares_et_passifs_obtenables() -> void:
	var niveaux: Array = ContentDB.levels.values()
	var d: Array[String] = defauts_obtention(niveaux, _catalogue())
	ok(d.is_empty(), "chaque sort et chaque passif s obtient (base, campagne, annexes) %s" % [d])
	var rares: int = 0
	for c: SpellCard in _catalogue():
		if not c.is_passive and c.rarity == GameEnums.Rarity.RARE:
			rares += 1
	ok(rares > 0, "des rares au catalogue (%d)" % rares)


func _test_le_surplus_d_abord() -> void:
	var d: Array[String] = defauts_surplus(ContentDB.campaign_levels(), _annexes(), _catalogue())
	ok(d.is_empty(), "les annexes donnent d abord le surplus de la campagne %s" % [d])
	# Le surplus calcule ici (ce que la campagne ne donne pas) est EXACTEMENT ce
	# que la campagne declare laisser aux annexes, et chaque element de ces
	# reserves est donne par une annexe.
	var donnes: Dictionary = sorts_obtenables(ContentDB.campaign_levels())
	var debloques: Dictionary = {}
	for id: StringName in GameConfig.BASE_PASSIVES:
		debloques[String(id)] = true
	for lv: LevelDef in ContentDB.campaign_levels():
		for p in lv.passive_unlocks:
			if p != null:
				debloques[String((p as SpellCard).id)] = true
	var surplus_sorts: Array = []
	var surplus_passifs: Array = []
	for c: SpellCard in _catalogue():
		if c.is_passive and not debloques.has(String(c.id)):
			surplus_passifs.append(String(c.id))
		elif not c.is_passive and not donnes.has(String(c.id)):
			surplus_sorts.append(String(c.id))
	surplus_sorts.sort()
	surplus_passifs.sort()
	eq(surplus_sorts, _tries(Progression.RESERVE_SORTS_ANNEXES),
		"le surplus de sorts est la reserve declaree par la campagne")
	eq(surplus_passifs, _tries(Campagne.RESERVE_PASSIFS_ANNEXES),
		"le surplus de passifs est la reserve declaree par la campagne")
	var par_annexes: Dictionary = {}
	for lv: LevelDef in _annexes():
		for liste: Array in [lv.objective_rewards, lv.passive_unlocks]:
			for c in liste:
				if c != null:
					par_annexes[String((c as SpellCard).id)] = lv.id
	for id in surplus_sorts + surplus_passifs:
		ok(par_annexes.has(id), "%s, laisse par la campagne, est donne par une annexe" % id)
	# LA ROUTE JOUEE : une annexe finie, ses passifs sont au pool de montee de
	# niveau (SaveData._passive_unlocked_by_progress lit passive_unlocks de tout
	# niveau fini), et pas avant.
	var acte_2: LevelDef = null
	for lv: LevelDef in ContentDB.campaign_levels():
		if lv.allows_passives() and (acte_2 == null or String(lv.id) < String(acte_2.id)):
			acte_2 = lv
	for lv: LevelDef in _annexes():
		if lv.passive_unlocks.is_empty() or acte_2 == null:
			continue
		SaveData.reset_profile()
		SaveData.unlock_level(acte_2.id)
		var avant: Array = _ids_cartes(RunState.levelup_pool(acte_2, GameEnums.Mode.EXPLORATION))
		SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {}, lv.waves.size())
		var apres: Array = _ids_cartes(RunState.levelup_pool(acte_2, GameEnums.Mode.EXPLORATION))
		for p in lv.passive_unlocks:
			var pid: String = String((p as SpellCard).id)
			not_ok(avant.has(pid), "%s : %s n est pas propose avant la victoire" % [lv.id, pid])
			ok(apres.has(pid), "%s finie : %s est propose a la montee de niveau" % [lv.id, pid])
	SaveData.reset_profile()


## Un des defauts contient-il `morceau` ?
static func _un_defaut_dit(defauts: Array[String], morceau: String) -> bool:
	for d: String in defauts:
		if d.contains(morceau):
			return true
	return false


static func _ids_cartes(cartes: Array) -> Array:
	var out: Array = []
	for c in cartes:
		if c != null:
			out.append(String((c as SpellCard).id))
	return out


static func _tries(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		out.append(String(id))
	out.sort()
	return out


func _test_le_deck_d_une_annexe() -> void:
	# La regle d ouverture, sur trois cas ecrits EN DUR.
	var apres_02: Array[StringName] = ouverts_a_l_ouverture(&"lvl_02")
	eq(_tries(apres_02), ["lvl_01", "lvl_02"],
		"apres lvl_02 : lvl_01 et lvl_02 ouverts, PAS lvl_08 (qu ouvre la victoire)")
	var apres_12: Array[StringName] = ouverts_a_l_ouverture(&"lvl_12")
	for frere: StringName in [&"lvl_07", &"lvl_10", &"lvl_11", &"lvl_05", &"lvl_06"]:
		ok(apres_12.has(frere), "apres lvl_12 : %s est ouvert (ouvert par lvl_21 / lvl_20)" % frere)
	not_ok(apres_12.has(&"lvl_13"), "apres lvl_12 : lvl_13 ne l est pas (il attend les quatre)")
	var apres_14: Array[StringName] = ouverts_a_l_ouverture(&"lvl_14")
	ok(apres_14.has(&"lvl_13") and apres_14.has(&"lvl_07"), "apres lvl_14 : le pentacle et les demons")
	not_ok(apres_14.has(&"lvl_15"), "apres lvl_14 : pas lvl_15")
	# L exception est encore NECESSAIRE et justifiee : sinon, la retirer.
	for id in COMMUNES_HORS_CAMPAGNE:
		var a: LevelDef = ContentDB.levels.get(id)
		ok(a != null, "(l annexe %s de l exception existe)" % id)
		if a == null:
			continue
		var aura: bool = false
		for d: EnemyDef in ObjectiveChecker.level_enemies(a):
			aura = aura or d.aura_shield_radius > 0.0
		ok(aura, "%s : un porteur d aura y descend (raison de l exception)" % id)
		var donnees: Array[StringName] = SaveData.cards_owned_by_decks(
			ouverts_a_l_ouverture(a.side_quest_after))
		for c in COMMUNES_HORS_CAMPAGNE[id]:
			ok(_ids_cartes(a.base_commons).has(String(c)), "%s porte bien %s" % [id, c])
			not_ok(donnees.has(c), "%s : %s n est pas encore donnee (l exception sert)" % [id, c])
	for lv: LevelDef in _annexes():
		var d: Array[String] = defauts_deck(lv)
		ok(d.is_empty(), "%s : deck de base jouable %s" % [lv.id, d])
		# Le deck joue est celui que le jeu lui donne : la table du co-auteur
		# sur ses communes, 12 cartes valides.
		var deck: Array[SpellCard] = lv.campaign_deck([])
		eq(deck.size(), 12, "%s : 12 cartes au deck de depart" % lv.id)
		ok(GameController.run_deck(lv, GameEnums.Mode.EXPLORATION).size() == 12,
			"%s : la partie distribue ce deck" % lv.id)


## Une annexe d apprenti est FERMEE tant que l apprenti n est pas gagne au compte,
## meme son niveau d ouverture fini ; elle s ouvre quand il l est.
func _test_annexe_d_apprenti_fermee() -> void:
	var vus: int = 0
	for lv: LevelDef in _annexes():
		if lv.side_quest_character == "":
			continue
		vus += 1
		SaveData.reset_profile()
		var avant: LevelDef = ContentDB.levels.get(lv.side_quest_after)
		ok(avant != null, "%s : son niveau d ouverture existe" % lv.id)
		if avant == null:
			continue
		SaveData.record_victory(avant, GameEnums.Mode.EXPLORATION, {}, avant.waves.size())
		var perso: AccountRewardDef = null
		for r: AccountRewardDef in ContentDB.rewards_list():
			if r != null and r.kind == GameEnums.RewardKind.CHARACTER \
					and r.texture_name == lv.side_quest_character:
				perso = r
		ok(perso != null, "%s : l apprenti %s est une recompense de compte" % [lv.id, lv.side_quest_character])
		if perso == null:
			continue
		ok(SaveData.account_level() < perso.at_level, "profil neuf : %s pas encore gagne" % perso.display_name)
		not_ok(SaveData.is_level_unlocked(lv.id),
			"%s : fermee tant que %s n est pas gagne" % [lv.id, perso.display_name])
		ok(SaveData.side_quest_lock_reason(lv).contains(perso.display_name),
			"%s : la raison nomme l apprenti (%s)" % [lv.id, SaveData.side_quest_lock_reason(lv)])
		SaveData.grant_account_xp(SaveData.account_xp_for_level(perso.at_level) - SaveData.account_xp())
		ok(SaveData.character_unlocked(lv.side_quest_character), "%s gagne" % perso.display_name)
		ok(SaveData.is_level_unlocked(lv.id), "%s : ouverte une fois l apprenti gagne" % lv.id)
	eq(vus, APPRENTIS.size(), "les trois annexes d apprenti ont ete verifiees")
	# LA TUILE DE LA CARTE ne montre que la PREMIERE condition qui manque : vue
	# en capture, la phrase entiere (niveau ET apprenti) debordait d une tuile
	# d un quart d ecran. La suivante apparait quand la premiere est remplie.
	for lv: LevelDef in _annexes():
		if lv.side_quest_character == "":
			continue
		SaveData.reset_profile()
		var avant: LevelDef = ContentDB.levels.get(lv.side_quest_after)
		var nom_avant: String = avant.display_name if avant != null else "?"
		ok(SaveData.side_quest_lock_reason(lv).contains(" ; "),
			"%s : profil neuf, deux conditions manquent" % lv.id)
		var tuile: String = CampaignMap.side_tile_reason(lv)
		ok(tuile.contains(nom_avant) and not tuile.contains(";"),
			"%s : la tuile dit d abord le niveau a finir (%s)" % [lv.id, tuile])
		if avant != null:
			SaveData.record_victory(avant, GameEnums.Mode.EXPLORATION, {}, avant.waves.size())
		var tuile2: String = CampaignMap.side_tile_reason(lv)
		ok(tuile2 != "" and not tuile2.contains(nom_avant),
			"%s : niveau fini, la tuile passe a l apprenti (%s)" % [lv.id, tuile2])
	SaveData.reset_profile()


func _test_chaque_annexe_a_ses_scenes() -> void:
	for lv: LevelDef in _annexes():
		var d: Array[String] = defauts_scenes(lv)
		ok(d.is_empty(), "%s : intro et outro jouables %s" % [lv.id, d])


func _test_objectifs_classes_par_difficulte() -> void:
	for lv: LevelDef in _annexes():
		var d: Array[String] = defauts_classement(lv, MESURES.get(String(lv.id)))
		ok(d.is_empty(), "%s : objectifs classes du plus facile au plus dur %s" % [lv.id, d])
	var ids: Dictionary = {}
	for lv: LevelDef in _annexes():
		ids[String(lv.id)] = true
	for niveau: String in MESURES:
		ok(ids.has(niveau), "MESURES[%s] est une annexe livree" % niveau)
	eq(MESURES.size(), ids.size(), "une ligne MESURES par annexe")


## La fiche du bestiaire dit de quel monstre le boss dore est la version
## renforcee, ses PV compares et ce que l or lui ajoute.
func _test_le_bestiaire_dit_l_or() -> void:
	for lv: LevelDef in _annexes():
		var dore: EnemyDef = _dore_de(lv)
		if dore == null or not dore.is_gilded():
			continue
		var base: EnemyDef = ContentDB.enemies.get(dore.gilded_from)
		var lignes: Array[String] = BestiaryLore.behaviours(dore)
		var texte: String = "\n".join(lignes)
		ok(texte.contains("Boss dore") and base != null and texte.contains(base.display_name),
			"%s : la fiche nomme sa base (%s)" % [dore.id, texte])
		ok(texte.contains(str(int(round(dore.max_hp)))), "%s : la fiche donne ses PV" % dore.id)
		ok(texte.contains("Ce que l or lui ajoute"), "%s : la fiche dit ce que l or ajoute" % dore.id)
	eq(BestiaryLore.gilded_lines(ContentDB.enemies.get(&"gnome")), [] as Array[String],
		"un monstre qui n est pas dore n a pas de ligne d or")


# --- Sabotages ------------------------------------------------------------------

func _test_les_detecteurs_mordent() -> void:
	var annexes: Array[LevelDef] = _annexes()
	var campagne: Dictionary = _campagne_par_id()
	ok(annexes.size() == ANNEXES, "les annexes livrees servent de modele")
	if annexes.size() != ANNEXES:
		return
	# 1. Repartition : une annexe de moins, deux pour le meme acte, une d apprenti
	#    sans apprenti.
	var moins: Array[LevelDef] = annexes.duplicate()
	moins.pop_back()
	not_ok(defauts_repartition(moins, campagne).is_empty(), "sabotage : sept annexes")
	var deux: Array[LevelDef] = annexes.duplicate()
	var copie: LevelDef = deux[0].duplicate()
	copie.id = &"copie"
	copie.side_quest_character = ""
	copie.act = 1
	deux[deux.size() - 1] = copie
	not_ok(defauts_repartition(deux, campagne).is_empty(), "sabotage : deux annexes pour l acte 1")
	var mauvais: LevelDef = annexes[0].duplicate()
	mauvais.side_quest_after = &"lvl_inexistant"
	var avec_mauvais: Array[LevelDef] = annexes.duplicate()
	avec_mauvais[0] = mauvais
	not_ok(defauts_repartition(avec_mauvais, campagne).is_empty(),
		"sabotage : une annexe ouverte apres un niveau inconnu")
	# 2. Boss dore : base en tete au lieu du dore, dore pas plus fort, feuille
	#    interdite.
	var lv: LevelDef = annexes[0]
	var dore: EnemyDef = _dore_de(lv)
	ok(dore != null and defauts_boss_dore(lv).is_empty(), "le modele est conforme")
	if dore == null:
		return
	var base: EnemyDef = ContentDB.enemies.get(dore.gilded_from)
	var faux: LevelDef = lv.duplicate()
	var w: WaveDef = lv.waves[-1].duplicate()
	var tete: WaveEntry = w.entries[0].duplicate()
	tete.enemy = base
	var entrees: Array[WaveEntry] = [tete]
	w.entries = entrees
	var vagues: Array[WaveDef] = lv.waves.duplicate()
	vagues[vagues.size() - 1] = w
	faux.waves = vagues
	not_ok(defauts_boss_dore(faux).is_empty(), "sabotage : le monstre de base mene la vague de boss")
	var faible: EnemyDef = dore.duplicate()
	faible.max_hp = base.max_hp
	not_ok(defauts_dore(faible).is_empty(), "sabotage : un dore qui n a pas plus de PV")
	var sans_meca: EnemyDef = base.duplicate()
	sans_meca.id = &"sabotage_dore"
	sans_meca.kind = GameEnums.EnemyKind.BOSS
	sans_meca.max_hp = base.max_hp * 5.0
	sans_meca.gilded_from = base.id
	not_ok(defauts_dore(sans_meca).is_empty(), "sabotage : un dore sans mecanique en plus")
	var interdit: EnemyDef = dore.duplicate()
	interdit.anim_key = &"golem_blue"
	not_ok(defauts_dore(interdit).is_empty(), "sabotage : un dore sur la feuille des golems")
	var tot: LevelDef = lv.duplicate()
	var trop: Array[WaveDef] = lv.waves.duplicate()
	for i in 3:
		trop.push_front(lv.waves[0])
	tot.waves = trop
	not_ok(defauts_boss_dore(tot).is_empty(), "sabotage : sept vagues")
	# 3. Obtention : une rare que plus personne ne donne.
	var catalogue: Array = _catalogue()
	var niveaux: Array = ContentDB.levels.values()
	var une_rare: SpellCard = null
	for c: SpellCard in catalogue:
		if not c.is_passive and c.rarity == GameEnums.Rarity.RARE:
			une_rare = c
			break
	var fantome: SpellCard = une_rare.duplicate()
	fantome.id = &"rare_sabotage"
	var cat2: Array = catalogue.duplicate()
	cat2.append(fantome)
	not_ok(defauts_obtention(niveaux, cat2).is_empty(), "sabotage : une rare que rien ne donne")
	# Un passif que rien ne debloque, une fois les passifs ecrits.
	var passif: SpellCard = null
	for c: SpellCard in catalogue:
		if c.is_passive and not GameConfig.BASE_PASSIVES.has(c.id):
			passif = c
			break
	var ecrit: LevelDef = annexes[1].duplicate()
	var un: Array[SpellCard] = [passif]
	ecrit.passive_unlocks = un
	var niv2: Array = niveaux.duplicate()
	niv2.append(ecrit)
	var p2: SpellCard = passif.duplicate()
	p2.id = &"passif_sabotage"
	var cat3: Array = [passif, p2]
	var d3: Array[String] = defauts_obtention(niv2, cat3)
	ok(d3.size() == 1 and d3[0].contains(String(p2.id)),
		"sabotage : un passif que ni la base ni un niveau ne debloque %s" % [d3])
	# 4. Surplus : une rare que la campagne ne donne pas, oubliee pendant qu une
	#    annexe REPREND une rare que la campagne donne deja.
	var surplus_cat: Array = catalogue.duplicate()
	surplus_cat.append(fantome)
	var donnes: Dictionary = sorts_obtenables(ContentDB.campaign_levels())
	var reprise: SpellCard = null
	for c: SpellCard in catalogue:
		if not c.is_passive and c.rarity == GameEnums.Rarity.RARE and donnes.has(String(c.id)):
			reprise = c
			break
	ok(reprise != null, "la campagne donne des rares")
	if reprise != null:
		var annexes_s: Array = []
		for a: LevelDef in annexes:
			annexes_s.append(a)
		var rep: LevelDef = annexes[0].duplicate()
		var rec: Array[SpellCard] = [reprise, annexes[0].objective_reward(1), annexes[0].objective_reward(2)]
		rep.objective_rewards = rec
		annexes_s[0] = rep
		not_ok(defauts_surplus(ContentDB.campaign_levels(), annexes_s, surplus_cat).is_empty(),
			"sabotage : du surplus de rare oublie pendant qu une annexe reprend")
	var annexes_r: Array = []
	for a: LevelDef in annexes:
		annexes_r.append(a)
	# Une annexe qui debloque un passif de BASE.
	var base_p: SpellCard = ContentDB.cards.get(GameConfig.BASE_PASSIVES[0])
	var avec_base: LevelDef = annexes[1].duplicate()
	var bp: Array[SpellCard] = [base_p]
	avec_base.passive_unlocks = bp
	var ann2: Array = annexes_r.duplicate()
	ann2[1] = avec_base
	not_ok(defauts_surplus(ContentDB.campaign_levels(), ann2, catalogue).is_empty(),
		"sabotage : une annexe qui debloque un passif de base")
	# 5. Deck : sans commune qui tue, ou sans dissipation face a une aura.
	var atelier: LevelDef = null
	for a: LevelDef in annexes:
		for d: EnemyDef in ObjectiveChecker.level_enemies(a):
			if d.aura_shield_radius > 0.0:
				atelier = a
	ok(atelier != null, "une annexe a un porteur d aura")
	if atelier != null:
		var sans: LevelDef = atelier.duplicate()
		var communes: Array[SpellCard] = []
		for c: SpellCard in ContentDB.cards_of_rarity(GameEnums.Rarity.COMMON):
			if not &"dispel_zone" in c.effect_keys() and communes.size() < 3:
				communes.append(c)
		sans.base_commons = communes
		# Le message PRECIS : depuis C7a, ces communes prises au hasard peuvent
		# aussi ne pas etre donnees a l ouverture ; le sabotage doit mordre pour
		# SA raison.
		ok(_un_defaut_dit(defauts_deck(sans), "aucune dissipation"),
			"sabotage : un porteur d aura sans dissipation %s" % [defauts_deck(sans)])
	var muet: LevelDef = lv.duplicate()
	var mur: SpellCard = null
	for c: SpellCard in ContentDB.cards_of_rarity(GameEnums.Rarity.COMMON):
		if not ObjectiveChecker.card_can_kill(c, dore):
			mur = c
			break
	ok(mur != null, "une commune ne tue pas (un mur)")
	if mur != null:
		var murs: Array[SpellCard] = [mur, mur, mur]
		muet.base_commons = murs
		ok(_un_defaut_dit(defauts_deck(muet), "ne peut tuer"),
			"sabotage : un deck qui ne tue pas le boss %s" % [defauts_deck(muet)])
	# 5 ter. Une commune que la campagne n a PAS encore donnee a l ouverture
	#    (C7a) : la premiere annexe prend une commune absente des decks ouverts.
	var tot_lv: LevelDef = lv.duplicate()
	var donnees: Array[StringName] = SaveData.cards_owned_by_decks(
		ouverts_a_l_ouverture(lv.side_quest_after))
	var pas_donnee: SpellCard = null
	for c: SpellCard in ContentDB.cards_of_rarity(GameEnums.Rarity.COMMON):
		if not c.is_passive and not donnees.has(c.id) and not lv.base_commons.has(c):
			pas_donnee = c
			break
	ok(pas_donnee != null, "(une commune n est pas encore donnee a l ouverture de %s)" % lv.id)
	if pas_donnee != null:
		var en_avance: Array[SpellCard] = [lv.base_commons[0], pas_donnee, lv.base_commons[2]]
		tot_lv.base_commons = en_avance
		ok(_un_defaut_dit(defauts_deck(tot_lv), "pas encore donnee"),
			"sabotage : une commune donnee EN AVANCE (%s) %s" % [pas_donnee.id, defauts_deck(tot_lv)])
	# L exception ne vaut que pour SON annexe : la Lumiere purifiante ailleurs,
	# avant que la campagne ne la donne, est refusee.
	var lumiere: SpellCard = ContentDB.cards.get(&"purifying_light")
	ok(lumiere != null and not donnees.has(&"purifying_light"),
		"(la Lumiere purifiante n est pas donnee a l ouverture de %s)" % lv.id)
	if lumiere != null and lv.id != &"side_a2_atelier":
		var ailleurs: LevelDef = lv.duplicate()
		var avec_lumiere: Array[SpellCard] = [lv.base_commons[0], lumiere, lv.base_commons[2]]
		ailleurs.base_commons = avec_lumiere
		ok(_un_defaut_dit(defauts_deck(ailleurs), "pas encore donnee"),
			"sabotage : l exception de l atelier ne vaut pas pour %s" % lv.id)
	# 5 bis. « D un seul sort » avec des Ronces (objet permanent qui tue) en
	#    recompense.
	var vise: LevelDef = null
	for a: LevelDef in annexes:
		for o: ObjectiveDef in a.objectives:
			if o != null and o.check_key == &"kill_type_one_cast":
				vise = a
	var tueur: SpellCard = null
	for c: SpellCard in _catalogue():
		if not c.is_passive and c.rarity == GameEnums.Rarity.RARE and Progression.pose_un_tueur_permanent(c):
			tueur = c
	ok(vise != null and tueur != null, "une annexe vise « d un seul sort », une rare pose un tueur")
	if vise != null and tueur != null:
		var ronces: LevelDef = vise.duplicate()
		var rec2: Array[SpellCard] = [tueur, vise.objective_reward(1), vise.objective_reward(2)]
		ronces.objective_rewards = rec2
		not_ok(defauts_un_seul_sort(ronces).is_empty(), "sabotage : un tueur permanent en recompense")
	# 6. Scenes : une scene absente, un apprenti muet.
	var sans_scene: LevelDef = lv.duplicate()
	sans_scene.outro_story = &"scene_inexistante"
	not_ok(defauts_scenes(sans_scene).is_empty(), "sabotage : une outro absente")
	for a: LevelDef in annexes:
		if a.side_quest_character == "":
			continue
		var muette: LevelDef = a.duplicate()
		muette.intro_story = lv.intro_story
		muette.outro_story = lv.outro_story
		not_ok(defauts_scenes(muette).is_empty(), "sabotage : l apprenti ne parle pas")
		break
	# 7. Classement : rangs inverses, objectif jamais rate.
	var m: Array = []
	for i in lv.objectives.size():
		m.append([String(lv.objectives[i].id), 10 + 10 * i])
	not_ok(defauts_classement(lv, m).is_empty(), "sabotage : un rang 3 plus facile que le rang 1")
	var m2: Array = []
	for i in lv.objectives.size():
		m2.append([String(lv.objectives[i].id), PARTIES_DU_BANC - i])
	not_ok(defauts_classement(lv, m2).is_empty(), "sabotage : un objectif jamais rate")


static func _ids(cartes: Array) -> Array:
	var out: Array = []
	for c in cartes:
		if c != null:
			out.append(String((c as SpellCard).id))
	out.sort()
	return out

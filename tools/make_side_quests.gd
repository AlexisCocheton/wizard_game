extends RefCounted
## QUETES ANNEXES ET BOSS DORES (vague 10, chantier B3).
##
## Appele par tools/make_content.gd, JUSTE APRES la generation des niveaux de
## campagne (une ligne dans son _ready) : la distribution des recompenses LIT
## les niveaux de campagne qui viennent d etre ecrits. Ecrit :
##   - resources/enemies/<base>_gold.tres : les BOSS DORES ;
##   - resources/waves/side_*.tres        : leurs vagues ;
##   - resources/levels/side_*.tres       : les HUIT quetes annexes.
## Les scenes (intro / outro) sont dans tools/make_story.gd, section « QUETES
## ANNEXES ». A relancer comme le reste du contenu :
##   godot --headless --path . tools/make_content.tscn
##
## LES HUIT QUETES (decision d Alexis, 14/10) : une par ACTE, ouverte apres un
## niveau de campagne de cet acte ; une par APPRENTI (l ecuyer, la fee,
## l apprentie d azur), fermee tant que l apprenti n est pas gagne au compte, et
## rattachee a un acte pour ses communes et ses passifs. Chacune se ferme sur un
## BOSS DORE : un monstre de base renforce (plus de PV, une mecanique EXISTANTE
## en plus ou plus forte, la teinte d or d AnimCatalog). Aucune mecanique neuve.
##
## LES RECOMPENSES SONT CALCULEES A LA GENERATION, pas ecrites en dur. Le
## chantier B2 refait EN PARALLELE les 21 niveaux de campagne et leurs
## recompenses : la liste du SURPLUS (ce que la campagne ne donne pas) n existe
## qu une fois ses niveaux ecrits. Le generateur la deduit :
##   1. il relit sur le disque les niveaux de campagne (objective_rewards,
##      decks de base, passive_unlocks, et cartes nouvelles s ils sont encore
##      au format d avant la vague 10) et GameConfig.BASE_PASSIVES ;
##   2. le SURPLUS = les rares (et epiques, legendaires) qu aucun niveau ne
##      donne, les passifs que ni la base ni la campagne ne debloquent ;
##   3. il le distribue selon la table de PREFERENCES de chaque quete (son
##      boss, ses monstres), puis un REPLI automatique pour ce qu aucune
##      preference ne couvre ; une case encore vide prend une REPRISE (une carte
##      que la campagne a deja proposee AVANT l ouverture de la quete, jamais une
##      carte deja possedee par un deck ouvert).
## Ce qui ne trouve pas de place est imprime « SURPLUS NON PLACE » : il faut
## alors une quete de plus ou une campagne qui en donne davantage
## (test_side_quests rougit, il verifie que tout rare et tout passif s obtient).
##
## LES PASSIFS. Ecrire un `passive_unlocks` bascule TOUT le jeu hors du repli
## d avant la vague 10 (ContentDB.passive_unlocks_authored : des lors, seuls les
## passifs debloques entrent au pool de montee). Tant que la campagne n en ecrit
## aucun, les annexes n en ecrivent pas non plus : sinon les 24 passifs que la
## campagne propose encore a la montee de niveau disparaitraient d un coup.
## Une annexe d acte 1 n en porte jamais (LevelDef.PASSIVES_FROM_ACT).
##
## LE DECK D UNE ANNEXE. Elle se lance en CAMPAGNE comme les autres niveaux
## (GameController.run_deck -> LevelDef.campaign_deck) : trois communes x4, qui
## evoluent avec ses objectifs reussis (table du co-auteur). Les trois communes
## sont prises parmi celles que les decks de base des niveaux de campagne ont
## DEJA donnees au moment ou la quete s ouvre (regle du livre : ouvrir l annexe
## ne doit pas faire posseder en avance la commune NOUVELLE d un niveau a
## venir), dans l ordre de preference de la quete. Exception nommee : une quete
## ou descend un porteur d AURA prend la Lumiere purifiante (DEC-057), meme si
## la campagne ne l a pas encore donnee.

const ENNEMIS: String = "res://resources/enemies/"
const NIVEAUX: String = "res://resources/levels/"
const VAGUES: String = "res://resources/waves/"
const CARTES: String = "res://resources/cards/"
## Prefixe des niveaux et des vagues des annexes (purges puis regeneres).
const PREFIXE: String = "side_"
## Suffixe de FICHIER des boss dores (resources/enemies/<base>_gold.tres). La
## filiation, elle, se lit dans EnemyDef.gilded_from, jamais dans l id.
const SUFFIXE_DORE: String = "_gold"

## LICENCES (licences.md) : ces feuilles interdisent litteralement la
## MODIFICATION. Une teinte doree en serait une : aucun boss dore ne les porte.
## Golems (golem, Behemoth, Vharn, Briseur), l insecte volant (Feu follet) et le
## paon (Oiseau mirage). test_side_quests relit cette liste.
const FEUILLES_SANS_TEINTE: Array[StringName] = [
	&"golem_blue", &"golem_orange", &"flyer", &"peacock",
]

## La couleur de la forme de SECOURS (EnemyBody, sans feuille) d un boss dore.
## La teinte de la feuille, elle, est AnimCatalog.GOLD_TINT.
const COULEUR_DOREE: Color = Color(0.95, 0.78, 0.25)

## Un boss dore est un BOSS (hors budget, barre de boss, palier du Massacre) :
## memes reperes que les boss de campagne (XP 30, rayon 70 a 84).
const DORE_PUISSANCE: int = 10
const DORE_XP: int = 30
## Rayon : celui de la base x DORE_RAYON_FACTEUR, borne. Le rayon fait aussi la
## taille a l ecran (gotchas : « le rayon logique d un monstre est aussi sa
## taille ») : un boss dore doit se lire plus gros que son monstre de base sans
## ecraser les boss d acte.
const DORE_RAYON_FACTEUR: float = 2.1
const DORE_RAYON_MIN: float = 56.0
const DORE_RAYON_MAX: float = 72.0

## La commune de DISSIPATION garantie dans une quete a porteur d aura (DEC-057).
const DISSIPATION: String = "purifying_light"

## Rarete -> dossier de cartes.
const DOSSIERS: Dictionary = {
	GameEnums.Rarity.RARE: "rare",
	GameEnums.Rarity.EPIC: "epic",
	GameEnums.Rarity.LEGENDARY: "legendary",
}

var _proprio: Node
## Les niveaux de campagne relus sur le disque, dans l ORDRE DE JEU.
var _campagne: Array[LevelDef] = []
## Les lignes du rapport imprime en fin de generation.
var _rapport: PackedStringArray = []


## Point d entree, appele par make_content.gd (`proprio`) : ses utilitaires
## _objectif (identifiant deduit, partage entre niveaux) et _save sont reutilises
## tels quels, pour qu un objectif d annexe et un objectif de campagne
## identiques partagent la meme ressource.
func generer(proprio: Node) -> void:
	_proprio = proprio
	_purger()
	var dores: Dictionary = _boss_dores()
	_campagne = _lire_campagne()
	var niveaux: Array[LevelDef] = []
	for q: Dictionary in quetes():
		niveaux.append(_niveau(q, dores))
	_distribuer(niveaux)
	for lv: LevelDef in niveaux:
		_proprio.call("_save", lv, NIVEAUX + String(lv.id) + ".tres")
	print("\n=== QUETES ANNEXES (make_side_quests.gd) ===")
	for l in _rapport:
		print(l)
	print("=== FIN DES QUETES ANNEXES ===")


# =====================================================================
# LES BOSS DORES
# =====================================================================

## base -> [id du boss dore, nom affiche, multiplicateur de PV, reglages].
## Les reglages sont des champs d EnemyDef (mecaniques EXISTANTES) ; la valeur
## d une cle se termine par « .tres » pour une ressource (sbire invoque, enfant
## de division). Le pourquoi de chacun est dans la table des quetes plus bas et
## dans la fiche du bestiaire (BestiaryLore.gilded_lines).
const DORES: Dictionary = {
	# Acte 1 — il bat la mesure : il presse les autres deux fois plus que le
	# Corniste et APPELLE la colonne de gnomes que le village a vue marcher au pas.
	"hornblower": ["hornblower_gold", "Corniste dore", 8.0, {
		"buff_speed_pct": 40.0, "summon_def": "gnome.tres", "summon_interval": 7.0,
		"summon_count": 2, "summon_max_alive": 6, "base_speed": 40.0}],
	# Acte 2 — un totem de port de l atelier du rat : aura plus large, et il
	# REPARE ce qu il protege (le soin du Pretre goule).
	"totem_guardian": ["totem_guardian_gold", "Gardien-totem dore", 3.0, {
		"aura_shield_radius": 300.0, "heal_per_second": 2.0, "base_speed": 26.0}],
	# Acte 3 — la garde du tresor vide : son bouclier de premier coup, et une
	# GARDE qui renvoie (le cycle du Miroir de Forge).
	"parry_skeleton": ["parry_skeleton_gold", "Squelette pareur dore", 4.5, {
		"reflect_interval": 6.0, "reflect_window": 1.6, "reflect_pct": 50.0,
		"base_speed": 40.0}],
	# Acte 4 — le champion de l arene : sa rage monte plus vite, et il se releve
	# UNE fois depuis le haut (les vies du Mage de braise).
	"berserker": ["berserker_gold", "Berserker dore", 5.5, {
		"enrage_speed_pct": 16.0, "extra_lives": 1, "extra_life_hp_pct": 50.0,
		"base_speed": 44.0}],
	# Acte 5 — la statue de la vitrine : deux cartes figees au lieu d une, et la
	# pierre encaisse ses trois premiers coups (les sceaux du Mage des arcanes).
	"gorgon_gazer": ["gorgon_gazer_gold", "Gorgone doree", 6.5, {
		"blocks_cards": 2, "hits_immune": 3, "base_speed": 32.0}],
	# L ecuyer — l archer d or des toits : il tire plus vite et plus fort, et
	# GARDE SES DISTANCES (la ligne de tir des boss tireurs).
	"imp_archer": ["imp_archer_gold", "Lutin archer dore", 10.0, {
		"shoot_interval": 2.2, "shot_damage": 3, "keeps_distance_at": 620.0,
		"base_speed": 42.0}],
	# La fee — pousse sur les tombes noyees : il se FEND en deux champignons a
	# sa mort (la division des gelees).
	"mushroom": ["mushroom_gold", "Champignon dore", 5.0, {
		"split_into": "mushroom.tres", "split_count": 2, "base_speed": 30.0}],
	# L apprentie d azur — le gardien de son cristal : son bouclier de premier
	# coup, et il DISPARAIT dans le vide par moments (la phase de l Ombre).
	"void_knight": ["void_knight_gold", "Chevalier du vide dore", 5.0, {
		"phase_interval": 4.5, "base_speed": 42.0}],
}


## Fabrique les boss dores a partir de leur monstre de base RELU SUR LE DISQUE
## (le cache de ContentDB date d avant cette generation : un monstre de base
## retouche par le chantier des monstres doit etre lu tel qu il vient d etre
## ecrit). Rend {id du boss dore -> EnemyDef}.
func _boss_dores() -> Dictionary:
	var out: Dictionary = {}
	var bases: Array = DORES.keys()
	bases.sort()
	for base_id: String in bases:
		var spec: Array = DORES[base_id]
		var base: EnemyDef = ResourceLoader.load(ENNEMIS + base_id + ".tres", "",
			ResourceLoader.CACHE_MODE_IGNORE) as EnemyDef
		if base == null:
			printerr("BOSS DORE : monstre de base introuvable : %s" % base_id)
			continue
		if base.anim_key in FEUILLES_SANS_TEINTE:
			printerr("BOSS DORE : %s porte la feuille %s, dont la licence interdit la teinte"
				% [base_id, base.anim_key])
			continue
		var g: EnemyDef = base.duplicate() as EnemyDef
		g.resource_path = ""
		g.id = StringName(spec[0])
		g.display_name = String(spec[1])
		g.kind = GameEnums.EnemyKind.BOSS
		g.power = DORE_PUISSANCE
		g.base_xp = DORE_XP
		g.max_hp = snappedf(base.max_hp * float(spec[2]), 1.0)
		g.base_radius = clampf(snappedf(base.base_radius * DORE_RAYON_FACTEUR, 1.0),
			DORE_RAYON_MIN, DORE_RAYON_MAX)
		g.color = COULEUR_DOREE
		g.resistances = base.resistances.duplicate()
		g.demoted_from = &""
		g.gilded_from = base.id
		var reglages: Dictionary = spec[3]
		for champ: String in reglages:
			var v: Variant = reglages[champ]
			if v is String and String(v).ends_with(".tres"):
				v = load(ENNEMIS + String(v))
			g.set(champ, v)
		var chemin: String = ENNEMIS + base_id + SUFFIXE_DORE + ".tres"
		_proprio.call("_save", g, chemin)
		# Le boss dore PREND le chemin de son fichier : sans cela les vagues qui
		# le citent l embarqueraient en COPIE (une ressource sans chemin est
		# ecrite dans le .tres qui la reference), et le monstre qui descend ne
		# serait plus celui du catalogue, du bestiaire et des tests. Vu au
		# sabotage : un boss dore affaibli dans son .tres restait entier en jeu.
		g.take_over_path(chemin)
		# Les objectifs des annexes nomment leur boss dore : ObjectiveChecker le
		# valide dans ContentDB, qui ne le connait pas encore a la premiere
		# generation. On l y inscrit pour ce processus seulement.
		ContentDB.enemies[g.id] = g
		out[g.id] = g
		_rapport.append("  boss dore %s (%s) : %d PV (base %s %d PV), rayon %d"
			% [g.id, g.display_name, int(g.max_hp), base_id, int(base.max_hp), int(g.base_radius)])
	return out


# =====================================================================
# LES HUIT QUETES
# =====================================================================

## LA TABLE DES QUETES. Une entree par quete :
##   id, nom, sous_titre, texte (briefing, tutoiement), acte, apres (niveau de
##   campagne qui l ouvre), perso (cle de l apprenti requis, "" sinon), fond,
##   dore (id du boss dore), communes (preferences du deck de base, dans
##   l ordre), rares / epiques / legendaires / passifs (preferences de
##   recompense), vagues, objectifs (3, du plus facile au plus dur ; le pourquoi
##   du classement et le taux mesure sont dans test_side_quests.MESURES).
## Une vague : [suffixe, duree, difficulte, "boss" | "", [[monstre, nombre,
## intervalle, decalage], ...]] ; le boss dore est la PREMIERE entree de la
## derniere vague (test_bosses lit la tete d une vague a cette place).
##
## LA DIFFICULTE EST MESUREE (cible du chantier : 40 a 70 % de victoires, plus
## dur que la campagne de l acte, qui vise 60 % et plus). Banc d equilibrage du
## 17/10, 60 parties, bot AutoPick, chaque annexe jouee juste apres son niveau
## d ouverture (SimBalance._inserer_annexes) : mesure 38, atelier 40, tresor 35,
## champion 36, vitrine 31, ecuyer 39, fee 39, apprentie 28 victoires sur 60.
## Reglees en sept passes : les difficultes de vague (multiplicateur de PV) et
## les effectifs, jamais les boss dores eux-memes. Ce qui a le plus bouge un
## taux : les PRETRES GOULES (soin de groupe : 25 % avec deux dans la vague 3 de
## l apprentie, 92 % avec un seul) et un deck de base tout en FEU contre des
## champignons qui le craignent (la fee gagnait 60 fois sur 60). Apres la
## fusion du chantier B2 (decks de base de la campagne, donc communes possedees
## a l ouverture), REJOUER : `tools/sim_balance.tscn -- --niveaux=side_... --parties=60
## --massacre=0`.
static func quetes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# --- ACTE 1 : LA MESURE ---------------------------------------------------
	# Le village petrifie (lvl_02) marchait au pas : « quelqu un leur bat la
	# mesure ». Les gnomes descendent en COLONNE (la Fleche percante les
	# enfile), le Corniste dore les presse et en appelle d autres. Acte 1 :
	# aucun passif (LevelDef.PASSIVES_FROM_ACT).
	out.append({
		"id": "side_a1_mesure", "nom": "La mesure", "acte": 1, "apres": "lvl_02", "perso": "",
		"sous_titre": "Celui qui bat la cadence",
		"texte": "Au village petrifie, les monstres marchaient au pas. Quelque part dans la foret de Nuri, quelqu un leur bat la mesure avec un cor. Trouve-le et fais-le taire : tant qu il joue, tout ce qui descend va plus vite.",
		"fond": "act1_sky", "dore": "hornblower_gold",
		"communes": ["piercing_arrow", "fireball", "ember_pool", "spark", "meteor", "arcane_bolt"],
		"rares": ["temporal_drag", "about_face", "brazier"],
		"epiques": ["weakness_mark", "reckless_bargain", "maelstrom"],
		"legendaires": ["hourglass_shard", "time_rift", "forge_dial"],
		"passifs": [],
		"vagues": [
			["1", 26.0, 1.1, "", [["gnome", 5, 1.8, 0.0], ["sprite", 3, 1.6, 7.0],
				["hornblower", 1, 1.0, 12.0], ["hopper", 3, 1.5, 16.0]]],
			["2", 28.0, 1.2, "", [["gnome", 5, 1.2, 0.0], ["jelly", 1, 1.0, 6.0],
				["imp_archer", 2, 3.0, 10.0], ["rat_swarm", 1, 1.0, 18.0], ["hornblower", 1, 1.0, 20.0]]],
			["3", 28.0, 1.2, "", [["gorgon_gazer", 1, 1.0, 0.0], ["hornblower", 1, 1.0, 4.0],
				["gnome", 5, 1.2, 8.0], ["hive", 1, 1.0, 14.0], ["sprite", 4, 1.4, 20.0]]],
			["boss", 45.0, 0.9, "boss", [["hornblower_gold", 1, 1.0, 0.0], ["gnome", 3, 2.5, 6.0],
				["hopper", 3, 2.0, 16.0], ["imp_archer", 1, 1.0, 20.0], ["sprite", 3, 1.5, 26.0]]],
		],
		"objectifs": [
			[&"no_hit_from", {"enemy": "hornblower_gold"}],
			[&"kill_type_one_cast", {"enemy": "hopper", "count": 3}],
			[&"win_above_speed", {"pct": 160}],
		],
	})
	# --- ACTE 2 : L ATELIER DU RAT ---------------------------------------------
	# Apres les courants (lvl_17), ou le rat avoue avoir travaille dans l atelier
	# des Sky Lands. Un totem de PORT, dore et retourne, protege tout ce qui
	# l approche : la Lumiere purifiante est au deck (DEC-057).
	out.append({
		"id": "side_a2_atelier", "nom": "L atelier du rat", "acte": 2, "apres": "lvl_17", "perso": "",
		"sous_titre": "Vingt ans d etabli, et une tour d or",
		"texte": "Le rat a travaille vingt ans dans un atelier des Sky Lands, sur l ile voisine. Ce qui garde la porte aujourd hui rend invulnerable tout ce qui l approche : eteins son aura a la Lumiere purifiante, abats le gardien, puis le reste.",
		"fond": "act1_sky", "dore": "totem_guardian_gold",
		"communes": [DISSIPATION, "arcane_bolt", "fireball", "meteor", "frost_rain", "piercing_arrow"],
		"rares": ["focus", "mana_flow", "time_surge"],
		"epiques": ["bastion", "arcane_insight", "resonance"],
		"legendaires": ["summoners_key", "world_loom", "twin_channeling"],
		"passifs": ["pass_chain", "pass_arcane_mind", "pass_arcane_lore", "pass_pulse", "pass_companion"],
		"vagues": [
			["1", 26.0, 1.3, "", [["wisp", 3, 1.6, 0.0], ["current_eye", 2, 2.0, 6.0],
				["sand_serpent", 2, 2.0, 12.0]]],
			["2", 27.0, 1.35, "", [["totem_guardian", 1, 1.0, 0.0], ["nacelle_raider", 3, 1.5, 4.0],
				["current_eye", 2, 2.0, 12.0]]],
			["3", 28.0, 1.45, "", [["sand_serpent", 3, 1.8, 0.0], ["imp_archer", 2, 3.0, 6.0],
				["wisp", 3, 1.5, 12.0], ["shade", 2, 2.0, 18.0]]],
			["boss", 46.0, 1.55, "boss", [["totem_guardian_gold", 1, 1.0, 0.0],
				["nacelle_raider", 3, 2.0, 4.0], ["current_eye", 3, 2.0, 12.0],
				["sand_serpent", 2, 2.5, 22.0]]],
		],
		"objectifs": [
			[&"kill_flying", {"count": 8}],
			[&"win_under_time", {"seconds": 130}],
			[&"win_above_speed", {"pct": 240}],
		],
	})
	# --- ACTE 3 : LE TRESOR DE TOMBOL ------------------------------------------
	# Apres la cour des rois morts (lvl_20) : un roi qui fuit ses creanciers vide
	# ses coffres. Il ne reste que la garde, doree, qui RENVOIE les coups : frapper
	# entre ses gardes est l objectif le plus dur (rang 3, mesure au banc).
	out.append({
		"id": "side_a3_tresor", "nom": "Le tresor de Tombol", "acte": 3, "apres": "lvl_20", "perso": "",
		"sous_titre": "Une salle vide et sa garde",
		"texte": "Un roi qui fuit ses creanciers vide ses coffres d abord. Sous la cour des rois morts, la salle du tresor de Tombol n a plus que sa garde : un squelette en armure d or qui renvoie les coups. Frappe entre ses gardes.",
		"fond": "act2_graveyard", "dore": "parry_skeleton_gold",
		"communes": ["fireball", "piercing_arrow", "meteor", "ember_pool", "arcane_bolt", "frost_rain"],
		"rares": ["brazier", "repulsion_wave", "terrain_brambles"],
		"epiques": ["deep_freeze", "void_grip", "terrain_pit"],
		"legendaires": ["forge_dial", "meteor_storm", "echo_of_the_hand"],
		"passifs": ["pass_overflow", "pass_fire_embers", "pass_fire_fury", "pass_fireboom"],
		"vagues": [
			["1", 26.0, 2.0, "", [["parry_skeleton", 3, 2.5, 0.0], ["pit_ghoul", 3, 2.0, 6.0],
				["shade", 2, 2.0, 12.0]]],
			["2", 28.0, 2.1, "", [["slime_ghost", 2, 2.0, 0.0], ["ghoul_priest", 2, 3.0, 5.0],
				["pit_ghoul", 2, 2.0, 10.0], ["parry_skeleton", 2, 3.0, 16.0]]],
			["3", 29.0, 2.2, "", [["void_knight", 2, 3.0, 0.0], ["hive", 1, 1.0, 6.0],
				["parry_skeleton", 3, 3.0, 10.0], ["pit_ghoul", 2, 2.0, 18.0], ["shade", 2, 2.0, 22.0]]],
			["boss", 46.0, 2.1, "boss", [["parry_skeleton_gold", 1, 1.0, 0.0],
				["pit_ghoul", 3, 2.0, 6.0], ["parry_skeleton", 2, 3.0, 14.0],
				["ghoul_priest", 1, 1.0, 20.0], ["shade", 3, 2.0, 24.0]]],
		],
		"objectifs": [
			[&"win_under_time", {"seconds": 150}],
			[&"multi_kill", {"count": 5, "window": 1}],
			[&"never_hit_reflect", {}],
		],
	})
	# --- ACTE 4 : LE CHAMPION DE KALTEK ----------------------------------------
	# Apres l arene (lvl_11) : Kaltek mort, son champion enchaine reste. Il
	# accelere a chaque coup et se releve une fois : peu de gros coups, du froid.
	out.append({
		"id": "side_a4_champion", "nom": "Le champion de Kaltek", "acte": 4, "apres": "lvl_11", "perso": "",
		"sous_titre": "L arene vide garde son meilleur combattant",
		"texte": "Kaltek est tombe, son arene est restee. Au centre, son champion en armure d or casse sa chaine. Il accelere a chaque coup recu et se releve une fois : frappe-le peu, mais fort, et ralentis-le.",
		"fond": "act3_demon", "dore": "berserker_gold",
		"communes": ["meteor", "frost_field", "fireball", "frost_rain", "arcane_bolt", "piercing_arrow"],
		"rares": ["ice_wall", "temporal_drag", "terrain_brambles"],
		"epiques": ["deep_freeze", "terrain_pit", "weakness_mark"],
		"legendaires": ["venom_mire", "meteor_storm", "forge_dial"],
		"passifs": ["pass_ice_bite", "pass_ice_winter", "pass_frostbite"],
		"vagues": [
			["1", 26.0, 1.6, "", [["berserker", 2, 3.0, 0.0], ["hopper", 3, 1.5, 6.0],
				["sprite", 3, 1.4, 14.0]]],
			["2", 28.0, 1.65, "", [["void_knight", 2, 3.0, 0.0], ["berserker", 2, 3.0, 8.0],
				["carnivore_plant", 2, 2.0, 16.0]]],
			["3", 30.0, 1.7, "", [["berserker", 3, 3.0, 0.0], ["mushroom", 2, 2.5, 8.0],
				["rat_swarm", 2, 1.5, 14.0], ["imp_archer", 1, 1.0, 20.0]]],
			["boss", 46.0, 1.65, "boss", [["berserker_gold", 1, 1.0, 0.0],
				["berserker", 2, 3.0, 10.0], ["sprite", 4, 1.5, 20.0]]],
		],
		"objectifs": [
			[&"kill_type_one_cast", {"enemy": "berserker", "count": 2}],
			[&"multi_kill", {"count": 4, "window": 1}],
			[&"win_above_speed", {"pct": 140}],
		],
	})
	# --- ACTE 5 : LA VITRINE DE NURI -------------------------------------------
	# Apres la galerie des saisons (lvl_14) : une aile entiere au nom de Nuri, et
	# une gorgone d or sur son socle. L enfant ne parle plus depuis le pentacle.
	out.append({
		"id": "side_a5_vitrine", "nom": "La vitrine de Nuri", "acte": 5, "apres": "lvl_14", "perso": "",
		"sous_titre": "Une aile de la galerie porte le nom de ton ile",
		"texte": "Dans la galerie des saisons, une aile entiere porte le nom de Nuri. Au centre, sous verre, une gorgone d or se reveille quand on approche : son regard fige deux de tes sorts tant qu elle vit, et la pierre encaisse ses premiers coups.",
		"fond": "act5_divine", "dore": "gorgon_gazer_gold",
		"communes": ["piercing_arrow", "chain_break", "frost_rain", "frost_field", "south_wind", "fireball"],
		"rares": ["repulsion_wave", "about_face", "focus"],
		"epiques": ["maelstrom", "weakness_mark", "deep_freeze"],
		"legendaires": ["time_rift", "twin_channeling", "hourglass_shard"],
		"passifs": ["pass_timelock", "pass_wind_tailwind", "pass_wind_gale", "pass_apotheosis"],
		"vagues": [
			["1", 27.0, 1.5, "", [["gnome", 6, 1.3, 0.0], ["sprite", 4, 1.4, 6.0],
				["sleepy_fox", 2, 3.0, 12.0], ["hopper", 3, 1.5, 18.0]]],
			["2", 29.0, 1.6, "", [["warden_echo", 2, 4.0, 0.0], ["gorgon_gazer", 1, 1.0, 6.0],
				["jelly", 2, 3.0, 12.0], ["hornblower", 1, 1.0, 18.0], ["imp_archer", 2, 3.0, 22.0]]],
			["3", 30.0, 1.45, "", [["blood_clot", 2, 3.0, 0.0], ["hive", 1, 1.0, 6.0],
				["gorgon_gazer", 1, 1.0, 12.0], ["rat_swarm", 2, 1.5, 16.0],
				["imp_archer", 2, 3.0, 20.0], ["warden_echo", 1, 1.0, 24.0]]],
			["boss", 48.0, 1.0, "boss", [["gorgon_gazer_gold", 1, 1.0, 0.0],
				["gnome", 5, 1.8, 6.0], ["hopper", 3, 2.0, 14.0], ["sleepy_fox", 1, 1.0, 24.0],
				["warden_echo", 1, 1.0, 28.0], ["sprite", 4, 1.5, 32.0]]],
		],
		"objectifs": [
			[&"hit_from", {"enemy": "sleepy_fox"}],
			[&"multi_kill", {"count": 6, "window": 1}],
			[&"win_above_speed", {"pct": 240}],
		],
	})
	# --- L ECUYER : HAUTE-NACELLE ----------------------------------------------
	# Apres le port vide (lvl_18) : le dernier garde du port tire depuis les toits.
	# En face, un archer d or qui tire plus vite et garde ses distances : un mur
	# arrete ses fleches (« tireur -> bloque-projectiles ») s il est au deck ou tire.
	out.append({
		"id": "side_squire", "nom": "L ecuyer du port", "acte": 2, "apres": "lvl_18",
		"perso": "soldier",
		"sous_titre": "Le dernier garde du port vide",
		"texte": "Dans le port vide de Haute-Nacelle, quelqu un tire encore depuis les toits : le dernier garde du port, qui a pose l epee pour l arc. En face de lui, un archer d or tire plus vite et ne s approche jamais : va le chercher avec tes sorts, ou abrite-toi derriere un mur si tu en tires un.",
		"fond": "act1_sky", "dore": "imp_archer_gold",
		"communes": ["frost_rain", "fireball", "stone_wall", "water_jet", "piercing_arrow", "frost_field", "arcane_bolt"],
		"rares": ["ice_wall", "heartwood_totem", "repulsion_wave"],
		"epiques": ["bastion", "mirror_apprentice", "weakness_mark"],
		"legendaires": ["tide_ledger", "terrain_river", "twin_channeling"],
		"passifs": ["pass_storm_reflex", "pass_water_spring", "pass_water_flood", "pass_quickhand", "pass_dual"],
		"vagues": [
			["1", 25.0, 1.4, "", [["nacelle_raider", 3, 2.0, 0.0], ["imp_archer", 1, 1.0, 8.0]]],
			["2", 27.0, 1.45, "", [["void_knight", 1, 1.0, 0.0], ["nacelle_raider", 2, 2.0, 4.0],
				["imp_archer", 2, 4.0, 10.0], ["shade", 1, 1.0, 18.0]]],
			["3", 28.0, 1.5, "", [["berserker", 1, 1.0, 0.0], ["imp_archer", 2, 4.0, 6.0],
				["nacelle_raider", 3, 2.0, 14.0]]],
			["boss", 46.0, 1.3, "boss", [["imp_archer_gold", 1, 1.0, 0.0],
				["nacelle_raider", 2, 2.5, 8.0], ["imp_archer", 1, 1.0, 16.0],
				["shade", 2, 2.0, 26.0]]],
		],
		"objectifs": [
			[&"kill_type_one_cast", {"enemy": "nacelle_raider", "count": 2}],
			[&"win_above_speed", {"pct": 140}],
			[&"multi_kill", {"count": 3, "window": 1}],
		],
	})
	# --- LA FEE : LES FOSSES NOYEES --------------------------------------------
	# Apres les fosses basses (lvl_19) : une fee qui ne se pose jamais au-dessus
	# d une eau qui « mange ». Le Champignon dore pousse sur les tombes noyees et
	# se fend en deux : une zone de feu sur sa chute les prend ensemble.
	out.append({
		"id": "side_fairy", "nom": "La fee des fosses", "acte": 3, "apres": "lvl_19",
		"perso": "fairy",
		"sous_titre": "Elle ne se pose jamais",
		"texte": "Au-dessus de l eau trouble des fosses basses, une fee voltige sans jamais se poser. Sous elle, un champignon d or pousse sur les tombes noyees, et il se fend en deux quand on l abat. Le feu le ronge mieux que tout.",
		"fond": "act2_graveyard", "dore": "mushroom_gold",
		"communes": ["fireball", "arcane_bolt", "frost_rain", "piercing_arrow", "ember_pool", "meteor"],
		"rares": ["brazier", "tidal_pool", "terrain_brambles"],
		"epiques": ["blight_sapling", "terrain_altar", "terrain_pit"],
		"legendaires": ["venom_mire", "summoners_key", "meteor_storm"],
		"passifs": ["pass_poison_corrode", "pass_nature_sap", "pass_nature_roots", "pass_poison_linger"],
		"vagues": [
			["1", 26.0, 2.15, "", [["pit_ghoul", 4, 1.5, 0.0], ["slime_ghost", 3, 2.0, 6.0],
				["mushroom", 2, 3.0, 12.0], ["shade", 2, 2.0, 18.0]]],
			["2", 27.0, 2.25, "", [["mushroom", 3, 2.5, 0.0], ["ghoul_priest", 2, 3.0, 5.0],
				["slime_skeleton", 3, 2.0, 10.0], ["pit_ghoul", 3, 1.5, 16.0]]],
			["3", 28.0, 2.35, "", [["slime_ghost_big", 2, 4.0, 0.0], ["mushroom", 3, 2.5, 6.0],
				["pit_ghoul", 4, 1.5, 12.0], ["carnivore_plant", 3, 2.0, 18.0],
				["shade", 2, 2.0, 22.0]]],
			["boss", 46.0, 2.2, "boss", [["mushroom_gold", 1, 1.0, 0.0],
				["pit_ghoul", 4, 1.5, 6.0], ["slime_ghost", 3, 2.0, 14.0],
				["ghoul_priest", 2, 3.0, 20.0], ["mushroom", 2, 3.0, 26.0], ["shade", 3, 2.0, 32.0]]],
		],
		"objectifs": [
			[&"element_casts", {"element": "FIRE", "count": 30}],
			[&"kill_type_one_cast", {"enemy": "mushroom", "count": 3}],
			[&"win_above_speed", {"pct": 260}],
		],
	})
	# --- L APPRENTIE D AZUR : LE CRISTAL D YMOA --------------------------------
	# Apres le temple d Ymoa (lvl_12) : ce que le cercle « protegeait » sans savoir
	# quoi. Sous un cristal bleu, l apprentie du mage de la PREMIERE boucle, morte
	# a Nox ; dans celle-ci elle ne le connait pas. Son gardien d or avale le
	# premier coup et disparait dans le vide : la foudre et le vent le percent.
	out.append({
		"id": "side_bluewitch", "nom": "L apprentie d azur", "acte": 4, "apres": "lvl_12",
		"perso": "bluewitch",
		"sous_titre": "Ce que le cercle protegeait sans savoir quoi",
		"texte": "Au fond du temple d Ymoa, sous un cristal bleu, dort une jeune sorciere que tu as deja connue, dans une autre boucle. Devant elle, un chevalier d or dont l armure avale le premier coup et qui disparait dans le vide.",
		"fond": "act3_demon", "dore": "void_knight_gold",
		"communes": ["spark", "electric_mark", "piercing_arrow", "chain_break", "frost_rain", "fireball", "arcane_bolt"],
		"rares": ["time_surge", "focus", "mana_flow"],
		"epiques": ["deep_focus", "thunder_root", "resonance", "arcane_insight"],
		"legendaires": ["echo_of_the_hand", "twin_channeling", "world_loom"],
		"passifs": ["pass_storm_surge", "pass_echo", "pass_scholar"],
		"vagues": [
			["1", 26.0, 1.3, "", [["void_knight", 1, 1.0, 0.0], ["shade", 3, 2.0, 4.0],
				["gnome", 3, 1.6, 12.0]]],
			["2", 28.0, 1.35, "", [["ghoul_priest", 2, 3.0, 0.0], ["void_knight", 2, 3.0, 6.0],
				["shade", 2, 2.0, 14.0]]],
			["3", 30.0, 1.4, "", [["golem", 1, 1.0, 0.0], ["void_knight", 2, 3.0, 6.0],
				["ghoul_priest", 2, 3.0, 12.0], ["shade", 2, 2.0, 18.0]]],
			["boss", 46.0, 1.1, "boss", [["void_knight_gold", 1, 1.0, 0.0],
				["shade", 3, 2.0, 8.0], ["void_knight", 1, 1.0, 18.0],
				["ghoul_priest", 1, 1.0, 26.0]]],
		],
		"objectifs": [
			[&"element_casts", {"element": "LIGHTNING", "count": 40}],
			[&"win_under_time", {"seconds": 140}],
			[&"no_hit_from", {"enemy": "void_knight_gold"}],
		],
	})
	return out


## Fabrique le niveau d une quete : vagues, deck de base, objectifs, scenes.
## Les recompenses sont posees ensuite, pour toutes les quetes ensemble
## (_distribuer).
func _niveau(q: Dictionary, dores: Dictionary) -> LevelDef:
	var lv := LevelDef.new()
	lv.id = StringName(q["id"])
	lv.display_name = String(q["nom"])
	lv.subtitle = String(q["sous_titre"])
	lv.intro_text = String(q["texte"])
	lv.act = int(q["acte"])
	lv.side_quest = true
	lv.side_quest_after = StringName(q["apres"])
	lv.side_quest_character = String(q["perso"])
	lv.terrain = "grass"
	lv.backdrop = String(q["fond"])
	lv.intro_story = StringName(String(q["id"]) + "_intro")
	lv.outro_story = StringName(String(q["id"]) + "_outro")
	lv.next_levels = []
	lv.levelup_cards = []
	lv.exploration_deck = []
	# Les vagues.
	var vagues: Array[WaveDef] = []
	var pool: Array[EnemyDef] = []
	for v: Array in q["vagues"]:
		var w := WaveDef.new()
		w.id = StringName("%s_%s" % [q["id"], v[0]])
		w.duration = float(v[1])
		w.difficulty = float(v[2])
		w.is_boss = String(v[3]) == "boss"
		var entrees: Array[WaveEntry] = []
		for e: Array in v[4]:
			var def: EnemyDef = dores.get(StringName(e[0]))
			if def == null:
				def = load(ENNEMIS + String(e[0]) + ".tres") as EnemyDef
			if def == null:
				printerr("QUETE %s : monstre introuvable %s" % [q["id"], e[0]])
				continue
			var we := WaveEntry.new()
			we.enemy = def
			we.count = int(e[1])
			we.spawn_delay = float(e[2])
			we.start_offset = float(e[3])
			entrees.append(we)
			if not def.is_boss() and not pool.has(def):
				pool.append(def)
		w.entries = entrees
		_proprio.call("_save", w, VAGUES + String(w.id) + ".tres")
		vagues.append(w)
	lv.waves = vagues
	lv.enemy_pool = pool
	# Les objectifs (identifiants deduits du controle, partages : make_content).
	var objectifs: Array[ObjectiveDef] = []
	for o: Array in q["objectifs"]:
		objectifs.append(_proprio.call("_objectif", o[0], o[1]) as ObjectiveDef)
	lv.objectives = objectifs
	# Le deck de base : trois communes possedees a l ouverture de la quete.
	var dore: EnemyDef = dores.get(StringName(q["dore"]))
	lv.base_commons = _communes_de(q, dore, _a_une_aura(vagues))
	# Le REPLI d avant la vague 10 (exploration_deck) porte le meme deck de
	# depart : un ecran ou un outil qui lirait encore ce champ montre ce que la
	# partie distribue (LevelDef.campaign_deck, aucun objectif reussi).
	lv.exploration_deck = lv.campaign_deck([])
	return lv


func _a_une_aura(vagues: Array[WaveDef]) -> bool:
	for w: WaveDef in vagues:
		for e: WaveEntry in w.entries:
			if e != null and e.enemy != null and e.enemy.aura_shield_radius > 0.0:
				return true
	return false


# =====================================================================
# LA CAMPAGNE RELUE, ET CE QU ELLE DONNE
# =====================================================================

## Les niveaux de CAMPAGNE tels que make_content vient de les ecrire, relus sur
## le disque (CACHE_MODE_IGNORE : ContentDB les a charges au demarrage, avant
## cette generation), dans l ORDRE DE JEU : parcours en largeur des
## next_levels depuis les niveaux que rien n ouvre (la regle de
## SimBalance._levels et de test_level_progression.ordre_de_jeu).
func _lire_campagne() -> Array[LevelDef]:
	var tous: Dictionary = {}
	var dir := DirAccess.open(NIVEAUX)
	if dir == null:
		return []
	for f: String in dir.get_files():
		if not f.ends_with(".tres") or f.begins_with(PREFIXE):
			continue
		var lv: LevelDef = ResourceLoader.load(NIVEAUX + f, "",
			ResourceLoader.CACHE_MODE_IGNORE) as LevelDef
		if lv != null and lv.is_campaign_level():
			tous[lv.id] = lv
	var pointes: Dictionary = {}
	for id in tous:
		for s in (tous[id] as LevelDef).next_levels:
			pointes[StringName(s)] = true
	var departs: Array = []
	for id in tous:
		if not pointes.has(id):
			departs.append(id)
	departs.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var out: Array[LevelDef] = []
	var vus: Dictionary = {}
	var file: Array = departs.duplicate()
	while not file.is_empty():
		var id: StringName = StringName(file.pop_front())
		if vus.has(id) or not tous.has(id):
			continue
		vus[id] = true
		out.append(tous[id])
		for s in (tous[id] as LevelDef).next_levels:
			if not vus.has(StringName(s)):
				file.append(StringName(s))
	var reste: Array = []
	for id in tous:
		if not vus.has(id):
			reste.append(id)
	reste.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in reste:
		out.append(tous[id])
	return out


## Les niveaux de campagne joues jusqu a `apres` INCLUS, dans l ordre de jeu.
func _jusqu_a(apres: StringName) -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for lv: LevelDef in _campagne:
		out.append(lv)
		if lv.id == apres:
			return out
	printerr("QUETE ANNEXE : le niveau d ouverture %s n est pas un niveau de campagne" % apres)
	return out


## Les SORTS qu un niveau de campagne donne au livre, toutes routes : son deck
## de base (regle du livre), les recompenses de ses objectifs, et ses cartes
## nouvelles tant qu il est au format d avant la vague 10 (repli : elles
## restent alors au pool de montee de niveau, RunState.levelup_pool_to_obtain).
static func sorts_donnes_par(lv: LevelDef) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	var listes: Array = [lv.campaign_base_cards(), lv.objective_rewards]
	if not lv.has_base_commons():
		listes.append(lv.levelup_cards)
	for liste: Array in listes:
		for c in liste:
			var carte: SpellCard = c as SpellCard
			if carte != null and not carte.is_passive and not out.has(carte):
				out.append(carte)
	return out


## Les ids des sorts donnes par TOUTE la campagne.
func _sorts_de_la_campagne() -> Dictionary:
	var out: Dictionary = {}
	for lv: LevelDef in _campagne:
		for c: SpellCard in sorts_donnes_par(lv):
			out[String(c.id)] = true
	return out


## Les ids des cartes POSSEDEES par les decks de base des niveaux joues jusqu a
## `apres` (regle du livre : le deck d un niveau ouvert est obtenu).
func _possedees_a(apres: StringName) -> Dictionary:
	var out: Dictionary = {}
	for lv: LevelDef in _jusqu_a(apres):
		for c: SpellCard in lv.campaign_base_cards():
			if c != null:
				out[String(c.id)] = true
	return out


## La campagne ecrit-elle des passifs debloquables ? Sinon (contenu d avant la
## vague 10), les annexes n en ecrivent pas : voir l en-tete.
func _campagne_ecrit_des_passifs() -> bool:
	for lv: LevelDef in _campagne:
		if not lv.passive_unlocks.is_empty():
			return true
	return false


## Les ids des passifs que la base ou la campagne debloquent.
func _passifs_de_la_campagne() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in GameConfig.BASE_PASSIVES:
		out[String(id)] = true
	for lv: LevelDef in _campagne:
		for p in lv.passive_unlocks:
			if p != null:
				out[String((p as SpellCard).id)] = true
	return out


## Les cartes d un dossier de rarete (ou des passifs), relues sur le disque et
## triees par id. Les cartes ne viennent pas de ContentDB : un chantier de cartes
## qui en ajoute dans la meme generation doit etre vu.
static func catalogue(dossier: String) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	var dir := DirAccess.open(CARTES + dossier)
	if dir == null:
		return out
	var fichiers: Array = Array(dir.get_files())
	fichiers.sort()
	for f: String in fichiers:
		if not f.ends_with(".tres"):
			continue
		var c: SpellCard = load(CARTES + dossier + "/" + f) as SpellCard
		if c != null:
			out.append(c)
	return out


# =====================================================================
# LE DECK DE BASE D UNE QUETE
# =====================================================================

## Trois communes DISTINCTES, prises dans l ordre de preference de la quete parmi
## celles que les decks de base de la campagne ont deja donnees a l ouverture,
## puis (repli) parmi toutes les communes possedees a ce moment, celles qui
## blessent le boss d abord. La premiere doit pouvoir TUER le boss dore (« jamais
## un deck sans degats ») ; une quete a porteur d aura prend la dissipation.
func _communes_de(q: Dictionary, dore: EnemyDef, aura: bool) -> Array[SpellCard]:
	var possedees: Dictionary = _possedees_a(StringName(q["apres"]))
	var choix: Array[SpellCard] = []
	if aura:
		var d: SpellCard = _carte_commune(DISSIPATION)
		if d != null:
			choix.append(d)
	var candidates: Array[SpellCard] = []
	for id: String in q["communes"]:
		var c: SpellCard = _carte_commune(id)
		if c != null and possedees.has(id):
			candidates.append(c)
	var repli: Array[SpellCard] = []
	for c: SpellCard in catalogue("common"):
		if possedees.has(String(c.id)) and not candidates.has(c):
			repli.append(c)
	# Repli : celles qui blessent le boss le mieux d abord.
	repli.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		var fa: float = dore.resistance_to_tags(a.combat_tags()) if dore != null else 1.0
		var fb: float = dore.resistance_to_tags(b.combat_tags()) if dore != null else 1.0
		if not is_equal_approx(fa, fb):
			return fa > fb
		return String(a.id) < String(b.id))
	candidates.append_array(repli)
	# D abord une commune qui TUE le boss, puis les autres dans l ordre.
	var tueuse: bool = false
	for c: SpellCard in choix:
		tueuse = tueuse or ObjectiveChecker.card_can_kill(c, dore)
	if not tueuse:
		for c: SpellCard in candidates:
			if ObjectiveChecker.card_can_kill(c, dore) and not choix.has(c):
				choix.append(c)
				break
	for c: SpellCard in candidates:
		if choix.size() >= LevelDef.BASE_COMMONS_COUNT:
			break
		if not choix.has(c):
			choix.append(c)
	if choix.size() < LevelDef.BASE_COMMONS_COUNT:
		printerr("QUETE %s : %d communes possedees a l ouverture, %d attendues"
			% [q["id"], choix.size(), LevelDef.BASE_COMMONS_COUNT])
	# La premiere est la commune « nouvelle » de la table du co-auteur (celle qui
	# garde 3 ou 4 exemplaires) : on y met la preference de la quete.
	var ids: Array = []
	for c: SpellCard in choix:
		ids.append(String(c.id))
	_rapport.append("  %s : deck de base %s" % [q["id"], ids])
	return choix


func _carte_commune(id: String) -> SpellCard:
	var chemin: String = CARTES + "common/" + id + ".tres"
	if not ResourceLoader.exists(chemin):
		return null
	return load(chemin) as SpellCard


# =====================================================================
# LA DISTRIBUTION DES RECOMPENSES
# =====================================================================

## Pose sur chaque quete ses trois recompenses d objectif (rare, epique,
## legendaire : LevelDef.REWARD_RARITY_BY_RANK) et ses passifs, en donnant
## d ABORD le surplus de la campagne. Voir l en-tete.
func _distribuer(niveaux: Array[LevelDef]) -> void:
	var tables: Array[Dictionary] = quetes()
	var donnes: Dictionary = _sorts_de_la_campagne()
	var rangs: Array[Dictionary] = []
	for lv: LevelDef in niveaux:
		rangs.append({})
	for rang in LevelDef.REWARD_RARITY_BY_RANK.size():
		var rarete: int = LevelDef.REWARD_RARITY_BY_RANK[rang]
		var cle: String = ["rares", "epiques", "legendaires"][rang]
		var catalogue_r: Array[SpellCard] = catalogue(String(DOSSIERS[rarete]))
		var par_id: Dictionary = {}
		for c: SpellCard in catalogue_r:
			par_id[String(c.id)] = c
		var surplus: Array[String] = []
		for c: SpellCard in catalogue_r:
			if not donnes.has(String(c.id)) and not c.is_passive:
				surplus.append(String(c.id))
		var pris: Dictionary = {}
		var choix: Dictionary = {}   # index de quete -> id
		# 1. Le surplus, par preference.
		for i in niveaux.size():
			for id: String in tables[i][cle]:
				if id in surplus and not pris.has(id) and _admise(niveaux[i], par_id.get(id)):
					choix[i] = id
					pris[id] = true
					break
		# 2. Le surplus restant, aux quetes qui n ont rien (repli automatique).
		for id: String in surplus:
			if pris.has(id):
				continue
			for i in niveaux.size():
				if not choix.has(i) and _admise(niveaux[i], par_id.get(id)):
					choix[i] = id
					pris[id] = true
					break
		for id: String in surplus:
			if not pris.has(id):
				printerr("SURPLUS NON PLACE : %s (%s), aucune quete libre"
					% [id, GameEnums.rarity_name(rarete)])
				_rapport.append("  SURPLUS NON PLACE : %s" % id)
		# 3. Une REPRISE pour les cases encore vides : une carte que la campagne
		#    donne AVANT l ouverture, qu aucun deck ouvert ne possede deja.
		for i in niveaux.size():
			if choix.has(i):
				continue
			var reprise: String = _reprise(niveaux[i], tables[i], cle, catalogue_r,
				StringName(tables[i]["apres"]), pris)
			if reprise != "":
				choix[i] = reprise
				pris[reprise] = true
		for i in niveaux.size():
			rangs[i][rang] = choix.get(i, "")
		_rapport.append("  %s : surplus %s" % [cle, surplus])
	for i in niveaux.size():
		var lv: LevelDef = niveaux[i]
		var recompenses: Array[SpellCard] = []
		var ids: Array = []
		for rang in LevelDef.REWARD_RARITY_BY_RANK.size():
			var id: String = String(rangs[i][rang])
			var c: SpellCard = _carte(id) if id != "" else null
			recompenses.append(c)
			ids.append(id if id != "" else "-")
		lv.objective_rewards = recompenses
		_rapport.append("  %s : recompenses %s" % [lv.id, ids])
	_distribuer_passifs(niveaux, tables)


## Une reprise pour la case `cle` d une quete : d abord ses preferences, puis le
## catalogue trie. Rend "" si la campagne n a rien propose de cette rarete
## avant l ouverture.
func _reprise(quete: LevelDef, q: Dictionary, cle: String, catalogue_r: Array[SpellCard],
		apres: StringName, pris: Dictionary) -> String:
	var possedees: Dictionary = _possedees_a(apres)
	var avant: Dictionary = {}
	for lv: LevelDef in _jusqu_a(apres):
		for c: SpellCard in sorts_donnes_par(lv):
			avant[String(c.id)] = true
	var par_id: Dictionary = {}
	for c: SpellCard in catalogue_r:
		par_id[String(c.id)] = c
	var ordre: Array[String] = []
	for id: String in q[cle]:
		ordre.append(id)
	for c: SpellCard in catalogue_r:
		if not ordre.has(String(c.id)):
			ordre.append(String(c.id))
	for passe in 2:
		for id: String in ordre:
			if not avant.has(id) or possedees.has(id) or not _admise(quete, par_id.get(id)):
				continue
			# Premiere passe : une carte qu aucune autre quete n a prise.
			if passe == 0 and pris.has(id):
				continue
			return id
	return ""


## Les passifs : le surplus seulement (rien a reprendre, la base et la campagne
## les debloquent deja), au plus LevelDef.MAX_PASSIVE_UNLOCKS par quete, et
## jamais en acte 1. Une preference par quete et par tour, pour que chaque quete
## ait d abord le sien.
func _distribuer_passifs(niveaux: Array[LevelDef], tables: Array[Dictionary]) -> void:
	if not _campagne_ecrit_des_passifs():
		_rapport.append("  passifs : la campagne n en debloque aucun (format d avant la vague 10),"
			+ " les annexes non plus (repli : tous proposes des l acte 2)")
		return
	var debloques: Dictionary = _passifs_de_la_campagne()
	var surplus: Array[String] = []
	for c: SpellCard in catalogue("passive"):
		if c.is_passive and not debloques.has(String(c.id)):
			surplus.append(String(c.id))
	var pris: Dictionary = {}
	var par_quete: Array = []
	for lv: LevelDef in niveaux:
		par_quete.append([])
	for tour in LevelDef.MAX_PASSIVE_UNLOCKS:
		# Preferences d abord, une par quete et par tour.
		for i in niveaux.size():
			if not niveaux[i].allows_passives() or (par_quete[i] as Array).size() > tour:
				continue
			for id: String in tables[i]["passifs"]:
				if id in surplus and not pris.has(id):
					(par_quete[i] as Array).append(id)
					pris[id] = true
					break
		# Repli : le surplus restant, a qui n a pas encore son passif de ce tour.
		for i in niveaux.size():
			if not niveaux[i].allows_passives() or (par_quete[i] as Array).size() > tour:
				continue
			for id: String in surplus:
				if not pris.has(id):
					(par_quete[i] as Array).append(id)
					pris[id] = true
					break
	for id: String in surplus:
		if not pris.has(id):
			printerr("SURPLUS NON PLACE : passif %s, toutes les quetes d acte 2 ou plus en ont deja %d"
				% [id, LevelDef.MAX_PASSIVE_UNLOCKS])
			_rapport.append("  SURPLUS NON PLACE : passif %s" % id)
	for i in niveaux.size():
		var liste: Array[SpellCard] = []
		for id in par_quete[i]:
			var c: SpellCard = load(CARTES + "passive/" + id + ".tres") as SpellCard
			if c != null:
				liste.append(c)
		niveaux[i].passive_unlocks = liste
		_rapport.append("  %s : passifs %s" % [niveaux[i].id, par_quete[i]])
	_rapport.append("  passifs : surplus %s" % [surplus])


## Une recompense est-elle admise dans cette quete ? Pas un objet PERMANENT qui
## tue dans une quete qui demande « N monstres d un seul sort » : un tel objet
## est UN lancer pour toute la partie (ObjectiveChecker, section LANCER), ses
## morts s additionnent et l objectif deviendrait gratuit des que la carte entre
## au deck (meme regle que test_level_progression pour la campagne).
static func _admise(quete: LevelDef, c: SpellCard) -> bool:
	if c == null:
		return false
	for o: ObjectiveDef in quete.objectives:
		if o != null and o.check_key == &"kill_type_one_cast" and pose_un_tueur_permanent(c):
			return false
	return true


## La carte pose-t-elle un objet PERMANENT qui tue (ronces, arbre empoisonne,
## autel qui fait naitre des allies) ? La definition de test_level_progression.
static func pose_un_tueur_permanent(c: SpellCard) -> bool:
	if c == null:
		return false
	for spec: EffectSpec in c.effects:
		if spec == null or spec.duration > 0.0:
			continue
		if not spec.key in [&"place_terrain", &"taunt_prop"]:
			continue
		if spec.magnitude > 0.0:
			return true
		if float(spec.get_param(&"summon_every", 0.0)) > 0.0 \
				and float(spec.get_param(&"ally_damage", 0.0)) > 0.0:
			return true
	return false


func _carte(id: String) -> SpellCard:
	for dossier in ["common", "rare", "epic", "legendary"]:
		var chemin: String = "%s%s/%s.tres" % [CARTES, dossier, id]
		if ResourceLoader.exists(chemin):
			return load(chemin) as SpellCard
	printerr("QUETE ANNEXE : carte inconnue %s" % id)
	return null


# =====================================================================
# LA PURGE
# =====================================================================

## Les fichiers des annexes sont PURGES puis regeneres, comme les objectifs : une
## quete ou un boss dore retire de la table ne doit pas survivre en .tres
## orphelin que ContentDB continuerait d indexer.
func _purger() -> void:
	for spec: Array in [[NIVEAUX, PREFIXE, ""], [VAGUES, PREFIXE, ""],
			[ENNEMIS, "", SUFFIXE_DORE + ".tres"]]:
		var dir := DirAccess.open(String(spec[0]))
		if dir == null:
			continue
		for f: String in dir.get_files():
			if not f.ends_with(".tres"):
				continue
			if String(spec[1]) != "" and not f.begins_with(String(spec[1])):
				continue
			if String(spec[2]) != "" and not f.ends_with(String(spec[2])):
				continue
			dir.remove(f)

extends Node
## Index de tout le contenu .tres. Source de verite unique pour l'etage AUDIT.

signal content_loaded()

var cards: Dictionary = {}       # StringName -> SpellCard
var enemies: Dictionary = {}     # StringName -> EnemyDef
var waves: Dictionary = {}       # StringName -> WaveDef
var levels: Dictionary = {}      # StringName -> LevelDef
var objectives: Dictionary = {}  # StringName -> ObjectiveDef
var challenges: Dictionary = {}  # StringName -> ChallengeDef
var rewards: Dictionary = {}     # StringName -> AccountRewardDef

## Ids rencontres deux fois — l'AUDIT echoue dessus (ecrasement silencieux sinon).
var duplicate_ids: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	cards.clear()
	enemies.clear()
	waves.clear()
	levels.clear()
	objectives.clear()
	challenges.clear()
	rewards.clear()
	duplicate_ids.clear()
	_scan_dir("res://resources")
	# OUTILS DU TESTEUR (vague 8) : le calque de surcharges est rejoue ICI, et
	# seulement ici, sur les objets fraichement indexes. Il ne fait rien hors
	# mode testeur. Avant l emission : un ecouteur doit voir le contenu regle.
	TesterOverrides.after_content_load()
	# Plus de "communes de depart" ecrites dans le profil (discover_starters a
	# ete SUPPRIMEE, le 01/10) : le livre d un profil neuf est le deck du premier
	# niveau, et SaveData le DEDUIT des niveaux ouverts (LE LIVRE DE SORTS). La
	# fonction est retiree plutot que videe : un appelant oublie casse a la
	# compilation au lieu de croire qu il donne encore des cartes.
	content_loaded.emit()


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full)
		elif entry.ends_with(".tres"):
			_index(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _index(path: String) -> void:
	var res: Resource = load(path)
	if res == null:
		push_error("Ressource illisible : %s" % path)
		return
	if res is SpellCard:
		_put(cards, (res as SpellCard).id, res, path)
	elif res is EnemyDef:
		_put(enemies, (res as EnemyDef).id, res, path)
	elif res is WaveDef:
		_put(waves, (res as WaveDef).id, res, path)
	elif res is LevelDef:
		_put(levels, (res as LevelDef).id, res, path)
	elif res is ObjectiveDef:
		_put(objectives, (res as ObjectiveDef).id, res, path)
	elif res is ChallengeDef:
		_put(challenges, (res as ChallengeDef).id, res, path)
	elif res is AccountRewardDef:
		_put(rewards, (res as AccountRewardDef).id, res, path)


func _put(target: Dictionary, id: StringName, res: Resource, path: String) -> void:
	if id == &"":
		push_error("Ressource sans id : %s" % path)
		return
	if target.has(id):
		duplicate_ids.append("%s (%s)" % [id, path])
		return
	target[id] = res


func cards_of_rarity(rarity: GameEnums.Rarity) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in cards.values():
		if c.rarity == rarity:
			out.append(c)
	return out


## Defis tries par XP croissant : les plus accessibles en premier.
func challenges_list() -> Array[ChallengeDef]:
	var out: Array[ChallengeDef] = []
	for c: ChallengeDef in challenges.values():
		out.append(c)
	out.sort_custom(func(a: ChallengeDef, b: ChallengeDef) -> bool:
		return a.xp_reward < b.xp_reward if a.xp_reward != b.xp_reward else a.id < b.id)
	return out


# =====================================================================
# CHANTIER A3 (vague 10) — campagne, actes, quetes annexes, passifs.
# Lectures PURES du contenu : aucune ne lit le profil.
# =====================================================================

## Les niveaux du fil de la CAMPAGNE (un acte, pas une annexe), tries par id.
## Tri sur String : le tri de StringName n est pas fiable en 4.4 (gotchas).
func campaign_levels() -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for lv: LevelDef in levels.values():
		if lv != null and lv.is_campaign_level():
			out.append(lv)
	out.sort_custom(func(a: LevelDef, b: LevelDef) -> bool: return String(a.id) < String(b.id))
	return out


## Les QUETES ANNEXES, triees par acte de rattachement puis par id : c est
## l ordre de la page « Quetes annexes » de la carte.
func side_quests() -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for lv: LevelDef in levels.values():
		if lv != null and lv.side_quest:
			out.append(lv)
	out.sort_custom(func(a: LevelDef, b: LevelDef) -> bool:
		if a.act != b.act:
			return a.act < b.act
		return String(a.id) < String(b.id))
	return out


## LES COMMUNES DE L ACTE : « toutes les communes de l acte sont disponibles des
## le niveau 1 » (co-auteur, 14/10). Union, sans doublon et triee par id, des
## base_commons des niveaux de CAMPAGNE de cet acte (les annexes n en
## fournissent pas : leur acte est un rattachement).
##
## REPLI tant que le contenu de la vague 10 n existe pas (aucun niveau de l acte
## n a de deck de base) : les COMMUNES que portent les decks d exploration et les
## cartes nouvelles des niveaux de campagne de l acte. Meme intention — les
## communes que l acte fait jouer — lue dans le seul contenu qui existe.
func act_commons(act: int) -> Array[SpellCard]:
	var vues: Dictionary = {}
	var nouveau: bool = false
	for lv: LevelDef in campaign_levels():
		if lv.act == act and lv.has_base_commons():
			nouveau = true
	for lv2: LevelDef in campaign_levels():
		if lv2.act != act:
			continue
		var sources: Array = []
		if nouveau:
			sources.append(lv2.base_commons)
		else:
			sources.append(lv2.exploration_deck)
			sources.append(lv2.levelup_cards)
		for liste: Array in sources:
			for c in liste:
				var carte: SpellCard = c as SpellCard
				if carte != null and not carte.is_passive \
						and carte.rarity == GameEnums.Rarity.COMMON:
					vues[String(carte.id)] = carte
	var ids: Array = vues.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var out: Array[SpellCard] = []
	for id in ids:
		out.append(vues[id])
	return out


## Le contenu ecrit-il deja les PASSIFS DEBLOQUABLES (LevelDef.passive_unlocks) ?
## Faux = contenu d avant la vague 10 : tous les passifs restent proposables des
## l acte 2, comme avant (voir RunState.levelup_pool et SaveData.passive_unlocked).
func passive_unlocks_authored() -> bool:
	for lv: LevelDef in levels.values():
		if lv != null and not lv.passive_unlocks.is_empty():
			return true
	return false


## Les passifs de base (GameConfig.BASE_PASSIVES) qui existent au catalogue.
func base_passives() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for id: StringName in GameConfig.BASE_PASSIVES:
		var c: SpellCard = cards.get(id)
		if c != null and c.is_passive:
			out.append(c)
	return out


## Recompenses triees par niveau : c est l ordre ou le joueur les obtiendra.
func rewards_list() -> Array[AccountRewardDef]:
	var out: Array[AccountRewardDef] = []
	for r: AccountRewardDef in rewards.values():
		out.append(r)
	out.sort_custom(func(a: AccountRewardDef, b: AccountRewardDef) -> bool:
		return a.at_level < b.at_level if a.at_level != b.at_level else a.id < b.id)
	return out

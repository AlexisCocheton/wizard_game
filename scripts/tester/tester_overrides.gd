class_name TesterOverrides
extends RefCounted
## LES SURCHARGES DU TESTEUR — reglages du contenu faits depuis le telephone.
##
## Demande du co-auteur (vague 8) : "modifier les visuels, les statistiques, les
## resistances et toutes les valeurs de zone, duree, etc. pour ajuster les cartes
## et les monstres", "modifier le contenu et la difficulte des vagues de la
## campagne", puis "telecharger un document de changement" a nous transmettre.
##
## LE MODELE. Une surcharge = { cible, champ, valeur } :
##   cible  "card:<id>", "enemy:<id>", "level:<id>", "objective:<id>"
##   champ  un chemin dans la Resource, segments separes par "/" :
##            "max_hp"                    propriete exportee
##            "resistances/feu"           cle d un dictionnaire (element en clair)
##            "effects/0/radius"          champ d un EffectSpec de la carte
##            "effects/0/params/slow_pct" parametre libre d un EffectSpec
##            "params/seconds"            parametre d un objectif
##            "waves/2"                   une vague de campagne ENTIERE
##            "waves/#"                   le NOMBRE de vagues du niveau
##   valeur la valeur ENCODEE en JSON : nombres, booleens, textes ; un enum par
##          son nom ("Rare"), une couleur en "#rrggbbaa", un monstre / une carte
##          / un objectif par son id, une liste par une liste.
##
## POURQUOI UN CALQUE ET NON UNE ECRITURE DANS LES .tres. Les .tres sont generes
## par tools/make_content.gd : une modification ecrite ailleurs serait ECRASEE a
## la prochaine generation, et le telephone ne peut de toute facon pas ecrire
## dans res://. Le calque vit dans user://, il est rejoue apres chaque
## chargement de ContentDB, et le document de changement est le pont vers la
## seule source de verite (make_content.gd), voir docs/outil_donnees.md.
##
## POURQUOI ON MODIFIE LES RESOURCES SUR PLACE. Elles sont PARTAGEES (cache de
## Godot) : Enemy lit def.max_hp a l apparition, le sort lit ses EffectSpec au
## lancer. Modifier l objet suffit donc a ce que toute la partie voie la valeur,
## sans une seule accroche dans le code de jeu. Le revers : il faut savoir
## REVENIR exactement, d ou `_undo`, qui garde l ancienne valeur ET l objet
## modifie (et donc le garde en vie : le cache rend le meme objet au prochain
## load(), c est ce qui rend le retour fiable meme apres un ContentDB.reload()).
##
## ACTIF SEULEMENT EN MODE TESTEUR. Eteindre le mode rend le jeu d origine
## IMMEDIATEMENT, sans redemarrer : `sync()` est branche sur
## SaveData.profile_changed, que set_tester_mode() et reset_profile() emettent
## tous les deux. Les surcharges restent enregistrees : rallumer les rejoue.
##
## JAMAIS DE PLANTAGE. Une surcharge invalide (cible disparue apres une mise a
## jour, valeur hors bornes, id inconnu) est ECARTEE et signalee dans
## `rejected()`, jamais appliquee a moitie. On n emet ni push_error ni
## SCRIPT ERROR : une saisie du testeur n est pas un defaut du jeu.

const STORE_PATH: String = "user://tester_overrides.json"
const DOC_DIR: String = "user://changements"

## Signature du document : l outil de chez nous (tools/apply_changes.py) refuse
## un JSON qui ne la porte pas, pour ne pas appliquer un fichier quelconque.
const FORMAT: String = "time_wizard_changements"
const FORMAT_VERSION: int = 1

## Prefixe de cible -> dictionnaire de ContentDB.
const TARGET_KINDS: Dictionary = {
	"card": "cards", "enemy": "enemies", "level": "levels", "objective": "objectives",
}

## Classe de Resource -> prefixe de cible. Sert a encoder une reference par id.
const REF_CLASSES: Dictionary = {
	"EnemyDef": "enemy", "SpellCard": "card", "ObjectiveDef": "objective",
}

## Champs JAMAIS editables. `id` : changer l id casserait l index de ContentDB
## et toutes les references. Les textures ne passent pas dans un JSON.
## `immune_tags` est deprecie (voir enemy_def.gd), `is_passive` change la NATURE
## de la carte (deck ou emplacement), `check_key` celle de l objectif : ce sont
## des decisions de conception, pas des reglages.
const SKIP_FIELDS: Array[String] = [
	"id", "icon", "sprite", "immune_tags", "is_passive", "check_key",
]

## Elements dans l ordre d affichage, par leur nom joueur : c est ce nom qui
## apparait dans le champ ("resistances/feu"), lisible dans le document.
const RESIST_TAGS: Array[int] = [
	GameEnums.DamageTag.PHYSICAL, GameEnums.DamageTag.FIRE, GameEnums.DamageTag.FROST,
	GameEnums.DamageTag.ARCANE, GameEnums.DamageTag.POISON, GameEnums.DamageTag.LIGHTNING,
	GameEnums.DamageTag.SLOW,
]

## BORNES RAISONNABLES par nom de champ : [min, max]. Une borne n est pas une
## regle d equilibrage, c est un garde-fou contre la faute de frappe (un 0 de
## trop sur des PV, une incantation a 0 s qui ferait boucler la main). Les
## `@export_range` des Resources priment quand ils existent.
const BOUNDS: Dictionary = {
	"max_hp": [1.0, 100000.0],
	"base_speed": [0.0, 2000.0],
	"base_xp": [0.0, 10000.0],
	"contact_damage": [0.0, 400.0],
	"sprite_scale": [0.1, 10.0],
	"base_radius": [4.0, 400.0],
	"dodge_chance": [0.0, 1.0],
	"swarm_count": [1.0, 50.0],
	"base_cast_time": [0.05, 60.0],
	"copies_in_starter": [0.0, 10.0],
	"speed_threshold": [100.0, 500.0],
	"magnitude": [0.0, 100000.0],
	"duration": [0.0, 600.0],
	"radius": [0.0, 2000.0],
	"resistances": [0.0, 5.0],
	"difficulty": [0.05, 20.0],
	"count": [1.0, 200.0],
	"spawn_delay": [0.0, 60.0],
	"start_offset": [0.0, 600.0],
	"wave_duration": [1.0, 600.0],
	"wave_count": [1.0, 30.0],
	"act": [0.0, 9.0],
}
const DEFAULT_BOUNDS: Array = [0.0, 100000.0]
## Les parametres libres (EffectSpec.params, ObjectiveDef.params) n ont pas de
## schema commun : on ne refuse que l absurde.
const PARAM_BOUNDS: Array = [-100000.0, 100000.0]
const MAX_TEXT: int = 4000
const MAX_LIST: int = 60

## Libelles en clair pour l ecran et le document. Un champ absent garde son nom
## de code : c est celui que l outil cherche dans make_content.gd.
const LABELS: Dictionary = {
	"display_name": "nom", "description": "description", "rarity": "rarete",
	"base_cast_time": "incantation (s)", "targeting": "ciblage", "tags": "elements / tags",
	"copies_in_starter": "exemplaires de depart", "exile_after_cast": "exilee apres usage",
	"speed_threshold": "seuil de vitesse (%)", "fx_key": "effet visuel", "sfx_key": "son",
	"kind": "famille", "power": "puissance", "max_hp": "PV", "base_speed": "vitesse",
	"base_xp": "XP", "contact_damage": "degats au contact", "anim_key": "apparence",
	"sprite_scale": "echelle", "shape": "forme de secours", "color": "teinte",
	"base_radius": "rayon", "dodge_chance": "esquive", "swarm_count": "taille de nuee",
	"flying": "volant", "magnitude": "magnitude", "duration": "duree (s)", "radius": "rayon",
	"key": "verbe", "act": "acte", "subtitle": "sous-titre", "backdrop": "fond",
	"exploration_deck": "deck du niveau", "levelup_cards": "cartes nouvelles",
	"objectives": "objectifs", "objective_rewards": "cartes des objectifs",
	"enemy_pool": "monstres du mode infini", "next_levels": "niveaux suivants",
}

static var _entries: Array = []          # [{target, field, value}]
static var _undo: Array = []             # [[Object, String, Variant]] dans l ordre
static var _originals: Dictionary = {}   # "target|field" -> valeur encodee d origine
static var _rejected: Array = []         # [{target, field, value, reason}]
static var _active: bool = false
static var _loaded: bool = false
static var _plists: Dictionary = {}      # chemin de script -> Array de proprietes
## Faux en test : rien n est ecrit dans user://. Recopie SaveData.persistence_enabled
## au premier chargement (aucune persistance en headless, DEC-008).
static var persist: bool = true


## --- CYCLE DE VIE --------------------------------------------------------

## LA SEULE ACCROCHE : appelee par ContentDB.reload() apres le chargement.
## Charge le fichier la premiere fois, branche le basculement du mode testeur,
## puis rejoue le calque sur les objets fraichement indexes.
static func after_content_load() -> void:
	if not _loaded:
		_loaded = true
		persist = SaveData.persistence_enabled
		_load_store()
	if not SaveData.profile_changed.is_connected(TesterOverrides.sync):
		SaveData.profile_changed.connect(TesterOverrides.sync)
	reapply()


## Remet le calque en accord avec le mode testeur. Sans effet si rien ne change :
## profile_changed est emis a chaque sauvegarde, ce test est donc la regle.
static func sync() -> void:
	if _wanted_active() != _active:
		reapply()


static func is_active() -> bool:
	return _active


static func _wanted_active() -> bool:
	return SaveData.tester_mode()


## Defait tout, puis rejoue chaque surcharge sur le contenu COURANT.
##
## Hors mode testeur on rejoue AUSSI, puis on defait : c est une passe a blanc
## qui valide les surcharges et releve les valeurs d origine, pour que l editeur
## et l export marchent pareil que le mode soit allume ou non.
static func reapply() -> void:
	_revert_all()
	_originals.clear()
	var gardees: Array = []
	# Les changements de NOMBRE de vagues d abord : "waves/5" n existe qu apres
	# un "waves/#" qui porte le niveau a six vagues.
	var ordre: Array = []
	for e in _entries:
		if String(e["field"]).ends_with("/#"):
			ordre.append(e)
	for e in _entries:
		if not String(e["field"]).ends_with("/#"):
			ordre.append(e)
	for e: Dictionary in ordre:
		var raison: String = _apply_entry(e)
		if raison == "":
			gardees.append(e)
		else:
			_reject(e, raison)
	# L ordre d origine est garde : c est celui ou le testeur a fait ses reglages,
	# et celui du document.
	var ok: Array = []
	for e in _entries:
		if gardees.has(e):
			ok.append(e)
	_entries = ok
	_active = _wanted_active()
	if not _active:
		_revert_all()


static func _revert_all() -> void:
	for i in range(_undo.size() - 1, -1, -1):
		var u: Array = _undo[i]
		var obj: Object = u[0]
		if obj != null and is_instance_valid(obj):
			obj.set(u[1], u[2])
	_undo.clear()


static func _reject(e: Dictionary, raison: String) -> void:
	for r in _rejected:
		if r["target"] == e["target"] and r["field"] == e["field"]:
			_rejected.erase(r)
			break
	_rejected.append({"target": e["target"], "field": e["field"],
		"value": e.get("value"), "reason": raison})
	push_warning("Surcharge ignoree %s / %s : %s" % [e["target"], e["field"], raison])


## --- API DE L EDITEUR ------------------------------------------------------

static func entries() -> Array:
	return _entries.duplicate(true)


static func rejected() -> Array:
	return _rejected.duplicate(true)


static func count() -> int:
	return _entries.size()


static func has_override(target: String, field: String) -> bool:
	return _index_of(target, field) >= 0


static func _index_of(target: String, field: String) -> int:
	for i in _entries.size():
		if _entries[i]["target"] == target and _entries[i]["field"] == field:
			return i
	return -1


## Pose (ou remplace) une surcharge. Rend "" si elle tient, la raison sinon —
## et dans ce cas l etat d avant est rendu tel quel. Une valeur egale a
## l origine RETIRE la surcharge : "revenir a l origine" a la main ou par le
## bouton donne le meme resultat, et le document ne porte pas de faux changement.
static func set_override(target: String, field: String, value: Variant) -> String:
	var avant: Array = _entries.duplicate(true)
	var origine: Variant = original_value(target, field)
	var i: int = _index_of(target, field)
	if same_value(value, origine) and _resolve_target(target) != null:
		if i >= 0:
			_entries.remove_at(i)
	elif i >= 0:
		_entries[i] = {"target": target, "field": field, "value": value}
	else:
		_entries.append({"target": target, "field": field, "value": value})
	_rejected = _rejected.filter(func(r: Dictionary) -> bool:
		return not (r["target"] == target and r["field"] == field))
	reapply()
	for r in _rejected:
		if r["target"] == target and r["field"] == field:
			var raison: String = r["reason"]
			_rejected.erase(r)
			_entries = avant
			reapply()
			return raison
	_save_store()
	return ""


static func remove_override(target: String, field: String) -> void:
	var i: int = _index_of(target, field)
	if i < 0:
		return
	_entries.remove_at(i)
	reapply()
	_save_store()


## Toutes les surcharges d une cible (ou dont le champ commence par `prefix`).
static func remove_all_for(target: String, prefix: String = "") -> void:
	_entries = _entries.filter(func(e: Dictionary) -> bool:
		return not (e["target"] == target and String(e["field"]).begins_with(prefix)))
	reapply()
	_save_store()


static func clear_all() -> void:
	_entries.clear()
	_rejected.clear()
	reapply()
	_save_store()


## Remplace TOUT le jeu de surcharges (import). Rend les ecartees.
static func replace_all(list: Array) -> Array:
	_entries.clear()
	_rejected.clear()
	for e in list:
		if typeof(e) == TYPE_DICTIONARY and e.has("target") and e.has("field"):
			var t: String = String(e["target"])
			var f: String = String(e["field"])
			var i: int = _index_of(t, f)
			var neuve: Dictionary = {"target": t, "field": f, "value": e.get("value")}
			if i >= 0:
				_entries[i] = neuve
			else:
				_entries.append(neuve)
	reapply()
	_save_store()
	return rejected()


## Valeur ENCODEE actuellement en jeu (surcharge comprise si active), ou null.
static func current_value(target: String, field: String) -> Variant:
	var res: Resource = _resolve_target(target)
	if res == null:
		return null
	var f: Dictionary = resolve_field(res, field)
	if f.is_empty():
		return null
	return _read(f)


## Valeur ENCODEE d origine, celle du .tres. Relevee au moment ou la surcharge
## est appliquee ; sans surcharge, c est simplement la valeur courante.
static func original_value(target: String, field: String) -> Variant:
	var k: String = target + "|" + field
	if _originals.has(k):
		return _originals[k]
	if not _active or not has_override(target, field):
		return current_value(target, field)
	return null


## Valeur ENCODEE que le testeur a choisie (meme si le mode est eteint).
static func override_value(target: String, field: String) -> Variant:
	var i: int = _index_of(target, field)
	return _entries[i]["value"] if i >= 0 else null


## --- RESOLUTION -----------------------------------------------------------

static func target_of(res: Resource) -> String:
	if res is SpellCard:
		return "card:%s" % (res as SpellCard).id
	if res is EnemyDef:
		return "enemy:%s" % (res as EnemyDef).id
	if res is LevelDef:
		return "level:%s" % (res as LevelDef).id
	if res is ObjectiveDef:
		return "objective:%s" % (res as ObjectiveDef).id
	return ""


static func _resolve_target(target: String) -> Resource:
	var parts: PackedStringArray = target.split(":", true, 1)
	if parts.size() != 2 or not TARGET_KINDS.has(parts[0]):
		return null
	var dict: Dictionary = ContentDB.get(TARGET_KINDS[parts[0]])
	return dict.get(StringName(parts[1]))


static func resolve_target(target: String) -> Resource:
	return _resolve_target(target)


## Proprietes exportees d une Resource, dans l ordre du script, groupes compris
## (une entree {"group": nom} annonce une section, comme dans l inspecteur).
static func exported_properties(obj: Object) -> Array:
	var script: Script = obj.get_script()
	var cle: String = script.resource_path if script != null else obj.get_class()
	if _plists.has(cle):
		return _plists[cle]
	var out: Array = []
	for p: Dictionary in obj.get_property_list():
		var usage: int = int(p["usage"])
		if usage & PROPERTY_USAGE_GROUP:
			out.append({"group": String(p["name"])})
			continue
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (usage & PROPERTY_USAGE_STORAGE):
			out.append(p)
	_plists[cle] = out
	return out


static func _prop(obj: Object, name: String) -> Dictionary:
	for p: Dictionary in exported_properties(obj):
		if p.get("name", "") == name:
			return p
	return {}


## Decrit un champ : ou il vit, comment il s encode, quelles bornes il a.
## Dictionnaire vide = champ inconnu ou non editable.
##   holder  l objet porteur      prop   la propriete sur ce porteur
##   kind    float int bool string text name enum color ref ref_list
##           enum_list name_list dict_value wave wave_count
##   sub     cle du dictionnaire (dict_value) ou indice (wave)
static func resolve_field(res: Resource, field: String) -> Dictionary:
	var segs: PackedStringArray = field.split("/")
	var holder: Object = res
	var i: int = 0
	while i < segs.size():
		var name: String = segs[i]
		if name in SKIP_FIELDS:
			return {}
		var p: Dictionary = _prop(holder, name)
		if p.is_empty():
			return {}
		var restant: int = segs.size() - i - 1
		# Les briques d effet d une carte : on descend dans l EffectSpec.
		if name == "effects" and holder is SpellCard:
			if restant < 2 or not segs[i + 1].is_valid_int():
				return {}
			var idx: int = segs[i + 1].to_int()
			var effs: Array = holder.get("effects")
			if idx < 0 or idx >= effs.size() or effs[idx] == null:
				return {}
			holder = effs[idx]
			i += 2
			continue
		# Les vagues d un niveau : une vague entiere, ou leur nombre.
		if name == "waves" and holder is LevelDef:
			if restant != 1:
				return {}
			var s: String = segs[i + 1]
			if s == "#":
				return {"holder": holder, "prop": "waves", "kind": "wave_count",
					"bounds": BOUNDS["wave_count"]}
			if not s.is_valid_int():
				return {}
			var w: int = s.to_int()
			if w < 0 or w >= (holder as LevelDef).waves.size():
				return {}
			return {"holder": holder, "prop": "waves", "kind": "wave", "sub": w}
		if int(p["type"]) == TYPE_DICTIONARY:
			if restant != 1:
				return {}
			return _dict_field(holder, name, segs[i + 1])
		if restant != 0:
			return {}
		return _simple_field(holder, p)
	return {}


static func _dict_field(holder: Object, prop: String, key_text: String) -> Dictionary:
	var d: Dictionary = holder.get(prop)
	if prop == "resistances":
		for t in RESIST_TAGS:
			if GameEnums.tag_name(t) == key_text:
				return {"holder": holder, "prop": prop, "kind": "dict_value", "sub": t,
					"value_type": TYPE_FLOAT, "bounds": BOUNDS["resistances"],
					"default": 1.0}
		return {}
	# Parametres libres : seulement les cles EXISTANTES, avec leur type. Une cle
	# inventee ne serait lue par aucun handler : elle ne ferait rien, en silence.
	for k in d.keys():
		if String(k) == key_text:
			return {"holder": holder, "prop": prop, "kind": "dict_value", "sub": k,
				"value_type": typeof(d[k]), "bounds": PARAM_BOUNDS}
	return {}


static func _simple_field(holder: Object, p: Dictionary) -> Dictionary:
	var name: String = p["name"]
	var t: int = int(p["type"])
	var hint: int = int(p["hint"])
	var hs: String = String(p["hint_string"])
	var f: Dictionary = {"holder": holder, "prop": name}
	match t:
		TYPE_BOOL:
			f["kind"] = "bool"
		TYPE_INT:
			if hint == PROPERTY_HINT_ENUM:
				f["kind"] = "enum"
				f["choices"] = _enum_names(hs)
			else:
				f["kind"] = "int"
				f["bounds"] = _bounds_for(name, hint, hs)
		TYPE_FLOAT:
			f["kind"] = "float"
			f["bounds"] = _bounds_for(name, hint, hs)
		TYPE_STRING:
			f["kind"] = "text" if hint == PROPERTY_HINT_MULTILINE_TEXT else "string"
		TYPE_STRING_NAME:
			f["kind"] = "name"
		TYPE_COLOR:
			f["kind"] = "color"
		TYPE_OBJECT:
			var cls: String = String(p["class_name"])
			if not REF_CLASSES.has(cls):
				return {}
			f["kind"] = "ref"
			f["ref"] = REF_CLASSES[cls]
		TYPE_ARRAY:
			if hs.begins_with("2/2:"):
				f["kind"] = "enum_list"
				f["choices"] = _enum_names(hs.substr(4))
			elif hs.begins_with("24/17:"):
				var cls2: String = hs.substr(6)
				if not REF_CLASSES.has(cls2):
					return {}
				f["kind"] = "ref_list"
				f["ref"] = REF_CLASSES[cls2]
			elif hs.begins_with("21:"):
				f["kind"] = "name_list"
			elif hs.begins_with("2:") and name == "chameleon_elements":
				# Des entiers qui SONT des elements : on les ecrit par leur nom.
				f["kind"] = "enum_list"
				f["choices"] = _enum_names("Physical:0,Fire:1,Frost:2,Arcane:3,Slow:4,Summon:5,Poison:6,Lightning:7")
			else:
				return {}
		_:
			return {}
	f["choices_extra"] = choices_for(holder, name)
	return f


## Choix fermes pour les champs dont la valeur libre n aurait pas de sens :
## une apparence hors du catalogue serait une forme de secours, un verbe sans
## handler un sort qui ne fait rien.
static func choices_for(holder: Object, name: String) -> Array:
	var out: Array = []
	match name:
		"anim_key":
			out = AnimCatalog.keys().duplicate()
		"fx_key":
			out = Fx.sheet_names().duplicate()
		"sfx_key":
			# Meme raison que les verbes ci-dessous : AudioBus vient apres ContentDB.
			var bus: Node = _autoload("AudioBus")
			if bus != null:
				for k in bus.call("sfx_keys"):
					out.append(String(k))
		"key":
			# EffectRegistry est charge APRES ContentDB : au tout premier
			# chargement il n est pas encore dans l arbre. Sans liste, le champ
			# n est simplement pas contraint ; l editeur, lui, l ouvre bien plus
			# tard.
			var reg: Node = _autoload("EffectRegistry")
			if holder is EffectSpec and reg != null:
				for k in reg.call("keys"):
					out.append(String(k))
		"backdrop":
			for lv: LevelDef in ContentDB.levels.values():
				if lv.backdrop != "" and not out.has(lv.backdrop):
					out.append(lv.backdrop)
		"terrain":
			out = ["grass", "sand"]
		"next_levels":
			for id in ContentDB.levels.keys():
				out.append(String(id))
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	return out


static func _autoload(name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(name)


static func _enum_names(hs: String) -> Array:
	var out: Array = []
	for part in hs.split(","):
		var nom: String = part.split(":")[0].strip_edges()
		if nom != "":
			out.append(nom)
	return out


static func _bounds_for(name: String, hint: int, hs: String) -> Array:
	if hint == PROPERTY_HINT_RANGE:
		var b: PackedStringArray = hs.split(",")
		if b.size() >= 2 and b[0].is_valid_float() and b[1].is_valid_float():
			return [b[0].to_float(), b[1].to_float()]
	if BOUNDS.has(name):
		return BOUNDS[name]
	return DEFAULT_BOUNDS


## --- LECTURE / ECRITURE ENCODEES -----------------------------------------

static func _read(f: Dictionary) -> Variant:
	var holder: Object = f["holder"]
	var raw: Variant = holder.get(f["prop"])
	match String(f["kind"]):
		"bool", "string", "text":
			return raw
		"int":
			return int(raw)
		"float":
			return float(raw)
		"name":
			return String(raw)
		"enum":
			var ch: Array = f["choices"]
			var v: int = int(raw)
			return ch[v] if v >= 0 and v < ch.size() else v
		"color":
			return "#" + (raw as Color).to_html(true)
		"ref":
			return _id_of(raw)
		"ref_list":
			var ids: Array = []
			for r in raw:
				ids.append(_id_of(r))
			return ids
		"enum_list":
			var noms: Array = []
			var ch2: Array = f["choices"]
			for v2 in raw:
				noms.append(ch2[int(v2)] if int(v2) >= 0 and int(v2) < ch2.size() else int(v2))
			return noms
		"name_list":
			var out: Array = []
			for s in raw:
				out.append(String(s))
			return out
		"dict_value":
			var d: Dictionary = raw
			if d.has(f["sub"]):
				return _num_or(d[f["sub"]])
			return f.get("default")
		"wave_count":
			return (raw as Array).size()
		"wave":
			return encode_wave((raw as Array)[int(f["sub"])])
	return null


static func _num_or(v: Variant) -> Variant:
	if typeof(v) == TYPE_STRING_NAME:
		return String(v)
	return v


static func _id_of(r: Variant) -> Variant:
	if r == null or not (r is Resource):
		return null
	var id: Variant = (r as Resource).get("id")
	return String(id) if id != null else null


## Ecrit `value` (encodee) dans le champ, apres validation. "" si ecrit.
static func _write(f: Dictionary, value: Variant, undo: bool = true) -> String:
	var dec: Array = decode(f, value)
	if dec[0] != "":
		return dec[0]
	var holder: Object = f["holder"]
	var prop: String = f["prop"]
	var old: Variant = holder.get(prop)
	var neuf: Variant = dec[1]
	match String(f["kind"]):
		"dict_value":
			var d: Dictionary = (old as Dictionary).duplicate()
			d[f["sub"]] = neuf
			neuf = d
		"ref_list", "enum_list", "name_list":
			var a: Array = (old as Array).duplicate()
			a.clear()
			a.append_array(neuf)
			neuf = a
		"wave_count":
			var waves: Array = (old as Array).duplicate()
			var n: int = int(dec[1])
			if waves.is_empty():
				return "le niveau n a aucune vague a recopier"
			while waves.size() > n:
				waves.pop_back()
			while waves.size() < n:
				# Une vague AJOUTEE part d une copie de la derniere : une vague
				# vide se viderait a l instant et le niveau sauterait un palier.
				# Copie par encodage et non par duplicate(true) : une copie
				# profonde dupliquerait aussi les EnemyDef des entrees, et une
				# surcharge du monstre ne toucherait plus ces exemplaires-la.
				var copie: WaveDef = decode_wave(encode_wave(waves[waves.size() - 1]))[1]
				if copie == null:
					return "la derniere vague ne se recopie pas"
				copie.is_boss = false
				copie.id = StringName("%s_ajout%d" % [copie.id, waves.size() + 1])
				waves.append(copie)
			neuf = waves
		"wave":
			var waves2: Array = (old as Array).duplicate()
			waves2[int(f["sub"])] = neuf
			neuf = waves2
	if undo:
		_undo.append([holder, prop, old])
	holder.set(prop, neuf)
	return ""


## Valide et convertit une valeur encodee. Rend [raison, valeur brute] ;
## raison vide = valide.
static func decode(f: Dictionary, v: Variant) -> Array:
	var kind: String = f["kind"]
	match kind:
		"bool":
			if typeof(v) != TYPE_BOOL:
				return ["vrai ou faux attendu", null]
			return ["", v]
		"int", "float", "wave_count":
			if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
				return ["nombre attendu", null]
			var x: float = float(v)
			if is_nan(x) or is_inf(x):
				return ["nombre invalide", null]
			if kind != "float" and absf(x - roundf(x)) > 0.0001:
				return ["nombre entier attendu", null]
			var b: Array = f.get("bounds", DEFAULT_BOUNDS)
			if x < float(b[0]) - 0.0001 or x > float(b[1]) + 0.0001:
				return ["hors bornes [%s ; %s]" % [_fmt(b[0]), _fmt(b[1])], null]
			return ["", x if kind == "float" else int(roundf(x))]
		"string", "text", "name":
			if typeof(v) != TYPE_STRING and typeof(v) != TYPE_STRING_NAME:
				return ["texte attendu", null]
			var s: String = String(v)
			if s.length() > MAX_TEXT:
				return ["texte trop long", null]
			var ch: Array = f.get("choices_extra", [])
			if not ch.is_empty() and s != "" and not ch.has(s):
				return ["'%s' n est pas dans la liste" % s, null]
			return ["", StringName(s) if kind == "name" else s]
		"enum":
			var noms: Array = f["choices"]
			if typeof(v) == TYPE_STRING and noms.has(v):
				return ["", noms.find(v)]
			return ["valeur inconnue : %s" % str(v), null]
		"color":
			if typeof(v) != TYPE_STRING or not Color.html_is_valid(String(v)):
				return ["couleur #rrggbbaa attendue", null]
			return ["", Color.html(String(v))]
		"ref":
			if v == null or String(v) == "":
				return ["", null]
			var r: Resource = _resolve_target("%s:%s" % [f["ref"], v])
			if r == null:
				return ["id inconnu : %s" % str(v), null]
			return ["", r]
		"ref_list":
			if typeof(v) != TYPE_ARRAY:
				return ["liste attendue", null]
			if (v as Array).size() > MAX_LIST:
				return ["liste trop longue", null]
			var out: Array = []
			for id in v:
				var r2: Resource = _resolve_target("%s:%s" % [f["ref"], id])
				if r2 == null:
					return ["id inconnu : %s" % str(id), null]
				out.append(r2)
			return ["", out]
		"enum_list":
			if typeof(v) != TYPE_ARRAY:
				return ["liste attendue", null]
			var vals: Array = []
			var noms2: Array = f["choices"]
			for n in v:
				if typeof(n) != TYPE_STRING or not noms2.has(n):
					return ["valeur inconnue : %s" % str(n), null]
				vals.append(noms2.find(n))
			return ["", vals]
		"name_list":
			if typeof(v) != TYPE_ARRAY:
				return ["liste attendue", null]
			var noms3: Array = []
			var ch3: Array = f.get("choices_extra", [])
			for n2 in v:
				if typeof(n2) != TYPE_STRING:
					return ["texte attendu dans la liste", null]
				if not ch3.is_empty() and not ch3.has(n2):
					return ["'%s' n est pas dans la liste" % n2, null]
				noms3.append(StringName(n2))
			return ["", noms3]
		"dict_value":
			return _decode_param(f, v)
		"wave":
			return decode_wave(v)
	return ["champ non editable", null]


static func _decode_param(f: Dictionary, v: Variant) -> Array:
	var t: int = int(f.get("value_type", TYPE_FLOAT))
	if t == TYPE_BOOL:
		return ["", v] if typeof(v) == TYPE_BOOL else ["vrai ou faux attendu", null]
	if t == TYPE_STRING or t == TYPE_STRING_NAME:
		if typeof(v) != TYPE_STRING:
			return ["texte attendu", null]
		return ["", StringName(v) if t == TYPE_STRING_NAME else String(v)]
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return ["nombre attendu", null]
	var x: float = float(v)
	if is_nan(x) or is_inf(x):
		return ["nombre invalide", null]
	var b: Array = f.get("bounds", PARAM_BOUNDS)
	if x < float(b[0]) - 0.0001 or x > float(b[1]) + 0.0001:
		return ["hors bornes [%s ; %s]" % [_fmt(b[0]), _fmt(b[1])], null]
	if t == TYPE_INT:
		if absf(x - roundf(x)) > 0.0001:
			return ["nombre entier attendu", null]
		return ["", int(roundf(x))]
	return ["", x]


## --- LES VAGUES ------------------------------------------------------------

## Une vague en clair. Les cles sont les NOMS DE CODE de WaveDef / WaveEntry :
## c est ce que l outil de chez nous retrouve dans make_content.gd.
static func encode_wave(w: WaveDef) -> Dictionary:
	if w == null:
		return {}
	var entrees: Array = []
	for e: WaveEntry in w.entries:
		if e == null:
			continue
		entrees.append({
			"enemy": _id_of(e.enemy), "count": e.count,
			"spawn_delay": e.spawn_delay, "start_offset": e.start_offset,
		})
	return {
		"id": String(w.id), "duration": w.duration, "difficulty": w.difficulty,
		"is_miniboss": w.is_miniboss, "is_boss": w.is_boss, "entries": entrees,
	}


static func decode_wave(v: Variant) -> Array:
	if typeof(v) != TYPE_DICTIONARY:
		return ["vague attendue", null]
	var d: Dictionary = v
	var w := WaveDef.new()
	w.id = StringName(String(d.get("id", "")))
	var num: Array = [["duration", "wave_duration"], ["difficulty", "difficulty"]]
	for paire in num:
		var x: Variant = d.get(paire[0])
		if typeof(x) != TYPE_INT and typeof(x) != TYPE_FLOAT:
			return ["%s : nombre attendu" % paire[0], null]
		var b: Array = BOUNDS[paire[1]]
		if float(x) < float(b[0]) or float(x) > float(b[1]):
			return ["%s hors bornes [%s ; %s]" % [paire[0], _fmt(b[0]), _fmt(b[1])], null]
		w.set(paire[0], float(x))
	w.is_miniboss = bool(d.get("is_miniboss", false))
	w.is_boss = bool(d.get("is_boss", false))
	var entrees: Variant = d.get("entries")
	if typeof(entrees) != TYPE_ARRAY or (entrees as Array).is_empty():
		return ["une vague porte au moins une entree", null]
	if (entrees as Array).size() > MAX_LIST:
		return ["trop d entrees", null]
	var liste: Array[WaveEntry] = []
	for e in entrees:
		if typeof(e) != TYPE_DICTIONARY:
			return ["entree illisible", null]
		var def: EnemyDef = ContentDB.enemies.get(StringName(String(e.get("enemy", ""))))
		if def == null:
			return ["monstre inconnu : %s" % str(e.get("enemy")), null]
		var we := WaveEntry.new()
		we.enemy = def
		for champ in [["count", "count"], ["spawn_delay", "spawn_delay"], ["start_offset", "start_offset"]]:
			var x2: Variant = e.get(champ[0], we.get(champ[0]))
			if typeof(x2) != TYPE_INT and typeof(x2) != TYPE_FLOAT:
				return ["%s : nombre attendu" % champ[0], null]
			var b2: Array = BOUNDS[champ[1]]
			if float(x2) < float(b2[0]) or float(x2) > float(b2[1]):
				return ["%s hors bornes [%s ; %s]" % [champ[0], _fmt(b2[0]), _fmt(b2[1])], null]
			if champ[0] == "count":
				we.count = int(roundf(float(x2)))
			else:
				we.set(champ[0], float(x2))
		liste.append(we)
	w.entries = liste
	return ["", w]


## --- APPLICATION -----------------------------------------------------------

static func _apply_entry(e: Dictionary) -> String:
	var target: String = String(e.get("target", ""))
	var field: String = String(e.get("field", ""))
	var res: Resource = _resolve_target(target)
	if res == null:
		return "cible inconnue : %s" % target
	var f: Dictionary = resolve_field(res, field)
	if f.is_empty():
		# Une vague AU-DELA de l origine n existe qu apres son "waves/#" : sans
		# lui, l indice est hors limites — c est bien une surcharge invalide.
		return "champ inconnu ou non modifiable : %s" % field
	var k: String = target + "|" + field
	if not _originals.has(k):
		_originals[k] = _read(f)
	return _write(f, e.get("value"))


## Egalite de deux valeurs ENCODEES. Un nombre relu d un JSON est un flottant :
## 12 et 12.0 doivent etre egaux, sinon un aller-retour par le presse-papiers
## inventerait des changements.
static func same_value(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	var na: bool = ta == TYPE_INT or ta == TYPE_FLOAT
	var nb: bool = tb == TYPE_INT or tb == TYPE_FLOAT
	if na and nb:
		return absf(float(a) - float(b)) <= 0.00001
	if ta == TYPE_ARRAY and tb == TYPE_ARRAY:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not same_value(a[i], b[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in (a as Dictionary).keys():
			if not (b as Dictionary).has(k) or not same_value(a[k], b[k]):
				return false
		return true
	if (ta == TYPE_STRING or ta == TYPE_STRING_NAME) and (tb == TYPE_STRING or tb == TYPE_STRING_NAME):
		return String(a) == String(b)
	return ta == tb and a == b


static func _fmt(x: Variant) -> String:
	var f: float = float(x)
	if absf(f - roundf(f)) < 0.00001:
		return str(int(roundf(f)))
	return str(snappedf(f, 0.001))


## --- FICHIER ----------------------------------------------------------------

static func _load_store() -> void:
	if not persist or not FileAccess.file_exists(STORE_PATH):
		return
	var text: String = FileAccess.get_file_as_string(STORE_PATH)
	var lu: Dictionary = TesterDocument.parse(text)
	if lu.get("error", "") != "":
		push_warning("Surcharges illisibles (%s) : ignorees" % lu["error"])
		return
	_entries = lu["entries"]


static func _save_store() -> void:
	if not persist:
		return
	var fa := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if fa == null:
		push_warning("Surcharges : ecriture impossible dans %s" % STORE_PATH)
		return
	fa.store_string(TesterDocument.build())
	fa.close()


## Pour les tests : etat neuf, rien de lu ni d ecrit.
static func reset_for_tests() -> void:
	_entries.clear()
	_rejected.clear()
	reapply()


static func label_of(field: String) -> String:
	var segs: PackedStringArray = field.split("/")
	if segs.size() >= 3 and segs[0] == "effects":
		var suite: String = "/".join(segs.slice(2))
		return "effet %d : %s" % [segs[1].to_int() + 1, LABELS.get(suite, suite)]
	if segs.size() == 2 and segs[0] == "waves":
		return "nombre de vagues" if segs[1] == "#" else "vague %d" % (segs[1].to_int() + 1)
	if segs.size() == 2 and segs[0] == "resistances":
		return "resistance %s" % segs[1]
	if segs.size() == 2 and segs[0] == "params":
		return "parametre %s" % segs[1]
	return LABELS.get(field, field)

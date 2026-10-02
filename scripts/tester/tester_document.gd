class_name TesterDocument
extends RefCounted
## LE DOCUMENT DE CHANGEMENT - ce que le co-auteur nous transmet.
##
## "Creer la possibilite de telecharger un document de changement que je pourrai
## te transmettre pour que tu modifies le jeu en consequence."
##
## LISIBLE ET STRUCTURE A LA FOIS. Le testeur le colle dans un message depuis son
## telephone : il doit pouvoir le relire (`texte`, une phrase par changement).
## L outil de chez nous (tools/apply_changes.py) le lit : il lui faut la cible,
## le champ, l avant et l apres, sans interpretation. Un seul JSON porte les deux.
##
## FORMAT (version 1) :
## {
##   "format": "time_wizard_changements",   <- signature, refusee sinon
##   "version": 1,
##   "jeu": {"nom": ..., "version": ..., "commit": ...},
##   "date": "2026-10-02T17:21:21",
##   "mode_testeur": true,                  <- les surcharges etaient-elles jouees
##   "resume": "3 changements : 1 sort, 1 monstre, 1 niveau",
##   "changements": [
##     {"cible": "enemy:gnome", "nom": "Gnome", "champ": "max_hp",
##      "libelle": "PV", "avant": 12.0, "apres": 30.0,
##      "texte": "Monstre Gnome : PV 12 -> 30"}
##   ],
##   "ignores": [{"cible", "champ", "apres", "raison"}]
## }
##
## LE MEME FORMAT SERT DE FICHIER DE SAUVEGARDE (user://tester_overrides.json) :
## un seul lecteur, donc l aller-retour export -> import ne peut pas diverger de
## l enregistrement. A l import, seuls `cible`, `champ` et `apres` comptent ;
## `avant` et `texte` sont recalcules sur le contenu du moment.

const KIND_WORDS: Dictionary = {
	"card": ["sort", "sorts"], "enemy": ["monstre", "monstres"],
	"level": ["niveau", "niveaux"], "objective": ["objectif", "objectifs"],
}


## Le document courant, en JSON indente.
static func build() -> String:
	return JSON.stringify(build_dict(), "  ", false)


static func build_dict() -> Dictionary:
	var changements: Array = []
	var par_genre: Dictionary = {}
	for e: Dictionary in TesterOverrides.entries():
		var cible: String = e["target"]
		var champ: String = e["field"]
		var genre: String = cible.split(":")[0]
		par_genre[genre] = int(par_genre.get(genre, 0)) + 1
		var avant: Variant = TesterOverrides.original_value(cible, champ)
		changements.append({
			"cible": cible,
			"nom": display_name_of(cible),
			"champ": champ,
			"libelle": TesterOverrides.label_of(champ),
			"avant": avant,
			"apres": e["value"],
			"texte": sentence(cible, champ, avant, e["value"]),
		})
	var ignores: Array = []
	for r: Dictionary in TesterOverrides.rejected():
		ignores.append({"cible": r["target"], "champ": r["field"],
			"apres": r.get("value"), "raison": r["reason"]})
	return {
		"format": TesterOverrides.FORMAT,
		"version": TesterOverrides.FORMAT_VERSION,
		"jeu": {
			"nom": String(ProjectSettings.get_setting("application/config/name", "")),
			"version": String(ProjectSettings.get_setting("application/config/version", "")),
			"commit": commit(),
		},
		"date": Time.get_datetime_string_from_system(false, false),
		"mode_testeur": SaveData.tester_mode(),
		"resume": summary(par_genre, changements.size()),
		"changements": changements,
		"ignores": ignores,
	}


static func summary(par_genre: Dictionary, total: int) -> String:
	if total == 0:
		return "aucun changement"
	var morceaux: Array[String] = []
	for g in ["card", "enemy", "level", "objective"]:
		var n: int = int(par_genre.get(g, 0))
		if n > 0:
			morceaux.append("%d %s" % [n, KIND_WORDS[g][1 if n > 1 else 0]])
	return "%d changement%s : %s" % [total, "s" if total > 1 else "", ", ".join(morceaux)]


## Lit un document (ou le fichier de sauvegarde). Rend
## {"entries": [{target, field, value}], "error": ""}. N ECRIT RIEN : c est
## replace_all() qui decide, apres validation.
static func parse(text: String) -> Dictionary:
	var j := JSON.new()
	# JSON.parse et non JSON.parse_string : l instance rend un code d erreur sans
	# rien ecrire sur stderr. Un texte colle par erreur n est pas un defaut du jeu.
	if j.parse(text.strip_edges()) != OK:
		return {"entries": [], "error": "pas un JSON lisible (ligne %d : %s)"
			% [j.get_error_line(), j.get_error_message()]}
	var d: Variant = j.data
	if typeof(d) != TYPE_DICTIONARY:
		return {"entries": [], "error": "le document n est pas un objet JSON"}
	if String((d as Dictionary).get("format", "")) != TesterOverrides.FORMAT:
		return {"entries": [], "error": "ce n est pas un document de changement Time Wizard"}
	var liste: Variant = (d as Dictionary).get("changements", [])
	if typeof(liste) != TYPE_ARRAY:
		return {"entries": [], "error": "la liste des changements est illisible"}
	var out: Array = []
	for c in liste:
		if typeof(c) != TYPE_DICTIONARY or not c.has("cible") or not c.has("champ") \
				or not c.has("apres"):
			continue
		out.append({"target": String(c["cible"]), "field": String(c["champ"]),
			"value": c["apres"]})
	return {"entries": out, "error": ""}


## Importe un document : remplace le jeu de surcharges. Rend
## {"error", "imported", "rejected": [...]}.
static func import_text(text: String) -> Dictionary:
	var lu: Dictionary = parse(text)
	if lu["error"] != "":
		return {"error": lu["error"], "imported": 0, "rejected": []}
	var ecartees: Array = TesterOverrides.replace_all(lu["entries"])
	return {"error": "", "imported": TesterOverrides.count(), "rejected": ecartees}


## Ecrit le document dans user://changements/ et rend le chemin ABSOLU (affiche
## au testeur ; sur PC, le dossier s ouvre). "" si l ecriture echoue.
static func write_file(dir: String = TesterOverrides.DOC_DIR) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp: String = Time.get_datetime_string_from_system(false, false) \
		.replace(":", "").replace("-", "").replace("T", "_")
	var path: String = dir.path_join("changements_%s.json" % stamp)
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		return ""
	fa.store_string(build())
	fa.close()
	return ProjectSettings.globalize_path(path)


## --- PHRASES -----------------------------------------------------------------

static func display_name_of(target: String) -> String:
	var res: Resource = TesterOverrides.resolve_target(target)
	if res == null:
		return target.split(":")[-1]
	var n: Variant = res.get("display_name")
	if n != null and String(n) != "":
		return String(n)
	return String(res.get("id"))


static func sentence(target: String, field: String, avant: Variant, apres: Variant) -> String:
	var genre: String = target.split(":")[0]
	var mot: String = String(KIND_WORDS.get(genre, ["?", "?"])[0]).capitalize()
	var champ: String = TesterOverrides.label_of(field)
	if field.begins_with("waves/") and not field.ends_with("/#"):
		return "%s %s, %s : %s -> %s" % [mot, display_name_of(target), champ,
			wave_text(avant), wave_text(apres)]
	return "%s %s : %s %s -> %s" % [mot, display_name_of(target), champ,
		value_text(avant), value_text(apres)]


static func value_text(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "(rien)"
		TYPE_FLOAT, TYPE_INT:
			return TesterOverrides._fmt(v)
		TYPE_BOOL:
			return "oui" if v else "non"
		TYPE_ARRAY:
			var morceaux: Array[String] = []
			for x in v:
				morceaux.append(value_text(x))
			return "[" + ", ".join(morceaux) + "]"
		TYPE_STRING:
			var s: String = v
			return "\"%s\"" % (s if s.length() <= 60 else s.substr(0, 57) + "...")
	return str(v)


## Une vague en une ligne : "gnome x5, wisp x3 (difficulte 1, 26 s)".
static func wave_text(v: Variant) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "(aucune)"
	var d: Dictionary = v
	var morceaux: Array[String] = []
	for e in d.get("entries", []):
		morceaux.append("%s x%s" % [e.get("enemy", "?"), TesterOverrides._fmt(e.get("count", 0))])
	var drapeau: String = ""
	if bool(d.get("is_boss", false)):
		drapeau = ", boss"
	elif bool(d.get("is_miniboss", false)):
		drapeau = ", mini-boss"
	return "%s (difficulte %s, %s s%s)" % [", ".join(morceaux),
		TesterOverrides._fmt(d.get("difficulty", 1.0)),
		TesterOverrides._fmt(d.get("duration", 0.0)), drapeau]


## Le commit du jeu quand on le connait. Sur le telephone il n y a pas de depot :
## "inconnu", et c est le champ `avant` de chaque changement qui permet a l outil
## de reperer un contenu qui a bouge depuis. Sur PC (projet ouvert depuis le
## depot ou un worktree), on lit HEAD.
static func commit() -> String:
	var git: String = ProjectSettings.globalize_path("res://.git")
	var head_path: String = ""
	if DirAccess.dir_exists_absolute(git):
		head_path = git.path_join("HEAD")
	elif FileAccess.file_exists(git):
		var lien: String = FileAccess.get_file_as_string(git).strip_edges()
		if lien.begins_with("gitdir:"):
			head_path = lien.substr(7).strip_edges().path_join("HEAD")
	if head_path == "" or not FileAccess.file_exists(head_path):
		return "inconnu"
	var head: String = FileAccess.get_file_as_string(head_path).strip_edges()
	if not head.begins_with("ref:"):
		return head.substr(0, 12)
	var ref: String = head.substr(4).strip_edges()
	var base: String = head_path.get_base_dir()
	# Un worktree range ses refs dans le depot commun (fichier commondir).
	var commun: String = base.path_join("commondir")
	if FileAccess.file_exists(commun):
		base = base.path_join(FileAccess.get_file_as_string(commun).strip_edges()).simplify_path()
	var ref_path: String = base.path_join(ref)
	if FileAccess.file_exists(ref_path):
		return FileAccess.get_file_as_string(ref_path).strip_edges().substr(0, 12) \
			+ " (" + ref.get_file() + ")"
	return ref.get_file()

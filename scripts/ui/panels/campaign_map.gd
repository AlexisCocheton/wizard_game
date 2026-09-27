class_name CampaignMap
extends Control
## Carte de campagne : UN ECRAN PAR ACTE, pose sur le fond de combat de l acte.
##
##   +--------------------------------------------------+
##   |  ####  bande decoree du fond de l acte  ########  |
##   |                                                   |
##   |         ACTE II  -  Le Grand Cimetiere            |
##   | +-+    .----.                               +-+   |
##   | |<|   ( BOSS ) Ossuaire des                 |>|   |
##   | +-+    `----'  Marees   * * .               +-+   |
##   |                     .----.                        |
##   |                    ( BOSS ) Le Grand Appel        |
##   |                     `----'  . . .                 |
##   |                                                   |
##   |  ####  premier plan du fond  ###################   |
##   +--------------------------------------------------+
##
## CHAQUE NIVEAU PORTE LA SILHOUETTE DE SON MONSTRE SIGNATURE (UI-007)
## ------------------------------------------------------------------
## Deux illustrations etaient possibles : un medaillon recadre dans le fond du
## lieu, ou la silhouette du boss. Le fond est PAR ACTE (5 images pour 21
## niveaux) : tous les medaillons d une meme page auraient montre le meme
## decor, c est-a-dire exactement ce qu on cherche a distinguer. Le boss, lui,
## est propre au niveau, c est ce que le joueur affronte et retient (« le niveau
## de la gorgone »), et le jeu en a deja les feuilles animees. `signature_of`
## garantit en plus qu aucune silhouette ne se repete SUR UNE PAGE.
##
## UN ACTE A EMBRANCHEMENT SE DESSINE EN EVENTAIL
## ----------------------------------------------
##   +--------------------------------------------------+
##   |        ACTE IV  -  Le monde demoniaque           |
##   |   Les niveaux cote a cote s ouvrent ensemble...  |  <- avis d ordre libre
##   |                                                  |
##   |      .--.    .--.     .--.    .--.               |
##   |  <  (    )  (    )   (    )  (    )  >           |  <- une RANGEE : les
##   |      `--'    `--'     `--'    `--'               |     quatre demons, en
##   |     Vharn   Sesh    Kaltek   Ymoa                |     arc, nom DESSOUS
##   |                                                  |
##   |                    .--.                          |
##   |                   (    )                         |  <- la convergence,
##   |                    `--'                          |     centree sous
##   |              Le pentacle brise                   |     l eventail
##   +--------------------------------------------------+
##
## Le rang d un niveau est sa PROFONDEUR dans le chainage de son acte
## (`_compute_rows`) : deux niveaux de meme profondeur s ouvrent par la meme
## victoire et se jouent dans l ordre qu on veut. Les poser l un sous l autre en
## zigzag, comme un acte lineaire, disait au joueur « celui du haut d abord » —
## c est ce que l acte IV affichait, alors que le pentacle de Tombol ouvre ses
## quatre demons d un coup. La regle est tiree des DONNEES, pas ecrite pour
## l acte IV : l acte III (deux forges apres la cour des rois morts) en profite
## aussi, et un acte a venir n aura rien a declarer.
##
## POURQUOI un ecran par acte et non plus un defilement vertical : demande du
## testeur, mot pour mot — « utilise les fonds de combat pour l image de fond de
## l acte, change d acte avec les fleches ». Un fond peint ne se defile pas : il
## est compose pour 1080x1920 (bande decoree en haut, sol au milieu, premier plan
## en bas). Le faire glisser sous une colonne d iles le decoupe n importe ou.
##
## POURQUOI un Control et non plus une ScrollContainer : il n y a plus rien a
## faire defiler. Un acte tient dans un ecran, et c est precisement ce qui rend
## la navigation par fleches lisible — on voit d un coup tout l acte.
##
## POURQUOI le fond vient de `LevelDef.backdrop` et non d une table dans l UI :
## le combat de lvl_03 et le point de lvl_03 sur la carte doivent montrer le meme
## lieu. Deux tables finiraient par diverger a la premiere reorganisation des
## actes ; ici la carte lit la meme donnee que `BattleBackdrop`.

signal level_pressed(level_id: StringName)

## Un niveau = un MEDAILLON de 150 px qui porte la silhouette de son monstre
## signature (voir `signature_of`). La CIBLE TACTILE est le bouton qui porte le
## medaillon ET son etiquette (DOT_HIT), largement au-dessus des 90 px du cahier
## des charges.
##
## Pourquoi 150 et plus 96 : a 96 px une silhouette de boss n est plus qu une
## tache, on ne reconnait pas la gorgone du golem sur un telephone. 150 est le
## plus grand medaillon qui laisse passer CINQ niveaux (actes III et IV) sur la
## hauteur du sol sans que deux cibles se chevauchent : l etiquette passe donc
## A COTE du medaillon et non plus dessous.
const DOT_SIZE: float = 150.0
const DOT_HIT_W: float = 500.0
const DOT_HIT_H: float = 170.0
## Part du medaillon occupee par la silhouette. Le reste est l anneau et un peu
## d air : une silhouette qui touche le bord se lit comme rognee.
const PORTRAIT_FILL: float = 0.74

## Tuile d EVENTAIL : le nom passe SOUS le medaillon. A cote, il faudrait 500 px
## par niveau, et quatre niveaux n en ont que 740 entre les deux fleches.
## Hauteur = medaillon (150) + deux lignes de nom + la rangee d etoiles.
const FAN_HIT_H: float = 280.0
## Colonne maximale d une rangee : au-dela, deux niveaux d une rangee de deux
## s ecarteraient jusqu aux fleches et ne se liraient plus comme une paire.
const FAN_COL_MAX: float = 360.0
## Air entre deux tuiles voisines d une rangee : sans lui, deux cibles tactiles
## se touchent et un pouce a cheval ouvre l une ou l autre au hasard.
const FAN_GAP: float = 10.0
## Cambrure de l arc (rangees de trois et plus) : les tuiles du bord descendent,
## celles du centre montent. C est ce qui fait lire UNE rangee qui converge vers
## le niveau d en dessous, et non une ligne de plus d une liste.
const FAN_ARC: float = 80.0
## Marge verticale reservee a chaque rangee, en plus de sa tuile.
const ROW_GAP: float = 30.0

## Avis affiche sous le titre d un acte a embranchement. La forme (cote a cote)
## porte l information ; le texte la NOMME, pour le joueur qui n aurait pas lu
## la disposition comme un choix.
const FORK_NOTICE: String = "Les niveaux cote a cote s ouvrent ensemble : a toi de choisir l ordre."

## Bande utilisable du fond, en fraction de la hauteur de l ecran. Les fonds ont
## une bande DECOREE en haut (arbres, grilles, vitraux) et un PREMIER PLAN en bas
## (herbes hautes, dalles). Un point pose dedans se noie dans le decor : ces deux
## bornes delimitent le SOL, ou un point et son nom restent lisibles.
## Le haut est fixe par le TITRE de l acte (qui occupe jusqu a ~0.07) plus la
## bande decoree ; le bas par le premier plan, qui commence vers 0.85 sur les
## quatre fonds composes. Verifie a l oeil sur les 5 captures `map_acte*.png`.
const GROUND_TOP: float = 0.24
const GROUND_BOTTOM: float = 0.83

## Largeur reservee aux fleches sur chaque bord. Un point sous une fleche serait
## inatteignable : les positions sont contraintes a l interieur.
const SIDE_MARGIN: float = 150.0

## Fleches de changement d acte : 120x170, bien au-dela des 90 px minimum, et
## collees aux BORDS de l ecran — c est la ou tombe naturellement le pouce.
const ARROW_W: float = 120.0
const ARROW_H: float = 170.0

## Fond de repli quand l acte n a aucun niveau (donc aucun `backdrop` a lire).
## L acte 5 existe dans l histoire mais n a pas encore de niveau : il doit tout
## de meme s afficher, sinon le joueur croit que le jeu s arrete a l acte 4.
const ACT_BACKDROPS: Dictionary = {
	1: "act1_sky",
	2: "act2_graveyard",
	3: "act3_demon",
	4: "act4_origin",
	5: "act5_divine",
}
const BACKDROP_DIR: String = "res://assets/backdrops/"
const FALLBACK_BACKDROP: String = "menu_space"

## Le pack Tiny Swords n a pas d icone d etoile. La piece d or (icon_03) est la
## seule pastille ronde qui se lit a 34 px, doree quand elle est acquise et
## eteinte sinon. On ne DESSINE pas une etoile : la regle du projet est de
## n utiliser que les assets fournis (DEC-012).
const STAR_ICON: int = 3
const STAR_FULL_PX: float = 40.0
## Etoile VIDE : un ANNEAU creux, clair autour d un coeur sombre.
##
## Elle etait une piece de 30 px teintee rgba(0.22, 0.20, 0.18, 0.55) : sombre
## et translucide. Mesure sur la capture de l acte V : le fond d espace rend
## rgb(31,20,34) et la piece vide au mieux rgb(42,35,22), soit 1,14:1 — autant
## dire invisible, le plancher du projet etant 4,5:1.
## Une seule teinte ne peut pas servir a la fois le ciel clair de l acte I et le
## vide de l acte V : l anneau porte donc DEUX tons. Sur un fond sombre c est le
## liseret clair qui se voit, sur un fond clair c est le coeur sombre. Ce sont
## les deux tons du texte de la carte (`label_hud` : lettre claire, contour
## sombre), pour la meme raison.
##
## POURQUOI blanc et NOIR, et pas creme et violet sombre : c est la seule paire
## qui passe 4,5:1 sur TOUT fond. Le noir y arrive des que le fond depasse une
## luminance de 0,175, le blanc tant qu il reste sous 0,183 : les deux plages se
## recouvrent. Un creme (luminance 0,70) laisse un trou entre 0,12 et 0,175 —
## exactement les dalles des actes III et IV, mesurees a 4,04:1 avec le premier
## essai creme/violet (test `campaign_map`, fonds lus sur le disque).
##
## La FORME porte l information autant que la couleur (lecon du chantier E) :
## pleine = piece d or plus grande ; vide = anneau sans piece, plus petit. Un
## joueur daltonien compte ses etoiles au creux, pas a la teinte.
const STAR_EMPTY_PX: float = 28.0
const STAR_EMPTY_RIM_W: int = 4
const STAR_EMPTY_RIM: Color = Color(1.0, 1.0, 0.97)
const STAR_EMPTY_FILL: Color = Color(0.0, 0.0, 0.0)

## Anneau du medaillon jouable — l or du cahier des charges, demande mot pour mot
## (« des points de couleur jaune, qui sont grises quand pas encore debloques »).
## Le JAUNE reste le signal « jouable » : il est passe du disque a l anneau pour
## laisser la place a l illustration.
const DOT_OPEN: Color = Color(0.95, 0.80, 0.35)
const DOT_LOCKED: Color = Color(0.42, 0.42, 0.46)
## Fond du medaillon jouable : papier clair. Les boss Duelyst sont sombres et
## desatures ; sur un fond sombre leur silhouette disparaissait (piege deja paye
## sur les fonds de combat, voir la memoire « assets »). Le clair fait ressortir
## aussi bien un boss noir qu un guerrier rouge de Tiny Swords.
const MEDAL_FILL_OPEN: Color = Color(0.95, 0.90, 0.78)
## Fond du medaillon verrouille : gris moyen, sous une silhouette NOIRE. C est
## l idiome « ombre d un inconnu » : on devine la forme du boss (envie d y
## aller) sans ses couleurs (on n y est pas encore). Aucun cadenas dans les
## packs fournis, et un cadenas dessine par le code est interdit (DEC-012).
const MEDAL_FILL_LOCKED: Color = Color(0.56, 0.56, 0.60)
const SILHOUETTE_LOCKED: Color = Color(0.06, 0.05, 0.08)

## Les noms viennent de `docs/histoire.md`, sections 3 a 7, et doivent le rester.
##
## Ils dataient d une nomenclature en QUATRE actes abandonnee depuis : la carte
## annoncait "Le Monde volant" devant la foret de Nuri, et "Le Grand Cimetiere"
## devant les Sky Lands. Trois noms sur cinq nommaient le mauvais lieu — un
## joueur qui lit le document et joue le jeu voyait deux campagnes differentes.
const ACT_NAMES: Dictionary = {
	1: "ACTE I  -  La foret de Nuri",
	2: "ACTE II  -  Les Sky Lands",
	3: "ACTE III  -  Le cimetiere de Tombol",
	4: "ACTE IV  -  Le monde demoniaque",
	5: "ACTE V  -  L espace divin",
}

## Message d un acte encore vide. Il dit la VERITE (le contenu n existe pas
## encore) plutot que de laisser un ecran nu que le joueur lirait comme un bug.
const EMPTY_NOTICE: String = "Le voyage ne va pas encore jusqu ici."

## Etat calcule : acte -> [ids ordonnes], et id -> donnees du point.
var _by_act: Dictionary = {}          # int -> Array[StringName]
var _rows: Dictionary = {}            # int -> Array[Array[StringName]], par profondeur
var _nodes: Dictionary = {}           # StringName -> {level, pos, hit, row, stars, max_stars, enabled}
var _acts: Array[int] = []
var _act: int = 0

var _backdrop: TextureRect
var _title: Label
var _fork_lbl: Label
var _empty_lbl: Label
var _layer: Control                   # porte les points ; vide a chaque changement d acte
var _prev_btn: Button
var _next_btn: Button
var _buttons: Dictionary = {}         # StringName -> Button
var _signatures: Dictionary = {}      # StringName -> EnemyDef (ou absent)
## Forme des tuiles au moment ou les boutons de l acte affiche ont ete construits.
var _built_compact: bool = false

## Portraits recadres, partages entre toutes les cartes : le recadrage lit les
## pixels de la feuille, inutile de le refaire a chaque changement d acte.
static var _portrait_cache: Dictionary = {}   # String -> Texture2D


func _ready() -> void:
	clip_contents = true
	if _backdrop == null:
		rebuild()
	# Un changement de taille (rotation, redimension du menu) replace les points :
	# ils sont exprimes en fraction de la taille, pas en pixels figes.
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _on_resized() -> void:
	_layout_dots()


## Reconstruit entierement la carte depuis ContentDB + SaveData.
## Appelee a chaque `refresh()` du panneau : les etoiles et les verrous sont
## relus du profil, jamais memorises a cote.
func rebuild() -> void:
	_compute()
	_build_shell()
	# On rouvre sur l acte du niveau en cours : avec 5 actes, retomber sur l acte I
	# a chaque retour obligerait a quatre appuis pour revenir ou on en est.
	show_act(_act_of_current_level())


# --------------------------------------------------------------------------
# Donnees
# --------------------------------------------------------------------------


## Les niveaux dans l ORDRE OU ON LES JOUE, en suivant `next_levels`.
##
## Pourquoi pas l ordre des identifiants : la campagne a ete etendue en ajoutant
## des niveaux a la SUITE plutot qu en renumerotant — pour ne pas casser les
## sauvegardes — donc `lvl_17` se joue avant `lvl_03`. Trier sur le nom
## afficherait le parcours a l envers.
##
## Les niveaux orphelins (qu aucun chainage n atteint) sont ajoutes a la fin :
## une carte qui cache un niveau est pire qu une carte mal ordonnee.
func _ordre_de_jeu() -> Array[StringName]:
	var restants: Dictionary = {}
	for k in ContentDB.levels.keys():
		restants[StringName(k)] = true
	# Les DEPARTS : ceux que personne ne pointe.
	var pointes: Dictionary = {}
	for k in restants:
		var lv: LevelDef = ContentDB.levels[k]
		for suivant in lv.next_levels:
			pointes[StringName(suivant)] = true
	var departs: Array[StringName] = []
	for k in restants:
		if not pointes.has(k):
			departs.append(StringName(k))
	departs.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))

	var ordre: Array[StringName] = []
	var vus: Dictionary = {}
	# Parcours en largeur : un niveau qui ouvre plusieurs suites (l acte 4 est
	# un eventail) place ses enfants cote a cote, ce qui se lit bien sur la
	# carte.
	var file: Array[StringName] = departs.duplicate()
	var garde: int = 512
	while not file.is_empty() and garde > 0:
		garde -= 1
		var id: StringName = file.pop_front()
		if vus.has(id) or not ContentDB.levels.has(id):
			continue
		vus[id] = true
		ordre.append(id)
		var lv2: LevelDef = ContentDB.levels[id]
		for suivant in lv2.next_levels:
			var s: StringName = StringName(suivant)
			if not vus.has(s):
				file.append(s)
	# Les orphelins, en queue, pour qu aucun niveau ne disparaisse.
	var reste: Array[StringName] = []
	for k in restants:
		if not vus.has(k):
			reste.append(StringName(k))
	reste.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	ordre.append_array(reste)
	return ordre


func _compute() -> void:
	_by_act.clear()
	_nodes.clear()
	_acts.clear()

	# ORDRE DE LECTURE DE L ACTE. Mesure sur 4.4.stable : `sort()` sur l `Array`
	# NON TYPE rendu par `Dictionary.keys()` ne trie PAS des StringName de facon
	# fiable — il a rendu [lvl_02..lvl_07, lvl_01], et l acte I affichait « La
	# Tour des Sables » AU-DESSUS de « Les Marches du Temps » : le joueur lisait
	# son voyage a l envers. Le resultat dependait en plus du contexte d appel,
	# donc le defaut apparaissait a l ecran sans apparaitre au test.
	# On compare explicitement les valeurs en String : plus rien a deviner.
	# L ORDRE EST CELUI DU CHAINAGE, pas celui des identifiants.
	#
	# Le tri alphabetique marchait tant que les niveaux etaient ecrits dans
	# l ordre ou on les joue. La campagne s est etendue en AJOUTANT des niveaux
	# a la suite — `lvl_17` se joue avant `lvl_03` — et l acte II affichait donc
	# ses niveaux neufs sous les anciens, a l envers du parcours. Le joueur
	# lisait des noms dans un ordre qui n est pas le sien.
	#
	# On remonte donc `next_levels` depuis le premier niveau de chaque acte. Un
	# niveau qu aucun chainage n atteint est ajoute a la fin par ordre
	# d identifiant : il ne disparait jamais de la carte, meme si le contenu est
	# incoherent.
	var ids: Array[StringName] = _ordre_de_jeu()
	for id in ids:
		var lv: LevelDef = ContentDB.levels[id]
		var a: int = lv.act
		if not _by_act.has(a):
			_by_act[a] = []
		(_by_act[a] as Array).append(StringName(id))
		_nodes[StringName(id)] = {
			"level": lv,
			"act": a,
			"pos": Vector2.ZERO,
			"hit": Vector2(DOT_HIT_W, DOT_HIT_H),
			"row": 0,
			"stars": SaveData.objectives_done_count(lv),
			"max_stars": lv.objectives.size(),
			"enabled": SaveData.is_level_unlocked(id),
		}

	# Les actes affichables sont ceux du contenu UNION ceux de l histoire : l acte
	# 5 est ecrit mais n a pas encore de niveau, et le joueur doit voir qu il y a
	# une suite. C est exactement la demande « un acte ... reste visible ».
	var seen: Dictionary = {}
	for a in _by_act.keys():
		if int(a) > 0:
			seen[int(a)] = true
	for a in ACT_BACKDROPS.keys():
		seen[int(a)] = true
	_acts = []
	for a in seen.keys():
		_acts.append(int(a))
	_acts.sort()

	_compute_rows()
	_assign_signatures(ids)


## Range les niveaux de chaque acte par PROFONDEUR dans le chainage de l acte :
## rang 0 = les entrees (aucun niveau du meme acte n y mene), puis le plus long
## chemin depuis elles. Deux niveaux de meme rang sont ouverts par la meme
## victoire : ils forment une rangee, et leur ordre est libre.
##
## Pourquoi le plus LONG chemin et non le plus court : un niveau atteint a la
## fois directement et par un detour doit se poser APRES le detour, sinon il
## s afficherait au-dessus d un niveau qui le precede.
##
## Seuls comptent les liens INTERNES a l acte. Le pentacle de Tombol (acte III)
## ouvre les quatre demons de l acte IV : vus depuis l acte IV, ils n ont aucun
## predecesseur, donc ils sont tous au rang 0, cote a cote.
##
## L ordre DANS une rangee reste l ordre de jeu (`_ordre_de_jeu`), c est-a-dire
## celui que l auteur a ecrit dans `next_levels`.
func _compute_rows() -> void:
	_rows.clear()
	for a in _by_act.keys():
		var ids: Array = _by_act[a]
		var dans: Dictionary = {}
		var rang: Dictionary = {}
		for id in ids:
			dans[id] = true
			rang[id] = 0
		# Relaxation bornee : au plus une passe par niveau. Un cycle dans le
		# contenu (qui serait un defaut) ne peut donc pas boucler, et le rang
		# reste plafonne au nombre de niveaux de l acte.
		for _passe in ids.size():
			var bouge: bool = false
			for id in ids:
				var lv: LevelDef = _nodes[id]["level"]
				for suivant in lv.next_levels:
					var s: StringName = StringName(suivant)
					if s == id or not dans.has(s):
						continue
					var r: int = int(rang[id]) + 1
					if r > int(rang[s]) and r < ids.size():
						rang[s] = r
						bouge = true
			if not bouge:
				break
		# Rangs compactes : un rang sans niveau ne laisse pas de trou sur l ecran.
		var par_rang: Dictionary = {}
		for id in ids:
			var r2: int = int(rang[id])
			if not par_rang.has(r2):
				par_rang[r2] = []
			(par_rang[r2] as Array).append(id)
		var cles: Array = par_rang.keys()
		cles.sort()
		var rangees: Array = []
		for k in cles:
			rangees.append(par_rang[k])
		_rows[a] = rangees
		for ri in rangees.size():
			for id in rangees[ri]:
				_nodes[id]["row"] = ri


# --------------------------------------------------------------------------
# Le monstre signature de chaque niveau
# --------------------------------------------------------------------------

## Les candidats a l illustration d un niveau, du plus parlant au moins parlant :
##   1. les monstres de la vague de BOSS, du plus puissant au plus faible ;
##   2. a defaut, ceux des vagues de MINI-BOSS (niveaux d exploration) ;
##   3. a defaut, le pool du niveau (l acte V a deux niveaux sans vague ecrite).
## Seuls comptent les monstres qui ont une feuille : un projectile ou une cle
## inconnue ne donneraient rien a montrer. Chaque silhouette n apparait qu une
## fois (deux entrees du meme monstre dans la vague de boss ne sont pas deux
## choix).
static func signature_candidates(lv: LevelDef) -> Array[EnemyDef]:
	var boss: Array[EnemyDef] = []
	var mini: Array[EnemyDef] = []
	for w in lv.waves:
		if w == null:
			continue
		if w.is_boss:
			boss.append_array(w.enemy_defs())
		elif w.is_miniboss:
			mini.append_array(w.enemy_defs())
	var pool: Array[EnemyDef] = []
	pool.append_array(lv.enemy_pool)
	var out: Array[EnemyDef] = []
	var vus: Dictionary = {}
	for palier in [boss, mini, pool]:
		var tri: Array[EnemyDef] = []
		for e: EnemyDef in palier:
			if not _montrable(e):
				continue
			if vus.has(e.id):
				continue
			vus[e.id] = true
			tri.append(e)
		# Tri STABLE a la main : `sort_custom` ne garantit pas l ordre des egaux,
		# et deux boss de meme puissance (lvl_02 en a deux) doivent toujours
		# rendre le meme, celui que l auteur a ecrit en premier.
		for i in range(1, tri.size()):
			var cle: EnemyDef = tri[i]
			var j: int = i - 1
			while j >= 0 and tri[j].power < cle.power:
				tri[j + 1] = tri[j]
				j -= 1
			tri[j + 1] = cle
		out.append_array(tri)
	return out


## Palier du meilleur candidat : 0 boss, 1 mini-boss, 2 pool, 3 rien.
static func _signature_tier(lv: LevelDef) -> int:
	for palier in 2:
		for w in lv.waves:
			if w == null:
				continue
			# Palier 0 : vagues de boss. Palier 1 : vagues de mini-boss seulement.
			var vise: bool = w.is_boss if palier == 0 else (w.is_miniboss and not w.is_boss)
			if not vise:
				continue
			for e in w.enemy_defs():
				if _montrable(e):
					return palier
	for e in lv.enemy_pool:
		if _montrable(e):
			return 2
	return 3


static func _montrable(e: EnemyDef) -> bool:
	return e != null and not e.projectile and AnimCatalog.has(e.anim_key)


## Choisit le monstre de chaque niveau.
##
## La regle dure : DEUX NIVEAUX D UNE MEME PAGE N ONT JAMAIS LA MEME SILHOUETTE.
## Une page ne montre qu un acte, et c est la qu on doit reconnaitre un niveau
## d un coup d oeil. L acte V en a besoin : deux de ses niveaux n ont pas de
## boss et leur monstre le plus fort est le Juggernaut du troisieme.
##
## La regle douce : eviter aussi de repeter une silhouette D UN ACTE A L AUTRE,
## mais sans jamais retirer son boss a un niveau de boss. Le boss EST l identite
## du niveau ; lui substituer un sbire pour eviter un doublon avec une autre page
## (ou le fond et le titre different deja) ferait mentir l illustration.
##
## Ordre de choix : les niveaux a boss d abord, puis a mini-boss, puis les
## autres — chacun dans l ordre de jeu. Ainsi un niveau sans boss s efface
## devant le boss d un niveau voisin, jamais l inverse.
func _assign_signatures(ordre: Array[StringName]) -> void:
	_signatures.clear()
	var file: Array[StringName] = []
	for palier in 4:
		for id in ordre:
			if _signature_tier(_nodes[id]["level"]) == palier:
				file.append(id)
	var pris: Dictionary = {}          # anim_key -> true, tout le jeu
	var pris_acte: Dictionary = {}     # acte -> {anim_key: true}
	for id in file:
		var lv: LevelDef = _nodes[id]["level"]
		var cands: Array[EnemyDef] = signature_candidates(lv)
		if cands.is_empty():
			continue
		var acte: int = int(_nodes[id]["act"])
		if not pris_acte.has(acte):
			pris_acte[acte] = {}
		var deja: Dictionary = pris_acte[acte]
		var choix: EnemyDef = null
		# 1) Parmi les candidats de TETE (meme puissance que le meilleur, tous du
		#    meme palier puisque la liste est rangee par palier), une silhouette
		#    encore inedite dans tout le jeu.
		var tete: int = cands[0].power
		for c in cands:
			if c.power != tete:
				break
			if not pris.has(String(c.anim_key)):
				choix = c
				break
		# 2) Sinon le meilleur candidat absent de CETTE page. Un boss dont la
		#    feuille sert deja sur un autre acte garde donc son boss.
		if choix == null:
			for c in cands:
				if not deja.has(String(c.anim_key)):
					choix = c
					break
		# 3) Contenu pathologique (tout est deja pris sur la page) : on montre
		#    quand meme le boss plutot qu un medaillon vide.
		if choix == null:
			choix = cands[0]
		_signatures[id] = choix
		pris[String(choix.anim_key)] = true
		deja[String(choix.anim_key)] = true


## Le monstre dont la silhouette illustre ce niveau, ou null si le niveau n en
## a aucun (le medaillon reste alors vide, mais present).
func signature_of(level_id: StringName) -> EnemyDef:
	return _signatures.get(level_id)


## Premiere pose de la silhouette, RECADREE sur ses pixels opaques.
##
## Pourquoi recadrer : les cases des feuilles sont loin d etre pleines (Blood
## Monster occupe 20 % de sa case, voir la memoire « assets »). Mettre la case
## entiere dans le medaillon donnait un point au milieu d un disque. On mesure
## le rectangle opaque de la pose AFFICHEE, pas l occupation moyenne du
## catalogue, qui est mesuree sur la marche et deborderait ou rognerait ici.
##
## Pose : `idle` si la feuille en a une (le monstre au repos, de face ou de
## profil selon le pack), sinon `walk`. Sans pixels lisibles (rendu factice en
## headless), on rend la case brute : le medaillon reste construit et testable.
static func portrait(anim_key: StringName) -> Texture2D:
	var k: String = String(anim_key)
	if _portrait_cache.has(k):
		return _portrait_cache[k]
	var brut: Texture2D = null
	if AnimCatalog.is_static(anim_key):
		brut = AnimCatalog.static_texture(anim_key)
	else:
		var sf: SpriteFrames = AnimCatalog.frames(anim_key)
		if sf != null:
			var anim: StringName = &"idle" if sf.has_animation(&"idle") else &"walk"
			if not sf.has_animation(anim):
				var noms: PackedStringArray = sf.get_animation_names()
				anim = StringName(noms[0]) if not noms.is_empty() else &""
			if anim != &"" and sf.get_frame_count(anim) > 0:
				brut = sf.get_frame_texture(anim, 0)
	var out: Texture2D = brut
	if brut != null:
		var img: Image = brut.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				# Copie avant de decompresser : on ne touche jamais l image
				# que le moteur partage avec la texture source.
				img = img.duplicate()
				img.decompress()
			var r: Rect2i = img.get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				out = ImageTexture.create_from_image(img.get_region(r))
	_portrait_cache[k] = out
	return out


func _act_of_current_level() -> int:
	var cur: StringName = SaveData.current_level()
	if _nodes.has(cur):
		return int(_nodes[cur]["act"])
	return _acts[0] if not _acts.is_empty() else 1


# --------------------------------------------------------------------------
# Vue : la coquille (fond, titre, fleches) ne se reconstruit qu au rebuild ;
# seuls les POINTS changent quand on tourne les pages.
# --------------------------------------------------------------------------

func _build_shell() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()

	# 1) le fond de l acte, en pleine surface. COVERED : le fond est compose pour
	# 1080x1920 et la zone de contenu du menu est plus courte ; l etirer libre
	# ecraserait les arbres. On rogne plutot que de deformer.
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# 2) le titre de l acte. Contour sombre (label_hud) : le fond est un decor
	# PEINT dont on ne maitrise pas la couleur sous le texte — l acte I est un
	# ciel clair, l acte III une salle sombre. C est le piege connu du projet.
	_title = UiTheme.label_hud("", UiTheme.FONT_BODY, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 24.0
	_title.offset_bottom = 90.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	# 2 bis) l avis d ordre libre, sous le titre, seulement sur un acte a
	# embranchement. Dans la bande decoree et non sur le sol : le sol est a
	# l eventail, et un texte pose entre deux rangees se lirait comme le nom
	# d un niveau.
	_fork_lbl = UiTheme.label_hud(FORK_NOTICE, UiTheme.FONT_SMALL,
		Color(1.0, 0.97, 0.90), HORIZONTAL_ALIGNMENT_CENTER, true)
	_fork_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_fork_lbl.offset_left = SIDE_MARGIN * 0.5
	_fork_lbl.offset_right = -SIDE_MARGIN * 0.5
	_fork_lbl.offset_top = 96.0
	_fork_lbl.offset_bottom = 190.0
	_fork_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fork_lbl.visible = false
	add_child(_fork_lbl)

	# 3) la couche des points, videe a chaque changement d acte.
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

	# 4) le message d acte vide, au centre du sol.
	_empty_lbl = UiTheme.label_hud(EMPTY_NOTICE, UiTheme.FONT_BODY,
		Color(0.88, 0.86, 0.92), HORIZONTAL_ALIGNMENT_CENTER, true)
	_empty_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_empty_lbl.anchor_left = 0.12
	_empty_lbl.anchor_right = 0.88
	_empty_lbl.anchor_top = 0.45
	_empty_lbl.anchor_bottom = 0.45
	_empty_lbl.offset_left = 0.0
	_empty_lbl.offset_right = 0.0
	_empty_lbl.offset_bottom = 140.0
	_empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_lbl.visible = false
	add_child(_empty_lbl)

	# 5) les fleches, PAR-DESSUS tout le reste : ce sont elles qui doivent gagner
	# le toucher sur les bords, jamais un point qui deborderait.
	_prev_btn = _make_arrow("<", false)
	_next_btn = _make_arrow(">", true)


## Une fleche de bord. Ancrage sur le bord et centrage vertical : elle reste au
## meme endroit quelle que soit la hauteur reelle de la zone de contenu.
func _make_arrow(glyph: String, at_right: bool) -> Button:
	var b := Button.new()
	b.text = glyph
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ARROW_W, ARROW_H)
	b.add_theme_font_size_override(&"font_size", 64)
	# Bois du pack, comme les autres commandes de navigation du menu : une fleche
	# sans fond disparaitrait sur la bande decoree de certains actes.
	b.add_theme_stylebox_override(&"normal", UiTheme.tex_box("wood", 40, 6.0))
	b.add_theme_stylebox_override(&"hover", UiTheme.tex_box("wood", 40, 6.0, Color(1.15, 1.15, 1.15)))
	b.add_theme_stylebox_override(&"pressed", UiTheme.tex_box("wood", 40, 6.0, Color(0.8, 0.8, 0.8)))
	b.add_theme_stylebox_override(&"disabled", UiTheme.tex_box("wood", 40, 6.0, Color(0.5, 0.5, 0.55, 0.6)))
	b.add_theme_color_override(&"font_color", UiTheme.GOLD)
	b.add_theme_color_override(&"font_disabled_color", Color(0.6, 0.58, 0.55, 0.7))
	b.set_anchors_preset(Control.PRESET_CENTER_RIGHT if at_right else Control.PRESET_CENTER_LEFT)
	b.offset_top = -ARROW_H * 0.5
	b.offset_bottom = ARROW_H * 0.5
	if at_right:
		b.offset_left = -ARROW_W - 8.0
		b.offset_right = -8.0
	else:
		b.offset_left = 8.0
		b.offset_right = ARROW_W + 8.0
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		if at_right: go_next() else: go_previous())
	add_child(b)
	return b


# --------------------------------------------------------------------------
# Navigation entre actes
# --------------------------------------------------------------------------

func acts() -> Array[int]:
	return _acts.duplicate()


func current_act() -> int:
	return _act


func act_title(act: int) -> String:
	return String(ACT_NAMES.get(act, "ACTE %d" % act))


func empty_notice() -> String:
	return EMPTY_NOTICE


func levels_in_act(act: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _by_act.get(act, []):
		out.append(StringName(id))
	return out


## Les rangees de l acte, de haut en bas (voir `_compute_rows`).
func rows_in_act(act: int) -> Array:
	var out: Array = []
	for r in _rows.get(act, []):
		out.append((r as Array).duplicate())
	return out


## Vrai si l acte contient au moins une rangee de plusieurs niveaux, c est-a-dire
## un endroit ou le joueur choisit l ordre.
func act_has_fork(act: int) -> bool:
	for r in _rows.get(act, []):
		if (r as Array).size() > 1:
			return true
	return false


func fork_notice() -> String:
	return FORK_NOTICE


func fork_notice_visible() -> bool:
	return _fork_lbl != null and _fork_lbl.visible


## Un acte est « ouvert » des qu UN de ses niveaux est jouable. Ferme, il reste
## affiche et atteignable : le joueur doit voir qu il y a une suite.
func act_is_open(act: int) -> bool:
	for id in levels_in_act(act):
		if bool(_nodes[id]["enabled"]):
			return true
	return false


func can_go_previous() -> bool:
	return _acts.find(_act) > 0


func can_go_next() -> bool:
	var i: int = _acts.find(_act)
	return i >= 0 and i < _acts.size() - 1


## Les bornes sont INERTES plutot que bouclantes : un joueur qui appuie une fois
## de trop a droite ne doit pas se retrouver a l acte I sans avoir rien compris.
func go_next() -> void:
	if can_go_next():
		show_act(_acts[_acts.find(_act) + 1])


func go_previous() -> void:
	if can_go_previous():
		show_act(_acts[_acts.find(_act) - 1])


func show_act(act: int) -> void:
	_act = act
	if _backdrop == null:
		return
	_backdrop.texture = SheetLib.texture(BACKDROP_DIR + backdrop_for_act(act) + ".png")
	_title.text = act_title(act)
	_fork_lbl.visible = act_has_fork(act)
	if _prev_btn != null:
		_prev_btn.disabled = not can_go_previous()
		_next_btn.disabled = not can_go_next()
	_build_dots()


## Le fond de l acte se LIT dans les niveaux de cet acte, pas dans une table de
## l UI : combat et carte montrent alors forcement le meme lieu. La table
## `ACT_BACKDROPS` n est qu un repli pour un acte encore sans niveau.
func backdrop_for_act(act: int) -> String:
	for id in levels_in_act(act):
		var lv: LevelDef = _nodes[id]["level"]
		if lv.backdrop != "":
			return lv.backdrop
	return String(ACT_BACKDROPS.get(act, FALLBACK_BACKDROP))


# --------------------------------------------------------------------------
# Les points
# --------------------------------------------------------------------------

## Place les points de l acte courant sur le sol du fond. Le calcul est separe de
## la construction pour qu un simple redimensionnement les replace sans
## reconstruire les boutons (et donc sans recasser les connexions).
func _layout_dots() -> void:
	# La forme des tuiles (large ou d eventail) depend de la hauteur disponible :
	# si un redimensionnement la fait basculer, les tuiles construites n ont plus
	# la bonne forme et il faut les refaire, pas seulement les deplacer.
	if not _buttons.is_empty() and _compact_for(_act) != _built_compact:
		_build_dots()
		return
	_layout_act(_act)


## Vrai si toutes les rangees de l acte passent en tuiles d eventail a la taille
## actuelle de la carte (voir `_all_compact`).
func _compact_for(act: int) -> bool:
	var h: float = maxf(size.y, 1.0)
	return _all_compact(_rows.get(act, []), h * (GROUND_BOTTOM - GROUND_TOP))


## Calcule la place de chaque niveau d un acte. Ne deplace que les boutons de
## l acte AFFICHE ; pour un autre acte, seules les positions sont memorisees
## (c est ce que lit `position_of`).
func _layout_act(act: int) -> void:
	var rows: Array = _rows.get(act, [])
	if rows.is_empty():
		return
	var w: float = maxf(size.x, 1.0)
	var h: float = maxf(size.y, 1.0)
	# Repartition sur la hauteur du sol : la premiere rangee de l acte en haut, la
	# derniere en bas — on lit l acte dans le sens de la marche, du fond vers soi.
	var top: float = h * GROUND_TOP
	var bottom: float = h * GROUND_BOTTOM
	var fourche: bool = act_has_fork(act)
	var tout_compact: bool = _all_compact(rows, bottom - top)

	# Chaque rangee recoit une bande proportionnelle a ce qu elle doit loger :
	# une tuile large (170) ou une tuile d eventail (280, plus la cambrure). Sur
	# un acte lineaire toutes les bandes sont egales, donc la repartition est
	# exactement l ancienne.
	var besoins: Array[float] = []
	var total: float = 0.0
	for r in rows.size():
		var k: int = (rows[r] as Array).size()
		var compact: bool = tout_compact or k > 1
		var besoin: float = (FAN_HIT_H if compact else DOT_HIT_H) + ROW_GAP
		if k >= 3:
			besoin += FAN_ARC
		besoins.append(besoin)
		total += besoin
	var echelle: float = (bottom - top) / maxf(total, 1.0)

	# Zigzag horizontal des rangees d UN niveau sur un acte LINEAIRE : deux
	# niveaux d affilee au meme x donneraient une colonne, ou le nom du second
	# passerait sous le point du premier. L amplitude est bornee par SIDE_MARGIN
	# pour ne jamais passer sous une fleche.
	#
	# UN SEUL niveau dans l acte : pas de zigzag du tout. Le decaler le collait
	# contre une fleche, ce qui etait pire que la colonne que le zigzag cherche a
	# eviter. Vu sur la capture `map_acte4.png`, quand l acte IV n avait qu un
	# niveau.
	#
	# Sur un acte a EMBRANCHEMENT, pas de zigzag non plus : le tronc reste au
	# centre et l eventail s ouvre de part et d autre. Un tronc qui serpente
	# ferait lire un eventail de plus la ou il n y en a pas.
	var amp: float = 0.0
	if rows.size() > 1 and not fourche:
		amp = minf(w * 0.16, maxf((w - 2.0 * SIDE_MARGIN - DOT_HIT_W) * 0.5, 0.0))

	var y0: float = top
	for r in rows.size():
		var rangee: Array = rows[r]
		var k: int = rangee.size()
		var bande: float = besoins[r] * echelle
		var cy: float = y0 + bande * 0.5
		y0 += bande
		if k == 1 and not tout_compact:
			var x: float = w * 0.5 + (amp if r % 2 == 1 else -amp)
			_place(rangee[0], Vector2(x, cy), Vector2(DOT_HIT_W, DOT_HIT_H))
			continue
		# Rangee d eventail : colonnes egales entre les fleches, centrees.
		var col: float = minf((w - 2.0 * SIDE_MARGIN) / float(k), FAN_COL_MAX)
		var x0: float = w * 0.5 - col * float(k) * 0.5
		var hit := Vector2(maxf(col - FAN_GAP, DOT_SIZE), FAN_HIT_H)
		# Cambrure en parabole, recentree sur zero pour que la rangee reste au
		# milieu de sa bande : les bords descendent, le centre monte.
		var moyenne: float = 0.0
		for c in k:
			moyenne += _arc_t2(c, k)
		moyenne /= float(k)
		for c in k:
			var creux: float = (_arc_t2(c, k) - moyenne) * FAN_ARC if k >= 3 else 0.0
			_place(rangee[c], Vector2(x0 + col * (float(c) + 0.5), cy + creux), hit)


## Carre de l ecart au centre de la colonne `c` sur `k`, ramene a [0, 1].
func _arc_t2(c: int, k: int) -> float:
	if k <= 1:
		return 0.0
	var t: float = (float(c) - float(k - 1) * 0.5) / (float(k - 1) * 0.5)
	return t * t


## Toutes les rangees d un acte a embranchement passent en tuiles d eventail
## (nom sous le medaillon) QUAND LA HAUTEUR LE PERMET. Pourquoi : le niveau ou
## l eventail converge doit etre centre SOUS lui ; en tuile large, son medaillon
## serait decale de 175 px a gauche (le nom occupe la droite) et la convergence
## ne se lirait plus. L acte III (cinq niveaux sur quatre rangees) n a pas la
## hauteur : seule sa rangee double y passe en eventail.
func _all_compact(rows: Array, hauteur: float) -> bool:
	var fourche: bool = false
	var besoin: float = 0.0
	for r in rows:
		var k: int = (r as Array).size()
		fourche = fourche or k > 1
		besoin += FAN_HIT_H + ROW_GAP + (FAN_ARC if k >= 3 else 0.0)
	return fourche and besoin <= hauteur


func _place(id: StringName, pos: Vector2, hit: Vector2) -> void:
	_nodes[id]["pos"] = pos
	_nodes[id]["hit"] = hit
	var b: Button = _buttons.get(id) if int(_nodes[id]["act"]) == _act else null
	if b != null:
		b.custom_minimum_size = hit
		b.size = hit
		b.position = pos - hit * 0.5


func _build_dots() -> void:
	if _layer == null:
		return
	for c in _layer.get_children():
		_layer.remove_child(c)
		c.queue_free()
	_buttons.clear()

	var ids: Array[StringName] = levels_in_act(_act)
	_empty_lbl.visible = ids.is_empty()
	_built_compact = _compact_for(_act)
	for id in ids:
		_add_dot(id)
	_layout_act(_act)


## Vrai si le niveau se dessine en tuile d EVENTAIL (nom sous le medaillon).
func _is_fan_tile(id: StringName) -> bool:
	if _built_compact:
		return true
	var act: int = int(_nodes[id]["act"])
	var rows: Array = _rows.get(act, [])
	var r: int = int(_nodes[id]["row"])
	return r < rows.size() and (rows[r] as Array).size() > 1


## Un niveau = un Button transparent qui porte le MEDAILLON, le nom et les
## etoiles. Le bouton est la racine pour que TOUTE l etiquette reponde au
## doigt, pas seulement le medaillon. Deux formes :
##
##   tuile LARGE (500x170, acte lineaire)     tuile d EVENTAIL (colonne x 280)
##   .------.                                       .------.
##  ( boss   )  Nom du niveau                      ( boss   )
##  (  en    )  sur deux lignes                     `------'
##   `------'   o o o            <- etoiles       Nom du niveau
##                                                   o o o
func _add_dot(id: StringName) -> void:
	var data: Dictionary = _nodes[id]
	var lv: LevelDef = data["level"]
	var enabled: bool = bool(data["enabled"])
	var eventail: bool = _is_fan_tile(id)

	var b := Button.new()
	b.name = "Niveau_%s" % id
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(DOT_SIZE, FAN_HIT_H) if eventail else Vector2(DOT_HIT_W, DOT_HIT_H)
	b.custom_minimum_size = b.size
	b.disabled = not enabled
	# Un bouton desactive ne montre pas d infobulle ; on met la raison dans le
	# nom accessible, ce qui sert aussi au debogage des captures.
	b.tooltip_text = lv.display_name if enabled else "Verrouille"
	_layer.add_child(b)
	_buttons[id] = b

	var row: BoxContainer
	if eventail:
		row = VBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override(&"separation", 4)
	else:
		row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override(&"separation", 14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var medal: Control = _medallion(id, enabled)
	if eventail:
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN if eventail else BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override(&"separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vb)

	# LE NOM, en contour sombre : le fond est peint et sa couleur sous le texte
	# n est pas maitrisee. Un texte clair sans contour disparait sur le ciel de
	# l acte I — c est le piege deja paye sur le HUD.
	#
	# Le nom est ecrit MEME VERROUILLE, juste plus terne. Le testeur demande
	# « on voit les noms des etapes » : masquer en « ? ? ? » repondrait a la
	# question inverse, et une carte dont les etapes n ont pas de nom ne donne
	# plus envie d y aller.
	#
	# Retour a la ligne AUTORISE : a cote du medaillon il reste ~330 px, et
	# « Proteger le dirigeable » n y tient pas sur une ligne. Le coupe-mot par
	# lettre (piege connu de AUTOWRAP_WORD_SMART) ne mord pas ici : aucun mot de
	# nom de niveau ne depasse la colonne.
	#
	# En tuile d EVENTAIL, le nom est centre sous le medaillon, sur la largeur
	# de la colonne (~175 px pour quatre demons) : « La forge de Vharn » y tient
	# en deux lignes, et le mot le plus long (« Kaltek ») loin de la limite.
	var name_lbl: Label = UiTheme.label_hud(lv.display_name, UiTheme.FONT_SMALL,
		Color(1.0, 0.97, 0.90) if enabled else Color(0.74, 0.74, 0.78),
		HORIZONTAL_ALIGNMENT_CENTER if eventail else HORIZONTAL_ALIGNMENT_LEFT, true)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(name_lbl)

	# LES ETOILES : une par objectif (jamais du texte ASCII, qui ne se lit pas
	# comme une note). Pleines = pieces d or, vides = anneaux creux.
	var stars: int = int(data["stars"])
	var star_row := HBoxContainer.new()
	star_row.name = "Etoiles"
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER if eventail else BoxContainer.ALIGNMENT_BEGIN
	star_row.add_theme_constant_override(&"separation", 8)
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(star_row)
	for i in int(data["max_stars"]):
		star_row.add_child(_star(i < stars))

	if enabled:
		var idx: StringName = id
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			level_pressed.emit(idx))


## Une etoile de la rangee.
##
## HISTORIQUE, mesure et non impression : sur la capture de l acte I, une
## pastille acquise rendait rgb(171,148,54) et une vide teintee en gris
## rgb(149,152,78) — la vide etait donc devenue un creux sombre et translucide,
## qui a son tour disparaissait sur l espace de l acte V (1,14:1, voir
## STAR_EMPTY_*). La vide est desormais un ANNEAU a deux tons ; la pleine reste
## la piece d or du pack, plus grande.
func _star(acquise: bool) -> Control:
	if acquise:
		var s: TextureRect = UiTheme.icon(STAR_ICON, STAR_FULL_PX)
		s.name = "EtoilePleine"
		s.modulate = Color(1.0, 0.88, 0.35)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return s
	var creux := Panel.new()
	creux.name = "EtoileVide"
	creux.custom_minimum_size = Vector2(STAR_EMPTY_PX, STAR_EMPTY_PX)
	creux.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	creux.mouse_filter = Control.MOUSE_FILTER_IGNORE
	creux.add_theme_stylebox_override(&"panel", UiTheme.flat_box(STAR_EMPTY_FILL,
		int(STAR_EMPTY_PX * 0.5), 0.0, STAR_EMPTY_RIM, STAR_EMPTY_RIM_W))
	return creux


## Le medaillon : un disque a anneau epais, la silhouette du monstre signature
## dedans.
##
## JOUABLE : fond clair, anneau OR, silhouette en couleurs.
## VERROUILLE : fond gris, anneau gris, silhouette NOIRE. Trois indices
## redondants et non une seule teinte : un joueur daltonien lit l etat a la
## silhouette pleine ou vide, pas a la couleur de l anneau.
func _medallion(id: StringName, enabled: bool) -> Control:
	var medal := Panel.new()
	medal.name = "Medaillon"
	medal.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bord sombre SOUS l anneau colore : sur le ciel clair de l acte I comme sur
	# les dalles sombres de l acte III, c est le contour sombre qui detache le
	# medaillon du fond peint. Deux StyleBox imbriquees : l anneau or (ou gris)
	# dans un liseret sombre.
	medal.add_theme_stylebox_override(&"panel", UiTheme.flat_box(
		Color(0.10, 0.07, 0.05, 0.95), int(DOT_SIZE * 0.5), 0.0))
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 4.0
	ring.offset_top = 4.0
	ring.offset_right = -4.0
	ring.offset_bottom = -4.0
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override(&"panel", UiTheme.flat_box(
		MEDAL_FILL_OPEN if enabled else MEDAL_FILL_LOCKED,
		int(DOT_SIZE * 0.5), 0.0, DOT_OPEN if enabled else DOT_LOCKED, 8))
	medal.add_child(ring)

	var sig: EnemyDef = signature_of(id)
	if sig != null:
		var art := TextureRect.new()
		art.name = "Silhouette"
		art.texture = portrait(sig.anim_key)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var marge: float = DOT_SIZE * (1.0 - PORTRAIT_FILL) * 0.5
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.offset_left = marge
		art.offset_top = marge
		art.offset_right = -marge
		art.offset_bottom = -marge
		# Jouable : la teinte du monstre en jeu (MODULATE du catalogue), pour
		# que la silhouette du medaillon soit celle que le joueur affrontera.
		# Verrouille : une ombre, qui garde la forme et tait les couleurs.
		art.modulate = AnimCatalog.modulate_for(sig.id) if enabled else SILHOUETTE_LOCKED
		medal.add_child(art)

	# Le niveau ou en est le joueur porte un halo : sur un acte de 4 medaillons
	# il faut un repere « tu es ici », sinon on cherche.
	if enabled and id == SaveData.current_level():
		var here := Panel.new()
		here.name = "IciHalo"
		here.add_theme_stylebox_override(&"panel", UiTheme.flat_box(
			Color.TRANSPARENT, int(DOT_SIZE * 0.62), 0.0, Color(1.0, 0.95, 0.6, 0.85), 5))
		here.set_anchors_preset(Control.PRESET_FULL_RECT)
		here.offset_left = -10.0
		here.offset_top = -10.0
		here.offset_right = 10.0
		here.offset_bottom = 10.0
		here.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medal.add_child(here)
	return medal


## Le medaillon affiche pour un niveau de l acte courant (null hors page).
## Expose pour les tests : ils verifient ce que le joueur VOIT, pas seulement
## le choix fait dans `_signatures`.
func medallion_for(level_id: StringName) -> Control:
	var b: Button = _buttons.get(level_id)
	if b == null:
		return null
	return b.find_child("Medaillon", true, false) as Control


# --------------------------------------------------------------------------
# Lecture (utilisee par le panneau et par les tests)
# --------------------------------------------------------------------------

func node_count() -> int:
	return _nodes.size()


func has_node_for(level_id: StringName) -> bool:
	return _nodes.has(level_id)


func label_for(level_id: StringName) -> String:
	if not _nodes.has(level_id):
		return ""
	return (_nodes[level_id]["level"] as LevelDef).display_name


## Position du point. Pour un niveau qui n est pas sur l acte affiche, on calcule
## la position qu il AURAIT : les tests verifient le placement de tous les actes
## sans avoir a tourner les pages, et le resultat est le meme.
func position_of(level_id: StringName) -> Vector2:
	if not _nodes.has(level_id):
		return Vector2.ZERO
	var pos: Vector2 = _nodes[level_id]["pos"]
	if pos != Vector2.ZERO:
		return pos
	_layout_act(int(_nodes[level_id]["act"]))
	return _nodes[level_id]["pos"]


## La cible tactile du niveau, dans le repere de la carte : ce que le doigt peut
## toucher. Calculee comme `position_of` pour un acte non affiche.
func hit_rect_of(level_id: StringName) -> Rect2:
	if not _nodes.has(level_id):
		return Rect2()
	var p: Vector2 = position_of(level_id)
	var hit: Vector2 = _nodes[level_id]["hit"]
	return Rect2(p - hit * 0.5, hit)


## Les etoiles affichees pour un niveau de l acte courant, dans l ordre (vide si
## le niveau n est pas sur la page). Pour les tests : ils jugent ce qui est
## DESSINE, pas le compteur.
func star_nodes_for(level_id: StringName) -> Array[Control]:
	var out: Array[Control] = []
	var b: Button = _buttons.get(level_id)
	if b == null:
		return out
	var rangee: Node = b.find_child("Etoiles", true, false)
	if rangee == null:
		return out
	for c in rangee.get_children():
		out.append(c as Control)
	return out


func stars_for(level_id: StringName) -> int:
	return int(_nodes.get(level_id, {}).get("stars", 0))


func max_stars_for(level_id: StringName) -> int:
	return int(_nodes.get(level_id, {}).get("max_stars", 0))


func is_enabled(level_id: StringName) -> bool:
	return bool(_nodes.get(level_id, {}).get("enabled", false))


## Amene le joueur sur l acte d un niveau. Remplace l ancien `focus_level`, qui
## faisait defiler une carte verticale qui n existe plus.
func focus_level(level_id: StringName) -> void:
	if _nodes.has(level_id):
		show_act(int(_nodes[level_id]["act"]))

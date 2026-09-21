extends Node
## Generateur des POUVOIRS PASSIFS — version 2.
##
## Fichier separe de make_content.gd a dessein : les passifs sont une famille a
## part (hors deck, equipes, actifs seulement au-dela d une vitesse) et ce
## decoupage permet de les regenerer sans toucher au reste du contenu.
##
## DEUX ECHELLES, et elles montent ENSEMBLE (demande du testeur du 21 septembre) :
##
##   - le SEUIL mesure la PUISSANCE. Plus un passif est fort, plus le jeu doit
##     aller vite pour qu il s allume. C est ce qui empeche un passif de
##     transformer une partie prudente en promenade : pour en profiter il faut
##     deja avoir pris le risque de monter la jauge — et un seul coup recu
##     l eteint.
##   - la RARETE mesure la COMPLEXITE. Une commune fait une chose simple et
##     constante ; une legendaire renverse une regle du jeu.
##
## Bornes verrouillees par tests/unit/test_passives.gd :
##   commune 105-135 · rare 136-199 · epique 200-275 · legendaire 276+
##
## Usage : Godot --headless --path . tools/make_passives.tscn
##         (PAS --script : ce script etend Node et a besoin des autoloads)

const DIR := "res://resources/cards/passive/"


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_nettoyer()
	_passives()
	print("PASSIVES_OK")
	get_tree().quit(0)


## Les .tres d une generation precedente qui ne sont plus produits resteraient
## dans ContentDB et l AUDIT les verrait comme du contenu mort. On repart propre.
func _nettoyer() -> void:
	var d: DirAccess = DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".tres"):
			d.remove(f)


func _spec(key: String, magnitude: float) -> EffectSpec:
	var s := EffectSpec.new()
	s.key = StringName(key)
	s.magnitude = magnitude
	return s


## `seuil` : pourcentage de vitesse a partir duquel le passif agit.
## `cast_time` reste renseigne bien qu un passif ne s incante plus : la fiche du
## grimoire affiche le champ, et un 0 s y lirait comme un bug.
func _passive(id: String, dname: String, desc: String, rarity: GameEnums.Rarity,
		seuil: int, key: String, magnitude: float) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = dname
	c.description = desc
	c.rarity = rarity
	c.base_cast_time = 0.0
	c.speed_threshold = seuil
	c.targeting = GameEnums.Targeting.NONE
	c.effects = [_spec(key, magnitude)]
	c.is_passive = true
	return c


func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Sauvegarde impossible : %s (err %d)" % [path, err])
	else:
		print("  ecrit ", path)


func _emit(c: SpellCard) -> void:
	_save(c, DIR + String(c.id) + ".tres")


func _passives() -> void:
	# ---------------------------------------------------------------- COMMUNES
	# Effets SIMPLES et CONSTANTS, seuils bas (105-135). Ce sont les passifs
	# qu un joueur garde en fond de barre : ils ne demandent rien a comprendre et
	# s allument des la premiere montee naturelle de la jauge.

	_emit(_passive("pass_celerity", "Celerite",
		"Au-dela de 110 % de vitesse : chaque sort se lance 0,3 s plus vite.",
		GameEnums.Rarity.COMMON, 110, "passive_cast_haste", 0.3))

	_emit(_passive("pass_scholar", "Erudition",
		"Au-dela de 115 % de vitesse : +30 % d experience gagnee.",
		GameEnums.Rarity.COMMON, 115, "passive_xp_boost", 30.0))

	_emit(_passive("pass_quickhand", "Main leste",
		"Au-dela de 120 % de vitesse : la pioche va 35 % plus vite.",
		GameEnums.Rarity.COMMON, 120, "passive_draw_haste", 35.0))

	# Le mur ne tue rien : il ACHETE DU TEMPS. C est le passif commun le plus
	# lisible a l ecran — on voit exactement ce qu il fait, et quand il s eteint.
	_emit(_passive("pass_bark", "Ecorce vive",
		"Au-dela de 130 % de vitesse : un mur de ronces pousse a chaque vague.",
		GameEnums.Rarity.COMMON, 130, "passive_start_wall", 1.0))

	# ------------------------------------------------------------------- RARES
	# Une regle en PLUS, comprehensible d un coup mais qui demande d y penser.
	# Seuils 140-180 : il faut tenir une vitesse deja inconfortable.

	# "Fire boom", l exemple donne mot pour mot par le testeur, seuil compris.
	_emit(_passive("pass_fireboom", "Combustion",
		"Au-dela de 140 % de vitesse : les monstres explosent en mourant et"
		+ " infligent 5 degats autour d eux.",
		GameEnums.Rarity.RARE, 140, "passive_death_blast", 5.0))

	_emit(_passive("pass_companion", "Compagnon fidele",
		"Au-dela de 150 % de vitesse : un allie apparait au debut de chaque vague.",
		GameEnums.Rarity.RARE, 150, "passive_wave_ally", 12.0))

	# Change la NATURE des sorts : un sort de feu se met a freiner. Le joueur
	# n a pas a choisir des cartes de givre pour ralentir la vague.
	_emit(_passive("pass_frostbite", "Morsure de givre",
		"Au-dela de 165 % de vitesse : tout degat, quel que soit son element,"
		+ " ralentit sa cible de 30 % pendant 1,5 s.",
		GameEnums.Rarity.RARE, 165, "passive_chill_on_hit", 30.0))

	# Boucle de retour : tuer rend la vitesse, la vitesse allume les passifs.
	# Seuil haut dans sa rarete, parce qu il s auto-entretient une fois lance.
	_emit(_passive("pass_pulse", "Pulsation",
		"Au-dela de 180 % de vitesse : chaque monstre tue pousse la jauge de"
		+ " vitesse de 2 points.",
		GameEnums.Rarity.RARE, 180, "passive_kill_speed", 2.0))

	# ----------------------------------------------------------------- EPIQUES
	# Changent la FACON de jouer, pas la puissance d un chiffre. Seuils 200-250 :
	# a ce regime le moindre contact coute tout, donc l avantage se merite.

	_emit(_passive("pass_dual", "Double incantation",
		"Au-dela de 200 % de vitesse : deux sorts chargent en meme temps, mais"
		+ " chacun prend 50 % plus de temps tant que les deux places servent.",
		GameEnums.Rarity.EPIC, 200, "passive_double_cast", 1.0))

	# Ne donne aucun degat : il change le RYTHME du deck. Aux hautes vitesses la
	# pioche ne suit plus, et garder une carte sur trois vaut plus qu un bonus.
	_emit(_passive("pass_echo", "Echo perpetuel",
		"Au-dela de 225 % de vitesse : une carte lancee sur trois revient en main"
		+ " au lieu d aller a la defausse.",
		GameEnums.Rarity.EPIC, 225, "passive_echo_cast", 3.0))

	# Ne fait rien tout seul : il AMPLIFIE Combustion. Un passif qui depend d un
	# autre est exactement ce que "complexe" veut dire — d ou l epique.
	_emit(_passive("pass_chain", "Reaction en chaine",
		"Au-dela de 250 % de vitesse : une explosion de mort peut en declencher"
		+ " d autres, jusqu a trois fois de suite. Sans effet sans Combustion.",
		GameEnums.Rarity.EPIC, 250, "passive_chain_blast", 1.0))

	# ------------------------------------------------------------- LEGENDAIRES
	# Renversent une regle CENTRALE du jeu. Seuils 300+ : il faut avoir survecu
	# assez longtemps sans etre touche pour y arriver, ce qui est deja l exploit.

	# S attaque a la punition centrale du jeu : un coup ne remet plus la jauge au
	# plancher. Le bouclier reste consomme et les PV restent entames — seul le
	# retour a zero de la vitesse est adouci.
	_emit(_passive("pass_timelock", "Verrou temporel",
		"Au-dela de 300 % de vitesse : un coup encaisse ne fait plus perdre que"
		+ " la moitie de la vitesse au lieu de la faire retomber.",
		GameEnums.Rarity.LEGENDARY, 300, "passive_shield_keeper", 1.0))

	_emit(_passive("pass_overflow", "Debordement",
		"Au-dela de 350 % de vitesse : chaque sort lance se resout DEUX FOIS.",
		GameEnums.Rarity.LEGENDARY, 350, "passive_twin_cast", 1.0))

	# La vitesse multipliait l XP et donnait du bouclier ; ici elle multiplie
	# aussi les DEGATS. A 400 % le mage frappe quatre fois plus fort — c est le
	# passif le plus bouleversant du catalogue, donc le seuil le plus haut.
	_emit(_passive("pass_apotheosis", "Apotheose",
		"Au-dela de 400 % de vitesse : la vitesse multiplie aussi les degats de"
		+ " vos sorts, comme elle multiplie deja l experience.",
		GameEnums.Rarity.LEGENDARY, 400, "passive_speed_damage", 1.0))

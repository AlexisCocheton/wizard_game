extends Node
## Generateur des scenes de visual novel. Ecrit les DialogueDef .tres de
## `resources/story/` a partir de docs/histoire.md.
##
## POURQUOI un generateur et pas des .tres ecrits a la main : une replique est
## un Dictionary dans un Array type ; a la main, une virgule oubliee donne un
## .tres qui se charge SANS erreur et une scene muette. Ici, le code est lisible
## et le format est garanti par ResourceSaver (meme raison que make_content.gd).
##
## A relancer apres toute modification du texte :
##   godot --headless --path . tools/make_story.tscn
##
## COUVERTURE : prologue + acte 1 (lvl_01..lvl_04), c est-a-dire tout ce qui est
## jouable aujourd hui. Les actes 2 a 5 sont ecrits dans docs/histoire.md et
## attendent que leurs niveaux existent — une scene sans niveau ne se jouerait
## jamais et l etage AUDIT la refuserait.

const DIR: String = "res://resources/story/"

## Cles de portrait : doivent exister dans StoryScene.FACES, sinon le personnage
## parle sans visage. Ce sont des constantes pour que la faute de frappe soit une
## erreur de compilation et pas un portrait absent a l ecran.
const MAGE := &"mage"
## Meme personnage, expression marquee : reservee aux repliques ou le mage dit
## ce qu il a perdu. Changer de visage sur ces lignes-la est tout ce qu on peut
## faire pour jouer une emotion sans animation.
const MAGE_GRAVE := &"mage_grave"
const CHILD := &"child"
const RAT := &"rat"
const MAYOR := &"mayor"
const GUARDIAN := &"guardian"

const L := "left"
const R := "right"


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_prologue()
	_acte1()
	print("STORY_OK")
	get_tree().quit(0)


## Une replique. `speaker` vide = narrateur : ni nom ni portrait, le texte occupe
## toute la boite (c est ce qui fait respirer les scenes longues).
func _say(speaker: String, portrait: StringName, text: String,
		side: String = L) -> Dictionary:
	return {"speaker": speaker, "portrait": portrait, "text": text, "side": side}


func _narr(text: String) -> Dictionary:
	return {"speaker": "", "portrait": &"", "text": text, "side": L}


func _scene(id: String, background: String, lines: Array[Dictionary]) -> void:
	var d := DialogueDef.new()
	d.id = StringName(id)
	d.scene_background = background
	d.lines = lines
	var path: String = DIR + id + ".tres"
	var err: int = ResourceSaver.save(d, path)
	if err != OK:
		printerr("Echec ecriture %s (err %d)" % [path, err])
	else:
		print("  ecrit %s (%d repliques)" % [path, lines.size()])


# --- PROLOGUE ---
##
## Il ne raconte pas l attaque : il raconte ce qu elle a DEJA coute. Le joueur
## commence la partie en ayant deja perdu une fois — c est ce qui justifie un
## mage faible, chauve, et presse.

func _prologue() -> void:
	_scene("prologue", "act1_sky", [
		_narr("Ils ne sont pas venus d un pays. Ils ne sont pas venus d une mer. Un matin, ils etaient la."),
		_narr("La foret de Nuri a brule en six jours. La ville de Nox, promise aux siecles, a tenu une nuit."),
		_say("Le Mage", MAGE_GRAVE, "Je n ai pas su les arreter. Alors j ai arrete le temps."),
		_narr("Il a tout donne d un coup. Sa magie, ses annees, et jusqu au dernier de ses cheveux."),
		_say("Le Mage", MAGE, "Me voila revenu avant. Avant la foret. Avant la ville. Avant eux."),
		_say("Le Mage", MAGE, "Il ne me reste qu une chose : aller vite. Plus vite que ce qui arrive."),
		_say("Le Mage", MAGE_GRAVE, "Cette fois je ne vais pas defendre. Je vais remonter le courant jusqu a l origine du mal."),
	])


# --- ACTE 1 : la foret de Nuri ---

func _acte1() -> void:
	_lvl_01()
	_lvl_02()
	_lvl_03()
	_lvl_04()


## Niveau 1 — tutoriel. L intro pose le lieu et la faiblesse ; l outro fait
## entrer l enfant, qui est le PLOT TWIST du jeu (acte 5). Il doit etre attachant
## ici pour que la revelation coute quelque chose plus tard.
func _lvl_01() -> void:
	_scene("lvl_01_intro", "act1_sky", [
		_narr("La foret de Nuri, six jours avant sa fin. Elle ne le sait pas encore."),
		_say("Le Mage", MAGE, "Meme odeur de mousse. Meme lumiere entre les branches. Je suis au bon endroit, au bon matin."),
		_say("Le Mage", MAGE, "Et je suis vide. De quoi lancer trois sorts et courir vite. Ca ira."),
		_narr("Puis un cri, entre les arbres. Une voix d enfant."),
	])
	_scene("lvl_01_outro", "act1_sky", [
		_say("L Enfant", CHILD, "Tu les as fait tomber ! Tous les trois ! Comment on fait ca ?", R),
		_say("Le Mage", MAGE, "On va vite. Plus vite qu eux. C est tout ce que je sais encore faire."),
		_say("L Enfant", CHILD, "Alors va vite jusqu a mon village. Il y en a plein la-bas. Plein.", R),
		_say("Le Mage", MAGE, "... Des gnomes qui attaquent un village. Les gnomes ne font pas ca."),
		_say("L Enfant", CHILD, "Tu viens ?", R),
		_say("Le Mage", MAGE, "Je viens. Reste derriere moi et ne me lache pas."),
	])


## Niveau 2 — le village. La scene existe pour une seule information : les
## monstres avancent EN RANG. C est le premier indice qu on leur donne un ordre,
## et le corniste du niveau le rend visible en jeu.
func _lvl_02() -> void:
	_scene("lvl_02_intro", "act1_sky", [
		_say("L Enfant", CHILD, "C est la ! La maison bleue, c est chez moi !", R),
		_say("Le Mage", MAGE, "Ne regarde pas la maison. Regarde la ligne."),
		_say("L Enfant", CHILD, "Quelle ligne ?", R),
		_say("Le Mage", MAGE, "Ils avancent en rang. Des nuisibles pillent au hasard. Ceux-la marchent. Quelqu un leur bat la mesure."),
	])
	_scene("lvl_02_outro", "act1_sky", [
		_narr("Le corniste tombe en dernier. Sa corne roule dans la boue et continue a sonner deux secondes de trop."),
		_say("L Enfant", CHILD, "Il jouait pour les autres.", R),
		_say("Le Mage", MAGE, "Il jouait pour quelqu un d autre. Il recevait un tempo, il le repetait."),
		_say("Le Mage", MAGE, "Ou est ton maire, petit ?"),
		_say("L Enfant", CHILD, "Dans la grange. Il s y cache depuis trois jours.", R),
		_say("Le Mage", MAGE, "Trois jours. Avant meme l attaque, donc. Interessant."),
	])


## Niveau 3 — la route. Le maire elargit l echelle : ce n est pas un village, ce
## n est meme pas une foret, c est toute l ile, et ca vient d en haut. C est le
## niveau qui transforme une defense en VOYAGE.
func _lvl_03() -> void:
	_scene("lvl_03_intro", "act1_sky", [
		_say("Le Maire", MAYOR, "Je n ai rien cache. J ai... attendu."),
		_say("Le Mage", MAGE, "Vous avez attendu quoi, exactement ?", R),
		_say("Le Maire", MAYOR, "Que ca s arrete tout seul. Ca arrivait par le ciel, mage. Tous les mois, un peu plus bas."),
		_say("Le Maire", MAYOR, "Des betes qui tombaient d en haut et qui ne remontaient pas."),
		_say("Le Mage", MAGE, "D en haut. Donc il y a une ile au-dessus de la notre.", R),
		_say("Le Maire", MAYOR, "Il y a les Sky Lands. Et il y a un dirigeable ecrase au bout de cette route. Si vous voulez monter, c est la seule facon."),
		_say("L Enfant", CHILD, "Je viens.", R),
		_say("Le Mage", MAGE, "Non.", R),
		_say("L Enfant", CHILD, "Mon village est derriere moi et il n y a plus rien dedans. Je viens.", R),
	])
	_scene("lvl_03_outro", "act1_sky", [
		_narr("Au bout de la route, une carcasse de dirigeable coincee dans les arbres comme une baleine echouee. Elle fume encore."),
		_say("L Enfant", CHILD, "Il y a quelqu un dedans. Ca tape.", R),
		_say("Le Mage", MAGE, "Ca tape avec un outil. Ce n est pas un monstre, c est un mecanicien."),
		_narr("Loin derriere eux, dans la foret, quelque chose de tres grand se met debout."),
	])


## Niveau 4 — proteger le dirigeable. Fin de l acte : le Gardien de la foret,
## l esprit PROTECTEUR de Nuri, attaque. L outro donne la preuve materielle — on
## lui a mis quelque chose dans la poitrine — et ouvre l acte 2.
func _lvl_04() -> void:
	_scene("lvl_04_intro", "act1_sky", [
		_say("Le Rat pilote", RAT, "Bougez pas, touchez a rien, et surtout ne montez pas. Il manque une valve, deux ailerons et ma patience.", R),
		_say("Le Mage", MAGE, "Combien de temps ?"),
		_say("Le Rat pilote", RAT, "Le temps qu il faut. Vous, dehors. Moi, dessous.", R),
		_narr("Les arbres, au fond de la clairiere, s ecartent d eux-memes."),
		_say("L Enfant", CHILD, "C est le Gardien ! C est lui qui protege la foret, il va nous aider !", R),
		_say("Le Mage", MAGE_GRAVE, "Petit... il marche sur les arbres, pas entre."),
	])
	_scene("lvl_04_outro", "act1_sky", [
		_narr("Le Gardien s effondre en un tas de bois mort. Dans sa poitrine ouverte, plantee la comme une echarde, une plaque de metal noir que personne n a taillee ici."),
		_say("Le Gardien", GUARDIAN, "... pas... voulu...", R),
		_say("Le Mage", MAGE, "Il n est pas devenu fou. On lui a mis quelque chose dedans."),
		_say("Le Rat pilote", RAT, "Vu la soudure, c est du travail d en haut. Sky Lands. Je connais le style, j en viens.", R),
		_say("L Enfant", CHILD, "Alors on monte ?", R),
		_say("Le Rat pilote", RAT, "On monte. Accrochez-vous a ce qui est visse.", R),
	])

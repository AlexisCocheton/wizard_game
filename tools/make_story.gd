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
## COUVERTURE (vague 10, chantier B4) : le prologue et les VINGT ET UN niveaux
## de la campagne, chacun encadre d une intro et d une outro. Les identifiants ne
## suivent pas l ordre de jeu : le chantier N a choisi de NE PAS renumeroter la
## campagne pour ne pas casser les sauvegardes, donc c est `LevelDef.act` qui
## porte le plan de docs/histoire.md, pas le numero du niveau. Ordre de jeu :
##   acte 1 : lvl_01, lvl_02, lvl_08, lvl_09
##   acte 2 : lvl_17, lvl_18, lvl_03, lvl_04
##   acte 3 : lvl_19, lvl_20, fourche lvl_05 / lvl_06, lvl_21
##   acte 4 : lvl_07, lvl_10, lvl_11, lvl_12 dans l ordre libre, puis lvl_13
##   acte 5 : lvl_14, lvl_15, lvl_16
##
## UNE SCENE N EXISTE QUE SI UN NIVEAU LA CITE (`intro_story` / `outro_story`
## dans tools/make_content.gd). Les scenes de Vharn ont vecu des semaines sur le
## disque sans etre jouees : `test_story` refuse desormais une scene orpheline.
##
## REGLES D ECRITURE (verifiees ou relues) :
##   - texte SANS accents ni tiret long : la police n en a pas ;
##   - une replique tient en moins de 180 caracteres (la boite fait ~54 x 7) ;
##   - le NARRATEUR decrit ce qui se passe a l ecran : s il nomme un monstre,
##     ce monstre est dans les vagues du niveau (`test_story` le verifie) ;
##   - le mage parle a gauche, les autres a droite ;
##   - une scene ne suppose jamais un ordre que le joueur peut ne pas avoir
##     suivi (fourche de l acte 3, eventail de l acte 4).

const DIR: String = "res://resources/story/"

## LES DECORS DE DIALOGUE. Chaque scene nomme un fichier de `assets/backdrops/`
## prefixe `talk_` : ce sont les decors PEINTS du pack `Wood Elves`, un par lieu
## de l acte 1. Avant, toutes les scenes nommaient `act1_sky`, le fond de COMBAT
## de l acte, assombri de moitie — neuf dialogues devant la meme pelouse verte.
## Le lieu fait la moitie du travail d une scene de visual novel : le prologue se
## joue devant un sanctuaire sous la lune, le village devant ses maisons de bois,
## et le Gardien devant l arbre qu il protege.

## Cles de portrait : doivent exister dans StoryScene.CAST, sinon le personnage
## parle sans visage. Ce sont des constantes pour que la faute de frappe soit une
## erreur de compilation et pas un portrait absent a l ecran.
const MAGE := &"mage"
## Meme personnage, repliques ou le mage dit ce qu il a perdu. Le pack de
## portraits ne donne qu UNE expression par personnage : la cle reste distincte
## pour que le jour ou un second visage du mage existe, seul StoryScene.CAST ait
## a changer — pas les neuf scenes.
const MAGE_GRAVE := &"mage_grave"
const CHILD := &"child"
const RAT := &"rat"
const MAYOR := &"mayor"
const GUARDIAN := &"guardian"
## CHANTIER N2 — le Roi squelette, souverain de Tombol. Il parle dans tout
## l acte 3 et sa case existait deja dans `StoryScene.CAST` sans qu aucune
## scene ne la cite : un portrait paye et jamais affiche.
const SKELETON_KING := &"skeleton_king"
## CHANTIER N3 — LE RETOURNEMENT DE L ACTE 5. Meme personnage que `CHILD`, autre
## visage : un masque de dragon d or, rien d humain dedans. La case existait dans
## `StoryScene.CAST` depuis le debut et AUCUNE scene ne la citait — le plot twist
## du jeu etait paye et jamais joue.
##
## Les deux cles coexistent pour une raison precise : dans `lvl_16_intro`, le
## portrait BASCULE au milieu de la scene, sur la replique ou l enfant arrete de
## faire semblant. C est la seule scene du jeu ou un personnage change de visage.
const CHILD_GOD := &"child_god"
## Les quatre grands demons de l acte 4. Ils partagent une case — le pack ne
## fournit qu un visage de demon — et c est acceptable ici : ils ne se rencontrent
## JAMAIS dans la meme scene, chacun tenant son propre niveau. Le NOM affiche est
## en revanche le leur (Sesh, Kaltek, Ymoa) : le mage les appelle par leur nom et
## le niveau le porte, un locuteur « Un demon » contredisait les deux (revue A4).
const DEMON := &"demon"

const L := "left"
const R := "right"


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_prologue()
	_acte1()
	# CHANTIER N2 — les actes 2 et 3 : les quatre niveaux des Sky Lands (dont
	# `lvl_03` et `lvl_04`, qui attendaient leurs dialogues depuis que le
	# chantier N a rendu les leurs a l acte 1) et les cinq de Tombol, fourche
	# comprise depuis le chantier B4.
	_acte2()
	_acte3()
	# CHANTIER N3 — LA FIN DU JEU. L acte 4 encadre les quatre grands demons et
	# le pentacle brise ; l acte 5 encadre les trois niveaux de l espace divin,
	# dont le plot twist et la fin de la campagne.
	_acte4()
	_acte5()
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
	_scene("prologue", "talk_shrine", [
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
	_lvl_08()
	_lvl_09()


## Niveau 1 — tutoriel. L intro pose le lieu et la faiblesse ; l outro fait
## entrer l enfant, qui est le PLOT TWIST du jeu (acte 5). Il doit etre attachant
## ici pour que la revelation coute quelque chose plus tard.
##
## CHRONOS EST NOMME ICI (revue A4, n° 17). Il ferme le tutoriel, ses Echos
## reviennent aux lvl_15 et lvl_16, et le boss final porte sa silhouette en or :
## un adversaire qu on n a jamais nomme ne peut pas revenir. Le mage le
## reconnait, il ne le decouvre pas — c est le seul qui se souvienne de la
## premiere fois.
##
## Le mini-boss du niveau (le Gardien) n est volontairement PAS cite : il meurt
## ici alors que l enfant le presente en allie au lvl_09. Le remplacer est une
## affaire de vagues (renvoye a B2) ; en attendant, aucune scene n en parle.
func _lvl_01() -> void:
	_scene("lvl_01_intro", "talk_glade", [
		_narr("La foret de Nuri, six jours avant sa fin. Elle ne le sait pas encore."),
		_say("Le Mage", MAGE, "Meme odeur de mousse. Meme lumiere entre les branches. Je suis au bon endroit, au bon matin."),
		_say("Le Mage", MAGE, "Et je suis vide. De quoi lancer quelques sorts et courir vite. Ca ira."),
		_narr("Puis un cri, entre les arbres. Une voix d enfant."),
	])
	_scene("lvl_01_outro", "talk_glade", [
		_say("L Enfant", CHILD, "Tu les as tous fait tomber ! Meme le grand ! Comment on fait ca ?", R),
		_say("Le Mage", MAGE, "On va vite. Plus vite qu eux. C est tout ce que je sais encore faire."),
		_narr("Le plus grand d entre eux porte un cadran a la place du coeur. Les aiguilles tournent encore."),
		_say("Le Mage", MAGE_GRAVE, "Chronos. L huissier des delais. Il etait deja la, la premiere fois, quand Nox est tombee."),
		_say("L Enfant", CHILD, "Alors va vite jusqu a mon village. Il y en a plein la-bas. Plein.", R),
		_say("Le Mage", MAGE, "... Des gnomes qui attaquent un village. Les gnomes ne font pas ca."),
		_say("L Enfant", CHILD, "Tu viens ?", R),
		_say("Le Mage", MAGE, "Je viens. Reste derriere moi et ne me lache pas."),
	])


## Niveau 2 — LE VILLAGE PETRIFIE (demande du co-auteur, vague 10 : « quand on
## retrouve les gorgones, que le dialogue dise qu ils retrouvent le village
## petrifie »).
##
## Le niveau envoie toute la lignee des gorgones : la Matrone en mini-boss (deux
## cartes figees), deux Gorgones, puis la Reine (trois cartes) a la fin de la
## vague de boss. La scene fait TROIS choses, dans cet ordre :
##   1. montrer le village en pierre — c est ce que le joueur doit retenir ;
##   2. apprendre la mecanique AVANT la Matrone : un regard de gorgone fige des
##      sorts dans la main, la reponse est de l abattre d abord ;
##   3. garder l indice de la cadence (ils marchent au pas, le Corniste du
##      niveau la rend visible), qui revient chez Vharn a l acte 4.
## L outro pose le PREMIER GRAIN du retournement final : la Reine morte, les
## sorts se degelent mais pas les villageois. Quelqu un les avait figes avant
## elle, et l enfant trouve qu « ils sont bien comme ca ». Le siege vide
## (lvl_16) le paie : « Les statues du village, c etait moi. »
func _lvl_02() -> void:
	_scene("lvl_02_intro", "talk_village", [
		_say("L Enfant", CHILD, "C est la ! La maison sous le grand arbre, c est chez moi !", R),
		_narr("Le village est debout. Ses gens aussi : en pierre, figes au milieu d un geste."),
		_say("L Enfant", CHILD, "Ils ne repondent pas. Pourquoi ils ne repondent pas ?", R),
		_say("Le Mage", MAGE_GRAVE, "Des gorgones sont passees. Il en reste. Si l une d elles regarde mes sorts, ils se figeront dans ma main."),
		_say("Le Mage", MAGE, "Alors on les abat en premier. Et regarde les autres : ils marchent au pas. Quelqu un leur bat la mesure."),
	])
	_scene("lvl_02_outro", "talk_village", [
		_narr("La Reine gorgone s effondre au milieu de la place. Les sorts du mage se degelent d un coup. Les gens du village, eux, restent en pierre."),
		_say("Le Mage", MAGE_GRAVE, "Ce qu une gorgone fige, sa mort le libere. Pas eux. Quelqu un les a figes avant elle."),
		_say("L Enfant", CHILD, "Ils sont bien comme ca. Ils n ont plus peur.", R),
		_say("Le Mage", MAGE, "... Ou est ton maire, petit ?"),
		_say("L Enfant", CHILD, "Dans la grange. Il s y cache depuis trois jours.", R),
		_say("Le Mage", MAGE, "Trois jours. Avant meme l attaque. Et lui n est pas en pierre."),
	])


## Niveau 3 — la route. Le maire elargit l echelle : ce n est pas un village, ce
## n est meme pas une foret, c est toute l ile, et ca vient d en haut. C est le
## niveau qui transforme une defense en VOYAGE.
##
## Le mage parle A GAUCHE comme dans toutes les autres scenes (il etait a droite
## ici seulement, revue A4 n° 23) ; le maire et l enfant a droite.
func _lvl_08() -> void:
	_scene("lvl_08_intro", "talk_path", [
		_say("Le Maire", MAYOR, "Je n ai rien cache. J ai... attendu.", R),
		_say("Le Mage", MAGE, "Vous avez attendu quoi, exactement ?"),
		_say("Le Maire", MAYOR, "Que ca s arrete tout seul. Ca arrivait par le ciel, mage. Tous les mois, un peu plus bas.", R),
		_say("Le Maire", MAYOR, "Des betes qui tombaient d en haut et qui ne remontaient pas.", R),
		_say("Le Mage", MAGE, "D en haut. Donc il y a une ile au-dessus de la notre."),
		_say("Le Maire", MAYOR, "Il y a les Sky Lands. Et il y a un dirigeable ecrase au bout de cette route. Si vous voulez monter, c est la seule facon.", R),
		_say("L Enfant", CHILD, "Je viens.", R),
		_say("Le Mage", MAGE, "Non."),
		_say("L Enfant", CHILD, "Mon village est en pierre derriere moi. Il n y a plus rien a garder. Je viens.", R),
	])
	_scene("lvl_08_outro", "talk_path", [
		_narr("Au bout de la route, une carcasse de dirigeable coincee dans les arbres comme une baleine echouee. Elle fume encore."),
		_say("L Enfant", CHILD, "Il y a quelqu un dedans. Ca tape.", R),
		_say("Le Mage", MAGE, "Ca tape avec un outil. Ce n est pas un monstre, c est un mecanicien."),
		_narr("Loin derriere eux, dans la foret, quelque chose de tres grand se met debout."),
	])


## Niveau 4 — proteger le dirigeable. Fin de l acte : le Gardien de la foret,
## l esprit PROTECTEUR de Nuri, attaque. L outro donne la preuve materielle — on
## lui a mis quelque chose dans la poitrine — et ouvre l acte 2.
##
## « LE VRAI, CELUI DE L ARBRE » (revue A4, n° 3) : le tutoriel envoie deja un
## Gardien en mini-boss. Tant que B2 ne l a pas remplace, l enfant distingue
## celui-ci, le protecteur de l arbre, de tout ce que le joueur a pu croiser
## avant. Et le Gardien est un chevalier en armure noire a l ecran : il ne
## « s effondre pas en un tas de bois mort », son armure s ouvre comme une
## ecorce et c est DEDANS qu est le bois (n° 24).
func _lvl_09() -> void:
	_scene("lvl_09_intro", "talk_greattree", [
		_say("Le Rat pilote", RAT, "Bougez pas, touchez a rien, et surtout ne montez pas. Il manque une valve, deux ailerons et ma patience.", R),
		_say("Le Mage", MAGE, "Combien de temps ?"),
		_say("Le Rat pilote", RAT, "Le temps qu il faut. Vous, dehors. Moi, dessous.", R),
		_narr("Les arbres, au fond de la clairiere, s ecartent d eux-memes."),
		_say("L Enfant", CHILD, "C est le Gardien ! Le vrai, celui de l arbre. C est lui qui protege la foret, il va nous aider !", R),
		_say("Le Mage", MAGE_GRAVE, "Petit... il marche sur les arbres, pas entre."),
	])
	_scene("lvl_09_outro", "talk_greattree", [
		_narr("Le Gardien s effondre. Son armure s ouvre comme une ecorce : dedans, du bois mort, et plantee comme une echarde, une plaque de metal noir."),
		_say("Le Gardien", GUARDIAN, "... pas... voulu...", R),
		_say("Le Mage", MAGE, "Il n est pas devenu fou. On lui a mis quelque chose dedans."),
		_say("Le Rat pilote", RAT, "Vu la soudure, c est du travail d en haut. Sky Lands. Je connais le style, j en viens.", R),
		_say("L Enfant", CHILD, "Alors on monte ?", R),
		_say("Le Rat pilote", RAT, "On monte. Accrochez-vous a ce qui est visse.", R),
	])


# --- ACTE 2 : les Sky Lands (chantier N2) ---
##
## QUATRE niveaux, dans l ordre de JEU et non dans l ordre des numeros :
##   `lvl_17` (les courants) -> `lvl_18` (le port) -> `lvl_03` (l ossuaire de
##   bordure) -> `lvl_04` (le Grand Appel).
##
## LE DEFAUT QUE CES SCENES REPARENT. `lvl_03` et `lvl_04` appartiennent a
## l acte 2 et n avaient plus AUCUNE scene : les leurs avaient ete reattribuees
## a `lvl_08` / `lvl_09` par le chantier N, parce qu elles racontaient l acte 1
## (le maire y parlait du dirigeable devant un ossuaire). Les deux niveaux
## attendaient depuis les dialogues des Sky Lands, ecrits dans docs/histoire.md
## section 4 et jamais mis en scene. Ils les ont ici.
##
## LES DECORS. Le pack `Wood Elves` ne fournit que cinq `talk_*`, tous poses par
## l acte 1, et en fabriquer d autres passe par `tools/story/build_backdrops.py`
## (hors du perimetre des chantiers d ecriture). On REUTILISE donc, en choisissant
## par ce que l IMAGE montre (relu au chantier B4, revue A4 n° 19) :
##   `talk_greattree` — un grand arbre blanc sur une colline, des NUAGES : le
##     Gardien de l arbre (lvl_09), puis le ciel des courants (lvl_17) ;
##   `talk_path` — un sentier et une cabane de bois : la route du maire (lvl_08)
##     et les entrepots du port (lvl_18) ;
##   `talk_shrine` — un sanctuaire de pierre sous la lune, des STATUES, de
##     l eau : tout ce qui est funeraire, souterrain ou hors du monde, de
##     l ossuaire (lvl_03) au registre (lvl_15).
## Les actes 3 a 5 restent donc presque tous devant `talk_shrine` : c est le moins
## faux des cinq pour une forge, une arene ou un temple, mais il faudra des decors
## dedies (renvoye a l asset-pipeline). Un decor de dialogue ne doit jamais etre
## un fond de COMBAT (`test_story` le verifie).

func _acte2() -> void:
	_lvl_17()
	_lvl_18()
	_lvl_03()
	_lvl_04()


## Niveau 1 de l acte — les courants. La scene appartient au RAT : il vient
## d entrer dans le groupe et c est son vehicule. Le document lui donne ses deux
## repliques mot pour mot (« si je crie a bas », « il n y a pas de regle deux »),
## et elles font tout le travail de ton : on monte dans quelque chose qui tient
## avec de la ficelle.
##
## L outro faisait tomber l Ecumeur du ciel, ABSENT du niveau (revue A4, n° 9) :
## c est le Grand Oeil des courants qui le mene. Il n a pas d aile, la soudure
## est donc « derriere l oeil ».
func _lvl_17() -> void:
	_scene("lvl_17_intro", "talk_greattree", [
		_narr("Le dirigeable se decroche des arbres et monte. Sous la nacelle, la foret de Nuri devient une tache verte, puis rien."),
		_say("Le Rat pilote", RAT, "Regle une : si je crie a bas, vous vous mettez a bas. Pas de question, pas de regard autour.", R),
		_say("Le Mage", MAGE, "Il y a une regle deux ?"),
		_say("Le Rat pilote", RAT, "La regle deux c est qu il n y a pas de regle deux, on va s ecraser.", R),
		_say("L Enfant", CHILD, "Il y a des choses qui volent, dehors. Beaucoup.", R),
		_say("Le Mage", MAGE, "Alors mes murs ne servent plus a rien. Il va falloir couvrir le ciel."),
	])
	_scene("lvl_17_outro", "talk_greattree", [
		_narr("Le Grand Oeil des courants s abat sur la nacelle et reste pris dans les cordages."),
		_say("Le Rat pilote", RAT, "Bougez pas.", R),
		_narr("Le rat le retourne du pied, se penche, et ne dit rien pendant un long moment."),
		_say("Le Rat pilote", RAT, "Derriere l oeil. La meme soudure noire que dans la poitrine de votre Gardien.", R),
		_say("Le Mage", MAGE, "Donc ce n est pas une bete des courants. C est une piece."),
		_say("Le Rat pilote", RAT, "Les Sky Lands ne sont pas sauvages, mage. C est un atelier. J y ai travaille.", R),
	])


## Niveau 2 de l acte — le port. Le document place ici le PREMIER GRAIN du
## retournement de l acte 5 : « l enfant montre quelque chose qu il ne devrait
## pas savoir ». Les quatre repliques sont reprises mot pour mot, et surtout on
## n y revient PAS : le mage note, accepte, et passe. C est ce silence qui fait
## que le joueur oubliera lui aussi jusqu a l acte 5.
func _lvl_18() -> void:
	_scene("lvl_18_intro", "talk_path", [
		_narr("Haute-Nacelle a ete videe par le haut. Les quais de bois tiennent encore, les entrepots sont ouverts, et il n y a personne."),
		_say("Le Rat pilote", RAT, "Six cents habitants. J y ai bu pendant douze ans.", R),
		_say("Le Mage", MAGE, "Ils sont partis ou ?"),
		_say("Le Rat pilote", RAT, "Ils ne sont pas partis. On ne vide pas un port par le haut en laissant les portes ouvertes.", R),
		_say("L Enfant", CHILD, "Il y a des gens sur les quais. Ils ne bougent pas comme des gens.", R),
	])
	_scene("lvl_18_outro", "talk_path", [
		_narr("Le Mage noir de Haute-Nacelle s effondre. Sous sa robe, la meme soudure noire."),
		_narr("Au bout du quai, deux passages : celui de droite et celui de gauche."),
		_say("L Enfant", CHILD, "Il faut passer par la droite. La gauche est fermee.", R),
		_say("Le Mage", MAGE, "Tu es deja venu ici ?"),
		_say("L Enfant", CHILD, "Non. Mais c est ferme. Je le sais, c est tout.", R),
		_say("Le Mage", MAGE, "... D accord. Par la droite."),
		_narr("Personne ne releve. Le rat regarde l enfant une seconde de trop, puis regarde ailleurs."),
	])


## Niveau 3 de l acte — l ossuaire de bordure. LE NIVEAU N AVAIT PLUS DE SCENE :
## voir l en-tete. Le document dit du cimetiere de bordure « premiers
## morts-vivants, brume » et « les morts se levent et PARLENT ». La scene existe
## pour installer ce fait-la — des morts qui ne chargent pas — sans encore lacher
## le nom, qui appartient a la fin de l acte.
##
## L outro nomme LE RELIQUAIRE, boss du niveau, que la scene ignorait (revue A4) :
## c est en tombant qu il livre les registres. Les repliques du mage sont au
## FUTUR : dans cette boucle-ci, l extinction n a pas encore eu lieu.
func _lvl_03() -> void:
	_scene("lvl_03_intro", "talk_shrine", [
		_narr("Passe le port, les iles ne portent plus de maisons. Elles portent des tombes, rangees, numerotees, et de la brume jusqu aux genoux."),
		_say("Le Rat pilote", RAT, "Cimetiere de bordure. On enterrait ici ce que les iles hautes ne voulaient pas garder.", R),
		_say("Le Mage", MAGE, "Les tombes sont ouvertes. Toutes, et de l interieur."),
		_say("L Enfant", CHILD, "Elles sont rangees par... par quoi ? Ce ne sont pas des noms.", R),
		_say("Le Mage", MAGE_GRAVE, "Ce sont des quantites. Quelqu un tient des comptes ici, petit."),
	])
	_scene("lvl_03_outro", "talk_shrine", [
		_narr("Le Reliquaire s ouvre en tombant. Dedans, les registres de l ossuaire, intacts : une colonne par ile, une ligne par annee."),
		_narr("Les trois dernieres annees, on n a plus compte des morts. On les a COMMANDES."),
		_say("Le Mage", MAGE, "Ils ne vont pas nous effacer par haine. Ils vont nous effacer pour faire du STOCK."),
		_say("Le Rat pilote", RAT, "Du stock pour quoi ?", R),
		_say("Le Mage", MAGE_GRAVE, "On ne range pas des morts en colonnes si on ne compte pas s en servir tous ensemble."),
		_say("L Enfant", CHILD, "Il y en a un qui nous regarde. Au fond. Il ne vient pas.", R),
	])


## Niveau 4 de l acte — le Grand Appel, fin de l acte 2. C EST ICI QUE LE NOM
## TOMBE, et le document lui donne sa propre scene (`lvl_08_outro` dans sa
## numerotation) : les morts s arretent tous en meme temps et parlent.
##
## LE MORT N A PAS DE PORTRAIT, et c est voulu. Le casting de
## `scripts/ui/story_scene.gd` est fixe et hors du perimetre de ce chantier ;
## surtout, une voix sans visage est exactement ce que la scene demande — ce
## n est pas un personnage, c est un choeur. `StoryScene` gere le cas : le nom
## s affiche, la boite du portrait se cache.
##
## « On regarde ce qui sort » restait sans reponse (revue A4, n° 14) : l outro
## dit maintenant CE qui est sorti — l Ensevelisseur, boss du niveau — et que sa
## chute arrete les morts. Decor : le sanctuaire de pierre, pas l arbre vert de
## l acte 1 (un cimetiere joue devant une colline fleurie, n° 19).
func _lvl_04() -> void:
	_scene("lvl_04_intro", "talk_shrine", [
		_narr("Au centre du cimetiere de bordure, un cercle deja trace et des Pretres goules qui chantent depuis assez longtemps pour que la pierre soit chaude."),
		_say("Le Mage", MAGE, "Nous arrivons trop tard. On ne l arrete plus."),
		_say("Le Rat pilote", RAT, "Alors on repart.", R),
		_say("Le Mage", MAGE_GRAVE, "Non. On reste, et on regarde ce qui sort. C est la seule chose que je sois venu chercher."),
		_say("L Enfant", CHILD, "Et si ce qui sort nous voit ?", R),
		_say("Le Mage", MAGE, "Alors nous aurons une adresse."),
	])
	_scene("lvl_04_outro", "talk_shrine", [
		_narr("Ce qui est sorti du cercle s appelle l Ensevelisseur. Quand il tombe, les morts cessent de charger."),
		_narr("Ils s arretent, tous, en meme temps, et se tournent vers le mage."),
		_say("Un mort", &"", "Ce n est pas nous. Nous, on nous a reveilles."),
		_say("Le Mage", MAGE, "Par qui ?"),
		_say("Un mort", &"", "Par l ordre de Tombol. Le Roi squelette a signe. Il a signe pour nous tous et il n avait pas le droit."),
		_say("Le Rat pilote", RAT, "Tombol, c est trois iles plus loin. Le grand cimetiere.", R),
		_say("Le Mage", MAGE, "Alors on a enfin un nom. On y va."),
	])


# --- ACTE 3 : le cimetiere de Tombol (chantier N2) ---
##
## CINQ niveaux, et une seule forme : une POURSUITE. Le document est explicite —
## « le Roi squelette FUIT. Tout l acte est une poursuite : a chaque niveau on
## arrive juste apres lui. » Les scenes sont donc ecrites pour qu on ne le
## rencontre JAMAIS avant la derniere, et chacune se ferme sur une trace fraiche
## plutot que sur une confrontation.
##
## LA FOURCHE (`lvl_05` les forges, `lvl_06` la cour brisee) n avait AUCUNE
## scene, et montrait le monde demoniaque en plein acte 3 avec des textes de
## l ancienne histoire (« les seigneurs demoniaques s entretuent »). Elle en a
## depuis le chantier B4, ecrites sous trois contraintes :
##   - le joueur en joue UNE, ou les deux, dans l ordre qu il veut : chaque
##     scene se lit seule, et aucune ne cite l autre ;
##   - l outro de `lvl_20` annonce les DEUX escaliers, chaque intro de fourche
##     dit lequel on a pris ;
##   - elles ne gachent pas `lvl_21` : on y voit que quelque chose REMONTE sous
##     Tombol (le rouge du fond de combat devient un indice), jamais QUI : c est
##     le roi qui le montre, au `lvl_21` (« Voila mes creanciers »).
## Le rat est reste avec la nacelle (`lvl_19`) : il revient dans l outro de
## `lvl_21`, quand tout le monde descend.

func _acte3() -> void:
	_lvl_19()
	_lvl_20()
	_lvl_05()
	_lvl_06()
	_lvl_21()


## Niveau 1 de l acte — les fosses basses. On entre dans Tombol par le bas, dans
## l eau. La scene installe la poursuite : le sillage est encore trouble.
func _lvl_19() -> void:
	_scene("lvl_19_intro", "talk_shrine", [
		_narr("Tombol ne se voit pas d en haut : c est une ile qui descend."),
		_narr("On y entre par les fosses basses, ou l eau monte aux mollets et ou les tombes se sont ouvertes vers le bas."),
		_say("Le Rat pilote", RAT, "Je reste avec la nacelle. Ce qui est en dessous, ce n est plus de la mecanique.", R),
		_say("Le Mage", MAGE, "Combien de temps avant que le Roi squelette sache que nous sommes la ?"),
		_say("Le Rat pilote", RAT, "Il le sait. Regardez l eau : elle est encore trouble.", R),
		_say("L Enfant", CHILD, "Il vient de passer.", R),
	])
	# « Les Pretres des fosses » n existent pas (revue A4, n° 10) : la vague de
	# boss est le TRIO des mages de braise, du givre et des arcanes.
	_scene("lvl_19_outro", "talk_shrine", [
		_narr("Les trois mages des fosses tombent l un apres l autre, et aucun ne demande grace."),
		_say("Le Mage", MAGE, "Ils n ont pas essaye de me tuer. Ils ont essaye de me FAIRE PERDRE DU TEMPS."),
		_say("L Enfant", CHILD, "C est different ?", R),
		_say("Le Mage", MAGE_GRAVE, "C est tout ce qui compte, petit. Un roi qui veut ma mort m attend. Un roi qui veut mon retard, lui, court encore."),
	])


## Niveau 2 de l acte — la cour des rois morts. Le document dit « statues,
## arrieres-gardes laissees par le roi ». La scene sert a retourner la lecture
## du joueur : ce ne sont pas des gardes qui defendent leur roi, ce sont des gens
## qu on a laisses mourir pour acheter une heure. C est le premier indice que le
## roi lui-meme est poursuivi par autre chose.
##
## Decor : le sanctuaire aux STATUES, que la scene decrit (il etait joue devant
## l arbre blanc). La derniere replique ouvre la FOURCHE : deux escaliers, celui
## qui descend vers les forges (`lvl_05`), celui qui remonte vers la salle du
## trone (`lvl_06`).
func _lvl_20() -> void:
	_scene("lvl_20_intro", "talk_shrine", [
		_narr("Une cour bordee de statues : chaque roi de Tombol, chacun plus haut que le precedent. Au pied du dernier, des gardes en rang."),
		_say("Le Mage", MAGE, "Ils ne surveillent pas la porte. Ils surveillent le fond de la cour."),
		_say("L Enfant", CHILD, "Ils ont peur de ce qui est derriere eux, pas de nous.", R),
		_say("Le Mage", MAGE, "Reste pres de moi. Et ne touche a aucune inscription."),
	])
	_scene("lvl_20_outro", "talk_shrine", [
		_narr("La derniere arriere-garde tombe sans un mot. Aucune n a recule d un pas, et aucune n a tenu plus d une minute."),
		_say("Le Mage", MAGE_GRAVE, "Il ne les a pas postes pour me battre. Il les a postes pour gagner une heure."),
		_say("L Enfant", CHILD, "On ne fait pas ca quand on fuit un ennemi ?", R),
		_say("Le Mage", MAGE, "On fait ca quand on fuit un creancier. Un ennemi, on le combat. Un creancier, on le retarde."),
		_narr("Au fond de la cour, deux escaliers. L un descend vers une lueur rouge. L autre remonte vers la salle du trone, d ou viennent des cris."),
	])


## LA FOURCHE, BRANCHE 1 — les forges sous Tombol (`lvl_05`). On y voit que ce
## qui blinde les monstres de Tombol est FABRIQUE, et fabrique par en dessous :
## le poincon a cinq branches annonce le pentacle de `lvl_21` sans le nommer.
## « Tu as vu les registres » renvoie a l ossuaire (`lvl_03`), que tous les
## joueurs ont traverse.
func _lvl_05() -> void:
	_scene("lvl_05_intro", "talk_shrine", [
		_narr("L escalier qui descend ne mene pas a une crypte. Il mene a une forge, et la forge tourne a plein, rouge jusqu au plafond."),
		_say("L Enfant", CHILD, "Tout est chaud. Le roi est passe par ici ?", R),
		_say("Le Mage", MAGE, "Il a traverse sans s arreter, comme quelqu un qui connait le chemin."),
		_say("Le Mage", MAGE_GRAVE, "Tombol enterre ses morts. Elle ne coule pas d armures. Ca, quelqu un l a installe sous ses pieds."),
	])
	_scene("lvl_05_outro", "talk_shrine", [
		_narr("Le dernier colosse de la forge s effondre dans sa propre coulee. Sur chaque piece, le meme poincon : un cercle a cinq branches."),
		_say("Le Mage", MAGE, "Ce n est pas Tombol qui fabrique ca. Ca remonte d en dessous, et Tombol paie l atelier."),
		_say("L Enfant", CHILD, "Il paie avec quoi ?", R),
		_say("Le Mage", MAGE_GRAVE, "Avec ses morts, petit. Tu as vu les registres."),
	])


## LA FOURCHE, BRANCHE 2 — la cour brisee (`lvl_06`). La « cour », ce sont les
## seigneurs du roi : il a fui sans dire a qui revenait le trone, et ils se le
## disputent au milieu du passage du mage (le sous-titre du niveau, « une guerre
## civile ou tu n es qu un passant », est enfin vrai). Le sceau casse dit que la
## signature est deja partie « en bas » : c est `lvl_21` qui dira a qui.
func _lvl_06() -> void:
	_scene("lvl_06_intro", "talk_shrine", [
		_narr("L escalier qui remonte mene a la salle du trone de Tombol. Le trone est vide, et la cour du roi se dechire tout autour."),
		_say("L Enfant", CHILD, "Ils se battent entre eux. Ils ne nous regardent meme pas.", R),
		_say("Le Mage", MAGE, "Leur roi est parti sans dire a qui revenait le trone. Ils se le disputent."),
		_say("Le Mage", MAGE_GRAVE, "Nous, on ne fait que passer. Mais ici, tout ce qui passe, ils le tuent quand meme."),
	])
	_scene("lvl_06_outro", "talk_shrine", [
		_narr("Le dernier seigneur de la cour tombe sur les marches du trone vide, la main sur le sceau royal. Le sceau est casse en deux."),
		_say("Le Mage", MAGE, "Ils se battaient pour un sceau qui ne vaut plus rien. Le roi a signe avec, et ce qu il a signe est deja parti."),
		_say("L Enfant", CHILD, "Parti ou ?", R),
		_say("Le Mage", MAGE_GRAVE, "En bas. Par le meme chemin que lui."),
	])


## Niveau 3 de l acte — le pentacle. LE RETOURNEMENT : le roi accule explique
## qu il a signe pour sauver son royaume, puis que les creanciers savent, pour la
## boucle. Le document donne les deux scenes en entier ; elles sont reprises
## presque mot pour mot parce qu elles portent l information la plus importante
## de toute la campagne — c est le mage lui-meme qui a accelere la fin.
##
## Corrige au chantier B4 (revue A4) : le roi ne dit plus « Encore toi » a un
## homme qu il n a jamais rencontre (n° 16), le mage ne parle plus de « son
## royaume », reste de l ancienne histoire (n° 22) : il parle de Nuri et de Nox.
## Et le rat, reste avec la nacelle depuis les fosses basses, REVIENT ici avant
## la descente — il parle de nouveau a l acte 4, il fallait le dire (n° 21).
func _lvl_21() -> void:
	_scene("lvl_21_intro", "talk_shrine", [
		_narr("Au fond de Tombol, une salle ronde et un pentacle qui tourne lentement au ras du sol."),
		_narr("Devant, un squelette couronne, dos au cercle. Il n a plus nulle part ou reculer."),
		_say("Le Roi squelette", SKELETON_KING, "Te voila enfin. Tu cours vite pour un homme qui n a plus rien.", R),
		_say("Le Mage", MAGE, "Tu as signe la fin de Nuri et de Nox."),
		_say("Le Roi squelette", SKELETON_KING, "J ai signe pour SAUVER Tombol. Ils sont venus avec un contrat deja ecrit, mage.", R),
		_say("Le Roi squelette", SKELETON_KING, "On ne negocie pas avec ce qui monte de ce puits.", R),
		_say("Le Mage", MAGE, "Qui monte de ce puits ?"),
		_say("Le Roi squelette", SKELETON_KING, "Regarde derriere moi et arrete de poser la question.", R),
	])
	_scene("lvl_21_outro", "talk_shrine", [
		_narr("Le sceau se fend. Ce qui passe au travers n a pas d yeux et sait exactement ou tout le monde se tient."),
		_say("Le Roi squelette", SKELETON_KING, "Voila mes creanciers. Ils m ont pris mes morts, mes terres et ma signature.", R),
		_say("Le Roi squelette", SKELETON_KING, "Ils te prendront ta boucle.", R),
		_say("Le Mage", MAGE, "Ma quoi ?"),
		_say("Le Roi squelette", SKELETON_KING, "Ils savent que tu as recule le temps, mage. Tout le monde en bas le sait.", R),
		_say("Le Roi squelette", SKELETON_KING, "C est pour CA qu ils avancent si vite maintenant.", R),
		_say("Le Mage", MAGE_GRAVE, "... Alors c est moi qui ai accelere la fin."),
		_say("Le Roi squelette", SKELETON_KING, "Tu as change la date, pas la fin. Fais-moi une place, je descends avec toi. Je n ai plus rien a perdre.", R),
		_narr("Au bord du puits, la nacelle attend, moteur deja chaud."),
		_say("Le Rat pilote", RAT, "J ai dit que je restais avec la nacelle. Elle descend, alors je descends.", R),
		_say("L Enfant", CHILD, "On descend ? Vraiment ?", R),
		_say("Le Mage", MAGE, "On descend."),
	])


# --- ACTE 4 : le monde demoniaque (chantier N3, docs/histoire.md section 6) ---
##
## CINQ NIVEAUX : les quatre grands demons (`lvl_07`, `lvl_10`, `lvl_11`,
## `lvl_12`), puis le pentacle brise (`lvl_13`).
##
## LA DIFFICULTE PROPRE A L ACTE 4 : il est NON LINEAIRE. Le joueur affronte les
## quatre demons dans l ordre qu il veut, donc AUCUNE scene de cet acte ne peut
## supposer ce que le joueur a deja vu. Chaque intro de demon se lit comme la
## premiere, chaque outro apporte le MEME fait — « celui-la non plus ne savait
## pas ce qu il signait » — par un chemin different, et se lit aussi bien en
## premier qu en dernier : aucune ne compte ce qui reste (« il y en a trois
## autres », « quatre seigneurs » supposaient un ordre, revue A4 n° 2).
##
## LE PENTACLE NE COMPTE PAS NON PLUS. Au 14/10, `SaveData.record_victory` ouvre
## `lvl_13` des la PREMIERE victoire contre un demon, alors que le plan veut les
## quatre (renvoye a B2 / gdscript-dev). Les scenes de `lvl_13` sont donc ecrites
## pour tenir dans les deux cas : elles parlent « des seigneurs », jamais « des
## quatre ».
##
## LA LOGIQUE DES CONTRATS, une fois pour toutes : chaque seigneur tient un
## contrat signe par le Roi squelette, et AU-DESSUS de la signature du roi, une
## ecriture petite et soignee que personne n a jamais vue. Malyk porte les ordres
## (`lvl_13`) ; l ecriture est celle du registre (`lvl_15`), donc de l enfant.
##
## Ce que le document appelle « le comique noir de l acte » tient dans cette
## repetition : plus le mage descend, moins il trouve de responsable.
##
## LES DECORS : le sanctuaire de pierre sous la lune pour les cinq. C est le seul
## des cinq `talk_*` qui ne soit pas une foret en plein jour ; une forge, des
## fosses ou une arene « de sable noir » jouees devant une cabane ou un arbre
## blanc se contredisaient (revue A4 n° 19). Des decors dedies restent a faire.

func _acte4() -> void:
	_lvl_07()
	_lvl_10()
	_lvl_11()
	_lvl_12()
	_lvl_13()


## VHARN, L ENCLUME — la forge. `lvl_07` existait sans aucune scene : c etait le
## dernier niveau du jeu quand la campagne en comptait sept. Ses scenes ont ete
## ecrites au chantier N3 et ne se jouaient JAMAIS : le niveau ne les citait pas
## (revue A4, n° 1). Il les cite depuis le chantier B4, et `test_story` refuse
## desormais toute scene qu aucun niveau ne cite.
##
## Le demon ne parle pas. C est le seul des quatre dans ce cas, et c est son
## personnage : une enclume n argumente pas. Le roi fait la lecture a sa place.
## La cadence du corniste, c est le MAGE qui la reconnait : le rat n etait pas au
## village (n° 13).
func _lvl_07() -> void:
	_scene("lvl_07_intro", "talk_shrine", [
		_narr("Une forge sans forgeron. Les marteaux tombent tout seuls, en cadence, sur des choses qui ne sont pas du metal."),
		_say("Le Mage", MAGE, "Cette cadence. C est celle du corniste, au village."),
		_say("Le Mage", MAGE_GRAVE, "Le Gardien avait une plaque dans la poitrine. Elle a ete faite ici."),
		_say("Le Roi squelette", SKELETON_KING, "Vharn ne te repondra pas. Il n a jamais rien dit a personne, meme quand il m a fait signer.", R),
		_say("Le Mage", MAGE, "Alors il encaissera. J ai le temps."),
	])
	_scene("lvl_07_outro", "talk_shrine", [
		_narr("L Enclume se fend en deux comme un moule de fonte. Dedans, pas de coeur : un contrat, grave dans le metal."),
		_say("Le Roi squelette", SKELETON_KING, "C est ma signature. Et au-dessus, une autre, que je n ai jamais vue. Petite et soignee.", R),
		_say("Le Mage", MAGE, "Donc il recevait des ordres, lui aussi."),
		_say("Le Rat pilote", RAT, "J ai travaille vingt ans dans un atelier comme ca, la-haut. Le patron fabrique ce qu on lui commande.", R),
		_say("L Enfant", CHILD, "Le pentacle a cinq branches. Quatre portent un nom. J ai compte.", R),
		_say("Le Mage", MAGE, "... Quand est-ce que tu as compte ?"),
		_narr("L enfant ne repond pas. Il regarde deja ailleurs."),
	])


## SESH, LA FAIM — les fosses. Le demon qui mange. Il parle, mais il ne repond
## pas aux questions : il est occupe.
##
## « Lui n a jamais rien signe » contredisait la logique des contrats (n° 12) :
## il a signe, SANS LIRE. Et « tout ce qu il avait avale ressort intact » etait
## faux a l ecran, ou ses proies sont detruites (revue A4 §1.3) : l outre creve,
## sans promettre ce qui en sort.
func _lvl_10() -> void:
	_scene("lvl_10_intro", "talk_shrine", [
		_narr("Des fosses tiedes, et le sol remue. Ce qui vit ici a deja mange ce qui vivait la avant."),
		_say("Le Mage", MAGE, "Sesh ! Qui t a donne l ordre de monter chez moi ?"),
		_say("Sesh", DEMON, "Monter ? On ne m a rien demande. J ai suivi l odeur.", R),
		_say("Le Mage", MAGE, "Quelle odeur ?"),
		_say("Sesh", DEMON, "Celle d un monde qui allait finir. Ca sent tres bon, un monde qui finit.", R),
		_say("Le Roi squelette", SKELETON_KING, "Il dit vrai, mage. Il a signe sans lire. Il etait deja a table.", R),
	])
	_scene("lvl_10_outro", "talk_shrine", [
		_narr("Sesh creve comme une outre trop pleine, au milieu des fosses qu il a videes."),
		_say("Le Mage", MAGE, "Il ne commandait rien. Il a suivi une odeur."),
		_say("Le Rat pilote", RAT, "Une odeur que quelqu un a mise dans l air, alors. Les fins de monde ne sentent pas tout seules.", R),
		_say("Le Mage", MAGE, "Quelqu un a prevenu les charognards avant le mort."),
		_say("L Enfant", CHILD, "C est plus gentil, non ? Comme ca personne n attend pour rien.", R),
		_say("Le Mage", MAGE_GRAVE, "... Petit, ne dis plus jamais ca comme ca."),
	])


## KALTEK, LA CHAINE — l arene. Le seul des quatre qui SE VANTE, et le seul dont
## la vantardise se retourne dans la meme scene : il croit tenir ses esclaves et
## il est tenu par le meme lien.
func _lvl_11() -> void:
	_scene("lvl_11_intro", "talk_shrine", [
		_narr("Une arene de sable noir. Des chaines partent du sol, des murs, du plafond, et toutes vont dans le meme sens."),
		_say("Kaltek", DEMON, "Le vieux ! On m a dit qu un homme avait recule le temps. C etait toi ?", R),
		_say("Le Mage", MAGE, "C etait moi."),
		_say("Kaltek", DEMON, "Alors tu comprends ce qu est une laisse. Moi je tiens quarante mille laisses.", R),
		_say("Le Mage", MAGE, "Et toi, qui te tient ?"),
		_say("Kaltek", DEMON, "Personne ne me tient ! Personne ! Frappe-moi, tu vas voir comme je suis libre.", R),
	])
	_scene("lvl_11_outro", "talk_shrine", [
		_narr("Kaltek tombe au milieu de ses chaines. Elles ne tenaient rien : elles PARTAIENT de lui, vers le haut, et elles continuent de tirer."),
		_say("Le Roi squelette", SKELETON_KING, "Voila. Il criait parce qu il ne pouvait pas regarder en l air.", R),
		_say("Le Mage", MAGE, "Un seigneur de la rage qui obeit. Ca n a plus de nom."),
		_say("Le Rat pilote", RAT, "Ca a un nom : un contremaitre.", R),
		_say("L Enfant", CHILD, "Tu veux te reposer avant la suite ?", R),
		_say("Le Mage", MAGE, "Non. Je commence a avoir une idee et elle ne me plait pas."),
	])


## YMOA, LE CERCLE — le temple. Le seul des quatre qui COMPRENNE, et qui le dise
## calmement : c est la scene qui prepare le pentacle. Il ne se defend pas, il
## explique — et ce qu il explique fait de lui un fonctionnaire.
func _lvl_12() -> void:
	_scene("lvl_12_intro", "talk_shrine", [
		_narr("Un temple de cristal ou chaque chose est protegee par une autre. Au fond, tres loin, une forme qui ne descend pas."),
		_say("Ymoa", DEMON, "Tu es celui qui est revenu en arriere. Approche, si tu peux.", R),
		_say("Le Mage", MAGE, "Tu ne viens pas te battre ?"),
		_say("Ymoa", DEMON, "Je ne me bats jamais. Je PROTEGE. C est une fonction, pas un caractere.", R),
		_say("Le Mage", MAGE, "Tu protegeais quoi, au juste ? Nuri a brule. Nox aussi."),
		_say("Ymoa", DEMON, "Je protegeais l ordre. On ne m a pas dit ce qu il contenait.", R),
	])
	_scene("lvl_12_outro", "talk_shrine", [
		_narr("Le cercle s eteint, et tout ce qu il protegeait meurt d un coup, sans avoir ete touche."),
		_say("Ymoa", DEMON, "... je n ai pas lu... personne ne lit...", R),
		_say("Le Mage", MAGE_GRAVE, "Un seigneur qui protege sans savoir quoi, et qui signe sans lire."),
		_say("Le Roi squelette", SKELETON_KING, "Bienvenue en enfer, mage. C est une administration.", R),
		_say("Le Mage", MAGE, "Alors on va jusqu au bout du couloir. Jusqu au pentacle."),
	])


## LE PENTACLE BRISE — fin de l acte 4. Les dialogues sont ceux du document
## (section 6, `lvl_18_intro` et `lvl_18_outro` dans sa numerotation), portes ici
## par `lvl_13`, qui est le cinquieme niveau de l acte dans le jeu.
##
## LA DERNIERE REPLIQUE DU MAGE EST LE SEUL INDICE HONNETE du plot twist : « ta
## main est froide comme le puits ». Elle est dans le document, elle est posee
## sans commentaire, et personne ne la releve — exactement comme « la gauche est
## fermee » a l acte 2. Le joueur doit pouvoir y repenser apres l acte 5.
##
## Corrige au chantier B4 (revue A4) :
##   - les deux tetes du niveau sont NOMMEES (n° 11) : la Reine gorgone, que le
##     mage a brisee au village (`lvl_02`) — son retour s explique, « ici on
##     recolle les statues » (n° 18) — et Malyk, qui porte les ordres ;
##   - plus de « quatre seigneurs, quatre contrats » : la scene tient que le
##     joueur ait abattu un seigneur ou les quatre (n° 2), et le pentacle a cinq
##     branches comme l a compte l enfant (n° 8).
func _lvl_13() -> void:
	_scene("lvl_13_intro", "talk_shrine", [
		_narr("Au centre du monde demoniaque, le pentacle. Devant sa porte, une silhouette que le mage connait."),
		_say("Le Mage", MAGE, "La Reine gorgone. Je l ai brisee dans le village de l enfant."),
		_say("Le Roi squelette", SKELETON_KING, "Ici, on recolle les statues. Elle garde la porte. Derriere, Malyk ramasse ce qui a deja servi.", R),
		_say("Le Mage", MAGE, "Malyk ?"),
		_say("Le Roi squelette", SKELETON_KING, "Celui qui porte les ordres aux seigneurs. Il mange ce qu il appelle. Les seigneurs n ont jamais lu l ordre : ils l ont RECU de lui.", R),
		_say("Le Rat pilote", RAT, "J ai deja vu ca. Un atelier ou personne n est le patron : ca veut dire que le patron n habite pas l atelier.", R),
		_say("Le Mage", MAGE_GRAVE, "Alors Malyk n est qu un coursier de plus. Je suis descendu pour rien."),
	])
	_scene("lvl_13_outro", "talk_shrine", [
		_narr("Malyk tombe, et le pentacle qui tient le monde demoniaque se fend en cinq morceaux. Le monde avec lui."),
		_say("Le Mage", MAGE, "Ce n est pas nous qui l avons casse."),
		_say("Le Roi squelette", SKELETON_KING, "Non. On nous RETIRE. Comme on retire une piece du plateau.", R),
		_say("L Enfant", CHILD, "Ne lachez pas ma main.", R),
		_say("Le Mage", MAGE, "Petit, ta main est froide comme le puits."),
		_narr("La chute ne va pas vers le bas."),
	])


# --- ACTE 5 : l espace divin (chantier N3, docs/histoire.md section 7) --------
##
## TROIS NIVEAUX, ET LA FIN DU JEU. C est l acte que personne n avait jamais vu :
## il n avait aucun niveau, donc aucune scene, et sa page de carte affichait « Le
## voyage ne va pas encore jusqu ici ».
##
## CE QUE CES SCENES DOIVENT FAIRE, dans l ordre :
##
##   `lvl_14` — installer que plus rien n impressionne. Les anciens boss sont des
##              pieces de musee, et le mage le constate sans emphase.
##   `lvl_15` — livrer le rebondissement du document : l extinction etait AU
##              PROGRAMME, a la date prevue, et le retour en arriere du mage n a
##              inquiete personne — il les a AMUSES.
##   `lvl_16` — le plot twist. L enfant est la divinite. Le dialogue est celui du
##              document, mot pour mot ou presque : c est la scene la plus ecrite
##              de tout le jeu et il n y avait aucune raison de la reecrire.
##
## LE PORTRAIT `child_god` EXISTE DEPUIS LE DEBUT dans `StoryScene.CAST` (un
## masque de dragon d or, `deity_man_01`) et n avait jamais ete cite par une
## seule scene : le retournement etait paye et jamais joue. Il l est ici, et le
## BASCULEMENT DE CLE se fait au milieu de `lvl_16_intro`, sur la replique ou
## l enfant « arrete de faire semblant » — avant elle il a le visage du gamin,
## apres il a celui du dieu. C est la seule scene du jeu ou un personnage change
## de portrait, et c est tout l interet d avoir garde deux cles.

func _acte5() -> void:
	_lvl_14()
	_lvl_15()
	_lvl_16()


## LA GALERIE DES SAISONS. Le mage traverse un musee de ses propres victoires.
## Le ton est plat expres : personne ne le menace, et c est ce qui inquiete.
## « Personne n est venu defendre la galerie » suivait un mini-boss et un boss
## (revue A4, n° 15) : les gardiens tombent, mais SANS BRUIT, comme des pieces
## qu on range.
func _lvl_14() -> void:
	_scene("lvl_14_intro", "talk_shrine", [
		_narr("Il n y a pas de sol. Il y a une galerie, et dans la galerie tout ce qui a deja ete efface, range par saison."),
		_say("Le Rat pilote", RAT, "Mage. La chose dans la vitrine, la. C est ton Gardien.", R),
		_say("Le Mage", MAGE, "C est un Gardien. Il y en a deux autres derriere."),
		_say("Le Roi squelette", SKELETON_KING, "Et une aile entiere pour mon cimetiere. Nous sommes une COLLECTION.", R),
		_say("Le Mage", MAGE_GRAVE, "Alors ce que j ai pris pour une guerre etait un inventaire."),
	])
	_scene("lvl_14_outro", "talk_shrine", [
		_narr("Les gardiens de la galerie tombent sans bruit, comme des pieces qu on range. On laisse passer le mage en visiteur."),
		_say("Le Rat pilote", RAT, "Ca ne se defend pas parce que ca ne vaut rien. On ne met pas de garde devant ses vieux outils.", R),
		_say("Le Mage", MAGE, "Le Gardien de la foret ne valait rien ?"),
		_say("Le Roi squelette", SKELETON_KING, "Toi non plus, mage. Moi non plus. C est reposant, d une certaine facon.", R),
		_narr("L enfant ne dit plus rien depuis le pentacle. Il marche devant."),
	])


## LE REGISTRE. Le rebondissement de l acte, et le plus dur a avaler du jeu : il
## n y a pas de coupable, il y a un CALENDRIER. Le mage n a pas ete attaque, il a
## ete programme — et son retour en arriere a servi de spectacle.
##
## L Horloger, boss du niveau, n etait jamais evoque : c est sa chute qui arrete
## le registre sur la ligne du mage. La note de la marge tient en un mot
## souligne deux fois (« souligne » revenait trois fois en deux phrases).
func _lvl_15() -> void:
	_scene("lvl_15_intro", "talk_shrine", [
		_narr("Des colonnes de noms qui montent plus haut que le regard. Ce ne sont pas des morts : ce sont des DATES."),
		_say("Le Mage", MAGE, "Nuri. Nox. Le sixieme jour, la septieme nuit. C etait ecrit avant."),
		_say("Le Roi squelette", SKELETON_KING, "Tombol aussi. Trois lignes plus bas, meme encre, meme main.", R),
		_say("Le Mage", MAGE, "Ce n est pas une invasion. C est une SAISON qui se termine."),
		_say("Le Rat pilote", RAT, "Je le savais. Je l ai vu une fois deja, et je n ai rien dit parce que reparer me tenait occupe.", R),
		_say("Le Mage", MAGE, "... Tu le savais."),
		_say("Le Rat pilote", RAT, "Je repare, mage. C est ma facon de refuser.", R),
	])
	_scene("lvl_15_outro", "talk_shrine", [
		_narr("L Horloger s arrete au milieu d un tour de cle, et le registre cesse de tourner ses pages. Il s ouvre sur la ligne du mage."),
		_narr("La date y a ete raturee une fois, et quelqu un a ecrit dans la marge. L ecriture est petite et soignee."),
		_say("Le Mage", MAGE, "Qu est-ce que ca dit ?"),
		_say("Le Roi squelette", SKELETON_KING, "Un seul mot : inattendu. Souligne deux fois, comme on souligne ce qui fait rire.", R),
		_say("Le Mage", MAGE_GRAVE, "J ai brule ma magie, mes annees et mes cheveux pour reculer le temps."),
		_say("Le Mage", MAGE_GRAVE, "Et ca les a fait SOURIRE."),
		_say("Le Roi squelette", SKELETON_KING, "On t a laisse courir pour voir jusqu ou tu irais. Tu es alle jusqu ici. Bravo, je suppose.", R),
		_narr("Au bout du registre, une porte, et derriere la porte un siege."),
	])


## LE SIEGE VIDE — LE PLOT TWIST. Dialogue du document, section 7.
##
## LE BASCULEMENT DE PORTRAIT est au milieu de la scene : l enfant parle deux
## fois avec le visage du gamin (`CHILD`), puis le narrateur dit qu il arrete de
## faire semblant, et toutes ses repliques suivantes portent `CHILD_GOD`. Le
## joueur voit litteralement le masque tomber dans la boite de dialogue.
##
## Ajouts du chantier B4 :
##   - « Les statues du village, c etait moi » paie le village petrifie de
##     `lvl_02`, ou la mort de la Reine gorgone n avait rendu personne ;
##   - le boss final porte la silhouette de CHRONOS en or (make_content.gd) :
##     la scene le montre et le mage le dit, sinon le joueur croit a un Chronos
##     de plus. « Il ne change pas de forme » reste vrai au moment ou le masque
##     tombe ; c est en se relevant du siege, pour le combat, qu il la prend ;
##   - « pendant cinq actes » sortait du recit : « jusqu ici ».
func _lvl_16() -> void:
	_scene("lvl_16_intro", "talk_shrine", [
		_narr("Au bout du registre, un siege. Il est vide depuis toujours."),
		_say("Le Mage", MAGE, "Ou est celui qui a signe ?"),
		_say("L Enfant", CHILD, "Il est la.", R),
		_narr("L enfant lache la main du mage. Il ne grandit pas, il ne change pas de forme. Il arrete simplement de faire semblant d avoir peur."),
		_say("L Enfant", CHILD_GOD, "Tu m as porte jusqu ici, mage. Merci. C etait tres long a pied.", R),
		_say("Le Mage", MAGE_GRAVE, "... Tu etais la depuis la premiere clairiere."),
		_say("L Enfant", CHILD_GOD, "J etais la depuis la date. C est moi qui l ai posee. Nuri le sixieme jour, Nox la septieme nuit. C etait propre.", R),
		_say("L Enfant", CHILD_GOD, "Les statues du village, c etait moi. Les gorgones n ont fait que signer en dessous.", R),
		_say("Le Roi squelette", SKELETON_KING, "Le gamin. C est le gamin. J ai signe un contrat pour UN GAMIN.", R),
		_say("L Enfant", CHILD_GOD, "Et puis tu as recule, et pour la premiere fois depuis tres longtemps je n ai pas su ce qui allait arriver.", R),
		_say("L Enfant", CHILD_GOD, "Tu ne peux pas savoir a quel point c etait bon.", R),
		_say("Le Mage", MAGE, "Tu m as laisse venir jusqu ici pour t amuser."),
		_say("L Enfant", CHILD_GOD, "Je t ai laisse venir jusqu ici parce que je voulais voir la fin. Fais-la belle.", R),
		_narr("Il s assoit sur le siege, et ce qui s en releve n a plus rien d un enfant : une bete de cadrans, toute en or."),
		_say("Le Mage", MAGE_GRAVE, "La forme de Chronos. Ton huissier portait ta forme depuis le premier matin."),
	])
	# L OUTRO DU DERNIER NIVEAU EST LA FIN DU JEU. Le document lui consacre une
	# scene a part (section 8, `ending`), mais `SceneRouter` ne connait que
	# `intro_story` et `outro_story` : la fin se joue donc ICI, en outro de
	# `lvl_16`, plutot que dans une scene que rien n appellerait jamais.
	#
	# LE DECOR CHANGE, et c est le seul endroit du jeu ou je me le permets :
	# `talk_glade`, la clairiere du tout premier matin. La boucle se referme a
	# l image sur le lieu ou le mage a sauve l enfant. Le texte dit que le
	# registre se referme sur une seule page qui recommence ; le fond le dit en
	# meme temps, sans une ligne de dialogue en plus.
	#
	# Chantier B4 (revue A4) : le rat et le roi, qui disparaissaient sans un mot,
	# ont leur adieu — ils RESTENT dans la boucle (n° 21). Et la derniere ligne
	# n annonce plus un « MODE INFINI » retire depuis la vague 10 (n° 6) : la
	# boucle sans fin du jeu est le MASSACRE, qui s ouvre quand chaque niveau de
	# la campagne est fini (SaveData.massacre_unlocked), fourche comprise — la
	# phrase reste donc vraie que le joueur ait fait une branche ou les deux.
	_scene("lvl_16_outro", "talk_glade", [
		_say("L Enfant", CHILD_GOD, "Bien joue. Vraiment.", R),
		_say("Le Mage", MAGE, "Rends-moi Nuri. Rends-moi Nox."),
		_say("L Enfant", CHILD_GOD, "Je ne rends rien, je PLACE. Et toi, je te place ici.", R),
		_narr("Le registre se referme sur une seule page, qui recommence."),
		_say("L Enfant", CHILD_GOD, "Tu as voulu recommencer une fois. Recommence autant que tu veux.", R),
		_say("Le Mage", MAGE, "... C est cense etre une punition ?"),
		_say("L Enfant", CHILD_GOD, "C est cense etre un cadeau. Tu verras a la millieme vague.", R),
		_say("Le Rat pilote", RAT, "Moi je repare. Meme une boucle, ca se repare.", R),
		_say("Le Roi squelette", SKELETON_KING, "Je reste. Plus de royaume, autant avoir une boucle.", R),
		_narr("Une clairiere, au petit matin. La meme odeur de mousse, la meme lumiere entre les branches."),
		_narr("LE MASSACRE, la boucle sans fin, s ouvre quand chaque niveau de la campagne est fini."),
	])

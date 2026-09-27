class_name TerrainProp
extends RefCounted
## Un objet PLANTE sur le champ de bataille : un arbre provocateur, un semis
## empoisonne, une nappe d eau.
##
## Pourquoi une classe et pas un Dictionary comme les murs et les zones : un mur
## n a que deux etats (debout, expire) et trois champs, alors qu un accessoire de
## terrain porte des PV, une portee de provocation, une zone attachee, un noeud
## visuel et un compteur de degats. Les dictionnaires anonymes de Battlefield sont
## deja le point le plus difficile a relire du fichier ; en ajouter un sixieme,
## deux fois plus gros que les autres, aurait rendu chaque acces (`p["zone"]`)
## impossible a verifier au moment de la compilation.
##
## Logique PURE : aucun noeud n est cree ici, aucune regle de temps. Battlefield
## garde la main sur `simulate()` — c est lui qui connait `SpeedGauge.world_delta`
## et lui seul doit decider quand une chose vieillit. TerrainProp ne repond qu a
## la question « qu est-ce que cet objet, ou est-il, tient-il encore ».

## Ce que l accessoire est. La FORME sert au visuel (arbre du pack, nappe d eau) ;
## la REGLE, elle, depend des champs ci-dessous et pas du genre — un arbre sans
## `taunt_radius` n attire personne, et c est un cas legitime.
##
## Les quatre genres ajoutes par les sorts de terrain PERMANENTS :
##   RIVER   ligne d eau sur toute la largeur, franchie par un seul pont ;
##   BRAMBLE ronces qui ralentissent ;
##   PIT     fosse qui rend vulnerable ;
##   ALTAR   autel qui invoque des allies a intervalle (un GENERATEUR).
enum Kind { TREE, WATER, RIVER, BRAMBLE, PIT, ALTAR }

## Groupe de TOUS les objets de terrain (accessoires et murs). C est le contrat
## promis au futur boss « Briseur de terrain » : il n a pas a connaitre les
## listes internes de Battlefield, il parcourt ce groupe et appelle `destroy()`
## sur chaque membre. Voir `Anchor`.
const GROUP: StringName = &"terrain_props"

var kind: int = Kind.TREE
var position: Vector2 = Vector2.ZERO
## Secondes de vie restantes. INF = PERMANENT : l objet reste jusqu a la fin du
## combat, sauf s il est abattu, remplace par un plus recent (plafond de
## GameConfig.TERRAIN_PERMANENT_MAX) ou detruit par `destroy()`.
##
## LA CONVENTION DES CARTES : un `EffectSpec.duration` NUL OU NEGATIF sur une cle
## de terrain veut dire « jusqu a la fin du combat ». Zero ne peut pas vouloir
## dire « instantane » pour un objet pose, et c est la seule valeur qu un .tres
## ecrit par erreur sans duree porterait : on prefere qu elle donne un objet qui
## reste plutot qu un objet qui disparait a l image suivante. La traduction en
## INF est faite une seule fois, par `lifetime_for()`.
var time_left: float = 0.0
## Ordre de pose, croissant. Sert a trouver le PLUS ANCIEN objet permanent quand
## le plafond est atteint ; l ordre du tableau `props` ne suffit pas, il bouge a
## chaque retrait.
var serial: int = 0
## Cellules de navigation que l objet BLOQUE (la riviere). Liberees a sa
## disparition, exactement celles-la : la grille compte ses blocages, un mur
## pose sur la meme rangee ne doit pas etre debloque par la fin de la riviere.
var cells: Array[Vector2i] = []
## Colonne du pont de la riviere, -1 sinon.
var bridge_col: int = -1
## GENERATEUR : intervalle entre deux invocations (secondes MONDE), 0 = aucun.
var summon_every: float = 0.0
var summon_timer: float = 0.0
## Allie invoque : degats par coup et duree de vie.
var summon_damage: float = 0.0
var summon_duration: float = 0.0
## Noeud du groupe `GROUP`, toujours cree (meme en headless, ou `node` reste
## nul) : le contrat du Briseur de terrain ne doit pas dependre de l ecran.
var anchor: Node = null
## PV restants. 0 ou moins = l accessoire n est pas destructible et seule la duree
## le tue ; c est le cas de la nappe d eau, qu on ne peut pas frapper.
var hp: float = 0.0
var max_hp: float = 0.0
## Rayon dans lequel les monstres VISENT cet objet au lieu du mage. 0 = il
## n attire personne (la nappe d eau).
var taunt_radius: float = 0.0
## Rayon de morsure : un monstre a cette distance frappe l accessoire, et c est
## aussi la zone que `covers()` considere comme « dedans ».
##
## Deduit du GENRE par Battlefield (un arbre est plus large qu une flaque), jamais
## expose comme parametre de carte : c est une donnee de silhouette, pas un levier
## d equilibrage, et la laisser regler par .tres inviterait a fabriquer un arbre
## qu on frappe a 400 px.
var reach: float = 70.0
## Vitesse du courant en px/s a x1, positive vers le HAUT. 0 = aucun courant.
## C est ce qui separe la nappe d eau du Champ de givre : le givre ralentit la
## descente, l eau la RENVERSE.
var current: float = 0.0
## Rayon du courant / de la nappe. Distinct de `taunt_radius` : un arbre attire de
## loin mais n inonde rien, une nappe inonde large mais n attire pas.
var area: float = 0.0
## La zone au sol attachee, vide s il n y en a pas. Elle doit mourir AVEC
## l accessoire, sinon le joueur abattrait son propre arbre et garderait le poison
## gratuitement.
##
## On retient le DICTIONNAIRE de la zone, pas son index dans `Battlefield.zones` :
## les zones sont retirees de ce tableau en cours de simulation, donc un index
## designerait une autre zone des la premiere expiration.
var zone: Dictionary = {}
## Noeud visuel, libere par Battlefield quand l accessoire disparait.
var node: Node = null


func is_alive() -> bool:
	return time_left > 0.0 and (max_hp <= 0.0 or hp > 0.0)


## Reste-t-il jusqu a la fin du combat ?
func is_permanent() -> bool:
	return is_inf(time_left)


## Bloque-t-il la navigation au sol ?
func blocks() -> bool:
	return not cells.is_empty()


## Duree d une carte -> duree de vie. Seul point de traduction de la convention
## « duration <= 0 = permanent » (voir `time_left`).
static func lifetime_for(duration: float) -> float:
	return INF if duration <= 0.0 else duration


## Le noeud du groupe `terrain_props`. Un TerrainProp est un RefCounted et ne peut
## pas entrer dans un groupe ; les murs sont des dictionnaires. Chacun recoit donc
## une ANCRE, un Node2D vide pose a sa place, qui porte le contrat :
##   - membre du groupe `TerrainProp.GROUP` ;
##   - `destroy()` retire l objet exactement comme s il avait ete abattu.
## Le Briseur de terrain n a besoin de rien d autre, et un futur objet de terrain
## n aura qu a poser une ancre pour etre concerne.
class Anchor extends Node2D:
	## Ce que `destroy()` declenche : la fonction de retrait de Battlefield, liee
	## a l objet. Un Callable plutot qu une reference au champ de bataille : l ancre
	## n a pas a savoir si elle garde un arbre ou un mur.
	var on_destroy: Callable = Callable()
	## Genre de l objet garde, pour qu un boss puisse choisir sa cible (-1 = mur).
	var kind: int = -1

	func _init() -> void:
		name = "TerrainAnchor"
		add_to_group(TerrainProp.GROUP)

	func destroy() -> void:
		if on_destroy.is_valid():
			var cb: Callable = on_destroy
			# Coupe AVANT l appel : le retrait libere l ancre, et un second appel
			# (deux coups du boss dans la meme image) ne doit rien refaire.
			on_destroy = Callable()
			cb.call()


## Nom en clair d un genre d objet, -1 = mur (convention de `Anchor.kind`). Sert a
## la legende du Briseur de terrain : « BRISE : ARBRE » dit au joueur ce qu il va
## perdre avant de le perdre.
static func kind_label(k: int) -> String:
	match k:
		Kind.TREE: return "arbre"
		Kind.WATER: return "nappe"
		Kind.RIVER: return "riviere"
		Kind.BRAMBLE: return "ronces"
		Kind.PIT: return "fosse"
		Kind.ALTAR: return "autel"
	return "mur"


## Destructible ? Une nappe d eau ne se frappe pas : on ne peut pas casser une
## flaque, et laisser les monstres la taper leur donnerait une cible ou ils
## devraient simplement patauger.
func is_breakable() -> bool:
	return max_hp > 0.0


## Encaisse un coup. Renvoie true si l accessoire vient de tomber, pour que
## Battlefield sache qu il a un nettoyage a faire (zone, noeud, eclat).
func take_damage(amount: float) -> bool:
	if not is_breakable() or hp <= 0.0:
		return false
	hp = maxf(hp - amount, 0.0)
	return hp <= 0.0


## Ce point est-il assez pres pour que l accessoire soit frappe ?
func covers(point: Vector2) -> bool:
	return position.distance_to(point) <= reach


## Ce monstre doit-il viser l accessoire plutot que le mage ?
##
## La provocation ne regarde QUE la distance, pas la hauteur : un monstre deja
## passe sous l arbre doit pouvoir remonter le frapper. Sans cela le joueur
## planterait un arbre derriere une vague et n obtiendrait rien du tout.
func attracts(point: Vector2) -> bool:
	return taunt_radius > 0.0 and position.distance_to(point) <= taunt_radius


## Le courant porte-t-il ce point ? Reponse separee de `attracts` : un accessoire
## peut inonder sans attirer, et l inverse.
func floods(point: Vector2) -> bool:
	return current != 0.0 and area > 0.0 and position.distance_to(point) <= area

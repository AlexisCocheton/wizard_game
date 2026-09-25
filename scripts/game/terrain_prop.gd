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
enum Kind { TREE, WATER }

var kind: int = Kind.TREE
var position: Vector2 = Vector2.ZERO
## Secondes de vie restantes. INF pour un accessoire qui ne meurt que sous les
## coups (aucune carte livree ne le fait, mais le mur permanent a montre que le
## cas arrive : on garde la porte ouverte sans brancher de branche speciale).
var time_left: float = 0.0
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

class_name MassacreMode
extends RefCounted
## Le MASSACRE : un niveau infini A PART, ouvert depuis son propre onglet du menu.
##
## A ne pas confondre avec l INFINI (GameEnums.Mode.INFINITE), qui prolonge UN
## niveau de campagne : ses monstres, et une descente a travers les cinq mondes
## qui changent toutes les WaveBudget.WORLD_EVERY vagues.
##
## Le Massacre, lui, n appartient a aucun niveau :
##   - monstres : ceux de TOUS les niveaux, melanges, sans monde qui pese ;
##   - paliers  : les boss et mini-boss de TOUT le jeu ;
##   - fond     : le Seuil divin, fixe (voir BACKDROP) ;
##   - deck     : le deck du joueur (onglet Deck), 15 cartes valides.
##
## Il n existe donc aucun .tres pour lui : son LevelDef est fabrique ici, a la
## demande. Un .tres de niveau serait compte par la campagne (campaign_progress,
## carte des actes, audit des objectifs) alors que le Massacre n en fait pas
## partie.

## Identifiant porte par la charge utile du routeur ("level_id"). Il ne doit
## jamais exister dans ContentDB.levels : c est ce qui le distingue d un niveau.
const LEVEL_ID: StringName = &"massacre"
const DISPLAY_NAME: String = "Massacre"

## LE FOND : le Seuil divin, et il ne change pas.
##
## Pourquoi pas un fond qui tourne : en INFINI, le fond qui change ANNONCE un
## monde, et le monde change vraiment ce qui descend. Ici tous les monstres sont
## melanges ; un fond qui tournerait promettrait un changement qui n arrive pas.
## Pourquoi pas le ciel etoile du menu : c est l ecran d ATTENTE du jeu, pas un
## lieu. Le Seuil divin est deja, dans le jeu, le lieu ou les quatre mondes
## CONVERGENT (voir WaveBudget.WORLDS) : c est exactement ce qu est le Massacre.
const BACKDROP: String = "act5_divine"


## Le niveau a jouer pour (level_id, mode). Un seul point de resolution pour la
## partie, le briefing et l ecran de defaite : les trois recoivent le meme
## "level_id" dans la charge utile, et le Massacre n est pas dans ContentDB.
static func resolve_level(level_id: StringName, mode: GameEnums.Mode) -> LevelDef:
	if mode == GameEnums.Mode.MASSACRE or level_id == LEVEL_ID:
		return level_def()
	return ContentDB.levels.get(level_id)


## Le LevelDef fabrique du Massacre : aucune vague ecrite (tout est genere par
## budget), aucun objectif, aucune histoire, aucun niveau suivant.
static func level_def() -> LevelDef:
	var d := LevelDef.new()
	d.id = LEVEL_ID
	d.display_name = DISPLAY_NAME
	d.act = 0
	d.subtitle = "Tous les mondes a la fois"
	d.backdrop = BACKDROP
	d.enemy_pool = enemy_pool()
	return d


## Les monstres de TOUS les niveaux de la campagne, sans doublon, boss et
## projectiles exclus.
##
## Pris dans les niveaux (pool ET vagues ecrites) et non dans tout le bestiaire :
## ContentDB.enemies contient aussi des creatures qui ne descendent jamais d elles-
## memes (invocations, rejetons d une division). Les lacher en vague les ferait
## jouer hors de leur role. Trie par id : le tirage d une graine donnee ne doit
## pas dependre de l ordre de lecture du disque (voir le piege des boss affames
## dans la memoire du projet).
static func enemy_pool() -> Array[EnemyDef]:
	var vus: Dictionary = {}
	var out: Array[EnemyDef] = []
	for level_id in ContentDB.levels.keys():
		var lvl: LevelDef = ContentDB.levels.get(level_id)
		if lvl == null:
			continue
		var source: Array[EnemyDef] = []
		for d in lvl.enemy_pool:
			source.append(d)
		for w: WaveDef in lvl.waves:
			if w == null:
				continue
			for e: WaveEntry in w.entries:
				if e != null:
					source.append(e.enemy)
		for d: EnemyDef in source:
			if d == null or d.is_boss() or d.projectile or vus.has(d.id):
				continue
			vus[d.id] = true
			out.append(d)
	out.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool: return String(a.id) < String(b.id))
	return out


## Les boss ET mini-boss de tout le jeu : ce sont eux qui tombent aux paliers.
static func boss_pool() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.is_boss():
			out.append(d)
	out.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool: return String(a.id) < String(b.id))
	return out

class_name LevelDef
extends Resource
## Un niveau de la campagne.

@export var id: StringName = &""
@export var display_name: String = ""
## --- Narration (voir docs/histoire.md) ---
## Tout ce bloc est FACULTATIF : un niveau sans texte reste parfaitement jouable.
## C est volontaire, pour qu ajouter un niveau ne demande pas d ecrire un scenario.
## Acte de la campagne : 1 Monde volant, 2 Grand Cimetiere, 3 Monde demoniaque,
## 4 Monde d origine. 0 = hors campagne.
@export var act: int = 0
## Sous-titre court affiche sous le nom du niveau sur la carte de campagne.
@export var subtitle: String = ""
## Texte lu au briefing, AVANT le combat : ou on est et pourquoi on y va.
@export_multiline var intro_text: String = ""
## Texte lu a la victoire : le rebondissement que le niveau vient de reveler.
@export_multiline var outro_text: String = ""
## Tuiles du decor : "grass" ou "sand" (tilesets Tiny Swords).
@export var terrain: String = "grass"
@export var waves: Array[WaveDef] = []
## Pool de monstres utilisable par la generation procedurale de vagues.
@export var enemy_pool: Array[EnemyDef] = []
## Deck impose en mode Exploration.
@export var exploration_deck: Array[SpellCard] = []
## Exactement 3 objectifs (verifie par l'etage AUDIT).
@export var objectives: Array[ObjectiveDef] = []
## Carte legendaire debloquee en validant les 3 objectifs.
@export var legendary_reward: SpellCard
## Niveaux accessibles apres victoire.
@export var next_levels: Array[StringName] = []


func boss_wave() -> WaveDef:
	for w in waves:
		if w != null and w.is_boss:
			return w
	return null

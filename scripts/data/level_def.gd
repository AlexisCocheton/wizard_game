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
## Scenes de visual novel (DialogueDef dans resources/story/), jouees par
## SceneRouter AVANT le briefing et APRES la victoire, une seule fois par
## profil. Vide = pas de scene : meme regle que les textes ci-dessus, un niveau
## sans histoire reste jouable. Voir docs/histoire.md.
@export var intro_story: StringName = &""
@export var outro_story: StringName = &""
## Tuiles du decor : "grass" ou "sand" (tilesets Tiny Swords).
## Ne sert plus que de REPLI, quand `backdrop` est vide.
@export var terrain: String = "grass"
## Fond peint de l acte, dans `assets/backdrops/` sans l extension :
## "act1_sky", "act2_graveyard", "act3_demon", "act4_origin".
## Vide = on retombe sur les tuiles `terrain`, pour qu un niveau sans fond
## reste jouable (meme regle que les champs narratifs).
@export var backdrop: String = ""
@export var waves: Array[WaveDef] = []
## Pool de monstres utilisable par la generation procedurale de vagues.
@export var enemy_pool: Array[EnemyDef] = []
## Deck impose en mode Exploration.
@export var exploration_deck: Array[SpellCard] = []
## Exactement 3 objectifs (verifie par l'etage AUDIT), CLASSES PAR DIFFICULTE :
## l objectif 1 est le plus accessible, le 3 le plus dur. Leur position est leur
## rang (voir objective_rank) et fixe la rarete de la carte qu ils debloquent.
@export var objectives: Array[ObjectiveDef] = []

## --- PROGRESSION DES CARTES (vague 5, chantier P) ---
##
## Le pool de montee de niveau en campagne = le deck du niveau + ces cartes
## NOUVELLES + les cartes debloquees par les objectifs deja reussis de CE niveau
## (RunState.levelup_pool). Il n y a plus de recompense de boss d office ni de
## legendaire "3/3 objectifs" : l ancien champ `legendary_reward` a ete RETIRE
## (un profil qui l avait obtenue la garde, voir SaveData._migrate).

## Les cartes NOUVELLES que ce niveau fait decouvrir a la montee de niveau
## (LEVELUP_NEW_CARDS attendues, aucune deja dans le deck du niveau). Vide = le
## pool se reduit au deck, le jeu tourne quand meme : l AUDIT le signale en
## avertissement tant que le contenu n est pas ecrit.
@export var levelup_cards: Array[SpellCard] = []

## La carte que debloque chaque objectif, A LA MEME POSITION que `objectives`.
##
## POURQUOI ICI ET PAS SUR ObjectiveDef : un meme ObjectiveDef est PARTAGE par
## plusieurs niveaux (ids deduits du controle, DEC-023 : `obj_untouched` sert a
## cinq niveaux). Une carte portee par l objectif serait donc la meme partout,
## et son rang aussi — alors qu un meme controle peut etre le plus facile d un
## niveau et le plus dur d un autre. Le niveau est le seul a savoir les deux.
## Une case nulle ou absente = cet objectif ne debloque rien (encore).
@export var objective_rewards: Array[SpellCard] = []

## Niveaux accessibles apres victoire.
@export var next_levels: Array[StringName] = []

## Nombre de cartes nouvelles attendues par niveau (demande du co-auteur).
const LEVELUP_NEW_CARDS: int = 3

## Premier acte ou les POUVOIRS PASSIFS existent (demande du co-auteur : "rien
## avant l acte 2"). En campagne, un niveau d acte inferieur n en propose ni
## n en active aucun ; hors campagne, il faut avoir OUVERT un niveau de cet acte.
## Lu par RunState.passives_allowed() et SaveData.passives_unlocked().
const PASSIVES_FROM_ACT: int = 2


## Ce niveau de campagne admet-il les passifs ?
func allows_passives() -> bool:
	return act >= PASSIVES_FROM_ACT

## Rarete de la carte debloquee selon le RANG de l objectif (1, 2, 3) : le plus
## facile rapporte une rare, le plus dur une legendaire. Indexe par rang - 1.
const REWARD_RARITY_BY_RANK: Array[int] = [
	GameEnums.Rarity.RARE, GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY,
]


## Rang de difficulte de l objectif en position `index` : 1 = le plus facile.
## C est sa POSITION, pas un champ : deux objectifs ne peuvent donc jamais
## revendiquer le meme rang, et reclasser = reordonner la liste.
static func objective_rank(index: int) -> int:
	return index + 1


## La carte debloquee par l objectif en position `index`, ou null.
func objective_reward(index: int) -> SpellCard:
	if index < 0 or index >= objective_rewards.size():
		return null
	return objective_rewards[index]


## La carte debloquee par cet objectif DANS CE NIVEAU, ou null. Par id et non
## par identite : un .tres recharge ailleurs reste le meme objectif.
func reward_of(objective: ObjectiveDef) -> SpellCard:
	if objective == null:
		return null
	for i in objectives.size():
		if objectives[i] != null and objectives[i].id == objective.id:
			return objective_reward(i)
	return null


## Rarete attendue de la recompense du rang donne, -1 hors bornes.
static func reward_rarity_for_rank(rank: int) -> int:
	if rank < 1 or rank > REWARD_RARITY_BY_RANK.size():
		return -1
	return REWARD_RARITY_BY_RANK[rank - 1]


## Ce qui MANQUE encore au contenu de progression de ce niveau. Lu par l AUDIT,
## qui le signale en AVERTISSEMENT : le contenu (3 cartes par niveau, une carte
## par objectif) vient d un chantier posterieur au moteur.
func missing_progression() -> Array[String]:
	var out: Array[String] = []
	var nouvelles: int = 0
	for c in levelup_cards:
		if c != null:
			nouvelles += 1
	if nouvelles < LEVELUP_NEW_CARDS:
		out.append("%d carte(s) nouvelle(s) de montee de niveau sur %d"
			% [nouvelles, LEVELUP_NEW_CARDS])
	for i in objectives.size():
		if objective_reward(i) == null:
			out.append("l objectif %d ne debloque aucune carte" % objective_rank(i))
	return out


## Ce qui est FAUX dans le contenu de progression (et non simplement absent).
## L AUDIT en fait des echecs : une carte en trop ou de mauvaise rarete ne se
## corrige pas toute seule en ecrivant la suite du contenu.
func progression_errors() -> Array[String]:
	var out: Array[String] = []
	if levelup_cards.size() > LEVELUP_NEW_CARDS:
		out.append("%d cartes de montee de niveau, %d au plus"
			% [levelup_cards.size(), LEVELUP_NEW_CARDS])
	var vues: Dictionary = {}
	for c in levelup_cards:
		if c == null:
			out.append("carte de montee de niveau nulle")
			continue
		if exploration_deck.has(c):
			out.append("%s est deja dans le deck : elle n est pas NOUVELLE" % c.id)
		if vues.has(c.id):
			out.append("%s listee deux fois en montee de niveau" % c.id)
		vues[c.id] = true
		if c.is_passive and not allows_passives():
			out.append("%s est un passif, or l acte %d n en admet aucun" % [c.id, act])
	if objective_rewards.size() > objectives.size():
		out.append("%d recompenses d objectif pour %d objectifs"
			% [objective_rewards.size(), objectives.size()])
	for i in mini(objective_rewards.size(), objectives.size()):
		var r: SpellCard = objective_rewards[i]
		if r == null:
			continue
		if r.is_passive and not allows_passives():
			out.append("l objectif %d debloque le passif %s, or l acte %d n en admet aucun"
				% [objective_rank(i), r.id, act])
		var voulue: int = reward_rarity_for_rank(objective_rank(i))
		if voulue >= 0 and r.rarity != voulue:
			out.append("l objectif %d debloque %s (%s), %s attendue" % [
				objective_rank(i), r.id, GameEnums.rarity_name(r.rarity),
				GameEnums.rarity_name(voulue)])
	return out


func boss_wave() -> WaveDef:
	for w in waves:
		if w != null and w.is_boss:
			return w
	return null

class_name LevelDef
extends Resource
## Un niveau de la campagne.

@export var id: StringName = &""
@export var display_name: String = ""
## --- Narration (voir docs/histoire.md) ---
## Tout ce bloc est FACULTATIF : un niveau sans texte reste parfaitement jouable.
## C est volontaire, pour qu ajouter un niveau ne demande pas d ecrire un scenario.
## Acte de la campagne, de 1 a 5, dans l ordre du voyage (docs/histoire.md).
## 0 = hors campagne.
@export var act: int = 0
## Sous-titre court affiche sous le nom du niveau sur la carte de campagne. Une
## seule veine depuis la vague 10 (B2) : une ligne de RECIT, jamais un conseil de
## jeu (le briefing dit deja les mecaniques).
@export var subtitle: String = ""
## Texte lu au briefing, AVANT le combat : ou on est et pourquoi on y va.
@export_multiline var intro_text: String = ""
## Ancien texte de victoire. Il n est affiche NULLE PART : la scene de fin
## (outro_story) le dit. Laisse vide par le contenu depuis la vague 10 (B2) : un
## texte qu on ne lit pas finit faux (revue A4, §2.7 point 6).
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
## Deck impose en campagne AVANT la vague 10. Depuis, le deck de campagne se
## deduit de `base_commons` et des objectifs reussis (campaign_deck) ; ce champ
## reste le REPLI d un niveau sans deck de base.
@export var exploration_deck: Array[SpellCard] = []
## Exactement 3 objectifs (verifie par l'etage AUDIT), CLASSES PAR DIFFICULTE :
## l objectif 1 est le plus accessible, le 3 le plus dur. Leur position est leur
## rang (voir objective_rank) et fixe la rarete de la carte qu ils debloquent.
@export var objectives: Array[ObjectiveDef] = []

## --- PROGRESSION DES CARTES (vague 5, chantier P) ---
##
## Jusqu a la vague 10, le pool de montee de niveau en campagne = le deck du
## niveau + ces cartes NOUVELLES + les cartes debloquees par les objectifs deja
## reussis de CE niveau. Depuis (14/10) : cartes obtenues + communes de l acte, et
## cet ancien pool seulement en REPLI, pour un niveau sans deck de base (voir
## RunState.levelup_pool et la section A3 en fin de fichier). Il n y a plus de recompense de boss d office ni de
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

## VAGUE 10 (chantier B2) : ce niveau ne s ouvre qu une fois TOUS les niveaux de
## campagne qui le citent dans `next_levels` finis (lvl_13 apres les quatre
## demons). Faux = il s ouvre a la premiere victoire d un de ses precedents :
## c est la regle d une FOURCHE (lvl_21 s ouvre apres lvl_05 OU lvl_06), qu une
## regle generale « tous les precedents » aurait verrouillee. Lu par
## SaveData.record_victory.
@export var requires_all_previous: bool = false

## --- STRUCTURE DE LA VAGUE 10 (chantier A3, regles du co-auteur du 14/10) ---
## Tous ces champs sont FACULTATIFS : vides, le niveau se joue comme avant la
## vague 10 (voir les replis documentes dans la section en fin de fichier).

## LE DECK DE BASE DE LA CAMPAGNE : exactement BASE_COMMONS_COUNT communes,
## distinctes. La PREMIERE est la commune NOUVELLE du niveau, les deux autres
## font tourner les communes de l acte. Le deck joue en campagne se DEDUIT de
## cette liste et des objectifs reussis (campaign_deck, table du co-auteur).
## Vide = repli sur `exploration_deck` (contenu d avant la vague 10).
@export var base_commons: Array[SpellCard] = []

## Les PASSIFS que la VICTOIRE EN CAMPAGNE de ce niveau debloque (1 ou 2 par
## niveau de campagne, le reste dans les quetes annexes, qui utilisent le meme
## champ). Gagnes a la victoire et non par objectif : les objectifs rapportent
## deja les cartes du deck, et une victoire est la seule etape que tout joueur
## franchit. Deduit de l etat « niveau fini », rien n est ecrit : un ancien profil
## qui a deja fini le niveau a ses passifs sans migration.
@export var passive_unlocks: Array[SpellCard] = []

## QUETE ANNEXE : un niveau hors du fil de la campagne. Il a un acte de
## RATTACHEMENT (`act`, qui decide des passifs et des communes de son pool), ne
## compte PAS dans SaveData.campaign_progress (sinon une annexe deviendrait
## obligatoire pour ouvrir le Massacre) et s affiche sur la page « Quetes
## annexes » de la carte, jamais sur la page de son acte.
@export var side_quest: bool = false
## Condition d ouverture d une annexe : ce niveau de CAMPAGNE doit etre FINI.
## Vide = aucune condition de niveau : l annexe s ouvre des qu un niveau de
## campagne de son acte de rattachement est ouvert.
@export var side_quest_after: StringName = &""
## Condition d ouverture d une annexe : ce PERSONNAGE (cle AnimCatalog d une
## recompense CHARACTER, ex. "squire") doit etre debloque au compte. Vide =
## aucune condition de personnage. Les deux conditions se cumulent.
@export var side_quest_character: String = ""

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
	# VAGUE 10 (chantier B2) : un niveau qui a son deck de base n a plus de cartes
	# nouvelles a lui. Son pool de montee de niveau est « cartes obtenues +
	# communes de l acte » (RunState.levelup_pool), qui ne lit plus levelup_cards :
	# en exiger trois serait reclamer une donnee morte.
	if nouvelles < LEVELUP_NEW_CARDS and not has_base_commons():
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
		if exploration_deck.has(c) or base_commons.has(c):
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
	# Vague 10 (chantier A3) : deck de base, passifs debloques, annexes.
	out.append_array(structure_errors())
	return out


func boss_wave() -> WaveDef:
	for w in waves:
		if w != null and w.is_boss:
			return w
	return null


# =====================================================================
# CHANTIER A3 (vague 10) — DECK DE CAMPAGNE QUI EVOLUE, QUETES ANNEXES.
# Section a part pour se fusionner sans toucher au reste du fichier.
# =====================================================================

## Nombre de communes du deck de base (regle du co-auteur : « 3 communes x4 »).
const BASE_COMMONS_COUNT: int = 3

## Au plus ce nombre de passifs debloques par la victoire d un niveau (« 1 ou 2
## debloquables par niveau de campagne »). Une annexe suit la meme borne.
const MAX_PASSIVE_UNLOCKS: int = 2

## LA TABLE DU CO-AUTEUR (14/10), a la lettre. Cle = masque des objectifs
## REUSSIS : bit 0 = rang 1 (rare), bit 1 = rang 2 (epique), bit 2 = rang 3
## (legendaire). Valeur = [nouvelle, 2e commune, 3e commune, rare, epique,
## legendaire] en EXEMPLAIRES, la nouvelle etant base_commons[0], la 2e
## base_commons[1], la 3e base_commons[2].
##
## LECTURE DE LA NOTATION DU CO-AUTEUR. Il ecrit les communes « a/b/c » et
## precise pour E : « 3/3/4, la nouvelle a 4 ». La nouvelle est donc la
## TROISIEME de sa notation, qui se lit (2e, 3e, nouvelle) ; c est la seule
## lecture ou la nouvelle n a jamais moins de 3 exemplaires, ce qui est
## l intention (le niveau la fait decouvrir). D ou, de sa notation a la table :
##   aucun  4/4/4               -> [4, 4, 4, 0, 0, 0]
##   R      3/3/3 + R x3        -> [3, 3, 3, 3, 0, 0]
##   E      3/3/4 + E x2        -> [4, 3, 3, 0, 2, 0]
##   L      4/4/3 + L x1        -> [3, 4, 4, 0, 0, 1]
##   R+E    2/2/3 + R x3 + E x2 -> [3, 2, 2, 3, 2, 0]
##   R+L    2/3/3 + R x3 + L x1 -> [3, 2, 3, 3, 0, 1]
##   tout   2/2/3 + R x2 + E x2 + L x1 -> [3, 2, 2, 2, 2, 1]
## E+L N EST PAS DANS LA TABLE DU CO-AUTEUR. Regle deduite et documentee :
##   E+L    3/3/3 + E x2 + L x1 -> [3, 3, 3, 0, 2, 1]
## Pourquoi : les recompenses gardent les exemplaires qu elles ont SEULES (E x2
## comme dans E, L x1 comme dans L ; seul « tout » reduit la rare) ; la nouvelle
## garde 3 comme dans toute combinaison a deux objectifs ou plus ; il reste 6
## exemplaires pour deux communes, partages egalement (3/3), comme dans R.
## Chaque ligne fait 12 cartes, 6 ids au plus et respecte les plafonds par
## rarete (4/3/2/1) : verifie pour les huit cas par test_campaign_deck.
const CAMPAIGN_DECK_TABLE: Dictionary = {
	0: [4, 4, 4, 0, 0, 0],
	1: [3, 3, 3, 3, 0, 0],
	2: [4, 3, 3, 0, 2, 0],
	4: [3, 4, 4, 0, 0, 1],
	3: [3, 2, 2, 3, 2, 0],
	5: [3, 2, 3, 3, 0, 1],
	6: [3, 3, 3, 0, 2, 1],
	7: [3, 2, 2, 2, 2, 1],
}


## Le niveau porte-t-il un deck de base complet (BASE_COMMONS_COUNT cartes non
## nulles) ? Faux = repli sur exploration_deck partout ou le deck de base sert.
func has_base_commons() -> bool:
	if base_commons.size() != BASE_COMMONS_COUNT:
		return false
	for c in base_commons:
		if c == null:
			return false
	return true


## Un niveau du fil de la CAMPAGNE (un acte, pas une annexe). Seuls ceux-la
## comptent dans campaign_progress et fournissent les communes de leur acte.
func is_campaign_level() -> bool:
	return act > 0 and not side_quest


## La commune NOUVELLE du niveau (base_commons[0]), ou null en repli.
func new_common() -> SpellCard:
	return base_commons[0] if has_base_commons() else null


## Masque de la table a partir des RANGS reussis (1, 2, 3 ; les autres valeurs
## et les doublons sont ignores). Un rang dont l objectif ne rapporte AUCUNE
## carte de deck (case vide, ou passif : un passif ne se pioche pas) ne compte
## pas : sinon la table enleverait des communes pour une carte qui n existe pas,
## et le deck tomberait sous 12.
func campaign_deck_mask(ranks_done: Array) -> int:
	var mask: int = 0
	for r in ranks_done:
		var rang: int = int(r)
		if rang < 1 or rang > REWARD_RARITY_BY_RANK.size():
			continue
		var carte: SpellCard = objective_reward(rang - 1)
		if carte == null or carte.is_passive:
			continue
		mask |= 1 << (rang - 1)
	return mask


## LE DECK DE CAMPAGNE du niveau quand les objectifs de rangs `ranks_done`
## (1 = le plus facile) sont reussis. FONCTION UNIQUE : la partie, le briefing,
## la fiche et le livre de sorts la lisent tous (via SaveData.campaign_deck).
## Une entree = un exemplaire, dans l ordre nouvelle, 2e, 3e commune, puis rare,
## epique, legendaire.
##
## REPLI (contenu d avant la vague 10) : sans deck de base complet, le deck est
## `exploration_deck`, passifs exclus, quels que soient les objectifs reussis.
## Les recompenses de ces niveaux restent alors au pool de montee de niveau
## (RunState.levelup_pool), comme avant.
func campaign_deck(ranks_done: Array) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	if not has_base_commons():
		for c in exploration_deck:
			if c != null and not c.is_passive:
				out.append(c)
		return out
	var ligne: Array = CAMPAIGN_DECK_TABLE.get(campaign_deck_mask(ranks_done),
		CAMPAIGN_DECK_TABLE[0])
	var cartes: Array[SpellCard] = [base_commons[0], base_commons[1], base_commons[2],
		objective_reward(0), objective_reward(1), objective_reward(2)]
	for i in cartes.size():
		var n: int = int(ligne[i]) if i < ligne.size() else 0
		if n <= 0 or cartes[i] == null:
			continue
		for _k in n:
			out.append(cartes[i])
	return out


## Les cartes du deck de campagne SANS aucun objectif : les communes de base, ou
## le deck d exploration en repli. C est la part du deck que le CONTENU seul
## garantit (SaveData.cards_owned_by_decks, regle du livre de sorts).
func campaign_base_cards() -> Array[SpellCard]:
	return campaign_deck([])


## Ce qui est FAUX dans le contenu de la vague 10 (deck de base, passifs
## debloques, annexe). Lu par progression_errors(), donc par l AUDIT : une
## erreur de structure ne se corrige pas en ecrivant la suite du contenu.
func structure_errors() -> Array[String]:
	var out: Array[String] = []
	if not base_commons.is_empty():
		if base_commons.size() != BASE_COMMONS_COUNT:
			out.append("%d communes de base, %d attendues"
				% [base_commons.size(), BASE_COMMONS_COUNT])
		var vues: Dictionary = {}
		for c in base_commons:
			if c == null:
				out.append("commune de base nulle")
				continue
			if c.is_passive or c.rarity != GameEnums.Rarity.COMMON:
				out.append("%s n est pas une commune : elle ne peut pas etre au deck de base" % c.id)
			if vues.has(c.id):
				out.append("%s listee deux fois au deck de base" % c.id)
			vues[c.id] = true
		if has_base_commons():
			for mask: int in CAMPAIGN_DECK_TABLE:
				var ids: Array = []
				for c2: SpellCard in campaign_deck(_ranks_of_mask(mask)):
					ids.append(String(c2.id))
				var msg: String = DeckRules.validation_message(ids)
				if msg != "":
					out.append("deck de campagne (objectifs %s) invalide : %s"
						% [str(_ranks_of_mask(mask)), msg])
	if passive_unlocks.size() > MAX_PASSIVE_UNLOCKS:
		out.append("%d passifs debloques, %d au plus"
			% [passive_unlocks.size(), MAX_PASSIVE_UNLOCKS])
	for p in passive_unlocks:
		if p == null:
			out.append("passif debloque nul")
		elif not p.is_passive:
			out.append("%s debloque a la victoire n est pas un passif" % p.id)
		elif not allows_passives():
			out.append("%s : passif debloque, or l acte %d n en admet aucun" % [p.id, act])
	if not side_quest and (side_quest_after != &"" or side_quest_character != ""):
		out.append("condition d ouverture d annexe sur un niveau de campagne")
	if side_quest and act <= 0:
		out.append("quete annexe sans acte de rattachement")
	if side_quest_after != &"":
		var avant: LevelDef = ContentDB.levels.get(side_quest_after)
		if avant == null:
			out.append("annexe ouverte apres '%s', qui n existe pas" % side_quest_after)
		elif avant.side_quest:
			out.append("annexe ouverte apres %s, une autre annexe" % side_quest_after)
	return out


## Les rangs (1, 2, 3) d un masque de CAMPAIGN_DECK_TABLE.
static func _ranks_of_mask(mask: int) -> Array:
	var out: Array = []
	for i in REWARD_RARITY_BY_RANK.size():
		if mask & (1 << i):
			out.append(i + 1)
	return out

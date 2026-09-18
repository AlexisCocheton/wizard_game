extends TestCase
## Pouvoirs passifs : des cartes qu on joue UNE fois et dont l effet vaut pour
## tout le combat.
##
## Demande du testeur : "3 passifs en debut de jeu, on peut en gagner en montant
## de niveau ; au debut les passifs sont dans le deck en plus des 15 cartes et il
## faut les jouer, avec un temps d incantation, et ils font un effet pour tout le
## combat. Il faut indiquer les passifs en cours par une petite icone."
##
## Exemples demandes : invoquer un allie au debut de chaque vague, reduire le temps
## de charge de 0,3 s, lancer deux sorts a la fois mais 50 % plus lents.

func get_suite_name() -> String:
	return "passives"


func run() -> void:
	_test_un_passif_joue_reste_actif()
	_test_le_passif_ne_retourne_pas_dans_le_deck()
	_test_reduction_du_temps_de_charge()
	_test_double_cast_ralentit_les_sorts()
	_test_les_passifs_repartent_a_zero_entre_les_parties()


func _passive(id: String, key: String, magnitude: float = 0.0) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.base_cast_time = 1.0
	c.is_passive = true
	c.targeting = GameEnums.Targeting.NONE
	var sp := EffectSpec.new()
	sp.key = StringName(key)
	sp.magnitude = magnitude
	c.effects = [sp]
	return c


## Un passif joue reste actif : il est consultable en pause.
func _test_un_passif_joue_reste_actif() -> void:
	RunState.reset()
	var p := _passive("t_haste", "passive_cast_haste", 0.3)
	RunState.activate_passive(p)
	eq(RunState.active_passives.size(), 1, "le passif est enregistre")
	eq(RunState.active_passives[0].id, p.id, "c est bien celui qu on a joue")


## Un passif ne revient JAMAIS en main : son effet est deja acquis, le rejouer
## n aurait aucun sens et il encombrerait la pioche jusqu a la fin du combat.
func _test_le_passif_ne_retourne_pas_dans_le_deck() -> void:
	RunState.reset()
	var p := _passive("t_ally", "passive_wave_ally", 1.0)
	RunState.hand.append(p)
	var avant_defausse: int = RunState.discard.size()
	ok(RunState.play_card(p), "le passif se joue")
	eq(RunState.discard.size(), avant_defausse, "il ne part pas a la defausse")
	not_ok(RunState.hand.has(p), "il quitte la main")


## Le passif de celerite retire un temps fixe a chaque incantation.
func _test_reduction_du_temps_de_charge() -> void:
	RunState.reset()
	var c := SpellCard.new()
	c.id = &"t_spell"
	c.base_cast_time = 2.0
	var sans: float = RunState.effective_cast_time(c)
	RunState.activate_passive(_passive("t_haste", "passive_cast_haste", 0.3))
	var avec: float = RunState.effective_cast_time(c)
	feq(avec, sans - 0.3, "le passif retire 0,3 s au temps de charge")

	# Il ne peut pas rendre un sort instantane : il resterait plus rien a lire.
	var court := SpellCard.new()
	court.id = &"t_court"
	court.base_cast_time = 0.2
	ok(RunState.effective_cast_time(court) >= 0.1, "un sort tres court reste lisible")


## Double cast : deux sorts a la fois, mais chacun 50 % plus lent.
func _test_double_cast_ralentit_les_sorts() -> void:
	RunState.reset()
	var c := SpellCard.new()
	c.id = &"t_spell"
	c.base_cast_time = 2.0
	var sans: float = RunState.effective_cast_time(c)
	RunState.activate_passive(_passive("t_double", "passive_double_cast", 1.0))
	eq(RunState.cast_slots(), 2, "deux sorts peuvent charger en meme temps")
	feq(RunState.effective_cast_time(c), sans * 1.5, "mais chacun prend 50 % de plus")


func _test_les_passifs_repartent_a_zero_entre_les_parties() -> void:
	RunState.reset()
	RunState.activate_passive(_passive("t_haste", "passive_cast_haste", 0.3))
	ok(RunState.active_passives.size() > 0, "un passif est actif")
	RunState.reset()
	eq(RunState.active_passives.size(), 0, "une nouvelle partie repart sans passif")
	eq(RunState.cast_slots(), 1, "et avec une seule place d incantation")

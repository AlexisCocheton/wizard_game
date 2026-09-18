extends TestCase
## Pre-cast : preparer le sort suivant pendant que le premier se charge.
##
## Demande du testeur : "pouvoir selectionner et cibler un deuxieme sort avant que
## le premier ait fini. Il se lancera la ou on a clique, avec son propre chargement.
## Si on en lance un troisieme avant la fin du premier, c est lui qui sera lance et
## pas le deuxieme." Autrement dit : UNE seule place en attente, remplacable.

func get_suite_name() -> String:
	return "precast"


func _card(id: String, cast_time: float) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.base_cast_time = cast_time
	c.targeting = GameEnums.Targeting.NONE
	var sp := EffectSpec.new()
	sp.key = &"damage_single"
	sp.magnitude = 1.0
	c.effects = [sp]
	return c


func run() -> void:
	_test_une_place_en_attente()
	_test_le_troisieme_remplace_le_deuxieme()
	_test_le_sort_en_attente_part_a_la_fin_du_premier()
	_test_annuler_vide_aussi_l_attente()


func _test_une_place_en_attente() -> void:
	var c := Caster.new()
	attach(c)
	var a := _card("a", 2.0)
	var b := _card("b", 1.0)

	ok(c.begin(a, CastContext.make(null, a)), "le premier sort demarre")
	ok(c.is_busy(), "le mage incante")
	ok(c.queue_next(b, CastContext.make(null, b)), "le second se met en attente")
	ok(c.has_queued(), "une carte attend son tour")
	eq(c.queued_card(), b, "c est bien la seconde carte")


func _test_le_troisieme_remplace_le_deuxieme() -> void:
	var c := Caster.new()
	attach(c)
	var a := _card("a", 2.0)
	var b := _card("b", 1.0)
	var d := _card("d", 1.0)

	c.begin(a, CastContext.make(null, a))
	c.queue_next(b, CastContext.make(null, b))
	c.queue_next(d, CastContext.make(null, d))
	eq(c.queued_card(), d, "le troisieme sort remplace le deuxieme en attente")


## Quand le premier se resout, celui en attente demarre AVEC SON PROPRE temps
## d incantation : ce n est pas un lancement instantane.
func _test_le_sort_en_attente_part_a_la_fin_du_premier() -> void:
	var c := Caster.new()
	attach(c)
	var a := _card("a", 1.0)
	var b := _card("b", 2.0)
	SpeedGauge.reset()

	c.begin(a, CastContext.make(null, a))
	c.queue_next(b, CastContext.make(null, b))
	for i in 70:
		c.tick(1.0 / 60.0)
	eq(c.current, b, "le sort en attente a pris le relais")
	not_ok(c.has_queued(), "la place d attente est liberee")
	ok(c.progress() < 0.9, "il a bien son propre temps de chargement")


func _test_annuler_vide_aussi_l_attente() -> void:
	var c := Caster.new()
	attach(c)
	var a := _card("a", 2.0)
	var b := _card("b", 1.0)
	c.begin(a, CastContext.make(null, a))
	c.queue_next(b, CastContext.make(null, b))
	c.cancel()
	not_ok(c.is_busy(), "plus rien en incantation")
	not_ok(c.has_queued(), "plus rien en attente : annuler annule tout")

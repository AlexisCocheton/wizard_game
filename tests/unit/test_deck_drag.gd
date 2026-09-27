extends TestCase
## Glisser-deposer de l ecran de deck (UI-006) et raison d un refus.
##
## Ce que ce test verrouille, et POURQUOI :
##  - collection -> deck ajoute UN exemplaire, deck -> collection en retire UN :
##    c est le geste demande, dans les deux sens.
##  - un depot HORS de la zone visee ne change rien : la carte revient. Un doigt
##    qui glisse de travers ne doit jamais modifier le deck.
##  - un ajout refuse ne change rien ET dit pourquoi, avec la chaine EXACTE de
##    `DeckRules.refusal_reason` : l ecran ne reformule pas une regle qu il ne
##    possede pas (elle vit dans DeckRules et changera sans lui).
##  - la raison se lit dans la zone de depot DES LE DEPART du glisser, avant de
##    lacher : sinon le retour de la carte ressemble a un bug.
##  - prendre une carte ne l arme pas pour le double toucher : le toucher qui
##    suivrait l ajouterait sans que le joueur ait lu sa fiche.
##  - le toucher simple garde son effet, refus compris.
##
## La geometrie (quel point de l ecran est « le deck ») est verifiee par le
## SMOKE, qui rejoue le geste au doigt sur un menu dispose. Ici on teste la
## regle via `drop_on(zone)` : en headless les conteneurs ne sont pas encore
## disposes au moment ou un test synchrone lit leurs rectangles.

func get_suite_name() -> String:
	return "deck_drag"


func run() -> void:
	_test_glisser_vers_le_deck_ajoute()
	_test_depot_hors_zone_ne_change_rien()
	_test_glisser_du_deck_retire()
	_test_depot_refuse_dit_pourquoi()
	_test_prendre_n_arme_pas()
	_test_le_toucher_refuse_dit_pourquoi()
	_test_la_fiche_affiche_la_raison()
	_test_defiler_ou_prendre()
	SaveData.reset_profile()
	ContentDB.discover_starters()


## Un panneau sur un profil neuf, avec `libres` places liberees dans le deck
## de base (qui fait pile DECK_SIZE depuis le chantier K).
func _panel(libres: int) -> DeckPanel:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	var p := DeckPanel.new()
	attach(p)
	p.refresh()
	var deck: Array = SaveData.massacre_deck()
	deck.resize(maxi(0, deck.size() - libres))
	SaveData.set_massacre_deck(deck)
	p.refresh()
	return p


## Une carte de la collection que la regle accepte (ou refuse) sur ce deck.
func _carte(accepte: bool) -> SpellCard:
	var ids: Array = SaveData.massacre_deck()
	var toutes: Array = ContentDB.cards.values()
	toutes.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return String(a.id) < String(b.id))
	for c: SpellCard in toutes:
		if c == null or c.is_passive or not SaveData.is_discovered(c.id):
			continue
		var raison: String = DeckRules.refusal_reason(ids, c, true)
		if (raison == "") == accepte:
			return c
	return null


func _test_glisser_vers_le_deck_ajoute() -> void:
	var p: DeckPanel = _panel(2)
	var c: SpellCard = _carte(true)
	ok(c != null, "une carte decouverte est ajoutable sur un deck a 13")
	if c == null:
		detach(p)
		return
	var avant: int = SaveData.massacre_deck().size()
	var exemplaires: int = DeckRules.count_of(SaveData.massacre_deck(), c.id)
	p.begin_drag(c, false, Vector2.ZERO)
	ok(p.is_dragging(), "la carte est prise")
	ok(p.drop_hint_visible(), "la zone de depot s affiche pendant le glisser")
	ok(p.drop_on(DeckPanel.Zone.DECK), "deposee sur le deck, elle est acceptee")
	eq(SaveData.massacre_deck().size(), avant + 1, "le deck gagne UNE carte")
	eq(DeckRules.count_of(SaveData.massacre_deck(), c.id), exemplaires + 1,
		"et c est bien un exemplaire de la carte glissee")
	not_ok(p.is_dragging(), "le glisser est termine")
	not_ok(p.drop_hint_visible(), "la zone de depot disparait au relachement")
	eq(p.refusal_message(), "", "un ajout accepte n affiche aucun refus")
	detach(p)


func _test_depot_hors_zone_ne_change_rien() -> void:
	var p: DeckPanel = _panel(2)
	var c: SpellCard = _carte(true)
	if c == null:
		detach(p)
		return
	var avant: Array = SaveData.massacre_deck().duplicate()
	for zone in [DeckPanel.Zone.NONE, DeckPanel.Zone.COLLECTION]:
		p.begin_drag(c, false, Vector2.ZERO)
		not_ok(p.drop_on(zone), "une carte de collection lachee hors du deck est refusee (zone %d)" % zone)
		eq(SaveData.massacre_deck(), avant, "et le deck n a pas bouge (zone %d)" % zone)
		not_ok(p.is_dragging(), "la carte est revenue (zone %d)" % zone)
	eq(p.refusal_message(), "",
		"manquer la zone n est pas un refus de regle : aucun bandeau")
	detach(p)


func _test_glisser_du_deck_retire() -> void:
	var p: DeckPanel = _panel(0)
	var deck: Array = SaveData.massacre_deck()
	ok(not deck.is_empty(), "le deck de base n est pas vide")
	if deck.is_empty():
		detach(p)
		return
	var c: SpellCard = ContentDB.cards.get(StringName(deck[0]))
	var n: int = DeckRules.count_of(deck, c.id)
	# Lachee sur le deck lui-meme : rien ne change.
	p.begin_drag(c, true, Vector2.ZERO)
	not_ok(p.drop_on(DeckPanel.Zone.DECK), "une carte du deck relachee sur le deck ne fait rien")
	eq(DeckRules.count_of(SaveData.massacre_deck(), c.id), n, "aucun exemplaire retire")
	# Lachee sur la collection : un exemplaire de moins, pas tous.
	p.begin_drag(c, true, Vector2.ZERO)
	ok(p.drop_hint_visible(), "la collection s affiche comme zone de depot")
	ok(p.drop_on(DeckPanel.Zone.COLLECTION), "deposee sur la collection, elle quitte le deck")
	eq(DeckRules.count_of(SaveData.massacre_deck(), c.id), n - 1,
		"UN exemplaire retire, pas toute la pile")
	detach(p)


func _test_depot_refuse_dit_pourquoi() -> void:
	var p: DeckPanel = _panel(0)
	var c: SpellCard = _carte(false)
	ok(c != null, "sur un deck plein, au moins une carte est refusee")
	if c == null:
		detach(p)
		return
	var avant: Array = SaveData.massacre_deck().duplicate()
	var attendu: String = DeckRules.refusal_reason(avant, c, SaveData.is_discovered(c.id))
	ok(attendu != "", "la regle donne une raison")
	p.begin_drag(c, false, Vector2.ZERO)
	eq(p.drop_hint_text(), attendu,
		"la zone de depot annonce le refus AVANT qu on lache")
	not_ok(p.drop_on(DeckPanel.Zone.DECK), "le depot est refuse")
	eq(SaveData.massacre_deck(), avant, "le deck n a pas change")
	not_ok(p.is_dragging(), "la carte est revenue")
	eq(p.refusal_message(), attendu,
		"le bandeau affiche la chaine EXACTE de DeckRules.refusal_reason")
	# Retirer une carte leve le refus : le bandeau ne doit pas contredire le deck.
	var premiere: SpellCard = ContentDB.cards.get(StringName(avant[0]))
	p._on_remove(premiere)
	eq(p.refusal_message(), "", "un retrait efface le refus affiche")
	detach(p)


func _test_prendre_n_arme_pas() -> void:
	var p: DeckPanel = _panel(2)
	var c: SpellCard = _carte(true)
	if c == null:
		detach(p)
		return
	p._on_collection_tap(c)
	eq(p.armed_card(), c.id, "le toucher arme la carte (double toucher inchange)")
	p.begin_drag(c, false, Vector2.ZERO)
	eq(p.armed_card(), &"", "prendre la carte la desarme")
	p.cancel_drag()
	var n: int = SaveData.massacre_deck().size()
	p._on_collection_tap(c)
	eq(SaveData.massacre_deck().size(), n,
		"apres un glisser, le toucher suivant montre la fiche, il n ajoute pas")
	detach(p)


func _test_le_toucher_refuse_dit_pourquoi() -> void:
	var p: DeckPanel = _panel(0)
	var c: SpellCard = _carte(false)
	if c == null:
		detach(p)
		return
	var avant: Array = SaveData.massacre_deck().duplicate()
	var attendu: String = DeckRules.refusal_reason(avant, c, SaveData.is_discovered(c.id))
	p._on_collection_tap(c)
	p._on_collection_tap(c)
	eq(SaveData.massacre_deck(), avant, "le double toucher refuse ne change pas le deck")
	eq(p.refusal_message(), attendu, "et le bandeau dit pourquoi, mot pour mot")
	detach(p)


## La fiche d une carte refusee : son bouton AJOUTER est grise, et la raison
## ecrite dessous est celle de DeckRules.
func _test_la_fiche_affiche_la_raison() -> void:
	var p: DeckPanel = _panel(0)
	var c: SpellCard = _carte(false)
	if c == null:
		detach(p)
		return
	var attendu: String = p.refusal_for(c)
	p._on_collection_tap(c)
	var trouve: bool = false
	for n in p.find_children("*", "Label", true, false):
		if (n as Label).text == attendu and (n as Label).is_visible_in_tree():
			trouve = true
	ok(trouve, "la fiche ecrit la raison du refus : '%s'" % attendu)
	detach(p)


## DEFILER OU PRENDRE : la regle qui departage un doigt pose sur une vignette.
##
## Le defaut corrige : sur un deck qui deborde de sa zone, un pouce qui voulait
## faire defiler soulevait la carte (le glisser-deposer la prenait des le seuil,
## dans toutes les directions). Le geste est rejoue au doigt dans le SMOKE ; ici
## on verrouille la regle elle-meme, cas par cas, sans nombre en dur : tout est
## exprime en multiples du seuil.
func _test_defiler_ou_prendre() -> void:
	var s: float = DeckPanel.DRAG_START_PX
	var haut := Vector2(0.0, -s * 2.0)
	var bas := Vector2(0.0, s * 2.0)
	var cote := Vector2(s * 2.0, 0.0)
	var biais_vertical := Vector2(s * 0.8, s * 1.6)

	# Sous le seuil, rien n est decide : le relachement reste un toucher.
	eq(DeckPanel.gesture_for(true, true, Vector2(0.0, s * 0.5)), DeckPanel.Geste.AUCUN,
		"sous le seuil, un doigt qui derive n a encore rien decide")
	eq(DeckPanel.gesture_for(false, false, Vector2(s * 0.5, 0.0)), DeckPanel.Geste.AUCUN,
		"sous le seuil, meme en collection")

	# Zone du deck qui deborde : la verticale defile, dans les deux sens.
	eq(DeckPanel.gesture_for(true, true, haut), DeckPanel.Geste.DEFILER,
		"deck qui deborde, doigt vers le haut : la zone defile")
	eq(DeckPanel.gesture_for(true, true, bas), DeckPanel.Geste.DEFILER,
		"deck qui deborde, doigt vers le bas : la zone defile")
	eq(DeckPanel.gesture_for(true, true, biais_vertical), DeckPanel.Geste.DEFILER,
		"deck qui deborde, surtout vertical : la zone defile")
	# ... et le cote prend la carte : retirer par glisser reste possible.
	eq(DeckPanel.gesture_for(true, true, cote), DeckPanel.Geste.PRENDRE,
		"deck qui deborde, doigt de cote : la carte est prise")

	# Deck CONFORME (ne deborde pas) : UI-006 a l identique, tout prend la carte,
	# y compris vers le bas, vers la collection.
	for d in [haut, bas, cote, biais_vertical]:
		eq(DeckPanel.gesture_for(true, false, d), DeckPanel.Geste.PRENDRE,
			"deck conforme, geste %s : la carte est prise comme avant" % d)
	# La collection ne defile jamais : c est d elle que partent les ajouts, dans
	# toutes les directions.
	for d2 in [haut, bas, cote, biais_vertical]:
		eq(DeckPanel.gesture_for(false, true, d2), DeckPanel.Geste.PRENDRE,
			"collection, geste %s : la carte est prise" % d2)

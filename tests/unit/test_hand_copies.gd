extends TestCase
## PETRIFICATION ET VOL PAR EXEMPLAIRE, pas par carte.
##
## Les copies d une meme carte partagent LA MEME ressource SpellCard. Le registre
## de RunState comparait les ressources : deux regards gelaient alors toutes les
## copies d une carte, soit quatre cartes figees sur une capture pour deux
## annoncees, et une carte gelee rendait injouables toutes ses jumelles.
##
## Chaque test pose donc une main AVEC DOUBLONS : sur une main de cartes toutes
## differentes, l ancien registre passait tous les controles.

func get_suite_name() -> String:
	return "hand_copies"


func run() -> void:
	_test_deux_regards_gelent_deux_exemplaires()
	_test_la_copie_libre_se_joue()
	_test_le_gel_suit_l_exemplaire_quand_la_main_bouge()
	_test_le_joueur_ne_lance_pas_la_copie_gelee_qu_il_touche()
	_test_plafond_sur_une_main_de_copies()
	_test_le_voleur_tient_un_exemplaire()
	_test_le_voleur_lance_l_exemplaire_tenu()
	_test_une_main_videe_ne_laisse_rien_de_gele()
	_test_le_hud_ne_grise_que_l_exemplaire_gele()
	RunState.reset()


func _card(id: String, cast: float = 1.0) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.base_cast_time = cast
	c.tags = [GameEnums.DamageTag.ARCANE]
	return c


## La main telle que les cartes y sont posees, sans passer par la pioche.
func _main(cartes: Array) -> void:
	RunState.reset()
	for c in cartes:
		RunState.hand.append(c)


func _gelees() -> int:
	var n: int = 0
	for i in RunState.hand.size():
		if RunState.is_slot_blocked(i):
			n += 1
	return n


## LE DEFAUT VU EN CAPTURE. Main [A, B, C, A, A] : deux regards doivent geler
## DEUX cartes. L ancien registre gelait A (les trois copies) puis C : quatre.
func _test_deux_regards_gelent_deux_exemplaires() -> void:
	var a := _card("a")
	_main([a, _card("b"), _card("c"), a, a])
	RunState.set_card_block_count(2)
	eq(_gelees(), 2, "deux regards : exactement deux cartes grisees, doublons compris")
	eq(RunState.blocked_count(), 2, "et le registre en compte deux")
	# Depuis la droite : les deux dernieres, qui sont deux copies de A.
	ok(RunState.is_slot_blocked(4) and RunState.is_slot_blocked(3),
		"les deux exemplaires les plus a droite sont geles, meme s ils sont jumeaux")
	not_ok(RunState.is_slot_blocked(0), "la premiere copie de A, elle, reste libre")
	not_ok(RunState.is_slot_blocked(2), "et C n est pas gele a la place")


## Une carte dont une copie reste libre se JOUE : c est la copie libre qui part.
func _test_la_copie_libre_se_joue() -> void:
	var a := _card("a")
	_main([a, _card("b"), a, a])
	RunState.set_card_block_count(2)
	not_ok(RunState.is_card_blocked(a), "une copie de A est libre : A n est pas bloquee")
	ok(RunState.play_card(a), "on peut lancer A")
	eq(RunState.hand.count(a), 2, "UNE copie est partie")
	eq(_gelees(), 2, "les deux copies gelees le sont toujours")
	ok(RunState.is_card_blocked(a), "il ne reste que des copies gelees : A est bloquee")
	not_ok(RunState.play_card(a), "et ne se lance plus")


## Jouer une carte a GAUCHE des gelees decale leurs positions. Le gel doit
## suivre l exemplaire, pas rester sur la position (sinon il glisserait sur la
## voisine), et une copie piochee ensuite doit arriver LIBRE.
func _test_le_gel_suit_l_exemplaire_quand_la_main_bouge() -> void:
	var a := _card("a")
	var b := _card("b")
	_main([b, _card("c"), a, a])
	RunState.set_card_block_count(1)
	ok(RunState.is_slot_blocked(3), "la derniere copie de A est gelee")
	ok(RunState.play_card(b), "B part, a gauche de la carte gelee")
	eq(RunState.hand[2], a, "(la copie gelee est passee en position 2)")
	ok(RunState.is_slot_blocked(2), "le gel l a suivie")
	not_ok(RunState.is_slot_blocked(1), "sa jumelle en position 1 reste libre")
	RunState.set_card_block_count(1)
	eq(_gelees(), 1, "le rafraichissement de l image suivante ne change rien")
	ok(RunState.is_slot_blocked(2), "c est toujours le MEME exemplaire")
	# Une nouvelle copie arrive a droite : elle n herite de rien.
	RunState.hand.append(a)
	RunState.set_card_block_count(1)
	not_ok(RunState.is_slot_blocked(3), "une copie piochee apres le gel arrive libre")
	eq(_gelees(), 1, "et le nombre de gelees ne bouge pas")


## Le joueur touche l exemplaire GELE : refus, meme si une copie libre existe.
## Lancer la copie libre a sa place ferait partir une carte qu il n a pas touchee.
func _test_le_joueur_ne_lance_pas_la_copie_gelee_qu_il_touche() -> void:
	var a := _card("a")
	_main([a, _card("b"), a])
	RunState.set_card_block_count(1)
	ok(RunState.is_slot_blocked(2), "(la copie de droite est gelee)")
	not_ok(RunState.play_card(a, 2), "toucher la copie gelee ne lance rien")
	eq(RunState.hand.size(), 3, "et rien ne quitte la main")
	ok(RunState.play_card(a, 0), "toucher la copie libre la lance")
	eq(RunState.hand.size(), 2, "une carte en moins")
	ok(RunState.is_slot_blocked(1), "la copie gelee l est toujours, en position 1")


## Six copies de la meme carte et une gorgone enorme : le plafond laisse une
## copie jouable. L ancien registre gelait « la carte » : zero jouable.
func _test_plafond_sur_une_main_de_copies() -> void:
	var a := _card("a")
	var cartes: Array = []
	for i in GameConfig.MAX_HAND_SIZE:
		cartes.append(a)
	_main(cartes)
	RunState.set_card_block_count(99)
	eq(_gelees(), RunState.hand.size() - RunState.MIN_PLAYABLE_CARDS,
		"toutes gelees sauf le plancher jouable")
	not_ok(RunState.is_card_blocked(a), "il reste une copie de A jouable")
	ok(RunState.play_card(a), "et elle se lance")


## Le voleur prend UN exemplaire : la jumelle reste jouable et se voit libre.
func _test_le_voleur_tient_un_exemplaire() -> void:
	var longue := _card("longue", 3.0)
	_main([longue, longue, _card("courte", 1.0)])
	var prise: SpellCard = RunState.steal_card()
	eq(prise, longue, "il vole la plus longue")
	ok(RunState.is_slot_stolen(0), "l exemplaire de gauche est vole")
	not_ok(RunState.is_slot_stolen(1), "sa jumelle ne l est pas")
	not_ok(RunState.is_slot_blocked(1), "et reste jouable a l ecran")
	not_ok(RunState.is_card_blocked(longue), "la carte, elle, reste jouable par sa copie")
	ok(RunState.play_card(longue), "on lance la copie libre")
	ok(RunState.is_slot_stolen(0), "l exemplaire vole est toujours tenu")
	ok(RunState.is_card_stolen(longue), "et le voleur le sait")


## Le voleur LANCE : c est l exemplaire tenu qui part, et une copie gelee par une
## gorgone a cote reste gelee a sa nouvelle place.
func _test_le_voleur_lance_l_exemplaire_tenu() -> void:
	var longue := _card("longue", 3.0)
	var b := _card("b", 1.0)
	_main([b, longue, longue])
	RunState.set_card_block_count(1)
	ok(RunState.is_slot_blocked(2), "(une gorgone gele la copie de droite)")
	var prise: SpellCard = RunState.steal_card()
	eq(prise, longue, "le voleur prend l autre copie")
	ok(RunState.is_slot_stolen(1), "(celle du milieu)")
	ok(RunState.spend_stolen_card(longue), "il la lance")
	eq(RunState.hand.size(), 2, "une carte a quitte la main")
	eq(RunState.hand[1], longue, "la copie gelee est restee")
	ok(RunState.is_slot_blocked(1), "et elle est toujours gelee, decalee d un cran")
	not_ok(RunState.is_slot_stolen(1), "mais plus volee")
	ok(RunState.discard.has(longue), "la copie lancee est a la defausse")


## Main defaussee d un coup : plus rien n est tenu, et une copie repiochee a la
## meme position n herite pas du gel de l ancienne.
func _test_une_main_videe_ne_laisse_rien_de_gele() -> void:
	var a := _card("a")
	_main([a, a, a])
	RunState.set_card_block_count(2)
	var prise: SpellCard = RunState.steal_card()
	ok(prise == null, "(plafond : le voleur ne peut rien prendre sur une main deja gelee)")
	RunState.discard_hand()
	RunState.hand.append(a)
	RunState.hand.append(a)
	RunState.hand.append(a)
	eq(_gelees(), 0, "la main repiochee arrive entierement libre")
	eq(RunState.blocked_count(), 0, "et le registre est vide")


## LE RENDU. Le HUD demande la teinte par position : sur deux copies d une meme
## carte dont une seule est gelee, une seule doit etre grisee.
func _test_le_hud_ne_grise_que_l_exemplaire_gele() -> void:
	var a := _card("a")
	_main([a, a])
	RunState.set_card_block_count(1)
	var hud: Node = load("res://scripts/ui/hud.gd").new()
	eq(hud._teinte_carte(a, 0, null), Color.WHITE, "la copie libre reste en couleur")
	var t: Color = hud._teinte_carte(a, 1, null)
	ok(t.r < 0.8 and t.g < 0.8, "la copie gelee est grisee")
	hud.free()

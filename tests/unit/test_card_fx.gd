extends TestCase
## LA FEUILLE D EFFET D UNE CARTE DOIT ARRIVER A L ECRAN.
##
## L AUDIT verifiait deja que chaque carte non passive porte une `fx_key` unique
## et connue de Fx. Il ne verifiait pas que quelqu un la JOUE : quatre cartes
## (Entrave temporelle, Rappel d ossements, Epuration, Lumiere purifiante)
## portaient une feuille que leur handler n a jamais regardee. Leurs effets
## passaient par `screen_tint`, `self_aura` ou `dispel_at`, qui choisissaient une
## feuille en dur. Le champ satisfaisait l audit et ne se voyait nulle part.
##
## D ou cette suite : elle relie la DONNEE (fx_key) au CHEMIN DE RENDU. Une carte
## dont le handler ignore sa feuille echoue ici, meme si l AUDIT reste vert.

func get_suite_name() -> String:
	return "card_fx"


## Feuilles extraites le 26/09 des packs du testeur et restees orphelines
## jusqu au chantier F2. Elles sont listees ici NOMMEMENT : c est la seule facon
## qu une feuille telechargee, importee, puis oubliee sur le disque redevienne un
## echec de test plutot qu un fichier mort que personne ne relit.
const FEUILLES_F2: Array[String] = [
	"timemagic", "lightpillar", "dark_soul", "dark_vanish", "dark_swirl",
]

## Les trois seuls effets a SORT de grande taille (192 px de case). Le testeur :
## « si tu veux faire des gros effet qui prend une grande partie de l ecran
## utilise plutot des animation qui on une grosse resolution ». Une feuille de
## 64 px etiree sur 1400 px de large donne la bouillie qu on lui reprochait.
const PLEIN_ECRAN_MIN_PX: int = 160


func run() -> void:
	_test_les_feuilles_f2_sont_declarees()
	_test_les_feuilles_f2_se_chargent()
	_test_les_feuilles_f2_sont_toutes_employees()
	_test_chaque_carte_voit_sa_feuille_arriver_a_l_ecran()
	_test_les_effets_plein_ecran_sont_en_haute_definition()


## Une feuille sur le disque mais absente des tables de Fx est invisible pour le
## jeu : `has_sheet` la refuse, donc aucune carte ne peut la porter.
func _test_les_feuilles_f2_sont_declarees() -> void:
	for nom in FEUILLES_F2:
		ok(Fx.has_sheet(nom), "la feuille '%s' est declaree dans Fx" % nom)


## Declaree avec un mauvais decoupage, la feuille rend un SpriteFrames vide ou nul :
## le sort se lance alors sans rien afficher.
func _test_les_feuilles_f2_se_chargent() -> void:
	for nom in FEUILLES_F2:
		var sf: SpriteFrames = Fx.frames_of(nom)
		ok(sf != null, "la feuille '%s' produit un SpriteFrames" % nom)
		if sf != null:
			ok(sf.get_frame_count("play") > 1,
				"la feuille '%s' a plus d une image" % nom)


## Le point du chantier : ces cinq feuilles etaient sur le disque et dans AUCUNE
## carte. Les declarer sans les distribuer ne ferait que deplacer le probleme.
func _test_les_feuilles_f2_sont_toutes_employees() -> void:
	var portees: Dictionary = {}
	for card: SpellCard in ContentDB.cards.values():
		if card.fx_key != &"":
			portees[String(card.fx_key)] = String(card.id)
	for nom in FEUILLES_F2:
		ok(portees.has(nom), "la feuille '%s' est portee par une carte" % nom)


## LE COEUR DE LA SUITE.
##
## Pour chaque carte non passive, on lance reellement ses effets sur un champ de
## bataille et on demande a Fx quelles feuilles ont ete demandees. Si la feuille
## propre de la carte n en fait pas partie, son `fx_key` est decoratif.
##
## Le mouchard est pose sur Fx lui-meme (`Fx.begin_trace()`), et non sur une copie
## du code de rendu : un test qui reimplementerait le choix de feuille ne
## prouverait que sa propre coherence.
func _test_chaque_carte_voit_sa_feuille_arriver_a_l_ecran() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.running = false
	var bf: Battlefield = g.battlefield
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	# Des monstres VIVANTS et a portee : plusieurs effets (dissipation, degats
	# cibles) ne dessinent rien quand ils ne touchent personne. Un champ vide
	# ferait echouer des cartes parfaitement branchees.
	for i in 6:
		bf.spawn_enemy(gnome, 200.0 + i * 120.0, 1.0,
			Vector2(200.0 + i * 120.0, 700.0))

	var ids: Array = ContentDB.cards.keys()
	ids.sort()
	for id in ids:
		var card: SpellCard = ContentDB.cards[id]
		if card.is_passive or card.fx_key == &"":
			continue
		var attendue: String = String(card.fx_key)
		Fx.begin_trace()
		var ctx := CastContext.make(bf, card)
		ctx.caster = g
		ctx.target_position = Vector2(540.0, 700.0)
		ctx.direction = Vector2(0.0, -1.0)
		ctx.target_enemy = bf.enemy_nearest_to(ctx.target_position)
		EffectRegistry.cast(card, ctx)
		var demandees: Array[String] = Fx.end_trace()
		ok(demandees.has(attendue),
			"la carte %s affiche sa feuille '%s' (feuilles demandees : %s)"
				% [card.id, attendue, demandees])

	detach(g)


## Les feuilles jouees a pleine largeur doivent avoir la resolution qui va avec.
func _test_les_effets_plein_ecran_sont_en_haute_definition() -> void:
	for nom in Fx.plein_ecran_sheets():
		var cote: int = Fx.cell_size(nom)
		ok(cote >= PLEIN_ECRAN_MIN_PX,
			"la feuille plein ecran '%s' fait %d px de case (minimum %d)"
				% [nom, cote, PLEIN_ECRAN_MIN_PX])

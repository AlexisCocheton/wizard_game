Scripts de preparation des assets (Python 3 + Pillow + numpy).

compose_ui.py       : recompose les planches 9-tranches Tiny Swords (assets/ui/<nom>9.png) et ecrit UiTheme.NINE
make_wardrobe.py    : garde-robe du profil (robes, apprentis et teintes, tours, portraits,
                      chapeaux dessines par hat_painter.py + leur ancrage image par image)
                      -> scripts/game/wardrobe_data.gd. Argument : chemin de raw_assets/.
measure_occupancy.py: mesure la part occupee de chaque feuille et ecrit AnimCatalog occupancy + Fx.OCC

A relancer apres tout ajout de feuille dans assets/. Puis : bash tools/run_tests.sh visual

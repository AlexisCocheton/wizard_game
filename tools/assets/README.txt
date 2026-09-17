Scripts de preparation des assets (Python 3 + Pillow + numpy).

compose_ui.py       : recompose les planches 9-tranches Tiny Swords (assets/ui/<nom>9.png) et ecrit UiTheme.NINE
measure_occupancy.py: mesure la part occupee de chaque feuille et ecrit AnimCatalog occupancy + Fx.OCC

A relancer apres tout ajout de feuille dans assets/. Puis : bash tools/run_tests.sh visual

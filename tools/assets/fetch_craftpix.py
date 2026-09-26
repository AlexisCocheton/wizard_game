# -*- coding: utf-8 -*-
"""Telecharge les packs craftpix dans `raw_assets/`, avec TA session.

POURQUOI CET OUTIL EXISTE
-------------------------
craftpix.net sert ses fichiers uniquement a un compte connecte. Rien ne
l interdit, mais l assistant n a pas de session — et il ne doit pas en creer
une ni manipuler tes identifiants. La solution est de separer les deux roles :

  - TOI, une seule fois : `python tools/assets/fetch_craftpix.py login`
    ouvre un Chrome sur un profil dedie au projet. Tu te connectes a la main,
    tu fermes la fenetre. Le cookie de session reste dans ce profil.

  - MOI, autant de fois que necessaire : `... fetch <url> [<url> ...]`
    rouvre le MEME profil, donc deja connecte, et enregistre les .zip.

Tes identifiants ne passent jamais par le script, ne sont jamais lus et ne sont
jamais ecrits nulle part. Seul un cookie de session vit dans le profil Chrome.

LE PROFIL EST HORS DU DEPOT
---------------------------
Il vit dans `.browser_profile/`, ignore par git (voir .gitignore). Un cookie de
session dans un depot pousse sur GitHub, c est exactement le genre de chose qui
fuit.

Usage :
    python tools/assets/fetch_craftpix.py login
    python tools/assets/fetch_craftpix.py fetch https://craftpix.net/freebies/...
    python tools/assets/fetch_craftpix.py status
"""
import os
import sys
import time
import glob

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROFIL = os.path.join(RACINE, ".browser_profile")
SORTIE = os.path.join(RACINE, "raw_assets")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


def _driver(headless: bool):
    """Chrome sur le profil du projet. `headless` seulement pour telecharger :
    la connexion demande une vraie fenetre."""
    from selenium import webdriver
    opts = webdriver.ChromeOptions()
    opts.binary_location = CHROME
    opts.add_argument("--user-data-dir=" + PROFIL)
    opts.add_argument("--profile-directory=Default")
    # Sans cela, Chrome annonce qu il est pilote et certains sites changent de
    # comportement ; on ne cherche pas a tromper, seulement a se comporter en
    # navigateur ordinaire.
    opts.add_experimental_option("excludeSwitches", ["enable-automation"])
    opts.add_experimental_option("useAutomationExtension", False)
    if headless:
        opts.add_argument("--headless=new")
        opts.add_argument("--window-size=1400,1000")
    os.makedirs(SORTIE, exist_ok=True)
    opts.add_experimental_option("prefs", {
        "download.default_directory": SORTIE,
        "download.prompt_for_download": False,
        "profile.default_content_setting_values.automatic_downloads": 1,
    })
    d = webdriver.Chrome(options=opts)
    if headless:
        # En headless, Chrome refuse les telechargements sauf autorisation
        # explicite par le protocole de debogage.
        d.execute_cdp_cmd("Page.setDownloadBehavior",
                          {"behavior": "allow", "downloadPath": SORTIE})
    return d


def login() -> int:
    print("Une fenetre Chrome s ouvre sur craftpix.")
    print("Connecte-toi, puis FERME la fenetre. La session restera dans")
    print("  %s" % PROFIL)
    d = _driver(headless=False)
    d.get("https://craftpix.net/authorization/")
    print("\nEn attente... (le script se termine quand tu fermes Chrome)")
    try:
        while True:
            time.sleep(2)
            _ = d.title  # leve une exception des que la fenetre est fermee
    except Exception:
        pass
    print("Fenetre fermee. Session enregistree.")
    return 0


def _connecte(d) -> bool:
    """Vrai si le profil porte une session craftpix ouverte."""
    d.get("https://craftpix.net/")
    time.sleep(2)
    src = d.page_source.lower()
    # "my downloads" / "logout" n apparaissent que connecte ; "sign in" que
    # deconnecte. On teste les deux sens, un seul indice se trompe trop souvent.
    return ("logout" in src or "my downloads" in src) and "sign in to your account" not in src


def fetch(urls) -> int:
    avant = set(glob.glob(os.path.join(SORTIE, "*")))
    d = _driver(headless=True)
    try:
        if not _connecte(d):
            print("PAS CONNECTE. Lance d abord :")
            print("    python tools/assets/fetch_craftpix.py login")
            return 2
        print("Session craftpix active.\n")
        for u in urls:
            print("--- %s" % u)
            d.get(u)
            time.sleep(3)
            # Le bouton de telechargement pointe sur /download/<id>/
            liens = []
            for a in d.find_elements("tag name", "a"):
                try:
                    h = a.get_attribute("href") or ""
                except Exception:
                    continue
                if "/download/" in h and h.rstrip("/").split("/")[-1].isdigit():
                    liens.append(h)
            if not liens:
                print("    aucun lien de telechargement trouve")
                continue
            print("    -> %s" % liens[0])
            d.get(liens[0])
            # Laisser le fichier arriver : on attend qu aucun .crdownload ne
            # traine, plutot qu une duree fixe qui serait soit trop courte soit
            # du temps perdu.
            for _ in range(60):
                time.sleep(2)
                if not glob.glob(os.path.join(SORTIE, "*.crdownload")):
                    break
    finally:
        d.quit()
    apres = set(glob.glob(os.path.join(SORTIE, "*")))
    neufs = sorted(apres - avant)
    print("\n%d fichier(s) recupere(s) :" % len(neufs))
    for f in neufs:
        print("   %s  (%.1f Mo)" % (os.path.basename(f),
                                    os.path.getsize(f) / 1048576.0))
    return 0 if neufs else 1


def status() -> int:
    if not os.path.isdir(PROFIL):
        print("Aucun profil : lance `login` d abord.")
        return 1
    d = _driver(headless=True)
    try:
        ok = _connecte(d)
    finally:
        d.quit()
    print("Session craftpix : %s" % ("ACTIVE" if ok else "absente ou expiree"))
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "login":
        sys.exit(login())
    if cmd == "status":
        sys.exit(status())
    if cmd == "fetch":
        if len(sys.argv) < 3:
            print("fetch demande au moins une URL")
            sys.exit(1)
        sys.exit(fetch(sys.argv[2:]))
    print("commande inconnue : %s" % cmd)
    sys.exit(1)

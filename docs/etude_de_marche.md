# Étude de marché — *Wizard Story: Battle of the Time*

**Date :** 16 septembre 2026
**Statut du projet :** pré-production / early dev (architecture posée, contenu quasi vide)
**Cible étudiée :** sortie Google Play (Android), portrait mobile
**Nature du document :** théorique. Aucune implication sur le développement en cours.

---

## 1. Résumé exécutif

*Wizard Story* est un **roguelike defender / deck-builder temps réel** en portrait one-hand, dont la mécanique signature est un **multiplicateur de vitesse (x1 → x1.5 → x2 → x4)** qui remplit simultanément trois rôles : accélérateur du monde, multiplicateur d'XP, et **bouclier devant les PV**. Cette triple fonction crée une tension risque/récompense permanente et *lisible sans tutoriel* — un atout réel sur mobile.

**Verdict marché en une phrase :** le créneau est porteur et en croissance (+10 % CAGR sur le roguelike, +80 % YoY sur Steam en 2025), mais il est **saturé côté offre et étranglé côté découvrabilité**. Le projet est viable comme **produit de niche rentable**, pas comme hit de masse.

| Axe | Évaluation |
|---|---|
| Attractivité du marché | ⭐⭐⭐⭐ Forte croissance, appétit prouvé |
| Intensité concurrentielle | ⭐⭐ Très élevée, leaders installés |
| Différenciation du concept | ⭐⭐⭐⭐ La jauge-bouclier est un vrai hook |
| Barrière à l'entrée (UA) | ⭐ Prohibitive en achat média |
| Adéquation produit/plateforme | ⭐⭐⭐⭐⭐ Portrait, sessions courtes, une main |

---

## 2. Taille et dynamique du marché

### 2.1 Le marché adressable

| Segment | Valeur | Source |
|---|---|---|
| Marché roguelike global | **3,91 Md$ en 2026** → 8,7 Md$ en 2033 (CAGR ~10 %) | Verified Market Reports |
| Prévision alternative | 9,6 Md$ en 2034 (CAGR 10,8 %) | Market Intelo |
| Croissance Asie-Pacifique | **13,4 % CAGR** (segment le plus dynamique) | Market Intelo |
| Revenus Google Play 2026 | ~47 Md$, dont **65 % issus des jeux** (~30,5 Md$) | Business of Apps |
| Roguelike sur Steam 2025 | ~400 M$, **+80 % YoY**, 2e année consécutive d'explosion | note.com / analyse marché |

**Lecture :** le genre n'est pas une mode passagère — deux années consécutives de croissance à deux chiffres sur PC, et une expansion mobile portée par l'Asie. Le marché *existe* et *paie*.

### 2.2 Le marché réellement accessible (SAM/SOM)

Il faut être honnête sur l'entonnoir :

```
Marché roguelike global ................... 3,91 Md$
  └─ part mobile (est. 35-40%) ............ ~1,4 Md$
      └─ sous-genre deckbuilder/defender ... ~150-250 M$
          └─ hors top-10 titres établis .... ~30-50 M$
              └─ part atteignable en solo ... 20-200 K$/an
```

**Conclusion réaliste :** l'objectif crédible pour un premier titre solo/petite équipe sans budget UA est de l'ordre de **10 000 à 100 000 $ de revenus cumulés sur 2-3 ans**, pas d'un million. Tout scénario au-delà suppose soit un coup de chance viral, soit un featuring Google, soit un éditeur.

---

## 3. Tendance de fond : le retour du premium sur mobile

C'est **la tendance la plus importante de ce document** pour ton positionnement.

- Les sorties **premium** sur mobile ont bondi de **+77 % en 2025** (~750 titres).
- Le free-to-play garde **96 % des téléchargements** — mais le premium récupère une audience à forte valeur et faible churn.
- Causes identifiées : Apple Arcade / Netflix Games ont relevé les attentes de qualité, **fatigue des joueurs face aux monétisations manipulatoires**, et écosystèmes cross-plateformes.

**Deux archétypes de succès coexistent désormais :**

| Modèle | Exemple | Logique |
|---|---|---|
| **Premium pur** | Slay the Spire mobile (~10 $) | Achat unique, offline, zéro pub, zéro upsell. Référence absolue du genre. |
| **F2P respectueux** | Vampire Survivors mobile | Gratuit, monétisation *minimale et optionnelle*, jamais interruptive, revenus par vente de **contenu additionnel de qualité** |
| **F2P léger historique** | Magic Survival | Pubs rewarded pour revive + IAP ~2,49 $ pour retirer les pubs |

Vampire Survivors mobile a dépassé **3 M de téléchargements** avec ~60 K installs/jour en pic, en traitant explicitement les joueurs "comme des clients, pas comme des ressources".

**Implication directe :** ton jeu peut légitimement viser le modèle "F2P respectueux" ou le premium. Le modèle F2P agressif (énergie, gacha, pay-to-win) est à la fois hors-sujet pour un roguelike et de plus en plus rejeté.

---

## 4. Analyse concurrentielle

### 4.1 Cartographie

| Concurrent | Positionnement | Modèle | Performance | Menace |
|---|---|---|---|---|
| **Slay the Spire** | Deckbuilder roguelike au tour par tour, référence du genre | Premium ~10 $ | Benchmark absolu, base fidèle | 🔴 Élevée — occupe le mot-clé "deckbuilder" |
| **Vampire Survivors** | Survivor arena, temps réel, one-hand | F2P + DLC | 3 M+ DL mobile | 🟠 Moyenne — genre voisin, pas de cartes |
| **Magic Survival** | Survivor magique, précurseur du genre | F2P + pub/IAP 2,49 $ | Niche installée | 🟠 Moyenne — thème mage identique |
| **Rush Royale** | Tower defense + deckbuilding PvP | F2P agressif + Battle Pass | **280 M$+ cumulés**, plus gros TD mobile | 🟡 Faible — PvP compétitif, autre public |
| **Clash Royale** | Arena PvP temps réel | F2P monétisé fort | Mastodonte Supercell | 🟢 Nulle — hors segment |

**Données récentes Rush Royale** (référence de plafond du sous-genre TD) : ~200 K DL / 900 K$ sur App Store et ~300 K DL / 500 K$ sur Google Play par période récente. Noter le **ratio inversé** : Android génère plus de téléchargements mais moins de revenus qu'iOS — constante du marché à intégrer dans tes projections.

### 4.2 Positionnement de *Wizard Story* — la carte blanche

Aucun concurrent direct n'occupe l'intersection exacte :

```
                    TEMPS RÉEL
                        ▲
      Vampire Survivors │  ★ WIZARD STORY
      Magic Survival    │  (defender + deck + jauge-risque)
                        │
   PAS DE DECK ─────────┼───────── DECK
                        │
                        │  Slay the Spire
                        │  (tour par tour)
                        ▼
                  TOUR PAR TOUR
```

**Ce qui est réellement différenciant :**

1. **La jauge de vitesse comme bouclier** — mécanique originale. Monter la vitesse = plus d'XP *et* une protection, mais un monde plus rapide. Un coup encaissé au-dessus de x1 fait retomber le multiplicateur **sans coûter de PV**. C'est un système de risque élégant que je n'ai pas retrouvé dans les concurrents.
2. **Le temps d'incantation divisé par le multiplicateur** — l'accélération est à double tranchant de façon non-triviale : les ennemis descendent plus vite, mais tu lances aussi plus vite.
3. **Deux modes complémentaires** : Exploration (deck imposé = puzzle/design intentionnel) et Massacre (deck libre = expression du joueur). Couvre deux profils de joueurs avec le même contenu.
4. **Portrait one-hand strict** (1080×1920) — jouable dans les transports, une main. Sous-exploité dans le deckbuilder, dominé par le paysage/tablette.

**Ce qui est faible :**

- Thème "mage / fantasy" **extrêmement saturé** sur le Play Store — mauvais pour l'ASO.
- Le nom "Wizard Story" est générique et quasi-impossible à référencer. ⚠️ **À changer avant soumission.**
- Aucun contenu produit à ce jour (0 carte, 0 ennemi, 0 niveau dans `resources/`) : tout le risque d'exécution est devant.

---

## 5. Le vrai obstacle : la découvrabilité

C'est **le facteur qui décide du sort du projet**, bien plus que la qualité du jeu.

### 5.1 Coûts d'acquisition 2026

| Métrique | Valeur |
|---|---|
| CPI moyen Android | **2,97 $** |
| CPI moyen iOS | 4,22 $ |
| Fourchette Android par genre | 0,14 $ → 4,50 $ |
| Coût de 50 000 installs iOS | **~211 000 $** avant production créative |

> « C'est le chiffre qui tue la plupart des projets autofinancés. »

**Traduction pour ton projet :** l'achat média est **hors de portée**. Budgéter 0 € d'UA payante et construire toute la stratégie sur l'organique.

Le benchmark industrie recommande 25-50 % du budget total en marketing. Si ton budget de dev est ton temps, le budget marketing doit être **du temps aussi**, pas de l'argent.

### 5.2 Ce qui reste accessible

- **Google Play I/O 2026** pousse vers la découverte active : intention de recherche, recommandations IA, **Play Shorts** (vidéos courtes), **custom listings**. Un dev solo peut désormais tenir une présence multi-canal qui demandait une équipe marketing. À exploiter à fond — c'est gratuit.
- ⚠️ Limites connues : les listings générés par Gemini échouent parfois, et l'articulation entre formats vidéo reste confuse.
- **Playable ads** : -20 à -30 % de CPI vs vidéo standard (si un jour tu payes).
- Leviers organiques éprouvés : audience social pré-lancement, contenu gameplay early, **Discord communautaire**, micro-influenceurs.
- **Règle des 12 testeurs** Google Play (compte perso) + **25 $** de frais développeur unique : contrainte administrative à anticiper ~3 semaines avant la date de sortie visée.

### 5.3 Le canal le plus sous-estimé pour ce projet

Le multiplicateur x4 produit des **moments spectaculaires courts** (écran saturé de monstres, incantations éclair, bouclier qui saute). C'est du **matériau TikTok/Shorts natif**. Un roguelike au tour par tour n'a pas cet avantage. C'est ton meilleur actif marketing et il est gratuit — à condition d'y penser **pendant** le design (feedback visuel lisible en 6 secondes).

---

## 6. Analyse SWOT

| **Forces** | **Faiblesses** |
|---|---|
| Mécanique signature originale et lisible | Thème fantasy/mage ultra-saturé (ASO) |
| Portrait one-hand, sessions courtes | Nom générique et non-référençable |
| Architecture technique saine (autoloads, save atomique, tests headless) | Contenu inexistant à ce jour — 100 % du risque d'exécution devant |
| Deux modes = rejouabilité sans doubler le contenu | Pas d'audience, pas de communauté |
| Godot 4.4 GL Compatibility = large parc Android couvert | Ressources solo : contenu + art + son + marketing |
| Gameplay très "clippable" (TikTok/Shorts) | Godot = moins d'outils SDK ads/analytics prêts à l'emploi qu'Unity |

| **Opportunités** | **Menaces** |
|---|---|
| Croissance roguelike +10 % CAGR, +80 % YoY sur Steam | CPI Android 2,97 $ = UA payante inaccessible |
| Retour du premium (+77 % de sorties en 2025) | Play Store saturé de clones fantasy |
| Fatigue joueurs envers la monétisation agressive | Un concurrent peut copier la jauge-bouclier en 3 mois |
| Nouveaux outils de découverte Google Play 2026 (gratuits) | Dépendance totale à l'algorithme Google |
| Asie-Pacifique +13,4 % CAGR (localisation) | Fenêtre de marché qui se referme si le genre sature |
| Cross-plateforme : port Steam/Switch du même code | Android = plus de DL, moins de revenus qu'iOS |

---

## 7. Segments de joueurs cibles

### Cible primaire — « Le stratège de transport »
25-40 ans, joue 10-20 min par trajet, une main, debout. Connaît Slay the Spire mais le trouve trop long/pas adapté au format téléphone. **Cherche de la profondeur en sessions courtes.** Faible tolérance à la pub interruptive, prêt à payer 3-8 € pour un jeu propre.
→ **C'est ta cible payante.** Le design portrait + sessions courtes le sert nativement.

### Cible secondaire — « Le chasseur de build »
16-30 ans, joue au survivor/roguelite, cherche les synergies cassées et les runs délirants. Consomme et produit du contenu (Reddit, TikTok, Discord). Monétise peu directement mais **fait la découvrabilité**.
→ Le mode Massacre (deck libre) et les légendaires débloquées par objectifs sont faits pour lui.

### Cible tertiaire — « Le joueur TD occasionnel »
Vient de Rush Royale ou d'un TD classique. Attiré par le visuel et la défense de ligne. Volume important mais faible rétention si le jeu est trop exigeant.
→ Le mode Exploration à deck imposé est la bonne porte d'entrée pour lui.

---

## 8. Recommandations stratégiques

### Priorité 1 — Changer le nom avant toute chose
"Wizard Story" est invisible en recherche Play Store. Il faut un nom qui porte la **mécanique** (le temps, la vitesse, l'accélération), pas le thème. Le sous-titre actuel "Battle of the Time" est plus distinctif que le titre principal. C'est une décision **gratuite maintenant, coûteuse après lancement**.

### Priorité 2 — Trancher le modèle économique tôt
Le choix premium vs F2P conditionne le game design (voir document `monetisation.md`). Il ne doit pas être différé jusqu'à la fin du dev : une boucle F2P se conçoit *avec* le jeu, pas *après*.

### Priorité 3 — Construire l'audience pendant le dev, pas après
Le seul canal d'acquisition finançable est organique, et l'organique a besoin de temps de chauffe. Devlog + clips de gameplay dès qu'une run est jouable, même moche. L'attente "je publierai quand ce sera fini" est le plus sûr moyen de sortir devant 0 joueur.

### Priorité 4 — Soigner les 60 premières secondes
Le premier run doit démontrer la jauge-bouclier sans texte. Si le joueur ne comprend pas en une run que monter la vitesse est à la fois risqué et rentable, la différenciation est perdue et le jeu redevient un clone fantasy de plus.

### Priorité 5 — Prévoir le multi-plateforme dès l'architecture
Godot exporte vers Steam/Switch sans réécriture. Le marché PC roguelike (~400 M$, +80 % YoY) est **plus rémunérateur par joueur** et moins dépendant d'un algorithme de store. Garder la logique de jeu découplée du rendu et des entrées tactiles (ce que fait déjà `speed_gauge.gd` avec son tick headless) préserve cette option gratuitement.

---

## 9. Scénarios de résultat

| Scénario | Probabilité | Téléchargements 12 mois | Revenus 12 mois | Déclencheur |
|---|---|---|---|---|
| **Échec silencieux** | 50 % | < 2 000 | < 200 € | Aucune audience construite, pas de featuring |
| **Niche rentable** | 35 % | 10 000 - 50 000 | 2 000 - 15 000 € | Communauté Discord + quelques clips qui prennent |
| **Succès modéré** | 13 % | 100 000 - 500 000 | 20 000 - 150 000 € | Featuring Google Play ou vidéo virale |
| **Hit** | 2 % | 1 M+ | 200 000 € + | Effet Vampire Survivors, non planifiable |

**Ces chiffres sont des ordres de grandeur, pas des prévisions.** Ils supposent un jeu fini, poli, et une stratégie organique tenue sur 6 mois minimum. Le scénario « échec silencieux » est le plus probable **par défaut** — c'est le cas de base qu'il faut activement combattre, pas un risque résiduel.

---

## 10. Sources

- [Roguelike Game Market Size, Growth Analysis — Verified Market Reports](https://www.verifiedmarketreports.com/product/roguelike-game-market/)
- [Roguelike Games Market Research Report 2034 — Market Intelo](https://marketintelo.com/report/roguelike-games-market)
- [Mobile Games Revenue Data 2026 — Business of Apps](https://www.businessofapps.com/data/mobile-games-revenue/)
- [Premium mobile games are back, with releases up 77% in 2025 — daily.dev](https://daily.dev/posts/premium-mobile-games-are-back-with-releases-up-77-in-2025-mo3xb5ehx)
- [Vampire Survivors developer takes new approach to monetisation — PocketGamer.biz](https://www.pocketgamer.biz/vampire-survivors-developer-takes-new-approach-to-monetisation/)
- [Vampire Survivors tops 3 million downloads on mobile — Game World Observer](https://gameworldobserver.com/2023/01/17/vampire-survivors-mobile-3-million-downloads-appmagic)
- [Crappy Mobile Games Accidentally Led To The Best Version Of Vampire Survivors — Kotaku](https://kotaku.com/vampire-survivors-free-iphone-steam-mobile-smartphone-1849955308)
- [Rush Royale has surpassed the $280M revenue mark — GameDev Reports](https://gamedevreports.substack.com/p/rush-royale-has-surpassed-the-280m)
- [Mobile Game CPI Benchmarks 2026: iOS $4.22, Android $2.97 — Game Growth Advisor](https://gamegrowthadvisor.com/blog/2026-03-17-user-acquisition-cpi-benchmarks-2026/)
- [2026 Mobile Game UA Cost Benchmarks — FoxData](https://foxdata.com/en/blogs/2026-mobile-game-user-acquisition-cost-benchmarks-how-much-should-you-spend/)
- [What Google Play's I/O 2026 Updates Look Like From a Solo Indie Developer — DEV](https://dev.to/lumaplay/what-google-plays-io-2026-updates-look-like-from-a-solo-indie-puzzle-developer-51kp)
- [Google Play Developer Fee 2026: $25 + 12-Tester Rule — IconikAI](https://www.iconikai.com/blog/google-play-developer-account-fee-2026)
- [Game Survival Strategies 2026 Edition — note.com](https://note.com/sora2112/n/n9050a9743f59)

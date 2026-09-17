# Stratégie de monétisation — *Wizard Story: Battle of the Time*

**Date :** 16 septembre 2026
**Nature :** **document théorique.** Aucune de ces mécaniques ne doit être implémentée maintenant.
**Objet :** cadrer les options de rentabilisation pour un lancement Google Play, et identifier les rares décisions qui doivent être prises **tôt** parce qu'elles touchent le game design.

> ⚠️ **Règle directrice de ce document**
> La monétisation ne doit **jamais** entrer en conflit avec la mécanique signature du jeu — la jauge de vitesse comme bouclier et multiplicateur d'XP. Toute option qui permet d'acheter de la vitesse, de l'XP, des PV ou une relance gratuite corrompt la boucle risque/récompense qui fait exister le jeu. Cette contrainte élimine à elle seule 80 % des modèles F2P standards.

---

## 1. Les trois modèles viables

### Vue d'ensemble

| Modèle | Revenu/joueur | Volume DL | Complexité dev | Risque design | Verdict |
|---|---|---|---|---|---|
| **A. Premium pur** | Élevé (3-8 €) | Très faible | ⭐ Minimale | 🟢 Nul | ✅ **Recommandé** |
| **B. F2P respectueux** | Faible (0,10-0,50 €) | Élevé | ⭐⭐⭐ Moyenne | 🟠 Modéré | ✅ Alternative sérieuse |
| **C. Premium + DLC** | Élevé + récurrent | Faible | ⭐⭐ Faible | 🟢 Nul | ✅ Évolution de A |
| ~~D. F2P agressif~~ | Très élevé | Élevé | ⭐⭐⭐⭐⭐ | 🔴 Destructeur | ❌ **Écarté** |

---

## 2. Modèle A — Premium pur (recommandé)

### Principe
Achat unique. Pas de pub, pas d'IAP, jouable hors-ligne, tout le contenu inclus. C'est le modèle **Slay the Spire mobile**, benchmark absolu du genre.

### Prix conseillé

| Palier | Prix | Justification |
|---|---|---|
| Lancement | **3,99 €** | Prix d'impulsion, réduit la friction pour un studio inconnu |
| Après review positive | 5,99 € | Si la note dépasse 4,5 et que le contenu suit |
| Plafond réaliste | 7,99 € | Slay the Spire est à ~10 € avec une marque établie — ne pas s'y comparer |

**Pourquoi pas plus cher :** sans notoriété, le prix est un filtre brutal. Chaque euro au-dessus de 4 € divise la conversion. Mieux vaut 3 000 ventes à 3,99 € que 800 à 7,99 €.

### Calcul de revenu

```
Revenu net = Ventes × Prix × (1 − commission Google)

Commission Google Play : 15 % sur le premier million de $ annuel
                         (30 % au-delà — non pertinent ici)

Exemple scénario "niche rentable" (cf. étude de marché) :
  5 000 ventes × 3,99 € × 0,85 = ~16 950 € bruts
  − TVA, frais bancaires, impôts → ~10 000-12 000 € nets
```

### Avantages
- **Zéro impact sur le game design.** Le jeu reste le jeu. Aucun système à équilibrer autour de l'argent.
- Aucun SDK publicitaire à intégrer (gain de temps considérable en Godot, où les SDK ads sont moins matures qu'en Unity).
- Pas de RGPD/consentement pub, pas de tracking, pas de politique de confidentialité complexe.
- Aligné sur la tendance 2025-2026 : **+77 % de sorties premium**, fatigue des joueurs envers la monétisation agressive.
- Public à haute valeur, forte rétention, bonnes notes.

### Inconvénients
- **96 % des téléchargements mobile vont au F2P.** Le premium coupe le volume d'entrée de façon drastique.
- Pas de revenu récurrent : la courbe de revenus s'effondre après le pic de lancement.
- Impossible de monétiser les joueurs qui ne paieront jamais.
- Nécessite un jeu *fini et poli* dès le jour 1 — pas de droit à l'erreur, les remboursements et les 1★ arrivent vite.

### Variante recommandée : **démo gratuite séparée**
Publier deux apps : une démo gratuite (niveau 1 complet, mode Exploration seul) et l'app payante. Cela récupère une partie du volume F2P tout en gardant un design non corrompu. C'est le compromis le plus propre.

---

## 3. Modèle B — F2P respectueux

### Principe
Gratuit, monétisation **optionnelle, non-interruptive et sous contrôle du joueur**. C'est le modèle **Vampire Survivors mobile** : « ne jamais interrompre le jeu, toujours optionnel, toujours sous ton contrôle ». Et le modèle **Magic Survival** : pubs rewarded pour revive + IAP à 2,49 $ pour retirer les pubs.

### Sources de revenu

#### 3.1 Publicité rewarded (jamais interstitielle)

**Benchmarks 2026 :**

| Métrique | Valeur |
|---|---|
| eCPM rewarded Tier 1 (US/UK/JP) | **15-40 $** (certaines sources : 18-45 $) |
| eCPM rewarded Tier 2-3 | 3-10 $ |
| Moyenne globale | **10-22 $** |
| Taux de complétion (si la récompense a du sens) | **85-95 %** |
| Part du rewarded dans les revenus pub des top apps | **50-70 %** |

**Placements possibles — et leur compatibilité avec le design :**

| Placement | Compatible ? | Analyse |
|---|---|---|
| Doubler l'or/XP de fin de run | ✅ **Oui** | Post-run, n'affecte pas la run jouée. Le placement le plus sain. |
| Une 4e carte au choix de montée de niveau | ⚠️ **Prudence** | Interrompt la run, mais le jeu est déjà en pause à ce moment. Acceptable si strictement optionnel. |
| Relancer une run échouée (revive) | ❌ **Non** | **Détruit la mécanique.** La mort est la sanction du risque pris sur la jauge. Un revive gratuit annule tout l'enjeu du multiplicateur. |
| Démarrer à x2 gratuitement | ❌ **Non** | Vend l'avantage qui doit être *gagné*. Corruption directe du système signature. |
| Interstitiel entre deux niveaux | ❌ **Non** | Interruption forcée = 1★ garantis. Contraire au modèle "respectueux". |

**Revenu estimé :**
```
ARPDAU pub réaliste pour ce profil de jeu : 0,05 - 0,15 €
(benchmark hybrid-casual : 0,15-0,50 € — mais ce jeu est plus mid-core et
 moins agressif, donc bas de fourchette)

1 000 DAU × 0,08 € × 30 j = ~2 400 €/mois
```
⚠️ Atteindre 1 000 DAU stables est déjà le scénario « succès modéré » de l'étude de marché. Ne pas partir de ce chiffre comme d'un acquis.

#### 3.2 IAP « Remove Ads » / Supporter Pack — **2,99 €**
Le plus important des IAP. Convertit les joueurs les plus engagés, ceux qui refusent la pub par principe. Taux de conversion typique : 1-3 % des joueurs actifs. Doit inclure un bonus cosmétique symbolique pour ne pas ressembler à une rançon.

#### 3.3 Contenu additionnel payant — **1,99 à 4,99 €**
C'est le levier de Vampire Survivors : **vendre plus de contenu de qualité**, pas des raccourcis.
- Pack de nouvelles cartes légendaires + biome + boss (contenu horizontal, pas de puissance vendue)
- Nouveau personnage jouable avec un deck de départ et une identité mécanique distincte
- **Règle absolue : jamais de contenu qui rend plus fort dans le contenu existant.** Du contenu *à côté*, pas *au-dessus*.

#### 3.4 Cosmétiques — **0,99 à 2,99 €**
Skins de mage, dos de cartes, effets de sort. Revenu faible mais **coût de design nul en termes d'équilibrage**. À considérer seulement si les moyens artistiques suivent — un skin mal fait ne se vend pas.

### Split de revenus visé
Benchmark 2026 : les titres hybrid-casual tournent autour de **59 % IAP / 41 % pub**, beaucoup de casual sont à 50/50. Pour ce jeu, viser **60 % IAP / 40 % pub** — le public roguelike paie plus volontiers qu'il ne regarde des pubs.

### Inconvénients du modèle B
- Nécessite des SDK (AdMob, éventuellement médiation) : **intégration Godot non triviale**, plugins Android à maintenir.
- RGPD, consentement, politique de confidentialité, conformité Play.
- Exige une **analytique** pour piloter (rétention D1/D7, ARPDAU) — encore du dev.
- Risque permanent de glissement : chaque placement pub est une tentation d'en ajouter un de plus.
- **Il faut du volume.** Sans 1 000+ DAU, les revenus pub sont négligeables (quelques euros par mois).

---

## 4. Modèle C — Premium + extensions

Modèle A au lancement, puis vente de DLC de contenu 12-18 mois plus tard. C'est l'évolution naturelle si le jeu trouve son public.

```
Jour 1 :        Jeu de base 3,99 €
Mois 12-18 :    Extension 1 — nouveau biome + 15 cartes + boss ... 2,99 €
Mois 24-30 :    Extension 2 — nouveau personnage jouable ......... 3,99 €
```

**Avantage majeur :** relance la visibilité Play Store à chaque sortie (les mises à jour majeures sont un signal d'algorithme) et remonétise la base existante sans rien corrompre.

**Condition :** suppose que le jeu de base ait trouvé son public. Ne pas planifier d'extensions avant d'avoir les chiffres du lancement.

---

## 5. Modèle D — F2P agressif ❌ **écarté**

Documenté uniquement pour justifier son rejet.

Mécaniques typiques : énergie/vies limitées, gacha de cartes, monnaie premium, pay-to-win, battle pass, coffres à timer. C'est le modèle **Rush Royale** (280 M$+ cumulés) — et il fonctionne, à son échelle.

**Pourquoi c'est inapplicable ici :**

1. **Incompatibilité fondamentale avec le design.** Un roguelike repose sur l'équité de la run : le joueur perd parce qu'il a mal joué, pas parce qu'il n'a pas payé. Vendre de la puissance détruit le contrat implicite du genre.
2. **Conflit direct avec la jauge signature.** Le multiplicateur *est* le système de risque. Toute monnaie qui l'achète, le protège ou le restaure vide le jeu de sa substance.
3. **Coût de développement disproportionné.** Économie virtuelle, live-ops, équilibrage continu, serveur, analytics, saisons : c'est plusieurs personnes à temps plein, indéfiniment.
4. **Nécessite un budget UA.** Ce modèle ne fonctionne qu'avec de l'achat média pour alimenter le sommet de l'entonnoir. À 2,97 $ de CPI Android, c'est inaccessible.
5. **Rejet croissant du public.** La tendance 2025-2026 va explicitement dans l'autre sens.

**Conclusion : pas une option, quelle que soit l'ambition commerciale.**

---

## 6. Recommandation

### Chemin recommandé

```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1 — Lancement (Modèle A)                             │
│  Premium 3,99 € + démo gratuite séparée                     │
│  → Zéro dette technique de monétisation                     │
│  → Zéro compromis de design                                 │
│  → Permet de valider si le JEU est bon, sans variable       │
│    de confusion monétaire                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
        Mesurer : ventes, rétention, notes, retours joueurs
                            ↓
        ┌───────────────────┴───────────────────┐
        ↓                                       ↓
┌──────────────────────┐          ┌──────────────────────────┐
│ Le jeu plaît         │          │ Volume insuffisant       │
│ → PHASE 2 : Modèle C │          │ → Envisager bascule F2P  │
│   Extensions payantes│          │   (Modèle B) en v2.0     │
└──────────────────────┘          └──────────────────────────┘
```

### Pourquoi commencer en premium

1. **Ça ne coûte rien à développer.** Aucun SDK, aucun système économique, aucune analytique obligatoire. Tout le temps de dev reste sur le jeu.
2. **C'est réversible.** Passer de premium à F2P est courant et bien accepté. L'inverse est impossible.
3. **Ça isole la variable.** Si le jeu se vend mal en premium, on sait que c'est le jeu ou la visibilité — pas la monétisation. Information précieuse.
4. **La tendance marché y est favorable** (+77 % de sorties premium en 2025).

### Quand reconsidérer
Basculer vers le Modèle B si, 6 mois après le lancement : les ventes sont sous 500 unités, **mais** la démo gratuite affiche une bonne rétention. Ce signal précis — les gens aiment le jeu mais n'achètent pas — est le seul qui justifie la bascule.

---

## 7. Décisions à prendre MAINTENANT (impact design)

C'est la seule section de ce document qui touche le développement en cours. Aucune ne demande d'écrire du code de monétisation — seulement de **ne pas se fermer de portes**.

| # | Décision | Pourquoi maintenant | Coût si différé |
|---|---|---|---|
| 1 | **Renommer le jeu** | "Wizard Story" est invisible en recherche Play Store | Élevé — rebranding post-lancement = perte des liens, avis, notoriété |
| 2 | **Garder le contenu data-driven** (`.tres` dans `resources/`) | L'architecture actuelle le fait déjà. Permet d'ajouter un DLC sans toucher au code. | Élevé — refonte si le contenu se retrouve codé en dur |
| 3 | **Prévoir un flag `is_premium` dans `SaveData`** | Le schéma de sauvegarde est versionné avec migration (`_migrate_0_to_1`). Ajouter un champ plus tard est **déjà géré proprement**. ✅ Rien à faire. | Nul — l'architecture est bonne |
| 4 | **Ne jamais coder de "revive"** | Même gratuit en debug, un revive crée une habitude de design contraire à la boucle de risque | Moyen — retirer une feature aimée est douloureux |
| 5 | **Séparer contenu de base / contenu extension** dans l'organisation des `.tres` | Facilite un futur DLC sans restructuration | Faible — mais gratuit à faire dès maintenant |
| 6 | **Concevoir les runs comme "clippables"** | Le marketing organique est le seul finançable. Un moment x4 lisible en 6 s est un actif marketing gratuit. | Moyen — le game feel se rattrape mal après coup |

**À ne PAS faire maintenant :** intégrer AdMob, coder une boutique, créer une monnaie premium, ajouter des analytics tiers, concevoir un battle pass. Tout cela est prématuré et serait à jeter.

---

## 8. Projections financières

### Hypothèses communes
- Commission Google Play : 15 % (premier million de $ annuel)
- Pas de budget UA (acquisition 100 % organique)
- Frais fixes : 25 $ de compte développeur Google Play (unique)

### Scénario « niche rentable » (35 % de probabilité)

| Modèle | Volume 12 mois | Revenu brut | Revenu net (post-commission) |
|---|---|---|---|
| **A. Premium 3,99 €** | 3 000 ventes | 11 970 € | **~10 175 €** |
| **B. F2P** | 30 000 DL, ~600 DAU | pub ~1 400 € + IAP ~2 400 € | **~3 230 €** |

### Scénario « succès modéré » (13 % de probabilité)

| Modèle | Volume 12 mois | Revenu brut | Revenu net |
|---|---|---|---|
| **A. Premium 3,99 €** | 25 000 ventes | 99 750 € | **~84 790 €** |
| **B. F2P** | 300 000 DL, ~6 000 DAU | pub ~17 500 € + IAP ~26 000 € | **~37 000 €** |

**Observation clé :** à volume comparable, le **premium rapporte 2 à 3× plus net** pour ce profil de jeu — parce que le public roguelike a une forte propension à payer et une faible tolérance à la pub. Le F2P ne devient supérieur qu'avec un volume 10× supérieur, lequel suppose un budget UA inaccessible.

⚠️ **Ces projections sont des ordres de grandeur pour comparer les modèles entre eux, pas des prévisions de revenus.** Le scénario le plus probable (50 %) reste l'échec silencieux à moins de 200 € — la variable décisive est la découvrabilité, pas le modèle de monétisation.

---

## 9. Checklist Google Play (pour mémoire, le moment venu)

- [ ] Compte développeur Google Play — **25 $**, frais unique
- [ ] **Règle des 12 testeurs** : 12 testeurs sur 14 jours consécutifs en test fermé avant publication (comptes personnels). À anticiper **~3 semaines** avant la date de sortie visée.
- [ ] Politique de confidentialité (obligatoire, même en premium sans tracking)
- [ ] Déclaration Data Safety
- [ ] Classification de contenu (IARC)
- [ ] Assets : icône 512×512, feature graphic 1024×500, 2-8 captures portrait, vidéo promo
- [ ] **Custom store listings** (nouveauté 2026) — une variante par segment d'audience
- [ ] **Play Shorts** — vidéos courtes de gameplay, canal de découverte gratuit
- [ ] Localisation : FR/EN minimum. Le profil supporte déjà `settings.language` ✅
- [ ] AAB signé, `min_sdk` cohérent avec GL Compatibility

---

## 10. Sources

- [Ad Monetization in Mobile Games – Benchmark Report 2026 — Tenjin](https://tenjin.com/blog/ad-mon-gaming-2026/)
- [Hybrid Monetization in Mobile Games: Guide to Ads & IAP — CAS.ai](https://cas.ai/blog/hybrid-monetization-in-mobile-games-a-practical-guide/)
- [F2P Monetization Models 2026: IAP, Ads, Subscription or Hybrid — Game Growth Advisor](https://gamegrowthadvisor.com/blog/2026-04-02-f2p-monetization-models-comparison-2026/)
- [Hybrid Casual Games 2026: Design and Monetization — Game Growth Advisor](https://gamegrowthadvisor.com/blog/2026-04-16-hybrid-casual-game-design-strategy-2026/)
- [Rewarded Video Ads: How They Work & 2026 eCPMs — Coinis](https://coinis.com/glossary/rewarded-video)
- [Mobile Game Ads: 7 Ad Formats, eCPM Ranges & Monetization — AppFollow](https://appfollow.io/blog/mobile-game-ads-formats-monetization)
- [Vampire Survivors developer takes new approach to monetisation — PocketGamer.biz](https://www.pocketgamer.biz/vampire-survivors-developer-takes-new-approach-to-monetisation/)
- [Crappy Mobile Games Accidentally Led To The Best Version Of Vampire Survivors — Kotaku](https://kotaku.com/vampire-survivors-free-iphone-steam-mobile-smartphone-1849955308)
- [Premium mobile games are back, with releases up 77% in 2025 — daily.dev](https://daily.dev/posts/premium-mobile-games-are-back-with-releases-up-77-in-2025-mo3xb5ehx)
- [Rush Royale has surpassed the $280M revenue mark — GameDev Reports](https://gamedevreports.substack.com/p/rush-royale-has-surpassed-the-280m)
- [Google Play Developer Fee 2026: $25 + 12-Tester Rule — IconikAI](https://www.iconikai.com/blog/google-play-developer-account-fee-2026)
- [Mobile Game CPI Benchmarks 2026 — Game Growth Advisor](https://gamegrowthadvisor.com/blog/2026-03-17-user-acquisition-cpi-benchmarks-2026/)

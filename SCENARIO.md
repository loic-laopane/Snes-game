# Scénario & direction artistique — Coin Dash

Ce fichier centralise tout ce qui concerne l'histoire, les personnages, les
décors et la direction artistique du jeu, au fur et à mesure que tu me les
donnes. Le code (mécaniques de jeu, physique, contrôles) reste dans
`src/main.asm` ; ce fichier ne contient que le contenu narratif/visuel.

Statut actuel : les mécaniques de base (déplacement, saut, plateformes,
pièces, drapeau) sont en place dans un niveau de test générique. Le scénario
et le concept des personnages commencent à être définis (voir ci-dessous) ;
décors et direction artistique encore à compléter.

> Note : le jeu met en scène des personnages inspirés de célébrités réelles
> (parodie/hommage). Pour un usage perso/hobby ce n'est pas un problème, mais
> si l'idée est un jour de distribuer ou vendre le jeu publiquement, ça vaut
> le coup d'y repenser (droit à l'image, ayants droit) — à garder en tête,
> pas bloquant pour continuer le développement.

## Histoire / scénario

Le joueur incarne **Steevie W.** (personnage inspiré du chanteur américain
aveugle : moustache, couette, lunettes de soleil — voir convention de
nommage ci-dessous), parti en vacances au Moyen-Orient. Pendant son séjour, l'armée israélienne bombarde
son hôtel et le pays tout entier. Steevie s'en sort indemne — mais c'est le
K.O. général dans le pays.

Son objectif : traverser le Moyen-Orient, puis différents pays du monde,
pour retrouver d'autres stars (voir liste des personnages ci-dessous). Une
fois tout le monde réuni, ils chantent ensemble **"We Are the World"** — une
chanson qui a le pouvoir de rétablir la paix.

## Personnages à retrouver (ordre de rencontre)

Convention de nommage in-game : prénom + initiale du nom seulement (ex.
« Steevie W. », « Michael J. »), jamais le nom complet. Ça aide un peu côté
distance/parodie, mais ne suffit pas à écarter le droit à l'image si le jeu
est un jour distribué publiquement (le physique + le contexte restent très
reconnaissables) — voir la note en haut du fichier.

1. Lionel R.
2. Tina T.
3. Diana R.
4. Billy J.
5. Cyndi L.
6. Bruce S.
7. Ray C.
8. Bob D.
9. Michael J.

## Concept personnages jouables

- Dès qu'on retrouve un personnage, on débloque la possibilité de jouer avec
  lui.
- Chaque personnage gagne de l'**expérience**, qui améliore sa **capacité
  principale**.
- Chaque personnage a aussi une **capacité spéciale**, qui se charge
  progressivement au fil du temps (par niveaux).
- _(à préciser : nature de la capacité principale/spéciale par personnage,
  nombre de niveaux de charge, comment l'expérience est gagnée en jeu)_

## Échelle de dégâts

Du plus faible au plus fort — utilisée pour les dégâts **infligés** par le
joueur (voir "Dégâts infligés" ci-dessous) :

1. Faible
2. Moyen
3. Fort
4. Puissant
5. Mortel

## Vie / dégâts subis (système de cœurs)

**Affichage** : chaque cœur à l'écran se remplit en **4 crans** (pas 2),
dans cet ordre visuel :

1. Vide (contour seul)
2. Moitié orange
3. Entièrement orange
4. Moitié rouge (le fond orange reste visible dessous)
5. Entièrement rouge

Intérêt technique : ces 5 états peuvent réutiliser une seule forme de cœur
avec juste la couleur/palette qui change, plutôt que 5 dessins différents —
peu coûteux en tuiles VRAM sur SNES.

**Unité de calcul interne : le quart de cœur** (1 cœur affiché = 4 quarts).
La règle de montée de niveau reste la même *en valeur réelle* (+0,5 cœur de
vie max tous les 2 niveaux), juste exprimée dans cette unité plus fine :

- **Départ** : 3 cœurs = 12 quarts.
- **Montée de niveau** : +2 quarts (= 0,5 cœur) tous les 2 niveaux gagnés.
  `vieMax(niveau) = 12 + 2 * floor((niveau - 1) / 2)` quarts.
- **Ramassables** :
  - Petit cœur → +1 quart (un cran de remplissage : vide→moitié orange,
    moitié orange→plein orange, plein orange→moitié rouge, ou moitié
    rouge→plein rouge, selon l'état courant du cœur en cours de
    remplissage).
  - Gros cœur → +4 quarts (remplit un cœur entier d'un coup).
  - Disque vinyle → remplit tous les cœurs (vie courante = vie max).
- **Plafond de vie au niveau 45** : `vieMax` arrête de grimper à partir du
  niveau 45, même si le personnage continue à farmer jusqu'au niveau 50.
  `vieMax(niveau) = 12 + 2 * floor((min(niveau, 45) - 1) / 2)` quarts.
  Au niveau 45 : `12 + 2*22 = 56` quarts = **14 cœurs**, plafond définitif
  de 45 à 50.

## Dégâts infligés (algorithme de montée en puissance)

Chaque tier de l'échelle de dégâts vaut, **au niveau 1**, un nombre de
points fixe :

| Tier     | Dégâts (niveau 1) |
|----------|-------------------|
| Faible   | 1 |
| Moyen    | 2 |
| Fort     | 3 |
| Puissant | 4 |
| Mortel   | tue l'ennemi instantanément (sauf boss) |

**Boss** : "Mortel" ne tue pas instantanément un boss ; à la place il
inflige un nombre de dégâts fixe qui vaut **5 points au niveau 1**, et qui
augmente avec le niveau (même règle de progression que les autres tiers,
voir juste en dessous).

**Progression avec le niveau du personnage** — un seul bonus, partagé par
tous les tiers, pour que la règle reste simple et cohérente :

```
bonus(niveau) = floor((niveau - 1) / 3)   ; +1 point tous les 3 niveaux

Faible(niveau)   = 1 + bonus(niveau)
Moyen(niveau)    = 2 + bonus(niveau)
Fort(niveau)     = 3 + bonus(niveau)
Puissant(niveau) = 4 + bonus(niveau)
Mortel_boss(niveau) = 5 + bonus(niveau)
```

Exemple : au niveau 10, `bonus = floor(9/3) = 3` → Faible inflige 4,
Moyen 5, Fort 6, Puissant 7, Mortel_boss 8.

**Niveau max : 50, mais non atteignable en jouant normalement.** Une partie
"normale" (sans reload/backtrack pour refarmer des ennemis) doit plafonner
en dessous de 50 ; seul un joueur qui farm délibérément peut atteindre le
niveau max. Concrètement, ça veut dire caler l'XP donnée par les ennemis et
le nombre de niveaux de jeu pour qu'une partie normale s'arrête quelque part
autour de, disons, niveau 30-40 à la fin du jeu (chiffre à affiner une fois
la courbe d'XP définie) — 50 reste un objectif de complétionniste/farmeur,
pas un palier que tout le monde atteint en terminant l'histoire.

Pourquoi cette formule :
- **Un seul palier de croissance** (tous les 3 niveaux) pour tous les
  tiers de dégâts → cohérent, simple à câbler en assembleur (un compteur
  qui s'incrémente tous les 3 level-up, ajouté à une table de 5 valeurs de
  base), et facile à équilibrer côté ennemis (leurs points de vie peuvent
  suivre le même palier de progression pour garder le nombre de coups
  nécessaires à peu près stable d'un bout à l'autre du jeu).
- **Croissance additive, pas multiplicative** : +1 point tous les 3
  niveaux reste lent — pas de risque que le joueur devienne surpuissant
  rapidement, contrairement à un scaling en pourcentage qui s'emballe avec
  le niveau.
- **Cadence volontairement différente de la vie** (dégâts : tous les 3
  niveaux / vie : tous les 2 niveaux) : le personnage devient un peu plus
  résistant avant de devenir plus puissant, ce qui limite encore le
  sentiment de toute-puissance trop tôt.
- _(à préciser : comment les points de vie des ennemis (normaux et boss)
  progressent au fil du jeu pour rester en face de cette échelle de
  dégâts)_

## Expérience (XP)

Deux sources d'XP, volontairement déséquilibrées pour rendre le farm
d'ennemis plus intéressant que le simple replay d'un niveau déjà fini :

**1. Tuer un ennemi** — l'XP dépend de sa force (même idée de tiers que les
dégâts), et augmente légèrement monde après monde pour rester cohérent
avec des ennemis plus costauds plus tard dans le jeu :

| Tier ennemi   | XP de base (monde 1) |
|---------------|-----------------------|
| Faible        | 1 |
| Moyen         | 2 |
| Fort          | 4 |
| Puissant      | 6 |
| Mortel / boss | 15 |

```
XP_ennemi(tier, monde) = XP_base(tier) + (monde - 1)   ; +1 XP par tier, par monde
```

**2. Terminer un niveau** — bonus fixe la première fois, qui **diminue de
moitié à chaque nouvelle fois où on retermine ce niveau**, avec un plancher
pour ne jamais tomber à zéro (juste devenir négligeable) :

```
bonus_base(monde) = 10 + 2 * (monde - 1)      ; monde 1 → 10, monde 9 → 26
bonus_fin_niveau(n) = max(bonus_base >> n, 2)  ; n = nb de fois déjà terminé (0 = 1ère fois)
```

Exemple (monde 1, `bonus_base` = 10) : 1ère fois → 10 XP, 2e fois → 5 XP,
3e fois → 2 XP, puis ça reste à 2 XP (le plancher). Au bout de 2-3 replays,
tuer quelques ennemis du niveau rapporte clairement plus que le rerun du
bonus de fin — c'est l'effet recherché.

**Seuils d'XP par niveau de personnage** : plutôt qu'une formule, une
**table précalculée de 50 valeurs** (XP cumulée nécessaire pour chaque
niveau, 1 à 50). Avec un plafond de niveau aussi petit, une table tient en
~100 octets de ROM et surtout se règle à la main après playtest, sans
avoir à retomber sur une formule mathématique parfaite à l'avance — c'est
l'approche la plus pratique pour équilibrer un jeu SNES solo.

_(à remplir progressivement une fois qu'on peut tester le combat : valeurs
exactes de la table de seuils, pour confirmer que 36 niveaux + farm
raisonnable atterrissent bien autour du niveau 30-40 en jeu normal et 50
en farmant à fond)_

## Décors / niveaux

**Structure retenue** : 9 mondes (un par star à retrouver, fixé par le
scénario), **4 niveaux par monde** = 3 niveaux d'action/plateforme + 1
niveau boss (l'affrontement pour retrouver la star) → **36 niveaux au
total**.

Raisonnement pour caler le niveau 30-40 en fin de partie normale (voir
"Dégâts infligés" pour le niveau max 50 farm-only) : si un niveau normal
rapporte grosso modo l'équivalent d'1 niveau de personnage, et qu'un boss
rapporte un peu plus (~1,5-2 niveaux, XP de fin de monde plus généreuse),
27 niveaux normaux + 9 boss donnent une partie normale qui termine autour
de niveau 30-40 — la courbe d'XP précise reste à affiner, mais l'ordre de
grandeur colle.

Point de vigilance : 36 niveaux (chacun avec son propre décor/ennemis/
layout) représente une grosse quantité de contenu à produire pour un
projet solo — faisable mais ambitieux. Une alternative plus courte serait
3 niveaux/monde (27 niveaux au total) avec un peu plus d'XP par niveau
pour garder le même palier final ; à trancher si le rythme de production
devient trop lourd.

On reste sur **9 mondes**, et on les travaillera **un par un** (décor,
ambiance, ennemis propres à chaque monde) plutôt que de tout spécifier
d'un coup.

### Monde 1 — Moyen-Orient

_(à compléter — c'est le premier à travailler)_

### Mondes 2 à 9

_(à compléter au fur et à mesure, un par un)_

## Direction artistique

_(notes de palette, style, références, une fois le scénario connu)_

## Journal des ajouts

- 2026-07-29 : création du fichier, en attente du contenu.
- 2026-07-29 : ajout du scénario principal, de la liste des 9 personnages à
  retrouver, du concept de jeu par personnage (expérience / capacité
  spéciale à charge), et de l'échelle de dégâts en 5 niveaux.
- 2026-07-29 : convention de nommage in-game (prénom + initiale), et
  concept de vie (barre courte, max lié à l'XP, cœurs ramassables).
- 2026-07-29 : système de vie en demi-cœurs chiffré (3 cœurs de départ,
  +1 demi-cœur tous les 2 niveaux, valeurs des ramassables), et algorithme
  de montée en puissance des dégâts infligés (base par tier + bonus
  partagé tous les 3 niveaux, cas particulier des boss pour "Mortel").
- 2026-07-29 : affichage des cœurs en 4 crans de couleur (vide → moitié
  orange → plein orange → moitié rouge → plein rouge), passage à l'unité
  "quart de cœur" en cohérence, et niveau max fixé à 50 mais volontairement
  hors de portée d'une partie normale (réservé au farm).
- 2026-07-29 : plafond de vie max au niveau 45 (14 cœurs), et structure
  retenue de 9 mondes × 4 niveaux (3 action + 1 boss) = 36 niveaux, pour
  faire atterrir une partie normale autour du niveau 30-40.
- 2026-07-29 : système d'XP (XP par ennemi tué selon son tier + bonus de
  fin de niveau qui diminue de moitié à chaque replay, plancher à 2 XP),
  table de seuils par niveau plutôt qu'une formule, confirmation des 9
  mondes travaillés un par un (monde 1 : Moyen-Orient, à définir).

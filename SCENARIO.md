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

Unité de calcul interne : le **demi-cœur** (1 cœur = 2 demi-cœurs), pour
pouvoir gérer les demi-cœurs proprement en points entiers.

- **Départ** : 3 cœurs (= 6 demi-cœurs).
- **Montée de niveau** : +1 demi-cœur de vie max tous les 2 niveaux gagnés.
  `vieMax(niveau) = 6 + floor((niveau - 1) / 2)` demi-cœurs.
  - Niveau 1 → 3 cœurs, niveau 3 → 3,5 cœurs, niveau 5 → 4 cœurs, niveau 7 →
    4,5 cœurs, etc.
- **Ramassables** :
  - Petit cœur → +1 demi-cœur (remplit un demi-cœur de vie).
  - Gros cœur → +2 demi-cœurs (remplit un cœur entier).
  - Disque vinyle → remplit tous les cœurs (vie courante = vie max).
- _(à préciser : niveau max du jeu, pour borner `vieMax` — ex. si le niveau
  max est 20, `vieMax` plafonne à 6 + 9 = 15 demi-cœurs = 7,5 cœurs)_

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
- _(à préciser : le niveau max du jeu (pour borner `bonus`), et comment
  les points de vie des ennemis (normaux et boss) progressent au fil du
  jeu pour rester en face de cette échelle de dégâts)_

## Décors / niveaux

_(à compléter — lieux, ambiance, progression entre niveaux)_

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

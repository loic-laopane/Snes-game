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

Du plus faible au plus fort :

1. Faible
2. Moyen
3. Fort
4. Puissant
5. Mortel

_(à préciser : à quoi s'applique cette échelle — dégâts subis par le joueur,
dégâts infligés aux ennemis, ou les deux)_

## Vie / dégâts subis

- Barre de vie **courte** (peu de points de vie au total, pour rester
  arcade/nerveux plutôt qu'un jeu d'endurance).
- Le **maximum** de la barre de vie augmente avec l'**expérience** du
  personnage (rejoint le concept personnages ci-dessus : XP = plus de vie
  max, en plus d'améliorer la capacité principale).
- Des **cœurs** ramassables dans les niveaux permettent de récupérer de la
  vie (probablement point(s) de vie, à préciser combien par cœur).
- _(à préciser : nombre de cœurs de vie de base, combien l'XP en ajoute par
  niveau, combien de vie un cœur ramassable rend, et comment l'échelle de
  dégâts ci-dessus se traduit en points de vie retirés)_

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

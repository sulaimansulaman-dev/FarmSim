# Asset Attribution and Licence Log

FarmSim uses third-party art. This file records where every asset came from and
under what terms, which is both a licence obligation and the asset licence log
the project owes as a deliverable.

**Anyone adding an asset to this repository must add a row here in the same
commit.** An asset with no entry here cannot be shipped.

---

## Sprout Lands — Cup Nooble

> Assets — From: Sprout Lands — By: Cup Nooble

Used for the player character, tilesets, crops, objects and environment art in
`farm-sim/farmland-tutorial/game/`.

- **Author:** Cup Nooble — https://cupnooble.carrd.co
- **Pack:** Sprout Lands (free pack, and premium pack where noted)

### Licence terms, as supplied with the pack

- The assets may be modified.
- They may be used in non-commercial and commercial projects.
- They may **not** be used for anything involving NFTs or AI training.
- The **asset pack itself may not be redistributed or resold**, even modified.
  Redistributing *this project* — the game, its source, an open-source
  repository — is expressly permitted.
- Open-source projects must include a note stating that some or all assets are
  by Cup Nooble, together with these licensing terms. **That is what this file
  is for.**
- **Credit is required.**

### What this means for us in practice

We may keep these sprites in this public repository, because that is
distributing our project rather than redistributing the pack. Two things follow:

1. This attribution file must stay in the repository, and the credit must also
   appear somewhere the player can see it — a credits screen, or the README.
2. We must not commit the original pack archive (the `.zip` as downloaded), or
   a folder that is simply the pack copied in wholesale. Use the sprites the
   game needs; do not re-host the product.

---

---

## Original art by the FarmSim team

Work drawn by the team is ours. It carries no third-party licence and needs
no external credit, but it is listed here so the distinction between what we
made and what we borrowed stays clear.

| Path | Author | Notes |
|---|---|---|
| `game/objects/pest_caterpillar.png` | Marne Vermaak | Drawn in Libresprite for the pest indicator. Replaced a generated placeholder. |

---

## Asset register

| Path | Source | Licence | Verified by | Date |
|---|---|---|---|---|
| `game/characters/*` | Sprout Lands, Cup Nooble | See above — credit required | *unverified* | — |
| `game/objects/*` (except originals above) | Sprout Lands, Cup Nooble | See above — credit required | *unverified* | — |
| `game/tilesets/*` | Sprout Lands, Cup Nooble | See above — credit required | *unverified* | — |

**These rows are marked unverified deliberately.** The attribution above is
inferred from the filenames and art style, which match Sprout Lands, but nobody
on the team has confirmed which pack each file came from or who downloaded it.
Whoever added them should confirm the source and sign the row.

---

## Adding a new asset

1. Confirm the licence permits use in a public, open-source student project.
2. Confirm it permits redistribution as part of a project, not just private use.
3. Add a row above with the path, source URL, licence, your name, and the date.
4. Keep the original licence or read-me file alongside the assets.
5. If the licence requires credit, make sure it reaches the credits screen —
   not just this file.

# Compiled build - how the two games were joined

This was three separate Godot projects. It is now one.

| Was | Now |
|---|---|
| `farm-sim/` (FarmSim menu shell) | the title screen, `res://scenes/ui/title_screen.tscn` |
| `farm-sim/godot-croptails-main/` (Croptails) | the project root, `res://` |
| `farm-sim/farmland-tutorial/` (level drafts) | `res://drafts/` |

Open the folder containing `project.godot` in Godot 4.7. The first launch
re-imports every texture, so give it a minute.

## Why Croptails is the project root

Croptails is the biggest of the three and the only one with autoloads, an addon
(Dialogue Manager) and a custom audio bus layout. Putting it at `res://` means
every path inside it - several hundred across its scenes and tilesets - still
resolves exactly as before. Nothing in Croptails was moved, so nothing in
Croptails needed rewriting.

The drafts moved instead, into `res://drafts/`, and were rewritten to match.

## What the title screen does

It is the main scene and it is **never freed**. Starting a level hides it and
adds the level under `/root` beside it; leaving frees the level and shows the
title again. That matters because Croptails' multiplayer code looks up
`/root/MainScene` by absolute path, and swapping the current scene out from
under it would break player spawning.

**Level Select** lists everything in one place, from `SceneManager`:

- **Croptails** - Island 1, Level 1, Island 3. These load the real game: main
  scene container, save system, HUD, tools, the lot.
- **Team level drafts** - Farm World, Farm Grid, Tilemap + Player, Tilemap Only,
  Greenfield. These run standalone with their own controls, inside a wrapper
  (`draft_level_host.tscn`) that adds a title bar and an Escape-to-leave.

To add a level, add one entry to `level_scenes` + `croptails_level_order`, or to
`draft_levels`, in `res://scripts/globals/scene_manager.gd`. The menu builds
itself from those lists - no UI work needed.

## Conflicts that had to be resolved

**Duplicate `class_name`.** Both projects defined `Player`, `Crop`,
`CropLibrary`, `NodeState` and `NodeStateMachine`. Two scripts claiming one
global class name is a parse error and the project will not run at all. The
draft copies were renamed with a `Draft` prefix (`DraftPlayer`, `DraftCrop`, and
so on) and every reference updated. Croptails' names are untouched, so the
drafts are the ones that changed - they are the work in progress.

**Overlapping paths.** Both projects had `res://scenes/` and `res://data/`.
Moving the drafts under `res://drafts/` separates them; all 87 `res://`
references inside the drafts were repointed, including the sprite sheet path
inside `crops.json`.

**Import cache.** The 47 draft `.import` files had their destination hashes
recomputed for the new paths (Godot names cached imports by MD5 of the resource
path), so the textures import cleanly rather than as mismatches.

**UIDs.** Checked before merging - 269 in Croptails, 70 in the drafts, no
collisions, so nothing needed reassigning.

**Input map.** Croptails' map is kept. It already binds WASD and the arrow keys
to the same `walk_*` actions the drafts use, so the drafts needed nothing added.

## Smaller changes

- The in-game pause menu gained a **MAIN MENU** button and hides **START**,
  since the title screen is the home screen now. Leaving a multiplayer session
  this way closes the peer first.
- Escape opens the Croptails pause menu only while a Croptails level is running.
  On the title screen there is nothing to pause, and the drafts use Escape
  themselves - Farm World's seed picker closes with it.
- The title screen's **Multiplayer** page is wired to Croptails'
  `MultiplayerManager` (real host/join). It previously only printed
  "Connecting..." and stopped.
- The dead **Scene 1-5** buttons are gone; Level Select replaces them.
- The menu font is applied to the title screen only. The original set it on the
  root viewport, which would now override Croptails' own UI theme everywhere.
- Menu sizing was rebuilt for the 640x360 viewport. At the old 1280x720 sizes
  the singleplayer card alone was taller than the screen.
- Added **Play as Guest**, and Enter now submits on the login screen.

## The staged build (Stages 1 to 5)

The level select now leads with the five stages from the functional spec. Each
stage adds exactly one system to the one before it, which only teaches anything
if the earlier stages genuinely lack the later ones - so a `StageDirector` node
in each scene decides which tools the toolbar offers and switches the economy
and calendar on or off.

| Stage | Scene | Adds |
|---|---|---|
| 1 - Core Lifecycle | `island_1.tscn` | Till, sow, water, harvest. Marlow's tutorial. |
| 2 - Market & Economy | `stage_2_market.tscn` | Money, seed cost, market stall, selling. |
| 3 - Pests & Quality | `stage_3_pests.tscn` | Pest outbreaks, bought sprays, Grade A/B. |
| 4 - Tree Farming | `stage_4_trees.tscn` | Fruit orchard, shaking, timber felling. |
| 5 - Seasons | `stage_5_seasons.tscn` | Four-season calendar, warnings, seed viability. |

Stages 2 to 5 are the Island 1 terrain with different components on it. Object
positions were not guessed: the tilemap data was decoded to find the walkable
grass, so the market crate and the orchard sit on real ground clear of the
tilled field (cells x19-26, y11-16) and the guide.

**Why the managers do not start themselves.** `EconomyManager` and
`SeasonManager` are autoloads, so they outlive a level. If they switched
themselves on they would still be on when the player returned to Stage 1, and
the tutorial would start charging for the seed it hands out free. Each stage
configures them, so leaving a stage resets them. With the economy off,
`charge_for_seed` always succeeds and costs nothing - which is what keeps every
pre-market island playing exactly as it did.

**Grading** is read off the crop's penalty ledger, not its health. Health
recovers day to day; the ledger is append-only and records what the season
actually cost. A crop that was eaten by pests for a week and then nursed back to
full health is not Grade A produce, and grading on health would say it was.
Graded produce stacks separately in the inventory (`cabbage (A)` vs
`cabbage (B)`) so the two can be priced and sold apart.

**Balance**, checked against the data rather than asserted: cabbage costs R9 and
returns R64 at Grade A or R38 at Grade B, so the R14 spray pays for itself.
Every crop stalls in winter, and off-season growth is genuinely slower rather
than merely discouraged - maize at spring's 18C develops at about two thirds
rate. Seasons run 4 in-game days each.

## Bugs found and fixed

**`CropManager` and `FarmEvents` were never registered as autoloads.** Both are
used in more than twenty places across Croptails - the tools panel, inventory
panel, crop info panel, crop plant, crop sim, both cursor components, the
tutorial director and the pest coach. This predates the merge: the original
Croptails `project.godot` lists nine autoloads and neither is among them. It was
breaking a large part of the game, and it is the error reported from
`tools_panel.gd` line 97.

**Autoload ordering.** `SeasonManager._ready` connects to
`DayNightCycleManager`, so it has to be instantiated after it. Caught by
auditing every autoload for singletons used during `_ready`; the full list is
now ordered by dependency.

**Fruit trees ignored `initial_growth_state`.** All four tree scripts export it
with a comment saying it "lets a level designer drop this scene in already fully
grown", and it never worked - Godot assigns exported properties before `_ready`,
so `growth_cycle_component` was still null and the setter's guard silently
discarded the value. Every tree placed as Mature came up a sapling. The value is
now kept and applied in `_ready`. Stage 4's orchard depends on this.

**`market_stall.tscn` under-declared `load_steps`.** Cosmetic, but fixed.

A sweep for undefined global identifiers across every script found no others.

## Known issues, inherited not introduced

- `drafts/scenes/characters/player/player.tscn` assigns `walk_state.gd` to
  **both** the `idle` and `walk` state nodes; `idle_state.gd` is never used. The
  player still moves correctly, so this was left as the authors had it.
- `scenes/test/test_scene_objects.tscn` carries a stale UID for
  `apple_tree.tscn`. Godot falls back to the path, which is correct. Pre-existing
  in Croptails.
- The stats screen still shows zeros. It was never connected to a data source in
  the original menu, and wiring it to Croptails' save data is a real piece of
  work rather than a merge fix.
- `ATTRIBUTION.md` refers to `farm-sim/farmland-tutorial/game/`. That art is now
  at `res://drafts/game/`. The licence terms are unchanged.

## Verified

No Godot binary was available, so this was checked statically rather than by
running it. Every `res://` reference resolves, every `uid://` is defined, no
duplicate `class_name` remains, all thirteen autoloads resolve and are ordered
by dependency, no scene references an undefined `ExtResource` id, every level in
the catalogue points at a real scene, all GDScript is bracket-balanced with
consistent indentation, and the economy and season data files were checked for
consistency against `crops.json`.

**It has not been launched.** Open it in the editor and play each stage before
relying on it. The stage scenes are generated `.tscn` text, so a property-name
mistake there is the most likely thing to surface first.

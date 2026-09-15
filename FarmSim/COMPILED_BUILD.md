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

No Godot binary was available in the environment used to do the merge, so this
was checked statically rather than by running it: every `res://` reference
resolves to a file that exists, every `uid://` reference is defined, no
duplicate `class_name` remains, all nine autoloads resolve, and every level in
the catalogue points at a real scene. **It has not been launched.** Open it in
the editor and play each entry in Level Select before relying on it.

# Lanternfall: Echoes of the Sunken Crown

An original fantasy action platformer for Android, built in Godot 4. This is a **vertical slice**: one region (Lanternroot Hollow), one enemy type, one spell. All art and audio are temporary placeholders generated in code.

Not affiliated with any other game. Read `STEAL_LIKE_AN_ARTIST.md` before you publish anything.

## Run it (desktop)

1. Install Godot 4.4.x (free): https://godotengine.org/download
2. Open `project.godot`, press F5.

Newer 4.x editors will offer to upgrade the project. Accept and re-run the tests.

| Action | Keyboard | Touch |
|---|---|---|
| Move | A/D or arrows | left/right buttons |
| Jump (hold for higher) | Space | JUMP |
| Slash | J | SLASH |
| Flare (costs light) | K | FLARE |
| Pause | Esc | II |

Goal: reach the Sun Sigil at the far right. The big gap needs Flare: it makes hidden stones solid for 7 seconds. There is one secret ledge with bonus shards.

## Test it

```
GODOT=/path/to/godot sh tests/run_tests.sh
```

Runs 83 headless checks: movement, jump height, coyote time, jump buffer, combat, enemy states, Flare, Lumen platforms, shards, checkpoints, saving, death, touch input, menu layout, scene flow. Exit code 1 on any failure.

Screenshots (needs a display, for example `xvfb-run`): `res://tests/screenshot_scene.tscn`. Samples are in `docs/screenshots/`.

## Build for Android

Not done yet. See status below. Steps once you have a PC with Godot:

1. Install JDK 17 and the Android SDK as described in the official guide: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
2. Editor > Manage Export Templates, install templates for your version.
3. Project > Export > Android. Change the package name from `com.example.lanternfall`.
4. Export a debug APK and install it with `adb install`.

No PC? Push this folder to GitHub and let `.github/workflows/android-build.yml` try to build it. That workflow is untested, so expect to fix a path or two.

## Project layout

```
scenes/        thin scene shells (main_menu, player, enemies, levels, environments, ui)
scripts/       player, enemies, magic, world objects, ui, levels, managers, save_system
assets/audio/  generated sfx and music (see tools/generate_audio.py)
tests/         headless tests and screenshot scene
```

Edit the level in `scripts/levels/level.gd`: the layout is plain data at the top of the file.

## Status against the skill's acceptance criteria

| Criterion | Status | Evidence |
|---|---|---|
| Project opens without blocking errors | Verified headless | Godot 4.4.1 import and run, no script errors. Editor GUI itself not opened. |
| Starts, main menu works | Verified | Rendered screenshot, New Game, Continue, Settings, Credits flow tested. Exit not tested. |
| Move and jump | Verified | Automated checks incl. variable height, coyote time, jump buffer. |
| Combat and enemy interactions | Verified | Sword hits, one hit per swing, enemy states, contact damage, invulnerability, death and respawn. Feel by hand not judged. |
| Magic ability works | Verified | Flare cost, projectile, damage, reveals platforms, platforms solid then fade. |
| Playable level with clear objective | Partly verified | Sigil triggers completion. A full start-to-finish run by simulated input was not done. |
| Collectibles and checkpoints | Verified | Pickup, no respawn after save, checkpoint heal and save, pit respawn. |
| Save/load | Verified | Roundtrip, corrupt file, wrong version, Continue restores state. |
| UI and touch controls | Logic verified | Simulated multi-touch passes. Not tried on a real phone. |
| Audio and visual feedback | Integrated | Files load and loop, visuals seen in screenshots. Sound quality never heard (no audio device here). |
| Android export succeeds | Not verified | No Android SDK or templates in the build environment. |
| APK installs and launches | Not verified | No APK exists. |
| GitHub docs and workflow | Present, workflow not validated | Never run. |
| Limitations disclosed | Yes | Below. |

## Known limits

Not implemented: moving platforms, ladders, wall mechanics, boss, extra spells, equipment, levels, upgrades shop, graphics presets, controller layout customization, safe-area handling for notches. Gamepad is mapped but untested. Art is placeholder shapes with no sprite animation. One music loop. Progress saves only at lantern posts, from the pause menu, and on victory.

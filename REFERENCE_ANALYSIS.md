# Reference Analysis

Phase 1 of the skill: inspect the supplied reference before relying on it.

## Supplied files

- `Swordigo_2_Claude_Skill.md`: the build specification (Godot 4, GDScript, Android, GitHub Actions). Followed, with one change: the provisional title was dropped (see `STEAL_LIKE_AN_ARTIST.md`).
- `swordigo-vita-master.zip`: inspected below.

## What the zip actually contains

28 files, about 4.9 MB unpacked.

| Part | Contents |
|---|---|
| `loader/` | 6 C files, 7 headers, 1 C++ file. A PlayStation Vita program that loads an Android binary into memory and patches it to run. |
| `CMakeLists.txt` | Build file for the Vita SDK (vitasdk, vitaGL, SDL2, OpenAL and similar). |
| `livearea/` | Vita home-screen images and a template.xml. |
| `screenshots/` | 4 screenshots of the commercial game running on a Vita. |
| `README.md` | Says it is a wrapper/port that loads the official Android ARMv7 executable (`libswordigo.so`) taken from the user's own copy of the game. |

## Findings

- It is a platform wrapper, not game source. There is no gameplay code, no levels, no art, no audio, no Android project and nothing for Godot.
- It cannot run without the commercial game's own binary and assets, which the user must extract from a legally obtained APK.
- Loader source files carry MIT license headers from their authors. The archive has no LICENSE file.
- Its target is PS Vita. It cannot produce an Android build or an original game.

## Decision

Nothing from this archive is used in Lanternfall: no code, no images, no screenshots, no build files. It was inspected only to establish what it is. Lanternfall is written from scratch.

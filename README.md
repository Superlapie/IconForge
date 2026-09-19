# Icon Studio

[![Godot 4.x](https://img.shields.io/badge/Godot-4.x-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![License: PolyForm Noncommercial](https://img.shields.io/badge/License-PolyForm%20Noncommercial-orange.svg)](LICENSE)
[![Commercial license available](https://img.shields.io/badge/commercial%20use-contact%20author-blue.svg)](COMMERCIAL.md)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Offline & deterministic](https://img.shields.io/badge/offline-deterministic-2ea043)](#quality-gate)

**Community-built Godot tooling for consistent game icons and thumbnails at content scale.**

Icon Studio is a standalone Godot 4.x application for turning 3D and static source assets into production-ready PNG imagery. It is offline-first, deterministic, and designed so an AI agent can operate the same render services as a human using the GUI.

![Icon Studio GUI — live preview, preset inspector, and export workflow](docs/assets/icon-studio-ui.png)

## Built for Enigma

This tool was extracted from the content pipeline for **Enigma**, my Godot 3D MMO project. Inventory grids, equipment previews, shop thumbnails, and portrait frames all need the same framing, lighting, and alpha behavior — Icon Studio is the shared render core that makes that repeatable.

The repo has **no runtime dependency** on the game itself: it ships as a standalone studio with its own CLI, presets, validation, and GUI. If you are building a Godot game with lots of item or character art, you can adopt Icon Studio without touching Enigma.

Related open tooling from the same ecosystem: [VFX Forge](https://github.com/Superlapie/VFXForgeEnigma) for real-time VFX authoring.

## Community project

Icon Studio is intentionally open. I want this to become a **badass community-built tool**, not a private pipeline script.

- **Good pull requests get reviewed.** See [CONTRIBUTING.md](CONTRIBUTING.md) for scope, quality gate expectations, and first-contribution ideas.
- **Discussions are open** for preset design, integration questions, and roadmap ideas: [GitHub Discussions](https://github.com/Superlapie/IconStudioEnigma/discussions).
- **Issues welcome** for reproducible bugs and focused feature requests.

If Icon Studio saves you time on your Godot project, a star, a preset contribution, or a docs fix helps others find it too.

## Launch

GUI:

```bash
./scripts/launch-gui
```

Machine API (recommended for AI agents):

```bash
./scripts/iconstudio api --request examples/render_inventory.json --json
```

Legacy expert CLI:

```bash
./scripts/iconstudio presets --json
./scripts/iconstudio render fixtures/sword.gltf --preset weapon --output out/sword.png --force --json
```

See [docs/MACHINE_API.md](docs/MACHINE_API.md).

The included `scripts/iconstudio` wrapper uses a local Godot binary when present and uses `xvfb-run` for software OpenGL batch rendering on headless Linux machines. Set `ICONSTUDIO_GODOT` to use another Godot 4.x executable.

## Included workflows

- GLB/glTF inspection and rendering through Godot’s native importer.
- PNG, JPEG, and WebP static-image fitting, background, outline, shadow, and resize workflow.
- Versioned JSON presets with migration, validation, schema discovery, and user preset creation.
- Auto-framing based on inspected AABB plus bounded rendered-silhouette correction.
- Orthographic and perspective cameras, predictable orientation strategies, deterministic key/fill/rim lighting, transparent/solid/gradient backgrounds, post-processing, outlines, and presentation layers.
- Asset-specific `<source_name>.icon.json` overrides, cache keys, safe atomic writes, batch isolation, and JSON manifests.
- GUI source list, drag-and-drop, preset picker, preview orbit/zoom, structured transform controls, sidecar save, and PNG export.

## Architecture

The project has no cloud service and no internal AI model. Its reusable core is organized as:

```text
source loading → inspection → render scene → framing/camera → lighting
→ image processing → quality checks → PNG export → manifest/cache
```

Both the GUI and CLI call the same shared `RenderService`. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [AGENTS.md](AGENTS.md).

## Quality gate

```bash
./scripts/quality-gate
```

It runs typed GDScript tests, validates all built-in presets, renders a fixture,
validates its output, completes a fixture batch smoke test, and runs the
real-authored-model and GUI drag/drop E2Es. Generated images and manifests are written under
`out/` and are ignored by Git.

For production-oriented proof against real authored GLB assets, run:

```bash
./scripts/real-model-e2e
```

The real-model proof uses pinned, openly licensed Khronos glTF samples and
writes its inspect/render/validation JSON plus PNG evidence to `out/e2e-real/`.
See [docs/REAL_MODEL_E2E.md](docs/REAL_MODEL_E2E.md).

For the full native OS drag/drop protocol proof on Linux/X11, see
[docs/GUI_E2E.md](docs/GUI_E2E.md).

## Documentation

- [Quickstart](docs/QUICKSTART.md)
- [CLI reference](docs/CLI_REFERENCE.md)
- [AI / machine workflow](docs/AI_WORKFLOW.md)
- [Preset reference](docs/PRESET_REFERENCE.md)
- [Contributing](CONTRIBUTING.md)
- [Commercial licensing](COMMERCIAL.md)

## License

Icon Studio uses **dual licensing**:

- **Noncommercial use** — free under the [PolyForm Noncommercial License 1.0.0](LICENSE). You can read, fork, contribute, learn from, and use the project for personal, hobby, educational, and other noncommercial purposes.
- **Commercial use** — requires a separate paid license. See [COMMERCIAL.md](COMMERCIAL.md) for what counts as commercial use and how to contact me.

If you want to ship a commercial game, product, service, or client deliverable with Icon Studio in the pipeline, get a commercial license first.

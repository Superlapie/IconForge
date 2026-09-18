# Icon Studio

Icon Studio is a standalone Godot 4.x application for turning 3D and static source assets into consistent, production-ready game icons and thumbnails. It is offline-first, deterministic, and designed so an AI agent can operate the same render services as a human using the GUI.

The project has no Enigma dependency, no cloud service, and no internal AI model. Its reusable core is organized as:

```text
source loading → inspection → render scene → framing/camera → lighting
→ image processing → quality checks → PNG export → manifest/cache
```

## Launch

GUI:

```bash
./scripts/launch-gui
```

CLI:

```bash
./scripts/iconstudio presets --json
./scripts/iconstudio inspect fixtures/sword.gltf --json
./scripts/iconstudio render fixtures/sword.gltf --preset weapon --output out/sword.png --force --json
```

The included `scripts/iconstudio` wrapper uses a local Godot binary when present and uses `xvfb-run` for software OpenGL batch rendering on headless Linux machines. Set `ICONSTUDIO_GODOT` to use another Godot 4.x executable.

## Included workflows

- GLB/glTF inspection and rendering through Godot’s native importer.
- PNG, JPEG, and WebP static-image fitting, background, outline, shadow, and resize workflow.
- Versioned JSON presets with migration, validation, schema discovery, and user preset creation.
- Auto-framing based on inspected AABB plus bounded rendered-silhouette correction.
- Orthographic and perspective cameras, predictable orientation strategies, deterministic key/fill/rim lighting, transparent/solid/gradient backgrounds, post-processing, outlines, and presentation layers.
- Asset-specific `<source_name>.icon.json` overrides, cache keys, safe atomic writes, batch isolation, and JSON manifests.
- GUI source list, drag-and-drop, preset picker, preview orbit/zoom, structured transform controls, sidecar save, and PNG export.

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

See [docs/QUICKSTART.md](docs/QUICKSTART.md), [docs/AI_WORKFLOW.md](docs/AI_WORKFLOW.md), and [docs/CLI_REFERENCE.md](docs/CLI_REFERENCE.md) for the full machine-facing contract.

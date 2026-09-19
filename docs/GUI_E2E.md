# GUI drag/drop E2E proof

> **AI agents** integrate through the [Machine API](MACHINE_API.md), not the GUI. This E2E validates the human-facing drop boundary.

Icon Studio accepts operating-system file drops through the main Godot
`Window.files_dropped` boundary. The callback normalizes file URIs, filters
supported sources, deduplicates the source list, selects the first accepted
asset, inspects it, and schedules the same `RenderService` preview used by
CLI rendering.

## Reproducible GUI proof

This command copies the real Khronos Avocado GLB to a temporary external path,
emits the native Godot file-drop signal, waits for the rendered 256px preview,
decodes the PNG, and verifies duplicate plus unsupported-file handling:

```bash
./scripts/gui-e2e
```

The machine-readable result and screenshot are written to:

```text
out/gui-e2e/result.json
out/gui-e2e/drop_preview.png
```

## Native X11 protocol proof

For Linux/X11, the stronger test below speaks XDND as an external source. It
verifies XDND enter/position/drop, selection transfer, Godot's actual
`files_dropped` callback, external runtime glTF loading, preview rendering,
and screenshot capture:

```bash
python3 -m pip install --target /tmp/iconstudio-python-xlib python-xlib
ICONSTUDIO_PYTHON_PATH=/tmp/iconstudio-python-xlib ./scripts/gui-native-dnd-e2e
```

`python-xlib` is test-harness tooling only; it is not an Icon Studio runtime
dependency. The proof output is written to `out/gui-native-dnd-e2e/`.

The native test deliberately drops a copied model outside the Godot project.
That proves the runtime `GLTFDocument` fallback is used when editor import
metadata is unavailable. The product remains offline and does not require
Blender or an online service.

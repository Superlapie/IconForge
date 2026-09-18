# Quickstart

## 1. Start the GUI

```bash
./scripts/launch-gui
```

Drop a `.glb`, `.gltf`, `.png`, `.jpg`, or `.webp` into the source panel, choose a preset, orbit or zoom the preview, and export a PNG. The fixture models are preloaded when available so a fresh checkout has an immediate example.

## 2. Inspect a source

```bash
./scripts/iconstudio inspect fixtures/sword.gltf --json
```

Inspection reports dimensions, center, AABB, meshes, materials, triangles, skeleton/animation flags, dependencies, and a suggested geometric orientation.

## 3. Render one source

```bash
./scripts/iconstudio render fixtures/sword.gltf \
  --preset weapon \
  --output out/sword.png \
  --force \
  --json
```

The result contains the output path, quality metrics, warnings, and number of auto-framing passes.

## 4. Render a directory

```bash
./scripts/iconstudio render-batch fixtures \
  --preset neutral_asset_thumbnail \
  --output out/icons \
  --manifest out/icons/manifest.json \
  --json
```

## 5. Run the quality gate

```bash
./scripts/quality-gate
```


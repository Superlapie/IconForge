# Architecture

## Boundaries

```text
ApiService           canonical machine API dispatcher (safe + expert modes)
PurposeRegistry      semantic purposes → production recipes
RecipeResolver       deterministic purpose + inspection → preset
WorkspacePolicy      safe-mode filesystem confinement
ProductionQuality    authoritative production contract validation
AssetInspector       source decode/import and geometry metrics
PresetDefinition     canonical versioned data model (preset_revision)
PresetService        preset discovery, migration, validation, persistence
FramingService       geometric orientation, AABB framing, correction math
RenderService        temporary Godot scene, camera, lights, capture, export
ImageProcessor       static fit, background, color, outline, glow, shadow
QualityService       alpha/resolution/clipping/occupancy checks
CacheService         content-addressed-ish render cache index
BatchService         discovery, naming, isolation, progress/result manifest
IconStudioCli        transport over ApiService + legacy expert commands
StudioUi             human-facing controls over the same services
```

The machine API sits **above** core render services. CLI `api` commands and future transports call `ApiService.execute()`. The GUI and legacy CLI expert commands may call `RenderService` directly. All paths share inspection, presets, framing, quality, cache, and manifests.

## Render lifetime

Each 3D render creates a temporary `SubViewport`, stage, imported instance, camera, environment, and deterministic key/fill/rim lights. The stage captures at supersampled resolution, then is freed. Static sources take a separate fit/contain/cover route before shared post-processing.

## Determinism

There is no random camera or lighting choice. The effective preset is the resolved JSON plus explicit/sidecar overrides. Cache keys include source SHA-256, canonical preset JSON, overrides, and tool version. GPU pixel identity can vary by driver; quality checks focus on catastrophic failures and measured silhouette behavior.

## Extension points

New output formats, turntables, multi-object compositions, material overrides, and atlas exporters should be added behind `RenderService`/`BatchService` contracts. Do not introduce an alternate command-specific render implementation.


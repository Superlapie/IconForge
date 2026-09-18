# Architecture

## Boundaries

```text
AssetInspector       source decode/import and geometry metrics
PresetDefinition     canonical versioned data model
PresetService        preset discovery, migration, validation, persistence
FramingService       geometric orientation, AABB framing, correction math
RenderService        temporary Godot scene, camera, lights, capture, export
ImageProcessor       static fit, background, color, outline, glow, shadow
QualityService       alpha/resolution/clipping/occupancy checks
CacheService         content-addressed-ish render cache index
BatchService         discovery, naming, isolation, progress/result manifest
IconStudioCli        machine-facing command routing and exit codes
StudioUi             human-facing controls over the same services
```

The GUI and CLI share every source-inspection, preset, render, processing, quality, cache, and manifest behavior. The GUI only supplies interaction state and displays service results.

## Render lifetime

Each 3D render creates a temporary `SubViewport`, stage, imported instance, camera, environment, and deterministic key/fill/rim lights. The stage captures at supersampled resolution, then is freed. Static sources take a separate fit/contain/cover route before shared post-processing.

## Determinism

There is no random camera or lighting choice. The effective preset is the resolved JSON plus explicit/sidecar overrides. Cache keys include source SHA-256, canonical preset JSON, overrides, and tool version. GPU pixel identity can vary by driver; quality checks focus on catastrophic failures and measured silhouette behavior.

## Extension points

New output formats, turntables, multi-object compositions, material overrides, and atlas exporters should be added behind `RenderService`/`BatchService` contracts. Do not introduce an alternate command-specific render implementation.


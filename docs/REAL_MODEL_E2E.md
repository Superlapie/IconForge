# Real-model E2E proof

> This is a **production evidence** test for humans and CI. AI agents normally integrate through the [Machine API](MACHINE_API.md) and do not run this script directly.

The procedural files in `fixtures/` are useful for fast unit and smoke tests,
but they are not sufficient evidence for production asset loading. The
canonical externally authored-model proof is:

```bash
./scripts/real-model-e2e
```

It performs a clean Godot import, verifies pinned SHA-256 checksums, inspects
two real textured GLBs, renders an Avocado with the `consumable` preset, and
renders a BoomBox with the neutral thumbnail preset. The BoomBox run
intentionally demonstrates the AI correction loop:

1. an explicit `occupancy: 0.80` and deliberately small `scale: 0.30` render
   emits `OUTPUT_OCCUPANCY_LOW`;
2. the committed `BoomBox.icon.json` sidecar restores the scale, permits the
   small model-unit zoom, and records the measured compact silhouette target;
3. the corrected render has no warnings and passes `validate-output`;
4. the same sidecar is applied during a two-asset batch, producing a success
   manifest.

Machine-readable evidence is written to `out/e2e-real/`:

- `inspect_*.json` — source metrics, material/mesh counts, triangle counts,
  and texture dependencies;
- `render_*.json` — render passes, metrics, warnings, and errors;
- `validate_boombox.json` — final quality result;
- `batch.json` and `batch/manifest.json` — batch result and per-source status;
- PNGs — the actual outputs inspected by the quality service.

The sources and licensing details are recorded in
`tests/e2e/assets/real/PROVENANCE.md`; they are Khronos glTF sample assets,
not generated primitives and not an Enigma dependency.

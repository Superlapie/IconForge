# Contributing to Icon Forge

Icon Forge is a **community-built, AI-agent-first** tool. It started as production infrastructure for **Enigma**, a Godot 3D MMO game, and is maintained in the open so other Godot teams — and the agents that serve them — can ship consistent inventory art, shop thumbnails, and UI imagery at scale.

Pull requests that improve reliability, preset quality, **machine API safety**, documentation, or agent-facing workflows are welcome.

## If you are an AI agent modifying this repo

Read [AGENTS.md](AGENTS.md) first. Preserve the machine API contract:

- Safe-mode agents specify `purpose`, not renderer internals.
- Unknown request fields must be rejected.
- `success: true` must mean validated production output.
- Run `./scripts/quality-gate` (includes adversarial API tests).

## Licensing and contributions

By contributing to this repository, you agree that:

1. Your contributions are licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE).
2. You grant Superlapie the right to use, sublicense, and commercially license your contributions as part of Icon Forge under separate commercial license terms offered to paying customers.

You keep copyright in your contributions, but you may not contribute code you do not have the right to license under these terms.

Commercial use of Icon Forge itself still requires a separate commercial license. See [COMMERCIAL.md](COMMERCIAL.md).

## Before you open a PR

1. Read [AGENTS.md](AGENTS.md) for the canonical architecture and safe editing rules.
2. Run the quality gate locally:

   ```bash
   ./scripts/quality-gate
   ```

3. Keep changes focused. Prefer extending shared services in `core/` over one-off GUI or CLI shortcuts.
4. Never overwrite source models or images in fixtures or tests.
5. Machine API changes must update `core/api/api_schema.gd` (executable schema) and [docs/MACHINE_API.md](docs/MACHINE_API.md).

## Great first contributions

- Machine API tests, error codes, or clearer `recommended_action` values.
- Preset tuning or new data-only presets in `presets/` (validate with `./scripts/iconforge validate-preset`).
- Documentation for agent integrators ([AGENTS.md](AGENTS.md), [MACHINE_API.md](docs/MACHINE_API.md)).
- Quality checks, adversarial request tests, and E2E stability on Linux headless CI.

## Pull request checklist

- [ ] `./scripts/quality-gate` passes (or you explain why a subset is sufficient).
- [ ] Machine API schema and docs stay in sync for any API changes.
- [ ] CLI JSON output remains stable for existing commands, or the change is documented.
- [ ] New presets pass `./scripts/iconforge validate-preset`.
- [ ] No secrets, credentials, or proprietary assets are added.

## Code of conduct

Be direct, be kind, and optimize for maintainability. Disagreement is fine; harassment is not.

## Questions

Open a [Discussion](https://github.com/Superlapie/IconForge/discussions) for design questions, preset ideas, or agent integration help. Use [Issues](https://github.com/Superlapie/IconForge/issues) for reproducible bugs and feature requests.

# Contributing to Icon Studio

Icon Studio is a **community-built** tool. It started as production infrastructure for **Enigma**, a Godot 3D MMO game, and is now maintained in the open so other Godot teams can ship consistent inventory art, shop thumbnails, and UI imagery at scale.

Pull requests that improve reliability, preset quality, documentation, or machine-facing workflows are welcome. I review good PRs promptly and would rather merge thoughtful community work than keep this as a solo project.

## Before you open a PR

1. Read [AGENTS.md](AGENTS.md) for the canonical architecture and safe editing rules.
2. Run the quality gate locally:

   ```bash
   ./scripts/quality-gate
   ```

3. Keep changes focused. Prefer extending shared services in `core/` over one-off GUI or CLI shortcuts.
4. Never overwrite source models or images in fixtures or tests.
5. Use `--json` for any CLI changes that affect machine workflows.

## Great first contributions

- Preset tuning or new data-only presets in `presets/` (validate with `./scripts/iconstudio validate-preset`).
- Documentation fixes, examples, and clearer error messages.
- Quality checks, test coverage, and E2E stability on Linux headless CI.
- Bug fixes with a reproducible fixture or real-model E2E case.

## Pull request checklist

- [ ] `./scripts/quality-gate` passes (or you explain why a subset is sufficient).
- [ ] CLI JSON output remains stable for existing commands, or the change is documented.
- [ ] New presets pass `./scripts/iconstudio validate-preset`.
- [ ] No secrets, credentials, or proprietary assets are added.

## Code of conduct

Be direct, be kind, and optimize for maintainability. Disagreement is fine; harassment is not.

## Questions

Open a [Discussion](https://github.com/Superlapie/IconStudioEnigma/discussions) for design questions, preset ideas, or integration help. Use [Issues](https://github.com/Superlapie/IconStudioEnigma/issues) for reproducible bugs and feature requests.

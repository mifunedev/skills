# `docs/`

Reference documentation for the skills library.

| File | Purpose |
|------|---------|
| [`checksum.md`](checksum.md) | Checksum algorithm — how `registry.json` integrity values are computed and verified |
| [`portability.md`](portability.md) | Portability policy — why Claude Code-specific keys are namespaced under `metadata.mifune.claude-code.*` |
| [`schema/registry.v1.json`](schema/registry.v1.json) | JSON Schema for `registry.json` |

Future site content for [skills.mifune.dev](https://skills.mifune.dev) will be generated from `skills/<name>/` + registry metadata. Authoring guides and architecture references will also live here.

## Conventions

- Markdown only. No generated output committed here.
- File names use kebab-case.
- Cross-references to skill folders use relative paths (`../skills/<name>/SKILL.md`).

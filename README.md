# mifunedev/skills

A portable, cross-agent skill library. Each skill is a plain folder containing a `SKILL.md` file that conforms to the [Agent Skills specification](https://agentskills.io/specification). The installer copies the folder to your project — no daemon, no runtime, no build step.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mifunedev/skills/master/scripts/install.sh | bash -s -- install <skill-name> --scope project
```

The `| bash -s --` pattern sends the downloaded script to bash. Everything after `--` is passed as arguments to the script itself, not to bash.

**Options:**

| Flag | Default | Purpose |
|------|---------|---------|
| `--scope project` | `project` | Install into the current git repo |
| `--client agents\|claude\|harness` | `agents` | Target client destination (`.agents/skills/`, `.claude/skills/`, or both) |

The installer pins the registry commit SHA in `.mifune/skills.lock`, so re-installs of the same version are deterministic.

---

## Skill catalog

| Skill | Category | Trigger phrases | Requires |
|-------|----------|-----------------|----------|
| `open-harness-review` | open-harness | "audit the harness", "review harness health", "what should we fix" | `gh`, `git` |
| `docker-sandbox-debug` | dev-workflow | "container won't start", "port already in use", "bind mount empty" | `docker` |
| `github-prd` | dev-workflow | "create a prd", "plan this feature", "requirements for", "spec out" | `gh` |

The canonical index is [`registry.json`](registry.json), with one entry per Mifune-curated skill plus an integrity checksum.

---

## Add a skill

Adding a new skill should take **<10 minutes**.

1. Create the skill folder: `mkdir skills/<name>` (lowercase, hyphens, ≤ 64 chars).
2. Copy the template: `cp template/SKILL.md skills/<name>/SKILL.md` (template is forthcoming; for V0, start from an existing skill's `SKILL.md`).
3. Fill in the frontmatter: set `name`, `description`, `license`, and `metadata.mifune.version`.
4. Write the skill body — imperative instructions the agent follows step by step.
5. Recompute checksums: `scripts/refresh-checksums.sh` (writes back into `registry.json`).
6. Add a `skills[]` entry in `registry.json` with `name`, `path`, `version`, `description`, `category`, `requires-tools`, `clients`, `license`, `added`, `updated`.
7. Validate: `scripts/validate.sh` — must report `PASS` (skills-ref + 5 Mifune rules + checksum integrity).
8. Commit `skills/<name>/` and `registry.json` in the same commit.

See [`docs/checksum.md`](docs/checksum.md) for the checksum algorithm and [`docs/portability.md`](docs/portability.md) for the frontmatter deny-list (stricter than the upstream spec).

---

## Layout

| Path | Purpose |
|------|---------|
| `registry.json` | Hand-written V0 seed index of Mifune-curated skills (name, version, checksum per entry) |
| `skills/<name>/` | One subfolder per Mifune-curated skill (`SKILL.md` + optional `scripts/`, `references/`, `assets/`, per-skill `LICENSE`) |
| `scripts/install.sh` | Bash installer — `curl \| bash` entry point; defaults to `master` branch, overridable via `MIFUNE_REGISTRY_BRANCH` |
| `scripts/validate.sh` | CI gatekeeper — 19 checks (skills-ref, JSON, registry parity, line count, deny-list, checksum integrity) |
| `scripts/refresh-checksums.sh` | V0 manual workflow to refresh checksums when a skill file changes |
| `scripts/test-install.sh` | Hermetic test harness for `install.sh` (6 scenarios) |
| `docs/` | Algorithm + portability documentation |
| `template/` | Boilerplate for `mifune skills new <name>` (V1) |
| `.claude-plugin/` | Reserved for V1 `marketplace.json` |

---

## Licensing

This repository is licensed under [MIT](LICENSE) at the root.

Each Mifune-curated skill under `skills/<name>/` carries its own [MIT](https://opensource.org/licenses/MIT) `LICENSE` file as a per-skill override. Per-skill license overrides are an explicit affordance of the Agent Skills specification.

---

## Roadmap

- **V0 (this release)**: 3 seed skills, hand-written `registry.json`, Bash installer, validator, CI.
- **V1**: TypeScript CLI (`@mifune/skills-cli`), npm + GHCR distribution, `.claude-plugin/marketplace.json` generator, `skills.mifune.dev` static site.
- **V2**: Sigstore signing, Open Harness `oh skills` wrapper, standalone binary.
- **V3**: Community contributions, federated registries.

Full design and milestone acceptance criteria: [ryaneggz/open-harness PR #306](https://github.com/ryaneggz/open-harness/pull/306).

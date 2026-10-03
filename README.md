<div align="center">

<table align="center">
  <tr>
    <td style="padding: 0; vertical-align: middle;">
      <img
        src="https://avatars.githubusercontent.com/u/139279732?v=4"
        width="60"
        height="60"
        style="border-radius: 50%; display: block;"
        alt="Mifune Logo"
      />
    </td>
    <td style="padding: 0 0 0 12px; vertical-align: middle;">
      <span style="font-weight: 600; font-style: italic; font-size: 2.4rem; line-height: 1;">
        SKILLS
      </span>
    </td>
  </tr>
</table>

A portable, cross-agent skill library for [Claude Code](https://claude.ai/code) and compatible AI agents.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Skills](https://img.shields.io/badge/skills-11-brightgreen)](registry.json)

</div>

Each skill is a plain folder with a `SKILL.md` — drop it into your project and the agent starts using it immediately. No daemon, no runtime, no build step.

---

## 🚀 Install

```bash
curl -fsSL https://raw.githubusercontent.com/mifunedev/skills/master/scripts/install.sh | bash -s -- install <skill-name> --scope project
```

| Flag | Default | Purpose |
|------|---------|---------|
| `--scope project` | `project` | Install into the current git repo |
| `--client agents\|claude\|harness` | `agents` | Target destination (`.agents/skills/`, `.claude/skills/`, or both) |

The installer pins the registry commit SHA in `.mifune/skills.lock` — re-installs of the same version are deterministic.

---

## 📦 Skill Catalog

11 skills across 4 categories:

| Skill | Category | Description |
|-------|----------|-------------|
| [`agent-browser`](skills/agent-browser) | dev-workflow | Open a URL in the headless browser with preflight health check |
| [`ci-status`](skills/ci-status) | dev-workflow | Poll CI after push; reports pass/fail with failure details |
| [`prd`](skills/prd) | dev-workflow | Generate a Product Requirements Document for a new feature |
| [`release`](skills/release) | dev-workflow | Cut a CalVer release: version, tag, push, CI poll, verify image |
| [`ste`](skills/ste) | dev-workflow | Write technical prose in Simplified Technical English, with a deterministic checker |
| [`worktrees`](skills/worktrees) | dev-workflow | Manage `.worktrees/` lifecycle: create, list, remove, clean, audit |
| [`delegate`](skills/delegate) | orchestration | Parallel execution coordinator — decomposes plans into wave-executed sub-agents |
| [`system-one`](skills/system-one) | integration | Typed choice, yes/no, and score judgments from System One: Jev by default, self-hosted Laya as the alternative |
| [`post-bridge`](skills/post-bridge) | integration | Publish posts, upload media, and schedule content via the Post Bridge API |
| [`agro-host-matrix`](skills/agro-host-matrix) | agro | Validate AGRO on real VMs (Vercel Sandbox, exe.dev, agro-console) with a reproducible 15-row matrix |
| [`interview`](skills/interview) | agro | Adaptive pre-work clarifier — batches 2–4 task-specific questions, then proceeds |

The canonical index — versions, checksums, and `requires-tools` per skill — is [`registry.json`](registry.json).

---

## ➕ Add a Skill

Adding a new skill takes **under 10 minutes**.

1. **Create the folder** — `mkdir skills/<name>` (lowercase, hyphens, ≤ 64 chars)
2. **Write the skill** — start from an existing `SKILL.md`; fill in `name`, `description`, and the imperative instruction body
3. **Add a license** — copy the root `LICENSE` into `skills/<name>/LICENSE`
4. **Recompute checksums** — `./scripts/refresh-checksums.sh`
5. **Register the skill** — add an entry to `registry.json` with `name`, `path`, `version`, `description`, `category`, `requires-tools`, `clients`, `license`, `added`, `updated`
6. **Validate** — `./scripts/validate.sh` must report `PASS`
7. **Commit** — `skills/<name>/` and `registry.json` in the same commit

Checksum algorithm: [`docs/checksum.md`](docs/checksum.md). Portability rules (Claude Code-specific keys go under `metadata.mifune.claude-code.*`): [`docs/portability.md`](docs/portability.md).

---

## 📁 Layout

| Path | Purpose |
|------|---------|
| `registry.json` | Canonical index — one entry per skill with version, checksum, and category |
| `skills/<name>/` | One subfolder per skill (`SKILL.md` + per-skill `LICENSE`) |
| `scripts/install.sh` | Bash installer — `curl \| bash` entry point |
| `scripts/validate.sh` | CI gatekeeper — 19 checks: schema, registry parity, checksum integrity |
| `scripts/refresh-checksums.sh` | Recompute and write checksums back into `registry.json` |
| `scripts/test-install.sh` | Hermetic test harness for `install.sh` (6 scenarios) |
| `docs/` | Checksum algorithm, portability policy, schema |
| `template/` | Skill boilerplate for `mifune skills new <name>` (V1) |

---

## 🗺️ Roadmap

| Version | Status | Highlights |
|---------|--------|------------|
| **V0** | ✅ Current | 11 skills, hand-written `registry.json`, Bash installer, CI validator |
| **V1** | 🔵 Planned | TypeScript CLI (`@mifune/skills-cli`), npm + GHCR distribution, `skills.mifune.dev` catalog |
| **V2** | 🔵 Planned | Sigstore signing, `oh skills` wrapper, standalone binary |
| **V3** | 🔵 Planned | Community contributions, federated registries |

Full design notes: [ryaneggz/open-harness PR #306](https://github.com/ryaneggz/open-harness/pull/306).

---

## ⚖️ License

This repository is licensed under [MIT](LICENSE).

Each skill in `skills/<name>/` carries its own [MIT](https://opensource.org/licenses/MIT) `LICENSE` file as a per-skill override — an explicit affordance of the Agent Skills specification.

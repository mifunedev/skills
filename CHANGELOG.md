# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions use CalVer (`YYYY.M.D` with `-N` suffix for same-day releases) and match git tags.

## [Unreleased]

### Added
- `reflect` skill (`skills/reflect/`) — deliberate whole-session "Improve" pass that operationalizes the Memory Improvement Protocol: scans the current conversation for durable behavioral patterns, applies the qualify filter, classifies survivors by memory tier, and proposes `MEMORY.md` / `IDENTITY.md` additions for explicit confirmation before writing (log-tier entry always appended). Manual-trigger, current-session scope, propose-then-confirm. Indexed in `registry.json` (`open-harness` category).
- `context-audit` skill (`skills/context-audit/`) — data-backed, repeatable eval for the default-loaded context budget. Tier-1 scores each file on 4 dimensions (footprint, load-bearing, integrity, redundancy) and emits KEEP/TRIM/DEMOTE/CUT verdicts. Tier-2 ablation harness (`runner.sh` + 7 probe files) removes a target file, runs a fixed task suite via `claude -p`, and measures behavior degradation.
- 13 Mifune-curated skills synced from upstream harness `.claude/skills/`: `agent-browser`, `ci-status`, `delegate`, `harness-audit`, `harness-context`, `post-bridge`, `prd`, `ralph`, `release`, `ship-spec`, `skill-lint`, `strategic-proposal`, `worktrees`.
- Per-skill `LICENSE` (MIT) file in each new skill directory.

### Changed
- `registry.json`: replaced `skills[]` array (3 placeholder entries → 13 current entries, alphabetical), set `license: "MIT"` on every entry, bumped top-level `version` to `2026.5.17`, refreshed all checksums via `scripts/refresh-checksums.sh`.
- `README.md`: per-skill license callout fixed from Apache-2.0 to MIT (matches root LICENSE).
- `registry.json` `_v0_note`: removed sentence about the now-deleted `rlm/` directory.

### Removed
- `rlm/` guest-skill directory (out of scope for Mifune V0 curation).
- Placeholder skills `docker-sandbox-debug/`, `github-prd/`, `open-harness-review/` (superseded by the upstream-sync set above).

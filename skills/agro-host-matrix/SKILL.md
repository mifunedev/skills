---
name: agro-host-matrix
description: |
  Validate mifunedev/agro expectations on real hosting environments and run
  the AGRO hosting-substrate matrix reproducibly: provision a VM on Vercel
  Sandbox, exe.dev, or an agro-console node, run 15 AGRO operation
  rows (cgroup delegation, sandbox boot under systemd, restarts, disconnect
  survival, SSH, HTTPS, egress TLS, Hermes install, time to shell), record
  one RESULT line per row, and remove every VM it creates. Knows why each
  provider, row, and probe exists, the 2026-10 baseline, and how to label a
  failure as a provider limit or an AGRO assumption. TRIGGER when: asked to
  validate an AGRO release, candidate build, or fix on real VMs, check AGRO
  for regressions, evaluate where AGRO can run, compare VM providers,
  re-run or extend the hosting matrix, test a new AGRO release on real VMs,
  measure agro-console provisioning time, or check a provider for systemd-in-
  Docker support.
license: MIT
compatibility: Needs bash, ssh, curl, jq, awk, and tmux on the driver host, plus an account on each provider under test (vercel CLI, an exe.dev SSH key, or a local agro-console stack).
metadata:
  mifune:
    category: open-harness
    requires-tools: ["bash", "ssh", "curl", "jq", "awk", "tmux"]
---

# AGRO hosting-substrate matrix

The matrix answers one question for each hosting environment: which AGRO operations hold here? Rows are AGRO operations. Columns are providers and modes.

Use the matrix for three jobs:

1. **Validate AGRO.** Run a release, a candidate build, or a fix on each environment, and compare the result with the baseline. A new `FAIL` is a regression in AGRO or a change in the environment.
2. **Qualify an environment.** Decide whether a new provider can host AGRO, and in which mode.
3. **Compare products.** Measure time to shell and supported operations for agro-console against other providers. Read `references/rationale.md` before you change a row, a provider, or a design rule. That file states why each one exists.

## Non-negotiable rules

1. Get operator approval before you start a run. A run creates a VM on a third-party host and can cost money.
2. Run every driver in a named tmux session. A run lasts up to 40 minutes, and a closed terminal must not stop the run.
3. Send no GitHub token, Slack token, API token, or `.env` file into a provider VM.
4. Confirm the cleanup. Each log ends with `remaining agro-matrix resources on <provider>: 0` and `RUN DONE`. If the count is not 0, sweep by hand with `references/providers.md`.
5. Copy every result from a log. Never write a predicted result into the matrix.

## Set up

1. Copy the `scripts/` directory to the driver host, or run the scripts from this skill directory.
2. Set `MATRIX_OUT` to the evidence directory. The default is `./matrix-evidence`.
3. Set up each provider with `references/providers.md`.
4. Run the preflight for each provider:

   ```bash
   bash scripts/run.sh vercel --preflight
   bash scripts/run.sh exedev --preflight
   bash scripts/run.sh console --preflight
   ```

   Each command prints `preflight ok: <provider>` and exits 0.

## Run the matrix

Run the probes in this sequence. A failed probe makes the later steps on that provider unnecessary.

1. Run the cgroup probe on a new provider:

   ```bash
   tmux new-session -d -s agro-mx-probe "bash scripts/run.sh exedev cg-probe.sh"
   ```

   The log shows `memory ok` and `io ok` when the provider delegates the controllers. `memory FAIL` means that the AGRO sandbox cannot run there. Label the column `provider-limit` and stop.

2. Run the rows in host mode:

   ```bash
   tmux new-session -d -s agro-mx-rows "bash scripts/run.sh exedev rows.sh"
   ```

3. On exe.dev, run the rows in image mode. The VM boots the AGRO image, and no container runs:

   ```bash
   tmux new-session -d -s agro-mx-image "IMAGE=ghcr.io/mifunedev/agro:<version> bash scripts/run.sh exedev rows.sh"
   ```

4. On exe.dev, run the two restart scenarios for `R08`:

   ```bash
   tmux new-session -d -s agro-mx-rs-sync "IMAGE=ghcr.io/mifunedev/agro:<version> bash scripts/restart-test.sh sync"
   tmux new-session -d -s agro-mx-rs-settled "IMAGE=ghcr.io/mifunedev/agro:<version> bash scripts/restart-test.sh settled"
   ```

5. Wait for `RUN DONE` in each log. Do not poll in a loop from an agent turn. Use one wait command per log:

   ```bash
   until grep -q "RUN DONE" "$MATRIX_OUT"/<log>; do sleep 15; done
   ```

6. Build the matrix table from all logs:

   ```bash
   bash scripts/summarize.sh "$MATRIX_OUT"
   ```

Runs on different providers are independent. You can start the runs in parallel. Keep each provider at one run at a time, because some plans cap concurrent VMs.

## Select the AGRO build under test

By default, `rows.sh` installs the latest release with `https://agro.mifune.dev/get-agro.sh`, and `agro sandbox install` pulls the image that matches the CLI. To validate another build, set these variables before `run.sh`. The driver forwards each variable into the VM and writes the build into the log.

| Variable | Effect |
|---|---|
| `GET_AGRO_URL` | URL of the `get-agro.sh` under test, for example a release asset or a raw file from a branch. |
| `AGRO_JS_URL` | URL of the `agro.js` bundle that `get-agro.sh` installs. |
| `SANDBOX_IMAGE` | Image reference for `agro sandbox install docker --image=<ref>`. |
| `IMAGE` | exe.dev only: the image that the VM boots. An AGRO image gives image mode. |

Example: validate a candidate installer from a branch on exe.dev.

```bash
GET_AGRO_URL=https://raw.githubusercontent.com/mifunedev/agro/<branch>/.agro/scripts/get-agro.sh \
  tmux new-session -d -s agro-mx-candidate "bash scripts/run.sh exedev rows.sh"
```

## Rows

| Row | Runs in | Checks |
|---|---|---|
| `R13-time-to-shell` | driver timestamps | seconds from `create` to the first `exec` |
| `R04-cgroup-delegation` | `rows.sh` | `+memory +io` delegation |
| `R02-workspace` | `rows.sh` host mode | `get-agro.sh`, then `agro workspace create` |
| `R02b-noninteractive-cli` | `rows.sh` host mode | `agro --version` in a non-interactive shell |
| `R03-docker-engine-host` | `rows.sh` host mode | `agro tool install docker-engine --host` |
| `R01-docker` | `rows.sh` host mode | `dockerd` and `docker compose` |
| `R05-sandbox-boot` | `rows.sh` | the sandbox reaches `healthy` |
| `R06-systemd` | `rows.sh` | PID 1, `agro-cron`, `agro-bootstrap` |
| `R07-container-restart` | `rows.sh` host mode | `agro-cron` after `docker restart` |
| `R08-vm-restart` | `restart-test.sh` | health and file content after a VM restart |
| `R09-disconnect` | `driver_rows` | a tmux session survives the client exit |
| `R10-ssh-inbound` | `driver_rows` | a standard SSH client reaches the VM |
| `R11-https-port` | `driver_rows` | an HTTPS client reaches a port |
| `R12-egress-tls` | `rows.sh` | `git ls-remote` over HTTPS inside the sandbox |
| `R14-hermes-install` | `rows.sh` | `agro harness install hermes` and the Hermes smoke |

`rows.sh` uses host mode on a plain VM and image mode on a VM that booted the AGRO image. `references/rationale.md` gives the expectation and the meaning of a failure for each row.

## Read the results

1. Compare each cell with the baseline table in `references/rationale.md`. A changed cell is drift. Find the cause before you report the cell.
2. Label each `FAIL` cell: `provider-limit`, `agro-assumption`, or `both`.
3. Record each `agro-assumption` in a change register with the question, the evidence log, and the provider. Mark an entry `supported` only when evidence from at least two providers supports the entry.
4. Report the timings from the `TIMING` lines: `create_return_s`, `first_shell_s`, `healthy_s`, and `restart_to_settled_s`.

## Scripts

| Script | Use |
|---|---|
| `scripts/lib.sh` | Provider adapters (`preflight`, `create`, `exec`, `destroy`, `list`, `restart`), the detached-run-and-poll driver, `driver_rows`, and `finish`. Sourced, not run. |
| `scripts/run.sh` | Entry point: `run.sh <vercel|exedev|console> <rows.sh|cg-probe.sh|--preflight>`. |
| `scripts/rows.sh` | In-VM row checks. The driver uploads and runs the script. |
| `scripts/cg-probe.sh` | In-VM cgroup and systemd-container probe. |
| `scripts/restart-test.sh` | exe.dev restart scenarios `sync` and `settled`. |
| `scripts/summarize.sh` | Builds a Markdown matrix from the logs in `MATRIX_OUT`. |

To add a provider, follow "Add a provider" in `references/providers.md`.

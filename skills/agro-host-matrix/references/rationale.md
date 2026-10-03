# Rationale: why each provider, row, probe, and design rule exists

## Contents

1. [The question the matrix answers](#the-question-the-matrix-answers)
2. [Why these providers](#why-these-providers)
3. [Why each row](#why-each-row)
4. [Why each probe and scenario](#why-each-probe-and-scenario)
5. [Why the driver works this way](#why-the-driver-works-this-way)
6. [Failure labels and the change register](#failure-labels-and-the-change-register)
7. [Baseline results, 2026-09-30 to 2026-10-01](#baseline-results-2026-09-30-to-2026-10-01)
8. [Known failure modes of the harness itself](#known-failure-modes-of-the-harness-itself)

## The question the matrix answers

AGRO turns a host into a durable workspace for coding agents. The AGRO sandbox is a container with systemd as PID 1. The sandbox needs `cgroup: private`, `SYS_ADMIN`, `apparmor=unconfined`, and a tmpfs on `/sys/fs`. Agents keep working after the operator disconnects.

The matrix asks one question for each hosting environment: which AGRO operations hold in this environment? The rows are AGRO operations, not provider features. A provider feature list tells you what a provider sells. The rows tell you whether AGRO works there.

The same rows serve three jobs. First, the rows validate AGRO itself. A release, a candidate build, or a fix runs on each environment. A new `FAIL` against the baseline is a regression. Second, the rows qualify a new environment. Third, the rows compare agro-console with other providers. The baseline run found three AGRO defects (`C8`, `C9`, `C10`), so the matrix is a test of AGRO first and a market comparison second.

## Why these providers

Each provider stands for one category. Add a provider only when the provider represents a category that the matrix does not hold, or when the provider is a direct competitor.

| Provider | Category | Why the matrix holds it |
|---|---|---|
| Vercel Sandbox | Ephemeral execution sandbox | The free Hobby tier renews each month. The provider documents Docker inside the microVM. The provider is the reference case for the category. Creation is fast, the init is custom, the provider keeps the cgroup controllers, and Hobby sessions stop at 45 minutes. |
| exe.dev | Persistent VM | Real KVM VMs on Cloud Hypervisor with root, systemd, and a persistent disk. A VM boots from any OCI image in about 2 seconds. The provider is the direct competitor to a dedicated-node product. The provider also tests a third mode: the AGRO image booted as the VM, with no container. |
| agro-console `n4` | Dedicated OVH VM | The product baseline. The console provisions a 2 vCPU, 4 GB OVH VM in host mode through its API. Every competitor number needs this baseline. |

Providers that the matrix reviewed from documentation only: E2B, Daytona, Fly.io Sprites, CodeSandbox, Docker Cloud Sandboxes, boxd. Docker Cloud Sandboxes repeats the Vercel category. The persistent-VM question has an answer from exe.dev.

## Why each row

| Row | AGRO expectation | A failure means |
|---|---|---|
| `R13-time-to-shell` | An operator gets a shell fast. | The substrate loses on first-session speed. The driver measures seconds from the `create` request to the first successful `exec`. |
| `R04-cgroup-delegation` | The host delegates the `memory` and `io` cgroup controllers. | systemd cannot run as PID 1 in a container. runc puts the container cgroup in `threaded` mode, and systemd exits with `Structure needs cleaning`. Every sandbox row then fails. |
| `R02-workspace` | `get-agro.sh` installs the CLI, and `agro workspace create` clones a workspace. | The documented host install path is broken. |
| `R02b-noninteractive-cli` | `agro --version` succeeds in a non-interactive shell after the install. | Cron, systemd units, cloud-init, and `ssh host cmd` cannot run `agro`. mifunedev/agro#1262 fixed this case for nvm installs. |
| `R03-docker-engine-host` | `agro tool install docker-engine --host` installs Docker. | The documented Docker path is broken on that base image. |
| `R01-docker` | `dockerd` runs and `docker compose` is present. | The host cannot run the sandbox container. |
| `R05-sandbox-boot` | `agro sandbox install docker --yes` reaches `healthy`. In image mode, `agro-bootstrap` is active and the healthcheck passes. | The core AGRO product does not start. |
| `R06-systemd` | PID 1 is `systemd`. The `agro-cron` unit runs. The `agro-bootstrap` unit reports `success`. | Unattended schedules do not run. |
| `R07-container-restart` | `agro-cron` is active again after `docker restart`. | A container restart loses the unattended runtime. |
| `R08-vm-restart` | The sandbox is healthy again after a VM restart, and files keep their content. | A host reboot loses work or corrupts state. |
| `R09-disconnect` | A tmux session survives the client exit. | Work dies with the terminal. This breaks the AGRO rule that remote and unattended operation is normal. |
| `R10-ssh-inbound` | A standard SSH client outside the provider reaches the VM. | `agro shell`, editors, and remote operators cannot attach. |
| `R11-https-port` | An HTTPS client outside the provider reaches a port on the VM. | Previews and code-server need a tunnel. |
| `R12-egress-tls` | `git ls-remote https://github.com/mifunedev/agro.git HEAD` succeeds inside the sandbox. | An egress proxy breaks TLS for containers. Vercel documents that containers do not inherit the proxy CA. |
| `R14-hermes-install` | `agro harness install hermes` and `hermes-install-smoke.sh` succeed. | A harness install path fails on that substrate. The smoke requires a sandbox name that starts with `oh-hermes-` and no Docker socket in the sandbox. |

`rows.sh` detects one of two modes:

- **host mode:** the VM is a plain host. The script installs AGRO and runs the sandbox container.
- **image mode:** the VM booted the AGRO image. `/opt/agro-seed` exists, PID 1 is systemd, and the `agro-bootstrap` unit exists. The script skips the host rows and checks the VM itself.

## Why each probe and scenario

| Script | Why |
|---|---|
| `cg-probe.sh` | The cheapest test that decides whether a provider can host the AGRO sandbox at all. The probe installs Docker, tries to enable each controller, and starts a plain `jrei/systemd-ubuntu:24.04` container. A failure with a plain image proves that the cause is the substrate, not AGRO. Run the probe first on a new provider. |
| `rows.sh` | The full set of in-VM rows, one `RESULT` line each. Each row runs when an earlier row fails, so one run gives the whole column. |
| `restart-test.sh sync` | Restarts an exe.dev VM after `sync`. This run separates a hard reset by the provider from a defect in AGRO. |
| `restart-test.sh settled` | Restarts an exe.dev VM 300 seconds after the sandbox is healthy. This run shows the normal case. |
| `driver_rows` in `lib.sh` | `R09`, `R10`, and `R11` need a second client connection from outside the VM, so the driver runs them, not `rows.sh`. |

## Why the driver works this way

| Rule | Reason |
|---|---|
| The check runs detached inside the VM, and the driver polls `/tmp/check.log` with `exec` calls of 2 minutes or less. | The first Vercel run used one long `exec` stream. The stream ended after about 6 minutes with `Stream ended before command finished`, and the run lost the remaining steps. |
| The driver writes straight to the log file and ignores `SIGHUP`. | An earlier driver piped its output through `tee`. When the tmux session closed, the `tee` process died first. The next cleanup write killed the shell, and the VM stayed. A closed terminal must not stop a run. |
| `finish` removes the VM on exit, on `SIGINT`, and on `SIGTERM`. After the removal, `finish` counts the tagged resources that remain. | A leftover VM spends quota and money. The count line proves the cleanup in the log. |
| Every resource carries the tag `agro-matrix` or the name prefix `agro-mx-`. | The cleanup count and a manual sweep can find every resource that the matrix created. They never touch other VMs. |
| No GitHub token, Slack token, or `.env` file goes into a provider VM. | Provider VMs are third-party hosts. The console adapter reads `PROVISION_KEY` inside a subshell and never prints the key. |
| Timing uses `date` and `awk`. | `bc` is absent from some hosts, and `python3` is absent from the AGRO image. |
| Run the driver in a named tmux session. | A run lasts up to 40 minutes. The run must survive a disconnect of the operator. |

## Failure labels and the change register

Label each `FAIL` cell with one label:

- `provider-limit`: AGRO is correct, and the provider does not fit.
- `agro-assumption`: AGRO depends on something that the objective does not need.
- `both`: the restriction is common across providers, so a change to AGRO is worth the cost.

Record each `agro-assumption` in a change register with a question and the evidence. An entry becomes `supported` only when evidence from at least two providers supports the entry. A change to AGRO starts only from a `supported` entry.

## Baseline results, 2026-09-30 to 2026-10-01

Compare a new run against these values. A difference is drift in a provider, in AGRO, or in the matrix.

| Row | Vercel host | exe.dev container | exe.dev image VM | console `n4` (agro 0.16.0) |
|---|---|---|---|---|
| `R13-time-to-shell` | 2.4 s | 2.1 s | 2.0 s | 80 s |
| `R04-cgroup-delegation` | FAIL `provider-limit` | PASS | PASS | PASS |
| `R02-workspace` | PASS | PASS | SKIPPED | PASS |
| `R02b-noninteractive-cli` | PASS | FAIL (fixed by mifunedev/agro#1263) | SKIPPED | FAIL (fixed by mifunedev/agro#1263) |
| `R03-docker-engine-host` | PASS | SKIPPED | SKIPPED | PASS |
| `R01-docker` | PASS | PASS | SKIPPED | PASS |
| `R05-sandbox-boot` | FAIL | PASS 22 s | PASS | PASS 75 s |
| `R06-systemd` | FAIL | PASS | PASS | PASS |
| `R07-container-restart` | FAIL | PASS 4 s | SKIPPED | PASS 4 s |
| `R08-vm-restart` | not run | not run | PASS 5.6 s to 8.1 s | not run |
| `R09-disconnect` | PASS | PASS | PASS | not run |
| `R10-ssh-inbound` | FAIL `provider-limit` | PASS | PASS | PASS |
| `R11-https-port` | SKIPPED | SKIPPED, HTTP 307 | SKIPPED, HTTP 307 | not run |
| `R12-egress-tls` | FAIL | PASS | PASS | PASS |
| `R14-hermes-install` | FAIL | PASS | FAIL `agro-assumption` | PASS, install exit 1 |

AGRO findings from the baseline:

| ID | Finding | Status on 2026-10-03 |
|---|---|---|
| `C8` | `entrypoint.sh` copies the seed with `cp -a` and writes the `.image-seeded` marker with no `sync`. A hard reset in the first seconds after the first boot left `agro.json`, `package.json`, and `pnpm-lock.yaml` at 0 bytes. | open |
| `C9` | nvm Node made `agro` fail in non-interactive shells. | fixed in mifunedev/agro#1263 |
| `C10` | The image booted as a VM has no `/.dockerenv` and no Dockerfile `ENV`. `agro harness install hermes` refuses, then fails with `HERMES_HOME is unset`. | open |

## Known failure modes of the harness itself

| Symptom | Cause | Action |
|---|---|---|
| `Stream ended before command finished` | A long `exec` stream on Vercel. | Keep each `exec` under 2 minutes. `run.sh` already does. |
| A VM remains after the tmux session closed. | A driver version that piped output through `tee`. | Use the current `run.sh`. Remove the VM with the provider CLI. |
| The log shows `boot=success` before the bootstrap ran. | systemd reports the default value `Result=success` for a unit before the first run. | Check `systemctl is-active agro-bootstrap` together with the result. |
| The marker file is missing after an exe.dev restart. | `ssh exe.dev restart` is a hard reset. ext4 runs journal recovery, and writes from the last seconds can vanish. | Call `sync` before the restart, or wait 30 seconds. |

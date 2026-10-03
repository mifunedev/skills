# Provider setup, cost, and cleanup

## Contents

1. [Vercel Sandbox](#vercel-sandbox)
2. [exe.dev](#exedev)
3. [agro-console node](#agro-console-node)
4. [Add a provider](#add-a-provider)

## Vercel Sandbox

Prerequisites:

1. Install the `vercel` CLI.
2. Run `vercel login`.
3. Set `VERCEL_SCOPE` to the team slug, for example `export VERCEL_SCOPE=mifunedev`.
4. Run `bash scripts/run.sh vercel --preflight`. The command prints `preflight ok: vercel`.

The adapter creates a sandbox with 2 vCPU and 4 GB, a 42-minute timeout, `--non-persistent`, and the tag `purpose=agro-matrix`.

The Hobby plan gives 5 active CPU-hours and 420 GB-hours of memory each month. The plan allows 10 concurrent sandboxes and 45 minutes for each session. Vercel charges nothing on Hobby. When the quota runs out, Vercel pauses sandbox creation.

Manual sweep:

```bash
vercel sandbox list --scope "$VERCEL_SCOPE" | grep purpose=agro-matrix
vercel sandbox remove <name> --scope "$VERCEL_SCOPE"
```

## exe.dev

Prerequisites:

1. Register an SSH public key of the driver host with the exe.dev account. The command `ssh exe.dev` asks for the account email and registers the key. A host with access can also run `ssh exe.dev ssh-key add "<public key>"`.
2. Run `bash scripts/run.sh exedev --preflight`. The command prints `preflight ok: exedev`.

The adapter manages VMs through the exe.dev SSH command API: `new --json`, `ls --json`, `rm`, and `restart`. The adapter runs commands on a VM with `ssh <name>.exe.xyz`. An API token is not necessary. Do not paste an API token into a chat or a log.

Set `IMAGE=<oci-ref>` to boot a VM from an image. `IMAGE=ghcr.io/mifunedev/agro:<version>` gives the image mode of `rows.sh`.

Cost: exe.dev bills a monthly pool of CPU, memory, and disk, not each VM. A VM has no stop command and uses the pool until `rm`.

Manual sweep:

```bash
ssh exe.dev ls --json | jq -r '.vms[] | select((.tags // []) | index("agro-matrix")) | .vm_name'
ssh exe.dev rm <name>
```

## agro-console node

Prerequisites:

1. A local agro-console stack: the `web` service on `CONSOLE_URL` (default `http://127.0.0.1:3005`) and the `provisioner` service. The services read the env file only at start. Restart the provisioner after a change to `NODE_AGRO_VERSION`.
2. `CONSOLE_DIR`: the agro-console checkout. The adapter loads `PROVISION_KEY` from the console env file through the env loader and `dotenv` of the agro-console checkout. The adapter never prints the key.
3. `CONSOLE_SSH_KEY`: the private key path. `CONSOLE_SSH_KEY_ID`: the console id of the matching public key. `POST /api/ssh-keys` registers the key and returns the id.
4. Run `bash scripts/run.sh console --preflight`. The command prints `preflight ok: console`.

The adapter creates a node with `CONSOLE_SPEC` (default `n4`) and the name prefix `agro-mx-`. `create` returns after the node reports `running`. The console reports `running` after timed waits, not after a readiness check, so `wait_shell` measures the first real SSH.

Cost: the `n4` spec costs $0.045 for each running hour on OVH.

Manual sweep:

```bash
curl -sS -H "x-provision-key: <key>" "$CONSOLE_URL/api/nodes" | jq -r '.nodes[] | select((.name // "") | startswith("agro-mx-")) | select(.status != "destroyed") | .id'
curl -sS -X DELETE -H "x-provision-key: <key>" "$CONSOLE_URL/api/nodes/<id>"
```

## Add a provider

1. Confirm that the provider represents a category that the matrix does not hold, or that the provider is a direct competitor.
2. Add six functions to `scripts/lib.sh`: `<p>_preflight`, `<p>_create`, `<p>_exec`, `<p>_destroy`, `<p>_list`, and, when the provider supports a restart, `<p>_restart`.
3. Tag or name every resource so that `<p>_list` counts only matrix resources.
4. Add a `case` branch to `driver_rows` for `R10` and `R11`.
5. Add the provider to the `case` statement in `scripts/run.sh`.
6. Run `cg-probe.sh` first. Run `rows.sh` only when the probe shows a delegated `memory` controller or when the host mode rows matter.

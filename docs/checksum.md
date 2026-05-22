# Checksum Algorithm

Every entry in `registry.json` carries a `checksum` field that uniquely identifies the contents of a skill folder at registration time. This document specifies the algorithm so that any tool — CI, the CLI, or a manual audit — can reproduce and verify it.

---

## Algorithm

Run from the **repository root** (the directory containing `registry.json`):

```bash
find skills/<name> -type f -not -path '*/.*' | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -d' ' -f1
```

Replace `<name>` with the skill folder name (e.g. `ci-status`).

### Step-by-step

| Step | Command fragment | Purpose |
|------|-----------------|---------|
| 1 | `find skills/<name> -type f -not -path '*/.*'` | List every non-hidden file in the skill folder recursively |
| 2 | `LC_ALL=C sort` | Sort paths in byte order — locale-independent and reproducible across machines |
| 3 | `xargs sha256sum` | Hash each file individually; output is `<hash>  <path>` per line |
| 4 | `sha256sum` | Hash the concatenated list of `<hash>  <path>` lines (a hash-of-hashes) |
| 5 | `cut -d' ' -f1` | Extract only the hex digest, discard the `-` filename |

The value stored in `registry.json` is prefixed with `sha256:`:

```
"checksum": "sha256:<64-char-hex-digest>"
```

---

## Worked Example

```bash
cd /path/to/mifunedev/skills
find skills/ci-status -type f -not -path '*/.*' | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -d' ' -f1
```

The stored entry in `registry.json`:

```json
"checksum": "sha256:0101319da83519db4950d83de2f18379c6b28fafb1e056d56819524e7f089670"
```

---

## Verification

To confirm a locally installed skill has not drifted from the registry:

```bash
SKILL=ci-status
EXPECTED=$(jq -r '.skills[] | select(.name == "'$SKILL'") | .checksum' registry.json | sed 's/sha256://')
ACTUAL=$(find skills/$SKILL -type f -not -path '*/.*' | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -d' ' -f1)
[ "$ACTUAL" = "$EXPECTED" ] && echo "OK" || echo "DRIFT DETECTED"
```

---

## Updating Checksums After a Skill Change

After editing any file inside a skill folder, run:

```bash
./scripts/refresh-checksums.sh
```

This script walks `skills/*/` using the same algorithm, compares each hash to `registry.json`, updates any that have changed, and prints `OK`, `UPD`, or `SKIP` per skill. Commit `registry.json` after it reports changes.

`scripts/validate.sh` (the CI gatekeeper) uses the identical `compute_checksum` function — both scripts are kept in sync.

---

## V1 Notes

In V1, `scripts/publish-registry.sh` will run this algorithm automatically for every skill folder and write the result into `registry.json`. The CI workflow will then verify the committed file matches the regenerated output, failing the build on drift. For V0, checksums are computed and committed manually.

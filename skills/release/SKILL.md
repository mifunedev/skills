---
name: release
description: |
  Release a validated AGRO commit by pushing it to main or master, then
  monitor the automatic SemVer/GHCR/GitHub Release workflow. TRIGGER when:
  asked to release, version, ship, cut a release, or verify release artifacts.
metadata:
  mifune:
    claude-code:
      argument-hint: "[--dry-run]"
---

# Release

`.github/workflows/release.yml` owns version allocation and artifact mutation.
The workflow validates every push to `main`, `master`, or `experiment/**` first, then reserves the
`v<version>` tag for the version root `package.json` names, publishes GHCR and
the CLI (or confirms the CLI version already exists), and finally publishes the
GitHub Release. Do not pre-create a release tag, draft, or `release/<version>`
branch.

Root `package.json` holds the release version. A release is a deliberate bump:
an unchanged version gives a clean, green no-op run.

## Artifact set

One release produces, from one build and one commit:

- The canonical npm package `@mifune/agro` (the `agro` executable, from the host repository's CLI package).
  The `@mifune/agro` shim source remains in the legacy shim directory of that CLI package, and
  already-published shim versions remain on the registry. The release path does
  not publish, wait for, or deprecate the shim.
- Four immutable GHCR tags: `ghcr.io/mifunedev/agro:<version>`,
  `:sha-<sha>`, `ghcr.io/mifunedev/agro:<version>`, and `:sha-<sha>`, verified to
  share one manifest digest (the host repository's `<release alias verifier>` script), then
  `latest` on both repositories (the host repository's `<release latest promoter>` script).
- Four GitHub Release assets: `agro.js`, `oh.js`, `get-agro.sh`, and `get-agro.sh`,
  attached before the release is undrafted so
  `releases/latest/download/<asset>` resolves on publication.

## Version sites

A release cut bumps the canonical version in two places, and `version-parity.sh`
fails the build when they drift:

1. `package.json` (root).
2. The `package.json` and `package-lock.json` of the CLI package.

The retained shim's `package.json` in the legacy shim directory keeps its own `version` and
an exact `@mifune/agro` pin that equals that shim version. The shim version does
not have to match a later canonical version.

## Operator prerequisites this repository cannot verify

- The npm token has publish rights for the `@mifune` scope, including the
  `@mifune/agro` package name.
- The GHCR package `mifunedev/agro` is set to public after its first push. A new
  GHCR package is private by default, so `agro sandbox install docker` cannot
  pull it until the operator changes the visibility.
- The compatibility SLA clock starts at the first public AGRO release, that is,
  the first release that publishes `@mifune/agro` and `ghcr.io/mifunedev/agro`.

## Pre-releases

A pre-release version has the form `MAJOR.MINOR.PATCH-<channel>.<n>`, for example
`0.15.0-minimal.1`. `<channel>` is lowercase (`[a-z][a-z0-9]*`) and is not `latest`.
`minimal` names the `experiment/minimal-core` track. Reserve `rc` for candidates of
the next `main` release.

| Version form | Branches that publish it | GitHub Release | npm dist-tag | GHCR `latest` |
| --- | --- | --- | --- | --- |
| `0.15.0` | `main`, `master` | latest | `latest` | moves |
| `0.15.0-minimal.1` | `main`, `master`, `experiment/**` | pre-release, never latest | `minimal` | never moves |

A stable version on an `experiment/**` push is a green no-op
(`stable-off-release-branch`), so a stable bump merged from `development` never
publishes from an experiment branch.

To cut a pre-release on an experiment branch:

1. Merge `development` into the branch so its `release.yml` supports pre-releases.
2. Set the version in root `package.json` and in the `package.json` and
   `package-lock.json` of the CLI package.
3. Add a dated `## [<version>] - YYYY-MM-DD` heading to `CHANGELOG.md`.
4. Push the branch. Monitor the run as in step 4, with `--branch <experiment-branch>`.

Install the pre-release:

```bash
npm i -g @mifune/agro@minimal
agro sandbox install docker --version 0.15.0-minimal.1
```

## 1. Resolve the canonical destination

```bash
if git remote get-url upstream >/dev/null 2>&1; then
  REMOTE=upstream
else
  REMOTE=origin
fi
REPO=$(gh repo view "$(git remote get-url "$REMOTE")" --json nameWithOwner -q .nameWithOwner)

if git ls-remote --exit-code --heads "$REMOTE" main >/dev/null 2>&1; then
  TARGET=main
elif git ls-remote --exit-code --heads "$REMOTE" master >/dev/null 2>&1; then
  TARGET=master
else
  echo "No main or master release branch exists on $REMOTE" >&2
  exit 1
fi
SOURCE=$(git branch --show-current)
printf 'Repo: %s · source: %s · release branch: %s\n' "$REPO" "$SOURCE" "$TARGET"
```

## 2. Pre-flight

Require all of the following before a release push:

- The working tree is clean.
- The source commit is pushed to the canonical remote.
- CI for the source commit is green.
- Root `package.json` names the version to publish, the `package.json` of the CLI package
  matches it (the host repository's version-parity contract test passes), and
  no `v<version>` tag exists yet. An unbumped push is a green no-op that publishes
  nothing. A newly published `@mifune/agro` version is not required.
- `CHANGELOG.md` has a `## [<version>]` section matching that version (the
  workflow falls back to `[Unreleased]` when the section is absent).
- The remote release branch is an ancestor of the source commit, so promotion is
  a fast-forward.

```bash
test -z "$(git status --porcelain)" || { echo "Working tree is dirty" >&2; exit 1; }
git fetch "$REMOTE" "$SOURCE" "$TARGET" --tags
VERSION=$(node -p "require('./package.json').version")
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && {
  echo "v$VERSION is already tagged; bump package.json to cut a new release" >&2
  exit 1
}
grep -q "^## \[$VERSION\]" CHANGELOG.md || {
  echo "CHANGELOG.md has no section for $VERSION" >&2
  exit 1
}
SHA=$(git rev-parse "$REMOTE/$SOURCE")
test "$(git rev-parse HEAD)" = "$SHA" || {
  echo "Local $SOURCE is not identical to $REMOTE/$SOURCE" >&2
  exit 1
}
git merge-base --is-ancestor "$REMOTE/$TARGET" "$SHA" || {
  echo "$TARGET has diverged from $SOURCE; reconcile before release" >&2
  exit 1
}
```

If `$ARGUMENTS` contains `--dry-run`, report the resolved repo, source, target,
SHA, clean-tree result, and fast-forward result, then stop without pushing.

## 3. Trigger the release

Promote the exact checked source SHA. The branch push—not a manually created
tag—is the release trigger.

```bash
git push "$REMOTE" "$SHA:refs/heads/$TARGET"
```

The workflow reads the version from root `package.json` on the pushed commit, so
retries always resolve the same version. A retry reuses a same-SHA draft or
published release. When the tag already exists on a different commit, the reserve
step reports the version as already released and every publication job skips —
the run stays green. Bump the version to publish again.

## 4. Monitor and verify

Find the `release.yml` push run for `$SHA` and `$TARGET`, then watch it:

```bash
gh run list --repo "$REPO" --workflow release.yml --branch "$TARGET" \
  --commit "$SHA" --event push --limit 5 \
  --json databaseId,headSha,status,conclusion,url
# Once the matching run appears:
gh run watch <run-id> --repo "$REPO" --exit-status
```

After success, fetch tags and identify the SemVer tag pointing to the exact SHA,
then verify the four immutable image tags, the canonical npm package, the release
assets, and the GitHub Release. The tag carries the `v` prefix; the image tags
do not. A newly published `@mifune/agro` version is not a release gate.

Replace `<release alias verifier>` with the host repository's script that checks
that the image tags share one manifest digest.

```bash
git fetch "$REMOTE" --tags
TAG=$(git tag --points-at "$SHA" \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V | tail -1)
test -n "$TAG" || { echo "No SemVer tag found for $SHA" >&2; exit 1; }
gh release view "$TAG" --repo "$REPO" --json assets -q '.assets[].name'
<release alias verifier> check \
  "ghcr.io/mifunedev/agro:${TAG#v}" "ghcr.io/mifunedev/agro:${TAG#v}"
npm view "@mifune/agro@${TAG#v}" version
printf 'Images: ghcr.io/mifunedev/{agro,agro}:%s and :sha-%s\n' "${TAG#v}" "$SHA"
```

The asset list must name `agro.js`, `oh.js`, `get-agro.sh`, and `get-agro.sh`.

The canonical mutable/latest branch is `main` when it exists, otherwise
`master`. Immediately before promotion, the workflow freshly reads both remote
refs and promotes the canonical head's versioned image to `latest` by immutable
digest. Stale canonical runs and every noncanonical-branch run skip `latest`;
GitHub's `make_latest` flag uses the same rule after a second fresh check.

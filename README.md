# SFDCDeploy — Salesforce CI/CD

GitHub Actions + Salesforce CLI pipeline that validates and deploys metadata
per branch/org pair, with a delta-only deploy strategy and per-branch
configurable checks.

## Branch → org map

| Branch    | Org (GitHub Environment) | Test level        |
|-----------|---------------------------|--------------------|
| `dev`     | `qa`                       | RunSpecifiedTests |
| `staging` | `uat`                      | RunSpecifiedTests |
| `master`  | `production`               | RunLocalTests     |

Feature branches PR into `dev`. Promote via `dev` → `staging` → `master` PRs.

## One-time setup

### 1. Create the GitHub Environments

In repo Settings → Environments, create `qa`, `uat`, and `production`. Each
needs a secret named `SFDX_AUTH_URL`. Optionally add required reviewers on
`production` for a manual approval gate before every prod deploy.

### 2. Generate each org's auth URL

Locally, per org:

```
sf org login web -r https://test.salesforce.com -a qa-org   # or login.salesforce.com for production
sf org display --verbose --json -o qa-org
```

Copy the `sfdxAuthUrl` field from the output into the matching GitHub
Environment's `SFDX_AUTH_URL` secret. This is a refresh token — if a sandbox
is later refreshed, its auth URL is invalidated and needs regenerating.

### 3. Set branch protection

On `dev`, `staging`, and `master`: require the `pr-gate` status check to
pass before merging, and require a PR (no direct pushes). `pr-gate` is the
only check you ever need to name in branch protection — see below.

## How the per-branch check toggles work

`.github/ci-config.json` maps each branch to its org, test level, and which
checks run:

```json
{
  "sourceDir": "force-app",
  "dev": {
    "org": "qa",
    "testLevel": "RunSpecifiedTests",
    "checks": {
      "staticAnalysis": {
        "enabled": true,
        "inlineComments": {
          "enabled": true,
          "minSeverity": "medium"
        }
      },
      "secretScan": true,
      "flowTests": true,
      "apexValidation": true
    }
  }
}
```

`staticAnalysis` is the one check with sub-options rather than a plain
boolean: `enabled` is the master toggle for the whole check (same as the
other booleans), and `inlineComments` separately controls whether
violations get posted as PR review comments on their specific line, not
just the summary. `inlineComments.minSeverity` is one of `critical`,
`high`, `medium`, `low`, `info` — it's a floor, not an exact match:
`"medium"` comments on medium/high/critical, `"critical"` comments on
critical only. Independent of both, the check still fails the PR on any
critical/high violation in changed files, regardless of whether
`inlineComments` is on.

`sourceDir` is repo-wide (top-level, not per-branch) — it's the path both
`validate.yml` and `deploy.yml` check for relevant changes before doing any
of the expensive CLI/plugin install work, and defaults to `force-app` if
omitted. Change it if your SFDX package directory uses a different name.
Note this can't be a hard trigger filter: GitHub's native `on: paths:` is
evaluated statically before any job runs and can't read a config file, so
instead the `delta` job does a cheap `git diff --quiet` check against
`sourceDir` as its first real step and skips everything after it (CLI
installs, delta generation, deploy) when there's nothing relevant - the
workflow still starts, but exits in a few seconds rather than ~30s+.

Flip a check to `false` (or `staticAnalysis.enabled` to `false`) for a given
branch and its job is skipped on the next PR — no workflow-file edits
needed. This works because `pr-gate` (the only
required status check) treats a skipped job as passing and only fails if an
*executed* job failed. Individual check jobs are therefore never named
directly in branch protection, so toggling them never breaks the required
check.

Note: `staticAnalysis` and `secretScan` only apply to `validate.yml` (PR-time
checks). `apexValidation` and `flowTests` apply to both `validate.yml` and
`deploy.yml`, since both need to know the test level and whether to include
Flow Test metadata in the deploy package.

## Checks

- **static-analysis** — Salesforce Code Analyzer (PMD for Apex, ESLint for
  LWC/Aura), scoped to the delta, via the official
  `forcedotcom/run-code-analyzer` action. Posts a PR review comment
  summarizing violations, publishes the full detail view as a GitHub
  Actions job summary, and uploads an HTML/JSON report as a workflow
  artifact. Only blocks the PR on Sev1 (critical) or Sev2 (high) violations
  in changed files — lower severities are visible but non-blocking.
- **secret-scan** — gitleaks over the PR's diff range.
- **deploy-validate** — `sf project deploy validate` against the delta
  package, running Apex tests at the branch's configured test level.
- **Flow Tests** — not a separate job. Any changed Flow's associated Flow
  Test metadata is pulled into the delta package by
  `scripts/ci/resolve-flow-tests.mjs`; Salesforce runs Flow Tests
  automatically during deploy/validate when that metadata is present. Active
  flows with no matching Flow Test fail the check; draft flows are exempt.

## Known caveats to verify before relying on this in production

- **Flow Testing tooling** — the file-naming convention and "runs
  automatically when included in the deploy package" behavior reflects
  Salesforce's Flow Testing feature as of this writing. This area has changed
  across recent releases — confirm against current release notes for your
  org's API version.
- **Salesforce Code Analyzer command/plugin name** — `sf code-analyzer run`
  and `@salesforce/plugin-code-analyzer` have been renamed before across CLI
  versions. Confirm current syntax with `sf plugins`.
- **gitleaks-action licensing** — `gitleaks/gitleaks-action@v2` may require a
  paid license for private-repo use beyond its free tier. If that's a
  blocker, swap the step for the OSS `gitleaks detect` CLI directly.

## Local delta preview

To see what a PR's delta would contain without running CI:

```
git fetch origin dev
sf sgd:source:delta --to HEAD --from origin/dev --output-dir delta_output --generate-delta
```

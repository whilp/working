# Working

Automated work loop for GitHub repositories.

## Setup

### Secrets

The workflow requires two secrets:

- **`CLAUDE_CODE_OAUTH_TOKEN`** — OAuth token for Claude API access.
- **`GH_TOKEN`** — Fine-grained GitHub PAT with access to target repositories.

#### GH_TOKEN permissions

Create a [fine-grained personal access token](https://github.com/settings/personal-access-tokens/new) with:

**Repository access**: select target repos (e.g. `whilp/ah`, `whilp/cosmic`).

| Permission | Level | Used for |
|---|---|---|
| Contents | Read and write | clone, push branches |
| Issues | Read and write | list issues, transition labels, comment |
| Pull requests | Read and write | create PRs |
| Metadata | Read-only | required by GitHub for all fine-grained PATs |

The following are optional and not currently used by the work loop:

| Permission | Level | Notes |
|---|---|---|
| Actions | Read and write | not needed unless running CI checks |
| Commit statuses | Read and write | not needed unless checking commit status |
| Workflows | Read and write | not needed unless modifying workflow files |

## Usage

```bash
# run full loop for a repo
REPO=whilp/ah make check

# run individual phases
REPO=whilp/ah make pick
REPO=whilp/ah make clone
REPO=whilp/ah make plan
REPO=whilp/ah make do
REPO=whilp/ah make check
```

The GitHub workflow runs on a schedule (every 3 hours) or via manual dispatch.
It matrices over configured repos (`whilp/ah`, `whilp/cosmic`).

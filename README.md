# gcp-fleet

A small fleet of web servers on Google Cloud, with **no public IP**, created by
Terraform and configured **only** by Ansible, always through a pipeline.
No SSH key and no cloud key is stored anywhere.

> **Current state: scaled to zero** (v1.0.0). The code, the pipelines and the
> identities are all here; the VMs are not, so the project costs nothing to keep.
> [Bring it back](#bring-it-back) with two pull requests.

## What it does

```
Pull request ──► Ansible lint ─► Check (dev) + Check (prod): --check --diff on the real VMs, posted on the PR
             └─► Validate ─► Security scan (checkov) ─► Plan (dev) + Plan (prod), posted on the PR

Merge to main ─► Terraform: Apply (dev) ─► Apply (prod) ⏸ waits for approval
              └─► Ansible:   Apply (dev, site.yml) ─► Apply (prod, rolling.yml) ⏸ waits for approval

Every day     ─► 19:17 UTC Config drift: --check against main; opens an issue if a VM was changed by hand
              ─► 20:07 UTC Power: stops every VM left running
```

| | dev | prod |
|---|---|---|
| VMs | `dev-web-01`, `dev-web-02` | `prod-web-01`, `prod-web-02` |
| Network | `10.10.1.0/24` (from [gcp-baseline](https://github.com/pedrosoares1903/gcp-baseline)) | `10.20.1.0/24` |
| Playbook | `site.yml`: every VM at once | `rolling.yml`: one VM at a time, each one checked |
| Applied | after every merge | after every merge, **once someone approves** |
| Vault | `dev` | `prod`, a different password |

## How it is built

| Piece | Tool | Where |
|---|---|---|
| State bucket, identities, workload identity federation | Terraform, applied by hand | `bootstrap/` |
| VMs and their firewall rules | Terraform module, one folder per environment | `terraform/` |
| Everything inside the VMs: packages, SSH hardening, nginx, the page, `/admin` | Ansible roles `common`, `nginx`, `site` | `ansible/` |
| The VMs Ansible works on | asked to Google on every run, by label (`env`, `tier`) | `ansible/inventories/*/gcp.yml` |
| Pipelines | GitHub Actions | `.github/workflows/` |

### Identities: who can do what

| Identity | Can | Cannot |
|---|---|---|
| `fleet-terraform` (Terraform pipeline) | create, change and delete VMs and firewall rules | log in to a VM |
| `fleet-ansible` (Ansible, drift and power pipelines) | list VMs, log in through IAP with sudo, start and stop VMs (custom role `fleetPower`) | create, change or delete a VM |
| `fleet-vm` (the VMs themselves) | nothing: it holds no roles | anything |

- **To Google:** GitHub OIDC → Workload Identity Federation, limited to this repository. No service account key exists.
- **To the VMs:** OS Login. Each run creates a new SSH key, registers it for **one hour**, and removes it at the end.
- **Secrets:** Ansible Vault, one vault per environment. The vault passwords are GitHub secrets and never in the repository.

## Proof

Each claim below was shown on the real VMs. The run logs are deleted by GitHub after 90 days, so the
lines that prove phase 7 are copied into [`docs/proof/phase-7.md`](docs/proof/phase-7.md).

| Claim | Evidence |
|---|---|
| Stopping a VM is not drift: Terraform plans no change | phase 1 |
| A pull request shows, line by line, what would change inside each VM | PR <link> (the `--diff` comment) |
| prod only changes after someone approves | [`docs/proof/phase-7.md`](docs/proof/phase-7.md) §1 |
| A rolling update finishes one VM before starting the next | [`docs/proof/phase-7.md`](docs/proof/phase-7.md) §2 |
| A change that passes every check but breaks the site stops at the first VM; the second is never touched | [`docs/proof/phase-7.md`](docs/proof/phase-7.md) §3 |
| The fix goes through the same path (a revert PR), with nobody logging in to a VM | [`docs/proof/phase-7.md`](docs/proof/phase-7.md) §4 |
| A change made by hand on a VM opens an issue, and the issue closes itself once the VM matches `main` again | issue <link> |

### What warns, and what blocks

| Check | When | Warns or blocks |
|---|---|---|
| `pre-commit`: private key, end of file, whitespace, large files, `terraform fmt`, `ansible-lint` | `git commit`, on your machine | **warns**: `git commit --no-verify` skips it |
| `Ansible lint`, `Validate`, `Security scan`, `Plan (dev/prod)`, `Check (dev/prod)` | every pull request | **blocks** the merge (branch ruleset, no bypass) |
| The plan and the `--diff` posted on the PR | every pull request | **warns**: a person has to read them |
| Approval of the `prod` environment | every merge | **blocks** prod |
| Page check in `rolling.yml` | prod apply | **blocks** the next VM |
| Page check in `site.yml` | dev apply | **warns**: the run turns red, but both VMs have already changed |
| Config drift | daily | **warns**: an issue and a red run |
| Power | nightly | **acts**: stops the VMs |

## Known limitations

- **Terraform and Ansible run as two workflows, in parallel.** A merge that creates a VM and changes Ansible
  can configure nothing until the next run. Approve Terraform's `prod` job first, then Ansible's; if a new VM
  is still unconfigured, Actions → Ansible → Run workflow.
- **dev is not protected, only watched.** `site.yml` changes both dev VMs at once; its page check makes the run
  red after the damage, by design.
- **Only `pre-commit` looks for private keys**, and it runs on the developer's machine. Nothing on GitHub would
  stop a key pushed with `--no-verify`.
- **`--check` cannot see what only exists after applying** (a reloaded nginx serving 404). That is what the
  page checks after the apply are for.
- **One person approves their own prod deployments** ("prevent self-review" is off). In a team it would be on.
- **The PR checks need the VMs running.** With the VMs stopped, nothing can be merged: on purpose.
- **Scheduled workflows stop after 60 days without repository activity** (a GitHub rule for public repositories).

## Bring it back

1. In [gcp-baseline](https://github.com/pedrosoares1903/gcp-baseline): `enable_nat = true` in the environments you
   need. The VMs have no public IP; without NAT, `apt` cannot reach the internet.
2. Here: `web_count = 2` in `terraform/environments/<env>/main.tf`, in a pull request. Merge; approve Terraform's
   `prod` job **before** Ansible's.
3. Check: Actions → Config drift → Run workflow. Green means every VM matches `main`.

## Versions

| Tag | What it added |
|---|---|
| `v0.1.0` | bootstrap: state bucket, identities, workload identity federation |
| `v0.2.0` | two VMs in dev |
| `v0.3.0` | Ansible reaches them: dynamic inventory, IAP, OS Login |
| `v0.4.0` | roles `common`, `nginx`, `site` |
| `v0.5.0` | pipelines: plan/apply and check/apply on every PR and merge |
| `v0.6.0` | prod behind approval; rolling updates proven with a failure |
| `v1.0.0` | drift check, nightly power-off, `pre-commit`, this README; scaled to zero |

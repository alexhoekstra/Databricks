# governance — config-driven Unity Catalog permissions

Security automation config maps drive everything via `for_each`.
Adding a team, a catalog, or a member is only a config edit.

## The model

> Unity Catalog only resolves account-level principals. The `databricks_group`,
> driven by a workspace-scoped provider (the only one the Free Edition hands
> out), creates **workspace-local** groups, which UC rejects as grant principals. 
> Users, however, register at the account level and resolve by email.
>
> So the teams matrix is projected down to per-user grants: for each member of
> a team, `grants.tf` emits a `databricks_grant`s to that user's email, and a user on
> multiple teams gets the union of their teams' privileges on each shared
> schema (`locals.tf`). 
>
> The groups and memberships are still created, and they are what
> would be promoted to account-level grants on a paid tier.

```mermaid
flowchart LR
    subgraph config["Config — the only thing you edit"]
        tfvars["terraform.tfvars<br/>catalogs = { hr, finance, programs }"]
        matrix["access_matrix.json<br/>teams → schema_grants<br/>e.g. finance_analysts:<br/>finance/silver, finance/gold,<br/>programs/gold = [SELECT]"]
        csv["members/&lt;team&gt;.csv<br/>name,email — one file per team,<br/>deduped across teams"]
    end

    subgraph tf["Terraform-owned resources"]
        schemas["databricks_schema<br/>hr · finance · programs<br/>× bronze/silver/gold = 9 schemas<br/>(force_destroy)"]
        users["databricks_user<br/>(deduped by lowercased email)"]
        members["databricks_group_member"]
        groups["databricks_group<br/>e.g. finance_analysts (is_member)"]
        grants["databricks_grant per (user, catalog/schema)<br/>+ one derived USE_CATALOG per (user, catalog)"]
    end

    subgraph data["sample_data/ — the data plane the grants act on"]
        hr["sample_data_hr.sql<br/>employees_raw → employees (PII) → headcount_by_program"]
        fin["sample_data_finance.sql<br/>contract_lines_raw → contracts → program_spend"]
        prog["sample_data_programs.sql<br/>milestones_raw → programs (ITAR) → program_status"]
        masks["row_filters_masks.sql<br/>HR masks (email/ssn/clearance/salary) + ITAR row filter"]
    end

    tfvars --> schemas
    csv --> users
    csv --> members
    matrix --> groups
    matrix -- "projected to each MEMBER's email" --> grants
    csv --> grants
    grants --> data
```

## Data Access Controls (testing examples)

The controls protect row-level detail, and gold is allowed to
expose aggregates that the row-level controls would hide:

- HR: `hr.silver.employees` masks individual `salary` (shows NULL for non-pii_readers),
  but `hr.gold.headcount_by_program` publishes `avg_salary` per program.
- ITAR: `programs.silver.programs` hides ITAR rows from non-`export_cleared`
  users, and `programs.gold.program_status` excludes ITAR programs entirely.

## Governance loop — access-as-code

The PR workflow is the only way make changes in production: an access request is a
PR touching two files, reviewed on the PR as a diff and applied behind an environment gate.

```mermaid
flowchart LR
    request["access request<br/>edit access_matrix.json<br/>+ members/*.csv"]
    review["review + merge<br/>governance-prod env<br/>required reviewer"]
    uc["Unity Catalog grants"]

    request -- "PR job: fmt / validate + lint<br/>+ sticky diff comment" --> review
    review -- "push:main<br/>gated apply (S3 state)" --> uc
```

### Request access

To grant or revoke access, open a PR that edits only:

1. `access_matrix.json` — add/adjust a team's `schema_grants` (privileges from
   `USE_SCHEMA`, `SELECT`, `MODIFY`; `USE_CATALOG` is derived).
2. `members/<team>.csv` — add/remove a `name,email` row.

The `governance_access.yml` The Github Action PR job runs `terraform fmt`,
and `validate`, lints the config, and posts a readable diff.
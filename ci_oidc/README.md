# ci_oidc — GitHub Actions ↔ AWS OIDC federation

Run-once bootstrap root that lets GitHub Actions authenticate to AWS with
**short-lived OIDC tokens instead of long-lived access keys**. It creates:

1. `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com`
2. IAM role **`gha-terraform`**, assumable only by Actions jobs in
   `alexhoekstra/Databricks`, whose only permission is read/write on the
   Terraform state bucket under the prefixes in `var.state_key_prefixes`
   (today: `declarative_bronze/`)

## Why OIDC

- No `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` repo secrets to leak or
  rotate — each job exchanges a GitHub-signed token for ~1h AWS credentials.
- The trust policy pins the exact repo (`sub = repo:alexhoekstra/Databricks:*`),
  so a fork or another repo can't assume the role even if it copies the workflow.
- Contrast worth noting: Databricks **account** federation for GitHub Actions
  was blocked on Free Edition, but AWS-side federation is independent and works.

How a workflow uses it (see `.github/workflows/terraform.yml`):

```yaml
permissions:
  id-token: write          # lets the job request a GitHub OIDC token
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ vars.GHA_TERRAFORM_ROLE_ARN }}
      aws-region: ${{ vars.TF_STATE_REGION }}
```

## One-time apply

State is **local on purpose** (this root creates the role that CI uses to reach
the S3 state bucket — remote state here would be a chicken-and-egg).

```sh
# 0. GOTCHA: AWS allows ONE OIDC provider per URL per account. If this lists a
#    token.actions.githubusercontent.com provider (e.g. from the earlier
#    explorations/terraform/dev/provisioning federation attempt), import it:
aws iam list-open-id-connect-providers
# terraform import aws_iam_openid_connect_provider.github <existing-provider-arn>

# 1. Apply with admin AWS credentials (defaults are correct for this repo/account)
terraform init
terraform apply

# 2. Publish the role ARN as a repo variable for the workflows
gh variable set GHA_TERRAFORM_ROLE_ARN --body "$(terraform output -raw github_terraform_role_arn)"
```

## Hardening path (documented, not built)

One wildcard role (`sub = repo:…:*`) is the pragmatic choice here: PR plans,
pushes to main, and environment-gated applies all present different `sub`
claims, and the role can only touch state objects anyway. For a production
account, split it:

- **plan role** — `s3:GetObject`/`ListBucket` only, trust restricted to
  `repo:…:pull_request`
- **apply role** — full state read/write, trust restricted to
  `repo:…:environment:declarative-bronze-prod`

## Migrating governance off static keys

`governance_access.yml` still authenticates with static `AWS_*` secrets. To
migrate it: add `"governance"` to `state_key_prefixes` and re-apply, add
`id-token: write` to its apply job, swap the `configure-aws-credentials` inputs
to `role-to-assume: ${{ vars.GHA_TERRAFORM_ROLE_ARN }}`, then delete the
`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` secrets (and the `gha-governance-tf`
IAM user).

# Databricks Platform Engineering Exploration - Terraform Provisioning

This portion of the repository contains my exploration and building depth of knowledge about Databrick Provisioning using Terraform. 

This was all done on Databricks Free Tier, so there are some limitations to what could be experimented on.

## Key Databricks functions

- `alerts.tf`: Creates a Databricks notification destination and configures administrator alert email delivery using Vault secrets.
- `federation_policy.tf`: Includes a commented example of GitHub Actions OIDC federation policy for a Databricks service principal.  I had to use a Personal Access Token (PAT) instead due to free tier limitations not allowing account-level configuration.

- `groups.tf`: Creates example workspace admin and user groups with cluster and instance pool permissions settings.
- `service_principal.tf`: Provisions a Databricks service principal to use with Github Actions and Databricks CLI, creates Git credentials and a secret, grants catalog privileges, and stores service principal data back into Vault.
- `users.tf`: Creates example Databricks users and assigns them into the admin and user groups.


##


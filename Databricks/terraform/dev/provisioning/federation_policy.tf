# OIDC Workload Identity Federation Policy for GitHub Actions


# NOTE: I was not able to play around with this, it is not available to free tier users 
#      since you dont have access to an Account ID or the Databricks Account Console

#Configure the OIDC Workload Identity Federation Policy
# resource "databricks_service_principal_federation_policy" "github_oidc" {
#   service_principal_id = databricks_service_principal.github_admin.id
#   policy_id            = "github-actions-deploy-policy"
#   description          = "Allows GitHub Actions repository to authenticate passwordless as account admin"
#   oidc_policy = {
#     # Standard GitHub Actions OIDC Configuration
#     issuer        = "https://token.actions.githubusercontent.com"
#     subject_claim = "sub"

#     # Databricks recommends targeting your account ID as the token audience
#     audiences = [var.databricks_account_id]

#     # Restrict access to a specific repository and branch (e.g., 'main')
#     # Syntax format expected by GitHub OIDC: repo:<org>/<repo>:ref:refs/heads/<branch>
#     subject = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
#   }
# }
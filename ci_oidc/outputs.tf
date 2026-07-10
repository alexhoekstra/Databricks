output "github_terraform_role_arn" {
  description = "Set this as the GHA_TERRAFORM_ROLE_ARN repository variable"
  value       = aws_iam_role.github_terraform.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

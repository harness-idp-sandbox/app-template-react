# {{ cookiecutter.project_name }} ({{ cookiecutter.project_slug }})
Minimal static site on AWS (S3 private + CloudFront). Infra via Terraform; deploy via GitHub Actions OIDC.
## Quick start
1) Create an IAM role for GitHub OIDC; save ARN to repo secret `AWS_GHA_ROLE_ARN`.
2) `cd infra && cp terraform.tfvars.example terraform.tfvars && terraform init && terraform apply`
3) Push changes under `/site` to deploy.

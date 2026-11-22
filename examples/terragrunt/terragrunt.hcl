terraform_binary = "terraform"

terraform {
  source = "../.."
}

locals {
  fleet   = get_env("RUNNER_FLEET", "aws-ci")
  profile = get_env("AWS_PROFILE")
  region  = get_env("AWS_REGION")
  account = regex("^[0-9]{12}$", get_env("RUNNER_AWS_ACCOUNT_ID"))
}

generate "provider" {
  path      = "provider.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = ${jsonencode(local.region)}
      profile             = ${jsonencode(local.profile)}
      allowed_account_ids = ${jsonencode([local.account])}
    }
  EOF
}

generate "backend" {
  path      = "backend.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      backend "local" {
        path = ${jsonencode("${get_terragrunt_dir()}/terraform.tfstate")}
      }
    }
  EOF
}

inputs = {
  fleet_name                    = local.fleet
  repository                    = get_env("RUNNER_GITHUB_REPOSITORY")
  vpc_id                        = get_env("RUNNER_VPC_ID")
  subnet_ids                    = split(",", get_env("RUNNER_SUBNET_IDS"))
  associate_public_ipv4_address = get_env("RUNNER_PUBLIC_IPV4", "false") == "true"
  ami_id                        = get_env("RUNNER_AMI_ID")
  ami_owner_id                  = get_env("RUNNER_AMI_OWNER_ID", local.account)
  artifacts_directory           = abspath("${get_terragrunt_dir()}/../../.artifacts")
  provisioning_enabled          = get_env("RUNNER_PROVISIONING_ENABLED", "false") == "true"
  app_parameters = {
    id             = "/${local.fleet}/github-app/id"
    key_base64     = "/${local.fleet}/github-app/key-base64"
    webhook_secret = "/${local.fleet}/github-app/webhook-secret"
  }
}

mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-west-2" }
  }
  mock_data "aws_ami" {
    defaults = {
      id               = "ami-0123456789abcdef0"
      root_device_name = "/dev/xvda"
    }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

mock_provider "null" {}
mock_provider "random" {}

variables {
  repository          = "example/private-repo"
  vpc_id              = "vpc-00000000000000000"
  subnet_ids          = ["subnet-00000000000000000"]
  artifacts_directory = "./.artifacts"
  app_parameters = {
    id             = "/aws-ci/github-app/id"
    key_base64     = "/aws-ci/github-app/key-base64"
    webhook_secret = "/aws-ci/github-app/webhook-secret"
  }
}

run "safe_first_apply" {
  command = plan

  assert {
    condition     = module.runners.runners.lambda_up.reserved_concurrent_executions == 0
    error_message = "Runner provisioning must start disabled."
  }
  assert {
    condition     = toset(jsondecode(module.runners.webhook.lambda.environment[0].variables.REPOSITORY_ALLOW_LIST)) == toset([var.repository])
    error_message = "Only the configured repository may queue runners."
  }
  assert {
    condition     = toset(output.runner_labels) == toset(module.runners.runners.labels)
    error_message = "The workflow labels must match the autoscaler."
  }
  assert {
    condition     = module.runners.ssm_parameters.key_base64.name == var.app_parameters.key_base64
    error_message = "The module must reference the external private-key parameter."
  }
  assert {
    condition     = tolist(data.aws_ami.runner.owners) == tolist(["amazon"]) && local.ami_id == "ami-0123456789abcdef0"
    error_message = "Use the public AL2023 parameter and require Amazon's owner alias by default."
  }
}

run "explicit_provisioning" {
  command = plan
  variables {
    provisioning_enabled = true
    ami_id               = "ami-00000000000000001"
    ami_owner_id         = "123456789012"
  }

  assert {
    condition     = module.runners.runners.lambda_up.reserved_concurrent_executions == 1
    error_message = "Enabling provisioning must serialize scale-up."
  }
  assert {
    condition     = length(data.aws_ssm_parameter.amazon_linux) == 0 && local.ami_id == var.ami_id && tolist(local.ami_owners) == tolist([var.ami_owner_id])
    error_message = "A pinned image must bypass the public parameter and keep its publisher restriction."
  }
}

run "custom_image_requires_publisher" {
  command = plan
  variables {
    ami_id = "ami-00000000000000001"
  }

  expect_failures = [data.aws_ami.runner]
}

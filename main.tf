terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.33, < 7.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_ami" "runner" {
  owners = [var.ami_owner_id]

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  release = jsondecode(file("${path.module}/release.json"))
  artifacts = {
    for filename in keys(local.release.sha256) :
    filename => "${var.artifacts_directory}/${filename}"
  }
  parameter_arn_prefix = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter"
  app_parameters = {
    for key, name in var.app_parameters :
    key => { name = name, arn = "${local.parameter_arn_prefix}${name}" }
  }
  tags = merge(var.tags, { Fleet = var.fleet_name })
}

resource "terraform_data" "verified_artifacts" {
  input = local.release.source_sha

  lifecycle {
    precondition {
      condition = alltrue([
        for filename, digest in local.release.sha256 : try(filesha256(local.artifacts[filename]) == digest, false)
      ])
      error_message = "Missing or unexpected Lambda artifacts. Run scripts/fetch_lambdas.py before planning."
    }
  }
}

module "runners" {
  source = "git::https://github.com/github-aws-runners/terraform-aws-github-runner.git?ref=f975153d6749b2ea2ddebc8d8cf5911196a1973a"

  prefix     = var.fleet_name
  aws_region = data.aws_region.current.region
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids
  tags       = local.tags

  github_app = {
    id_ssm             = local.app_parameters.id
    key_base64_ssm     = local.app_parameters.key_base64
    webhook_secret_ssm = local.app_parameters.webhook_secret
  }

  repository_white_list                   = [var.repository]
  enable_organization_runners             = false
  enable_ephemeral_runners                = true
  enable_jit_config                       = true
  enable_dynamic_labels                   = false
  enable_runner_bidirectional_label_match = true
  enable_job_queued_check                 = true
  enable_ssm_on_runners                   = false
  enable_user_data_debug_logging_runner   = false
  runner_extra_labels                     = [var.fleet_name]
  runner_name_prefix                      = "${var.fleet_name}-"
  runner_os                               = "linux"
  runner_architecture                     = "x64"
  idle_config                             = []
  runners_maximum_count                   = var.max_runners
  scale_up_reserved_concurrent_executions = var.provisioning_enabled ? 1 : 0
  scale_down_schedule_expression          = "cron(* * * * ? *)"
  eventbridge                             = { enable = false }

  instance_target_capacity_type   = "on-demand"
  instance_allocation_strategy    = "prioritized"
  instance_types                  = var.instance_types
  create_service_linked_role_spot = false
  associate_public_ipv4_address   = var.associate_public_ipv4_address
  ami = {
    owners = [var.ami_owner_id]
    filter = { image-id = [data.aws_ami.runner.id] }
  }
  block_device_mappings = [{
    device_name           = data.aws_ami.runner.root_device_name
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gib
    encrypted             = true
    delete_on_termination = true
  }]
  runner_metadata_options = {
    instance_metadata_tags      = "enabled"
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  logging_retention_in_days         = 14
  webhook_lambda_zip                = local.artifacts["webhook.zip"]
  runners_lambda_zip                = local.artifacts["runners.zip"]
  runner_binaries_syncer_lambda_zip = local.artifacts["runner-binaries-syncer.zip"]
  instance_termination_watcher = {
    enable = true
    features = {
      enable_spot_termination_handler              = false
      enable_spot_termination_notification_watcher = false
    }
    zip = local.artifacts["termination-watcher.zip"]
  }
}

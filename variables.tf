variable "fleet_name" {
  description = "AWS resource prefix, Fleet tag and GitHub runner label."
  type        = string
  default     = "aws-ci"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,23}$", var.fleet_name))
    error_message = "Use 2 to 24 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "repository" {
  description = "The trusted private GitHub repository allowed to queue runners, in owner/repo form."
  type        = string

  validation {
    condition = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository)) && alltrue([
      for part in split("/", var.repository) : !contains([".", ".."], part)
    ])
    error_message = "Provide one exact GitHub owner/repository."
  }
}

variable "app_parameters" {
  description = "Existing SecureString parameter names in this AWS account and region. The private key value must be base64."
  type = object({
    id             = string
    key_base64     = string
    webhook_secret = string
  })

  validation {
    condition = alltrue([
      for name in var.app_parameters : can(regex("^/([A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+$", name))
    ]) && length(distinct(values(var.app_parameters))) == 3
    error_message = "Provide three distinct SSM parameter paths. Pass names, never secret values."
  }
}

variable "vpc_id" {
  description = "VPC ID for runner instances."
  type        = string
}

variable "subnet_ids" {
  description = "Runner subnets with outbound access to GitHub and AWS APIs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0 && length(var.subnet_ids) == length(distinct(var.subnet_ids))
    error_message = "Provide one unique subnet per selected Availability Zone."
  }
}

variable "associate_public_ipv4_address" {
  description = "Use only for internet-gateway subnets with restricted inbound access."
  type        = bool
  default     = false
}

variable "ami_id" {
  description = "Pinned x86_64 Linux runner AMI supported by the upstream bootstrap."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.ami_id))
    error_message = "Provide a pinned EC2 AMI ID."
  }
}

variable "ami_owner_id" {
  description = "AWS account ID of the publisher of the pinned AMI."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.ami_owner_id))
    error_message = "Provide the 12-digit AWS account ID that owns the image."
  }
}

variable "artifacts_directory" {
  description = "Absolute path containing the verified Lambda release files."
  type        = string
}

variable "instance_types" {
  description = "Prioritized x86_64 On-Demand EC2 instance types."
  type        = list(string)
  default     = ["m6i.large", "m7i.large"]

  validation {
    condition     = length(var.instance_types) > 0
    error_message = "Select at least one EC2 instance type."
  }
}

variable "root_volume_size_gib" {
  description = "Encrypted gp3 root volume size in GiB."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size_gib >= 20 && floor(var.root_volume_size_gib) == var.root_volume_size_gib
    error_message = "Provide a whole-number size of at least 20 GiB and large enough for the AMI snapshot."
  }
}

variable "max_runners" {
  description = "Maximum number of runners for this repository."
  type        = number
  default     = 2

  validation {
    condition     = var.max_runners >= 1 && var.max_runners <= 10 && floor(var.max_runners) == var.max_runners
    error_message = "Set an integer from 1 to 10."
  }
}

variable "provisioning_enabled" {
  description = "Allow the scale-up Lambda to launch runners after the GitHub App is configured."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional AWS resource tags."
  type        = map(string)
  default     = {}
}

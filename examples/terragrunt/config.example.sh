# Copy this to config.local.sh, replace the example values, then source it.
export AWS_PROFILE=my-aws-profile
export AWS_REGION=eu-west-2
export RUNNER_AWS_ACCOUNT_ID=123456789012

export RUNNER_GITHUB_REPOSITORY=your-user/your-private-repo
export RUNNER_VPC_ID=vpc-your-id
export RUNNER_SUBNET_IDS=subnet-your-first-id,subnet-your-second-id
export RUNNER_AMI_ID=ami-your-id

# Only needed if the AMI belongs to a different AWS account.
# export RUNNER_AMI_OWNER_ID=123456789012

# For public subnets routed through an internet gateway.
# export RUNNER_PUBLIC_IPV4=true

# Set to true after the webhook is configured and delivery is verified.
export RUNNER_PROVISIONING_ENABLED=false

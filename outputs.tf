output "webhook_url" {
  description = "Set this URL on the GitHub App webhook."
  value       = module.runners.webhook.endpoint
}

output "runner_labels" {
  description = "Use the full label set in GitHub Actions runs-on."
  value       = ["self-hosted", "linux", "x64", var.fleet_name]
}

output "domain" {
  description = "Domain name"
  value       = var.domain
}

output "domain_url" {
  description = "HTTPS URL for the domain"
  value       = "https://${var.domain}"
}

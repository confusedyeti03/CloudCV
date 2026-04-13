output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Elastic IP address"
  value       = aws_eip.web.public_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/labsuser.pem -p ${var.ssh_port} admin@${aws_eip.web.public_ip}"
}

output "domain" {
  description = "Domain name"
  value       = var.domain
}

output "domain_url" {
  description = "HTTPS URL for the domain"
  value       = "https://${var.domain}"
}

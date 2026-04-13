# =============================================================================
# Cloudflare DNS Records
# =============================================================================
# PURPOSE: DNS-only mode (grey cloud) for Let's Encrypt SSL
# NOTE: proxied = false to allow direct connection for Certbot ACME challenges
# =============================================================================

# Root domain (DNS-only for Let's Encrypt)
resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "A"
  content = aws_eip.web.public_ip
  proxied = false # DNS-only mode for Let's Encrypt
  ttl     = 300
}

# WWW subdomain (DNS-only for Let's Encrypt)
resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  type    = "A"
  content = aws_eip.web.public_ip
  proxied = false # DNS-only mode for Let's Encrypt
  ttl     = 300
}

# CAA record - Only Let's Encrypt can issue certificates
resource "cloudflare_record" "caa" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CAA"
  data {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
  ttl = 3600
}

# SPF record - domain sends no email, reject all
resource "cloudflare_record" "spf" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "TXT"
  content = "v=spf1 -all"
  ttl     = 3600
}

# DMARC record - reject spoofed email
resource "cloudflare_record" "dmarc" {
  zone_id = var.cloudflare_zone_id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=reject; rua=mailto:${var.admin_email}"
  ttl     = 3600
}

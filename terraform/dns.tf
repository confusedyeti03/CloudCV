# =============================================================================
# Cloudflare DNS Records (Serverless Architecture)
# =============================================================================
# PURPOSE: Point to CloudFront distribution instead of EC2 Elastic IP
# CloudFront handles SSL/TLS (ACM certificates), no Certbot needed
# =============================================================================

# Root domain - points to CloudFront distribution
# CloudFront alias records don't require A records, but Cloudflare requires them
# Use CNAME to CloudFront domain
resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CNAME"
  content = aws_cloudfront_distribution.static.domain_name
  proxied = false
  ttl     = 300
}

# WWW subdomain - also points to CloudFront
resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  type    = "CNAME"
  content = aws_cloudfront_distribution.static.domain_name
  proxied = false
  ttl     = 300
}

# CAA record - Allow ACM to issue certificates for this domain
resource "cloudflare_record" "caa" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CAA"
  data {
    flags = 0
    tag   = "issue"
    value = "amazon.com"  # AWS Certificate Manager
  }
  ttl = 3600
}

# Secondary CAA record - Allow Let's Encrypt (not used, but for compatibility)
resource "cloudflare_record" "caa_letsencrypt" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CAA"
  data {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org;AccountUri=https://acme-v02.api.letsencrypt.org/acme/acct/12345678"
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

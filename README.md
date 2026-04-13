# CloudCV - Portfolio & CV Website

Personal portfolio website for **Lluís Noval** at [lnoval.dev](https://lnoval.dev).

## Architecture

- **Frontend**: Static HTML/CSS/JS (landing page, CV viewer, projects showcase)
- **Backend**: FastAPI service for multilingual CV API and PDF generation
- **Infrastructure**: AWS EC2 t4g.nano (ARM64) provisioned via Terraform
- **Configuration**: Ansible roles for nginx, security, and monitoring
- **DNS**: Cloudflare (DNS-only mode)
- **SSL**: Let's Encrypt certificates via Certbot (auto-renewal)

## Project Structure

```
CloudCV/
├── web/                    # Static frontend
│   ├── index.html          # Landing page
│   ├── cv/                 # CV viewer (CA/ES/EN)
│   └── portfolio/          # AWS projects portfolio
├── cv-service/             # FastAPI backend
│   ├── app.py              # API endpoints
│   └── data/               # CV data (YAML)
├── terraform/              # Infrastructure as Code
│   ├── ec2.tf              # EC2 instance
│   ├── vpc.tf              # VPC, subnet, gateway
│   ├── security_groups.tf  # Firewall rules
│   ├── iam.tf              # IAM roles and policies
│   ├── cloudwatch.tf       # Log groups and alarms
│   ├── ebs_snapshots.tf    # DLM backup policy
│   └── dns.tf              # Cloudflare DNS records
├── ansible/                # Configuration management
│   ├── playbooks/site.yml  # Main playbook
│   ├── roles/              # Modular roles
│   └── inventory/          # Host configuration
└── scripts/                # Utility scripts
```

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- Ansible >= 2.12
- Cloudflare API token with DNS edit permissions
- SSH key pair in AWS (default: `vockey`)

## Deployment

### 1. Bootstrap Terraform State (First Time Only)

```bash
cd terraform/state-bootstrap
terraform init
terraform apply
```

This creates the S3 bucket and DynamoDB table for remote state.

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
cp backend.tf.example backend.tf
```

Edit `terraform.tfvars`:
```hcl
cloudflare_api_token = "your-api-token"
cloudflare_zone_id   = "your-zone-id"
admin_email          = "admin@lnoval.dev"
ssh_key_name         = "your-key-name"
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Update Ansible Inventory

```bash
./scripts/update-inventory.sh
```

Or manually edit `ansible/inventory/hosts.yml` with the Elastic IP.

### 5. Run Ansible Playbook

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

For specific tasks:
```bash
# Deploy only
ansible-playbook playbooks/site.yml --tags "deploy"

# Skip WAF (Anubis)
ansible-playbook playbooks/site.yml --skip-tags "anubis"

# Monitoring only
ansible-playbook playbooks/site.yml --tags "cloudwatch"
```

## Monitoring

### CloudWatch Log Groups
- `/aws/lnoval-cv/nginx/access` - 3 day retention
- `/aws/lnoval-cv/nginx/error` - 14 day retention
- `/aws/lnoval-cv/app` - 7 day retention
- `/aws/lnoval-cv/system` - 7 day retention

### CloudWatch Alarms
- CPU utilization > 80%
- Memory usage > 85%
- Disk usage > 80%
- Instance status check failures

### EBS Snapshots
- Daily at 03:00 UTC
- Retained for 7 days
- Managed by AWS DLM

## Security Features

- UFW firewall (ports 80, 443, 2222)
- Fail2ban for SSH and nginx protection
- SSH hardening (key-only, custom port)
- IMDSv2 required on EC2
- SSM Session Manager access (no bastion needed)
- Let's Encrypt SSL with auto-renewal
- HSTS, CSP, and other security headers

## URLs

- **Landing**: https://lnoval.dev
- **CV Viewer**: https://lnoval.dev/cv/
- **Projects**: https://lnoval.dev/portfolio/
- **Health Check**: https://lnoval.dev/api/health

## Development

### Local Frontend
```bash
cd web
python -m http.server 8000
```

### Local Backend
```bash
cd cv-service
pip install -r requirements.txt
uvicorn app:app --reload
```

## License

Private repository for personal portfolio.

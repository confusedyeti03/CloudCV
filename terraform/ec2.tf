# Get latest Debian 12 ARM AMI
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # Debian Official

  filter {
    name   = "name"
    values = ["debian-12-arm64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.debian.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
    tags = {
      Name = "${var.project_name}-server"
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Change SSH port to match SG
              sed -i "s/^#*Port 22/Port 2222/" /etc/ssh/sshd_config
              sed -i "s/^#*Port .*/Port 2222/" /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
              systemctl restart ssh
              
              if ! swapon --show | grep -q "/swapfile"; then
                fallocate -l 1G /swapfile
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo "/swapfile none swap sw 0 0" >> /etc/fstab
              fi
              EOF

  tags = {
    Name = "${var.project_name}-server"
  }
}

# Elastic IP
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

# Run Ansible Playbook automatically
# DISABLED FOR FASE 3: Ansible configuration deferred to FASE 8 (EC2 retirement)
# In FASE 3-7, EC2 remains unchanged while serverless infrastructure is built
/*
resource "null_resource" "run_ansible" {
  depends_on = [aws_instance.web, aws_eip.web]

  triggers = {
    instance_id = aws_instance.web.id
  }

  provisioner "local-exec" {
    command     = "wsl bash -c \"sleep 30 && cd ../ansible && ANSIBLE_CONFIG=ansible.cfg ANSIBLE_ROLES_PATH=roles ansible-playbook playbooks/site.yml -e ansible_host=${aws_eip.web.public_ip}\""
    interpreter = ["powershell", "-Command"]
  }
}
*/


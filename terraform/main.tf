terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Look up the latest Ubuntu 24.04 AMI from Canonical's public SSM parameter,
# so no AMI ID is hardcoded (the lesson from the Terraform week).
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Find this computer's public IP so SSH and Jenkins are only reachable from here.
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# Upload the public half of the key you generated with ssh-keygen.
# The private half never leaves your computer.
resource "aws_key_pair" "jenkins" {
  key_name   = "jenkins-key"
  public_key = file("${path.module}/jenkins-key.pub")
}

resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "SSH and Jenkins from my IP, HTTP from anywhere"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  ingress {
    description = "HTTP for the sample app"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type
  key_name               = aws_key_pair.jenkins.key_name
  vpc_security_group_ids = [aws_security_group.jenkins.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # Runs once at first boot: adds 2 GB of swap so Jenkins fits in 1 GB of RAM.
  user_data = <<-EOF
    #!/bin/bash
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  EOF

  tags = {
    Name = "jenkins-server"
  }
}

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────
# Security Group: solo abre lo necesario
#   - 22/tcp  -> SSH para que Ansible configure el servidor
#   - 1194/tcp -> OpenVPN (el enunciado pide TCP, no UDP)
# ─────────────────────────────────────────────────────────
resource "aws_security_group" "openvpn_sg" {
  name        = "paas-openvpn-sg"
  description = "SSH para administracion + OpenVPN sobre TCP/1194"

  ingress {
    description = "SSH para Ansible / administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "OpenVPN sobre TCP"
    from_port   = 1194
    to_port     = 1194
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida libre (necesaria para apt, NAT de los clientes VPN, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "paas-openvpn-sg"
    Project = "PaaS.net"
  }
}

# ─────────────────────────────────────────────────────────
# Instancia EC2 que actuará como servidor OpenVPN
# ─────────────────────────────────────────────────────────
resource "aws_instance" "openvpn_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.openvpn_sg.id]

  # El servidor hace de "switch" L2 (bridge privado) para sus
  # clientes VPN y de NAT hacia Internet, por lo que necesita
  # poder mover tráfico que no coincide con su IP/MAC original.
  source_dest_check = false

  tags = {
    Name    = "paas-openvpn-server"
    Project = "PaaS.net"
  }
}

# IP fija, para que no cambie si la instancia se reinicia
# (los .ovpn de los clientes la referencian directamente)
resource "aws_eip" "openvpn_eip" {
  instance = aws_instance.openvpn_server.id
  domain   = "vpc"

  tags = {
    Name    = "paas-openvpn-eip"
    Project = "PaaS.net"
  }
}

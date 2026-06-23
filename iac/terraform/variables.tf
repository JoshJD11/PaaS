variable "aws_region" {
  description = "Región de AWS donde se despliega el servidor VPN"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = <<-EOT
    AMI de Ubuntu 22.04 LTS para la región elegida.
    Buscar la AMI vigente en: https://cloud-images.ubuntu.com/locator/ec2/
    (filtrar por la región de aws_region y arquitectura amd64)
  EOT
  type = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t2.micro" # Elegible en el Free Tier de AWS
}

variable "key_pair_name" {
  description = "Nombre del Key Pair de EC2 ya creado en la consola de AWS (Network & Security > Key Pairs), usado para SSH"
  type        = string
}

variable "admin_cidr" {
  description = "Tu IP pública en formato CIDR (ej. 200.123.45.67/32) desde donde administrarás el servidor por SSH"
  type        = string
}

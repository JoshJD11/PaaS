# Copiar este archivo a terraform.tfvars y completar con tus datos
# NUNCA subir terraform.tfvars (con datos reales) a un repositorio público

aws_region    = "us-east-1"
ami_id        = "ami-0b6d9d3d33ba97d99" # Ver: https://cloud-images.ubuntu.com/locator/ec2/
instance_type = "t3.micro"
key_pair_name = "paas-vpn"
admin_cidr    = "177.93.3.17/32" # tu IP pública actual, ver https://ifconfig.me

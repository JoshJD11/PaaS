output "openvpn_public_ip" {
  description = "IP pública del servidor OpenVPN. Usarla en el inventario de Ansible y en los perfiles .ovpn de los clientes"
  value       = aws_eip.openvpn_eip.public_ip
}

output "ssh_command" {
  description = "Comando listo para conectarte por SSH y verificar la instancia"
  value       = "ssh -i <ruta-a-tu-llave>.pem ubuntu@${aws_eip.openvpn_eip.public_ip}"
}

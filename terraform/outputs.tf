# Salidas — Estudiante A

output "ami_ubuntu" {
  description = "AMI de Ubuntu 24.04 encontrada (prueba de humo de la Fase 0)"
  value       = data.aws_ami.ubuntu.id
}

output "ip_publica" {
  description = "IP elástica de la EC2: registro A de cms.<dominio> y 'remote' de los .ovpn"
  value       = aws_eip.vpn.public_ip
}

output "ssh" {
  description = "Comando para entrar a la EC2"
  value       = "ssh -i ${pathexpand(trimsuffix(var.ruta_llave_publica, ".pub"))} ubuntu@${aws_eip.vpn.public_ip}"
}

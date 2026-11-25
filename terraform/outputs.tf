# Salidas — Estudiante A

output "ami_ubuntu" {
  description = "AMI de Ubuntu 24.04 encontrada (prueba de humo de la Fase 0)"
  value       = data.aws_ami.ubuntu.id
}

# TODO(A) · Fase 2:
# output "ip_publica" { value = aws_eip.vpn.public_ip }   -> registro A de cms.examenpaas.tech
# output "ssh"        { value = "ssh -i ~/.ssh/examen-paas ubuntu@${aws_eip.vpn.public_ip}" }

# Versiones y proveedores — Estudiante A
# El estado es local (terraform.tfstate, ignorado por Git): hay un solo operador (A). Ver ADR-0001.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.perfil_aws

  # Etiquetas en todos los recursos: facilitan encontrar costos y limpiar la cuenta
  default_tags {
    tags = {
      Proyecto      = var.proyecto
      Curso         = "PaaS II-2026"
      Responsable   = "Estudiante A"
      GestionadoPor = "terraform"
    }
  }
}

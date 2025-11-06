# Configuración de Terraform para AWS RDS - banco
# Autor: Andrés Quispe

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC y subnet para RDS
resource "aws_db_subnet_group" "banco" {
  name       = "banco-db-subnet"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]  # Reemplazar con IDs reales

  tags = {
    Name        = "banco DB Subnet Group"
    Environment = "production"
    Project     = "DevOps-Automation"
  }
}

# Security Group para RDS
resource "aws_security_group" "rds" {
  name        = "banco-rds-sg"
  description = "Security group for banco RDS"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Solo IPs internas del banco
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "banco RDS Security Group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "banco" {
  identifier           = "banco-clientes-db"
  engine               = "postgres"
  engine_version       = "15.3"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_encrypted    = true
  
  db_name  = "banco_db"
  username = "admin"
  password = var.db_password  # Desde Secrets Manager
  
  db_subnet_group_name   = aws_db_subnet_group.banco.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = false
  final_snapshot_identifier = "banco-final-snapshot"
  
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  tags = {
    Name        = "banco Clientes DB"
    Environment = "production"
    Project     = "DevOps-Automation"
  }
}

# Variable para password (se pasa de forma segura)
variable "db_password" {
  description = "Password para RDS (desde AWS Secrets Manager)"
  type        = string
  sensitive   = true
}

# Outputs útiles
output "rds_endpoint" {
  value       = aws_db_instance.banco.endpoint
  description = "Endpoint de conexión a RDS"
}

output "rds_arn" {
  value       = aws_db_instance.banco.arn
  description = "ARN del RDS para IAM policies"
}
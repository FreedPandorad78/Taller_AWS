provider "aws" {
  region = "us-east-2" 
}

# 1. Bucket S3
resource "aws_s3_bucket" "mi_bucket" {
  bucket_prefix = "bucket-taller-aws-"
  force_destroy = true
}

# 2. Instancia EC2 (Capa gratuita)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "mi_ec2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  tags = {
    Name = "Instancia-Taller"
  }
}

# 3. Base de Datos RDS (MySQL) con Secrets Manager
resource "aws_db_instance" "mi_rds" {
  identifier                  = "rds-taller-aws"
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  username                    = "admin"
  manage_master_user_password = true # Delega la contraseña a Secrets Manager
  skip_final_snapshot         = true # Evita cobros al eliminar
  apply_immediately           = true
}
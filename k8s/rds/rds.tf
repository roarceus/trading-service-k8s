provider "aws" {
  region = var.region
}

resource "aws_db_subnet_group" "default" {
  name       = "rds-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow access to RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "trading_rds" {
  identifier             = "trading-rds"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "17.4"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}
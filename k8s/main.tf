provider "aws" {
  region = var.region
}

module "eks" {
  source       = "./eks"
  region       = var.region
  cluster_name = var.cluster_name
}

module "rds" {
  source      = "./rds"
  region      = var.region
  vpc_id      = module.eks.vpc_id
  subnet_ids  = module.eks.subnet_ids
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}

module "vpc" {
  source = "./modules/vpc"

  vpc_name           = local.names.vpc
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  enable_nat_gateway = false
  region             = var.region
  tags               = local.common_tags
}

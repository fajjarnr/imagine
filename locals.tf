locals {
  resource_prefix = trimspace(var.environment) != "" ? "${var.name_prefix}-${var.environment}" : var.name_prefix

  names = {
    vpc     = var.vpc_name != "" ? var.vpc_name : "${local.resource_prefix}-vpc"
    bastion = "${local.resource_prefix}-imagine"
  }

  common_tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      NamePrefix  = var.name_prefix
      ManagedBy   = "terraform"
    }
  )
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "security_group_id" {
  description = "The ID of the security group."
  value       = module.vpc.security_group_id
}

output "imagine_instance_id" {
  description = "The ID of the Imagine EC2 instance."
  value       = module.imagine.instance_id
}

output "imagine_public_ip" {
  description = "The public IP address of the Imagine EC2 instance."
  value       = module.imagine.instance_public_ip
}

output "imagine_private_ip" {
  description = "The private IP address of the Imagine EC2 instance."
  value       = module.imagine.instance_private_ip
}

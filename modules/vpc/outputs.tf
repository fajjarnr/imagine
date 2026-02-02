output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets."
  value       = [for key in sort(keys(aws_subnet.public)) : aws_subnet.public[key].id]
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets."
  value       = [for key in sort(keys(aws_subnet.private)) : aws_subnet.private[key].id]
}

output "security_group_id" {
  description = "The ID of the security group."
  value       = aws_security_group.main.id
}

output "vpc_endpoint_s3_id" {
  description = "The ID of the S3 VPC endpoint."
  value       = aws_vpc_endpoint.s3.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT gateway (if enabled)."
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "internet_gateway_id" {
  description = "The ID of the internet gateway."
  value       = aws_internet_gateway.main.id
}

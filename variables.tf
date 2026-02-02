variable "region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "ap-southeast-1"
}

variable "name_prefix" {
  description = "Project or team identifier used as the leading portion for all resource names."
  type        = string
  default     = "imagine"
}

variable "environment" {
  description = "Environment identifier that augments the name prefix (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_name" {
  description = "Override for the VPC Name tag. Leave empty to derive from name_prefix/environment."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "public_subnets" {
  description = "Definitions for each public subnet. If availability_zone is omitted it will be auto-assigned."
  type = list(object({
    cidr              = string
    availability_zone = optional(string)
    name_suffix       = optional(string)
  }))
  default = [
    { cidr = "10.0.0.0/20" },
    { cidr = "10.0.16.0/20" },
    { cidr = "10.0.32.0/20" }
  ]

  validation {
    condition     = length(var.public_subnets) > 0 && alltrue([for s in var.public_subnets : can(cidrnetmask(s.cidr))])
    error_message = "public_subnets must be a non-empty list of objects with valid CIDR blocks."
  }
}

variable "private_subnets" {
  description = "Definitions for each private subnet. If availability_zone is omitted it will be auto-assigned."
  type = list(object({
    cidr              = string
    availability_zone = optional(string)
    name_suffix       = optional(string)
  }))
  default = []

  validation {
    condition     = length(var.private_subnets) == 0 || alltrue([for s in var.private_subnets : can(cidrnetmask(s.cidr))])
    error_message = "private_subnets must be a list of objects with valid CIDR blocks."
  }
}

variable "imagine_public_key" {
  description = "The public key for the bastion host."
  type        = string
  sensitive   = true
}

variable "default_tags" {
  description = "Default tags to apply to all supported AWS resources."
  type        = map(string)
  default     = {}
}

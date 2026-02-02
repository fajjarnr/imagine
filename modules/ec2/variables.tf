variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "MyInstance"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "ID of the AMI to use for the instance. If not provided, a default will be chosen based on the selected OS."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "ID of the subnet to launch the instance in"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs to associate with the instance"
  type        = list(string)
}

variable "key_name" {
  description = "Name of the key pair to use for SSH access"
  type        = string
  default     = ""
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with the instance"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "The size of the root volume in GB."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "The type of the root volume."
  type        = string
  default     = "gp3"
}

variable "instance_architecture" {
  description = "The architecture of the instance (amd64 or arm64)."
  type        = string
  default     = "amd64"
}

variable "user_data" {
  description = "The user data script to run on instance launch."
  type        = string
  default     = null
}

variable "enable_ssm" {
  description = "Create and attach an IAM role and instance profile for AWS Systems Manager (SSM) access."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to resources."
  type        = map(string)
  default     = {}
}

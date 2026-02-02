locals {
  ami_arch = var.instance_architecture == "arm64" ? "arm64" : "x86_64"

  ubuntu_name_pattern = (
    var.instance_architecture == "arm64"
    ? "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"
    : "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
  )
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = [local.ubuntu_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = [local.ami_arch]
  }
}

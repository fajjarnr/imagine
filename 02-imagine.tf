resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-key"
  public_key = var.imagine_public_key
}

module "bastion" {
  source = "./modules/ec2"

  instance_name               = local.names.bastion
  instance_type               = "g5g.xlarge"
  instance_architecture       = "arm64"
  root_volume_size            = 100
  root_volume_type            = "gp3"
  key_name                    = aws_key_pair.bastion_key.key_name
  subnet_id                   = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [module.vpc.security_group_id]
  associate_public_ip_address = true
  enable_ssm                  = true
  tags                        = local.common_tags
  user_data                   = <<-EOF
    #!/bin/bash
    set -e

    # Redirect output for debugging
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "Starting setup for Imagine EC2..."

    # 1. Update and install basic dependencies
    apt-get update && apt-get upgrade -y
    apt-get install -y linux-headers-$(uname -r) build-essential wget curl git bc

    # 2. Install NVIDIA Driver & CUDA 13.1 (Ubuntu 24.04 ARM64)
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
    apt-get update
    apt-get -y install cuda-drivers cuda-toolkit-13-1

    # Setup Environment for all users
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> /etc/profile.d/cuda.sh
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> /etc/profile.d/cuda.sh
    source /etc/profile.d/cuda.sh

    # 3. Setup Python & ai-tools (using uv)
    sudo -u ubuntu curl -LsSf https://astral.sh/uv/install.sh | sudo -u ubuntu sh

    # Setup folders
    mkdir -p /home/ubuntu/ai-tools
    chown ubuntu:ubuntu /home/ubuntu/ai-tools

    # 4. Clone ComfyUI & Setup (as ubuntu user)
    sudo -u ubuntu -i bash << 'EOT'
    cd ~/ai-tools
    ~/.local/bin/uv venv flux-env --python 3.12
    source flux-env/bin/activate

    # Install PyTorch with CUDA support
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

    # Clone ComfyUI
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    uv pip install -r requirements.txt

    # Install ComfyUI Manager
    cd custom_nodes
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    cd ..
    EOT


    echo "Setup Complete! ComfyUI is ready. Rebooting to apply driver changes..."
    reboot
  EOF
  # Catatan: Bila hanya ingin akses via SSM Session Manager,
  # Anda bisa menonaktifkan SSH key dengan menghapus/komentari "key_name".

  depends_on = [module.vpc]
}

# FLUX.2-dev + Wan2.1 I2V Deployment Guide for Windows 11 + WSL2 + NVIDIA RTX 4060

Panduan lengkap untuk men-deploy **FLUX.2-dev GGUF** (Image Generation) dan **Wan2.1 I2V** (Image-to-Video) di Windows 11 menggunakan WSL2 dengan GPU NVIDIA RTX 4060.

> **Image Generation:** [`unsloth/FLUX.2-dev-GGUF`](https://huggingface.co/unsloth/FLUX.2-dev-GGUF) (Q4_K_M)
> **Video Generation:** [`Wan-AI/Wan2.1-I2V-14B-480P`](https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-480P) (GGUF format tersedia)

> **Pipeline:** Generate image dengan FLUX → Generate video dengan Wan2.1 I2V

> **Kenapa GGUF format?**
>
> - **Hemat VRAM**: FLUX ~4-5GB, Wan2.1 ~6-7GB (bisa bergantian)
> - **Speed lebih cepat**: Quantized inference optimal untuk RTX 4060
> - **Kualitas tetap bagus**: Q4_K_M memberikan balance sempurna
> - **Cocok untuk RTX 4060 8GB**: Tidak perlu `--lowvram` mode

> **Kenapa Native WSL2 lebih mudah dari Docker?**
>
> - Tidak perlu konfigurasi Docker Desktop yang berat
> - Direct GPU access tanpa layer container
> - Lebih mudah troubleshooting dan modifikasi
> - Performa lebih optimal untuk VRAM 8GB RTX 4060

---

## 📋 System Requirements

| Komponen | Minimum              | Recommended             |
| -------- | -------------------- | ----------------------- |
| GPU      | NVIDIA RTX 3060 12GB | **NVIDIA RTX 4060 8GB** |
| VRAM     | 8GB                  | 8GB+                    |
| RAM      | 16GB                 | 32GB                    |
| Storage  | 50GB SSD             | 100GB+ NVMe SSD         |
| OS       | Windows 11 22H2+     | Windows 11 24H2         |

---

## 🚀 Quick Start

```bash
# 1. Clone repository ini dan masuk ke direktori
# 2. Ikuti langkah-langkah di bawah
```

---

## 🔧 Step 1: Setup WSL2 dan CUDA

### 1.1 Install/Update WSL2

Buka PowerShell sebagai Administrator:

```powershell
# Install WSL2 dengan Ubuntu 22.04
wsl --install -d Ubuntu-22.04

# Atau update existing WSL
wsl --update

# Set WSL2 sebagai default
wsl --set-default-version 2
```

### 1.2 Konfigurasi WSL2 (`.wslconfig`)

File `.wslconfig` Anda perlu **DIUPDATE** untuk FLUX.2-dev. Konfigurasi saat ini (8GB RAM) terlalu kecil.

Buka file `.wslconfig` di Windows (bukan di WSL):

```powershell
notepad "$env:USERPROFILE\.wslconfig"
```

**Update ke konfigurasi berikut:**

```ini
[wsl2]
# RAM untuk WSL2 - Dengan RAM 16GB fisik, alokasikan 12GB untuk WSL
memory=12GB

# CPU cores - bisa pakai semua core atau sisakan untuk Windows
processors=6

# Swap file - Naikkan untuk membantu ketika VRAM penuh
swap=8GB
swapFile=C:\\temp\\wsl-swap.vhdx

# Enable localhost forwarding untuk akses ComfyUI dari Windows
localhostForwarding=true

# GPU support
gpuSupport=true

# Kernel command line untuk memory management
kernelCommandLine = cgroup_memory=1
```

> **Penjelasan perubahan:**
>
> - `memory=16GB`: FLUX perlu RAM besar untuk model offload ketika VRAM 8GB penuh
> - `swap=8GB`: Swap membantu mencegah OOM ketika generate image besar
> - `processors=6`: Beri ruang untuk Windows (jika total 8 core)

Setelah edit, restart WSL2:

```powershell
wsl --shutdown
wsl
```

### 1.3 Install NVIDIA CUDA di WSL2 (Recommended Method)

Masuk ke WSL2 Ubuntu:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y build-essential dkms

# Hapus GPG key lama (jika ada) sesuai saran NVIDIA
sudo apt-key del 7fa2af80

# Setup NVIDIA Network Repository untuk WSL-Ubuntu
# Ini adalah metode paling bersih dan selalu up-to-date
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# Install CUDA Toolkit (hanya toolkit, tidak boleh install driver di dalam WSL)
# Versi 13.1 adalah yang terbaru saat ini
sudo apt-get -y install cuda-toolkit-13-1

# Setup environment variables
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Verifikasi instalasi
nvidia-smi
nvcc --version
```

> [!IMPORTANT]
> **HANYA** install `cuda-toolkit`. Jangan pernah memilih paket `cuda`, `cuda-12-x`, atau `cuda-drivers` di dalam WSL karena akan mencoba menginstal driver Linux yang akan konflik dengan driver Windows host.

---

## 🐍 Step 3: Setup Python Environment

```bash
# Install uv (Python manager super cepat)
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env  # atau restart terminal

# Buat virtual environment dengan uv
mkdir -p ~/ai-tools && cd ~/ai-tools
uv venv flux-env --python 3.12
source flux-env/bin/activate

# Install dependencies utama dengan uv
uv pip install --upgrade pip setuptools wheel
```

---

## 🎨 Step 4: Install ComfyUI

### 3.1 Clone dan Setup ComfyUI

```bash
cd ~/ai-tools

# Clone ComfyUI
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Install dependencies dengan uv
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
uv pip install -r requirements.txt

# Install additional packages untuk FLUX
uv pip install transformers accelerate safetensors huggingface-hub
uv pip install xformers  # Optional: untuk optimasi memori
```

### 3.2 Install ComfyUI Manager (Recommended)

```bash
cd ~/ai-tools/ComfyUI/custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager.git
```

---

## 📥 Step 5: Download FLUX.2-dev-GGUF Model

### 5.0 Direct Download Links (Recommended for Manual Transfer)

Jika Anda ingin mendownload model di PC lain kemudian di-copas ke WSL2, gunakan link berikut:

**A. Model Utama (Taruh di: `ComfyUI/models/diffusion_models/`)**

- [FLUX.2-dev GGUF Q4_K_M (8.2 GB)](https://huggingface.co/unsloth/FLUX.2-dev-GGUF/resolve/main/flux2-dev-Q4_K_M.gguf)
- [Wan 2.2 I2V High Noise GGUF Q4_K_M (9.1 GB)](https://huggingface.co/bullerwins/Wan2.2-I2V-A14B-GGUF/resolve/main/wan2.2_i2v_high_noise_14B_Q4_K_M.gguf)
- [Wan 2.2 I2V Low Noise GGUF Q4_K_M (9.1 GB)](https://huggingface.co/bullerwins/Wan2.2-I2V-A14B-GGUF/resolve/main/wan2.2_i2v_low_noise_14B_Q4_K_M.gguf)

**B. Text Encoders & CLIP (Taruh di: `ComfyUI/models/clip/` atau `models/text_encoders/`)**

- [Wan UMT5-XXL fp8 (9.7 GB)](https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors)
- [FLUX T5XXL GGUF (3.2 GB)](https://huggingface.co/unsloth/FLUX.2-dev-GGUF/resolve/main/t5xxl.gguf)
- [FLUX CLIP-L (246 MB)](https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors)

**C. VAE & LoRA (Taruh di folder masing-masing)**

- [Wan VAE (240 MB)](https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors) di `models/vae/`
- [Wan 2.2 High Noise LoRA](https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/high_noise_model.safetensors) di `models/loras/`
- [Wan 2.2 Low Noise LoRA](https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/low_noise_model.safetensors) di `models/loras/`

### 5.1 Setup Hugging Face CLI

```bash
# Install Hugging Face CLI dengan uv (lebih cepat)
uv pip install huggingface-hub[cli]

# Login (butuh token dari https://huggingface.co/settings/tokens)
huggingface-cli login
```

> ⚠️ **PENTING**: Meskipun GGUF adalah format open, tetap disarankan login ke HuggingFace untuk avoid rate limits.

### 5.2 Download GGUF Model Files

```bash
# Buat direktori untuk model GGUF
cd ~/ai-tools/ComfyUI
mkdir -p models/diffusion_models models/vae models/clip

# Download FLUX.2-dev GGUF model (Q4_K_M - recommended untuk RTX 4060)
# File size: ~8GB vs ~23GB untuk original FP16
huggingface-cli download unsloth/FLUX.2-dev-GGUF \
  flux2-dev-Q4_K_M.gguf \
  --local-dir models/diffusion_models \
  --local-dir-use-symlinks False

# Alternative quality options (pilih salah satu):
# Q2_K - ~5GB, fastest, lowest quality (tidak disarankan)
# Q3_K_M - ~6GB, good speed/quality balance
# Q4_K_M - ~8GB, RECOMMENDED untuk RTX 4060 ⭐
# Q5_K_M - ~10GB, higher quality, butuh lebih banyak VRAM
# Q8_0 - ~15GB, near FP16 quality, hanya jika VRAM cukup

# Download VAE (sama untuk semua format)
huggingface-cli download black-forest-labs/FLUX.2-dev \
  ae.safetensors \
  --local-dir models/vae \
  --local-dir-use-symlinks False

# Download CLIP Models (T5 dalam format GGUF lebih hemat VRAM)
huggingface-cli download unsloth/FLUX.2-dev-GGUF \
  t5xxl.gguf \
  --local-dir models/clip \
  --local-dir-use-symlinks False

# Download CLIP-L (standard)
huggingface-cli download comfyanonymous/flux_text_encoders \
  clip_l.safetensors \
  --local-dir models/clip \
  --local-dir-use-symlinks False
```

### 5.3 Alternative: Download via wget/curl

Jika HuggingFace CLI bermasalah:

```bash
cd ~/ai-tools/ComfyUI/models

# Buat direktori
mkdir -p diffusion_models vae clip

# Download GGUF model (Q4_K_M)
wget -O diffusion_models/flux2-dev-Q4_K_M.gguf \
  "https://huggingface.co/unsloth/FLUX.2-dev-GGUF/resolve/main/flux2-dev-Q4_K_M.gguf"

# Download VAE
wget -O vae/ae.safetensors \
  "https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/ae.safetensors"

# Download CLIP models
wget -O clip/t5xxl.gguf \
  "https://huggingface.co/unsloth/FLUX.2-dev-GGUF/resolve/main/t5xxl.gguf"

wget -O clip/clip_l.safetensors \
  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
```

### 5.4 Verifikasi Download

```bash
# Cek ukuran file
cd ~/ai-tools/ComfyUI/models
ls -lh diffusion_models/
ls -lh vae/
ls -lh clip/

# Expected sizes:
# flux2-dev-Q4_K_M.gguf: ~8.2 GB
# ae.safetensors: ~335 MB
# t5xxl.gguf: ~3.2 GB
# clip_l.safetensors: ~246 MB
```

---

## ⚙️ Step 6: Install ComfyUI-GGUF Node (REQUIRED)

Untuk menggunakan model GGUF di ComfyUI, Anda perlu menginstall custom node khusus:

### 6.1 Install ComfyUI-GGUF Node

```bash
cd ~/ai-tools/ComfyUI/custom_nodes

# Clone repository ComfyUI-GGUF
git clone https://github.com/city96/ComfyUI-GGUF.git
cd ComfyUI-GGUF

# Install dependencies dengan uv (lebih cepat)
uv pip install -r requirements.txt
```

### 6.2 Buat Configuration File

```bash
cd ~/ai-tools/ComfyUI
mkdir -p user

# Buat file konfigurasi untuk optimasi VRAM
cat > user/extra_model_paths.yaml << 'EOF'
# Extra model paths configuration
comfyui:
    base_path: /home/$USER/ai-tools/ComfyUI
    checkpoints: models/checkpoints/
    clip: models/clip/
    clip_vision: models/clip_vision/
    configs: models/configs/
    controlnet: models/controlnet/
    diffusion_models: models/diffusion_models/
    embeddings: models/embeddings/
    loras: models/loras/
    upscale_models: models/upscale_models/
    vae: models/vae/
    unet: models/unet/
EOF
```

### 6.3 Launch Script untuk GGUF

```bash
cd ~/ai-tools/ComfyUI

# Buat launch script
cat > launch-flux-gguf.sh << 'EOF'
#!/bin/bash

# FLUX.2-dev-GGUF Launch Script untuk RTX 4060 8GB
# GGUF format: lebih hemat VRAM, tidak perlu --lowvram

cd ~/ai-tools/ComfyUI
source ~/ai-tools/flux-env/bin/activate

# Environment variables untuk optimasi
export PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:512"
export CUDA_VISIBLE_DEVICES=0

# Launch ComfyUI
# Untuk GGUF, kita tidak perlu --lowvram karena model sudah quantized
python main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --preview-method auto \
  "$@"
EOF

chmod +x launch-flux-gguf.sh
```

> **Catatan untuk GGUF:**
>
> - Tidak perlu `--lowvram` karena model Q4_K_M hanya butuh ~4-5GB VRAM
> - Tidak perlu `--fp8_e4m3fn-unet` karena GGUF sudah quantized
> - Performa lebih cepat karena tidak ada overhead dequantization real-time

---

## 🎬 Step 7: Menjalankan ComfyUI dengan FLUX.2-dev

### 6.1 Start ComfyUI

```bash
cd ~/ai-tools/ComfyUI
./launch-flux.sh
```

### 6.2 Akses dari Windows

Buka browser di Windows:

```
http://localhost:8188
```

Atau gunakan IP WSL:

```bash
# Cek IP WSL
ip addr | grep eth0
# Akses via http://<WSL_IP>:8188
```

---

## 🖼️ Step 8: Workflow FLUX.2-dev-GGUF di ComfyUI

### 8.1 Basic FLUX-GGUF Workflow

Setelah install ComfyUI-GGUF node, workflow sedikit berbeda:

1. **Load Diffusion Model**: Gunakan node `GGUFLoader` (dari ComfyUI-GGUF)
   - Model: `flux2-dev-Q4_K_M.gguf`
2. **Load CLIP**: Gunakan `DualCLIPLoaderGGUF` untuk T5 GGUF
   - clip_name1: `clip_l.safetensors`
   - clip_name2: `t5xxl.gguf`
   - type: `flux`
3. **VAELoader**: Load `ae.safetensors`

4. **EmptySD3LatentImage**: Set resolution (rekomendasi: 1024x1024 atau 768x1344)

5. **CLIPTextEncode**: Masukkan prompt positif dan negatif

6. **KSampler**: Setting:
   - Steps: 20-28 (Q4_K_M bisa turun ke 20 steps dengan kualitas bagus)
   - CFG: 1.0 (FLUX tidak menggunakan CFG tradisional)
   - Sampler: euler
   - Scheduler: normal
7. **VAEDecode**: Decode latent ke image

### 8.2 Workflow JSON Example

```json
{
  "last_node_id": 15,
  "last_link_id": 20,
  "nodes": [
    {
      "id": 1,
      "type": "GGUFLoader",
      "widgets_values": ["flux2-dev-Q4_K_M.gguf"]
    },
    {
      "id": 2,
      "type": "DualCLIPLoaderGGUF",
      "widgets_values": ["clip_l.safetensors", "t5xxl.gguf", "flux"]
    }
  ]
}
```

### 7.2 Download Pre-made Workflows

```bash
# Buat direktori workflows
mkdir -p ~/ai-tools/ComfyUI/workflows

# Contoh workflow FLUX bisa didownload dari:
# https://comfyanonymous.github.io/ComfyUI_examples/flux/
```

---

## 🔥 Optimasi Performa untuk RTX 4060 dengan GGUF

### Memory Optimization Tips (GGUF Q4_K_M)

| Setting    | Value       | Keterangan                            |
| ---------- | ----------- | ------------------------------------- |
| Format     | GGUF Q4_K_M | Hemat 60% VRAM vs FP16                |
| Resolution | 1024x1024   | Optimal untuk 8GB                     |
| Batch Size | 1-2         | Bisa batch kecil dengan GGUF          |
| --lowvram  | Tidak perlu | GGUF sudah hemat VRAM                 |
| VRAM Usage | ~4-5GB      | Sisa VRAM untuk resolusi lebih tinggi |

### Expected Performance (GGUF Q4_K_M)

| Resolution | Steps | Time | VRAM Usage |
| ---------- | ----- | ---- | ---------- |
| 512x512    | 20    | ~10s | ~4GB       |
| 1024x1024  | 20    | ~30s | ~5GB       |
| 1024x1024  | 28    | ~40s | ~5GB       |
| 1344x768   | 20    | ~35s | ~5.5GB     |
| 1536x1024  | 28    | ~55s | ~6GB       |

### Perbandingan: FP8 vs GGUF Q4_K_M

| Metric     | FP8    | GGUF Q4_K_M       | Winner |
| ---------- | ------ | ----------------- | ------ |
| VRAM Usage | ~7.5GB | ~5GB              | GGUF   |
| Quality    | 95%    | 90%               | FP8    |
| Speed      | 1x     | 1.2x              | GGUF   |
| File Size  | ~17GB  | ~8GB              | GGUF   |
| Setup      | Simple | Butuh custom node | FP8    |

> **Rekomendasi**: Untuk RTX 4060 8GB, GGUF Q4_K_M adalah pilihan terbaik untuk daily use. Gunakan FP8 hanya jika butuh kualitas maksimal.

---

## 🛠️ Troubleshooting

### Issue: CUDA Out of Memory

```bash
# Solusi 1: Gunakan --lowvram
python main.py --lowvram

# Solusi 2: Turunkan resolution
# Gunakan 768x768 atau 512x512

# Solusi 3: Gunakan --normalvram
python main.py --normalvram
```

### Issue: Model tidak muncul di ComfyUI

```bash
# Verifikasi struktur direktori untuk GGUF
ls -la ~/ai-tools/ComfyUI/models/diffusion_models/
ls -la ~/ai-tools/ComfyUI/models/vae/
ls -la ~/ai-tools/ComfyUI/models/clip/

# Pastikan file .gguf dan .safetensors ada
# File GGUF harus di direktori diffusion_models, bukan unet
```

### Issue: GGUF Loader tidak muncul di ComfyUI

```bash
# Verifikasi ComfyUI-GGUF terinstall dengan benar
cd ~/ai-tools/ComfyUI/custom_nodes/ComfyUI-GGUF
ls -la

# Reinstall jika perlu
cd ~/ai-tools/ComfyUI/custom_nodes
rm -rf ComfyUI-GGUF
git clone https://github.com/city96/ComfyUI-GGUF.git
cd ComfyUI-GGUF
pip install -r requirements.txt

# Restart ComfyUI
```

### Issue: CUDA tidak terdeteksi

```bash
# Verifikasi NVIDIA driver
nvidia-smi

# Verifikasi PyTorch CUDA
python -c "import torch; print(torch.cuda.is_available())"

# Reinstall PyTorch dengan CUDA support menggunakan uv
uv pip uninstall torch torchvision torchaudio
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
```

### Issue: HuggingFace Access Denied

```bash
# Re-login
huggingface-cli logout
huggingface-cli login

# Verifikasi token
huggingface-cli whoami

# Accept license di website HuggingFace terlebih dahulu
```

---

## 📁 Directory Structure (FLUX + Wan2.1 Setup)

```
~/ai-tools/
├── flux-env/                 # Python virtual environment
└── ComfyUI/
    ├── models/
    │   ├── diffusion_models/     # GGUF models di sini
    │   │   ├── flux2-dev-Q4_K_M.gguf       # FLUX Image Gen
    │   │   └── wan2.1-i2v-14b-480p-Q4_K_M.gguf  # Wan2.1 Video Gen
    │   ├── vae/
    │   │   ├── ae.safetensors              # FLUX VAE
    │   │   └── wan_2.1_vae.safetensors     # Wan2.1 VAE
    │   ├── clip/
    │   │   ├── clip_l.safetensors          # FLUX CLIP-L
    │   │   └── t5xxl.gguf                  # FLUX T5 (GGUF)
    │   ├── clip_vision/
    │   │   └── model.safetensors           # CLIP Vision untuk I2V
    │   └── text_encoders/
    │       └── umt5-xxl.safetensors        # Wan2.1 Text Encoder
    ├── custom_nodes/
    │   ├── ComfyUI-Manager/
    │   ├── ComfyUI-GGUF/                   # REQUIRED untuk GGUF support
    │   └── ComfyUI-WanVideoWrapper/        # REQUIRED untuk Wan2.1
    ├── workflows/
    ├── launch-flux-gguf.sh
    └── user/
```

---

## 🔄 Update dan Maintenance

### Update ComfyUI

```bash
cd ~/ai-tools/ComfyUI
git pull
uv pip install -r requirements.txt --upgrade
```

### Update Models

```bash
# Re-download GGUF model jika ada update
cd ~/ai-tools/ComfyUI

huggingface-cli download unsloth/FLUX.2-dev-GGUF \
  flux2-dev-Q4_K_M.gguf \
  --local-dir models/diffusion_models \
  --local-dir-use-symlinks False
```

---

## ☁️ Alternatif: Deploy di AWS EC2 G6.xlarge (Ubuntu)

Jika Anda ingin menjalankan FLUX + Wan2.1 di cloud, AWS EC2 G6.xlarge adalah pilihan yang bagus dengan GPU NVIDIA L4 (24GB VRAM).

### Spesifikasi AWS EC2 G6.xlarge

| Komponen | Spec                        |
| -------- | --------------------------- |
| GPU      | NVIDIA L4 (24GB VRAM)       |
| vCPU     | 4                           |
| RAM      | 16GB                        |
| Storage  | EBS (rekomendasi 100GB+)    |
| Biaya    | ~$0.80-1.20/jam (on-demand) |

### Setup AWS EC2 G6.xlarge

#### 1. Launch Instance

```bash
# Gunakan AMI: Ubuntu 24.04 LTS dengan NVIDIA drivers
# Instance type: g6.xlarge
# Storage: 100GB GP3 SSD
# Security Group: Allow port 22 (SSH) dan 8188 (ComfyUI)
```

#### 2. Install NVIDIA Drivers & CUDA (Ubuntu Native)

```bash
# SSH ke instance
ssh -i your-key.pem ubuntu@<ec2-public-ip>

# Update system
sudo apt update && sudo apt upgrade -y

# Install NVIDIA drivers (Ubuntu 24.04)
sudo apt install -y linux-headers-$(uname -r)
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-drivers

# Reboot
sudo reboot

# Verifikasi setelah reboot
nvidia-smi
```

#### 3. Install CUDA Toolkit

```bash
# Install CUDA Toolkit 13.1
sudo apt-get install -y cuda-toolkit-13-1

# Setup environment
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

nvcc --version
```

#### 4. Setup Python & ComfyUI dengan uv (Sama dengan WSL2)

```bash
# Install Python 3.12 dan uv
sudo apt install -y python3.12 python3.12-venv python3.12-dev python3-pip git wget curl

# Install uv (Python package manager super cepat)
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env

# Setup environment dengan uv
mkdir -p ~/ai-tools && cd ~/ai-tools
uv venv flux-env --python 3.12
source flux-env/bin/activate

# Install PyTorch dengan CUDA support menggunakan uv
# CUDA 12.6 binaries compatible dengan driver 13.1
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

# Clone dan setup ComfyUI
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
uv pip install -r requirements.txt

# Install custom nodes
cd custom_nodes
git clone https://github.com/city96/ComfyUI-GGUF.git
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

# Install dependencies custom nodes dengan uv
cd ComfyUI-GGUF && uv pip install -r requirements.txt
cd ../ComfyUI-WanVideoWrapper && uv pip install -r requirements.txt
```

#### 5. Keuntungan G6.xlarge vs RTX 4060 Local

| Feature            | RTX 4060 8GB | AWS L4 24GB           |
| ------------------ | ------------ | --------------------- |
| VRAM               | 8GB          | **24GB**              |
| Bisa FP16?         | Tidak        | **Ya**                |
| Bisa batch besar?  | Tidak        | **Ya**                |
| Higher resolution? | 1024px max   | **1536px+**           |
| Wan2.1 720P?       | Tidak        | **Ya**                |
| Persistent?        | Ya           | Perlu manage instance |
| Biaya              | Listrik      | ~$0.80-1.20/jam       |

#### 6. Download Models (Bisa pakai FP16 di L4!)

Dengan 24GB VRAM, Anda bisa menggunakan model FP16 untuk kualitas maksimal:

```bash
cd ~/ai-tools/ComfyUI

# FLUX FP16 (kualitas terbaik)
huggingface-cli download black-forest-labs/FLUX.2-dev \
  flux2-dev.safetensors \
  --local-dir models/unet

# Atau tetap GGUF untuk hemat storage
# huggingface-cli download unsloth/FLUX.2-dev-GGUF \
#   flux2-dev-Q4_K_M.gguf \
#   --local-dir models/diffusion_models

# Wan2.1 I2V 720P (hanya bisa di L4, tidak di RTX 4060)
huggingface-cli download Wan-AI/Wan2.1-I2V-14B-720P \
  diffusion_pytorch_model.safetensors \
  --local-dir models/diffusion_models
```

#### 7. Launch Script untuk EC2

```bash
cat > launch-comfyui-ec2.sh << 'EOF'
#!/bin/bash
cd ~/ai-tools/ComfyUI
source ~/ai-tools/flux-env/bin/activate

# Untuk EC2 dengan public IP, bind ke 0.0.0.0
python main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --preview-method auto
EOF

chmod +x launch-comfyui-ec2.sh
```

#### 8. Security Group Settings

Buka port 8188 di AWS Security Group:

```bash
# Di AWS Console atau CLI
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 8188 \
  --cidr 0.0.0.0/0  # Atau restrict ke IP Anda saja
```

#### 9. Access ComfyUI dari Browser

```
http://<ec2-public-ip>:8188
```

#### 10. Auto-shutdown Script (Hemat Biaya)

```bash
# Buat script untuk auto-shutdown jika idle
sudo tee /usr/local/bin/check-idle.sh > /dev/null << 'EOF'
#!/bin/bash
# Shutdown jika GPU idle selama 30 menit
IDLE_TIME=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum/NR}')
if (( $(echo "$IDLE_TIME < 5" | bc -l) )); then
  shutdown -h +5 "GPU idle detected. Shutting down in 5 minutes."
fi
EOF

chmod +x /usr/local/bin/check-idle.sh

# Add to crontab (check every 10 minutes)
(crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/check-idle.sh") | crontab -
```

---

## 📚 Referensi

### FLUX

- [FLUX.2-dev HuggingFace](https://huggingface.co/black-forest-labs/FLUX.2-dev)
- [FLUX.2-dev-GGUF HuggingFace](https://huggingface.co/unsloth/FLUX.2-dev-GGUF)
- [ComfyUI-GGUF Node](https://github.com/city96/ComfyUI-GGUF)

### Wan2.1 Video

- [Wan2.1 I2V 14B HuggingFace](https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-480P)
- [Wan2.1 I2V GGUF](https://huggingface.co/city96/Wan2.1-I2V-14B-480P-gguf)
- [ComfyUI-WanVideoWrapper](https://github.com/kijai/ComfyUI-WanVideoWrapper)
- [Wan-AI Official](https://github.com/Wan-Video)

### AWS EC2

- [AWS EC2 G6 Instances](https://aws.amazon.com/ec2/instance-types/g6/)
- [NVIDIA L4 Tensor Core GPU](https://www.nvidia.com/en-us/data-center/l4/)
- [AWS Deep Learning AMI](https://aws.amazon.com/releasenotes/aws-deep-learning-ami/)

### General

- [ComfyUI Official](https://github.com/comfyanonymous/ComfyUI)
- [ComfyUI FLUX Examples](https://comfyanonymous.github.io/ComfyUI_examples/flux/)
- [NVIDIA CUDA on WSL](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)
- [Reference: ultra-fast-image-gen](https://github.com/newideas99/ultra-fast-image-gen)
- [Reference: comfyui-blackwell-docker](https://github.com/ChiefNakor/comfyui-blackwell-docker)

---

## 📝 License Notes

### FLUX.2-dev

FLUX.2-dev memerlukan acceptance of license dari Black Forest Labs. Model ini tidak boleh digunakan untuk:

- Illegal activities
- Creating non-consensual intimate imagery
- Creating hateful or harassing content
- Creating content that exploits or harms minors

### Wan2.1

Wan2.1 model subject to their respective licenses. Check [Wan-AI HuggingFace](https://huggingface.co/Wan-AI) for details.

---

## 📥 Step 9: Download Wan2.1 I2V Model (Optional - untuk Video Generation)

Jika Anda ingin generate video dari image yang dibuat FLUX:

### 9.1 Install ComfyUI-WanVideoWrapper

```bash
cd ~/ai-tools/ComfyUI/custom_nodes

# Clone Wan Video Wrapper
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
cd ComfyUI-WanVideoWrapper

# Install dependencies dengan uv (lebih cepat)
uv pip install -r requirements.txt
```

### 9.2 Download Wan2.1 I2V Models

```bash
cd ~/ai-tools/ComfyUI
mkdir -p models/diffusion_models models/text_encoders models/vae

# Download Wan2.1 I2V 14B 480P (GGUF format untuk hemat VRAM)
# Gunakan GGUF version untuk RTX 4060 8GB

# Download Wan2.2 I2V (Terbaru & Lebih Bagus)
# GGUF version sangat disarankan untuk RTX 4060 8GB
huggingface-cli download city96/Wan2.1-I2V-14B-480P-gguf \
  wan2.1-i2v-14b-480p-Q4_K_M.gguf \
  --local-dir models/diffusion_models \
  --local-dir-use-symlinks False

# Wan 2.2 GGUF (Jika ingin mencoba versi terbaru)
# huggingface-cli download bullerwins/Wan2.2-I2V-A14B-GGUF \
#   Wan2.2-I2V-A14B-Q4_K_M.gguf \
...

# Alternative: Download FP16 (butuh lebih banyak VRAM ~10GB+)
# huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
#   diffusion_pytorch_model.safetensors \
#   --local-dir models/diffusion_models \
#   --local-dir-use-symlinks False

# Download Text Encoder (UMT5 - sama untuk semua Wan models)
huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
  umt5-xxl.safetensors \
  --local-dir models/text_encoders \
  --local-dir-use-symlinks False

# Download VAE
huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
  wan_2.1_vae.safetensors \
  --local-dir models/vae \
  --local-dir-use-symlinks False

# Download CLIP Vision (untuk I2V - image conditioning)
huggingface-cli download openai/clip-vit-large-patch14 \
  model.safetensors \
  --local-dir models/clip_vision \
  --local-dir-use-symlinks False
```

### 9.3 Alternative Download via wget

```bash
cd ~/ai-tools/ComfyUI/models

# Wan2.1 I2V GGUF
wget -O diffusion_models/wan2.1-i2v-14b-480p-Q4_K_M.gguf \
  "https://huggingface.co/city96/Wan2.1-I2V-14B-480P-gguf/resolve/main/wan2.1-i2v-14b-480p-Q4_K_M.gguf"

# Text Encoder
wget -O text_encoders/umt5-xxl.safetensors \
  "https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-480P/resolve/main/umt5-xxl.safetensors"

# VAE
wget -O vae/wan_2.1_vae.safetensors \
  "https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-480P/resolve/main/wan_2.1_vae.safetensors"
```

### 9.4 Verifikasi Wan2.1 Files

```bash
# Cek ukuran file
ls -lh models/diffusion_models/wan2.1*
ls -lh models/text_encoders/umt5*
ls -lh models/vae/wan*

# Expected sizes (GGUF):
# wan2.1-i2v-14b-480p-Q4_K_M.gguf: ~9GB
# umt5-xxl.safetensors: ~9.7GB
# wan_2.1_vae.safetensors: ~240MB
```

---

## 🎬 Step 10: Workflow Wan2.1 I2V di ComfyUI

### 10.1 Basic I2V Workflow

1. **Load Image**: Load image yang sudah digenerate FLUX (atau image apapun)
2. **WanVideoSampler**: Node utama untuk video generation
   - Model: `wan2.1-i2v-14b-480p-Q4_K_M.gguf`
   - Text Encoder: `umt5-xxl.safetensors`
   - VAE: `wan_2.1_vae.safetensors`
3. **Settings**:
   - Resolution: 480x832 atau 832x480 (480P model)
   - Frames: 81 frames (~3 detik pada 27fps)
   - Steps: 20-30
   - CFG: 6.0-7.0
4. **VideoCombine**: Combine frames menjadi video file

### 10.2 Workflow Pipeline: FLUX → Wan2.1

```
[FLUX Image Gen] → [Save Image] → [Load Image] → [Wan2.1 I2V] → [Video Output]
     │                                                        │
     └─ Prompt: "A cat dancing..."                    Prompt: "The cat dances..."
     └─ Resolution: 832x480                           Frames: 81
     └─ Model: flux2-dev-Q4_K_M.gguf                  Model: wan2.1-i2v-Q4_K_M.gguf
```

### 10.3 Tips untuk I2V

- **Image size**: Sesuaikan dengan aspect ratio video (480P = 480x832 atau 832x480)
- **Motion**: Prompt harus mendeskripsikan motion/gerakan
- **Consistency**: Gunakan seed yang sama untuk konsistensi karakter
- **VRAM Management**: Generate FLUX image dulu, restart ComfyUI, baru load Wan2.1

---

## 🔥 Optimasi Performa: FLUX + Wan2.1

### VRAM Management Strategy

| Mode           | Model         | VRAM Usage  | Notes                        |
| -------------- | ------------- | ----------- | ---------------------------- |
| Image Gen Only | FLUX Q4_K_M   | ~5GB        | Bisa batch 2-3 images        |
| Video Gen Only | Wan2.1 Q4_K_M | ~6-7GB      | 480P, 81 frames              |
| Sequential     | Both          | ~5GB → ~7GB | Restart ComfyUI antara tasks |

### Recommended Workflow

1. **Generate Images** dengan FLUX (batch beberapa image)
2. **Save images** ke folder
3. **Restart ComfyUI** (clear VRAM)
4. **Load Wan2.1** dan generate video dari image pilihan

### Expected Performance (RTX 4060 8GB)

| Task       | Resolution   | Steps | Time      | VRAM   |
| ---------- | ------------ | ----- | --------- | ------ |
| FLUX Image | 1024x1024    | 20    | ~30s      | ~5GB   |
| FLUX Image | 832x480      | 20    | ~25s      | ~4.5GB |
| Wan2.1 I2V | 480x832, 81f | 20    | ~5-8 min  | ~6.5GB |
| Wan2.1 I2V | 480x832, 81f | 30    | ~8-12 min | ~6.5GB |

---

## 💡 Tips untuk FLUX + Wan2.1

### FLUX Image Generation

1. **GGUF Q4_K_M adalah sweet spot**: Kualitas 90% dari FP16 tapi hanya 50% VRAM usage
2. **Prompt Engineering**: FLUX sangat responsif terhadap prompt yang deskriptif dan panjang
3. **Resolution**: Untuk I2V, generate image dengan aspect ratio yang sama dengan target video
4. **Batch Processing**: GGUF memungkinkan batch 2-3 images untuk resolusi kecil

### Wan2.1 Video Generation

1. **Motion Prompt**: Deskripsikan gerakan dengan jelas ("the cat jumps gracefully")
2. **Frame Count**: 81 frames = ~3 detik, cukup untuk short clips
3. **VRAM Management**: Selalu restart ComfyUI sebelum switch model
4. **Image Prep**: Crop/resize image ke 480x832 atau 832x480 sebelum I2V

### General Tips

1. **Monitoring**: Gunakan `watch -n 1 nvidia-smi` untuk real-time VRAM monitoring
2. **Model Switching**: Jangan load FLUX dan Wan2.1 bersamaan (OOM risk)
3. **Storage**: Setiap video 81 frames ~50-100MB, siapkan storage cukup
4. **Update Nodes**: ComfyUI-GGUF dan WanVideoWrapper aktif dikembangkan

---

## 🎬 Step 9: Setup VideoFlow Wan 2.2 (Ultra Fast Workflow)

Workflow yang Anda download ([VideoFlow](https://civitai.com/models/1815300)) dioptimalkan untuk kecepatan tinggi. Gunakan langkah ini untuk download model yang tepat.

### 9.1 Download Model GGUF (Optimasi RTX 4060 8GB)

Simpan di `ComfyUI/models/diffusion_models`:

```bash
cd ~/ai-tools/ComfyUI/models/diffusion_models

# High Noise GGUF (Wajib ada)
huggingface-cli download bullerwins/Wan2.2-I2V-A14B-GGUF \
  wan2.2_i2v_high_noise_14B_Q4_K_M.gguf \
  --local-dir . --local-dir-use-symlinks False

# Low Noise GGUF (Wajib ada)
huggingface-cli download bullerwins/Wan2.2-I2V-A14B-GGUF \
  wan2.2_i2v_low_noise_14B_Q4_K_M.gguf \
  --local-dir . --local-dir-use-symlinks False
```

### 9.2 Download Lightning LoRAs (Hanya 4 Steps!)

Simpan di `ComfyUI/models/loras`:

```bash
cd ~/ai-tools/ComfyUI/models/loras

# High Noise LoRA
wget -O Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1_high_noise_model.safetensors \
  "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/high_noise_model.safetensors"

# Low Noise LoRA
wget -O Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1_low_noise_model.safetensors \
  "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/low_noise_model.safetensors"
```

### 9.3 Download Upscaler

Simpan di `ComfyUI/models/upscale_models`:

```bash
cd ~/ai-tools/ComfyUI/models/upscale_models
wget "https://openmodeldb.info/models/4x-UniversalUpscalerV2-Neutral" -O 4x_UniversalUpscalerV2-Neutral_115000_swaG.pth
```

---

## 🔥 Step 10: Tips Menjalankan VideoFlow di RTX 4060

1. **Shift = 8**: Di dalam workflow, pastikan nilai `Shift` adalah **8**. Wan 2.2 sangat sensitif dengan nilai ini.
2. **KSampler Settings**: Untuk video Lightning, gunakan `Sampler: euler`, `Scheduler: beta`, dan `Steps: 4`.
3. **VRAM Management**: Jika Anda mendapat error "Out of Memory", mute/bypass group `Increase fps` (RIFE) terlebih dahulu.
4. **Hardware Acceleration**: Matikan Hardware Acceleration di Browser (Chrome/Edge) saat menggunakan ComfyUI untuk membebaskan ~500MB VRAM tambahan.

---

**Selamat mencoba! 🎨🎬✨**

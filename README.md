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

---

## 🔧 Step 1: Setup WSL2 dan CUDA 13.1

### 1.1 Install/Update WSL2

Buka PowerShell sebagai Administrator:

```powershell
# Install WSL2 dengan Ubuntu 24.04 (Noble)
wsl --install -d Ubuntu-24.04

# Atau update existing WSL
wsl --update

# Set WSL2 sebagai default version
wsl --set-default-version 2
```

### 1.2 Install NVIDIA CUDA Toolkit (WSL-Ubuntu)

Masuk ke WSL2 Ubuntu:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y build-essential dkms wget curl git

# Hapus GPG key lama (jika ada) sesuai saran NVIDIA
sudo apt-key del 7fa2af80

# Setup NVIDIA Network Repository untuk Ubuntu 24.04
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# Install CUDA Toolkit 13.1 (Hanya toolkit, tidak boleh install driver di dalam WSL)
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
> **HANYA** install `cuda-toolkit-13-1`. Jangan pernah menginstal paket `cuda` atau `cuda-drivers` di dalam WSL karena akan menyebabkan konflik dengan driver Windows Host.

---

## ⚙️ Step 2: Konfigurasi WSL2 (`.wslconfig`)

File `.wslconfig` sangat krusial untuk mencegah **Out of Memory (OOM)** saat menjalankan FLUX.

Buka file `.wslconfig` di Windows (gunakan Notepad):

```powershell
notepad "$env:USERPROFILE\.wslconfig"
```

**Tempelkan konfigurasi berikut:**

```ini
[wsl2]
# RAM untuk WSL2 - Alokasikan minimal 12GB dari total RAM Anda
memory=12GB

# CPU cores
processors=6

# Swap file - Sangat penting untuk membantu VRAM 8GB
swap=8GB
swapFile=C:\\temp\\wsl-swap.vhdx

# Enable localhost forwarding
localhostForwarding=true

# GPU support
gpuSupport=true
```

Setelah edit, restart WSL2:

```powershell
wsl --shutdown
wsl
```

---

## 🐍 Step 3: Setup Python Environment (`uv`)

Gunakan `uv` untuk instalasi yang 10x lebih cepat daripada `pip` standar.

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env

# Buat virtual environment di folder ai-tools
mkdir -p ~/ai-tools && cd ~/ai-tools
uv venv flux-env --python 3.12
source flux-env/bin/activate
```

---

## 🎨 Step 4: Install ComfyUI & Manager

```bash
cd ~/ai-tools

# Clone ComfyUI
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Install PyTorch dengan CUDA support
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

# Install ComfyUI requirements
uv pip install -r requirements.txt

# Install ComfyUI Manager
cd custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager.git
cd ..
```

---

---

## 📥 Step 5: Setup FLUX.2-dev (Image Generation)

### 5.1 Direct Download Links (Recommended)

Jika Anda mendownload di PC lain, gunakan link ini dan pindahkan ke folder terkait:

| Model               | Link                                                                                                          | Dest Folder                |
| ------------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------- |
| **FLUX.2-dev GGUF** | [Download (8.2 GB)](https://huggingface.co/unsloth/FLUX.2-dev-GGUF/resolve/main/flux2-dev-Q4_K_M.gguf)        | `models/diffusion_models/` |
| **FLUX T5XXL GGUF** | [Download (3.2 GB)](https://huggingface.co/unsloth/FLUX.2-dev-GGUF/resolve/main/t5xxl.gguf)                   | `models/clip/`             |
| **FLUX VAE**        | [Download (335 MB)](https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/ae.safetensors)          | `models/vae/`              |
| **FLUX CLIP-L**     | [Download (246 MB)](https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors) | `models/clip/`             |

### 5.2 Install ComfyUI-GGUF Node

Node ini **WAJIB** ada untuk menjalankan format `.gguf`.

```bash
cd ~/ai-tools/ComfyUI/custom_nodes
git clone https://github.com/city96/ComfyUI-GGUF.git
cd ComfyUI-GGUF && uv pip install -r requirements.txt
```

### 5.3 Launch ComfyUI (RTX 4060 Optimized)

Gunakan script ini untuk menjalankan ComfyUI dengan alokasi VRAM yang efisien.

```bash
cd ~/ai-tools/ComfyUI
cat > launch.sh << 'EOF'
#!/bin/bash
source ~/ai-tools/flux-env/bin/activate
export PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:512"
python main.py --listen 0.0.0.0 --port 8188 --preview-method auto
EOF
chmod +x launch.sh
./launch.sh
```

---

## 🎬 Step 6: Setup Wan 2.1 / 2.2 (Video Generation)

Bagian ini digunakan untuk mengubah image hasil FLUX menjadi video (I2V).

### 6.1 Install WanVideoWrapper

```bash
cd ~/ai-tools/ComfyUI/custom_nodes
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
cd ComfyUI-WanVideoWrapper && uv pip install -r requirements.txt
```

### 6.2 Download Model Wan (I2V)

Simpan di folder terkait (cek **Step 5.0** untuk link manual yang lebih lengkap):

```bash
cd ~/ai-tools/ComfyUI

# Download Wan 2.2 GGUF (Recommended)
huggingface-cli download bullerwins/Wan2.2-I2V-A14B-GGUF \
  wan2.2_i2v_high_noise_14B_Q4_K_M.gguf \
  --local-dir models/diffusion_models --local-dir-use-symlinks False

# Download UMT5 Text Encoder (9.7 GB raksasa)
huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
  umt5-xxl.safetensors \
  --local-dir models/text_encoders --local-dir-use-symlinks False
```

### 6.3 Setup VideoFlow (Lightning 4-Steps)

Gunakan **VideoFlow LoRA** untuk generate video super cepat hanya dalam 4 steps.

```bash
# Download LoRA ke models/loras
cd ~/ai-tools/ComfyUI/models/loras
wget -O Wan2.2-Lightning-High.safetensors "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/high_noise_model.safetensors"
```

---

## 🔥 Step 7: Optimasi & Tips RTX 4060

| Fitur            | Rekomendasi                      | Efek                  |
| ---------------- | -------------------------------- | --------------------- |
| **Quantization** | GGUF Q4_K_M                      | Hemat VRAM 50%        |
| **Resolution**   | 832x480 (Wan) / 1024x1024 (Flux) | Optimal 8GB VRAM      |
| **Browser**      | Matikan Hardware Acceleration    | Free up ~500MB VRAM   |
| **Monitoring**   | `watch -n 1 nvidia-smi`          | Pantau real-time VRAM |

---

## ☁️ Step 8: Alternative: AWS EC2 G6 (L4 24GB VRAM)

Jika butuh kualitas **FP16** atau resolusi **720P**, gunakan AWS EC2.

### 8.1 Spesifikasi AWS G6.xlarge

- **GPU**: NVIDIA L4 (24GB VRAM) - Jauh lebih kuat dari RTX 4060.
- **OS**: Ubuntu 24.04 LTS.
- **CUDA**: 13.1 (Native).

### 8.2 Cara Install Singkat

1. Setup CUDA & Driver (Metode Network Repo).
2. Install Python 3.12 & `uv`.
3. Clone Repo ini dan jalankan Step 3-6.
4. Gunakan model **FP16** (bukan GGUF) untuk hasil maksimal.

---

## 📚 Referensi Resmi

### Model AI

- [FLUX.2-dev (Black Forest Labs)](https://huggingface.co/black-forest-labs/FLUX.2-dev)
- [Wan 2.1/2.2 (Wan-AI)](https://huggingface.co/Wan-AI)
- [GGUF Quants (Unsloth)](https://huggingface.co/unsloth/FLUX.2-dev-GGUF)
- [Lightning LoRA (Lightx2v)](https://huggingface.co/lightx2v/Wan2.2-Lightning)

### Tools & Nodes

- [ComfyUI Official](https://github.com/comfyanonymous/ComfyUI)
- [ComfyUI-GGUF (City96)](https://github.com/city96/ComfyUI-GGUF)
- [ComfyUI-WanVideoWrapper (Kijai)](https://github.com/kijai/ComfyUI-WanVideoWrapper)
- [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager)

### Dokumentasi Teknik

- [CUDA WSL User Guide (NVIDIA)](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)
- [NVIDIA L4 Tensor Core Specs](https://www.nvidia.com/en-us/data-center/l4/)

---

## 📝 License Notes

- **FLUX.2-dev**: Non-commercial license. Baca detail di [BFL License](https://huggingface.co/black-forest-labs/FLUX.2-dev/blob/main/LICENSE.md).
- **Wan2.1**: Subject to Wan-AI terms.

### Selamat mencoba! 🎨🎬✨

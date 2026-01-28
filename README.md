# FLUX.2-dev + Wan2.1 I2V Deployment Guide for Windows 11 + WSL2 + NVIDIA RTX 4060

Panduan lengkap untuk men-deploy **FLUX.2-dev GGUF** (Image Generation) dan **Wan2.1 I2V** (Image-to-Video) di Windows 11 menggunakan WSL2 dengan GPU NVIDIA RTX 4060.

> **Image Generation:** [`unsloth/FLUX.2-dev-GGUF`](https://huggingface.co/unsloth/FLUX.2-dev-GGUF) (Q4_K_M)
> **Video Generation:** [`Wan-AI/Wan2.2-I2V-A14B`](https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B) (MoE Architecture)

> **Pipeline:** Generate image dengan FLUX → Generate video dengan **Wan 2.2 I2V**

> **Kenapa GGUF format?**
>
> - **Hemat VRAM**: FLUX ~4-5GB, **Wan 2.2 (GGUF Expert)** ~6-7GB
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

**A. Model Utama (Taruh di: `ComfyUI/models/diffusion_models/`)**

- [FLUX.2-dev GGUF Q4_K_M (8.2 GB)](https://huggingface.co/unsloth/FLUX.2-dev-GGUF/resolve/main/flux2-dev-Q4_K_M.gguf)
- [Wan 2.2 High Noise GGUF Q4_K_M (9.1 GB)](https://huggingface.co/bullerwins/Wan2.2-I2V-A14B-GGUF/resolve/main/wan2.2_i2v_high_noise_14B_Q4_K_M.gguf)
- [Wan 2.2 Low Noise GGUF Q4_K_M (9.1 GB)](https://huggingface.co/bullerwins/Wan2.2-I2V-A14B-GGUF/resolve/main/wan2.2_i2v_low_noise_14B_Q4_K_M.gguf)

**B. Text Encoders & VAE (Taruh di folder masing-masing)**

- [Wan UMT5-XXL fp8 (9.7 GB)](https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors)
- [Wan VAE (508 MB)](https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B/resolve/main/Wan2.1_VAE.pth)

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

## 🎬 Step 6: Setup Wan 2.2 (Video Generation)

Bagian ini menggunakan arsitektur **MoE** (High & Low Noise experts).

### 6.1 Install WanVideoWrapper

```bash
cd ~/ai-tools/ComfyUI/custom_nodes
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
cd ComfyUI-WanVideoWrapper && uv pip install -r requirements.txt
```

### 6.2 Download Model Wan 2.2 (GGUF untuk RTX 4060)

Simpan di `models/diffusion_models`:

```bash
cd ~/ai-tools/ComfyUI/models/diffusion_models

# High Noise GGUF
huggingface-cli download bullerwins/Wan2.2-I2V-A14B-GGUF \
  wan2.2_i2v_high_noise_14B_Q4_K_M.gguf \
  --local-dir . --local-dir-use-symlinks False

# Low Noise GGUF
huggingface-cli download bullerwins/Wan2.2-I2V-A14B-GGUF \
  wan2.2_i2v_low_noise_14B_Q4_K_M.gguf \
  --local-dir . --local-dir-use-symlinks False
```

### 6.3 Setup VideoFlow (Lightning 4-Steps)

Gunakan LoRA khusus agar render Wan 2.2 hanya butuh 4-8 steps.

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

---

## ☁️ Step 8: Alternative: AWS EC2 G6 (L4 24GB VRAM)

Jika butuh kualitas **FP16** atau resolusi video **720P**, gunakan AWS EC2 G6.xlarge.

### 8.1 Spesifikasi AWS G6.xlarge

| Komponen    | Spec                                                  |
| ----------- | ----------------------------------------------------- |
| **GPU**     | NVIDIA L4 (24GB VRAM) - Jauh lebih kuat dari RTX 4060 |
| **vCPU**    | 4                                                     |
| **RAM**     | 16GB                                                  |
| **Storage** | EBS (rekomendasi 100GB+ GP3)                          |
| **OS**      | Ubuntu 24.04 LTS                                      |

### 8.2 Setup AWS EC2 Step-by-Step

#### 1. Install Driver & CUDA 13.1 (Ubuntu 24.04 Native)

SSH ke instance Anda, lalu jalankan:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y linux-headers-$(uname -r) build-essential

# Setup NVIDIA Network Repo
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# Install Drivers & Toolkit
sudo apt-get -y install cuda-drivers cuda-toolkit-13-1

# Setup Environment
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Reboot Instance
sudo reboot
```

#### 2. Install Python & ComfyUI (via `uv`)

Setelah reboot, jalankan:

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env

# Create Environment
mkdir -p ~/ai-tools && cd ~/ai-tools
uv venv flux-env --python 3.12
source flux-env/bin/activate

# Install PyTorch
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

# Clone Repo ComfyUI & Custom Nodes (Lihat Step 4 & 6)
# Catatan: Di L4 (24GB VRAM), Anda bisa download model FP16 untuk kualitas MAX!
```

#### 3. Keuntungan AWS G6 (L4) vs Lokal (RTX 4060)

| Fitur            | RTX 4060 8GB     | AWS L4 24GB             |
| ---------------- | ---------------- | ----------------------- |
| **VRAM**         | 8GB              | **24GB**                |
| **Model Format** | GGUF (Quantized) | **FP16 (Full Quality)** |
| **Max Res**      | 1024px           | **1536px+**             |
| **Video Res**    | 480P             | **720P / 1080P**        |

#### 4. Download Models (FP16 Max Quality)

Karena VRAM 24GB sangat lega, gunakan model FP16 asli dari repo **Wan 2.2 Official**:

```bash
cd ~/ai-tools/ComfyUI/models/diffusion_models

# FLUX.2-dev (FP16)
huggingface-cli download black-forest-labs/FLUX.2-dev \
  flux2-dev.safetensors --local-dir . --local-dir-use-symlinks False

# Wan 2.2 I2V A14B (Official FP16 folders)
huggingface-cli download Wan-AI/Wan2.2-I2V-A14B \
  --local-dir . --local-dir-use-symlinks False
```

#### 5. Launch ComfyUI di EC2 (Akses Publik)

Buat script khusus untuk AWS:

```bash
cat > launch-aws.sh << 'EOF'
#!/bin/bash
source ~/ai-tools/flux-env/bin/activate
# Bind ke 0.0.0.0 agar bisa diakses dari browser Windows melalui Public IP
python main.py --listen 0.0.0.0 --port 8188 --preview-method auto
EOF
chmod +x launch-aws.sh
./launch-aws.sh
```

#### 6. Akses Browser

Buka di Windows: `http://<EC2-PUBLIC-IP>:8188`
_(Pastikan Port 8188 sudah dibuka di Security Group AWS)_

#### 7. Auto-shutdown Script (Hemat Biaya)

Agar tagihan AWS tidak membengkak jika lupa mematikan instance:

```bash
sudo tee /usr/local/bin/check-idle.sh << 'EOF'
#!/bin/bash
# Shutdown jika utilitas GPU di bawah 5%
IDLE_TIME=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum/NR}')
if (( $(echo "$IDLE_TIME < 5" | bc -l) )); then
  sudo shutdown -h now
fi
EOF

chmod +x /usr/local/bin/check-idle.sh
(crontab -l 2>/dev/null; echo "*/15 * * * * /usr/local/bin/check-idle.sh") | crontab -
```

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

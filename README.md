# Linux 快速設定腳本

Ubuntu Server 一鍵安裝與設定腳本集，適用於 GPU AI 伺服器環境。

## 目錄結構

```
linux_script/
├── 01_system/           # 系統基礎設定
│   ├── 01_setup_tw_mirror.sh         # 台灣 apt 鏡像站點
│   ├── 02_install_build_essential.sh # 編譯工具 (gcc/cmake/git)
│   └── 03_setup_disable_sleep.sh     # 停用休眠與螢幕保護
│
├── 02_gpu_ai/           # GPU 驅動 & AI 環境
│   ├── 01_install_nvidia_driver.sh   # NVIDIA 驅動（ubuntu-drivers）
│   ├── 02_install_cuda.sh            # CUDA Toolkit 12.6
│   ├── 03_install_python.sh          # Python 3.12（透過 uv）
│   ├── 04_setup_llm_project.sh       # LLM 專案依賴（llama-cpp-python）
│   ├── 04b_build_llama_cpp.sh        # 編譯 llama.cpp 二進位檔
│   └── release_vram.sh               # 釋放 GPU VRAM（工具腳本）
│
├── 03_remote_desktop/   # 遠端桌面
│   ├── 01_setup_remote_desktop.sh    # 安裝 XFCE4 + XRDP
│   └── 02_fix_xrdp.sh               # 修正 XRDP 黑屏 / 無法連線
│
└── 04_network/          # 網路設定
    └── setup_network.sh             # 靜態 IP / DHCP / DNS 設定（Netplan）
```

## 建議執行順序

### 全新 GPU AI 伺服器

```bash
# 第一步：系統基礎
bash 01_system/01_setup_tw_mirror.sh        # 可選：台灣鏡像加速
bash 01_system/02_install_build_essential.sh
bash 01_system/03_setup_disable_sleep.sh    # 防止閒置休眠斷線

# 第二步：網路設定（可選）
bash 04_network/setup_network.sh            # 設定靜態 IP

# 第三步：GPU 驅動
bash 02_gpu_ai/01_install_nvidia_driver.sh
# → 重新開機
bash 02_gpu_ai/02_install_cuda.sh
bash 02_gpu_ai/03_install_python.sh

# 第四步：LLM 環境（二選一）
bash 02_gpu_ai/04_setup_llm_project.sh      # Python 套件（llama-cpp-python）
bash 02_gpu_ai/04b_build_llama_cpp.sh       # 原生二進位（llama-cli/server）

# 第五步：遠端桌面（可選）
bash 03_remote_desktop/01_setup_remote_desktop.sh
```

## 各腳本說明

### 01_system / 系統基礎

| 腳本 | 功能 |
|------|------|
| `01_setup_tw_mirror.sh` | 加入 NCTU/NTU/HiNet 鏡像站，加速 `apt` 下載 |
| `02_install_build_essential.sh` | 安裝 `gcc`, `cmake`, `git`, `ninja-build`, `pkg-config` |
| `03_setup_disable_sleep.sh` | 停用 systemd 休眠目標、logind 閒置動作、XFCE4 螢幕保護 |

### 02_gpu_ai / GPU & AI

| 腳本 | 功能 |
|------|------|
| `01_install_nvidia_driver.sh` | 使用 `ubuntu-drivers autoinstall` 安裝推薦驅動 |
| `02_install_cuda.sh` | 加入官方 repo 並安裝 CUDA Toolkit 12.6 |
| `03_install_python.sh` | 安裝 `uv` 並建立 Python 3.12 虛擬環境 |
| `04_setup_llm_project.sh` | 從 git 編譯安裝 `llama-cpp-python`（CUDA 加速）|
| `04b_build_llama_cpp.sh` | CMake 編譯 `llama.cpp`，安裝 `llama-cli/server/bench/quantize` |
| `release_vram.sh` | 停止 `llama-server` / `fetch_proxy`，確認 VRAM 釋放 |

### 03_remote_desktop / 遠端桌面

| 腳本 | 功能 |
|------|------|
| `01_setup_remote_desktop.sh` | 安裝 XFCE4 + XRDP，開放 port 3389 |
| `02_fix_xrdp.sh` | 修正黑屏問題：恢復終端模式、修正 `startwm.sh` |

### 04_network / 網路設定

| 腳本 | 功能 |
|------|------|
| `setup_network.sh` | 互動式設定靜態 IP 或 DHCP，透過 Netplan 套用，支援 DNS 設定 |

## 需求

- Ubuntu 22.04 (Jammy) 或 24.04 (Noble)
- GPU 腳本需要 NVIDIA GPU
- 遠端桌面需要 Ubuntu Server（無桌面環境）
- 網路設定需要 Netplan（Ubuntu 18.04+）

## 授權

MIT

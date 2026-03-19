# Linux 快速設定腳本

Ubuntu Server 一鍵安裝與設定腳本集，適用於 GPU AI 伺服器環境。

## 目錄結構

```
linux_script/
├── 01_system/           # 系統基礎設定
│   ├── 01_setup_tw_mirror.sh         # 台灣 apt 鏡像站點
│   ├── 02_install_build_essential.sh # 編譯工具 (gcc/cmake/git)
│   ├── 03_setup_disable_sleep.sh     # 停用休眠與螢幕保護
│   └── 04_install_chinese_input.sh   # 台灣中文輸入法（Fcitx5/IBus）
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
├── 04_network/          # 網路設定
│   └── setup_network.sh             # 靜態 IP / DHCP / DNS 設定（Netplan）
│
├── 05_troubleshoot/     # Linux Server 常見問題快速處理
│   ├── 01_disk_full.sh              # 磁碟空間不足（清理 apt/journal/大檔案）
│   ├── 02_memory_swap.sh            # 記憶體不足 / 建立 Swap
│   ├── 03_high_cpu.sh               # CPU 負載過高診斷 / Kill Process
│   ├── 04_service_fix.sh            # Systemd 服務無法啟動修復
│   ├── 05_network_debug.sh          # 網路連線問題診斷（DNS/路由/防火牆）
│   ├── 06_ssh_fix.sh                # SSH 無法連線修復
│   ├── 07_log_cleanup.sh            # 日誌檔清理與 logrotate 設定
│   ├── 08_time_sync.sh              # 系統時間不同步修復（NTP/台灣時區）
│   ├── 09_firewall_manager.sh       # UFW 防火牆互動式管理
│   └── 10_user_permission.sh        # 使用者與權限管理
│
└── 06_ai_deploy/        # AI 生產環境部署
    ├── 01_download_model.sh          # HuggingFace 模型下載（GGUF/完整Repo）
    ├── 02_gpu_health_check.sh        # GPU 健康檢查 / VRAM OOM 預防
    ├── 03_llama_server_service.sh    # llama-server 建立為 systemd 服務
    ├── 04_api_health_check.sh        # AI API 健康檢查 / 效能測試
    ├── 05_env_setup.sh              # AI 環境變數設定（CUDA/HF/llama）
    ├── 06_monitor_ai_service.sh      # 即時監控儀表板（GPU/API/服務）
    ├── 07_auto_restart_service.sh    # Watchdog 自動重啟（systemd timer）
    ├── 08_multi_model_switch.sh      # 多模型切換管理
    ├── 09_log_collector.sh           # 日誌收集 / 錯誤分析 / 診斷報告
    └── 10_backup_restore.sh          # AI 環境備份與還原 / 部署腳本匯出
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
| `04_install_chinese_input.sh` | 注音/倉頡/速成/行列/大易，支援 Fcitx5 與 IBus，含中文字型與語系 |

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

### 05_troubleshoot / Linux Server 常見問題

| 腳本 | 問題 | 功能 |
|------|------|------|
| `01_disk_full.sh` | 磁碟空間不足 | apt clean、舊 kernel 移除、journal 清理、大檔案掃描 |
| `02_memory_swap.sh` | 記憶體不足 | Page Cache 清除、Swap 建立與 swappiness 調整 |
| `03_high_cpu.sh` | CPU 負載過高 | Process 診斷、殭屍 Process 清理、互動式 Kill |
| `04_service_fix.sh` | 服務無法啟動 | 失敗服務列表、日誌查看、重啟/reset-failed/啟用開機 |
| `05_network_debug.sh` | 網路無法連線 | 介面/路由/DNS/ping 診斷、快速修復 |
| `06_ssh_fix.sh` | SSH 無法連線 | 設定語法檢查、防火牆修復、密碼登入啟用 |
| `07_log_cleanup.sh` | 日誌佔滿磁碟 | journald 清理、logrotate 設定、壓縮日誌刪除 |
| `08_time_sync.sh` | 系統時間錯誤 | NTP 修復、台灣時區設定、台灣 NTP 伺服器 |
| `09_firewall_manager.sh` | 防火牆管理 | UFW 規則增刪、常用服務開放、IP 白名單 |
| `10_user_permission.sh` | 權限問題 | 使用者增刪、sudo 管理、SSH key 權限修復 |

### 06_ai_deploy / AI 生產環境部署

| 腳本 | 場景 | 功能 |
|------|------|------|
| `01_download_model.sh` | 模型取得 | HuggingFace GGUF/完整模型下載，支援 hf_transfer 加速 |
| `02_gpu_health_check.sh` | 部署前確認 | VRAM/溫度/功耗檢查，推薦可用模型大小 |
| `03_llama_server_service.sh` | 服務化 | 將 llama-server 建立為 systemd 服務，開機自啟 |
| `04_api_health_check.sh` | 上線驗證 | /health、/v1/models、推理效能（tok/s）測試 |
| `05_env_setup.sh` | 環境初始化 | CUDA/HuggingFace/llama/Python 環境變數一鍵設定 |
| `06_monitor_ai_service.sh` | 即時監控 | GPU/VRAM/API/服務狀態儀表板（每 5s 刷新） |
| `07_auto_restart_service.sh` | 高可用 | Watchdog systemd timer，API 無回應自動重啟 |
| `08_multi_model_switch.sh` | 模型管理 | 多模型列表、切換、快速測試、效能比較 |
| `09_log_collector.sh` | 問題排查 | 即時日誌、診斷報告、OOM/崩潰錯誤分析 |
| `10_backup_restore.sh` | 備份還原 | 設定備份/還原、自動部署腳本匯出 |

## 需求

- Ubuntu 22.04 (Jammy) 或 24.04 (Noble)
- GPU 腳本需要 NVIDIA GPU
- 遠端桌面需要 Ubuntu Server（無桌面環境）
- 網路設定需要 Netplan（Ubuntu 18.04+）

## 授權

MIT

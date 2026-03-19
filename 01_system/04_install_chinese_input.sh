#!/bin/bash
# 04_install_chinese_input.sh
# 台灣中文輸入法安裝設定腳本
# 支援：Fcitx5（推薦）/ IBus
# 輸入法：注音、倉頡、速成、行列、大易
# 支援桌面：GNOME / XFCE / KDE / 無桌面（Server + XRDP）
# 適用：Ubuntu 22.04 (Jammy) / 24.04 (Noble)
set -e

# ── 顏色定義 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*"; exit 1; }
step()    { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       台灣中文輸入法安裝設定工具                     ║${RESET}"
echo -e "${BOLD}║  支援：注音 / 倉頡 / 速成 / 行列 / 大易              ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── 0. 系統偵測 ───────────────────────────────────────────────────────────────
step "系統環境偵測"

# Ubuntu 版本
CODENAME=$(lsb_release -cs 2>/dev/null || . /etc/os-release && echo "$VERSION_CODENAME")
UBUNTU_VER=$(lsb_release -rs 2>/dev/null || echo "unknown")
info "Ubuntu ${UBUNTU_VER} (${CODENAME})"

# 桌面環境
DESKTOP_ENV="${XDG_CURRENT_DESKTOP:-unknown}"
DISPLAY_SERVER="${WAYLAND_DISPLAY:+Wayland}"
DISPLAY_SERVER="${DISPLAY_SERVER:-${DISPLAY:+X11}}"
DISPLAY_SERVER="${DISPLAY_SERVER:-None}"
info "桌面環境：${DESKTOP_ENV} / 顯示伺服器：${DISPLAY_SERVER}"

# 判斷是否為 GNOME
IS_GNOME=false
[[ "$DESKTOP_ENV" =~ [Gg][Nn][Oo][Mm][Ee] ]] && IS_GNOME=true

# 判斷是否為 Wayland
IS_WAYLAND=false
[ -n "$WAYLAND_DISPLAY" ] && IS_WAYLAND=true

# 判斷是否有桌面環境
HAS_DESKTOP=false
[ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ] && HAS_DESKTOP=true
dpkg -l xfce4 gnome-shell kde-plasma-desktop 2>/dev/null | grep -q "^ii" && HAS_DESKTOP=true

if $IS_WAYLAND; then
    warn "偵測到 Wayland，建議使用 Fcitx5（對 Wayland 支援較佳）"
fi

echo ""

# ── 1. 選擇輸入法框架 ─────────────────────────────────────────────────────────
step "選擇輸入法框架"
echo ""
echo "  輸入法框架："
echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │ [1] Fcitx5（推薦）                                  │"
echo "  │     ✓ 支援 Wayland/X11                             │"
echo "  │     ✓ 現代化介面，支援主題                         │"
echo "  │     ✓ 適合 XFCE / KDE / 一般使用者                │"
echo "  │                                                     │"
echo "  │ [2] IBus（GNOME 原生）                              │"
echo "  │     ✓ GNOME 桌面整合最佳                          │"
echo "  │     ✓ Ubuntu 預設框架                              │"
echo "  │     ✓ 適合 GNOME 桌面                             │"
echo "  └─────────────────────────────────────────────────────┘"
echo ""

# 根據桌面環境給建議
if $IS_GNOME; then
    echo "  偵測到 GNOME，建議選擇 IBus [2]"
    DEFAULT_FRAMEWORK=2
else
    echo "  建議選擇 Fcitx5 [1]"
    DEFAULT_FRAMEWORK=1
fi

echo ""
read -rp "  請選擇框架 [${DEFAULT_FRAMEWORK}]: " FRAMEWORK_CHOICE
FRAMEWORK_CHOICE="${FRAMEWORK_CHOICE:-$DEFAULT_FRAMEWORK}"

# ── 2. 選擇輸入法 ─────────────────────────────────────────────────────────────
step "選擇要安裝的輸入法"
echo ""
echo "  台灣常用輸入法（可多選，以空格分隔）："
echo ""
echo "  [1] 注音輸入法（Chewing/新酷音）   ← 最多人使用，強烈推薦"
echo "  [2] 倉頡輸入法（Cangjie）          ← 字根輸入"
echo "  [3] 速成輸入法（Quick/倉頡簡化）"
echo "  [4] 行列輸入法（Array 30）"
echo "  [5] 大易輸入法（Dayi）"
echo "  [6] 全部安裝"
echo ""
read -rp "  請選擇（例如：1 2 或 6）[1]: " INPUT_CHOICES
INPUT_CHOICES="${INPUT_CHOICES:-1}"

# ── 解析輸入法選擇 ────────────────────────────────────────────────────────────
INSTALL_CHEWING=false
INSTALL_CANGJIE=false
INSTALL_QUICK=false
INSTALL_ARRAY=false
INSTALL_DAYI=false

for choice in $INPUT_CHOICES; do
    case "$choice" in
        1) INSTALL_CHEWING=true ;;
        2) INSTALL_CANGJIE=true ;;
        3) INSTALL_QUICK=true ;;
        4) INSTALL_ARRAY=true ;;
        5) INSTALL_DAYI=true ;;
        6) INSTALL_CHEWING=true; INSTALL_CANGJIE=true
           INSTALL_QUICK=true; INSTALL_ARRAY=true; INSTALL_DAYI=true ;;
    esac
done

echo ""
echo "  安裝摘要："
[ "$FRAMEWORK_CHOICE" = "1" ] && echo "  框架：Fcitx5" || echo "  框架：IBus"
$INSTALL_CHEWING && echo "  ✓ 注音（新酷音）"
$INSTALL_CANGJIE && echo "  ✓ 倉頡"
$INSTALL_QUICK   && echo "  ✓ 速成"
$INSTALL_ARRAY   && echo "  ✓ 行列"
$INSTALL_DAYI    && echo "  ✓ 大易"
echo ""
read -rp "  確認安裝？[Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"
[[ "$CONFIRM" =~ ^[Nn]$ ]] && echo "已取消" && exit 0

# ── 3. 更新套件清單 ───────────────────────────────────────────────────────────
step "更新套件清單"
sudo apt-get update -qq
success "套件清單已更新"

# ────────────────────────────────────────────────────────────────────────────
# ██  Fcitx5 安裝流程  ██
# ────────────────────────────────────────────────────────────────────────────
install_fcitx5() {
    step "安裝 Fcitx5 框架"

    # 核心套件
    FCITX5_PKGS=(
        fcitx5
        fcitx5-frontend-gtk3
        fcitx5-frontend-gtk4
        fcitx5-frontend-qt5
        fcitx5-config-qt
        fcitx5-data
    )

    # 中文支援
    FCITX5_PKGS+=(
        fcitx5-chinese-addons   # 拼音、五筆、倉頡、速成等
    )

    # 注音（新酷音）
    if $INSTALL_CHEWING; then
        FCITX5_PKGS+=(fcitx5-chewing libchewing3)
        info "加入：fcitx5-chewing（注音）"
    fi

    # table 輸入法（倉頡、速成、行列、大易）
    NEED_TABLE=false
    $INSTALL_CANGJIE && NEED_TABLE=true
    $INSTALL_QUICK   && NEED_TABLE=true
    $INSTALL_ARRAY   && NEED_TABLE=true
    $INSTALL_DAYI    && NEED_TABLE=true

    if $NEED_TABLE; then
        FCITX5_PKGS+=(fcitx5-table-extra)
        info "加入：fcitx5-table-extra（倉頡/速成/行列/大易）"
    fi

    # 安裝
    echo ""
    info "安裝中..."
    sudo apt-get install -y "${FCITX5_PKGS[@]}"
    success "Fcitx5 安裝完成"

    # ── 設定環境變數 ──────────────────────────────────────────────────────
    step "設定 Fcitx5 環境變數"

    ENV_CONF="$HOME/.config/environment.d/fcitx5.conf"
    mkdir -p "$(dirname "$ENV_CONF")"
    cat > "$ENV_CONF" <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
EOF
    success "已寫入：$ENV_CONF"

    # 同時加入 .bashrc（Terminal 程式支援）
    FCITX5_BASHRC='
# Fcitx5 輸入法
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx'
    if ! grep -q "GTK_IM_MODULE=fcitx" "$HOME/.bashrc"; then
        echo "$FCITX5_BASHRC" >> "$HOME/.bashrc"
        success "已加入 ~/.bashrc"
    fi

    # ── 設定開機自啟（XDG autostart）──────────────────────────────────────
    step "設定 Fcitx5 開機自啟"

    AUTOSTART_DIR="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/fcitx5.desktop" <<'EOF'
[Desktop Entry]
Name=Fcitx5
Comment=Start Input Method
Exec=fcitx5 -d --replace
Icon=fcitx5
Terminal=false
Type=Application
Categories=System;Utility;
X-GNOME-Autostart-Phase=Applications
X-GNOME-AutoRestart=false
NoDisplay=false
EOF
    chmod +x "$AUTOSTART_DIR/fcitx5.desktop"
    success "已設定開機自啟"

    # ── 設定注音輸入法選項 ─────────────────────────────────────────────────
    if $INSTALL_CHEWING; then
        step "設定注音輸入法"

        CHEWING_CONFIG_DIR="$HOME/.local/share/fcitx5/chewing"
        mkdir -p "$CHEWING_CONFIG_DIR"

        # Fcitx5 注音設定
        FCITX5_CONF_DIR="$HOME/.config/fcitx5"
        mkdir -p "$FCITX5_CONF_DIR/conf"

        # 輸入法排序設定（中文在前）
        cat > "$FCITX5_CONF_DIR/profile" <<EOF
[Groups/0]
# Group Name
Name=預設
# Layout
Default Layout=us
# Default Input Method
DefaultIM=chewing

[Groups/0/Items/0]
# Name
Name=chewing
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=keyboard-us
# Layout
Layout=

[GroupOrder]
0=預設
EOF
        success "注音輸入法已設定為預設"
    fi

    # ── 啟動 Fcitx5 ────────────────────────────────────────────────────────
    step "啟動 Fcitx5"
    if $HAS_DESKTOP; then
        fcitx5 -d --replace 2>/dev/null &
        sleep 2
        if pgrep -x fcitx5 > /dev/null; then
            success "Fcitx5 已啟動"
        else
            warn "Fcitx5 啟動中（可能需要重新登入）"
        fi
    else
        warn "未偵測到圖形環境，Fcitx5 將在下次登入桌面時自動啟動"
    fi
}

# ────────────────────────────────────────────────────────────────────────────
# ██  IBus 安裝流程  ██
# ────────────────────────────────────────────────────────────────────────────
install_ibus() {
    step "安裝 IBus 框架"

    IBUS_PKGS=(
        ibus
        ibus-gtk3
        ibus-gtk4
        ibus-qt4
    )

    # 注音（新酷音）
    if $INSTALL_CHEWING; then
        IBUS_PKGS+=(ibus-chewing libchewing3)
        info "加入：ibus-chewing（注音）"
    fi

    # table 輸入法
    if $INSTALL_CANGJIE; then
        IBUS_PKGS+=(ibus-table-cangjie5)
        info "加入：ibus-table-cangjie5（倉頡五代）"
    fi

    # 其他 table 輸入法
    NEED_TABLE_EXTRA=false
    $INSTALL_QUICK && NEED_TABLE_EXTRA=true
    $INSTALL_ARRAY && NEED_TABLE_EXTRA=true
    $INSTALL_DAYI  && NEED_TABLE_EXTRA=true
    if $NEED_TABLE_EXTRA; then
        IBUS_PKGS+=(ibus-table-wubi)   # 提供 table 引擎
        info "加入：ibus-table-extra"
        # 嘗試安裝額外表格
        sudo apt-get install -y ibus-table-extraphrase 2>/dev/null || true
    fi

    # 安裝
    echo ""
    info "安裝中..."
    sudo apt-get install -y "${IBUS_PKGS[@]}"
    success "IBus 安裝完成"

    # ── 設定環境變數 ──────────────────────────────────────────────────────
    step "設定 IBus 環境變數"

    IBUS_BASHRC='
# IBus 輸入法
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus'
    if ! grep -q "GTK_IM_MODULE=ibus" "$HOME/.bashrc"; then
        echo "$IBUS_BASHRC" >> "$HOME/.bashrc"
        success "已加入 ~/.bashrc"
    fi

    # /etc/environment 全局設定
    if ! grep -q "GTK_IM_MODULE" /etc/environment 2>/dev/null; then
        sudo tee -a /etc/environment > /dev/null <<'EOF'
GTK_IM_MODULE=ibus
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
EOF
        success "已設定 /etc/environment（全局）"
    fi

    # ── 設定開機自啟 ──────────────────────────────────────────────────────
    step "設定 IBus 開機自啟"

    AUTOSTART_DIR="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/ibus.desktop" <<'EOF'
[Desktop Entry]
Name=IBus
Comment=Start Input Method Framework
Exec=ibus-daemon -drx
Icon=ibus
Terminal=false
Type=Application
Categories=System;Utility;
X-GNOME-Autostart-Phase=Applications
NoDisplay=true
EOF
    success "已設定開機自啟"

    # ── 啟動 IBus daemon ───────────────────────────────────────────────────
    step "啟動 IBus"
    if $HAS_DESKTOP; then
        ibus-daemon -drx 2>/dev/null || true
        sleep 2
        if pgrep -f ibus-daemon > /dev/null; then
            success "IBus 已啟動"
        else
            warn "IBus 啟動中（可能需要重新登入）"
        fi
    else
        warn "未偵測到圖形環境，IBus 將在下次登入桌面時自動啟動"
    fi

    # ── GNOME 特別設定 ────────────────────────────────────────────────────
    if $IS_GNOME && command -v gsettings &>/dev/null; then
        step "GNOME 輸入法設定"

        # 設定 GNOME 使用 IBus
        gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]" 2>/dev/null || true

        INPUT_SOURCES="[('xkb', 'us')"
        $INSTALL_CHEWING && INPUT_SOURCES="${INPUT_SOURCES}, ('ibus', 'chewing')"
        INPUT_SOURCES="${INPUT_SOURCES}]"
        gsettings set org.gnome.desktop.input-sources sources "$INPUT_SOURCES" 2>/dev/null || true

        # 切換快捷鍵
        gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space', '<Shift>space']" 2>/dev/null || true
        success "GNOME 輸入法設定完成"
    fi
}

# ── 執行安裝 ──────────────────────────────────────────────────────────────────
case "$FRAMEWORK_CHOICE" in
    1) install_fcitx5 ;;
    2) install_ibus ;;
    *) error "無效選擇" ;;
esac

# ── 4. 安裝中文字型（可選）────────────────────────────────────────────────────
step "中文字型安裝"
echo ""
echo "  建議安裝中文字型（如尚未安裝）："
echo "  [1] 文泉驛正黑（WenQuanYi Zen Hei）- 推薦"
echo "  [2] Noto CJK 字型（Google Noto）- 完整"
echo "  [3] 全部安裝"
echo "  [0] 跳過"
echo ""
read -rp "  請選擇 [1]: " FONT_CHOICE
FONT_CHOICE="${FONT_CHOICE:-1}"

FONT_PKGS=()
case "$FONT_CHOICE" in
    1) FONT_PKGS=(fonts-wqy-zenhei fonts-wqy-microhei) ;;
    2) FONT_PKGS=(fonts-noto-cjk fonts-noto-cjk-extra) ;;
    3) FONT_PKGS=(fonts-wqy-zenhei fonts-wqy-microhei fonts-noto-cjk) ;;
    0) info "跳過字型安裝" ;;
esac

if [ ${#FONT_PKGS[@]} -gt 0 ]; then
    sudo apt-get install -y "${FONT_PKGS[@]}"
    sudo fc-cache -fv > /dev/null 2>&1
    success "中文字型安裝完成"
fi

# ── 5. 語系設定 ───────────────────────────────────────────────────────────────
step "語系設定"

# 確認 zh_TW.UTF-8 已安裝
if ! locale -a 2>/dev/null | grep -q "zh_TW.utf8"; then
    info "安裝 zh_TW.UTF-8 語系..."
    sudo locale-gen zh_TW.UTF-8 2>/dev/null || \
        sudo apt-get install -y language-pack-zh-hant language-pack-zh-hant-base
    sudo update-locale 2>/dev/null || true
    success "zh_TW.UTF-8 語系已安裝"
else
    success "zh_TW.UTF-8 語系已存在"
fi

# 加入語系設定
LOCALE_BASHRC='
# 中文語系（台灣）
export LANG=zh_TW.UTF-8
export LC_ALL=zh_TW.UTF-8
export LANGUAGE=zh_TW:zh:en'

if ! grep -q "LANG=zh_TW" "$HOME/.bashrc"; then
    read -rp "  是否將系統語言設為繁體中文（zh_TW.UTF-8）？[y/N]: " SET_LOCALE
    if [[ "$SET_LOCALE" =~ ^[Yy]$ ]]; then
        echo "$LOCALE_BASHRC" >> "$HOME/.bashrc"
        success "系統語言已設為 zh_TW.UTF-8"
    fi
fi

# ── 6. 完成報告 ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                   安裝完成！                         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

FRAMEWORK_NAME="Fcitx5"
[ "$FRAMEWORK_CHOICE" = "2" ] && FRAMEWORK_NAME="IBus"

echo -e "  框架：${GREEN}${FRAMEWORK_NAME}${RESET}"
echo "  已安裝輸入法："
$INSTALL_CHEWING && echo -e "    ${GREEN}✓${RESET} 注音（新酷音 Chewing）"
$INSTALL_CANGJIE && echo -e "    ${GREEN}✓${RESET} 倉頡"
$INSTALL_QUICK   && echo -e "    ${GREEN}✓${RESET} 速成"
$INSTALL_ARRAY   && echo -e "    ${GREEN}✓${RESET} 行列"
$INSTALL_DAYI    && echo -e "    ${GREEN}✓${RESET} 大易"
echo ""

echo -e "${CYAN}【後續步驟】${RESET}"
echo ""

if [ "$FRAMEWORK_CHOICE" = "1" ]; then
    echo "  Fcitx5 使用方式："
    echo "  1. 登出並重新登入（套用環境變數）"
    echo "  2. 工具列右下角點擊鍵盤圖示 → 設定"
    echo "  3. 新增輸入法：搜尋「注音」或「Chewing」"
    echo ""
    echo "  切換輸入法快捷鍵："
    echo "    Ctrl+Space  — 切換中/英文"
    echo "    Ctrl+Shift  — 切換輸入法"
    echo ""
    echo "  注音輸入法快捷鍵："
    echo "    Shift       — 全半形切換"
    echo "    Ctrl+.      — 全形標點切換"
    echo "    -/+         — 翻頁"
    echo ""
    echo "  圖形設定工具："
    echo "    fcitx5-config-qt  # 或工具列右鍵 → 設定"
else
    echo "  IBus 使用方式："
    echo "  1. 登出並重新登入（套用環境變數）"
    echo "  2. 工具列右上角點擊鍵盤圖示 → 偏好設定"
    echo "  3. 「輸入法」標籤 → 加入注音"
    echo ""
    echo "  切換輸入法快捷鍵："
    echo "    Super+Space  — 切換輸入法"
    echo "    Shift+Space  — 切換輸入法（備用）"
    echo ""
    echo "  圖形設定工具："
    echo "    ibus-setup"
fi

echo ""
echo -e "${CYAN}【XRDP 遠端桌面使用注意】${RESET}"
echo "  若透過 XRDP 遠端連線，需確認 ~/.xsession 已載入環境變數："
echo '  將以下內容加入 ~/.xsession 開頭：'
if [ "$FRAMEWORK_CHOICE" = "1" ]; then
    echo '    export GTK_IM_MODULE=fcitx'
    echo '    export QT_IM_MODULE=fcitx'
    echo '    export XMODIFIERS=@im=fcitx'
    echo '    fcitx5 -d &'
else
    echo '    export GTK_IM_MODULE=ibus'
    echo '    export QT_IM_MODULE=ibus'
    echo '    export XMODIFIERS=@im=ibus'
    echo '    ibus-daemon -drx &'
fi
echo ""
echo -e "${YELLOW}  重要：請執行下列指令套用環境變數，或登出重新登入：${RESET}"
echo "    source ~/.bashrc"
echo ""

# ── 可選：立即重新登入提示 ────────────────────────────────────────────────────
if $HAS_DESKTOP; then
    read -rp "  是否現在重新啟動桌面環境使設定生效？[y/N]: " RESTART_SESSION
    if [[ "$RESTART_SESSION" =~ ^[Yy]$ ]]; then
        if command -v xfce4-session-logout &>/dev/null; then
            xfce4-session-logout --logout 2>/dev/null || true
        elif command -v gnome-session-quit &>/dev/null; then
            gnome-session-quit --logout --no-prompt 2>/dev/null || true
        else
            warn "請手動登出後重新登入"
        fi
    fi
fi

echo ""
echo "=== 完成 ==="

#!/bin/bash
# 10_user_permission.sh — 使用者與權限快速管理
set -e

echo "=== 使用者與權限管理 ==="
echo ""

# ── 1. 目前使用者資訊 ─────────────────────────────────────────────────────────
echo "[1/4] 目前登入使用者："
who
echo ""
echo "目前使用者：$(whoami)（uid=$(id -u), gid=$(id -g)）"
echo "所屬群組：$(groups)"
echo ""

# ── 2. sudo 群組成員 ──────────────────────────────────────────────────────────
echo "[2/4] sudo 群組成員："
getent group sudo | awk -F: '{print $4}' | tr ',' '\n' | sed 's/^/  /'
echo ""

# ── 3. 管理選單 ───────────────────────────────────────────────────────────────
echo "[3/4] 管理選項："
echo "  [1]  新增使用者"
echo "  [2]  給予 sudo 權限"
echo "  [3]  移除 sudo 權限"
echo "  [4]  修改使用者密碼"
echo "  [5]  修復目錄權限（常見 777/444 錯誤）"
echo "  [6]  修復 SSH authorized_keys 權限"
echo "  [7]  查看使用者列表"
echo "  [8]  鎖定 / 解鎖帳號"
echo "  [0]  離開"
echo ""
read -rp "  請選擇: " OPT

case "$OPT" in
    1)
        read -rp "  新使用者名稱: " NEW_USER
        sudo useradd -m -s /bin/bash "$NEW_USER"
        sudo passwd "$NEW_USER"
        echo "  ✓ 使用者 $NEW_USER 已建立"
        ;;
    2)
        read -rp "  使用者名稱: " TARGET_USER
        sudo usermod -aG sudo "$TARGET_USER"
        echo "  ✓ $TARGET_USER 已加入 sudo 群組（需重新登入生效）"
        ;;
    3)
        read -rp "  使用者名稱: " TARGET_USER
        sudo deluser "$TARGET_USER" sudo 2>/dev/null || sudo gpasswd -d "$TARGET_USER" sudo
        echo "  ✓ $TARGET_USER 已移除 sudo 權限"
        ;;
    4)
        read -rp "  使用者名稱（留空=目前使用者）: " TARGET_USER
        TARGET_USER="${TARGET_USER:-$(whoami)}"
        sudo passwd "$TARGET_USER"
        echo "  ✓ 密碼已更新"
        ;;
    5)
        read -rp "  目錄路徑: " TARGET_DIR
        if [ -d "$TARGET_DIR" ]; then
            OWNER=$(stat -c '%U' "$TARGET_DIR")
            echo "  目錄擁有者：$OWNER"
            echo "  修復模式："
            echo "    [1] 一般目錄（755 / 檔案 644）"
            echo "    [2] 私人目錄（700 / 檔案 600）"
            echo "    [3] 共用目錄（775 / 檔案 664）"
            read -rp "  請選擇 [1]: " PERM_OPT
            case "${PERM_OPT:-1}" in
                1) sudo find "$TARGET_DIR" -type d -exec chmod 755 {} + && sudo find "$TARGET_DIR" -type f -exec chmod 644 {} + ;;
                2) sudo find "$TARGET_DIR" -type d -exec chmod 700 {} + && sudo find "$TARGET_DIR" -type f -exec chmod 600 {} + ;;
                3) sudo find "$TARGET_DIR" -type d -exec chmod 775 {} + && sudo find "$TARGET_DIR" -type f -exec chmod 664 {} + ;;
            esac
            echo "  ✓ 權限已修復：$TARGET_DIR"
        else
            echo "  ✗ 目錄不存在：$TARGET_DIR"
        fi
        ;;
    6)
        SSH_DIR="${HOME}/.ssh"
        if [ -d "$SSH_DIR" ]; then
            chmod 700 "$SSH_DIR"
            [ -f "$SSH_DIR/authorized_keys" ] && chmod 600 "$SSH_DIR/authorized_keys"
            [ -f "$SSH_DIR/id_rsa" ]          && chmod 600 "$SSH_DIR/id_rsa"
            [ -f "$SSH_DIR/id_ed25519" ]      && chmod 600 "$SSH_DIR/id_ed25519"
            [ -f "$SSH_DIR/config" ]           && chmod 600 "$SSH_DIR/config"
            [ -f "$SSH_DIR/known_hosts" ]      && chmod 644 "$SSH_DIR/known_hosts"
            echo "  ✓ ~/.ssh 權限已修復"
        else
            echo "  ~/.ssh 目錄不存在"
        fi
        ;;
    7)
        echo "  系統使用者（uid >= 1000）："
        awk -F: '$3>=1000 && $3<65534{printf "  %-15s uid=%-6s %s\n", $1, $3, $6}' /etc/passwd
        ;;
    8)
        read -rp "  使用者名稱: " TARGET_USER
        echo "  [1] 鎖定帳號  [2] 解鎖帳號"
        read -rp "  請選擇: " LOCK_OPT
        case "$LOCK_OPT" in
            1) sudo passwd -l "$TARGET_USER" && echo "  ✓ $TARGET_USER 已鎖定" ;;
            2) sudo passwd -u "$TARGET_USER" && echo "  ✓ $TARGET_USER 已解鎖" ;;
        esac
        ;;
    *)
        echo "  離開"
        ;;
esac

echo ""
echo "=== 完成 ==="

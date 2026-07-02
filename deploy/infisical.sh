#!/usr/bin/env bash
# infisical.sh — 自架 Infisical 管理腳本
# 用法: ./infisical.sh [install|uninstall|update|status|logs]

set -euo pipefail

# ── 設定 ────────────────────────────────────────────────────────────────────
INSTALL_DIR="/opt/infisical"
SERVICE_NAME="infisical"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 顏色 ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── 前置檢查 ────────────────────────────────────────────────────────────────
require_root() {
  [[ $EUID -eq 0 ]] || die "此指令需要 root 權限，請使用 sudo。"
}

require_docker() {
  command -v docker &>/dev/null || die "找不到 docker，請先安裝 Docker Engine。"
  docker compose version &>/dev/null 2>&1 || die "找不到 docker compose v2 plugin。"
}

# ── 產生 .env ───────────────────────────────────────────────────────────────
generate_env() {
  local env_file="$1"

  info "  自動產生 .env 設定..."

  # ── 可自動隨機的欄位 ──────────────────────────────────────────────────────
  local encryption_key auth_secret pg_password

  if command -v openssl &>/dev/null; then
    encryption_key=$(openssl rand -hex 16)
    auth_secret=$(openssl rand -base64 32)
    # 只用英數字，避免特殊字元在 DB URI 中需要 URL encode
    pg_password=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)
  else
    # openssl 不可用時降級（不常見，但防禦性處理）
    warn "  找不到 openssl，嘗試以 /dev/urandom 產生密鑰..."
    if [[ -r /dev/urandom ]]; then
      encryption_key=$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c 32)
      auth_secret=$(LC_ALL=C tr -dc 'A-Za-z0-9+/' </dev/urandom | head -c 44)
      pg_password=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
    else
      die "無法產生隨機密鑰：找不到 openssl 也找不到 /dev/urandom。請手動填寫 .env。"
    fi
  fi

  local db_uri="postgres://infisical:${pg_password}@db:5432/infisical"

  # ── 必須詢問使用者的欄位 ──────────────────────────────────────────────────
  echo ""
  echo "請輸入以下資訊（無法自動推測）："
  echo ""

  local site_url=""
  while [[ -z "$site_url" ]]; do
    read -rp "  SITE_URL（你的網站網址，例: http://192.168.1.100）: " site_url
    site_url="${site_url%/}"  # 移除結尾斜線
    if [[ -z "$site_url" ]]; then
      warn "  SITE_URL 不可為空，請重新輸入。"
    fi
  done

  echo ""

  # ── 寫入 .env（權限 600，避免其他使用者讀取密鑰）────────────────────────
  install -m 600 /dev/null "$env_file"

  cat > "$env_file" <<EOF
# ============================================================
# Infisical 自架部署設定（由 infisical.sh install 自動產生）
# ============================================================

# 加密金鑰（自動產生，請勿遺失）
ENCRYPTION_KEY=${encryption_key}

# JWT 簽名密鑰（自動產生）
AUTH_SECRET=${auth_secret}

# 網站網址
SITE_URL=${site_url}

# PostgreSQL
POSTGRES_USER=infisical
POSTGRES_PASSWORD=${pg_password}
POSTGRES_DB=infisical
DB_CONNECTION_URI=${db_uri}

# Redis
REDIS_URL=redis://redis:6379

# Email（可選，不填則停用 email 功能）
SMTP_HOST=
SMTP_PORT=587
SMTP_FROM_ADDRESS=
SMTP_FROM_NAME=Infisical
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_SECURE=false

# 關閉雲端遙測
TELEMETRY_ENABLED=false
EOF

  info "  .env 已產生：$env_file"
  info "  ENCRYPTION_KEY / AUTH_SECRET / POSTGRES_PASSWORD 已自動隨機產生。"
  warn "  請備份 $env_file — 遺失 ENCRYPTION_KEY 將無法解密已儲存的 Secrets。"
}

# ── 安裝 ────────────────────────────────────────────────────────────────────
cmd_install() {
  require_root
  require_docker

  info "開始安裝 Infisical 到 $INSTALL_DIR"

  # 建立安裝目錄
  mkdir -p "$INSTALL_DIR"

  # 複製部署檔案
  for f in docker-compose.yml mock-license-server.mjs; do
    if [[ -f "$SCRIPT_DIR/$f" ]]; then
      cp "$SCRIPT_DIR/$f" "$INSTALL_DIR/$f"
      info "  複製 $f"
    else
      die "找不到 $SCRIPT_DIR/$f，請確認腳本與部署檔案在同一目錄。"
    fi
  done

  # 建立 .env（如果不存在則自動產生，已存在則保留）
  if [[ ! -f "$INSTALL_DIR/.env" ]]; then
    generate_env "$INSTALL_DIR/.env"
  else
    info "  .env 已存在，跳過（不覆蓋現有設定）"
  fi

  # 安裝 systemd service unit
  install_systemd_unit

  info "安裝完成。"
  echo ""
  info "下一步："
  echo "  啟動服務：  sudo systemctl start $SERVICE_NAME"
  echo "  開機自啟：  sudo systemctl enable $SERVICE_NAME"
  echo "  查看狀態：  sudo systemctl status $SERVICE_NAME"
  echo "  查看日誌：  sudo $0 logs backend -f"
}

# ── 安裝 systemd unit ────────────────────────────────────────────────────────
install_systemd_unit() {
  local unit_file="/etc/systemd/system/${SERVICE_NAME}.service"

  info "  寫入 systemd unit: $unit_file"

  # 取得 docker 完整路徑（避免 systemd 找不到）
  local docker_bin
  docker_bin="$(command -v docker)"

  cat > "$unit_file" <<EOF
[Unit]
Description=Infisical Secret Manager (self-hosted)
Documentation=https://infisical.com/docs
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR

# 啟動前先 pull 最新映像（可選，移除此行可加快啟動速度）
ExecStartPre=$docker_bin compose -f $COMPOSE_FILE pull --quiet

ExecStart=$docker_bin compose -f $COMPOSE_FILE up -d --remove-orphans
ExecStop=$docker_bin compose -f $COMPOSE_FILE down

# 若服務失敗則 2 分鐘後自動重試
Restart=on-failure
RestartSec=120s

# 確保日誌寫入 journald
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  info "  systemd unit 已安裝並 reload。"
}

# ── 移除 ────────────────────────────────────────────────────────────────────
cmd_uninstall() {
  require_root

  warn "即將移除 Infisical（容器、服務設定），資料 Volume 預設保留。"
  read -rp "確認移除？輸入 'yes' 繼續: " confirm
  [[ "$confirm" == "yes" ]] || { info "取消。"; exit 0; }

  # 停止並停用 systemd service
  if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    info "停止 systemd service..."
    systemctl stop "$SERVICE_NAME"
  fi
  if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl disable "$SERVICE_NAME"
  fi

  local unit_file="/etc/systemd/system/${SERVICE_NAME}.service"
  if [[ -f "$unit_file" ]]; then
    rm -f "$unit_file"
    systemctl daemon-reload
    info "  已移除 $unit_file"
  fi

  # 停止並移除 docker containers
  if [[ -f "$COMPOSE_FILE" ]]; then
    info "停止並移除容器..."
    docker compose -f "$COMPOSE_FILE" down --remove-orphans || true
  fi

  # 詢問是否也刪除資料 volume
  echo ""
  warn "是否同時刪除資料庫及 Redis 資料 Volume？（此操作不可回復）"
  read -rp "刪除 Volume？輸入 'delete-data' 確認: " confirm_data
  if [[ "$confirm_data" == "delete-data" ]]; then
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true
    info "  Volume 已刪除。"
  else
    info "  Volume 保留。如需手動刪除：docker volume ls | grep infisical"
  fi

  # 移除安裝目錄
  info "移除安裝目錄 $INSTALL_DIR ..."
  rm -rf "$INSTALL_DIR"

  info "移除完成。"
}

# ── 更新 ────────────────────────────────────────────────────────────────────
cmd_update() {
  require_root
  require_docker

  [[ -f "$COMPOSE_FILE" ]] || die "找不到 $COMPOSE_FILE，請先執行 install。"

  info "拉取最新映像..."
  docker compose -f "$COMPOSE_FILE" pull

  info "重新啟動容器（零停機滾動更新）..."
  docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

  info "清理舊的懸空映像..."
  docker image prune -f

  info "更新完成。目前執行中的版本："
  docker compose -f "$COMPOSE_FILE" ps
}

# ── 狀態 & 日誌 ─────────────────────────────────────────────────────────────
cmd_status() {
  [[ -f "$COMPOSE_FILE" ]] || die "找不到 $COMPOSE_FILE，請先執行 install。"
  docker compose -f "$COMPOSE_FILE" ps
}

cmd_logs() {
  [[ -f "$COMPOSE_FILE" ]] || die "找不到 $COMPOSE_FILE，請先執行 install。"
  # 傳遞額外參數，例如 logs backend -f --tail 100
  docker compose -f "$COMPOSE_FILE" logs "${@:-}"
}

# ── 主程式 ───────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
用法: sudo $0 <指令> [選項]

指令:
  install     安裝 Infisical 到 $INSTALL_DIR 並設定 systemd service
  uninstall   停止服務、移除容器與安裝目錄（可選保留資料）
  update      拉取最新映像並重啟容器
  status      顯示容器執行狀態
  logs [srv]  查看日誌（srv 可選: backend/mock-license/db/redis）

範例:
  sudo $0 install
  sudo $0 logs backend -f --tail 200
  sudo $0 update
EOF
}

case "${1:-}" in
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
  update)    cmd_update ;;
  status)    cmd_status ;;
  logs)      shift; cmd_logs "$@" ;;
  *)         usage; exit 1 ;;
esac

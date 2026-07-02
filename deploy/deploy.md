# Infisical 自架部署指南

## 架構說明

```
Server
├── /opt/infisical/
│   ├── docker-compose.yml
│   ├── mock-license-server.mjs
│   └── .env                     ← install 時自動產生
│
Docker containers:
├── infisical        ← 官方映像 infisical/infisical:latest
├── mock-license     ← node:22-alpine + mock-license-server.mjs
├── db               ← postgres:16-alpine
└── redis            ← redis:7-alpine
```

所有 license 請求都由 `mock-license` sidecar 攔截，**不會連到官方授權伺服器**。

---

## 前置需求

- Linux 伺服器（Debian / Ubuntu / RHEL 均可）
- Docker Engine 24+ with Compose v2 plugin
- `openssl`（用於自動產生密鑰，絕大多數發行版預裝）

---

## 方法 A — 手動部署（scp）

### 1. 傳送部署檔案

在本機執行：

```bash
scp -r ./deploy/ user@your-server:/tmp/infisical-deploy/
```

### 2. 登入 Server 並安裝

```bash
ssh user@your-server
cd /tmp/infisical-deploy
sudo bash infisical.sh install
```

安裝過程中只需輸入一項資訊：

```
請輸入以下資訊（無法自動推測）：

  SITE_URL（你的網站網址，例: http://192.168.1.100）: http://192.168.1.100
```

其餘密鑰（`ENCRYPTION_KEY`、`AUTH_SECRET`、`POSTGRES_PASSWORD`）全部自動隨機產生。

### 3. 啟動服務

```bash
sudo systemctl start infisical
sudo systemctl enable infisical   # 開機自動啟動
```

### 4. 確認狀態

```bash
sudo systemctl status infisical
sudo infisical.sh status          # 顯示各容器狀態
sudo infisical.sh logs backend -f # 即時查看後端日誌
```

---

## 方法 B — Forgejo CI/CD（自動化）

### 前置設定

1. 在 Forgejo Server 上安裝 runner（self-hosted），並確認 runner 可以 `ssh` 到部署目標 Server。
2. 在 Forgejo 專案的 **Settings → Secrets** 新增：

   | Secret 名稱 | 內容 |
   |-------------|------|
   | `SSH_HOST` | 目標 Server IP 或域名 |
   | `SSH_USER` | 登入帳號（需有 sudo 權限） |
   | `SSH_KEY` | 私鑰內容（對應 Server 上的 authorized_keys） |

### Workflow 設定

建立 `.forgejo/workflows/deploy.yml`：

```yaml
name: Deploy Infisical

on:
  push:
    branches: [main]
    paths:
      - 'deploy/**'   # 只有 deploy/ 有變動才觸發

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: 設定 SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H "${{ secrets.SSH_HOST }}" >> ~/.ssh/known_hosts

      - name: 同步部署檔案
        run: |
          rsync -av --delete \
            -e "ssh -i ~/.ssh/deploy_key" \
            deploy/ \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:/tmp/infisical-deploy/

      - name: 安裝或更新
        run: |
          ssh -i ~/.ssh/deploy_key \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
            "if [ -d /opt/infisical ]; then
               sudo bash /tmp/infisical-deploy/infisical.sh update
             else
               echo '首次安裝請手動執行：sudo bash /tmp/infisical-deploy/infisical.sh install'
               exit 1
             fi"
```

> **注意**：`install` 需要互動式輸入 `SITE_URL`，**只做一次**，之後 CI/CD 只跑 `update`（全自動）。

---

## infisical.sh 指令速查

```bash
sudo bash infisical.sh install     # 首次安裝
sudo bash infisical.sh update      # 更新至最新映像並重啟
sudo bash infisical.sh status      # 查看容器狀態
sudo bash infisical.sh logs [服務] # 查看日誌（可加 -f --tail N）
sudo bash infisical.sh uninstall   # 移除（互動確認）
```

日誌服務名稱：`backend` / `mock-license` / `db` / `redis`

---

## 備份建議

`ENCRYPTION_KEY` 是 Secrets 的加密根密鑰，**遺失後無法解密任何已存資料**。

```bash
# 備份 .env
sudo cp /opt/infisical/.env /safe-backup-location/.env.infisical.bak
```

---

## 安全說明

本部署透過以下三層機制確保**絕不連到官方授權伺服器**：

| 層級 | 機制 |
|------|------|
| 應用層 | `LICENSE_SERVER_URL=http://mock-license:3001`，所有 license 請求打到 mock |
| 環境層 | `LICENSE_SERVER_KEY=`、`LICENSE_SERVER_V2_SERVICE_KEY=` 明確清空，不觸發 Cloud 路徑 |
| 網路層 | `extra_hosts` 把 `portal.infisical.com` / `license.infisical.com` 解析到 `127.0.0.2`（blackhole） |

#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 server for PrepLoop. Run as root:
#   curl -fsSL https://raw.githubusercontent.com/shaikfaizalios-byte/Flutter-project/main/infra/production/setup-server.sh -o setup.sh
#   less setup.sh   # read it first
#   bash setup.sh
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/shaikfaizalios-byte/Flutter-project.git}"
APP_DIR="${APP_DIR:-/opt/preploop}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
# Docker from Ubuntu's own repositories; automatic security updates; firewall.
apt-get -y install docker.io docker-compose-v2 git ufw unattended-upgrades
systemctl enable --now docker
dpkg-reconfigure -f noninteractive unattended-upgrades

# Only SSH and the web ports are reachable.
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

if [ ! -d "$APP_DIR/.git" ]; then
  git clone "$REPO_URL" "$APP_DIR"
fi

# Nightly backups at 02:30 server time (database dump + uploaded PDFs, 14 days kept).
install -m 0755 "$APP_DIR/infra/production/backup.sh" /usr/local/bin/preploop-backup
echo "30 2 * * * root /usr/local/bin/preploop-backup >> /var/log/preploop-backup.log 2>&1" \
  > /etc/cron.d/preploop-backup

cat <<MSG

Server prepared. Next:
  1. cp $APP_DIR/infra/production/.env.example $APP_DIR/infra/production/.env
  2. Edit $APP_DIR/infra/production/.env (secrets, API_DOMAIN, SMTP)
  3. bash $APP_DIR/infra/production/deploy.sh
MSG

#!/usr/bin/env bash
set -euo pipefail

# Expect environment variables provided via instance metadata or baked into template:
# PROJECT_ID, SUBSCRIPTION (full path), RESULTS_BUCKET, SCRIPTS_BUCKET

log() { echo "[startup] $(date -u +'%Y-%m-%dT%H:%M:%SZ') $*"; }

log "Updating APT and installing dependencies"
apt-get update -y

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

apt-get install -y python3 python3-full python3-venv python3-pip curl jq

log "Creating virtual environment and installing python libraries"
install -d /opt
python3 -m venv /opt/worker-venv
source /opt/worker-venv/bin/activate
pip install --no-cache-dir --upgrade pip
pip install --no-cache-dir google-cloud-pubsub google-cloud-storage

# Fetch worker script from scripts bucket if not already present
if [[ ! -f /opt/worker.py ]]; then
  log "Acquiring access token for GCS"
  TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
    "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token" | jq -r '.access_token') || {
      log "Failed to get token"; exit 1; }
  log "Downloading worker.py from bucket ${SCRIPTS_BUCKET}"
  curl -fsSL -H "Authorization: Bearer $TOKEN" \
    "https://storage.googleapis.com/${SCRIPTS_BUCKET}/worker.py" -o /opt/worker.py || {
      log "Failed to download worker.py"; exit 1; }
fi

cat >/etc/systemd/system/worker.service <<SERVICE
[Unit]
Description=PubSub Worker
After=network.target

[Service]
Type=simple
Environment=PROJECT_ID=${PROJECT_ID}
Environment=SUBSCRIPTION=${SUBSCRIPTION}
Environment=RESULTS_BUCKET=${RESULTS_BUCKET}
Environment=PYTHONUNBUFFERED=1
ExecStart=/opt/worker-venv/bin/python /opt/worker.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

log "Enabling and starting worker service"
systemctl daemon-reload
systemctl enable worker
systemctl start worker

log "Startup script completed"

#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  EC2 Bootstrap Script — Run ONCE after launching your EC2
#  Tested on: Ubuntu 22.04 LTS
#  Usage:  chmod +x scripts/ec2-setup.sh && sudo ./scripts/ec2-setup.sh
# ─────────────────────────────────────────────────────────────

set -e

echo "═══════════════════════════════════════════"
echo "  LUXE SHOP — EC2 Setup Script"
echo "═══════════════════════════════════════════"

# 1. Update system
echo "📦 Updating system packages..."
apt-get update -y && apt-get upgrade -y

# 2. Install Docker
echo "🐳 Installing Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 3. Start & enable Docker
systemctl start docker
systemctl enable docker

# 4. Allow ubuntu user to run docker without sudo
usermod -aG docker ubuntu

echo "✅ Docker installed: $(docker --version)"

# 5. Open ports via UFW (optional if using Security Groups only)
# ufw allow 22/tcp   # SSH
# ufw allow 80/tcp   # HTTP
# ufw allow 443/tcp  # HTTPS
# ufw --force enable

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ EC2 is ready!"
echo "  Next: Jenkins will SSH in and deploy."
echo "  Make sure Security Group allows port 80."
echo "═══════════════════════════════════════════"

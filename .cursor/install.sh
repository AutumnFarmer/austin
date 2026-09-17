#!/usr/bin/env bash
# Idempotent install for the austin message-push platform.
# Installs the JDK 8 / Maven / Docker toolchain, pre-pulls the middleware images,
# and builds austin-web. Runs after the repository is checked out.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

export DEBIAN_FRONTEND=noninteractive

# --- Adoptium apt repo (Temurin JDK 8 is not in the Ubuntu 24.04 default repos) ---
if [ ! -f /etc/apt/keyrings/adoptium.gpg ]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
    | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null

sudo apt-get update -y
# --force-conf* keeps existing config files and avoids interactive conffile prompts
# (e.g. /etc/fuse.conf) that would otherwise stall a non-interactive install.
sudo apt-get install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  temurin-8-jdk maven docker.io fuse-overlayfs redis-tools

# --- Docker daemon config + pre-pull middleware images into the image cache ---
source "${REPO_ROOT}/.cursor/docker-lib.sh"
ensure_docker_config
ensure_dockerd
sudo docker pull mysql:5.7
sudo docker pull redis:6.2

# --- Build the application (JDK 8) ---
export JAVA_HOME=/usr/lib/jvm/temurin-8-jdk-amd64
export PATH="${JAVA_HOME}/bin:${PATH}"
mvn -B -pl austin-web -am package -DskipTests

echo "install.sh complete: austin-web jar built and middleware images ready."

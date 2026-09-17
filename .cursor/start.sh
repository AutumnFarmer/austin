#!/usr/bin/env bash
# Per-boot startup for austin: brings up dockerd and the MySQL 5.7 + Redis
# containers, then waits until MySQL is reachable. Idempotent across reboots.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

source "${REPO_ROOT}/.cursor/docker-lib.sh"

ensure_docker_config
ensure_dockerd
ensure_mysql "${REPO_ROOT}"
ensure_redis
wait_for_mysql

echo "start.sh complete: MySQL and Redis are up."

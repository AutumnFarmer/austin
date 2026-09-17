#!/usr/bin/env bash
# Shared helpers for running austin's MySQL 5.7 + Redis via Docker inside the
# Cursor Cloud Agent VM. Sourced by install.sh and start.sh.

MYSQL_ROOT_PASSWORD="root123_A"
REDIS_PASSWORD="austin"

# The Cloud Agent VM is itself a container, so Docker's default overlay-on-overlay
# storage driver fails to mount. fuse-overlayfs works in this nested setup.
ensure_docker_config() {
  sudo mkdir -p /etc/docker
  echo '{ "features": { "containerd-snapshotter": false }, "storage-driver": "fuse-overlayfs" }' \
    | sudo tee /etc/docker/daemon.json >/dev/null
}

ensure_dockerd() {
  if sudo docker info >/dev/null 2>&1; then
    return 0
  fi
  echo "Starting dockerd..."
  sudo bash -c 'nohup dockerd >/var/log/dockerd.log 2>&1 &'
  for _ in $(seq 1 30); do
    if sudo docker info >/dev/null 2>&1; then
      echo "dockerd is up"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: dockerd failed to start" >&2
  sudo tail -n 30 /var/log/dockerd.log >&2 || true
  return 1
}

# Build a sanitized copy of sql/austin.sql. The committed file uses decorative
# '-----' comment lines which MySQL rejects (a '--' comment needs whitespace
# after it), so turn them into valid '-- ' comments for the init step.
render_init_sql() {
  local repo_root="$1"
  sed -E 's/^([[:space:]]*)---/\1-- -/' "${repo_root}/sql/austin.sql" > /tmp/austin-init.sql
}

ensure_mysql() {
  local repo_root="$1"
  render_init_sql "${repo_root}"
  if sudo docker ps -a --format '{{.Names}}' | grep -qx austin-mysql; then
    sudo docker start austin-mysql >/dev/null
  else
    sudo docker run -d --name austin-mysql --restart unless-stopped \
      -e TZ=Asia/Shanghai -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" -e MYSQL_ROOT_HOST=% \
      -v /tmp/austin-init.sql:/docker-entrypoint-initdb.d/init.sql \
      -p 3306:3306 mysql:5.7 >/dev/null
  fi
}

ensure_redis() {
  if sudo docker ps -a --format '{{.Names}}' | grep -qx austin-redis; then
    sudo docker start austin-redis >/dev/null
  else
    sudo docker run -d --name austin-redis --restart unless-stopped \
      -p 6379:6379 redis:6.2 redis-server --requirepass "${REDIS_PASSWORD}" >/dev/null
  fi
}

wait_for_mysql() {
  for _ in $(seq 1 60); do
    if sudo docker exec austin-mysql mysqladmin ping -uroot -p"${MYSQL_ROOT_PASSWORD}" --silent >/dev/null 2>&1; then
      echo "MySQL is ready"
      return 0
    fi
    sleep 2
  done
  echo "ERROR: MySQL did not become ready in time" >&2
  return 1
}

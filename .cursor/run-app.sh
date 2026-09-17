#!/usr/bin/env bash
# Runs austin-web with the 'cloud' Spring profile (local MySQL/Redis, eventBus
# queue, optional middleware disabled). Kept in a persistent terminal so its
# logs stay visible and it can be restarted easily.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

export JAVA_HOME=/usr/lib/jvm/temurin-8-jdk-amd64
export PATH="${JAVA_HOME}/bin:${PATH}"

JAR="austin-web/target/austin-web-0.0.1-SNAPSHOT.jar"
if [ ! -f "${JAR}" ]; then
  echo "Jar not found, building..."
  mvn -B -pl austin-web -am package -DskipTests
fi

exec java -jar "${JAR}" --spring.profiles.active=cloud

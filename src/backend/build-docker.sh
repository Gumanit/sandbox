#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
fi

: "${NEXUS_REGISTRY:?NEXUS_REGISTRY is required}"
: "${NEXUS_DOCKER_BACKEND_REPO:?NEXUS_DOCKER_BACKEND_REPO is required}"
: "${NEXUS_REPO_USER:?NEXUS_REPO_USER is required}"
: "${NEXUS_REPO_PASS:?NEXUS_REPO_PASS is required}"

IMAGE="$NEXUS_REGISTRY/$NEXUS_DOCKER_BACKEND_REPO/momo-store-backend"
TAG="${VERSION:-latest}"

printf '%s' "$NEXUS_REPO_PASS" | docker login "$NEXUS_REGISTRY" \
  -u "$NEXUS_REPO_USER" --password-stdin

docker build -t "$IMAGE:$TAG" -t "$IMAGE:latest" "$SCRIPT_DIR"
docker push "$IMAGE:$TAG"
docker push "$IMAGE:latest"
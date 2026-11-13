#!/bin/bash
set -e
docker compose pull
docker compose up -d --remove-orphans --force-recreate
docker image prune -f
#!/bin/bash
set -e 

echo "Останавливаем старые контейнеры..."
docker compose down --remove-orphans || true

echo "Скачиваем новые образы..."
docker compose pull

echo "Запускаем контейнеры..."
docker compose up -d --remove-orphans --force-recreate

echo "Чистим старые образы..."
docker image prune -f

echo "Деплой успешно завершен!"
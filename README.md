# 1. Перезагрузите конфигурацию systemd, чтобы он увидел новый файл
sudo systemctl daemon-reload

# 2. Запустите сервис прямо сейчас
sudo systemctl start "${SYSTEMD_SERVICE_NAME}"

# 3. Включите автозапуск при загрузке системы
sudo systemctl enable "${SYSTEMD_SERVICE_NAME}"

# Создаем сервисного пользователя, если его нет

# Создаем директории для сервиса, если их нет

# Скачиваем свежую версию сервиса

# Переносим свежую версию сервиса в целевую директорию

# Переносим свежую версию конфигурации в целевую директорию

# Запускаем сервис

sudo useradd --system --no-create-home --shell /usr/sbin/nologin --user-group "${SERVICE_NAME}"

# sudo journalctl -u "${SYSTEMD_SERVICE_NAME}" -n 50 --no-pager

ssh -l ildar 158.160.155.213
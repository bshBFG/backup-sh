#!/bin/bash

ROOT_DIR=$(cd $(dirname $(readlink -f $0))/.. && pwd)
source ${ROOT_DIR}/conf/default.sh
source "${ROOT_DIR}/libs/utils.sh"

# Проверка наличия и подключение конфигурационного файла
if [ ! -f "${ROOT_DIR}/settings.conf" ]; then
  error_exit "File settings.conf not found"
fi

source "${ROOT_DIR}/settings.conf"

# Проверка наличия конфигурационного файла
if [ ! -f "${ROOT_DIR}/settings.conf" ]; then
  error_exit "File settings.conf not found"
fi

# Проверяем наличие аргумента с путем к архиву
if [ -z "$1" ]; then
  error_exit "Please provide a path to the archive as an argument."
fi

# Получаем путь к архиву
BACKUP_ARCHIVE="$1"

# Проверяем существование архива
if [ ! -f "$BACKUP_ARCHIVE" ]; then
  error_exit "Archive not found at $BACKUP_ARCHIVE. Please check the provided path and try again."
fi

# Проверка существования необходимых директорий и файлов
if [[ ! -d "$PROJECT_DIR" ]]; then
  mkdir -p "$PROJECT_DIR" || error_exit "Project directory '$PROJECT_DIR' does not exist and cannot be created"
fi

# Удаляем старую директорию для установки, если она существует
if [[ -d "$TEMP_DEPLOY" ]]; then
  rm -rf "$TEMP_DEPLOY" || error_exit "Сan't delete temporary deployment directory"
fi

# Создаём новую директорию для установки
echo "Creating restore directory..."
mkdir -p "${TEMP_DEPLOY}" || error_exit "Failed to create deployment directory."

# Распаковываем архив
echo "Extracting archive..."
tar -xzf "$BACKUP_ARCHIVE" -C "$TEMP_DEPLOY" || error_exit "Failed to extract archive."

# Проверка директорий и файлов для восстановления
if [[ ! -f "$TEMP_DEPLOY/docker-compose.yml" ]]; then
  error_exit "Docker Compose file does not exist."
fi

if [[ ! -f "$TEMP_DEPLOY/db_backup.sql" ]]; then
  error_exit "Database dump file does not exist."
fi

for dir in "${BACKUP_DIRS[@]}"; do
  full_path=$TEMP_DEPLOY/$dir
  if [[ ! -d "$full_path" ]]; then
    error_exit "Folder '$dir' does not exist."
  fi
done

# Восстанавливаем docker-compose.yml
echo "Restoring Docker Compose file..."
mv "$TEMP_DEPLOY/docker-compose.yml" "$DOCKER_COMPOSE_FILE" || error_exit "Failed to restore Docker Compose file."

# Копируем файлы приложения
echo "Restoring directories..."
for dir in "${BACKUP_DIRS[@]}"; do
  rsync -av "$TEMP_DEPLOY/$dir/" "$PROJECT_DIR/$dir" || error_exit "Failed to restore $dir directory."
done

# Восстанавливаем базу данных
echo "Restoring database..."
docker compose up -d $DB_CONTAINER || error_exit "Failed to start database container."

# Убеждаемся, что база данных пустая
echo "Checking if database is empty..."
if docker compose exec $DB_CONTAINER psql -U $DB_USER -c "\dt" | grep -q 'No relations found'; then
  echo "Database is empty, proceeding with restoration."
else
  echo "Database is not empty. Dropping existing tables..."
  docker compose exec $DB_CONTAINER dropdb -U $DB_USER -e $DB_NAME && \
  docker compose exec $DB_CONTAINER createdb -U $DB_USER $DB_NAME || \
  error_exit "Failed to clear existing database."
fi

# Восстанавливаем данные из дампа
echo "Restoring data from SQL dump..."
cat "${TEMP_DEPLOY}/db_backup.sql" | docker compose exec -T $DB_CONTAINER psql -U $DB_USER -d $DB_NAME >/dev/null 2>&1 || error_exit "Failed to restore database."

# Запускаем контейнеры
echo "Starting containers..."
docker-compose -f $DOCKER_COMPOSE_FILE up -d || error_exit "Failed to start containers."

#Удаляем временные файлы
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DEPLOY" || error_exit "Failed to remove temporary restore directory."

echo "Restore completed successfully!"

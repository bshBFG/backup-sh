#!/bin/bash

ROOT_DIR=$(cd $(dirname $(readlink -f $0))/.. && pwd)
source ${ROOT_DIR}/conf/default.sh
source "${ROOT_DIR}/libs/utils.sh"

# Обрабатываем параметры введенные в консоль
source "${ROOT_DIR}/libs/params_handler.sh"

CONFIG_FILE_PATH=${CONFIG_FILE_PATH:-"${ROOT_DIR}/${CONFIG_FILE}"}

echo "${CONFIG_FILE_PATH}"

if [ ! -f "$CONFIG_FILE_PATH" ]; then
  error_exit "Config file not found"
fi

source "$CONFIG_FILE_PATH"

# Проверка наличия и подключение конфигурационного файла
if [ ! -f "${ROOT_DIR}/settings.conf" ]; then
  error_exit "Config not found"
fi

source "${ROOT_DIR}/settings.conf"


# Проверка существования необходимых директорий и файлов
if [ ! -d $PROJECT_DIR ]; then
  error_exit "Project directory '$PROJECT_DIR' does not exist."
fi

if [ ! -f $DOCKER_COMPOSE_FILE ]; then
  error_exit "Docker Compose file '$DOCKER_COMPOSE_FILE' does not exist."
fi

for dir in "${BACKUP_DIRS[@]}"; do
  full_path=$PROJECT_DIR/$dir
  if [ ! -d $full_path ]; then
    error_exit "Folder '$dir' does not exist."
  fi
done

# Проверка запуска контейнера базы данных
if ! docker compose -f "$DOCKER_COMPOSE_FILE" ps -q "$DB_CONTAINER" &>/dev/null; then
  error_exit "Database container is not running."
fi

# Проверка существования директории для бэкапов и её создание, если она не существует
if [ ! -d $BACKUPS ]; then
  mkdir -p "$BACKUPS" || error_exit "Failed to create backups directory."
fi

# Удаляем старую временную директорию для бэкапов, если она существует
if [ -d $TEMP_BACKUP ]; then
  rm -rf $TEMP_BACKUP || error_exit "Failed to delete old temporary backup directory."
fi

# Создаем временную директорию для бэкапов
mkdir -p $TEMP_BACKUP || error_exit "Failed to create temporary backup directory."

# Получаем текущую дату и время для именования архива
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Делаем дамп базы данных
echo "Creating database dump..."
docker compose -f $DOCKER_COMPOSE_FILE exec $DB_CONTAINER pg_dump -U $DB_USER -d $DB_NAME > "$TEMP_BACKUP/db_backup.sql" || error_exit "Failed to dump database."

# Копируем файлы приложений
echo "Copying uploads directory..."
for dir in "${BACKUP_DIRS[@]}"; do
  cp -R "$PROJECT_DIR/$dir" "$TEMP_BACKUP/$dir" || error_exit "Failed to copy $dir directory."
done

# Копируем docker-compose.yml
echo "Copying Docker Compose file..."
cp "$DOCKER_COMPOSE_FILE" "$TEMP_BACKUP/docker-compose.yml" || error_exit "Failed to copy Docker Compose file."

# Архивирование всех созданных резервных копий
echo "Archiving backups..."
ARCHIVE_NAME="${PROJECT_NAME}_backup_${TIMESTAMP}.tar.gz"
tar -czf "$BACKUPS/$ARCHIVE_NAME" -C "$TEMP_BACKUP" . || error_exit "Failed to create archive."

# Проверка успешного создания архива
if [[ ! -f "$BACKUPS/$ARCHIVE_NAME" ]]; then
  error_exit "Archive file was not created."
else
  echo "Archived backups to $BACKUPS/$ARCHIVE_NAME"
fi

# Выводим количество файлов и размер архива
num_files=$(find "$TEMP_BACKUP" -type f | wc -l)
archive_size=$(du -h "$BACKUPS/$ARCHIVE_NAME" | cut -f1)
echo "Created archive with $num_files files, size: $archive_size"

#Удаляем временные файлы
echo "Cleaning up temporary files..."
rm -rf "$TEMP_BACKUP" || error_exit "Failed to remove temporary backup directory."


# Чистим старые бэкапы
echo "Cleaning old backups..."
cleanup_old_backups "$BACKUPS" "$KEEP_LAST_N_BACKUPS"

echo "Backup completed successfully! Archive file: $ARCHIVE_NAME"

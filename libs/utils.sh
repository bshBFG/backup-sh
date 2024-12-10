error_exit() {
  echo "Error: $1" >&2
  exit 1
}

cleanup_old_backups() {
  # Получаем список всех бэкапов в порядке возрастания даты создания
  local backups=( "$1/"* )

  local KEEP_LAST_N_BACKUPS=$2

  # Оставляем только последние KEEP_LAST_N_BACKUPS бэкапов
  if (( ${#backups[@]} > KEEP_LAST_N_BACKUPS )); then
    for (( i = 0; i < ${#backups[@]} - KEEP_LAST_N_BACKUPS; i++ )); do
      if ! rm -f "${backups[i]}"; then
        echo "Warning: Failed to delete old backup '${backups[i]}'." >&2
      fi
    done
  fi
}

#!/bin/bash

# Опции для getopt
SHORT_OPTS="f:b:n:"
LONG_OPTS="file:,backups:,name:"

# Получение параметров
PARAMS=$(getopt --options ${SHORT_OPTS} --longoptions ${LONG_OPTS} --name "$0" -- "$@")
if [[ $? != 0 ]]; then
  echo "Incorrect params."
  exit 1
fi

eval set -- "${PARAMS}"

# Обрабатываем параметры
while true; do
  case "$1" in
    -f | --file )
      CONFIG_FILE_PATH="$2"; shift 2;;
    -b | --backups )
      readonly BACKUPS="$2"; shift 2;;
    -n | --name )
      readonly ARCHIVE_NAME="$2.tar.gz"; shift 2;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

# Остаток аргументов
ADDITIONAL_ARGS=("$@")

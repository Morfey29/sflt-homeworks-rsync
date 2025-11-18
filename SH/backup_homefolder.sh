#!/bin/bash

# резервное копирование домашней директории

# переменные
BACKUP_SOURCE="$HOME"
BACKUP_DEST="/tmp/backup"
LOG_TAG="HOME_FOLDER_BACKUP"
RSYNC_OPTS="-rlptvh --delete --checksum" 

# Функция логирования
log_message() {
    local level=$1
    local message=$2
    logger -t "$LOG_TAG" "[$level] $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Функция проверки директорий
check_directories() {
    if [ ! -d "$BACKUP_SOURCE" ]; then
        log_message "ERROR" "Источник не существует: $BACKUP_SOURCE"
        return 1
    fi
    
    # Создаем директорию назначения если не существует
    if [ ! -d "$BACKUP_DEST" ]; then
        mkdir -p "$BACKUP_DEST"
        if [ $? -ne 0 ]; then
            log_message "ERROR" "Не удалось создать директорию назначения: $BACKUP_DEST"
            return 1
        fi
        log_message "INFO" "Создана директория назначения: $BACKUP_DEST"
    fi
}

# Функция проверки места на диске
check_disk_space() {
    local available_space=$(df /tmp | awk 'NR==2 {print $4}')
    local source_size=$(du -s "$BACKUP_SOURCE" 2>/dev/null | cut -f1)
    
    # Если не удалось определить размер источника, пропускаем проверку
    if [ -z "$source_size" ]; then
        log_message "WARNING" "Не удалось определить размер источника, пропускаем проверку диска"
        return 0
    fi
    
    # Проверяем что доступно минимум в 1.5 раза больше места чем размер источника
    if [ "$available_space" -lt "$((source_size * 3 / 2))" ]; then
        log_message "ERROR" "Недостаточно места на диске. Доступно: ${available_space}KB, Требуется: ~$((source_size * 3 / 2))KB"
        return 1
    fi
}

# Функция резервного копирования
perform_backup() {
    local start_time=$(date +%s)
    
    log_message "INFO" "Начало резервного копирования из $BACKUP_SOURCE в $BACKUP_DEST"
    
    # Выполняем резервное копирование
    rsync $RSYNC_OPTS "$BACKUP_SOURCE/" "$BACKUP_DEST/" 2>&1
    local rsync_exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $rsync_exit_code -eq 0 ]; then
        log_message "SUCCESS" "Резервное копирование успешно завершено за ${duration} секунд"
        return 0
    else
        log_message "ERROR" "Ошибка резервного копирования. Код выхода: $rsync_exit_code. Время выполнения: ${duration} секунд"
        return $rsync_exit_code
    fi
}

# Задача
main() {
    log_message "INFO" "Запуск задачи резервного копирования"
    
    # Проверки
    check_directories || exit 1
    check_disk_space || exit 1
    
    # Выполняем резервное копирование
    perform_backup
    local backup_status=$?
    
    log_message "INFO" "Завершение задачи резервного копирования"
    exit $backup_status
}

# Запуск скрипта
main "$@"

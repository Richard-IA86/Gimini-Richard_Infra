#!/bin/bash

# Configuración
BACKUP_DIR="/opt/pose/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CONTAINER_NAME="pose_db"
DB_USER="postgres"
DB_NAME="pose_db"
BACKUP_FILE="$BACKUP_DIR/db_backup_$TIMESTAMP.sql.gz"

# Crear directorio si no existe
mkdir -p "$BACKUP_DIR"

# Ejecutar pg_dump dentro del contenedor
docker exec -t $CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME | gzip > "$BACKUP_FILE"

# Mantener solo los últimos 7 días de backups
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +7 -delete

echo "Backup completado: $BACKUP_FILE"

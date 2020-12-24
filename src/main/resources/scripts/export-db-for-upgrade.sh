#!/bin/bash

MYSQL_USER="${1:-root}"
MYSQL_PASSWORD="${2:-root}"
DB_NAME="${3:-openmrs}"
OUTPUT_FILE="${4:-/tmp/openmrs_export.sql}"
CONTAINER="${5}"

MYSQL_DUMP_CMD="mysqldump"
if [ ! -z "$CONTAINER" ]; then
  MYSQL_DUMP_CMD="docker exec -i $CONTAINER $MYSQL_DUMP_CMD"
fi

function execute_dump() {
  DUMP_ARGS="$@"
  COMMAND="$MYSQL_DUMP_CMD -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${DUMP_ARGS} $DB_NAME >> ${OUTPUT_FILE}"
  eval ${COMMAND}
}

function write_log() {
  echo "--" >> $OUTPUT_FILE
  echo "-- $(date): $1" >> $OUTPUT_FILE
  echo "--" >> $OUTPUT_FILE
}

write_log "Exporting Database"

write_log "Exporting schema..."
execute_dump --no-data

write_log "Exporting data..."
execute_dump \
  --no-create-info \
  --ignore-table=${DB_NAME}.sync_record \
  --ignore-table=${DB_NAME}.sync_server_record \
  --ignore-table=${DB_NAME}.sync_import \
  --ignore-table=${DB_NAME}.hl7_in_archive \
  --ignore-table=${DB_NAME}.hl7_in_error \
  --ignore-table=${DB_NAME}.hl7_in_queue \
  --ignore-table=${DB_NAME}.formentry_archive \
  --ignore-table=${DB_NAME}.formentry_error \
  --ignore-table=${DB_NAME}.formentry_queue \
  --ignore-table=${DB_NAME}.formentry_xsn \
  --ignore-table=${DB_NAME}.emrmonitor_report \
  --ignore-table=${DB_NAME}.emrmonitor_report_metric

write_log "Exporting Complete"

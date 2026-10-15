#!/usr/bin/env bash
set -uo pipefail
export AWS_PAGER=""

REGION="us-east-2"
ARCHIVO="recursos_cli.env"

if [ ! -f "$ARCHIVO" ]; then
  echo "No existe $ARCHIVO: no hay nada que eliminar."
  exit 0
fi
source "$ARCHIVO"

# 1. RDS (se inicia primero porque es lo más lento)
if [ -n "${RDS_ID:-}" ]; then
  echo "Eliminando RDS $RDS_ID..."
  aws rds delete-db-instance --region "$REGION" \
    --db-instance-identifier "$RDS_ID" --skip-final-snapshot > /dev/null
fi

# 2. S3: vaciar y eliminar
if [ -n "${BUCKET:-}" ]; then
  echo "Eliminando bucket $BUCKET..."
  aws s3 rb "s3://$BUCKET" --force
fi

# 3. EC2
if [ -n "${INSTANCE_ID:-}" ]; then
  echo "Terminando instancia $INSTANCE_ID..."
  aws ec2 terminate-instances --region "$REGION" \
    --instance-ids "$INSTANCE_ID" > /dev/null
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids "$INSTANCE_ID"
  echo "Instancia EC2 terminada."
fi

# 4. Esperar a que la RDS termine de eliminarse
if [ -n "${RDS_ID:-}" ]; then
  echo "Esperando a que la RDS termine de eliminarse (unos minutos)..."
  aws rds wait db-instance-deleted --region "$REGION" \
    --db-instance-identifier "$RDS_ID"
  echo "RDS eliminada."
fi

rm -f "$ARCHIVO"
echo "Eliminación completa."

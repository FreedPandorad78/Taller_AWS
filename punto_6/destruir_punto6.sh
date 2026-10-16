#!/usr/bin/env bash
set -uo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"

if [ ! -f recursos_punto6.env ]; then
  echo "No existe recursos_punto6.env: no hay nada que eliminar."
  exit 0
fi
source recursos_punto6.env
echo "Inicio de la eliminación: $(date)"

# 1. Crawler
if [ -n "${CRAWLER:-}" ]; then
  aws glue delete-crawler --region "$REGION" --name "$CRAWLER" && echo "Crawler eliminado."
fi

# 2. Tablas y base de datos del catálogo (los metadatos; los archivos están en S3)
for TABLA in envios envios_manual; do
  aws glue delete-table --region "$REGION" --database-name "${DATABASE:-taller_glue}" \
    --name "$TABLA" 2>/dev/null && echo "Tabla $TABLA eliminada."
done
if [ -n "${DATABASE:-}" ]; then
  aws glue delete-database --region "$REGION" --name "$DATABASE" && echo "Base de datos eliminada."
fi

# 3. Grupo de trabajo de Athena (con su historial de consultas)
if [ -n "${WORKGROUP:-}" ]; then
  aws athena delete-work-group --region "$REGION" --work-group "$WORKGROUP" \
    --recursive-delete-option && echo "Grupo de trabajo de Athena eliminado."
fi

# 4. Rol del crawler
if [ -n "${ROLE_NAME:-}" ]; then
  aws iam detach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole
  aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name leer-datos-taller
  aws iam delete-role --role-name "$ROLE_NAME" && echo "Rol de IAM eliminado."
fi

# 5. Bucket (datos y resultados de Athena)
if [ -n "${BUCKET:-}" ]; then
  aws s3 rb "s3://$BUCKET" --force && echo "Bucket eliminado."
fi

rm -f recursos_punto6.env
echo "Eliminación completa: $(date)"

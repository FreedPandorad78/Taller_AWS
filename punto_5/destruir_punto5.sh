#!/usr/bin/env bash
set -uo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"

if [ ! -f recursos_punto5.env ]; then
  echo "No existe recursos_punto5.env: no hay nada que eliminar."
  exit 0
fi
source recursos_punto5.env
echo "Inicio de la eliminación: $(date)"

# 1. Workgroup (se elimina antes que el namespace)
if [ -n "${WORKGROUP:-}" ]; then
  echo "Eliminando workgroup $WORKGROUP..."
  aws redshift-serverless delete-workgroup --region "$REGION" \
    --workgroup-name "$WORKGROUP" > /dev/null
  for i in $(seq 1 60); do
    aws redshift-serverless get-workgroup --region "$REGION" \
      --workgroup-name "$WORKGROUP" > /dev/null 2>&1 || break
    sleep 10
  done
  echo "Workgroup eliminado."
fi

# 2. Namespace (también elimina el secreto administrado de la contraseña)
if [ -n "${NAMESPACE:-}" ]; then
  echo "Eliminando namespace $NAMESPACE..."
  aws redshift-serverless delete-namespace --region "$REGION" \
    --namespace-name "$NAMESPACE" > /dev/null
  for i in $(seq 1 60); do
    aws redshift-serverless get-namespace --region "$REGION" \
      --namespace-name "$NAMESPACE" > /dev/null 2>&1 || break
    sleep 10
  done
  echo "Namespace eliminado."
fi

# 3. Grupo de seguridad (se reintenta hasta que se liberen las interfaces de red)
if [ -n "${SG_REDSHIFT:-}" ]; then
  for i in $(seq 1 20); do
    aws ec2 delete-security-group --region "$REGION" --group-id "$SG_REDSHIFT" 2>/dev/null \
      && { echo "Grupo de seguridad eliminado."; break; }
    sleep 15
  done
fi

# 4. Rol de IAM (primero su política en línea)
if [ -n "${ROLE_NAME:-}" ]; then
  aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name leer-bucket-taller
  aws iam delete-role --role-name "$ROLE_NAME" && echo "Rol de IAM eliminado."
fi

# 5. Bucket de S3 (vaciar y eliminar)
if [ -n "${BUCKET:-}" ]; then
  aws s3 rb "s3://$BUCKET" --force && echo "Bucket eliminado."
fi

rm -f recursos_punto5.env
echo "Eliminación completa: $(date)"

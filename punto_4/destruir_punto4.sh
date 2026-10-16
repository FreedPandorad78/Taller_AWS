#!/usr/bin/env bash
set -uo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"

if [ ! -f recursos_punto4.env ]; then
  echo "No existe recursos_punto4.env: no hay nada que eliminar."
  exit 0
fi
source recursos_punto4.env
echo "Inicio de la eliminación: $(date)"

# 1. Instancia y clúster de Neptune
if [ -n "${DB_INSTANCE_ID:-}" ]; then
  echo "Eliminando instancia $DB_INSTANCE_ID..."
  aws neptune delete-db-instance --region "$REGION" \
    --db-instance-identifier "$DB_INSTANCE_ID" --skip-final-snapshot > /dev/null
  aws neptune wait db-instance-deleted --region "$REGION" \
    --db-instance-identifier "$DB_INSTANCE_ID"
  echo "Instancia eliminada."
fi
if [ -n "${CLUSTER_ID:-}" ]; then
  echo "Eliminando clúster $CLUSTER_ID..."
  aws neptune delete-db-cluster --region "$REGION" \
    --db-cluster-identifier "$CLUSTER_ID" --skip-final-snapshot > /dev/null
  for i in $(seq 1 40); do
    aws neptune describe-db-clusters --region "$REGION" \
      --db-cluster-identifier "$CLUSTER_ID" > /dev/null 2>&1 || break
    sleep 15
  done
  echo "Clúster eliminado."
fi

# 2. Grupo de seguridad (se reintenta hasta que se libere la interfaz de red)
if [ -n "${SG_NEPTUNE:-}" ]; then
  for i in $(seq 1 20); do
    aws ec2 delete-security-group --region "$REGION" --group-id "$SG_NEPTUNE" 2>/dev/null \
      && { echo "Grupo de seguridad eliminado."; break; }
    sleep 15
  done
fi

# 3. Subnet group
if [ -n "${SUBNET_GROUP:-}" ]; then
  aws neptune delete-db-subnet-group --region "$REGION" \
    --db-subnet-group-name "$SUBNET_GROUP" && echo "Subnet group eliminado."
fi

rm -f recursos_punto4.env
echo "Eliminación completa: $(date)"

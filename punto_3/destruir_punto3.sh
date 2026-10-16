#!/usr/bin/env bash
set -uo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"

if [ ! -f recursos_punto3.env ]; then
  echo "No existe recursos_punto3.env: no hay nada que eliminar."
  exit 0
fi
source recursos_punto3.env
echo "Inicio de la eliminación: $(date)"

# 1. Instancia y clúster de DocumentDB
if [ -n "${DB_INSTANCE_ID:-}" ]; then
  echo "Eliminando instancia $DB_INSTANCE_ID..."
  aws docdb delete-db-instance --region "$REGION" \
    --db-instance-identifier "$DB_INSTANCE_ID" > /dev/null
  aws docdb wait db-instance-deleted --region "$REGION" \
    --db-instance-identifier "$DB_INSTANCE_ID"
  echo "Instancia eliminada."
fi
if [ -n "${CLUSTER_ID:-}" ]; then
  echo "Eliminando clúster $CLUSTER_ID..."
  aws docdb delete-db-cluster --region "$REGION" \
    --db-cluster-identifier "$CLUSTER_ID" --skip-final-snapshot > /dev/null
  for i in $(seq 1 40); do
    aws docdb describe-db-clusters --region "$REGION" \
      --db-cluster-identifier "$CLUSTER_ID" > /dev/null 2>&1 || break
    sleep 15
  done
  echo "Clúster eliminado."
fi

# 2. EC2 del túnel
if [ -n "${INSTANCE_ID:-}" ]; then
  echo "Terminando EC2 $INSTANCE_ID..."
  aws ec2 terminate-instances --region "$REGION" \
    --instance-ids "$INSTANCE_ID" > /dev/null
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids "$INSTANCE_ID"
  echo "EC2 terminada."
fi

# 3. Grupos de seguridad (primero el de DocumentDB, que referencia al de la EC2)
for SG in "${SG_DOCDB:-}" "${SG_EC2:-}"; do
  [ -z "$SG" ] && continue
  for i in $(seq 1 20); do
    aws ec2 delete-security-group --region "$REGION" --group-id "$SG" 2>/dev/null \
      && { echo "Grupo $SG eliminado."; break; }
    sleep 15
  done
done

# 4. Subnet group y par de claves
if [ -n "${SUBNET_GROUP:-}" ]; then
  aws docdb delete-db-subnet-group --region "$REGION" \
    --db-subnet-group-name "$SUBNET_GROUP" && echo "Subnet group eliminado."
fi
aws ec2 delete-key-pair --region "$REGION" --key-name taller-docdb-key \
  && echo "Par de claves eliminado."
rm -f ~/.ssh/taller-docdb-key.pem

rm -f recursos_punto3.env
echo "Eliminación completa: $(date)"

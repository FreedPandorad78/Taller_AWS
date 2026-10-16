#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"
source recursos_punto4.env

# 1. Clúster con autenticación IAM (requisito del punto de acceso público)
echo "Creando clúster Neptune 1.4.8.1 con autenticación IAM..."
aws neptune create-db-cluster --region "$REGION" \
  --db-cluster-identifier taller-neptune \
  --engine neptune --engine-version 1.4.8.1 \
  --db-subnet-group-name "$SUBNET_GROUP" \
  --vpc-security-group-ids "$SG_NEPTUNE" \
  --enable-iam-database-authentication \
  --no-deletion-protection > /dev/null
echo "CLUSTER_ID=taller-neptune" >> recursos_punto4.env

# 2. Instancia aprovisionada db.t4g.medium con punto de acceso público
echo "Creando instancia db.t4g.medium (pública)..."
aws neptune create-db-instance --region "$REGION" \
  --db-instance-identifier taller-neptune-1 \
  --db-instance-class db.t4g.medium \
  --engine neptune \
  --db-cluster-identifier taller-neptune \
  --publicly-accessible > /dev/null
echo "DB_INSTANCE_ID=taller-neptune-1" >> recursos_punto4.env

echo "Esperando a Neptune (unos 10 a 15 minutos)..."
aws neptune wait db-instance-available --region "$REGION" \
  --db-instance-identifier taller-neptune-1

# 3. Datos para conectar
NEPTUNE_ENDPOINT=$(aws neptune describe-db-clusters --region "$REGION" \
  --db-cluster-identifier taller-neptune \
  --query "DBClusters[0].Endpoint" --output text)
echo "NEPTUNE_ENDPOINT=$NEPTUNE_ENDPOINT" >> recursos_punto4.env

echo "Despliegue completo:"
cat recursos_punto4.env

#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"
source recursos_punto3.env

SUBNET_1=$(aws ec2 describe-subnets --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query "Subnets[0].SubnetId" --output text)

# 1. EC2 del túnel
echo "Creando EC2 del túnel (t3.micro)..."
AMI_ID=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query "Parameter.Value" --output text)
INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" --instance-type t3.micro --count 1 \
  --key-name taller-docdb-key \
  --security-group-ids "$SG_EC2" --subnet-id "$SUBNET_1" \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instancia-Tunel-DocDB}]' \
  --query "Instances[0].InstanceId" --output text)
echo "INSTANCE_ID=$INSTANCE_ID" >> recursos_punto3.env
echo "EC2 creada: $INSTANCE_ID"

# 2. Clúster DocumentDB Serverless (contraseña en Secrets Manager)
echo "Creando clúster DocumentDB Serverless..."
aws docdb create-db-cluster --region "$REGION" \
  --db-cluster-identifier taller-docdb \
  --engine docdb --engine-version 5.0.0 \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=1 \
  --master-username docdbadmin \
  --manage-master-user-password \
  --db-subnet-group-name "$SUBNET_GROUP" \
  --vpc-security-group-ids "$SG_DOCDB" > /dev/null
echo "CLUSTER_ID=taller-docdb" >> recursos_punto3.env

# 3. Instancia serverless del clúster
aws docdb create-db-instance --region "$REGION" \
  --db-cluster-identifier taller-docdb \
  --db-instance-identifier taller-docdb-1 \
  --db-instance-class db.serverless \
  --engine docdb > /dev/null
echo "DB_INSTANCE_ID=taller-docdb-1" >> recursos_punto3.env

echo "Esperando a DocumentDB (unos 10 a 15 minutos)..."
aws docdb wait db-instance-available --region "$REGION" \
  --db-instance-identifier taller-docdb-1
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

# 4. Datos para conectar
DOCDB_ENDPOINT=$(aws docdb describe-db-clusters --region "$REGION" \
  --db-cluster-identifier taller-docdb \
  --query "DBClusters[0].Endpoint" --output text)
SECRET_ARN=$(aws docdb describe-db-clusters --region "$REGION" \
  --db-cluster-identifier taller-docdb \
  --query "DBClusters[0].MasterUserSecret.SecretArn" --output text)
EC2_DNS=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicDnsName" --output text)
{
  echo "DOCDB_ENDPOINT=$DOCDB_ENDPOINT"
  echo "SECRET_ARN=$SECRET_ARN"
  echo "EC2_DNS=$EC2_DNS"
} >> recursos_punto3.env

echo "Despliegue completo:"
cat recursos_punto3.env

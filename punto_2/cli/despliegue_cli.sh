#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""

REGION="us-east-2"
ARCHIVO="recursos_cli.env"
: > "$ARCHIVO"

# 1. Bucket S3
BUCKET="bucket-taller-cli-$(date +%s)"
echo "Creando S3: $BUCKET..."
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
echo "BUCKET=$BUCKET" >> "$ARCHIVO"

# 2. Instancia EC2
echo "Obteniendo AMI y creando instancia EC2 (t3.micro)..."
AMI_ID=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 \
  --query "Parameter.Value" --output text)
INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" --instance-type t3.micro --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instancia-Taller-CLI}]' \
  --query "Instances[0].InstanceId" --output text)
echo "INSTANCE_ID=$INSTANCE_ID" >> "$ARCHIVO"
echo "EC2 creada con ID: $INSTANCE_ID"

# 3. Base de datos RDS con la contraseña en Secrets Manager
echo "Creando base de datos RDS (tarda unos minutos)..."
aws rds create-db-instance --region "$REGION" \
  --db-instance-identifier rds-taller-cli \
  --engine mysql --engine-version 8.0 \
  --db-instance-class db.t3.micro --allocated-storage 20 \
  --master-username admin \
  --manage-master-user-password \
  --no-publicly-accessible > /dev/null
echo "RDS_ID=rds-taller-cli" >> "$ARCHIVO"

aws rds wait db-instance-available --region "$REGION" \
  --db-instance-identifier rds-taller-cli
read -r RDS_ENDPOINT RDS_SECRET_ARN < <(aws rds describe-db-instances \
  --region "$REGION" --db-instance-identifier rds-taller-cli \
  --query "DBInstances[0].[Endpoint.Address,MasterUserSecret.SecretArn]" \
  --output text)
echo "RDS_ENDPOINT=$RDS_ENDPOINT" >> "$ARCHIVO"
echo "RDS_SECRET_ARN=$RDS_SECRET_ARN" >> "$ARCHIVO"

echo "Despliegue completo:"
cat "$ARCHIVO"

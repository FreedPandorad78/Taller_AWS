#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"

REGION=us-east-2
: > recursos_punto5.env
echo "REGION=$REGION" >> recursos_punto5.env

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true \
  --query "Vpcs[0].VpcId" --output text)
SUBNETS=$(aws ec2 describe-subnets --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query "Subnets[].SubnetId" --output text)

# 1. Bucket de S3
BUCKET="bucket-taller-redshift-$(date +%s)"
echo "Creando bucket $BUCKET..."
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
echo "BUCKET=$BUCKET" >> recursos_punto5.env

# 2. Rol de IAM que permite a Redshift leer los archivos de S3
echo "Creando rol de IAM taller-redshift-s3-role..."
cat > /tmp/confianza.json << 'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": ["redshift.amazonaws.com", "redshift-serverless.amazonaws.com"] },
    "Action": "sts:AssumeRole"
  }]
}
JSON
ROLE_ARN=$(aws iam create-role --role-name taller-redshift-s3-role \
  --assume-role-policy-document file:///tmp/confianza.json \
  --query "Role.Arn" --output text)
echo "ROLE_NAME=taller-redshift-s3-role" >> recursos_punto5.env
echo "ROLE_ARN=$ROLE_ARN" >> recursos_punto5.env

cat > /tmp/permisos_s3.json << JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"],
    "Resource": ["arn:aws:s3:::$BUCKET", "arn:aws:s3:::$BUCKET/*"]
  }]
}
JSON
aws iam put-role-policy --role-name taller-redshift-s3-role \
  --policy-name leer-bucket-taller --policy-document file:///tmp/permisos_s3.json
sleep 15   # el rol tarda unos segundos en propagarse

# 3. Grupo de seguridad sin reglas de entrada (la API de datos no necesita red local)
SG_REDSHIFT=$(aws ec2 create-security-group --region "$REGION" \
  --group-name taller-redshift-sg --description "Redshift Serverless del taller" \
  --vpc-id "$VPC_ID" --query GroupId --output text)
echo "SG_REDSHIFT=$SG_REDSHIFT" >> recursos_punto5.env

# 4. Namespace con la contraseña de administración en Secrets Manager
echo "Creando namespace de Redshift Serverless..."
aws redshift-serverless create-namespace --region "$REGION" \
  --namespace-name taller-redshift \
  --admin-username admin --manage-admin-password \
  --db-name dev --iam-roles "$ROLE_ARN" > /dev/null
echo "NAMESPACE=taller-redshift" >> recursos_punto5.env
for i in $(seq 1 60); do
  ESTADO=$(aws redshift-serverless get-namespace --region "$REGION" \
    --namespace-name taller-redshift --query "namespace.status" --output text)
  [ "$ESTADO" = "AVAILABLE" ] && break
  sleep 10
done
SECRET_ARN=$(aws redshift-serverless get-namespace --region "$REGION" \
  --namespace-name taller-redshift --query "namespace.adminPasswordSecretArn" --output text)
echo "SECRET_ARN=$SECRET_ARN" >> recursos_punto5.env

# 5. Workgroup de 4 RPU (el mínimo)
echo "Creando workgroup de 4 RPU (unos minutos)..."
aws redshift-serverless create-workgroup --region "$REGION" \
  --workgroup-name taller-wg --namespace-name taller-redshift \
  --base-capacity 4 --subnet-ids $SUBNETS \
  --security-group-ids "$SG_REDSHIFT" --no-publicly-accessible > /dev/null
echo "WORKGROUP=taller-wg" >> recursos_punto5.env
for i in $(seq 1 90); do
  ESTADO=$(aws redshift-serverless get-workgroup --region "$REGION" \
    --workgroup-name taller-wg --query "workgroup.status" --output text)
  [ "$ESTADO" = "AVAILABLE" ] && break
  sleep 10
done

# 6. Límite de uso: 5 RPU-horas al día, para que un descuido no cueste caro
WG_ARN=$(aws redshift-serverless get-workgroup --region "$REGION" \
  --workgroup-name taller-wg --query "workgroup.workgroupArn" --output text)
aws redshift-serverless create-usage-limit --region "$REGION" \
  --resource-arn "$WG_ARN" --usage-type serverless-compute \
  --amount 5 --period daily --breach-action deactivate > /dev/null

echo "Despliegue completo:"
cat recursos_punto5.env

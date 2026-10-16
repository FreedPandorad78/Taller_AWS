#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"
REGION=us-east-2
mkdir -p evidencias certs ~/.ssh

# Par de claves SSH para la EC2 del túnel (la clave privada queda fuera del repo)
aws ec2 create-key-pair --region $REGION --key-name taller-docdb-key --key-type rsa \
  --query KeyMaterial --output text > ~/.ssh/taller-docdb-key.pem
chmod 400 ~/.ssh/taller-docdb-key.pem

# Certificado TLS público de AWS (no se sube al repo)
curl -s -o certs/global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Red: VPC por defecto, grupos de seguridad y subnet group
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)
SUBNETS=($(aws ec2 describe-subnets --region $REGION --filters Name=vpc-id,Values=$VPC_ID Name=default-for-az,Values=true --query "Subnets[].SubnetId" --output text))
MI_IP=$(curl -s https://checkip.amazonaws.com)

SG_EC2=$(aws ec2 create-security-group --region $REGION --group-name taller-docdb-ec2-sg --description "SSH desde mi IP hacia la EC2 del tunel" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_EC2 --protocol tcp --port 22 --cidr ${MI_IP}/32 > /dev/null

SG_DOCDB=$(aws ec2 create-security-group --region $REGION --group-name taller-docdb-sg --description "DocumentDB: solo acepta la EC2 del tunel" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_DOCDB --protocol tcp --port 27017 --source-group $SG_EC2 > /dev/null

aws docdb create-db-subnet-group --region $REGION --db-subnet-group-name taller-docdb-subnets --db-subnet-group-description "Subredes de la VPC por defecto" --subnet-ids "${SUBNETS[@]}" > /dev/null

cat > recursos_punto3.env << EOF
REGION=$REGION
VPC_ID=$VPC_ID
SG_EC2=$SG_EC2
SG_DOCDB=$SG_DOCDB
SUBNET_GROUP=taller-docdb-subnets
EOF
echo "Preparación lista:"; cat recursos_punto3.env

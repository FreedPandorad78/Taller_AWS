#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"
REGION=us-east-2
mkdir -p evidencias

VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)
SUBNETS=($(aws ec2 describe-subnets --region $REGION --filters Name=vpc-id,Values=$VPC_ID Name=default-for-az,Values=true --query "Subnets[].SubnetId" --output text))
MI_IP=$(curl -s https://checkip.amazonaws.com)

SG_NEPTUNE=$(aws ec2 create-security-group --region $REGION --group-name taller-neptune-sg --description "Neptune: puerto 8182 solo desde mi IP" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_NEPTUNE --protocol tcp --port 8182 --cidr ${MI_IP}/32 > /dev/null

aws neptune create-db-subnet-group --region $REGION --db-subnet-group-name taller-neptune-subnets --db-subnet-group-description "Subredes de la VPC por defecto" --subnet-ids "${SUBNETS[@]}" > /dev/null

cat > recursos_punto4.env << EOF
REGION=$REGION
VPC_ID=$VPC_ID
SG_NEPTUNE=$SG_NEPTUNE
SUBNET_GROUP=taller-neptune-subnets
EOF
echo "Red lista:"; cat recursos_punto4.env

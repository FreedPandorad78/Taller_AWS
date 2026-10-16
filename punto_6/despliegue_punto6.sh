#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")"

REGION=us-east-2
: > recursos_punto6.env
echo "REGION=$REGION" >> recursos_punto6.env

# 1. Bucket y primera entrega de datos
BUCKET="bucket-taller-glue-$(date +%s)"
echo "Creando bucket $BUCKET..."
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
echo "BUCKET=$BUCKET" >> recursos_punto6.env
aws s3 cp datos/envios_1.csv "s3://$BUCKET/envios/envios_1.csv" > /dev/null
echo "Subido: envios/envios_1.csv"

# 2. Rol que usa el crawler para leer S3 y escribir en el catálogo
echo "Creando rol de IAM taller-glue-crawler-role..."
cat > /tmp/confianza_glue.json << 'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "glue.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
JSON
aws iam create-role --role-name taller-glue-crawler-role \
  --assume-role-policy-document file:///tmp/confianza_glue.json > /dev/null
echo "ROLE_NAME=taller-glue-crawler-role" >> recursos_punto6.env
aws iam attach-role-policy --role-name taller-glue-crawler-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole
cat > /tmp/permisos_s3_glue.json << JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": ["arn:aws:s3:::$BUCKET", "arn:aws:s3:::$BUCKET/envios/*"]
  }]
}
JSON
aws iam put-role-policy --role-name taller-glue-crawler-role \
  --policy-name leer-datos-taller --policy-document file:///tmp/permisos_s3_glue.json
sleep 15   # el rol tarda unos segundos en propagarse

# 3. Base de datos del catálogo
aws glue create-database --region "$REGION" \
  --database-input Name=taller_glue,Description="Base de datos del taller de Glue" > /dev/null
echo "DATABASE=taller_glue" >> recursos_punto6.env

# 4. Crawler (MergeNewColumns: al volver a ejecutarse conserva las correcciones de tipos)
aws glue create-crawler --region "$REGION" \
  --name taller-crawler \
  --role taller-glue-crawler-role \
  --database-name taller_glue \
  --targets "{\"S3Targets\":[{\"Path\":\"s3://$BUCKET/envios/\"}]}" \
  --schema-change-policy UpdateBehavior=UPDATE_IN_DATABASE,DeleteBehavior=LOG \
  --configuration '{"Version":1.0,"CrawlerOutput":{"Tables":{"AddOrUpdateBehavior":"MergeNewColumns"}}}' > /dev/null
echo "CRAWLER=taller-crawler" >> recursos_punto6.env

# 5. Grupo de trabajo de Athena: guarda resultados en S3 y limita los datos por consulta
aws athena create-work-group --region "$REGION" --name taller-athena \
  --configuration "ResultConfiguration={OutputLocation=s3://$BUCKET/athena-resultados/},EnforceWorkGroupConfiguration=true,BytesScannedCutoffPerQuery=10485760" > /dev/null
echo "WORKGROUP=taller-athena" >> recursos_punto6.env

echo "Despliegue completo:"
cat recursos_punto6.env

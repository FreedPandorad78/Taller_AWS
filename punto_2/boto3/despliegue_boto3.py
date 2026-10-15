import json
import time

import boto3

REGION = "us-east-2"  # misma región que Terraform y el punto 1
ARCHIVO_RECURSOS = "recursos_boto3.json"

ec2 = boto3.client("ec2", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION)
rds = boto3.client("rds", region_name=REGION)
ssm = boto3.client("ssm", region_name=REGION)

recursos = {}


def guardar():
    # Se guarda después de cada recurso, para que destruir_boto3.py
    # funcione aunque el despliegue se interrumpa a la mitad
    with open(ARCHIVO_RECURSOS, "w") as f:
        json.dump(recursos, f, indent=2)


def desplegar_infraestructura():
    # 1. Bucket S3
    nombre_bucket = f"bucket-taller-boto3-{int(time.time())}"
    print(f"Creando S3: {nombre_bucket}...")
    s3.create_bucket(
        Bucket=nombre_bucket,
        CreateBucketConfiguration={"LocationConstraint": REGION},
    )
    recursos["bucket"] = nombre_bucket
    guardar()

    # 2. Instancia EC2
    print("Obteniendo AMI y creando instancia EC2 (t3.micro)...")
    param = ssm.get_parameter(
        Name="/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
    )
    ami_id = param["Parameter"]["Value"]

    instancia = ec2.run_instances(
        ImageId=ami_id,
        InstanceType="t3.micro",
        MaxCount=1,
        MinCount=1,
        TagSpecifications=[
            {
                "ResourceType": "instance",
                "Tags": [{"Key": "Name", "Value": "Instancia-Taller-Boto3"}],
            }
        ],
    )
    instance_id = instancia["Instances"][0]["InstanceId"]
    recursos["instance_id"] = instance_id
    guardar()
    print(f"EC2 creada con ID: {instance_id}")

    # 3. Base de datos RDS con la contraseña en Secrets Manager
    print("Creando base de datos RDS (tarda unos minutos)...")
    rds.create_db_instance(
        DBInstanceIdentifier="rds-taller-boto3",
        Engine="mysql",
        EngineVersion="8.0",
        DBInstanceClass="db.t3.micro",
        AllocatedStorage=20,
        MasterUsername="admin",
        ManageMasterUserPassword=True,  # Delega la contraseña a Secrets Manager
        PubliclyAccessible=False,
    )
    recursos["rds_id"] = "rds-taller-boto3"
    guardar()

    rds.get_waiter("db_instance_available").wait(
        DBInstanceIdentifier="rds-taller-boto3"
    )
    info = rds.describe_db_instances(DBInstanceIdentifier="rds-taller-boto3")[
        "DBInstances"
    ][0]
    recursos["rds_endpoint"] = info["Endpoint"]["Address"]
    recursos["rds_secret_arn"] = info["MasterUserSecret"]["SecretArn"]
    guardar()

    print("Despliegue completo:")
    print(json.dumps(recursos, indent=2))


if __name__ == "__main__":
    desplegar_infraestructura()
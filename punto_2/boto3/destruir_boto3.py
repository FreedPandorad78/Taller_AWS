import json
import os

import boto3
from botocore.exceptions import ClientError

REGION = "us-east-2"  # misma región que el despliegue
ARCHIVO_RECURSOS = "recursos_boto3.json"

ec2 = boto3.client("ec2", region_name=REGION)
s3 = boto3.resource("s3", region_name=REGION)
rds = boto3.client("rds", region_name=REGION)


def destruir_infraestructura():
    if not os.path.exists(ARCHIVO_RECURSOS):
        print(f"No existe {ARCHIVO_RECURSOS}: no hay nada que eliminar.")
        return

    with open(ARCHIVO_RECURSOS) as f:
        recursos = json.load(f)

    # 1. RDS: se inicia primero porque es lo más lento
    rds_id = recursos.get("rds_id")
    if rds_id:
        print(f"Eliminando RDS {rds_id}...")
        try:
            rds.delete_db_instance(
                DBInstanceIdentifier=rds_id,
                SkipFinalSnapshot=True,  # sin snapshot final, para no dejar cobros
            )
        except ClientError as e:
            print(f"Nota RDS: {e}")
            rds_id = None

    # 2. S3: vaciar y luego eliminar
    nombre_bucket = recursos.get("bucket")
    if nombre_bucket:
        print(f"Eliminando bucket {nombre_bucket}...")
        try:
            bucket = s3.Bucket(nombre_bucket)
            bucket.objects.all().delete()
            bucket.delete()
            print("Bucket eliminado.")
        except ClientError as e:
            print(f"Nota S3: {e}")

    # 3. EC2
    instance_id = recursos.get("instance_id")
    if instance_id:
        print(f"Terminando instancia {instance_id}...")
        try:
            ec2.terminate_instances(InstanceIds=[instance_id])
        except ClientError as e:
            print(f"Nota EC2: {e}")
            instance_id = None

    # 4. Esperar a que EC2 y RDS terminen de eliminarse
    if instance_id:
        ec2.get_waiter("instance_terminated").wait(InstanceIds=[instance_id])
        print("Instancia EC2 terminada.")
    if rds_id:
        print("Esperando a que la RDS termine de eliminarse (unos minutos)...")
        rds.get_waiter("db_instance_deleted").wait(DBInstanceIdentifier=rds_id)
        print("RDS eliminada.")

    os.remove(ARCHIVO_RECURSOS)
    print("Eliminación completa.")


if __name__ == "__main__":
    destruir_infraestructura()
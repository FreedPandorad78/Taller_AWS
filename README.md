# Taller AWS - Ingeniería de Datos 2026-2

Código, consultas, instrucciones y evidencias de la Actividad AWS (seis puntos). Todo se ejecutó en una sola región, **us-east-2 (Ohio)**, con el usuario de IAM `user_cli` y nunca con la cuenta raíz. Los recursos se eliminaron al terminar cada punto. Las respuestas a las preguntas, las estimaciones de costos y los diagramas están en el informe entregado.

## Requisitos

- AWS CLI v2 configurada con `aws configure` para `user_cli`. Comprobación: `aws sts get-caller-identity` debe mostrar `user/user_cli`.
- Python 3 con `pip install --upgrade boto3 pymongo`.
- Terraform (punto 2) y MongoDB Compass (punto 3).
- Una cuenta con plan de pago de AWS: el plan gratuito bloquea DocumentDB (`FreeTierRestrictionError`).
- Las políticas de IAM de `user_cli` están en `politicas/`.

## Secretos y seguridad

- Ninguna contraseña ni clave está escrita en el código. Las contraseñas de DocumentDB y de Redshift las administra Secrets Manager y los programas las recuperan en tiempo de ejecución (Boto3 o la API de datos de Redshift). RDS tiene su contraseña administrada en Secrets Manager. Neptune y el punto 6 (S3, Glue y Athena) usan solo permisos IAM, sin contraseñas.
- No se publican claves de IAM, llaves privadas (`.pem`), archivos de estado de Terraform ni archivos `recursos_*.env` (están en `.gitignore`).
- Los datos de los puntos 3, 5 y 6 son sintéticos.
- Los scripts `despliegue_*` anotan cada recurso en un archivo `recursos_*.env` apenas lo crean, y los scripts `destruir_*` leen ese archivo para eliminar exactamente lo creado.

## Estructura

```
politicas/            Políticas de IAM de user_cli (JSON)
punto_1/              AWS Secrets Manager
punto_2/              Terraform (main.tf), boto3/ y cli/
punto_3/              Amazon DocumentDB
punto_4/              Amazon Neptune
punto_5/              Amazon Redshift Serverless
punto_6/              AWS Glue Data Catalog y Athena
evidencias_finales/   Revisión final de recursos y evidencia del punto 1
```

Cada punto tiene su carpeta `evidencias/` con las salidas de terminal de la creación, los resultados, la destrucción y la verificación de eliminación.

## Punto 1. Secrets Manager

1. En Secrets Manager (us-east-2) crear el secreto `mi_secreto_prueba` con las claves `usuario` y `password` (valores ficticios).
2. Dar a `user_cli` la política `politicas/politica_punto1.json` (solo `GetSecretValue` sobre ese secreto).
3. `python punto_1/punto1.py`
4. Cambiar el valor del secreto en la consola y volver a ejecutar: el programa obtiene la versión actual (`AWSCURRENT`) sin cambiar el código.
5. Eliminar: `aws secretsmanager delete-secret --secret-id mi_secreto_prueba --region us-east-2 --recovery-window-in-days 7`. Evidencia: `evidencias_finales/secreto_punto1.txt`.

## Punto 2. Terraform, Boto3 y AWS CLI

Crea un bucket de S3, una EC2 t3.micro y una RDS MySQL db.t3.micro con la contraseña administrada en Secrets Manager, en la VPC por defecto. Se hacen **en secuencia** y cada versión se destruye antes de iniciar la siguiente.

```bash
# Terraform
cd punto_2 && terraform init && terraform apply
terraform destroy

# Boto3
cd punto_2/boto3
python despliegue_boto3.py      # genera recursos_boto3.json
python destruir_boto3.py

# AWS CLI
cd punto_2/cli
./despliegue_cli.sh             # genera recursos_cli.env
./destruir_cli.sh
```

Política de IAM: `politicas/politica_user_cli.json`.

## Punto 3. DocumentDB

DocumentDB Serverless (0,5 a 1 DCU) con contraseña administrada, accesible desde el computador mediante una EC2 y un túnel SSH.

```bash
cd punto_3
./preparar_punto3.sh            # par de claves, certificado TLS, grupos de seguridad, subnet group
time ./despliegue_punto3.sh     # EC2 del túnel + clúster Serverless
./tunel_ssh.sh                  # en OTRA terminal; dejarla abierta
set -a; source recursos_punto3.env; set +a
python punto3.py                # inserta 10 documentos y ejecuta filtro, ordenación y agregación
./destruir_punto3.sh
```

Compass: URI `mongodb://docdbadmin@127.0.0.1:27018/?directConnection=true&tls=true&tlsAllowInvalidHostnames=true&tlsCAFile=<ruta>/punto_3/certs/global-bundle.pem&retryWrites=false`, con la contraseña tomada del secreto `rds!cluster-...` (no se escribe en ningún archivo). Política de lectura del secreto: `politicas/politica_docdb_secreto.json`.

## Punto 4. Neptune

Clúster Neptune 1.4.8.1 con una instancia db.t4g.medium, autenticación IAM y punto de acceso público (puerto 8182 solo desde mi IP). No usa EC2.

```bash
cd punto_4
./preparar_red_punto4.sh
time ./despliegue_punto4.sh
set -a; source recursos_punto4.env; set +a
aws neptunedata get-engine-status --region $REGION --endpoint-url https://$NEPTUNE_ENDPOINT:8182
python punto4.py                # grafo de 10 vértices y 20 relaciones; 3 consultas openCypher
./destruir_punto4.sh
```

Política: `politicas/politica_neptune.json`.

## Punto 5. Redshift

Redshift Serverless (4 RPU) con la contraseña de administración en Secrets Manager. El programa sube dos CSV a S3, crea las tablas, carga con `COPY` (rol de IAM) y consulta con la API de datos.

```bash
cd punto_5
python generar_datos.py         # clientes.csv y pedidos.csv (semilla fija)
time ./despliegue_punto5.sh
set -a; source recursos_punto5.env; set +a
python punto5.py
./destruir_punto5.sh
```

Política: `politicas/politica_redshift.json`.

## Punto 6. Glue Data Catalog y Athena

```bash
cd punto_6
python generar_datos.py         # envios_1.csv (24 registros) y envios_2.csv (8)
./despliegue_punto6.sh          # bucket, rol, base de datos, crawler y grupo de trabajo de Athena
set -a; source recursos_punto6.env; set +a
aws glue start-crawler --region $REGION --name $CRAWLER    # esperar a que quede en READY
python corregir_esquema.py      # codigo_postal -> string, fecha_envio -> date
python punto6.py                # consultas con filtro y agrupación
aws s3 cp datos/envios_2.csv s3://$BUCKET/envios/envios_2.csv
aws glue start-crawler --region $REGION --name $CRAWLER    # actualiza el catálogo
python punto6.py
python athena_sql.py tabla_manual.sql        # tabla manual para comparar con el crawler
python athena_sql.py comparar_tablas.sql
./destruir_punto6.sh
```

El grupo de registros `/aws-glue/crawlers` de CloudWatch no se elimina con el crawler y se borró aparte (`aws logs delete-log-group`). Política: `politicas/politica_glue_athena.json`.

## Notas

- Los precios del informe son de referencia, tomados de la documentación y de fuentes secundarias, y deben confirmarse en la calculadora de AWS.
- `evidencias_finales/revision_final.txt` es un barrido de la cuenta en us-east-2 al terminar: no quedaron instancias, bases de datos, clústeres, secretos ni buckets del taller.

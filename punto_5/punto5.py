import json
import os
import time

import boto3

REGION = os.environ.get("REGION", "us-east-2")
BUCKET = os.environ["BUCKET"]          # viene de recursos_punto5.env
ROLE_ARN = os.environ["ROLE_ARN"]      # rol que permite a Redshift leer S3
SECRET_ARN = os.environ["SECRET_ARN"]  # contraseña administrada en Secrets Manager
WORKGROUP = os.environ["WORKGROUP"]
BASE_DE_DATOS = "dev"
CARPETA_DATOS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "datos")

s3 = boto3.client("s3", region_name=REGION)
rsd = boto3.client("redshift-data", region_name=REGION)


def ejecutar(sql):
    """Envía una sentencia con la API de datos, espera a que termine y devuelve su id."""
    sentencia = rsd.execute_statement(
        WorkgroupName=WORKGROUP,
        Database=BASE_DE_DATOS,
        SecretArn=SECRET_ARN,  # autenticación con el secreto, sin contraseña en el código
        Sql=sql,
    )
    id_sentencia = sentencia["Id"]
    while True:
        estado = rsd.describe_statement(Id=id_sentencia)
        if estado["Status"] in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(2)
    if estado["Status"] != "FINISHED":
        raise RuntimeError(f"Sentencia en estado {estado['Status']}: {estado.get('Error')}")
    return id_sentencia


def resultados(id_sentencia):
    """Recupera todas las filas de una consulta como lista de diccionarios."""
    filas, columnas, token = [], None, None
    while True:
        argumentos = {"Id": id_sentencia}
        if token:
            argumentos["NextToken"] = token
        respuesta = rsd.get_statement_result(**argumentos)
        if columnas is None:
            columnas = [c["name"] for c in respuesta["ColumnMetadata"]]
        for registro in respuesta["Records"]:
            filas.append({
                columnas[i]: (None if celda.get("isNull") else list(celda.values())[0])
                for i, celda in enumerate(registro)
            })
        token = respuesta.get("NextToken")
        if not token:
            return filas


def consultar(titulo, sql):
    print(f"\n=== {titulo} ===")
    for fila in resultados(ejecutar(sql)):
        print(json.dumps(fila, ensure_ascii=False))


def main():
    # 1. Subir los archivos a S3
    for nombre in ("clientes.csv", "pedidos.csv"):
        s3.upload_file(os.path.join(CARPETA_DATOS, nombre), BUCKET, nombre)
        print(f"Subido a S3: {nombre}")

    # 2. Crear las tablas (se recrean para poder repetir el programa)
    ejecutar("DROP TABLE IF EXISTS pedidos")
    ejecutar("DROP TABLE IF EXISTS clientes")
    ejecutar("""
        CREATE TABLE clientes (
            cliente_id     INTEGER PRIMARY KEY,
            nombre         VARCHAR(100),
            ciudad         VARCHAR(50),
            fecha_registro DATE
        )""")
    ejecutar("""
        CREATE TABLE pedidos (
            pedido_id      INTEGER PRIMARY KEY,
            cliente_id     INTEGER REFERENCES clientes (cliente_id),
            fecha          DATE,
            producto       VARCHAR(50),
            cantidad       INTEGER,
            valor_unitario DECIMAL(10, 2)
        )""")
    print("Tablas creadas: clientes y pedidos")

    # 3. Cargar los datos con COPY desde S3 usando el rol de IAM
    for tabla in ("clientes", "pedidos"):
        ejecutar(
            f"COPY {tabla} FROM 's3://{BUCKET}/{tabla}.csv' "
            f"IAM_ROLE '{ROLE_ARN}' FORMAT AS CSV IGNOREHEADER 1 REGION '{REGION}'"
        )
        print(f"COPY terminado: {tabla}")

    consultar("Filas cargadas", """
        SELECT 'clientes' AS tabla, COUNT(*) AS filas FROM clientes
        UNION ALL
        SELECT 'pedidos', COUNT(*) FROM pedidos""")

    # 4. Consultas
    consultar("Consulta 1 (filtro): pedidos con total de 4000 o más", """
        SELECT pedido_id, producto, cantidad, valor_unitario,
               cantidad * valor_unitario AS total
        FROM pedidos
        WHERE cantidad * valor_unitario >= 4000
        ORDER BY total DESC
        LIMIT 10""")

    consultar("Consulta 2 (unión): pedidos con el nombre y la ciudad del cliente", """
        SELECT p.pedido_id, c.nombre, c.ciudad, p.producto,
               p.cantidad * p.valor_unitario AS total
        FROM pedidos p
        JOIN clientes c ON c.cliente_id = p.cliente_id
        ORDER BY p.pedido_id
        LIMIT 10""")

    consultar("Consulta 3 (agregación): ventas por producto", """
        SELECT producto,
               COUNT(*) AS pedidos,
               SUM(cantidad) AS unidades,
               SUM(cantidad * valor_unitario) AS ventas,
               ROUND(AVG(cantidad * valor_unitario), 2) AS ticket_promedio
        FROM pedidos
        GROUP BY producto
        ORDER BY ventas DESC""")

    consultar("Consulta 4 (filtro + unión + agregación): ventas por ciudad desde abril de 2026", """
        SELECT c.ciudad,
               COUNT(DISTINCT c.cliente_id) AS clientes_con_pedidos,
               COUNT(*) AS pedidos,
               SUM(p.cantidad * p.valor_unitario) AS ventas
        FROM pedidos p
        JOIN clientes c ON c.cliente_id = p.cliente_id
        WHERE p.fecha >= '2026-04-01'
        GROUP BY c.ciudad
        ORDER BY ventas DESC""")


if __name__ == "__main__":
    main()

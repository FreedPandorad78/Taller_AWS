import os
import time

import boto3

REGION = os.environ.get("REGION", "us-east-2")
BASE_DE_DATOS = os.environ["DATABASE"]
GRUPO = os.environ["WORKGROUP"]
athena = boto3.client("athena", region_name=REGION)

TB = 2 ** 40
MINIMO_FACTURADO = 10 * 1024 * 1024  # Athena factura mínimo 10 MB por consulta
escaneos = []


def ejecutar(sql):
    consulta = athena.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={"Database": BASE_DE_DATOS},
        WorkGroup=GRUPO,
    )["QueryExecutionId"]
    while True:
        ejecucion = athena.get_query_execution(QueryExecutionId=consulta)["QueryExecution"]
        estado = ejecucion["Status"]["State"]
        if estado in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(1)
    if estado != "SUCCEEDED":
        raise RuntimeError(f"{estado}: {ejecucion['Status'].get('StateChangeReason')}")
    return consulta, ejecucion["Statistics"].get("DataScannedInBytes", 0)


def filas(consulta):
    columnas, resultado = None, []
    for pagina in athena.get_paginator("get_query_results").paginate(QueryExecutionId=consulta):
        for fila in pagina["ResultSet"]["Rows"]:
            valores = [celda.get("VarCharValue") for celda in fila["Data"]]
            if columnas is None:
                columnas = valores
            else:
                resultado.append(dict(zip(columnas, valores)))
    return resultado


def consultar(titulo, sql):
    consulta, bytes_escaneados = ejecutar(sql)
    escaneos.append(bytes_escaneados)
    print(f"\n=== {titulo} (bytes escaneados: {bytes_escaneados}) ===")
    for fila in filas(consulta):
        print(fila)


consultar("Total de registros", "SELECT COUNT(*) AS total FROM envios")

consultar("Códigos postales por ciudad (comprueba los ceros a la izquierda)",
          "SELECT DISTINCT ciudad, codigo_postal FROM envios ORDER BY ciudad")

consultar("Filtro: envíos entregados de más de 8 kg",
          "SELECT envio_id, cliente, ciudad, peso_kg, valor_envio FROM envios "
          "WHERE estado = 'Entregado' AND peso_kg > 8 ORDER BY valor_envio DESC LIMIT 10")

consultar("Agrupación: resumen por ciudad",
          "SELECT ciudad, COUNT(*) AS envios, ROUND(AVG(peso_kg), 2) AS peso_promedio, "
          "SUM(valor_envio) AS valor_total FROM envios GROUP BY ciudad ORDER BY valor_total DESC")

consultar("Agrupación: envíos por estado",
          "SELECT estado, COUNT(*) AS envios, SUM(valor_envio) AS valor_total "
          "FROM envios GROUP BY estado ORDER BY envios DESC")

consultar("Agrupación: envíos por mes (comprueba que fecha_envio es de tipo date)",
          "SELECT month(fecha_envio) AS mes, COUNT(*) AS envios FROM envios GROUP BY 1 ORDER BY 1")

facturado = sum(max(b, MINIMO_FACTURADO) for b in escaneos)
print(f"\nConsultas: {len(escaneos)} | bytes escaneados: {sum(escaneos)} | "
      f"bytes facturados (mínimo 10 MB por consulta): {facturado}")
print(f"Costo estimado de Athena a USD 5 por TB: USD {facturado / TB * 5:.5f}")

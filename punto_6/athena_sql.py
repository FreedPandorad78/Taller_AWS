import os
import sys
import time

import boto3

REGION = os.environ.get("REGION", "us-east-2")
athena = boto3.client("athena", region_name=REGION)

with open(sys.argv[1], encoding="utf-8") as f:
    texto = f.read().replace("__BUCKET__", os.environ["BUCKET"])

for sentencia in [s.strip() for s in texto.split(";") if s.strip()]:
    if all(l.strip().startswith("--") or not l.strip() for l in sentencia.splitlines()):
        continue
    consulta = athena.start_query_execution(
        QueryString=sentencia,
        QueryExecutionContext={"Database": os.environ["DATABASE"]},
        WorkGroup=os.environ["WORKGROUP"],
    )["QueryExecutionId"]
    while True:
        ejecucion = athena.get_query_execution(QueryExecutionId=consulta)["QueryExecution"]
        estado = ejecucion["Status"]["State"]
        if estado in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(1)
    if estado != "SUCCEEDED":
        raise SystemExit(f"{estado}: {ejecucion['Status'].get('StateChangeReason')}")
    print(f"Sentencia ejecutada ({ejecucion['Statistics'].get('DataScannedInBytes', 0)} bytes escaneados)")
    if sentencia.lstrip().upper().startswith("SELECT"):
        columnas = None
        for pagina in athena.get_paginator("get_query_results").paginate(QueryExecutionId=consulta):
            for fila in pagina["ResultSet"]["Rows"]:
                valores = [c.get("VarCharValue") for c in fila["Data"]]
                if columnas is None:
                    columnas = valores
                else:
                    print(dict(zip(columnas, valores)))

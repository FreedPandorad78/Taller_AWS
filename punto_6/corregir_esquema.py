import os

import boto3

REGION = os.environ.get("REGION", "us-east-2")
BASE_DE_DATOS = os.environ["DATABASE"]
glue = boto3.client("glue", region_name=REGION)

tabla = glue.get_table(DatabaseName=BASE_DE_DATOS, Name="envios")["Table"]
print("Serializador:", tabla["StorageDescriptor"]["SerdeInfo"]["SerializationLibrary"])

# Correcciones: el código postal es un identificador (texto) y la fecha debe ser fecha
correcciones = {"codigo_postal": "string", "fecha_envio": "date"}
for columna in tabla["StorageDescriptor"]["Columns"]:
    if columna["Name"] in correcciones:
        print(f"{columna['Name']}: {columna['Type']} -> {correcciones[columna['Name']]}")
        columna["Type"] = correcciones[columna["Name"]]

# update_table solo acepta algunos campos; se descartan los de solo lectura
permitidos = ["Name", "Description", "Owner", "Retention", "StorageDescriptor",
              "PartitionKeys", "TableType", "Parameters"]
entrada = {k: tabla[k] for k in permitidos if k in tabla}
glue.update_table(DatabaseName=BASE_DE_DATOS, TableInput=entrada)
print("Tabla actualizada en el catálogo.")

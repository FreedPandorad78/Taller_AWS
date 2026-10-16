import json
import os

import boto3
from pymongo import MongoClient

REGION = os.environ.get("REGION", "us-east-2")
SECRET_ARN = os.environ["SECRET_ARN"]  # viene de recursos_punto3.env
CA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "certs", "global-bundle.pem")
PUERTO_LOCAL = 27018  # extremo local del túnel SSH


def obtener_credenciales():
    """Recupera usuario y contraseña desde Secrets Manager en tiempo de ejecución."""
    cliente = boto3.client("secretsmanager", region_name=REGION)
    respuesta = cliente.get_secret_value(SecretId=SECRET_ARN)
    return json.loads(respuesta["SecretString"])


def conectar():
    cred = obtener_credenciales()
    cliente = MongoClient(
        host="127.0.0.1",
        port=PUERTO_LOCAL,
        username=cred["username"],
        password=cred["password"],
        authSource="admin",
        directConnection=True,
        tls=True,
        tlsCAFile=CA_FILE,
        tlsAllowInvalidHostnames=True,  # el certificado es del clúster, no de 127.0.0.1
        retryWrites=False,
        serverSelectionTimeoutMS=10000,
    )
    cliente.admin.command("ping")
    return cliente


def mostrar(titulo, documentos):
    print(f"\n=== {titulo} ===")
    for doc in documentos:
        print(json.dumps(doc, ensure_ascii=False, default=str))


def main():
    cliente = conectar()
    print("Conexión exitosa a DocumentDB (contraseña obtenida de Secrets Manager).")

    productos = cliente["taller"]["productos"]
    productos.delete_many({})  # así el programa se puede repetir sin duplicar datos

    datos = [
        {"nombre": "Portátil 14 pulgadas", "categoria": "Electrónica", "precio": 2400, "stock": 8},
        {"nombre": "Audífonos inalámbricos", "categoria": "Electrónica", "precio": 180, "stock": 35},
        {"nombre": "Teclado mecánico", "categoria": "Electrónica", "precio": 220, "stock": 20},
        {"nombre": "Mouse ergonómico", "categoria": "Electrónica", "precio": 60, "stock": 50},
        {"nombre": "Silla de oficina", "categoria": "Muebles", "precio": 450, "stock": 12},
        {"nombre": "Escritorio ajustable", "categoria": "Muebles", "precio": 780, "stock": 6},
        {"nombre": "Lámpara de mesa", "categoria": "Muebles", "precio": 45, "stock": 40},
        {"nombre": "Cuaderno cuadriculado", "categoria": "Papelería", "precio": 4, "stock": 300},
        {"nombre": "Set de marcadores", "categoria": "Papelería", "precio": 9, "stock": 150},
        {"nombre": "Calculadora científica", "categoria": "Papelería", "precio": 28, "stock": 75},
    ]
    resultado = productos.insert_many(datos)
    print(f"Documentos insertados: {len(resultado.inserted_ids)}")

    # 1. Búsqueda con filtro: electrónica de más de 100
    mostrar(
        "Filtro: categoría Electrónica y precio > 100",
        productos.find({"categoria": "Electrónica", "precio": {"$gt": 100}}, {"_id": 0}),
    )

    # 2. Ordenación: los 5 productos más caros
    mostrar(
        "Ordenación: 5 productos más caros",
        productos.find({}, {"_id": 0, "nombre": 1, "precio": 1}).sort("precio", -1).limit(5),
    )

    # 3. Agregación: resumen por categoría
    pipeline = [
        {"$group": {
            "_id": "$categoria",
            "cantidad_productos": {"$sum": 1},
            "precio_promedio": {"$avg": "$precio"},
            "unidades_en_stock": {"$sum": "$stock"},
        }},
        {"$sort": {"precio_promedio": -1}},
    ]
    mostrar("Agregación: resumen por categoría", productos.aggregate(pipeline))

    cliente.close()


if __name__ == "__main__":
    main()

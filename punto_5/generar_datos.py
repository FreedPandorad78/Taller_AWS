import csv
import random
from datetime import date, timedelta

random.seed(42)

nombres = ["Ana Gómez", "Bruno Ríos", "Carla Mejía", "Diego Torres", "Elena Vargas",
           "Felipe Ortiz", "Gabriela Soto", "Héctor Pardo", "Isabel Cano", "Julián Rojas",
           "Karen Duque", "Luis Peña", "Marta Salazar", "Nicolás Ibarra", "Olga Restrepo",
           "Pablo Henao", "Quiteria Arias", "Rafael Mora", "Sofía Giraldo", "Tomás Zapata"]
ciudades = ["Medellín", "Bogotá", "Cali", "Barranquilla", "Bucaramanga"]
productos = {"Portátil": 2400, "Monitor": 900, "Escritorio": 780, "Silla": 450,
             "Teclado": 220, "Audífonos": 180, "Mouse": 60, "Lámpara": 45}

with open("datos/clientes.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["cliente_id", "nombre", "ciudad", "fecha_registro"])
    for i, nombre in enumerate(nombres, start=1):
        registro = date(2025, 1, 1) + timedelta(days=random.randint(0, 300))
        w.writerow([i, nombre, random.choice(ciudades), registro.isoformat()])

with open("datos/pedidos.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["pedido_id", "cliente_id", "fecha", "producto", "cantidad", "valor_unitario"])
    for i in range(1, 81):
        producto = random.choice(list(productos))
        fecha = date(2026, 1, 1) + timedelta(days=random.randint(0, 270))
        w.writerow([i, random.randint(1, 20), fecha.isoformat(), producto,
                    random.randint(1, 5), productos[producto]])

print("Archivos generados en datos/")

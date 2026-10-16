import csv
import random
from datetime import date, timedelta

random.seed(7)

ciudades = {"Medellín": "050001", "Bogotá": "110111", "Cali": "760001",
            "Barranquilla": "080001", "Bucaramanga": "680001"}
clientes = ["Ana Gómez", "Bruno Ríos", "Carla Mejía", "Diego Torres", "Elena Vargas",
            "Felipe Ortiz", "Gabriela Soto", "Héctor Pardo", "Isabel Cano", "Julián Rojas",
            "Karen Duque", "Luis Peña"]
estados = ["Entregado", "Entregado", "Entregado", "En camino", "Devuelto"]


def escribir(nombre, primer_id, cantidad, inicio, dias):
    with open(f"datos/{nombre}", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["envio_id", "cliente", "ciudad", "codigo_postal",
                    "fecha_envio", "peso_kg", "valor_envio", "estado"])
        for i in range(primer_id, primer_id + cantidad):
            ciudad = random.choice(list(ciudades))
            peso = round(random.uniform(0.5, 12), 1)
            valor = int(round((8000 + peso * 2500) / 100) * 100)
            fecha = inicio + timedelta(days=random.randint(0, dias))
            w.writerow([i, random.choice(clientes), ciudad, ciudades[ciudad],
                        fecha.isoformat(), peso, valor, random.choice(estados)])


escribir("envios_1.csv", 1, 24, date(2026, 3, 1), 45)
escribir("envios_2.csv", 25, 8, date(2026, 5, 1), 20)
print("Archivos generados en datos/")

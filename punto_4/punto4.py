import json
import os

import boto3

REGION = os.environ.get("REGION", "us-east-2")
ENDPOINT = os.environ["NEPTUNE_ENDPOINT"]  # viene de recursos_punto4.env

# Cliente firmado con SigV4 usando las credenciales de user_cli
cliente = boto3.client(
    "neptunedata",
    region_name=REGION,
    endpoint_url=f"https://{ENDPOINT}:8182",
)


def ejecutar(consulta, parametros=None):
    argumentos = {"openCypherQuery": consulta}
    if parametros:
        argumentos["parameters"] = json.dumps(parametros)
    return cliente.execute_open_cypher_query(**argumentos)["results"]


def mostrar(titulo, filas):
    print(f"\n=== {titulo} ===")
    for fila in filas:
        print(json.dumps(fila, ensure_ascii=False))


def cargar_grafo():
    ejecutar("MATCH (n) DETACH DELETE n")  # permite repetir el programa sin duplicar

    # Vértices (10)
    ejecutar("UNWIND $v AS n CREATE (:Persona {nombre: n})",
             {"v": ["Ana", "Bruno", "Carla", "Diego", "Elena", "Felipe"]})
    ejecutar("UNWIND $v AS n CREATE (:Empresa {nombre: n})",
             {"v": ["DataCorp", "NubeSoft"]})
    ejecutar("UNWIND $v AS n CREATE (:Ciudad {nombre: n})",
             {"v": ["Medellín", "Bogotá"]})

    # Relaciones (20)
    conoce = [("Ana", "Bruno"), ("Ana", "Carla"), ("Bruno", "Diego"),
              ("Carla", "Diego"), ("Diego", "Elena"), ("Elena", "Felipe")]
    trabaja = [("Ana", "DataCorp"), ("Bruno", "DataCorp"), ("Carla", "NubeSoft"),
               ("Diego", "NubeSoft"), ("Elena", "NubeSoft"), ("Felipe", "DataCorp")]
    vive = [("Ana", "Medellín"), ("Bruno", "Medellín"), ("Carla", "Bogotá"),
            ("Diego", "Bogotá"), ("Elena", "Medellín"), ("Felipe", "Bogotá")]
    sede = [("DataCorp", "Medellín"), ("NubeSoft", "Bogotá")]

    def relaciones(tipo, origen, destino, pares):
        ejecutar(
            f"UNWIND $p AS x "
            f"MATCH (a:{origen} {{nombre: x.de}}), (b:{destino} {{nombre: x.a}}) "
            f"CREATE (a)-[:{tipo}]->(b)",
            {"p": [{"de": d, "a": a} for d, a in pares]},
        )

    relaciones("CONOCE", "Persona", "Persona", conoce)
    relaciones("TRABAJA_EN", "Persona", "Empresa", trabaja)
    relaciones("VIVE_EN", "Persona", "Ciudad", vive)
    relaciones("SEDE_EN", "Empresa", "Ciudad", sede)


def main():
    print("Conectando a Neptune con autenticación IAM (user_cli)...")
    cargar_grafo()

    mostrar("Vértices cargados", ejecutar("MATCH (n) RETURN count(n) AS vertices"))
    mostrar("Relaciones cargadas", ejecutar("MATCH ()-[r]->() RETURN count(r) AS relaciones"))

    # Consulta 1: recorrido de 2 saltos (amigos de amigos de Ana)
    mostrar(
        "Consulta 1: personas que conoce Ana a través de otra persona (2 saltos)",
        ejecutar(
            "MATCH (a:Persona {nombre: 'Ana'})-[:CONOCE]->(:Persona)-[:CONOCE]->(c:Persona) "
            "RETURN DISTINCT c.nombre AS nombre"
        ),
    )

    # Consulta 2: persona -> empresa -> ciudad sede
    mostrar(
        "Consulta 2: empresa y ciudad sede de cada persona",
        ejecutar(
            "MATCH (p:Persona)-[:TRABAJA_EN]->(e:Empresa)-[:SEDE_EN]->(c:Ciudad) "
            "RETURN p.nombre AS persona, e.nombre AS empresa, c.nombre AS sede "
            "ORDER BY persona"
        ),
    )

    # Consulta 3: compañeros de la misma empresa que además se conocen
    mostrar(
        "Consulta 3: compañeros de empresa que se conocen",
        ejecutar(
            "MATCH (p:Persona)-[:CONOCE]->(q:Persona), "
            "(p)-[:TRABAJA_EN]->(e:Empresa)<-[:TRABAJA_EN]-(q) "
            "RETURN p.nombre AS persona, q.nombre AS conoce_a, e.nombre AS empresa "
            "ORDER BY persona"
        ),
    )


if __name__ == "__main__":
    main()

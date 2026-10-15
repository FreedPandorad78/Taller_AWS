import boto3
import json

def obtener_secreto():
    nombre_secreto = "mi_secreto_prueba"
    region = "us-east-2" 

    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager', region_name=region)

    try:
        respuesta = client.get_secret_value(SecretId=nombre_secreto)
        credenciales = json.loads(respuesta['SecretString'])
        print("--- Valores recuperados de AWS ---")
        print(f"Usuario: {credenciales.get('usuario')}")
        print(f"Contraseña: {credenciales.get('password')}")
        print("----------------------------------")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    obtener_secreto()
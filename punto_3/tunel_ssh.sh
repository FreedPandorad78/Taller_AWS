#!/usr/bin/env bash
# Abre el túnel: localhost:27018 -> EC2 -> DocumentDB:27017. Dejar esta terminal abierta.
cd "$(dirname "$0")"
source recursos_punto3.env
ssh -i ~/.ssh/taller-docdb-key.pem -o StrictHostKeyChecking=accept-new -N \
  -L 27018:$DOCDB_ENDPOINT:27017 ec2-user@$EC2_DNS

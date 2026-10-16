#!/usr/bin/env bash
export AWS_PAGER=""
R=us-east-2
sec() { echo; echo "== $1 =="; }

sec "EC2: instancias que no están terminadas"
aws ec2 describe-instances --region $R --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" --query "Reservations[].Instances[].[InstanceId,InstanceType,State.Name]" --output text
sec "EBS: volúmenes"
aws ec2 describe-volumes --region $R --query "Volumes[].[VolumeId,Size,State]" --output text
sec "EBS: snapshots propios"
aws ec2 describe-snapshots --region $R --owner-ids self --query "Snapshots[].[SnapshotId,VolumeSize]" --output text
sec "IP elásticas"
aws ec2 describe-addresses --region $R --query "Addresses[].[PublicIp,AllocationId]" --output text
sec "NAT gateways activas"
aws ec2 describe-nat-gateways --region $R --filter Name=state,Values=available,pending --query "NatGateways[].NatGatewayId" --output text
sec "Grupos de seguridad del taller"
aws ec2 describe-security-groups --region $R --query "SecurityGroups[?starts_with(GroupName,'taller')].[GroupName,GroupId]" --output text
sec "Pares de claves"
aws ec2 describe-key-pairs --region $R --query "KeyPairs[].KeyName" --output text
sec "RDS: instancias"
aws rds describe-db-instances --region $R --query "DBInstances[].[DBInstanceIdentifier,Engine,DBInstanceStatus]" --output text
sec "DocumentDB: clústeres"
aws docdb describe-db-clusters --region $R --query "DBClusters[].DBClusterIdentifier" --output text
sec "Neptune: clústeres"
aws neptune describe-db-clusters --region $R --query "DBClusters[].DBClusterIdentifier" --output text
sec "Snapshots manuales de bases de datos"
aws rds describe-db-snapshots --region $R --snapshot-type manual --query "DBSnapshots[].DBSnapshotIdentifier" --output text
aws rds describe-db-cluster-snapshots --region $R --snapshot-type manual --query "DBClusterSnapshots[].DBClusterSnapshotIdentifier" --output text
sec "Copias automáticas retenidas de RDS"
aws rds describe-db-instance-automated-backups --region $R --query "DBInstanceAutomatedBackups[].[DBInstanceIdentifier,Status]" --output text
sec "Redshift: clústeres, namespaces y workgroups"
aws redshift describe-clusters --region $R --query "Clusters[].ClusterIdentifier" --output text
aws redshift-serverless list-namespaces --region $R --query "namespaces[].namespaceName" --output text
aws redshift-serverless list-workgroups --region $R --query "workgroups[].workgroupName" --output text
sec "Secretos (incluye los programados para eliminación)"
aws secretsmanager list-secrets --region $R --include-planned-deletion --query "SecretList[].[Name,DeletedDate]" --output text
sec "Buckets de S3"
aws s3 ls
sec "Glue: bases de datos y crawlers"
aws glue get-databases --region $R --query "DatabaseList[].Name" --output text
aws glue get-crawlers --region $R --query "Crawlers[].Name" --output text
sec "Roles de IAM del taller (puede dar AccessDenied)"
aws iam list-roles --query "Roles[?starts_with(RoleName,'taller')].RoleName" --output text
echo; echo "(fin de la revisión)"

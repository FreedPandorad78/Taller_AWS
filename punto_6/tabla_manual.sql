-- SCRIPT-004
CREATE EXTERNAL TABLE IF NOT EXISTS envios_manual (
  envio_id      BIGINT,
  cliente       STRING,
  ciudad        STRING,
  codigo_postal STRING,
  fecha_envio   DATE,
  peso_kg       DOUBLE,
  valor_envio   BIGINT,
  estado        STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3://__BUCKET__/envios/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- SCRIPT-005
SELECT 'envios (crawler)' AS tabla, COUNT(*) AS filas, SUM(valor_envio) AS valor_total FROM envios
UNION ALL
SELECT 'envios_manual', COUNT(*), SUM(valor_envio) FROM envios_manual;

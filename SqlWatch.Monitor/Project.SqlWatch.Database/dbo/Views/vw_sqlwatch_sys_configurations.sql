CREATE VIEW [dbo].[vw_sqlwatch_sys_configurations]
as

SELECT sql_instance = @@SERVERNAME
     , configuration_id
     , name
     , CAST(value AS INT) as [value]
     , CAST(value_in_use AS INT) as [value_in_use]
     , description
  FROM sys.configurations
UNION ALL
SELECT @@SERVERNAME
    , -1
    , 'version'
    , (SELECT CAST(REPLACE(CAST(SERVERPROPERTY('productversion') AS VARCHAR(64)), '.', '') AS INT))
    , (SELECT CAST(REPLACE(CAST(SERVERPROPERTY('productversion') AS VARCHAR(64)), '.', '') AS INT))
    , 'Version as integer: xx.x.xxxx.xx'
--UNION ALL
--SELECT sql_instance = @@SERVERNAME
--     , -2
--     , 'instant file initialization'
--     , CASE WHEN s.instant_file_initialization_enabled = 'Y' THEN 1 ELSE 0 END AS instant_file_initialization_enabled
--     , CASE WHEN s.instant_file_initialization_enabled = 'Y' THEN 1 ELSE 0 END AS instant_file_initialization_enabled 
--     , 'indicates if instant file initialization (perform volume maintenance tasks) is enabled for the SQL Server service account.'
--  FROM sys.dm_server_services s
-- WHERE servicename NOT LIKE 'SQL Server Agent%' AND servicename NOT LIKE 'SQL Server Launchpad%'
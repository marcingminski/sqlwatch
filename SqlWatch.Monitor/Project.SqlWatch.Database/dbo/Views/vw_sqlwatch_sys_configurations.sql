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
    , 'Version as integer: xx.x.xxxx.xx';
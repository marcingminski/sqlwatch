CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_system_configuration]
AS

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	[usp_sqlwatch_logger_system_configuration]

 Description:
	Log system configuration into tables.

 Parameters
	N/A
	
 Author:
	Fabian Schenker

 Change Log:
	1.0		2020-05-13	- Fabian Schenker, Initial version
-------------------------------------------------------------------------------------------------------------------
*/

set nocount on ;
set xact_abort on;

declare @snapshot_time datetime2(0),
		@snapshot_type_id tinyint = 26,
		@date_snapshot_previous datetime2(0)

select @date_snapshot_previous = max([snapshot_time])
	from [dbo].[sqlwatch_logger_snapshot_header] (nolock) --so we dont get blocked by central repository. this is safe at this point.
	where snapshot_type_id = @snapshot_type_id
	and sql_instance = @@SERVERNAME

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id


INSERT INTO [dbo].[sqlwatch_logger_system_configuration] (sql_instance, sqlwatch_configuration_id, value, value_in_use, snapshot_time, snapshot_Type_id)
SELECT v.sql_instance, m.sqlwatch_configuration_id, v.value, v.value_in_use, @snapshot_time, @snapshot_type_id
  FROM dbo.vw_sqlwatch_sys_configurations v
 INNER JOIN dbo.[sqlwatch_meta_system_configuration] m
    ON v.configuration_id = m.configuration_id
   AND v.sql_instance = m.sql_instance


-- Slowly Changing Dimension for System Configuration

-- Set valid_until for changed or deleted:
UPDATE curr
   SET curr.valid_until = @snapshot_time
  FROM [dbo].[sqlwatch_logger_system_configuration_scd] curr
  LEFT JOIN (SELECT v.sql_instance, m.sqlwatch_configuration_id, v.value, v.value_in_use
               FROM dbo.vw_sqlwatch_sys_configurations v
              INNER JOIN dbo.[sqlwatch_meta_system_configuration] m
                 ON v.configuration_id = m.configuration_id
                AND v.sql_instance = m.sql_instance) n
   ON curr.sql_instance = n.sql_instance
  AND curr.sqlwatch_configuration_id = n.sqlwatch_configuration_id
 WHERE n.sql_instance IS NULL OR curr.value <> n.value OR curr.value_in_use <> n.value_in_use

-- Add the new ones or the changed:
INSERT INTO [dbo].[sqlwatch_logger_system_configuration_scd] (sql_instance, sqlwatch_configuration_id, value, value_in_use, valid_from, valid_until)
SELECT v.sql_instance, m.sqlwatch_configuration_id, v.value, v.value_in_use, @snapshot_time, NULL
  FROM dbo.vw_sqlwatch_sys_configurations v
 INNER JOIN dbo.[sqlwatch_meta_system_configuration] m
    ON v.configuration_id = m.configuration_id
   AND v.sql_instance = m.sql_instance
 LEFT JOIN [dbo].[sqlwatch_logger_system_configuration_scd] curr
   ON curr.sql_instance = v.sql_instance
  AND curr.sqlwatch_configuration_id = m.sqlwatch_configuration_id
WHERE curr.sql_instance IS NULL OR curr.value <> v.value OR curr.value_in_use <> v.value_in_use


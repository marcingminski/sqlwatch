CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_system_configuration]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32),
	@snapshot_time_previous datetime2(0)
as
begin
	set nocount on ;

	exec [dbo].[usp_sqlwatch_internal_meta_add_system_configuration]
		@xdoc = @xdoc,
		@sql_instance = @sql_instance;

	select 
		[configuration_id]
		, [name]
		, [value]
		, [value_in_use]
		, [description]
		, sql_instance = @sql_instance
	into #t
	from openxml (@xdoc, '/CollectionSnapshot/sys_configurations/row',1) 
		with (
			[configuration_id] int
			, [name] nvarchar(35)
			, [value] int
			, [value_in_use] int
			, [description] nvarchar(255)
		);

	INSERT INTO [dbo].[sqlwatch_logger_system_configuration] (sql_instance, sqlwatch_configuration_id, value, value_in_use, snapshot_time, snapshot_type_id)
	SELECT v.sql_instance, m.sqlwatch_configuration_id, v.value, v.value_in_use, @snapshot_time, @snapshot_type_id
	from #t v
	 INNER JOIN dbo.[sqlwatch_meta_system_configuration] m
		ON v.configuration_id = m.configuration_id
	   AND v.sql_instance = m.sql_instance;


	-- Slowly Changing Dimension for System Configuration
	-- Set valid_until for changed or deleted:
	UPDATE curr
	   SET curr.valid_until = @snapshot_time
	  FROM [dbo].[sqlwatch_meta_system_configuration_scd] curr
	  LEFT JOIN (
		SELECT v.sql_instance, m.sqlwatch_configuration_id, v.value, v.value_in_use
		FROM #t v
		INNER JOIN dbo.[sqlwatch_meta_system_configuration] m
			ON v.configuration_id = m.configuration_id
			AND v.sql_instance = m.sql_instance
			) n
	   ON curr.sql_instance = n.sql_instance
	  AND curr.sqlwatch_configuration_id = n.sqlwatch_configuration_id
	 WHERE n.sql_instance IS NULL OR curr.value <> n.value OR curr.value_in_use <> n.value_in_use;

	-- Add the new ones or the changed:
	INSERT INTO [dbo].[sqlwatch_meta_system_configuration_scd] (sql_instance, sqlwatch_configuration_id, value, value_in_use, valid_from, valid_until)
	SELECT DISTINCT v.sql_instance, m.sqlwatch_configuration_id, v.value, v.value_in_use, @snapshot_time, NULL
	  FROM #t v
	 INNER JOIN dbo.[sqlwatch_meta_system_configuration] m
		ON v.configuration_id = m.configuration_id
	   AND v.sql_instance = m.sql_instance
	 LEFT JOIN [dbo].[sqlwatch_meta_system_configuration_scd] curr
	   ON curr.sql_instance = v.sql_instance
	  AND curr.sqlwatch_configuration_id = m.sqlwatch_configuration_id
	WHERE curr.sql_instance IS NULL OR curr.value <> v.value OR curr.value_in_use <> v.value_in_use;
end;
CREATE TYPE [dbo].[utype_event_data] AS TABLE
(
	event_data xml,
	object_name nvarchar(256),
	event_time datetime2(0),
	sql_instance varchar(32),
	snapshot_time datetime2(0)
);

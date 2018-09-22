CREATE TABLE [dbo].[logger_missing_indexes](
	[snapshot_time] [datetime] NOT NULL,
	[database_name] [nvarchar](128) NOT NULL,
	[statement] [nvarchar](512) NULL,
	[benefit] [numeric](38, 6) NULL,
	[equality_columns] [nvarchar](4000) NULL,
	[inequality_columns] [nvarchar](4000) NULL,
	[included_columns] [nvarchar](4000) NULL,
	[usage] [bigint] NULL,
	[impact] [nvarchar](31) NULL,
	[average_query_cost] [numeric](29, 4) NULL,
	[last_user_seek] [datetime] NULL,
	[last_user_scan] [datetime] NULL,
	[unique_compiles] [bigint] NULL,
	[create_tsql] [nvarchar](max) NULL,
	[snapshot_type_id] TINYINT NULL DEFAULT 1
)


GO

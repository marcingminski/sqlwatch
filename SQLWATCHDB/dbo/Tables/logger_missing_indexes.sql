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
PRIMARY KEY CLUSTERED 
(
	[snapshot_time] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

ALTER TABLE [dbo].[logger_missing_indexes]  WITH CHECK ADD  CONSTRAINT [fk_sql_perf_mon_missing_indexes] FOREIGN KEY([snapshot_time])
REFERENCES [dbo].[sql_perf_mon_snapshot_header] ([snapshot_time])
ON DELETE CASCADE
GO

ALTER TABLE [dbo].[logger_missing_indexes] CHECK CONSTRAINT [fk_sql_perf_mon_missing_indexes]
GO
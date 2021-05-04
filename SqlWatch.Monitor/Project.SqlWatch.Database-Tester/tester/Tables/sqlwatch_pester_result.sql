CREATE TABLE [tester].[sqlwatch_pester_result]
(
	[result_datetime_utc] datetime not null constraint df_sqlawatch_pester_result_datetime_utc default getutcdate(),
	[result_datetime] datetime not null constraint df_sqlawatch_pester_result_datetime_local default getdate(),
	[Server] [nvarchar](max) NULL,
	[User] [nvarchar](max) NULL,
	[DateTime] datetime NULL,
	[Context] [nvarchar](max) NULL,
	[TestName] [nvarchar](max) NULL,
	[TestResult] nvarchar(50) NULL,
	[TestTime] decimal(20,5) NULL
);

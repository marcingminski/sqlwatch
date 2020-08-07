CREATE TABLE [dbo].[dbachecksResults] (
	[Date] [datetime2](7) NOT NULL,
	[Label] [nvarchar](255) NULL,
	[Describe] [nvarchar](255) NULL,
	[Context] [nvarchar](255) NULL,
	[Name] [nvarchar](600) NULL,
	[Database] [nvarchar](255) NULL,
	[ComputerName] [nvarchar](255) NULL,
	[Instance] [nvarchar](255) NULL,
	[Result] [nvarchar](10) NULL,
	[FailureMessage] [nvarchar](max) NULL
)
GO

CREATE NONCLUSTERED INDEX idx_sqlwatch_dbachecks_failure_by_date ON [dbo].[dbachecksResults] ([Result],[Date])
	WHERE [Result] = 'Failed'
GO
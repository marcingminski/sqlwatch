CREATE TABLE [dbo].[sqlwatch_app_version]
(
	[install_sequence] smallint identity(1,1) not null,
	[install_date] datetimeoffset not null,
	[sqlwatch_version] varchar(255) not null,
	constraint pk_sqlwatch_version primary key clustered (
		[install_sequence]
	)
)

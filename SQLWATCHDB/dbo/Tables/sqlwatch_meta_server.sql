CREATE TABLE [dbo].[sqlwatch_meta_server]
(
	[physical_name] nvarchar(128),
	[servername] nvarchar(25),
	[service_name] nvarchar(128),
	[local_net_address] varchar(50),
	[local_tcp_port] varchar(50),
	[utc_offset_minutes] int default DATEDIFF(mi, GETUTCDATE(), GETDATE()) not null,
	constraint pk_sqlwatch_meta_server primary key clustered (
		[servername]
		)
)

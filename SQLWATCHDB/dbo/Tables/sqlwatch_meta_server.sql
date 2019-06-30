CREATE TABLE [dbo].[sqlwatch_meta_server]
(
	[physical_name] sysname,
	[servername] sysname,
	[service_name] sysname,
	[local_net_address] varchar(50),
	[local_tcp_port] varchar(50),
	[utc_offset_minutes] int default DATEDIFF(mi, GETUTCDATE(), GETDATE()) not null,
	constraint pk_sqlwatch_meta_server primary key clustered (
		servername
		)
)

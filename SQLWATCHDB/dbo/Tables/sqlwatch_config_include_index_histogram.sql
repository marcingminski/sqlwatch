CREATE TABLE [dbo].[sqlwatch_config_include_index_histogram]
(
	[object_name_pattern] nvarchar(128) not null,
	[index_name_pattern] nvarchar(128) not null,
	constraint pk_sqlwatch_config_include_index_histogram primary key clustered (
		[object_name_pattern], [index_name_pattern]
	)
)

CREATE TABLE [dbo].[sqlwatch_config_include_errorlog_keywords]
(
	keyword_id int identity(1,1) not null,
	keyword1 nvarchar(255) not null,
	keyword2 nvarchar(255) null,
	log_type_id int not null,
	constraint pk_sqlwatch_config_include_errorlog_keywords primary key clustered (
		keyword_id, log_type_id
		)
);
go

create unique nonclustered index idx_sqlwatch_config_include_errorlog_keywords_keyword1
on [dbo].[sqlwatch_config_include_errorlog_keywords]  (keyword1)
where keyword2  is null;
go

create unique nonclustered index idx_sqlwatch_config_include_errorlog_keywords_keyword2
on [dbo].[sqlwatch_config_include_errorlog_keywords]  (keyword1, keyword2)
where keyword2  is not null;
go
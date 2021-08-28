CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_errorlog]
AS

set nocount on ;
set xact_abort on;

CREATE TABLE #sqlwatch_logger_errorlog (
	log_date datetime,
	attribute_value varchar(max),
	text nvarchar(max),
	keyword_id smallint,
	log_type_id int
);

declare @keyword_id smallint, 
		@keyword1 nvarchar(255), 
		@keyword2 nvarchar(255), 
		@log_type_id int,
		@prev_log_date datetime,
		@snapshot_type_id tinyint = 25,
		@snapshot_time datetime2(0);

merge dbo.sqlwatch_meta_errorlog_keyword as target
using dbo.sqlwatch_config_include_errorlog_keywords as source
on	target.keyword_id = source.keyword_id
and target.log_type_id = source.log_type_id
and target.sql_instance = @@SERVERNAME

when not matched then
	insert (keyword_id , sql_instance, keyword1, keyword2, log_type_id)
	values (source.keyword_id, @@SERVERNAME, source.keyword1, source.keyword2, source.log_type_id);

declare c_parse_errorlog cursor for
select m.keyword_id, m.keyword1, m.keyword2, m.log_type_id 
from dbo.sqlwatch_meta_errorlog_keyword m
where m.sql_instance = @@SERVERNAME;

open c_parse_errorlog

fetch next from c_parse_errorlog into @keyword_id, @keyword1, @keyword2, @log_type_id;

while @@FETCH_STATUS = 0
	begin
		select @prev_log_date = dateadd(ms,3,log_date)
		from dbo.sqlwatch_logger_errorlog l
		where log_type_id = @log_type_id
		and keyword_id = @keyword_id
		and sql_instance = @@SERVERNAME;

		set @prev_log_date = isnull(dateadd(ms,3,@prev_log_date),'1970-01-01');

		insert into #sqlwatch_logger_errorlog (log_date,attribute_value,text)
		exec xp_readerrorlog 0, @log_type_id, @keyword1, @keyword2 ,@prev_log_date;

		update #sqlwatch_logger_errorlog
			set text = replace(replace(rtrim(ltrim(text)),char(13),''),char(10),'')
			, keyword_id = @keyword_id
			, log_type_id = @log_type_id
		where keyword_id is null and log_type_id is null;

	fetch next from c_parse_errorlog into @keyword_id, @keyword1, @keyword2, @log_type_id;
	end

close c_parse_errorlog;
deallocate c_parse_errorlog;

merge dbo.sqlwatch_meta_errorlog_attribute as target
using (
	select distinct sql_instance = @@SERVERNAME, attribute_name = case s.log_type_id
			when 1 then 'ProcessInfo'
			when 2 then 'ErrorLevel'
			else '' end
			, s.attribute_value
	from #sqlwatch_logger_errorlog s
	) as source

on target.sql_instance = source.sql_instance collate database_default
and target.attribute_name = source.attribute_name collate database_default
and target.attribute_value = source.attribute_value collate database_default
		
when not matched then
	insert (sql_instance, attribute_name, attribute_value)
	values (source.sql_instance, source.attribute_name, source.attribute_value)
;

insert into dbo.sqlwatch_meta_errorlog_text (errorlog_text)
select distinct text
from #sqlwatch_logger_errorlog s
left join dbo.sqlwatch_meta_errorlog_text t
	on t.errorlog_text = s.text collate database_default
where t.errorlog_text_id is null;

update t
	set total_occurence_count = isnull(t.total_occurence_count,0) + isnull(c.total_occurence_count,0)
	, last_occurence = case when c.last_occurence is not null then c.last_occurence else t.last_occurence end
	, first_occurence = case when c.first_occurence is not null then c.first_occurence else t.first_occurence end
from dbo.sqlwatch_meta_errorlog_text t
left join (
	select text, total_occurence_count=count(*), first_occurence=min(log_date), last_occurence=max(log_date)
	from #sqlwatch_logger_errorlog
	group by text
) c
on c.text = t.errorlog_text collate database_default
and sql_instance = @@SERVERNAME;

exec [dbo].[usp_sqlwatch_internal_logger_new_header] 
	@snapshot_time_new = @snapshot_time OUTPUT,
	@snapshot_type_id = @snapshot_type_id;

insert into dbo.sqlwatch_logger_errorlog (log_date, attribute_id, errorlog_text_id, keyword_id, log_type_id, snapshot_time, snapshot_type_id, record_count)
select log_date, attribute_id , t.errorlog_text_id, s.keyword_id, s.log_type_id, @snapshot_time, @snapshot_type_id, record_count=count(*)
from #sqlwatch_logger_errorlog s
left join dbo.sqlwatch_meta_errorlog_attribute a
on s.attribute_value = a.attribute_value collate database_default
and a.attribute_name = case s.log_type_id
		when 1 then 'ProcessInfo'
		when 2 then 'ErrorLevel'
		else null end 
left join dbo.sqlwatch_meta_errorlog_text t
	on t.errorlog_text = s.text collate database_default
group by log_date, attribute_id , t.errorlog_text_id, s.keyword_id, s.log_type_id;
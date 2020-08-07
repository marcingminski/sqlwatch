CREATE VIEW [dbo].[vw_sqlwatch_logger_errorlog] WITH SCHEMABINDING
AS
SELECT le.[sql_instance]
      ,le.[log_date]
      ,log_type = case le.[log_type_id]
		when 1 then 'SQL Server'
		when 2 then 'SQL Agent'
		else 'Other'
		end
	  , ea.attribute_name
	  , ea.attribute_value
	  , et.errorlog_text
      , ek.keyword
  FROM [dbo].[sqlwatch_logger_errorlog] le
  inner join [dbo].[sqlwatch_meta_errorlog_attribute] ea
	on ea.[sql_instance] = le.sql_instance
	and ea.[attribute_id] = le.[attribute_id]
  inner join [dbo].[sqlwatch_meta_errorlog_text] et
	on et.sql_instance = le.sql_instance
	and et.[errorlog_text_id] = le.[errorlog_text_id]
  inner join dbo.sqlwatch_meta_errorlog_keyword ek
	on ek.sql_instance = le.sql_instance
	and ek.keyword_id = le.keyword_id
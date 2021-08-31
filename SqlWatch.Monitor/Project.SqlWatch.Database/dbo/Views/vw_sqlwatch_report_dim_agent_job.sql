﻿CREATE VIEW [dbo].[vw_sqlwatch_report_dim_agent_job] with schemabinding
	AS 
	select [sql_instance], [job_name], [job_create_date], [sqlwatch_job_id], [date_last_seen] , [is_record_deleted]
	from dbo.sqlwatch_meta_agent_job
	where [is_record_deleted] = 0 or [is_record_deleted] is null;

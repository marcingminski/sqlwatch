﻿create nonclustered index idx_sqlwatch_logger_agent_job_history_run_date_utc
	on dbo.sqlwatch_logger_agent_job_history (run_date_utc)
	with (data_compression=page)
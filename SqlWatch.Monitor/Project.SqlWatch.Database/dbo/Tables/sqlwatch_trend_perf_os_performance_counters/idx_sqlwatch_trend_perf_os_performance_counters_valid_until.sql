﻿CREATE NONCLUSTERED INDEX idx_sqlwatch_trend_perf_os_performance_counters_valid_until
	ON dbo.sqlwatch_trend_perf_os_performance_counters ([valid_until])
	WITH (DATA_COMPRESSION=PAGE)
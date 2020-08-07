CREATE VIEW [dbo].[vw_sqlwatch_report_dim_time] with schemabinding
as

select 
	  [sql_instance]
	, [snapshot_type_id]
	, [snapshot_time]
	, [report_time] 
	, [date] = convert(date,report_time)
	, [year] = datepart(year,report_time)
	, [month] = datepart(month, report_time)
	, [day] = datepart(day, report_time)
	, [hour] = datepart(hour, report_time)
	, [minute] = datepart(minute, report_time)
	, [time] = convert(time,report_time)
	, [month_name] = datename(month, report_time)
	, [week_number] = datename (wk, report_time)
	, [week_day] = datename (weekday, report_time)
	, [day_of_year] = datename (dayofyear, report_time)
	, [year_month] = convert(char(4),datepart(year,report_time)) + '-' + right('00' + convert(char(2),datepart(month, report_time)),2)
	, [day_of_week] = datepart(dw, report_time)
	, [year_week] = convert(char(4),datepart(year,report_time)) + '-' + right('WK' + convert(char(2),datename (wk, report_time)),4)

	/*	calculate time intervals for dynamic grouping in PBI
		based on the time interval parameter we can aggregate over 5, 15 or 16 minutes to reduce data pulled into PBI
		or we can show at 1 minute intervals - highest granularity */
	, interval_minutes_5 = convert(smalldatetime,dateadd(minute,(datediff(minute,0, report_time)/ 5) * 5,0))
	, interval_minutes_15 = convert(smalldatetime,dateadd(minute,(datediff(minute,0, report_time)/ 15) * 15,0))
	, interval_minutes_60 = convert(smalldatetime,dateadd(minute,(datediff(minute,0, report_time)/ 60) * 60,0))

	/*	calcuate dates for baselines so we can join "snapshot_time" on one of the below columns to get historical
		values for the same "current" period */
	, baseline_1_report_time = dateadd(DAY,-1,report_time)
	, baseline_2_report_time = dateadd(WEEK,-1,report_time)
	, baseline_3_report_time = dateadd(MONTH,-1,report_time)

	, baseline_1_snapshot_time = dateadd(DAY,-1,snapshot_time)
	, baseline_2_snapshot_time = dateadd(WEEK,-1,snapshot_time)
	, baseline_3_snapshot_time = dateadd(MONTH,-1,snapshot_time)
	--, report_time_utc = dateadd(minute,([snapshot_time_utc_offset]*-1),report_time)
from dbo.sqlwatch_logger_snapshot_header
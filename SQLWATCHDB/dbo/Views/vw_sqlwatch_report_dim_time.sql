CREATE VIEW [dbo].[vw_sqlwatch_report_dim_time] with schemabinding
as

with cte_snapshots as (
	select distinct report_time --, current_utc_report_time = dateadd(minute,1,convert(datetime,convert(varchar(16),[snapshot_time],121))) --same calc as in snapshot_header
	from dbo.sqlwatch_logger_snapshot_header
)
select distinct report_time
	, date = convert(date,report_time)
	, year = datepart(year,report_time)
	, month = datepart(month, report_time)
	, day = datepart(day, report_time)
	, hour = datepart(hour, report_time)
	, minute = datepart(minute, report_time)
	, time = convert(time,report_time)
	, month_name = datename(month, report_time)
	, week_number = datename (wk, report_time)
	, week_day = datename (weekday, report_time)
	, day_of_year = datename (dayofyear, report_time)
	, year_month = convert(char(4),datepart(year,report_time)) + '-' + right('00' + convert(char(2),datepart(month, report_time)),2)
	, day_of_week = datepart(dw, report_time)
	, year_week = convert(char(4),datepart(year,report_time)) + '-' + right('WK' + convert(char(2),datename (wk, report_time)),4)
	, relative_date_label = case 
			--when snapshot_time > dateadd(hour,-1,current_utc_date) then 'Last 1 hour'
			--when snapshot_time > dateadd(hour,-4,current_utc_date) then 'Last 4 hours'
			--when snapshot_time > dateadd(hour,-12,current_utc_date) then 'Last 12 hours'
			--when snapshot_time > dateadd(hour,-24,current_utc_date) then 'Last 24 hours'
			when convert(date,report_time) = convert(date,getutcdate()) then 'Today'
			when convert(date,report_time) = dateadd(day,-1,convert(date,getutcdate())) then 'Yesterday'
			when convert(date,report_time) = dateadd(week,-1,convert(date,getutcdate())) then 'Same Day Last Week'
			when convert(date,report_time) = dateadd(month,-1,convert(date,getutcdate())) then 'Same Day Last Month'
			--when convert(date,snapshot_time) between dateadd(day,-7,convert(date,current_utc_date)) and convert(date,current_utc_date) then 'Last 7 days'
			--when convert(date,snapshot_time) between dateadd(day,-30,convert(date,current_utc_date)) and convert(date,current_utc_date) then 'Last 30 days' 
			--when datepart(year,snapshot_time) = datepart(year,current_utc_date) and datename (wk, snapshot_time) = datename (wk, current_utc_date) - 1 then 'Previous Week'
			--when datepart(year,snapshot_time) = datepart(year,current_utc_date) and datepart(month, snapshot_time) = datepart(month, current_utc_date) - 1 then 'Previous Month'
			else '' end
	, interval_minutes_5 = convert(smalldatetime,dateadd(minute,(datediff(minute,0, report_time)/ 5) * 5,0))
	, interval_minutes_15 = convert(smalldatetime,dateadd(minute,(datediff(minute,0, report_time)/ 15) * 15,0))
	, interval_minutes_60 = convert(smalldatetime,dateadd(minute,(datediff(minute,0, report_time)/ 60) * 60,0))
	, baseline_1_report_time = dateadd(DAY,-1,report_time)
	, baseline_2_report_time = dateadd(WEEK,-1,report_time)
	, baseline_3_report_time = dateadd(MONTH,-1,report_time)
from cte_snapshots
CREATE VIEW [dbo].[vw_sqlwatch_report_dim_time] with schemabinding
as

with cte_snapshots as (
	select distinct snapshot_time=convert(smalldatetime,snapshot_time), current_utc_date = convert(smalldatetime,getutcdate())
	from dbo.sqlwatch_logger_snapshot_header
)
select distinct snapshot_time=snapshot_time
	, date = convert(date,snapshot_time)
	, year = datepart(year,snapshot_time)
	, month = datepart(month, snapshot_time)
	, day = datepart(day, snapshot_time)
	, hour = datepart(hour, snapshot_time)
	, minute = datepart(minute, snapshot_time)
	, time = convert(time,snapshot_time)
	, month_name = datename(month, snapshot_time)
	, week_number = datename (wk, snapshot_time)
	, week_day = datename (weekday, snapshot_time)
	, day_of_year = datename (dayofyear, snapshot_time)
	, year_month = convert(char(4),datepart(year,snapshot_time)) + '-' + right('00' + convert(char(2),datepart(month, snapshot_time)),2)
	, day_of_week = datepart(dw, snapshot_time)
	, year_week = convert(char(4),datepart(year,snapshot_time)) + '-' + right('WK' + convert(char(2),datename (wk, snapshot_time)),4)
	, relative_date_label = case 
			--when snapshot_time > dateadd(hour,-1,current_utc_date) then 'Last 1 hour'
			when snapshot_time > dateadd(hour,-4,current_utc_date) then 'Last 4 hours'
			--when snapshot_time > dateadd(hour,-12,current_utc_date) then 'Last 12 hours'
			--when snapshot_time > dateadd(hour,-24,current_utc_date) then 'Last 24 hours'
			when convert(date,snapshot_time) = convert(date,current_utc_date) then 'Today'
			when convert(date,snapshot_time) = dateadd(day,-1,convert(date,current_utc_date)) then 'Yesterday'
			when convert(date,snapshot_time) = dateadd(week,-1,convert(date,current_utc_date)) then 'Same Day Last Week'
			when convert(date,snapshot_time) = dateadd(month,-1,convert(date,current_utc_date)) then 'Same Day Last Month'
			when convert(date,snapshot_time) between dateadd(day,-7,convert(date,current_utc_date)) and convert(date,current_utc_date) then 'Last 7 days'
			when convert(date,snapshot_time) between dateadd(day,-30,convert(date,current_utc_date)) and convert(date,current_utc_date) then 'Last 30 days' 
			when datepart(year,snapshot_time) = datepart(year,current_utc_date) and datename (wk, snapshot_time) = datename (wk, current_utc_date) - 1 then 'Previous Week'
			when datepart(year,snapshot_time) = datepart(year,current_utc_date) and datepart(month, snapshot_time) = datepart(month, current_utc_date) - 1 then 'Previous Month'
			else 'Other' end

from cte_snapshots
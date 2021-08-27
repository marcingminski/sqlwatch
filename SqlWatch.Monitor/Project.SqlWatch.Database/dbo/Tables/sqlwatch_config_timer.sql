CREATE TABLE [dbo].[sqlwatch_config_timer]
(
	timer_id uniqueidentifier not null,
	timer_type char(1) not null,
	timer_desc nvarchar(4000) not null,
	timer_seconds int not null,
	timer_active_days varchar(27) null,
	timer_active_hours_utc varchar(5) null,
	timer_active_from_date_utc datetime2(0) null,
	timer_active_to_date_utc datetime2(0) null,
	timer_enabled bit,

	constraint pk_sqlwatch_config_timer
		primary key clustered (timer_id),

	constraint chk_sqlwatch_config_timer_type
		check (
				-- C = Collector -- Performance collection either via SqlWatchCollect.exe or via local Broker
				-- I = Internal -- Local processing that should always run regardless how we collect data (ex, retention, checks, etc)
				timer_type = 'C'
			or	timer_type = 'I'
			),

	constraint chk_sqlwatch_config_timer_seconds
		check (
				--limit the interval to min 5 seconds
				timer_seconds >= 5
			),

	constraint chk_sqlwatch_config_timer_hours
		check (
				--active hours must be in the format of 00-00
				--active between 8am and 8pm: 08-20
				timer_active_hours_utc like '[0-2][0-9]-[0-2][0-9]'
			or	timer_active_hours_utc = null
			),

	constraint chk_sqlwatch_config_timer_days
		check (
				--"ddd" format https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings#dddSpecifier
				timer_active_days like '%Mon%'
			or	timer_active_days like '%Tue%'
			or	timer_active_days like '%Wed%'
			or	timer_active_days like '%Thu%'
			or	timer_active_days like '%Fri%'
			or	timer_active_days like '%Sat%'
			or	timer_active_days like '%Sun%'
			or	timer_active_days = null
		)
);

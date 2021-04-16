CREATE TABLE [dbo].[sqlwatch_stage_performance_counters_to_collect]
(
	object_name nvarchar(128),
	counter_name nvarchar(128),
	instance_name nvarchar(128),
	base_counter_name nvarchar(128),
	is_os_counter bit,

	constraint pk_sqlwatch_stage_performance_counters_to_collect primary key clustered (
		object_name, counter_name, instance_name
		)
)

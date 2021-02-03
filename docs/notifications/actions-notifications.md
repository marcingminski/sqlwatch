---
nav_order: 20
title: Actions & Notifications
---

# Actions and Notifications
{: .no_toc }

---

1. TOC
{:toc }

## Actions

Actions exted the SQLWATCH functionalty beyond SQL Server. They can send notifications and integrate with other applications and processes.
Actions are triggered by checks and the most common usage will be a failed check triggering an action to send an email notification. For example, a high CPU usage alert.

Actions are defined in the `[dbo].[sqlwatch_config_action]` table. The column `[action_exec]` contains the code that will be executed when the action is triggered.
The `[action_exec]` command accepts two parameters: `{SUBJECT}` and `{BODY}`. They are named SUBJECT and BODY to make it a bit easier to understand, however any value can be passed as either SUBJECT or BODY. In other words, please think about them as `{PARAMETER_1}` and `{PARAMETER_2}`.

Actions could be either a T-SQL or PowerShell scripts. Ability to run PowerShell makes it possible to call HTTP endpoints, interface with file systems and do all sorts of things that SQL Server is normally not capable of doing.

When an action runs, the `{SUBJECT}` and `{BODY}` variables are substitued and the result is added to the action queue table `[dbo].[sqlwatch_meta_action_queue]`. Up until this point everything happens in T-SQL. The queue processor is written in PowerShell which is the critical bit allowing actions to go beyond SQL Server scope.

## Checks

The most common action trigger will be a check. Checks are simple and very fast queries that return only one value. For example, average CPU utilisation over the last 5 minutes:

```
select avg(cntr_value_calculated) 
from dbo.vw_sqlwatch_report_fact_perf_os_performance_counters
where counter_name = 'Processor Time %'
and report_time > dateadd(minute,-5,getutcdate())
```

The result of the check is compared to the threshold values set in the `[dbo].[sqlwatch_config_check]` table. If the result is above `[check_threshold_warning]` value a WARNING status will be raised, if the result is above `[check_threshold_critical]` value, a CRITICAL status will be raised. 

Every time checks run, they log output in the `[dbo].[sqlwatch_logger_check]` table. In addition, they can trigger actions. This is optional, checks do not have to trigger actions but often they will.

For a check to trigger an action, the action must be assigned to it. One check can trigger multiple actions and the assosiation is done in `[dbo].[sqlwatch_config_check_action]` table.

## Templates

Checks return a number of different parameters, such as status (OK, WARNING, CRITICAL), check value, date and more. As we learned earlier, actions only accept two parameters `{SUBJECT}` and `{BODY}`. To be able to customise what goes into the BODY and SUBJECT fields we can use templates.

The below template will produce a `{BODY}` variable with the following content in plain text:

```
Check: {CHECK_NAME} ( CheckId: {CHECK_ID} )

Current status:  {CHECK_STATUS}
Current value: {CHECK_VALUE}

Previous value: {CHECK_LAST_VALUE}
Previous status: {CHECK_LAST_STATUS}
Previous change: {LAST_STATUS_CHANGE}

SQL instance: {SQL_INSTANCE}
Alert time: {CHECK_TIME}

Warning threshold: {THRESHOLD_WARNING}
Critical threshold: {THRESHOLD_CRITICAL}

--- Check Description:

{CHECK_DESCRIPTION}

--- Check Query:

{CHECK_QUERY}

---

Sent from SQLWATCH on host: {SQL_INSTANCE}
https://docs.sqlwatch.io
```

This way, everything is fully customisable and nothing is hardcoded. 

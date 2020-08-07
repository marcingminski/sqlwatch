/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
declare @action_template_plain nvarchar(max) = 'Check: {CHECK_NAME} ( CheckId: {CHECK_ID} )

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

{SQL_VERSION}'

declare @action_template_report_html nvarchar(max) = '<html>
  <head>
    <style>
		.badge {display: inline-block;padding: .25em .4em;font-size: 95%;font-weight: 700;line-height: 1;text-align: center;
			white-space: nowrap;vertical-align: baseline;border-radius: .25rem;transition: color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out;}
		.badge-CRITICAL {color: #fff;background-color: #dc3545;}
		.badge-WARNING {color: #212529;background-color: #ffc107;}
		.badge-OK {color: #fff;background-color: #28a745;}
    </style>
  </head>
  <body>
<p>Check: {CHECK_NAME} ( CheckId: {CHECK_ID} )</p>

<p>Current status: <span class="badge badge-{CHECK_STATUS}"><b>{CHECK_STATUS}</span></b>
<br>Current value: <b>{CHECK_VALUE}</b></p>

<p>Previous value: {CHECK_LAST_VALUE}
<br>Previous status: {CHECK_LAST_STATUS}
<br>Previous change: {LAST_STATUS_CHANGE}</p>

<p>SQL instance: <b>{SQL_INSTANCE}</b>
<br>Alert time: <b>{CHECK_TIME}</b></p>

<p>Warning threshold: {THRESHOLD_WARNING}
<br>Critical threshold: {THRESHOLD_CRITICAL}</p>

<p>--- Check Description:</p>

<p>{CHECK_DESCRIPTION}</p>

<p>--- Check Query:</p>

<p><table border=0 width="100%" cellpadding="10" style="display:block;background:#ddd; margin-top:1em;white-space: pre;"><tr><td><pre>{CHECK_QUERY}</pre></td></tr></table></p>

<p>--- Report Content:</p></p>

<p><b>{REPORT_TITLE}</b></p>
<p>{REPORT_DESCRIPTION}</p>
<p>{REPORT_CONTENT}</p>

<p>---</p>

<p>Sent from SQLWATCH on host: {SQL_INSTANCE}</p>
<p><a href="https://docs.sqlwatch.io">https://docs.sqlwatch.io</a> </p>
<p>{SQL_VERSION}</p>
  </body>
</html>';

declare @action_template_html nvarchar(max) = '<html>
  <head>
    <style>
		.badge {display: inline-block;padding: .25em .4em;font-size: 95%;font-weight: 700;line-height: 1;text-align: center;
			white-space: nowrap;vertical-align: baseline;border-radius: .25rem;transition: color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out;}
		.badge-CRITICAL {color: #fff;background-color: #dc3545;}
		.badge-WARNING {color: #212529;background-color: #ffc107;}
		.badge-OK {color: #fff;background-color: #28a745;}
    </style>
  </head>
  <body>
<p>Check: {CHECK_NAME} ( CheckId: {CHECK_ID} )</p>

<p>Current status: <span class="badge badge-{CHECK_STATUS}"><b>{CHECK_STATUS}</b></span>
<br>Current value: <b>{CHECK_VALUE}</b></p>

<p>Previous value: {CHECK_LAST_VALUE}
<br>Previous status: {CHECK_LAST_STATUS}
<br>Previous change: {LAST_STATUS_CHANGE}</p>

<p>SQL instance: <b>{SQL_INSTANCE}</b>
<br>Alert time: <b>{CHECK_TIME}</b></p>

<p>Warning threshold: {THRESHOLD_WARNING}
<br>Critical threshold: {THRESHOLD_CRITICAL}</p>

<p>--- Check Description:</p>

<p>{CHECK_DESCRIPTION}</p>

<p>--- Check Query:</p>

<p><table border=0 width="100%" cellpadding="10" style="display:block;background:#ddd; margin-top:1em;white-space: pre;"><tr><td><pre>{CHECK_QUERY}</pre></td></tr></table></p>

<p>---</p>

<p>Sent from SQLWATCH on host: {SQL_INSTANCE}</p>
<p><a href="https://docs.sqlwatch.io">https://docs.sqlwatch.io</a> </p>
<p>{SQL_VERSION}</p>
  </body>
</html>';

declare @action_template_pushover nvarchar(max) = 'Check: {CHECK_NAME} ( CheckId: {CHECK_ID} )

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

---

Sent from SQLWATCH on host: {SQL_INSTANCE}
https://docs.sqlwatch.io

{SQL_VERSION}';

disable trigger [dbo].[trg_sqlwatch_config_check_action_template_modify] on [dbo].[sqlwatch_config_check_action_template];  --so we dont populate updated date as this is to detect if a user has modified default template
set identity_insert [dbo].[sqlwatch_config_check_action_template] on;
merge [dbo].[sqlwatch_config_check_action_template] as target
using (
	select
		 [action_template_id] = -1
		,[action_template_description] = 'Default plain notification template (Text).'
		,[action_template_fail_subject] = '{CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_fail_body] = @action_template_plain
		,[action_template_repeat_subject] = 'REPEATED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_repeat_body] = @action_template_plain
		,[action_template_recover_subject] = 'RECOVERED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_recover_body]	= @action_template_plain
		,[action_template_type] = 'TEXT'

	union all

	select
		 [action_template_id] = -2
		,[action_template_description] = 'Default Email notification template for Reports (HTML). This template is used for actions that run reports. The Report content is embeded in the check.'
		,[action_template_fail_subject] = '{CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_fail_body] = @action_template_report_html
		,[action_template_repeat_subject] = 'REPEATED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_repeat_body] = @action_template_report_html
		,[action_template_recover_subject] = 'RECOVERED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_recover_body]	= @action_template_report_html
		,[action_template_type] = 'HTML'

	union all

	select
		 [action_template_id] = -3
		,[action_template_description] = 'Default Email notification template (HTML). This template is used for actions that do not trigger reports but have HTML content.'
		,[action_template_fail_subject] = '{CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_fail_body] = @action_template_html
		,[action_template_repeat_subject] = 'REPEATED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_repeat_body] = @action_template_html
		,[action_template_recover_subject] = 'RECOVERED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_recover_body]	= @action_template_html
		,[action_template_type] = 'HTML'

	union all

	select
		 [action_template_id] = -4
		,[action_template_description] = 'Default notification template for Pushover. Plain text template with reduced content to comply with Pushover limitations.'
		,[action_template_fail_subject] = '{CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_fail_body] = @action_template_pushover
		,[action_template_repeat_subject] = 'REPEATED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_repeat_body] = @action_template_pushover
		,[action_template_recover_subject] = 'RECOVERED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_recover_body]	= @action_template_pushover
		,[action_template_type] = 'TEXT'
		) as source
on target.[action_template_id] = source.[action_template_id]
when not matched then
	insert ( [action_template_id]
			,[action_template_description]
			,[action_template_fail_subject]
			,[action_template_fail_body]
			,[action_template_repeat_subject]
			,[action_template_repeat_body]
			,[action_template_recover_subject]
			,[action_template_recover_body]
			,[action_template_type]
			)
	values (
			 source.[action_template_id]
			,source.[action_template_description]
			,source.[action_template_fail_subject]
			,source.[action_template_fail_body]
			,source.[action_template_repeat_subject]
			,source.[action_template_repeat_body]
			,source.[action_template_recover_subject]
			,source.[action_template_recover_body]
			,source.[action_template_type]
			)
when matched and target.[date_updated] is null then --only update when not modified by a user
	update set [action_template_description] = source.[action_template_description]
			,[action_template_fail_subject] = source.[action_template_fail_subject]
			,[action_template_fail_body] = source.[action_template_fail_body]
			,[action_template_repeat_subject] = source.[action_template_repeat_subject]
			,[action_template_repeat_body] = source.[action_template_repeat_body]
			,[action_template_recover_subject] = source.[action_template_recover_subject]
			,[action_template_recover_body] = source.[action_template_recover_body]
			,[action_template_type] = source.[action_template_type]
;
set identity_insert [dbo].[sqlwatch_config_check_action_template] off;
enable trigger [dbo].[trg_sqlwatch_config_check_action_template_modify] on [dbo].[sqlwatch_config_check_action_template];
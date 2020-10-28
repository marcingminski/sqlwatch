---
title: Known Issues
nav_order: 400
---

# Known Issues
{: .no_toc }
---

- TOC
{:toc}

## Collation conflict

If you encounter collation conflict during installation it means that your server’s collation is different from the SQLWATCH database collation and SQL cannot handle string comparisons.
`We use the Latin1_General_CI_AS collation`.

If you encounter this issue you can:

**Manually create an empty database**

By default, SQL Server creates new databases with the default servers' collation unless otherwise specified. The collation cannot be changed once the database has been created. By manually creating SQLWATCH database will force default collation.

```
CREATE DATABASE [SQLWATCH]
GO
```

Once the empty shell database has been created we can proceed with the installation as usual.

**Rebuild the project into the desired target collation**

If the above does not meet your requirements you can load the database solution in Visual Studio (please follow "Deploy from source code" guide for details) , change database collation to the desired value and rebuild and deploy.
Rebuilding the project into specific collation may result in a better performance. 

## Database drift

In some cases, you may receive the following error when upgrading from DacPac:

```
Database has drifted from its registered data-tier application
```

When SQLWATCH is deployed, it registers itself as data-tier application, which adds a record in `msdb.dbo.sysdac_instances`. 
The error may happen when database objects have been changed since the last deployment, for example, when you deploy SQLWATCH into your existing "dba_tools" database and add or remove some other tables, not related to SQLWATCH.

Registering data-tier application is useful to identify the currently installed version, however since version 2.x we have alterative method where we log this information directly in the SQLWATCH table there is no need for it.

**Unregister Data-Tier Application**

To work around this issue, we have to unregister the data-tier application. This can be done in SQL Server Management Studio: Right-click database -> Tasks -> Delete Data-Tier Application.

Alternatively, you can use T-SQL to achieve the same:

```
declare @instance_id uniqueidentifier
declare @database_name sysname = 'SQLWATCH'

select @instance_id = instance_id
from msdb.dbo.sysdac_instances dp 
where dp.instance_name = @database_name

exec dbo.sp_sysdac_delete_instance 
	    @instance_id = @instance_id
    
exec dbo.sp_sysdac_update_history_entry 
    @action_id=21,
    @instance_id=@instance_id,
    @action_type=14,
    @dac_object_type=0,
    @action_status=2,
    @dac_object_name_pretran=@database_name,
    @dac_object_name_posttran=@database_name,
    @sqlscript=NULL,
    @error_string=N''
```

## Login failed error when running disk logger

In some cases you may be getting the following error when running Step 2 of the `SQLWATCH-LOGGER-DISK-UTILISATION` Agent Job:

```
Cannot open database "SQLWATCH" requested by the login. The login failed.  Login failed for user 'HOME\SQL-TEST-1$'
```

This is because PowerShell jobs run under a SQL Agent context and this means they may not have permissions to the SQL Server and the SQLWATCH database.
SQLWATCH will not alter your server security configuration or permissions or create any accounts. If you do encounter this error you will have to fix it manually. Depending on your environment, there may be different ways to address this, some more appropriate and some less, again, depending on your setup.

The recommended and most secure way is to create a [SQL Agent Proxy Account](https://docs.microsoft.com/en-us/sql/ssms/agent/create-a-sql-server-agent-proxy) and grant this account db_datawriter and db_datareader roles in the SQLWATCH database. This account will need appropriate access to read OS disks. This account will ONLY have access you have created.

An alternative and slightly easier way are to grant `db_datawriter` and `db_datareader` roles to the login reported in the error in the SQLWATCH database. However, in this case, we may be granting permission to the SQLWATCH database to an account that perhaps should not have such access. Please be sure you are familiar with the security configuration in your environment. In our example this would be:

```
USE [master]
GO
CREATE LOGIN [HOME\SQL-TEST-1$] FROM WINDOWS
GO
USE [SQLWATCH]
GO
CREATE USER [HOME\SQL-TEST-1$] FOR LOGIN [HOME\SQL-TEST-1$]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [HOME\SQL-TEST-1$]
GO
ALTER ROLE [db_datareader] ADD MEMBER [HOME\SQL-TEST-1$]
GO
```

## Deadlock when creating the database

A few people experienced a deadlock whilst creating SQLWATCH Database. In all cases this was caused by the Query Store enabled on the model database. The locking transaction was `GetQdsTotalReseveredPageCount`. If you experience such issue, please disable Query Store on the model database and then re-try SQLWATCH deployment. 

## Timeout when deploying DACPAC

Depending on your workload and evironment, the dacpac deployment may sometimes time out. If this happens, you may want to increase the deployment timeout. This option is only available when using `SqlPackage.exe`:

```
/p:CommandTimeout=240
```

For example:

```
SqlPackage.exe /Action:Publish /SourceFile:"C:\Temp\SQLWATCH.dacpac" /TargetDatabaseName:SQLWATCH /TargetServerName:SQLSERVER /p:RegisterDataTierApplication=True /p:CommandTimeout=240
```
Thanks to Rafael Cuesta for reporting this.

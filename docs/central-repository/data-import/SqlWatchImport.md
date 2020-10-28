---
parent: Central Repository
title: SqlWatchImport
nav_order: 10
---

# Import remote data using `SqlWatchImport`
{: .no_toc }
---

Since version `3.x`, a new console application has been made available to efficiently handle imports from the remote instances. This is the preferred way to import data from the remote SQLWATCH databases. 

- TOC 
{:toc}

## Overview

The `SqlWatchImport.exe` leverages the performance of the .NET `SqlBulkCopy` and data streaming for fast inserts as well as framework's Thread and Connection pooling which makes it very efficient and lightweight. In my test setup, importing data from the same, single remote instance takes ~10 seconds in SSIS and Linked Server and 1.2 second using the console application.

The more often the import runs, the quicker it is because it has less work to do. You will have to find the best balance in your environment, as a reference, I have it running every 1 minute and as you can see, some servers take less tha 1 second to import:

```
2020-08-23 20:36:31.669  SQLWATCH Remote Instance Importer 
                         Imports remote SQLWATCH data into the Central Repository
                         Marcin Gminski 2020, SQLWATCH.IO
                         Version: 1.1.7537.25291 (8/20/2020 2:03:02 PM) 
2020-08-23 20:36:31.732  Got 3 instances to import 
2020-08-23 20:36:31.732  Got 44 tables to import from each instance 
2020-08-23 20:36:31.748  Importing: "SQLWATCH-TEST-1" 
2020-08-23 20:36:32.107  Importing: "SQL-1" 
2020-08-23 20:36:32.138  Finished: "SQLWATCH-TEST-1". Time taken: 379.5364ms 
2020-08-23 20:36:32.424  Importing: "SQLWATCH-TEST-2" 
2020-08-23 20:36:33.201  Finished: "SQLWATCH-TEST-2". Time taken: 768.9659ms 
2020-08-23 20:36:33.857  Finished: "SQL-1". Time taken: 1746.7494ms 
2020-08-23 20:36:33.857  Import completed in 2176.7349ms 
```

Prior to version `3.x` the data import was done with SSIS or via Linked Server. The application was written to address the following problems:

* SSIS is fast but cumbersome to maintain - every time new table or column is changed or added to the SqlWatch database, the package requires manual changes to reflect database changes. This is very time consuming and error prone. I am also trying to stay away from BIML to reduce complexity of the solution.
* Threading in SSIS is limited by the design of the package. 
* Not everyone has Integration Server.
* Linked Server does not require as much maintenance but it does rely on SQL Agent for data collection so cannot be run on SQL Express directly.
* Linked Server is not as fast as SSIS and does not handle XML fields.

## Configuration

The application configuration items are in the `App.config` file, included in the application folder.
Before the first run, you are going to have to configure Central Repository connection parameters:

```
<!-- Central repository connection details -->
<add key="CentralRepositorySqlInstance" value="REPOSITORY-SQLSERVER" />
<add key="CentralRepositorySqlDatabase" value="SQLWATCH" />
```

## Add and manage remote instance

The application allows adding new and updating existing remote Sql Instances. 

### Examples

Add remote Sql Instance "SQLSERVER1" with SqlWatch database "SQLWATCH" using Windows Authentication:
```
SqlWatchImport.exe --add -s SQLSERVER1 -d SQLWATCH
```

Add remote Sql Instance "SQLSERVER1" with SqlWatch database "SQLWATCH" using Sql user "Marcin" and Sql password "Password":
```
SqlWatchImport.exe --add -s SQLSERVER1 -d SQLWATCH -u Marcin -p Password
```

Add remote Sql Instance with custom hostname and port:
```
SqlWatchImport.exe --add -s SQLSERVER1 -d SQLWATCH -h 192.168.1.10 -o 1433
```
> You only have to configure hostname if your `@@SERVERNAME` does not match the physical hostname. Normally this would be a configuration error apart from rare scenarios, such as running Sql as a Docker container.

Update existing remote instance:
```
SqlWatchImport.exe --update -s SQLSERVER1 -d SQLWATCH -u Marcin -p NewPassword
```

Display help:
```
SqlWatchImport.exe -h 
```
The configuration data is saved in table `[dbo].[sqlwatch_config_sql_instance]`.

## Data Import

Once all remote instances have been added, data import can be simply invoked by running the `SqlWatchImport.exe` without any arguments.


## Credential encryption

It is advisable to use Windows Authentication instead of Sql Authentication. If you really have to use Sql Authentication you have to keep in mind few things.

The credentials will be encrypted and stored in the `[dbo].[sqlwatch_config_sql_instance]` table. The encryption will be done using .NET `MachineKey.Protect` method. This is a standard method often used to encrypt connection strings on web servers running .NET applications. 

By default, the encryption will use the Machine Key, which means, the application will be able to decrypt passwords on the same machine where the password was encrypted. For example, if you run `SqlWatchImport.exe --add -s SQLSERVER1 -d SQLWATCH -u Marcin -p Password` on your laptop, you will only be able to run the data import on your laptop. If you want to re-save the use secret on a new machine you will have to run the update command `SqlWatchImport.exe --update ...`

You can also use custom MachineKey stored in the `App.config` file. You can generate new key on https://www.allkeysgenerator.com/Random/ASP-Net-MachineKey-Generator.aspx and save it in the config file. This will allow the application to work from any machine.

If you ever decide to change the MachineKey, you will have generate new Sql Secrets by running the `--update` option. 

> Please note that anyone who has access to the machine, will be able to access the MachineKey and your config file. If they also have access to the SQLWATCH database where the secrets are saved, they will be able to decrypt it. Limit Read Only access to only authorised persons. If you use Sql Authentication, please create dedicated Sql Accounts for importing data. They should only have Read Only access to the remote database so if the passwords are broken, the intruder will not gain access to anything else but meaningless SQLWATCH data.

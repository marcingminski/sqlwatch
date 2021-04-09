![GitHub release](https://img.shields.io/github/release/marcingminski/sqlwatch.svg)
![GitHub All Releases](https://img.shields.io/github/downloads/marcingminski/sqlwatch/total.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![GitHub commits since latest release (by date)](https://img.shields.io/github/commits-since/marcingminski/sqlwatch/latest)
![AppVeyor](https://img.shields.io/appveyor/build/marcingminski/sqlwatch?label=branch%20build)
![AppVeyor tests](https://img.shields.io/appveyor/tests/marcingminski/sqlwatch)


# About
SQLWATCH is a SQL Server Performance and capacity data collector with Power BI dashboard for data analysis. The idea behind is to provide community driven, standardised "interface" for SQL Server monitoring that can be consumed by various interfaces and integrate with availabilty monitoring platforms such as Nagios, Zabbix, PRTG

# Resources
* How to get started https://sqlwatch.io/get 
* Documentation https://docs.sqlwatch.io
* Our Slack channel for discussion, asking questions, solving problems https://sqlcommunity.slack.com/messages/CCCETQBFZ

# Architecture
SQLWATCH uses SQL Agent Jobs to trigger data collection on a schedule which write results to a local database. For that reason each monitored SQL Server instance must have SQLWATCH deployed, however, the destination database can be an existing "dbatools" database, msdb or a dedicated SQLWATCH database. For performance reasons, it is advisable to deploy into a dedicated database as we're setting Read Committed Snapshot Isolation which will not be done if deployed to an existing database. The data can be consumed and analysed by the Power BI report. 

# Requirements
Tested on the following SQL Server versions:
* 2008 R2 SP3
* 2012
* 2014
* 2016
* 2017
* 2019

SQL Server Express is not supported as there is no Agent to invoke data collection. Theoretically, data collection would be possible via SQLCMD triggered from the Windows Task Scheduler but we have not got that tested or even coded.

>>Although Docker and Linux work, the Windows-only WMI basd disk utilisation collector will fail.

# Installation
The easiest way to install SQLWATCH is to use [dbatools](https://github.com/sqlcollaborative/dbatools):

```
Install-DbaSqlWatch -SqlInstance SQLSERVER1,SQLSERVER2,SQLSERVER3 -Database SQLWATCH
```
Alternatively, SQLWATCH can also be deployed manually from the included Dacpac either via command line using [SqlPackage.exe](https://docs.microsoft.com/en-us/sql/tools/sqlpackage?view=sql-server-2017):
```
SqlPackage.exe 
   /Action:Publish 
   /SourceFile:C:\Temp\SQLWATCH.dacpac 
   /TargetDatabaseName:SQLWATCH 
   /TargetServerName:YOURSQLSERVER 
   /p:RegisterDataTierApplication=True
  ```
  Or by [deploying Data-Tier application in SQL Server Management Studio](https://docs.microsoft.com/en-us/sql/relational-databases/data-tier-applications/deploy-a-data-tier-application?view=sql-server-2017)


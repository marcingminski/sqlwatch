---
title: Central Repository
nav_order: 20
has_children: true
---

# Central Repository
{: .no_toc }
---

The central repository is an ordinary SQLWATCH database where data from other instances is being imported for centralised reporting. Any SQLWATCH database can become a central repository.

- TOC 
{:toc}

## Overview

The central repository will import data from remote SQLWATCH instances into a central database. SQLWATCH must be installed on each monitored Sql Server.

The performance impact on the remote instance will be mainly driven by the amount of data we are pulling with each connection. The collection from the remote instance into the central repository is primarily delta with few exceptions of merged tables. The more often we are pulling data into the central repository the less data it will pull and likely less performance impact. Below is an example of the CPU utilisation of the remote instance whilst pulling a 5 minutes delta into the central repository. Note that pull does not last longer than a few seconds:

![SQLWATCH Central Repository impact on remote instance]({{ site.baseurl }}/assets/images/sqlwatch-central-repository-reading-impact.png)

## Permissions

The permission required to collect data from the remote instance is `db_datareader`. Permissions required to insert data into the central repository are: `db_datareader` to read parameters, `db_datawriter` to write data and `db_ddladmin` for bulk inserts and truncates.

## Importing data

From version `3.x`, the recommended way to import data from the remote instance is by using the included `SqlWatchImport.exe` console application. It has been designed and optimized specifically for this task. The application can be scheduled to be invoked by Windows Scheduled Tasks, SQL Agent Job or any other scheduling tool able to run `.exe` application. Prior to version `3.x`, there were alternative ways available that will also work with `3.x`.
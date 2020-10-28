---
title: Getting Started
has_children: true
nav_order: 10
---

# Getting Started
{: .no_toc }
---

SQLWATCH is a SQL Server database with some agent jobs. Installing SQLWATCH means deploying the database and corresponding agent jobs. 
It must be installed on each monitored SQL Server instance. 

The project has been developed in Visual Studio Data Tools and the base for deployments are Data Application Tier Packages (DacPac). 
You can install SQLWATCH in several ways.

- TOC
{:toc}

During installation, the following objects will be created:
- SQLWATCH database (or SQLWATCH objects in the existing database is such option was selected)
- Extended Event Sessions (`SQLWATCH-%`)
- Agent Jobs (`SQLWATCH-%`)

During installation, once the Agent Jobs have been deployed, the following job will be automatically invoked: `SQLWATCH-INTERNAL-CONFIG`. The job is normally scheduled to run every hour but the performance data collection will not start until this job runs. If the job fails to run during the deployment, you may want to run it manually after the deployment.

## Install with dbatools

[dbatools](https://dbatools.io/) support multi-server installation with a single command:

### Stable Release

To install into SQLWATCH database (new database will be created):

```
Install-DbaSqlWatch -SqlInstance Server1, Server2, Server3 -Database SQLWATCH
```

To install into your existing "DBA_ADMIN" database:

```
Install-DbaSqlWatch -SqlInstance Server1, Server2, Server3 -Database DBA_ADMIN
```

### Beta (Pre) Release

```
Install-DbaSqlWatch -SqlInstance DevServer1 -Database SQLWATCH -PreRelease
```

<div class="responsive-iframe-container responsive-iframe-container-4-3">
  <iframe class="responsive-iframe" src="https://www.youtube-nocookie.com/embed/W38osuBv_Q8" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

>The `Install-DbaSqlWatch` was designed for unattended multi-server installations. It will download the latest release and unpack it, including the Power BI dashboard, into its temporary directory.

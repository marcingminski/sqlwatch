---
parent: Getting Started
nav_order: 1
---

# Alternative Installation
{: .no_toc }

---

The following alternative insatllation methods are currently supported:

- TOC
{:toc}

## SqlPackage

The `SqlPackage.exe` is a command-line utility that automates SQL Server database deployments. This command comes with SQL Server Management Studio (SSMS) and is located in the ...\DAC\bin folder: `C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\SqlPackage.exe` Where 140 is the version of installed Management Studio. Your version and path may be different from the example. [Learn more about SqlPackage](https://docs.microsoft.com/en-us/sql/tools/sqlpackage)

To install SQLWATCH using `SqlPackage.exe`, please download the required release from our GitHub Releases and unzip. In this example we are using C:\Temp:

```
SqlPackage.exe 
    /Action:Publish 
    /SourceFile:C:\Temp\SQLWATCH.dacpac 
    /TargetDatabaseName:SQLWATCH 
    /TargetServerName:YOURSQLSERVER 
    /p:RegisterDataTierApplication=True
```

## Management Studio

SQL Server Management Studio (SSMS) is a free, integrated development environment (IDE) for SQL Server. [Learn more about SSMS](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms).

To install SQLWATCH using SSMS, please download the required release from our GitHub Releases and unzip. In this example we are using C:\Temp
Connect to the desired SQL Server, right click on Databases and select Deploy Data-Tier Application. Find the SQLWATCH.dacpac you have unzipped and follow the instructions:


<div class="responsive-iframe-container responsive-iframe-container-16-9">
  <iframe class="responsive-iframe" src="https://www.youtube-nocookie.com/embed/caufO79tKo4" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

## Build from Source

SQLWATCH is developed in [Visual Studio Community (Express)](https://visualstudio.microsoft.com/vs/express/). You can obtain a free copy of the Community edition on Microsoft website. You can also use Visual Studio Standard or Professional. You will also need to install [Data Tools (SSDT)](https://docs.microsoft.com/en-us/sql/ssdt/download-sql-server-data-tools-ssdt) - a Visual Studio plugin to understand SQL Server databases.

To deploy from VS, you will need to download the source code from GitHub. If you are planning on contributing to the project or making changes you will have to clone (or fork) the latest branch. You can also download a source code attached to a release which will contain a snapshot of the master branch at the time of build. 
Open the solution in Visual Studio and go to Build in the main menu and select Publish SQLWATCH. Next, set your connection to the destination server and click publish.

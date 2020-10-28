---
parent: Getting Started
nav_order: 99
---

# Removal
{: .no_toc }

---

SQLWATCH is a SQL Server database. It can be removed in two ways:

- TOC
{: toc }

## dbatools

Automatically with dbatools

```
Uninstall-DbaSqlWatch
```

>The Uninstall-DbaSqlWatch will only work if the database was installed using Install-DbaSqlWatch

Please be aware that there are safety measures built into the removal process to make sure that only objects deployed by the `Install-DbaSqlWatch` are removed, including database. If the deployment was into an existing database this will not be removed, analogically, if user tables were added to the SQLWATCH database post-deployment they were not registered as part of the application and thus they will not be removed and subsequently the database will not be dropped. 

## Manually

When removing manually please ensure the follwowing objects are removed:
- SQLWATCH database (`DROP DATABASE`)
- Extended Events (`SQLWATCH-%`)
- Agnet Jobs (`SQLWATCH-%`)
- Any additional PowerShell scripts used by the Actions engine (only if you have installed any manually, SQWALTCH does not create anything on the disk)

If you have installed Windows Scheduled Tasks they will too need to be removed manually.

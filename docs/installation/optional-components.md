---
parent: Getting Started
nav_order: 2
---

# Optional Components
{: .no_toc }

---

SQLWATCH can also capture output from the following optional components. 

- TOC
{:toc}

## sp_WhoIsActive

SQLWATCH will log output from Adam Machanic's, fantastic `sp_WhoIsAcitve` which can also be installed using dbatools. SQLWATCH will look for the procedure in either the `master` database or the database where the SQLWATCH is installed (default SQLWATCH but it could any database)

```
Install-DbaWhoIsActive -SqlInstance YourServer -Database master
```

When the `sp_WhoIsActive` procedure is detected during installation, the job `SQLWATCH-LOGGER-WHOISACTIVE` will be deployed in enabled state. If the procedure is not detected during installation, the job will be deployed in a **disabled** state

## dbachecks

When dbachecks write output to the SQLWATCH database, the results will be shown on the SQLWATCH dashboard which can be correlated with other metrics. [Learn more about dbachecks](https://dbachecks.readthedocs.io/en/latest/)

---
parent: Getting Started
nav_order: 10
title: Upgrade and Downgrade
---

# Upgrade

---

SQLWATCH has been developed in Visual Studio which is based on [Declarative Deployment Model](https://blogs.msdn.microsoft.com/gertd/2009/06/05/declarative-database-development/). 
This means that when a database is deployed, the deployment mechanism works out what needs to be done to bring the target database to the desired version.

To upgrade SQLWATCH database one simply follows the installation process. 
The only exception is when using SSMS, there is an explicit Upgrade Option in the database context (Right-click on database -> Tasks -> Upgrade data-tier application):

![SSMS Upgrade DacPac]({{ site.baseurl }}/assets/images/ssms-upgrade-data-tier-application.png)

## Challenges
Whilst declarative deployment makes the development very easy and deployment very reliable (either all or nothing) it can be a bottleneck when large schema changes are required. 
For example, migrating data type from UNIQUE IDENTIFIER to INTEGER would fail as such conversion is impossible. 
When this happens, manual migrations scripts are required which will be noted in the release notes.


# Downgrade

---

Whilst it is possible to downgrade database schema by deploying a previous DacPac there are few things to have in mind. 
Database deployments are designed to avoid data loss which means that any modification that could result in data loss will be rejected. For example, if new columns have been added in the latest release, downgrading to the previous release would result in the removal of the new columns. By default this operation is not allowed, however, it can be forced with the `SqlPackage.exe` and the following parameters:

```
/p:BlockOnPossibleDataLoss=false
```

Please make sure you have tested the downgrade in a non-production environment first and that you are familiar with the `SqlPackage.exe` parameters available on the Microsoft Docs website before you downgrade database version.

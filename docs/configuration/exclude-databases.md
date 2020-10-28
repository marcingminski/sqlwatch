---
nav_order: 20
parent: Data Collection
grand_parent: Configuration
title: Exclude Database
---

# Exclude Database from Collection
{: .no_toc }
---

We can exclude specific database from specific collectors in table `[dbo].[sqlwatch_config_exclude_database]`

For example, we may not want to collect Missing Indexes from a specific third party vendor database as we may have no control over indexes in this database.

In this case, we would add a record to `[dbo].[sqlwatch_config_exclude_database]` with the database name and the `[snapshot_type_id]` we want to exclude. We can find all snapshot types in `[dbo].[sqlwatch_config_snapshot_type]`.

```
  insert into [dbo].[sqlwatch_config_exclude_database]
  values ('VendorDatabaseName',3) -- where 3 is the [snapshot_type_id] of the Missing Indexes Collector
```

It is also possible to use patterns:

```
  insert into [dbo].[sqlwatch_config_exclude_database]
  values ('VendorDatabase%',3) -- where 3 is the [snapshot_type_id] of the Missing Indexes Collector
```
Would exclude all databases like `'VendorDatabase%'` such as `VendorDatabase1`, `VendorDatabase2` etc... 

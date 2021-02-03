---
nav_order: 30
parent: Data Collection
grand_parent: Configuration
title: Exclude Long Queries
---

# Exclude Long Queries from the XES Long Query Collector
{: .no_toc }
---

The Extended Event Session `SQLWATCH_Long_Queries` will collect queries that run for longer 15 seconds. However, in some cases long running queries are unavoidable in which case they would flood the collector.

To exclude a specific query from the collection, we can add it to the `[dbo].[sqlwatch_config_exclude_xes_long_query]` table.

We can use either of all of the columns:

```
      ,[statement]
      ,[sql_text]
      ,[username]
      ,[client_hostname]
      ,[client_app_name]
```

To exclude all queries from a specific client (hostname) we can use the following statement:

```
insert into [dbo].[sqlwatch_config_exclude_xes_long_query]([client_hostname])
values ('some hostname')
```

To exclude all queries from a specific application:

```
insert into [dbo].[sqlwatch_config_exclude_xes_long_query]([client_app_name])
values ('noisy app')
```

To exclude queries from a specific user:

```
insert into [dbo].[sqlwatch_config_exclude_xes_long_query]([username])
values ('The CEO')
```

To exclude specific queries:

```
insert into [dbo].[sqlwatch_config_exclude_xes_long_query]([sql_text])
values ('select * from bigtable')
```

To exclude specific queries from a specific application:

```
insert into [dbo].[sqlwatch_config_exclude_xes_long_query]([client_app_name],[sql_text])
values ('BadApp','select * from badtable')
```


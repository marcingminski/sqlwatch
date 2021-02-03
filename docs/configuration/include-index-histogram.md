---
nav_order: 50
parent: Data Collection
grand_parent: Configuration
title: Include Index Histograms
---

# Include specific index histograms
{: .no_toc }
---

Index histograms can be very large and so they are not being collected by default. 
To collect histograms of specific indexes we can add them to the `[dbo].[sqlwatch_config_include_index_histogram]` table.

To collect ALL histograms from ALL indexes and tables (not recommended):

```
insert into [dbo].[sqlwatch_config_include_index_histogram]
values ('%.%','%')
```

To collect all histograms from all indexes for a specific table:

```
insert into [dbo].[sqlwatch_config_include_index_histogram]
values ('dbo.table_with_histograms_we_want','%')
```

To collect histograms from a specific indexes:

```
insert into [dbo].[sqlwatch_config_include_index_histogram]
values ('dbo.table_with_histograms_we_want','some_index_of_interest')
```

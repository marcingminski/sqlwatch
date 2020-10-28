---
nav_order: 20
parent: Data Collection
grand_parent: Configuration
title: Exclude Wait Stats
---

# Exclude Wait Stats from Collection
{: .no_toc }
---

To exclude specific Wait Type from collection, you can add it to the `[dbo].[sqlwatch_config_exclude_wait_stats]` table. 

For example, to exclude `WAITFOR` wait type, we would add the following record:

```
insert into [dbo].[sqlwatch_config_exclude_wait_stats]
values ('WAITFOR')
```
SQLWATCH already excludes all wait types that do not impact performance and usually there is no need to modify those.
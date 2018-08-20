# SQLWATCH
Yet another SQL Server performance monitor with a PowerBI dashboard

The SQLServer-Performance-Poster.pdf is a very good Performance Counter reference from Quest Software.

details: https://marcin.gminski.net/goodies/sql-server-performance-dashboard-using-powerbi/

## Installation
By default, the script will create tables in tempdb. Please be aware that tempdb gets cleared down on server restart so you will lose your monitoring data. You may wish to install it in your own dedicated database.

# Roadmap
I would like to implement the following:
1. Database and individual tables growth history.
1. Backup and maintenance history (things like succesful DBCC checks)
1. Index usage history to help identify overindexed tables.
1. Missing indexes
1. Top queries
1. Some sort of Server configuration overview and perhaps validation 
1. Query store analysis
1. Errorlog analysis
1. Alerts. It would be good to have but may be difficult to implement.

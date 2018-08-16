# sql-performance-monitor
Yet another SQL Server performance monitor with a PowerBI dashboard

The SQLServer-Performance-Poster.pdf is a very good Performance Counter reference from Quest Software.

details: https://marcin.gminski.net/goodies/sql-server-performance-dashboard-using-powerbi/

## Installation
By default, the script will create tables in tempdb. Please be aware that tempdb gets cleared down on server restart so you will lose your monitoring data. You may wish to install it in your own dedicated database.

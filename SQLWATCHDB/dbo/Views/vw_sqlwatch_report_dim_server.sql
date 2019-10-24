CREATE VIEW [dbo].[vw_sqlwatch_report_dim_server] with schemabinding
as
SELECT [physical_name]
      ,[servername]
      ,[service_name]
      ,[local_net_address]
      ,[local_tcp_port]
      ,[utc_offset_minutes]
  FROM [dbo].[sqlwatch_meta_server]

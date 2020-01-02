CREATE PROCEDURE usp_sqlwatch_internal_purge_jobhistory @retentiondays INT = 7
AS
     DECLARE @jobname NVARCHAR(256);
     DECLARE @cleanupdate DATETIME;
     SET @cleanupdate = DATEADD(dd, -@retentiondays, GETDATE());
  
     -- Get all sqlwatch Job names
     DECLARE C_jobname CURSOR
     FOR SELECT [name]
         FROM msdb.dbo.sysjobs
         WHERE [name] LIKE 'SQLWATCH%';
     OPEN c_jobname;
     FETCH NEXT FROM c_jobname INTO @jobname;
     WHILE @@FETCH_STATUS = 0
         BEGIN
             --select @jobname
             --clearing job history
             EXEC msdb.dbo.sp_purge_jobhistory 
                  @job_name = @jobname, 
                  @oldest_date = @cleanupdate;
             FETCH NEXT FROM c_jobname INTO @jobname;
         END;
     CLOSE c_jobname;
     DEALLOCATE c_jobname;
    -- EXEC usp_sqlwatch_internal_purge_jobhistory ;
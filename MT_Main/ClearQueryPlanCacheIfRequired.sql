/****** Object:  StoredProcedure [dbo].[ClearQueryPlanCacheIfRequired] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ClearQueryPlanCacheIfRequired
/****************************************************
** 
**	Desc:	Clears the ad-hoc query plan cache if too large
**
**			Leverages code from Kimberly L. Tripp, SQLskills.com
**			http://www.sqlskills.com/blogs/kimberly/plan-cache-adhoc-workloads-and-clearing-the-single-use-plan-cache-bloat/
**
**	Important Note:
**			In order for the lookup of "max server memory" to work,
**			"show advanced options" must be set to 1 using sp_configure
**			prior to calling this procedure
**
**			sp_configure 'show advanced options', 1;
**			RECONFIGURE
**
**	Auth:	mem
**	Date:	02/20/2014 mem - Initial version
**			02/27/2014 mem - Updated to actually use @MemoryUsageThresholdPercent and @MemoryUsageMBThreshold (previously used hard-coded values)
**    
*****************************************************/
(
	@MemoryUsageThresholdPercent int = 10,
	@MemoryUsageMBThreshold int = 250,
	@message varchar(512) = '' output,
	@InfoOnly tinyint = 1
)
As
	set nocount on

	----------------------------------------------------
	-- Validate the inputs
	----------------------------------------------------
	
	If @MemoryUsageThresholdPercent < 10
		Set @MemoryUsageThresholdPercent = 10
	If @MemoryUsageThresholdPercent > 50
		Set @MemoryUsageThresholdPercent = 50
		
	If @MemoryUsageMBThreshold < 25
		Set @MemoryUsageMBThreshold = 25

	Set @InfoOnly = IsNull(@InfoOnly, 1)
	
	----------------------------------------------------
	-- Determine memory usage stats
	----------------------------------------------------
	--
	Declare @Percent decimal(6, 3)
	Declare @WastedMB decimal(19,3)
	Declare @StrMB varchar(20)
	Declare @StrPercent varchar(20)
	Declare @ClearCache tinyint = 0
	
	Declare @ConfiguredMemory decimal(19,3)
	Declare @PhysicalMemory decimal(19,3)
	Declare @MemoryInUse decimal(19,3)
	Declare @SingleUsePlanCount bigint

	CREATE TABLE #ConfigurationOptions (
	    [name]         nvarchar(35),
	    [minimum]      int,
	    [maximum]      int,
	    [config_value] int				-- in bytes
	                          ,
	    [run_value]    int				-- in bytes
	);
	INSERT #ConfigurationOptions EXEC ('sp_configure ''max server memory''');

	If Not Exists (Select * From #ConfigurationOptions)
	Begin
		print 'Error, sp_configure option "max server memory" is not available'
		print 'Run these commands before running this procedure:'
		print 'sp_configure ''show advanced options'', 1;'
		print 'RECONFIGURE'
		Return 50000;
	End
	
	SELECT @ConfiguredMemory = run_value 
	FROM #ConfigurationOptions 
	WHERE name = 'max server memory (MB)'

	If @ConfiguredMemory Is Null
	Begin
		print 'Error, sp_configure option "max server memory" did not report "max server memory (MB)"'
		print 'Unable to continue'
		Return 50000;
	End
	
	SELECT @PhysicalMemory = total_physical_memory_kb/1024.0
	FROM sys.dm_os_sys_memory

	SELECT @MemoryInUse = physical_memory_in_use_kb/1024.0
	FROM sys.dm_os_process_memory

	SELECT @WastedMB = sum(cast((CASE
	                                 WHEN usecounts = 1 AND
	                                      objtype IN ('Adhoc', 'Prepared') THEN size_in_bytes
	                                 ELSE 0
	                             END) AS decimal(12, 2))) / 1024.0 / 1024,
	       @SingleUsePlanCount = sum(CASE
	                                     WHEN usecounts = 1 AND
	                                          objtype IN ('Adhoc', 'Prepared') THEN 1
	                                     ELSE 0
	                                 END),
	       @Percent = @WastedMB / @MemoryInUse * 100
	FROM sys.dm_exec_cached_plans

	SELECT @StrMB = CONVERT(varchar(20), @WastedMB),
		   @StrPercent = CONVERT(varchar(20), @Percent)

	IF @Percent > @MemoryUsageThresholdPercent OR @WastedMB > @MemoryUsageMBThreshold
		Set @ClearCache = 1
		
	If @InfoOnly <> 0
	Begin
		SELECT @PhysicalMemory AS [TotalPhysicalMemory (MB)],
		       @ConfiguredMemory AS [TotalConfiguredMemory (MB)],
		       @ConfiguredMemory / @PhysicalMemory * 100 AS [MaxMemoryAvailableToSQLServer (%)],
		       @MemoryInUse AS [MemoryInUseBySQLServer (MB)],
		       @WastedMB AS [TotalSingleUsePlanCache (MB)],
		       @SingleUsePlanCount AS TotalNumberOfSingleUsePlans,
		       @Percent AS [PercentOfConfiguredCacheWastedForSingleUsePlans (%)],
		       CASE WHEN @ClearCache = 0 THEN 'No' ELSE 'Yes' END AS [Need to Clear Cache?]
	End	

	If @ClearCache <> 0
	BEGIN
		DBCC FREESYSTEMCACHE('SQL Plans') 
		Set @message = @StrMB + ' MB (' + @StrPercent + '% total ram) was allocated to single-use plan cache. Single-use plans have been cleared.'
		Exec PostLogEntry 'Normal', @message, 'ClearQueryPlanCacheIfRequired'
	END
	Else
		Set @message = 'Only ' + @StrMB + ' MB (' + @StrPercent + '% total ram) is allocated to single-use plan cache - no need to clear cache now.'

	If @InfoOnly <> 0
		Print @message
	
Done:
	return 0


GO
GRANT VIEW DEFINITION ON [dbo].[ClearQueryPlanCacheIfRequired] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ClearQueryPlanCacheIfRequired] TO [MTS_DB_Lite] AS [dbo]
GO

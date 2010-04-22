/****** Object:  StoredProcedure [dbo].[ShrinkTempDBLogIfRequired] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE dbo.ShrinkTempDBLogIfRequired
/****************************************************
**
**	Desc:	Examines the size of the TempDB's log file
**			If larger than @LogSizeMBThreshold, then shrink's
**			the log file to 5% of @LogSizeMBThreshold (minimum 5 MB)
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	04/12/2006
**			01/30/2009 mem - Switched to using DBCC SHRINKDATABASE, which is compatible with Sql Server 2008
**			04/20/2009 mem - Now shrinking both the tempdev and the templog file
**
*****************************************************/
(
	@LogSizeMBThreshold real = 500,
	@InfoOnly tinyint = 0,
	@PostLogEntry tinyint = 1,				-- Posts an entry to the log if the Temp DB log is shrunk
	@message varchar(255) = ''
)
AS

	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @MinimumLogSizeMB int
	Set @MinimumLogSizeMB = 5

	-- Validate the inputs
	If IsNull(@LogSizeMBThreshold,0) < @MinimumLogSizeMB
		Set @LogSizeMBThreshold = @MinimumLogSizeMB

	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @PostLogEntry = IsNull(@PostLogEntry, 1)
	Set @message = ''

	-- Portions of this code are from Master..sp_spaceused
	declare @DBSizePages  decimal(15)
	declare @LogSizePages decimal(15)
	declare @BytesPerPage decimal(15,0)
	declare @PagesPerMB   decimal(15,0)

	declare @DBSizeMB real
	declare @LogSizeMB real

	declare @FinalSizeMB int
	declare @S varchar(1024)
	
	SELECT @DBSizePages = Sum(Convert(decimal(15), [size]))
	FROM tempdb.dbo.sysfiles
	WHERE (status & 64 = 0)

	SELECT @LogSizePages = Sum(Convert(decimal(15), [size]))
	FROM tempdb.dbo.sysfiles
	WHERE (status & 64 <> 0)

	SELECT @BytesPerPage = [low]
	FROM master.dbo.spt_values
	WHERE number = 1 AND type = 'E'

	Set @PagesPerMB = (1024*1024) / @BytesPerPage

	Set @DBSizeMB = @DBSizePages / @PagesPerMB
	Set @LogSizeMB = @LogSizePages / @PagesPerMB

	Set @message = 'TempDB Log Size is ' + Convert(varchar(12), Round(@LogSizeMB,0)) + ' MB'

	If @LogSizeMB >= @LogSizeMBThreshold
	Begin
		set @message = @message + '; truncating and shrinking log'

		-- This command worked in Sql Server 2005 but is no longer valid in Sql Server 2008
		--  since "TRUNCATE_ONLY" is no longer supported with the BACKUP command
		--  BACKUP LOG tempdb WITH TRUNCATE_ONLY
		
		DBCC SHRINKDATABASE(N'tempdb' )

		-- Set @FinalSizeMB to 5% of @LogSizeMBThreshold
		Set @FinalSizeMB = Convert(int, @LogSizeMBThreshold * 0.05)
		If @FinalSizeMB < @MinimumLogSizeMB
			Set @FinalSizeMB = @MinimumLogSizeMB

		Set @message = @message + ' to ' + convert(varchar(12), @FinalSizeMB) + ' MB'
		If @InfoOnly = 0
		Begin
			-- Shrink the Temp DB data file
			Set @S = ''
			Set @S = @S + ' USE TempDB'
			Set @S = @S + ' DBCC SHRINKFILE (tempdev, ' + Convert(varchar(12), @FinalSizeMB) + ')'
			
			Exec (@S)

			-- Shrink the Temp DB log file
			Set @S = ''
			Set @S = @S + ' USE TempDB'
			Set @S = @S + ' DBCC SHRINKFILE (templog, ' + Convert(varchar(12), @FinalSizeMB) + ')'
			
			Exec (@S)
			
			If @PostLogEntry <> 0
				execute PostLogEntry 'Normal', @message, 'ShrinkTempDBLogIfRequired'
		End
	End

	If @InfoOnly <> 0
		SELECT @message As LogInfo
		
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ShrinkTempDBLogIfRequired] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ShrinkTempDBLogIfRequired] TO [MTS_DB_Lite] AS [dbo]
GO

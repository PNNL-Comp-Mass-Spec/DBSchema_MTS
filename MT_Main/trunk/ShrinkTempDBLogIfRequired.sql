SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ShrinkTempDBLogIfRequired]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ShrinkTempDBLogIfRequired]
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

		BACKUP LOG tempdb WITH TRUNCATE_ONLY

		-- Set @FinalSizeMB to 5% of @LogSizeMBThreshold
		Set @FinalSizeMB = Convert(int, @LogSizeMBThreshold * 0.05)
		If @FinalSizeMB < @MinimumLogSizeMB
			Set @FinalSizeMB = @MinimumLogSizeMB

		Set @message = @message + ' to ' + convert(varchar(12), @FinalSizeMB) + ' MB'
		If @InfoOnly = 0
		Begin
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


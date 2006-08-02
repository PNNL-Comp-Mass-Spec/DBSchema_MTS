SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateSequenceModsForAvailableAnalyses]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateSequenceModsForAvailableAnalyses]
GO


CREATE Procedure dbo.UpdateSequenceModsForAvailableAnalyses
/****************************************************
**
**	Desc: 
**		Updates peptide sequence modifications for
**		all the peptides for the all the analyses with
**		Process_State = @ProcessStateMatch
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 11/2/2001
**
**		Updated 03/25/2004 mem - Changed "no analyses were available" to be status Normal instead of Error
**			    04/16/2004 mem - Switched from using a cursor to using a while loop
**				08/07/2004 mem - Changed to use of Process_State field for choosing next job
**				09/04/2004 mem - Added additional call to PostLogEntry
**				09/09/2004 mem - Tweaked the while loop logic
**				02/10/2005 mem - Now looking for jobs with one or more peptides mapped to Seq_ID 0
**				02/11/2005 mem - Switched to using UpdateSequenceModsForOneAnalysisBulk
**				11/10/2005 mem - Updated default value for @ProcessStateMatch to 25
**    
*****************************************************/
	@ProcessStateMatch int = 25,
	@NextProcessState int = 30,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @jobAvailable int
	set @jobAvailable = 0

	declare @firstJobFound int
	set @firstJobFound = 0
	
	declare @result int
	declare @message varchar(255)
	set @message = ''
	
	declare @Job int

	declare @count int
	set @count = 0

	----------------------------------------------
	-- Look for jobs that have 1 or more peptides with Seq_ID values = 0
	-- If present, reset to state @ProcessStateMatch and post an entry to the log
	----------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateMatch
	WHERE Process_State >= @NextProcessState AND
		  Job IN (	SELECT Analysis_ID
					FROM T_Peptides
					WHERE (Seq_ID = 0)
					GROUP BY Analysis_ID
					HAVING COUNT(Peptide_ID) > 0
				 )
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error looking for jobs with one or more Seq_ID values = 0'
		goto done
	end

	if @myRowCount > 0
	begin
		set @message = 'Found ' + convert(varchar(9), @myRowCount) + ' job(s) containing one or more peptides mapped to a Seq_ID value of 0; job state has been reset to ' + convert(varchar(9), @ProcessStateMatch)
		execute PostLogEntry 'Error', @message, 'UpdateSequenceModsForAvailableAnalyses'
		set @message = ''
	end


	----------------------------------------------
	-- Loop through T_Analysis_Description, processing jobs with Process_State = @ProcessStatematch
	----------------------------------------------
	Set @Job = 0
	set @jobAvailable = 1
	set @numJobsProcessed = 0
	
	while @jobAvailable > 0 and @myError = 0 and @numJobsProcessed < @numJobsToProcess
	begin
		-- Look up the next available job
		SELECT	TOP 1 @Job = Job
		FROM	T_Analysis_Description
		WHERE	Process_State = @ProcessStateMatch AND Job > @Job
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Error while reading next job from T_Analysis_Description'
			goto done
		end

		if @myRowCount <> 1
			Set @jobAvailable = 0
		else
		begin
			if @firstJobFound = 0
			begin
				-- Write entry to T_Log_Entries for the first job processed
				set @message = 'Starting sequence mods processing for job ' + convert(varchar(11), @job)
				execute PostLogEntry 'Normal', @message, 'UpdateSequenceModsForAvailableAnalyses'
				set @message = ''
				set @firstJobFound = 1
			end
						
			-- Job is available to process
			exec @result = UpdateSequenceModsForOneAnalysisBulk
									@NextProcessState,
									@job,
									@count output,
									@message output

			-- make log entry
			--
			if @result = 0
				execute PostLogEntry 'Normal', @message, 'UpdateSequenceModsForAvailableAnalyses'
			else
				execute PostLogEntry 'Error', @message, 'UpdateSequenceModsForAvailableAnalyses'
				
			-- check number of jobs processed
			--
			set @numJobsProcessed = @numJobsProcessed + 1
		end
	end

	if @numJobsProcessed = 0
		set @message = 'no analyses were available'

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


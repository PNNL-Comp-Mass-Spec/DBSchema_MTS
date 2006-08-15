/****** Object:  StoredProcedure [dbo].[UpdateMassTagsFromAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateMassTagsFromAvailableAnalyses
/****************************************************
** 
**	Desc: 
**		Gets list of LCQ analyses that are available
**		 to have their peptides processed for mass tags,
**		 and processes them.
**
**		Caller must assure that peptides satisfy
**		 a minimum score threshold 
**
**	Return values: 0: success, otherwise, error code
** 
**
**	Auth:	grk
**	Date:	10/09/2001
**			09/21/2004 mem - Updated to utilize the PDB_ID field in T_Analysis_Description
**			09/23/2005 mem - Updated to handle PDB_ID values of 0 or Null
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			03/13/2006 mem - Now calling UpdateCachedHistograms if any data is loaded
**    
*****************************************************/
(
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
)
As
	set nocount on
	
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @numJobsProcessed = 0
	
	declare @jobAvailable int
	set @jobAvailable = 0
	
	Declare @message varchar(255)
	set @message = ''
	
	declare @count int
	declare @result int
	declare @job int
	declare @PDB_ID int
	declare @UpdateEnabled tinyint
	
	declare @NumAddedPeptides int
	set @NumAddedPeptides = 0
	
	declare @PeptideDBName varchar(128)
	declare @PeptideDBIDCached int
	
	declare @availableState int
	set @availableState = 1 -- 'New' 

	-----------------------------------------------------------
	-- loop through all available analyses and process their peptides
	-----------------------------------------------------------
	--

	Set @Job = 0
	Set @jobAvailable = 1
	Set @PeptideDBName = ''
	Set @PeptideDBIDCached = -1
	
	While @jobAvailable > 0 and @myError = 0 and @numJobsProcessed < @numJobsToProcess
	Begin -- <a>
		
		-----------------------------------------------------------
		-- get next available analysis
		-- If PDB_ID is Null then @PDB_ID will = 0
		-----------------------------------------------------------
		--
		Set @PDB_ID = 0
		--
		SELECT TOP 1 @job = Job, @PDB_ID = IsNull(PDB_ID, 0)
		FROM T_Analysis_Description
		WHERE State = @availableState AND Job > @job
		ORDER BY Job ASC
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
		begin -- <b>
			
			If @PDB_ID = 0
			Begin
				-- Job has a value of 0 or Null for PDB_ID
				-- This is the case in speciality DBs
				-- Post a warning message to the log then update the job's state to 7
				
				set @message = 'Warning: Job ' + convert(varchar(11), @Job) + ' has a value of 0 or Null for PDB_ID in T_Analysis_Description; advancing job state to 7'
				execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
				set @message = ''
				
				UPDATE T_Analysis_Description
				SET State = 7
				WHERE Job = @job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
			End
			Else
			Begin
				If @PeptideDBIDCached = -1 OR @PeptideDBIDCached <> @PDB_ID
				Begin
					-----------------------------------------------------------
					-- Lookup the peptide DB Name corresponding to PDB_ID
					-----------------------------------------------------------
					--
					SELECT @PeptideDBIDCached = PDB_ID, @PeptideDBName = PDB_Name
					FROM MT_Main..T_Peptide_Database_List
					WHERE PDB_ID = @PDB_ID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					if @myError <> 0 
					begin
						set @message = 'Error while reading next job from T_Analysis_Description'
						goto done
					end
					--
					if @myRowCount <> 1
					begin
						set @message = 'Peptide database not found in MT_Main for job ' + convert(varchar(11), @Job) + '; PDB_ID ' + convert(varchar(11), @PDB_ID)
						execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
						set @message = ''
						set @PeptideDBIDCached = -1
					end
				End
				
				if @PeptideDBIDCached <> -1 and @PeptideDBIDCached = @PDB_ID
				begin
					-----------------------------------------------------------
					-- import peptides for the job
					-----------------------------------------------------------
					--
					exec @result = UpdateMassTagsFromOneAnalysis @job, @PeptideDBName, @count output, @message output

					Set @NumAddedPeptides = @NumAddedPeptides + @count
					
					-- make log entry
					--
					if @result = 0
						execute PostLogEntry 'Normal', @message, 'UpdateMassTagsFromAvailableAnalyses'
					else
						execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
					
				end
			End
			
			-- increment number of jobs processed
			--
			set @numJobsProcessed = @numJobsProcessed + 1

		end -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateMassTagsFromAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done
		
	End -- </a>

	-----------------------------------------------------------
	-- Update the Analysis counts and High_Normalized_Score values in T_Mass_Tags
	-----------------------------------------------------------
	If @NumAddedPeptides > 0
	Begin
		Exec UpdateCachedHistograms @InvalidateButDoNotProcess=1
		Exec ComputeMassTagsAnalysisCounts
	End

Done:
	return @myError


GO

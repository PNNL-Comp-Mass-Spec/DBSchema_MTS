SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RefreshMSMSSICStats]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RefreshMSMSSICStats]
GO


CREATE Procedure dbo.RefreshMSMSSICStats
/****************************************************
**
**	Desc: 
**		Finds jobs that have null selected ion chromatogram (SIC)
**		values in T_Peptides and update with new values from the
**		peptide database.
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 09/02/2005 mem - This SP is modelled after RefreshMSMSJobNETs
**			  10/02/2005 mem - Updated to obtain the data from T_Peptides in the Peptide DB since that table now contains the SIC related values
**			  10/12/2005 mem - Now calling ComputeMaxObsAreaByJob to populate Max_Obs_Area_In_Job
**			  12/01/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**							 - Increased size of @peptideDBName from 64 to 128 characters
**    
*****************************************************/
 	@jobsUpdated int = 0 output,
 	@peptideRowsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList as varchar(1024) = '',
 	@infoOnly tinyint = 0
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @infoOnly = IsNull(@infoOnly, 0)
	set @jobsUpdated = 0
	set @peptideRowsUpdated = 0
	set @message = ''

	declare @result int
	set @result = 0
		
	declare @peptideDBName varchar(128)
	declare @peptideDBID int
	declare @jobCountToUpdate int
	
	set @peptideDBName = ''

	declare @S nvarchar(4000)
	declare @continue tinyint

	---------------------------------------------------
	-- Create two temporary tables
	---------------------------------------------------
	--
	CREATE TABLE #T_Peptide_Database_List (
		PeptideDBName varchar(128) NOT NULL,
		PDB_ID int
	)


	CREATE TABLE #T_Jobs_To_Update (
		Job int NOT NULL
	)

	---------------------------------------------------
	-- Get peptide database name(s)
	---------------------------------------------------
	--
	INSERT INTO #T_Peptide_Database_List (PeptideDBName, PDB_ID)
	SELECT DISTINCT PDL.PDB_Name, PDL.PDB_ID
	FROM MT_Main.dbo.T_Peptide_Database_List AS PDL INNER JOIN
		T_Analysis_Description AS TAD ON 
		PDL.PDB_ID = TAD.PDB_ID
	WHERE NOT (PDL.PDB_Name IS NULL)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount < 1
	begin
		set @message = 'No analyses with valid peptide DBs were found'
		set @myError = 0
		goto Done
	end


	---------------------------------------------------
	-- Loop through peptide database(s) and look for jobs
	-- that need to be updated
	---------------------------------------------------
	--

	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @peptideDBName = PeptideDBName, @peptideDBID = PDB_ID
		FROM #T_Peptide_Database_List
		ORDER BY PeptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>

			TRUNCATE TABLE #T_Jobs_To_Update
			set @jobCountToUpdate = 0
			
	
			-- Look for jobs with undefined Scan_Time_Peak_Apex values,
			-- Peak_Area values, or Peak_SN_Ratio values, yet 
			-- available values in the peptide DB
			set @S = ''
			set @S = @S + ' INSERT INTO #T_Jobs_To_Update (Job)'
			set @S = @S + ' SELECT LookupQ.Job'
			set @S = @S + ' FROM (SELECT TAD.Job,'
			set @S = @S + '   COUNT(TP.Peptide_ID) AS NullInfoCount'
			set @S = @S + '   FROM T_Analysis_Description AS TAD INNER JOIN'
			set @S = @S + '     T_Peptides AS TP ON TAD.Job = TP.Analysis_ID'
			set @S = @S + '   WHERE TAD.State > 1 AND ('
			set @S = @S + '     TP.Scan_Time_Peak_Apex IS NULL OR TP.Peak_Area IS NULL OR TP.Peak_SN_Ratio IS NULL)'
			set @S = @S + '   GROUP BY TAD.Job'
			set @S = @S + '   ) LookupQ INNER JOIN '
			set @S = @S +   ' [' + @peptideDBName + '].dbo.V_SIC_Job_to_PeptideHit_Map JobMap ON '
			set @S = @S + '   LookupQ.Job = JobMap.Job LEFT OUTER JOIN #T_Jobs_To_Update'
			set @S = @S + '   ON LookupQ.Job = #T_Jobs_To_Update.Job'
			set @S = @S + ' WHERE (LookupQ.NullInfoCount > 0) AND #T_Jobs_To_Update.Job IS NULL'

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND LookupQ.Job In (' + @JobFilterList + ')'

			exec @result = sp_executesql @S
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			set @jobCountToUpdate = @jobCountToUpdate + @myRowCount
			--
			if @myError <> 0
			begin
				set @message = 'Error comparing jobs to those in ' + @peptideDBName + ', Scan_Time values'
				goto Done
			end

			
			---------------------------------------------------
			-- Remove peptide DB from #T_Peptide_Database_List
			---------------------------------------------------
			DELETE FROM #T_Peptide_Database_List
			WHERE PDB_ID = @peptideDBID 
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--

			
			if @jobCountToUpdate > 0
			Begin -- <c>
				
		
				---------------------------------------------------
				-- Update missing Scan_Time_Peak_Apex values for the appropriate jobs
				---------------------------------------------------
				--
				set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					set @S = @S + 'SELECT JTU.Job, Count(TP.Peptide_ID) AS Peptide_Rows_To_Update'
				End
				Else
				Begin
					set @S = @S + 'UPDATE TP'
					set @S = @S + ' SET Scan_Time_Peak_Apex = PepTP.Scan_Time_Peak_Apex,'
					set @S = @S +     ' Peak_Area = PepTP.Peak_Area,'
					set @S = @S +     ' Peak_SN_Ratio = PepTP.Peak_SN_Ratio'
				End

				set @S = @S + ' FROM #T_Jobs_To_Update AS JTU INNER JOIN'
				set @S = @S +      ' T_Peptides AS TP ON JTU.Job = TP.Analysis_ID INNER JOIN '
				set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Peptides AS PepTP ON '
				set @S = @S +      ' TP.Analysis_ID = PepTP.Analysis_ID AND'
				set @S = @S +      ' TP.Scan_Number = PepTP.Scan_Number AND'
				set @S = @S +      ' TP.Number_Of_Scans = PepTP.Number_Of_Scans AND'
				set @S = @S +      ' TP.Charge_State = PepTP.Charge_State AND'
				set @S = @S +      ' TP.Mass_Tag_ID = PepTP.Seq_ID'

				/* 
				** Use the following to grab the data directly from T_Dataset_Stats_SIC and T_Dataset_Stats_Scans
				set @S = @S + ' FROM #T_Jobs_To_Update AS JTU INNER JOIN'
				set @S = @S + '   T_Peptides AS TP ON JTU.Job = TP.Analysis_ID INNER JOIN '
				set @S = @S +   ' [' + @peptideDBName + '].dbo.V_SIC_Job_to_PeptideHit_Map AS JobMap ON '
				set @S = @S + '   JTU.Job = JobMap.Job INNER JOIN '
				set @S = @S +   ' [' + @peptideDBName + '].dbo.T_Dataset_Stats_Scans AS DSS WITH (NOLOCK) ON '
				set @S = @S + '   JobMap.SIC_Job = DSS.Job INNER JOIN '
				set @S = @S +   ' [' + @peptideDBName + '].dbo.T_Dataset_Stats_SIC AS DSSIC WITH (NOLOCK) ON '
				set @S = @S + '   JobMap.SIC_Job = DSSIC.Job AND '
				set @S = @S + '   TP.Scan_Number = DSSIC.Frag_Scan_Number AND '
				set @S = @S + '   DSS.Scan_Number = DSSIC.Optimal_Peak_Apex_Scan_Number'
				*/

				If @infoOnly <> 0
				Begin
					set @S = @S + ' GROUP BY JTU.Job'
					set @S = @S + ' ORDER BY JTU.Job'
				End

				exec @result = sp_executesql @S
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					set @message = 'Error updating peptide Scan_Time_Peak_Apex, Peak_Area, and Peak_SN_Ratio values using ' + @peptideDBName
					goto Done
				end
					
				Set @peptideRowsUpdated = @peptideRowsUpdated + @myRowCount


				---------------------------------------------------
				-- Reset Max_Obs_Area_In_Job to 0 for the given jobs
				-- It will be repopulated below
				---------------------------------------------------
				--
				UPDATE T_Peptides
				SET Max_Obs_Area_In_Job = 0
				FROM T_Peptides INNER JOIN #T_Jobs_To_Update AS JTU ON
					 T_Peptides.Analysis_ID = JTU.Job 
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				---------------------------------------------------
				-- Increment @jobsUpdated
				---------------------------------------------------

				Set @jobsUpdated = @jobsUpdated + @jobCountToUpdate
				
			End -- </c>
		
		End -- </b>
	End -- </a>


	If @infoOnly = 0
	Begin
		---------------------------------------------------
		-- Compute the value for Max_Obs_Area_In_Job for the given jobs
		-- Values for jobs in #T_Jobs_To_Update will have been reset to 0 above,
		--  causing them to be processed by ComputeMaxObsAreaByJob
		-- Note that ComputeMaxObsAreaByJob will also look for other jobs where
		--  Max_Obs_Area_In_Job is 0 for all peptides in the job
		---------------------------------------------------
		--
		Exec @result = ComputeMaxObsAreaByJob @PostLogEntryOnSuccess = 1
	End
		    
	
	If @jobsUpdated > 0 and @infoOnly = 0
	Begin
		-- Make sure the MSMS Processing will occur on the next master update
		UPDATE T_Process_Step_Control
		SET Enabled = 1
		WHERE Processing_Step_Name = 'ForceLCQProcessingOnNextUpdate'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			set @message = 'Error refreshing SIC Stats, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSSICStats'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			set @message = 'SIC Stats refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs and ' + convert(varchar(12), @peptideRowsUpdated) + ' peptide rows'
			If @infoOnly <> 0
			Begin
				set @message = 'InfoOnly: ' + @message
				Select @message AS RefreshMSMSSICStats_Message
			End
			Else
				execute PostLogEntry 'Normal', @message, 'RefreshMSMSSICStats'
		End
		Else
		Begin
			If @infoOnly <> 0
				Select 'InfoOnly: No jobs needing to be updated were found' As RefreshMSMSSICStats_Message
		End
	End
	
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


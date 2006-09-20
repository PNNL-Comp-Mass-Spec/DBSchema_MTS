/****** Object:  StoredProcedure [dbo].[RefreshMSMSSICStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**	Auth:	mem
**	Date:	09/02/2005 mem - This SP is modelled after RefreshMSMSJobNETs
**			10/02/2005 mem - Updated to obtain the data from T_Peptides in the Peptide DB since that table now contains the SIC related values
**			10/12/2005 mem - Now calling ComputeMaxObsAreaByJob to populate Max_Obs_Area_In_Job
**			12/01/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**						   - Increased size of @peptideDBName from 64 to 128 characters
**			09/19/2006 mem - Added support for peptide DBs being located on a separate MTS server, utilizing MT_Main.dbo.PopulatePeptideDBLocationTable to determine DB location given Peptide DB ID
**    
*****************************************************/
(
 	@jobsUpdated int = 0 output,
 	@peptideRowsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(1024) = '',
 	@infoOnly tinyint = 0
)
As
	Set nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @jobsUpdated = 0
	Set @peptideRowsUpdated = 0
	Set @message = ''

	Declare @result int
	Set @result = 0

	Declare @PeptideDBPath varchar(256)		-- Switched from @peptideDBName to @PeptideDBPath on 9/19/2006
	Declare @PeptideDBID int
	Declare @jobCountToUpdate int

	Declare @PeptideDBCountInvalid int
	Declare @InvalidDBList varchar(1024)

	Declare @S nvarchar(4000)
	Declare @continue tinyint

	---------------------------------------------------
	-- Create two temporary tables
	---------------------------------------------------
	--
	CREATE TABLE #T_Peptide_Database_List (
		PeptideDBName varchar(128) NULL,
		PeptideDBID int NULL,
		PeptideDBServer varchar(128) NULL,
		PeptideDBPath varchar(256) NULL
	)

	CREATE TABLE #T_Jobs_To_Update (
		Job int NOT NULL
	)

	---------------------------------------------------
	-- Populate #T_Peptide_Database_List with the PDB_ID values
	-- defined in T_Analysis_Description
	---------------------------------------------------
	--
	INSERT INTO #T_Peptide_Database_List (PeptideDBID)
	SELECT DISTINCT PDB_ID
	FROM T_Analysis_Description TAD
	WHERE NOT PDB_ID IS NULL
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount < 1
	begin
		Set @message = 'No analyses with valid peptide DB IDs were found'
		Set @myError = 0
		goto Done
	end

	---------------------------------------------------
	-- Determine the name and server for each Peptide DB in #T_Peptide_Database_List
	---------------------------------------------------
	--
	exec @myError = MT_Main.dbo.PopulatePeptideDBLocationTable @PreferDBName = 0, @message = @message output

	If @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling MT_Main.dbo.PopulatePeptideDBLocationTable'
		
		Set @message = @message + '; Error Code ' + Convert(varchar(12), @myError)
		Goto Done
	End
	
	Set @PeptideDBCountInvalid = 0
	SELECT @PeptideDBCountInvalid = COUNT(*)
	FROM #T_Peptide_Database_List
	WHERE PeptideDBName Is Null

	If @PeptideDBCountInvalid > 0
	Begin -- <a>
		-- One or more DBs in #T_Peptide_Database_List are unknown
		-- Construct a comma-separated list, post a log entry, 
		--  and delete the invalid databases from #T_Peptide_Database_List
		
		Set @InvalidDBList = ''
		SELECT @InvalidDBList = @InvalidDBList + PeptideDBID + ','
		FROM #T_Peptide_Database_List
		WHERE PeptideDBName Is Null
		ORDER BY PeptideDBID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount > 0
		Begin
			-- Remove the trailing comma
			Set @InvalidDBList = Left(@InvalidDBList, Len(@InvalidDBList)-1)
			
			Set @message = 'Invalid peptide DB ID'
			If @myRowCount > 1
				Set @message = @message + 's'
				
			Set @message = @message + ' defined in T_Analysis_Description: ' + @InvalidDBList
			execute PostLogEntry 'Error', @message, 'RefreshMSMSSICStats'
			Set @message = ''
			
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBName Is Null
		End
	End
	
	---------------------------------------------------
	-- Loop through peptide database(s) and look for jobs
	-- that need to be updated
	---------------------------------------------------
	--

	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		Set @PeptideDBPath = ''

		SELECT TOP 1 @PeptideDBPath = PeptideDBPath,
					 @PeptideDBID = PeptideDBID
		FROM #T_Peptide_Database_List
		ORDER BY PeptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>

			TRUNCATE TABLE #T_Jobs_To_Update
			Set @jobCountToUpdate = 0
			
	
			-- Look for jobs with undefined Scan_Time_Peak_Apex values,
			-- Peak_Area values, or Peak_SN_Ratio values, yet 
			-- available values in the peptide DB
			Set @S = ''
			Set @S = @S + ' INSERT INTO #T_Jobs_To_Update (Job)'
			Set @S = @S + ' SELECT LookupQ.Job'
			Set @S = @S + ' FROM (SELECT TAD.Job,'
			Set @S = @S + '   COUNT(TP.Peptide_ID) AS NullInfoCount'
			Set @S = @S + '   FROM T_Analysis_Description AS TAD INNER JOIN'
			Set @S = @S + '     T_Peptides AS TP ON TAD.Job = TP.Analysis_ID'
			Set @S = @S + '   WHERE TAD.State > 1 AND ('
			Set @S = @S + '     TP.Scan_Time_Peak_Apex IS NULL OR TP.Peak_Area IS NULL OR TP.Peak_SN_Ratio IS NULL)'
			Set @S = @S + '   GROUP BY TAD.Job'
			Set @S = @S + '   ) LookupQ INNER JOIN '
			Set @S = @S +   ' ' + @PeptideDBPath + '.dbo.V_SIC_Job_to_PeptideHit_Map JobMap ON '
			Set @S = @S + '   LookupQ.Job = JobMap.Job LEFT OUTER JOIN #T_Jobs_To_Update'
			Set @S = @S + '   ON LookupQ.Job = #T_Jobs_To_Update.Job'
			Set @S = @S + ' WHERE (LookupQ.NullInfoCount > 0) AND #T_Jobs_To_Update.Job IS NULL'

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND LookupQ.Job In (' + @JobFilterList + ')'

			exec @result = sp_executesql @S
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			Set @jobCountToUpdate = @jobCountToUpdate + @myRowCount
			--
			if @myError <> 0
			begin
				Set @message = 'Error comparing jobs to those in ' + @PeptideDBPath + ', Scan_Time values'
				goto Done
			end

			
			---------------------------------------------------
			-- Remove peptide DB from #T_Peptide_Database_List
			---------------------------------------------------
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBID = @PeptideDBID 
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--

			
			if @jobCountToUpdate > 0
			Begin -- <c>
				
		
				---------------------------------------------------
				-- Update missing Scan_Time_Peak_Apex values for the appropriate jobs
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + 'SELECT JTU.Job, Count(TP.Peptide_ID) AS Peptide_Rows_To_Update'
				End
				Else
				Begin
					Set @S = @S + 'UPDATE TP'
					Set @S = @S + ' Set Scan_Time_Peak_Apex = PepTP.Scan_Time_Peak_Apex,'
					Set @S = @S +     ' Peak_Area = PepTP.Peak_Area,'
					Set @S = @S +     ' Peak_SN_Ratio = PepTP.Peak_SN_Ratio'
				End

				Set @S = @S + ' FROM #T_Jobs_To_Update AS JTU INNER JOIN'
				Set @S = @S +      ' T_Peptides AS TP ON JTU.Job = TP.Analysis_ID INNER JOIN '
				Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Peptides AS PepTP ON '
				Set @S = @S +      ' TP.Analysis_ID = PepTP.Analysis_ID AND'
				Set @S = @S +      ' TP.Scan_Number = PepTP.Scan_Number AND'
				Set @S = @S +      ' TP.Number_Of_Scans = PepTP.Number_Of_Scans AND'
				Set @S = @S +      ' TP.Charge_State = PepTP.Charge_State AND'
				Set @S = @S +      ' TP.Mass_Tag_ID = PepTP.Seq_ID'

				/* 
				** Use the following to grab the data directly from T_Dataset_Stats_SIC and T_Dataset_Stats_Scans
				Set @S = @S + ' FROM #T_Jobs_To_Update AS JTU INNER JOIN'
				Set @S = @S + '   T_Peptides AS TP ON JTU.Job = TP.Analysis_ID INNER JOIN '
				Set @S = @S +   ' ' + @PeptideDBPath + '.dbo.V_SIC_Job_to_PeptideHit_Map AS JobMap ON '
				Set @S = @S + '   JTU.Job = JobMap.Job INNER JOIN '
				Set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Dataset_Stats_Scans AS DSS WITH (NOLOCK) ON '
				Set @S = @S + '   JobMap.SIC_Job = DSS.Job INNER JOIN '
				Set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Dataset_Stats_SIC AS DSSIC WITH (NOLOCK) ON '
				Set @S = @S + '   JobMap.SIC_Job = DSSIC.Job AND '
				Set @S = @S + '   TP.Scan_Number = DSSIC.Frag_Scan_Number AND '
				Set @S = @S + '   DSS.Scan_Number = DSSIC.Optimal_Peak_Apex_Scan_Number'
				*/

				If @infoOnly <> 0
				Begin
					Set @S = @S + ' GROUP BY JTU.Job'
					Set @S = @S + ' ORDER BY JTU.Job'
				End

				exec @result = sp_executesql @S
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					Set @message = 'Error updating peptide Scan_Time_Peak_Apex, Peak_Area, and Peak_SN_Ratio values using ' + @PeptideDBPath
					goto Done
				end
					
				Set @peptideRowsUpdated = @peptideRowsUpdated + @myRowCount


				If @infoOnly = 0
				Begin
					---------------------------------------------------
					-- Reset Max_Obs_Area_In_Job to 0 for the given jobs
					-- It will be repopulated below
					---------------------------------------------------
					--
					UPDATE T_Peptides
					Set Max_Obs_Area_In_Job = 0
					FROM T_Peptides INNER JOIN #T_Jobs_To_Update AS JTU ON
						T_Peptides.Analysis_ID = JTU.Job 
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				End
				
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
		Set Enabled = 1
		WHERE Processing_Step_Name = 'ForceLCQProcessingOnNextUpdate'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error refreshing SIC Stats, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSSICStats'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			Set @message = 'SIC Stats refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs and ' + convert(varchar(12), @peptideRowsUpdated) + ' peptide rows'
			If @infoOnly <> 0
			Begin
				Set @message = 'InfoOnly: ' + @message
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

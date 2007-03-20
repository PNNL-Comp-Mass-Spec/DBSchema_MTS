/****** Object:  StoredProcedure [dbo].[RefreshMSMSJobNETs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE Procedure dbo.RefreshMSMSJobNETs
/****************************************************
**
**	Desc: 
**		Finds jobs that have differing GANET slope,
**		intercept, or fit values from the associated
**		peptide database.  For each, updates the 
**		values in T_Analysis_Description and GANET_Obs
**		in T_Peptides
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	10/15/2004
**			11/28/2004 mem - Added column GANET_RSquared
**			01/23/2005 mem - Added ScanTime_NET columns and optional population of T_Peptides.Scan_Time_Peak_Apex
**			01/28/2005 mem - Now updating T_Score_Discriminant when any NET values are updated
**			02/12/2005 mem - Now setting ForceLCQProcessingOnNextUpdate to 1 in T_Process_Step_Control if any jobs are updated; this is needed to guarantee that ComputeMassTagsGANET will be updated
**			02/23/2005 mem - Fixed bug that skipped rows in T_Peptides with null GANET_Obs values and rows in T_Score_Discriminant with null discriminant score values
**			09/02/2005 mem - Now posting entry to T_Log_Entries if any jobs are updated
**			10/04/2005 mem - Removed parameter @UpdateScanTimeValues and switched to always update Scan_Time_Peak_Apex since this value is now available in T_Peptides in the peptide DB
**			10/12/2005 mem - Added parameter @PostLogEntryOnSuccess
**			12/01/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**						   - Increased size of @peptideDBName from 64 to 128 characters
**			09/19/2006 mem - Added support for peptide DBs being located on a separate MTS server, utilizing MT_Main.dbo.PopulatePeptideDBLocationTable to determine DB location given Peptide DB ID
**			12/14/2006 mem - Updated @PostLogEntryOnSuccess to 1 and switched from using exec sp_executesql @S to Exec (@S)
**    
*****************************************************/
(
 	@jobsUpdated int = 0 output,
 	@peptideRowsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(1024) = '',
 	@infoOnly tinyint = 0,
 	@PostLogEntryOnSuccess tinyint = 1
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
			execute PostLogEntry 'Error', @message, 'RefreshMSMSJobNETs'
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
			
			Set @S = ''
			Set @S = @S + 'INSERT INTO #T_Jobs_To_Update (Job)'
			Set @S = @S + ' SELECT TAD.Job'
			Set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN '
			Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Analysis_Description AS PepTAD ON '
			Set @S = @S + ' 	TAD.Job = PepTAD.Job'
			Set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(nvarchar(21), @PeptideDBID) + ' AND'
			Set @S = @S + '    ('
			Set @S = @S + '  (IsNull(TAD.GANET_Fit, 0) <> IsNull(PepTAD.GANET_Fit, 0)) OR'
			Set @S = @S + '  (IsNull(TAD.GANET_Slope, 0) <> IsNull(PepTAD.GANET_Slope, 0)) OR'
			Set @S = @S + '  (IsNull(TAD.GANET_Intercept, 0) <> IsNull(PepTAD.GANET_Intercept, 0)) OR'
			Set @S = @S + '  (IsNull(TAD.GANET_RSquared, 0) <> IsNull(PepTAD.GANET_RSquared, 0)) OR'
			Set @S = @S + '  (IsNull(TAD.ScanTime_NET_Slope, 0) <> IsNull(PepTAD.ScanTime_NET_Slope, 0)) OR'
			Set @S = @S + '  (IsNull(TAD.ScanTime_NET_Intercept, 0) <> IsNull(PepTAD.ScanTime_NET_Intercept, 0)) OR'
			Set @S = @S + '  (IsNull(TAD.ScanTime_NET_Fit, 0) <> IsNull(PepTAD.ScanTime_NET_Fit, 0)) OR'
			Set @S = @S + '  (IsNull(TAD.ScanTime_NET_RSquared, 0) <> IsNull(PepTAD.ScanTime_NET_RSquared, 0))'
			Set @S = @S + '    )'

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND TAD.Job In (' + @JobFilterList + ')'

			exec @result = sp_executesql @S
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			Set @jobCountToUpdate = @jobCountToUpdate + @myRowCount
			--
			if @myError <> 0
			begin
				Set @message = 'Error comparing jobs to those in ' + @PeptideDBPath + ', examining NET values'
				goto Done
			end

			-- Look for jobs with undefined Scan_Time_Peak_Apex values, 
			-- but available Scan_Time info in the peptide DB
			Set @S = ''
			Set @S = @S + ' INSERT INTO #T_Jobs_To_Update (Job)'
			Set @S = @S + ' SELECT LookupQ.Job'
			Set @S = @S + ' FROM (SELECT TAD.Job,'
			Set @S = @S +              ' COUNT(TP.Peptide_ID) AS NullScanTimeCount'
			Set @S = @S +    ' FROM T_Analysis_Description AS TAD INNER JOIN'
			Set @S = @S + ' T_Peptides AS TP ON TAD.Job = TP.Analysis_ID'
			Set @S = @S +              ' WHERE TP.Scan_Time_Peak_Apex IS NULL AND TAD.State > 1'
			Set @S = @S +              ' GROUP BY TAD.Job'
			Set @S = @S +      ' ) LookupQ INNER JOIN '
			Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.V_SIC_Job_to_PeptideHit_Map JobMap ON '
			Set @S = @S + '   LookupQ.Job = JobMap.Job LEFT OUTER JOIN #T_Jobs_To_Update'
			Set @S = @S + '   ON LookupQ.Job = #T_Jobs_To_Update.Job'
			Set @S = @S + ' WHERE (LookupQ.NullScanTimeCount > 0) AND #T_Jobs_To_Update.Job IS NULL'

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
				-- Update the peptides for the appropriate jobs
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
					Set @S = @S + ' Set GANET_Obs = PepTP.GANET_Obs,'
					Set @S = @S +     ' Scan_Time_Peak_Apex = PepTP.Scan_Time_Peak_Apex'
				End

				Set @S = @S + ' FROM T_Peptides AS TP INNER JOIN '
				Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Peptides AS PepTP ON'
				Set @S = @S +      ' TP.Analysis_ID = PepTP.Analysis_ID AND'
				Set @S = @S +      ' TP.Scan_Number = PepTP.Scan_Number AND'
				Set @S = @S +      ' TP.Number_Of_Scans = PepTP.Number_Of_Scans AND'
				Set @S = @S +      ' TP.Charge_State = PepTP.Charge_State AND'
				Set @S = @S +      ' TP.Mass_Tag_ID = PepTP.Seq_ID AND'
				Set @S = @S +      ' (IsNull(TP.GANET_Obs,0) <> PepTP.GANET_Obs OR'
				Set @S = @S +       ' IsNull(TP.Scan_Time_Peak_Apex,0) <> PepTP.Scan_Time_Peak_Apex)'
				Set @S = @S +      ' INNER JOIN #T_Jobs_To_Update AS JTU ON TP.Analysis_ID = JTU.Job'
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
					Set @message = 'Error updating peptide GANET_Obs values using ' + @PeptideDBPath
					goto Done
				end
					
				Set @peptideRowsUpdated = @peptideRowsUpdated + @myRowCount


				---------------------------------------------------
				-- Update the discriminant score values for the appropriate jobs
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + 'SELECT JTU.Job, Count(SD.Peptide_ID) AS Peptide_Rows_To_Update'
				End
				Else
				Begin
					Set @S = @S + 'UPDATE SD'
					Set @S = @S + ' Set DiscriminantScore = PepSD.DiscriminantScore, '
					Set @S = @S +     ' DiscriminantScoreNorm = PepSD.DiscriminantScoreNorm'
				End
			
				Set @S = @S + ' FROM T_Peptides AS TP INNER JOIN '
				Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Peptides AS PepTP ON '
				Set @S = @S +      ' TP.Analysis_ID = PepTP.Analysis_ID AND '
				Set @S = @S +      ' TP.Scan_Number = PepTP.Scan_Number AND '
				Set @S = @S +      ' TP.Number_Of_Scans = PepTP.Number_Of_Scans AND '
				Set @S = @S +      ' TP.Charge_State = PepTP.Charge_State AND '
				Set @S = @S +      ' TP.Mass_Tag_ID = PepTP.Seq_ID INNER JOIN'
				Set @S = @S +      ' T_Score_Discriminant AS SD ON '
				Set @S = @S +      ' TP.Peptide_ID = SD.Peptide_ID INNER JOIN '
				Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Score_Discriminant AS PepSD ON '
				Set @S = @S +      ' PepTP.Peptide_ID = PepSD.Peptide_ID AND '
				Set @S = @S +      ' (IsNull(SD.DiscriminantScore,0) <> PepSD.DiscriminantScore OR '
				Set @S = @S +       ' IsNull(SD.DiscriminantScoreNorm,0) <> PepSD.DiscriminantScoreNorm)'
				Set @S = @S +      ' INNER JOIN #T_Jobs_To_Update AS JTU ON TP.Analysis_ID = JTU.Job'

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
					Set @message = 'Error updating peptide Discriminant Score values using ' + @PeptideDBPath
					goto Done
				end

				---------------------------------------------------
				-- Update the GANET values for these jobs
				---------------------------------------------------
				--
				Set @S = ''
				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + 'SELECT TAD.Job,'
					Set @S = @S + ' TAD.GANET_Fit, PTAD.GANET_Fit AS Fit_In_PeptideDB,'
					Set @S = @S + ' TAD.GANET_Slope, PTAD.GANET_Slope AS Slope_In_PeptideDB, '
					Set @S = @S + ' TAD.GANET_Intercept, PTAD.GANET_Intercept AS Intercept_In_PeptideDB, '
					Set @S = @S + ' TAD.GANET_RSquared, PTAD.GANET_RSquared AS RSquared_In_PeptideDB,'
					Set @S = @S + ' TAD.ScanTime_NET_Slope, PTAD.ScanTime_NET_Slope AS Slope_In_PeptideDB, '
					Set @S = @S + ' TAD.ScanTime_NET_Intercept, PTAD.ScanTime_NET_Intercept AS Intercept_In_PeptideDB, '
					Set @S = @S + ' TAD.ScanTime_NET_RSquared, PTAD.ScanTime_NET_RSquared AS RSquared_In_PeptideDB,'
					Set @S = @S + ' TAD.ScanTime_NET_Fit, PTAD.ScanTime_NET_Fit AS Fit_In_PeptideDB'
				End
				Else
				Begin
					Set @S = @S + 'UPDATE T_Analysis_Description'
					Set @S = @S + ' Set GANET_Fit = PTAD.GANET_Fit,'
					Set @S = @S + '	    GANET_Slope = PTAD.GANET_Slope,'
					Set @S = @S + '	    GANET_Intercept = PTAD.GANET_Intercept,'
					Set @S = @S + '	    GANET_RSquared = PTAD.GANET_RSquared,'
					Set @S = @S + '     ScanTime_NET_Fit = PTAD.ScanTime_NET_Fit,'
					Set @S = @S + '	    ScanTime_NET_Slope = PTAD.ScanTime_NET_Slope,'
					Set @S = @S + '	    ScanTime_NET_Intercept = PTAD.ScanTime_NET_Intercept,'
					Set @S = @S + '	    ScanTime_NET_RSquared = PTAD.ScanTime_NET_RSquared'
				End

				Set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN'
				Set @S = @S + '	    #T_Jobs_To_Update AS JTU ON TAD.JOB = JTU.Job INNER JOIN '
				Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Analysis_Description AS PTAD ON'
				Set @S = @S + '	    TAD.Job = PTAD.Job'

				If @infoOnly <> 0
				Begin
					Set @S = @S + ' ORDER BY TAD.Job'
				End

				exec @result = sp_executesql @S
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					Set @message = 'Error updating job GANETs using ' + @PeptideDBPath
					goto Done
				end

				---------------------------------------------------
				-- Increment @jobsUpdated
				---------------------------------------------------

				Set @jobsUpdated = @jobsUpdated + @jobCountToUpdate
				
			End -- </c>
		
		End -- </b>
	End -- </a>

	
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
			Set @message = 'Error refreshing Job GANETs, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSJobNETs'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			Set @message = 'Job GANETs refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs and ' + convert(varchar(12), @peptideRowsUpdated) + ' peptide rows'
			If @infoOnly <> 0
			Begin
				Set @message = 'InfoOnly: ' + @message
				Select @message AS RefreshMSMSJobNETs_Message
			End
			Else
			Begin
				If @PostLogEntryOnSuccess <> 0
					execute PostLogEntry 'Normal', @message, 'RefreshMSMSJobNETs'
			End
		End
		Else
		Begin
			If @infoOnly <> 0
				Select 'InfoOnly: No jobs needing to be updated were found' As RefreshMSMSJobNETs_Message
		End
	End
	
	return @myError


GO

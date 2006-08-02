SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RefreshMSMSJobNETs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RefreshMSMSJobNETs]
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
**		Auth: mem
**		Date: 10/15/2004
**			  11/28/2004 mem - Added column GANET_RSquared
**			  01/23/2005 mem - Added ScanTime_NET columns and optional population of T_Peptides.Scan_Time_Peak_Apex
**			  01/28/2005 mem - Now updating T_Score_Discriminant when any NET values are updated
**			  02/12/2005 mem - Now setting ForceLCQProcessingOnNextUpdate to 1 in T_Process_Step_Control if any jobs are updated; this is needed to guarantee that ComputeMassTagsGANET will be updated
**			  02/23/2005 mem - Fixed bug that skipped rows in T_Peptides with null GANET_Obs values and rows in T_Score_Discriminant with null discriminant score values
**			  09/02/2005 mem - Now posting entry to T_Log_Entries if any jobs are updated
**			  10/04/2005 mem - Removed parameter @UpdateScanTimeValues and switched to always update Scan_Time_Peak_Apex since this value is now available in T_Peptides in the peptide DB
**			  10/12/2005 mem - Added parameter @PostLogEntryOnSuccess
**			  12/01/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**							 - Increased size of @peptideDBName from 64 to 128 characters
**    
*****************************************************/
 	@jobsUpdated int = 0 output,
 	@peptideRowsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList as varchar(1024) = '',
 	@infoOnly tinyint = 0,
 	@PostLogEntryOnSuccess tinyint = 0
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
			
			set @S = ''
			set @S = @S + 'INSERT INTO #T_Jobs_To_Update (Job)'
			set @S = @S + ' SELECT TAD.Job'
			set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN '
			set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Analysis_Description AS PepTAD ON '
			set @S = @S + ' 	TAD.Job = PepTAD.Job'
			set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(nvarchar(21), @peptideDBID) + ' AND'
			set @S = @S + '    ('
			set @S = @S + '  (IsNull(TAD.GANET_Fit, 0) <> IsNull(PepTAD.GANET_Fit, 0)) OR'
			set @S = @S + '  (IsNull(TAD.GANET_Slope, 0) <> IsNull(PepTAD.GANET_Slope, 0)) OR'
			set @S = @S + '  (IsNull(TAD.GANET_Intercept, 0) <> IsNull(PepTAD.GANET_Intercept, 0)) OR'
			set @S = @S + '  (IsNull(TAD.GANET_RSquared, 0) <> IsNull(PepTAD.GANET_RSquared, 0)) OR'
			set @S = @S + '  (IsNull(TAD.ScanTime_NET_Slope, 0) <> IsNull(PepTAD.ScanTime_NET_Slope, 0)) OR'
			set @S = @S + '  (IsNull(TAD.ScanTime_NET_Intercept, 0) <> IsNull(PepTAD.ScanTime_NET_Intercept, 0)) OR'
			set @S = @S + '  (IsNull(TAD.ScanTime_NET_Fit, 0) <> IsNull(PepTAD.ScanTime_NET_Fit, 0)) OR'
			set @S = @S + '  (IsNull(TAD.ScanTime_NET_RSquared, 0) <> IsNull(PepTAD.ScanTime_NET_RSquared, 0))'
			set @S = @S + '    )'

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND TAD.Job In (' + @JobFilterList + ')'

			exec @result = sp_executesql @S
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			set @jobCountToUpdate = @jobCountToUpdate + @myRowCount
			--
			if @myError <> 0
			begin
				set @message = 'Error comparing jobs to those in ' + @peptideDBName + ', examining NET values'
				goto Done
			end

			-- Look for jobs with undefined Scan_Time_Peak_Apex values, 
			-- but available Scan_Time info in the peptide DB
			set @S = ''
			set @S = @S + ' INSERT INTO #T_Jobs_To_Update (Job)'
			set @S = @S + ' SELECT LookupQ.Job'
			set @S = @S + ' FROM (SELECT TAD.Job,'
			set @S = @S +              ' COUNT(TP.Peptide_ID) AS NullScanTimeCount'
			set @S = @S +              ' FROM T_Analysis_Description AS TAD INNER JOIN'
			set @S = @S +                   ' T_Peptides AS TP ON TAD.Job = TP.Analysis_ID'
			set @S = @S +              ' WHERE TP.Scan_Time_Peak_Apex IS NULL AND TAD.State > 1'
			set @S = @S +              ' GROUP BY TAD.Job'
			set @S = @S +      ' ) LookupQ INNER JOIN '
			set @S = @S +    ' [' + @peptideDBName + '].dbo.V_SIC_Job_to_PeptideHit_Map JobMap ON '
			set @S = @S + '   LookupQ.Job = JobMap.Job LEFT OUTER JOIN #T_Jobs_To_Update'
			set @S = @S + '   ON LookupQ.Job = #T_Jobs_To_Update.Job'
			set @S = @S + ' WHERE (LookupQ.NullScanTimeCount > 0) AND #T_Jobs_To_Update.Job IS NULL'

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
				-- Update the peptides for the appropriate jobs
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
					set @S = @S + ' SET GANET_Obs = PepTP.GANET_Obs,'
					set @S = @S +     ' Scan_Time_Peak_Apex = PepTP.Scan_Time_Peak_Apex'
				End

				set @S = @S + ' FROM T_Peptides AS TP INNER JOIN '
				set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Peptides AS PepTP ON'
				set @S = @S +      ' TP.Analysis_ID = PepTP.Analysis_ID AND'
				set @S = @S +      ' TP.Scan_Number = PepTP.Scan_Number AND'
				set @S = @S +      ' TP.Number_Of_Scans = PepTP.Number_Of_Scans AND'
				set @S = @S +      ' TP.Charge_State = PepTP.Charge_State AND'
				set @S = @S +      ' TP.Mass_Tag_ID = PepTP.Seq_ID AND'
				set @S = @S +      ' (IsNull(TP.GANET_Obs,0) <> PepTP.GANET_Obs OR'
				set @S = @S +       ' IsNull(TP.Scan_Time_Peak_Apex,0) <> PepTP.Scan_Time_Peak_Apex)'
				set @S = @S +      ' INNER JOIN #T_Jobs_To_Update AS JTU ON TP.Analysis_ID = JTU.Job'
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
					set @message = 'Error updating peptide GANET_Obs values using ' + @peptideDBName
					goto Done
				end
					
				Set @peptideRowsUpdated = @peptideRowsUpdated + @myRowCount


				---------------------------------------------------
				-- Update the discriminant score values for the appropriate jobs
				---------------------------------------------------
				--
				set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					set @S = @S + 'SELECT JTU.Job, Count(SD.Peptide_ID) AS Peptide_Rows_To_Update'
				End
				Else
				Begin
					set @S = @S + 'UPDATE SD'
					set @S = @S + ' SET DiscriminantScore = PepSD.DiscriminantScore, '
					set @S = @S +     ' DiscriminantScoreNorm = PepSD.DiscriminantScoreNorm'
				End
			
				set @S = @S + ' FROM T_Peptides AS TP INNER JOIN '
				set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Peptides AS PepTP ON '
				set @S = @S +      ' TP.Analysis_ID = PepTP.Analysis_ID AND '
				set @S = @S +      ' TP.Scan_Number = PepTP.Scan_Number AND '
				set @S = @S +      ' TP.Number_Of_Scans = PepTP.Number_Of_Scans AND '
				set @S = @S +      ' TP.Charge_State = PepTP.Charge_State AND '
				set @S = @S +      ' TP.Mass_Tag_ID = PepTP.Seq_ID INNER JOIN'
				set @S = @S +      ' T_Score_Discriminant AS SD ON '
				set @S = @S +      ' TP.Peptide_ID = SD.Peptide_ID INNER JOIN '
				set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Score_Discriminant AS PepSD ON '
				set @S = @S +      ' PepTP.Peptide_ID = PepSD.Peptide_ID AND '
				set @S = @S +      ' (IsNull(SD.DiscriminantScore,0) <> PepSD.DiscriminantScore OR '
				set @S = @S +       ' IsNull(SD.DiscriminantScoreNorm,0) <> PepSD.DiscriminantScoreNorm)'
				set @S = @S +      ' INNER JOIN #T_Jobs_To_Update AS JTU ON TP.Analysis_ID = JTU.Job'

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
					set @message = 'Error updating peptide Discriminant Score values using ' + @peptideDBName
					goto Done
				end

				---------------------------------------------------
				-- Update the GANET values for these jobs
				---------------------------------------------------
				--
				set @S = ''
				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					set @S = @S + 'SELECT TAD.Job,'
					set @S = @S + ' TAD.GANET_Fit, PTAD.GANET_Fit AS Fit_In_PeptideDB,'
					set @S = @S + ' TAD.GANET_Slope, PTAD.GANET_Slope AS Slope_In_PeptideDB, '
					set @S = @S + ' TAD.GANET_Intercept, PTAD.GANET_Intercept AS Intercept_In_PeptideDB, '
					set @S = @S + ' TAD.GANET_RSquared, PTAD.GANET_RSquared AS RSquared_In_PeptideDB,'
					set @S = @S + ' TAD.ScanTime_NET_Slope, PTAD.ScanTime_NET_Slope AS Slope_In_PeptideDB, '
					set @S = @S + ' TAD.ScanTime_NET_Intercept, PTAD.ScanTime_NET_Intercept AS Intercept_In_PeptideDB, '
					set @S = @S + ' TAD.ScanTime_NET_RSquared, PTAD.ScanTime_NET_RSquared AS RSquared_In_PeptideDB,'
					set @S = @S + ' TAD.ScanTime_NET_Fit, PTAD.ScanTime_NET_Fit AS Fit_In_PeptideDB'
				End
				Else
				Begin
					set @S = @S + 'UPDATE T_Analysis_Description'
					set @S = @S + ' SET GANET_Fit = PTAD.GANET_Fit,'
					set @S = @S + '	    GANET_Slope = PTAD.GANET_Slope,'
					set @S = @S + '	    GANET_Intercept = PTAD.GANET_Intercept,'
					set @S = @S + '	    GANET_RSquared = PTAD.GANET_RSquared,'
					set @S = @S + '     ScanTime_NET_Fit = PTAD.ScanTime_NET_Fit,'
					set @S = @S + '	    ScanTime_NET_Slope = PTAD.ScanTime_NET_Slope,'
					set @S = @S + '	    ScanTime_NET_Intercept = PTAD.ScanTime_NET_Intercept,'
					set @S = @S + '	    ScanTime_NET_RSquared = PTAD.ScanTime_NET_RSquared'
				End

				set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN'
				set @S = @S + '	    #T_Jobs_To_Update AS JTU ON TAD.JOB = JTU.Job INNER JOIN '
				set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Analysis_Description AS PTAD ON'
				set @S = @S + '	    TAD.Job = PTAD.Job'

				If @infoOnly <> 0
				Begin
					set @S = @S + ' ORDER BY TAD.Job'
				End

				exec @result = sp_executesql @S
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					set @message = 'Error updating job GANETs using ' + @peptideDBName
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
		SET Enabled = 1
		WHERE Processing_Step_Name = 'ForceLCQProcessingOnNextUpdate'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			set @message = 'Error refreshing Job GANETs, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSJobNETs'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			set @message = 'Job GANETs refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs and ' + convert(varchar(12), @peptideRowsUpdated) + ' peptide rows'
			If @infoOnly <> 0
			Begin
				set @message = 'InfoOnly: ' + @message
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


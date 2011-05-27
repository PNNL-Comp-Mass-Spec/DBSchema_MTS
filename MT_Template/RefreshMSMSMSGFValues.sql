/****** Object:  StoredProcedure [dbo].[RefreshMSMSMSGFValues] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Procedure dbo.RefreshMSMSMSGFValues
/****************************************************
**
**	Desc: 
**		Updates MSGF_SpecProb in T_Score_Discriminant
**		using the data in the associated peptide database(s)
**		
**		Use @JobFilterList to only update the specified jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	01/31/2011 - Initial version
**    
*****************************************************/
(
 	@jobsUpdated int = 0 output,
 	@peptideRowsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(4000) = '',
 	@PostLogEntryOnSuccess tinyint = 1,
 	@infoOnly tinyint = 0,
 	@PreviewSql tinyint = 0
)
As
	Set nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @result int
	Set @result = 0
		
	Declare @PeptideDBPath varchar(256)
	Declare @PeptideDBID int
	Declare @jobCountToUpdate int

	Declare @PeptideDBCountInvalid int
	Declare @InvalidDBList varchar(1024)

	Declare @S varchar(7500)
	Declare @continue tinyint

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	
	Set @jobsUpdated = 0
	Set @peptideRowsUpdated = 0
	Set @message = ''

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

	CREATE TABLE #T_Tmp_JobsToUpdateMSGF (
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
			execute PostLogEntry 'Error', @message, 'RefreshMSMSSMSGFValues'
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

			TRUNCATE TABLE #T_Tmp_JobsToUpdateMSGF
			Set @jobCountToUpdate = 0
			
			-- Look for Jobs with at least one null MSGF value
			Set @S = ''
			Set @S = @S + ' INSERT INTO #T_Tmp_JobsToUpdateMSGF (Job)'
			Set @S = @S + ' SELECT DISTINCT TAD.Job'
			Set @S = @S + ' FROM T_Analysis_Description AS TAD '
			Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Analysis_Description AS PepTAD ON '
			Set @S = @S +         ' TAD.Job = PepTAD.Job '
			Set @S = @S +      ' INNER JOIN T_Peptides AS Pep '
			Set @S = @S +         ' ON Pep.Analysis_ID = TAD.Job'
			Set @S = @S +      ' INNER JOIN T_Score_Discriminant AS SD ON '
			Set @S = @S +         ' SD.Peptide_ID = Pep.Peptide_ID'
			Set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(varchar(12), @PeptideDBID)
			Set @S = @S +       ' AND (SD.MSGF_SpecProb IS NULL) '

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND TAD.Job In (' + @JobFilterList + ')'

			If @PreviewSql <> 0
				Print @S
			Else
				exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			Set @jobCountToUpdate = @jobCountToUpdate + @myRowCount
			--
			if @myError <> 0
			begin
				Set @message = 'Error comparing jobs to those in ' + @PeptideDBPath
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

			
			if @jobCountToUpdate > 0 Or @PreviewSql <> 0
			Begin -- <c>
				
				---------------------------------------------------
				-- Update the peptides for the appropriate jobs
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + 'SELECT JTU.Job, Count(SD_Target.Peptide_ID) AS Peptide_Rows_To_Update'
				End
				Else
				Begin
					Set @S = @S + 'UPDATE T_Score_Discriminant'
					Set @S = @S + ' Set MSGF_SpecProb = SD_Src.MSGF_SpecProb'
				End

				Set @S = @S + ' FROM T_Peptides P_Target '
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Peptides P_Src ON'
				Set @S = @S +         ' P_Target.Analysis_ID = P_Src.Analysis_ID AND'
				Set @S = @S +         ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				Set @S = @S +         ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				Set @S = @S +         ' P_Target.Charge_State = P_Src.Charge_State AND'
				Set @S = @S +         ' P_Target.Mass_Tag_ID = P_Src.Seq_ID '
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Score_Discriminant SD_Src ON'
				Set @S = @S +         ' P_Src.Peptide_ID = SD_Src.Peptide_ID '
				Set @S = @S +      ' INNER JOIN T_Score_Discriminant SD_Target ON'
				Set @S = @S +         ' P_Target.Peptide_ID = SD_Target.Peptide_ID '
				Set @S = @S +      ' INNER JOIN #T_Tmp_JobsToUpdateMSGF AS JTU ON'
				Set @S = @S +         ' P_Src.Analysis_ID = JTU.Job'
				Set @S = @S + ' WHERE NOT SD_Src.MSGF_SpecProb IS Null AND SD_Src.MSGF_SpecProb <> IsNull(SD_Target.MSGF_SpecProb, -12345)'

				If @infoOnly <> 0
				Begin
					Set @S = @S + ' GROUP BY JTU.Job'
					Set @S = @S + ' ORDER BY JTU.Job'
				End

				If @PreviewSql <> 0
					Print @S
				Else
					exec (@S)

				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					Set @message = 'Error updating MSGF values using ' + @PeptideDBPath
					goto Done
				end
					
				Set @peptideRowsUpdated = @peptideRowsUpdated + @myRowCount


				---------------------------------------------------
				-- Increment @jobsUpdated
				---------------------------------------------------

				Set @jobsUpdated = @jobsUpdated + @jobCountToUpdate
				
			End -- </c>
		End -- </b>
	End -- </a>

	
	If @jobsUpdated > 0 And @infoOnly = 0 And @PreviewSql = 0
	Begin
		-- Make sure the MSMS Processing will occur on the next master update
		-- so that Min_MSGF_SpecProb will get updated in T_Mass_Tags
		UPDATE T_Process_Step_Control
		Set Enabled = 1
		WHERE Processing_Step_Name = 'ForceMSMSProcessingOnNextUpdate'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error updating MSGF values, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSSMSGFValues'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			Set @message = 'MSGF values refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs and ' + convert(varchar(12), @peptideRowsUpdated) + ' peptide rows'
			If @infoOnly <> 0 Or @PreviewSql <> 0
			Begin
				Set @message = 'InfoOnly: ' + @message
				Select @message AS Message
			End
			Else
			Begin
				If @PostLogEntryOnSuccess <> 0
					execute PostLogEntry 'Normal', @message, 'RefreshMSMSSMSGFValues'
			End
		End
		Else
		Begin
			If @previewSql <> 0
				Select 'PreviewSql mode; see the messages pane' As Message
			Else
			Begin
				If @infoOnly <> 0			
					Select 'InfoOnly: No jobs needing to be updated were found' As Message
			End
		End
	End

	DROP TABLE #T_Peptide_Database_List
	DROP TABLE #T_Tmp_JobsToUpdateMSGF
			
	return @myError


GO

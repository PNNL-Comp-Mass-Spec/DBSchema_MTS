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
**	Date:	01/31/2011 mem - Initial version
**			09/14/2011 mem - Expanded @JobFilterList to varchar(max)
**						   - Added parameter @UpdateNonNullValues
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			01/14/2012 mem - Tweaked InfoOnly messages
**			01/17/2012 mem - Now populating T_Analysis_ToolVersion
**    
*****************************************************/
(
 	@jobsUpdated int = 0 output,
 	@peptideRowsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(max) = '',
 	@PostLogEntryOnSuccess tinyint = 1,
 	@UpdateNonNullValues tinyint = 0,				-- When 1, then updates all MSGF_SpecProb values for jobs in @JobFilterList, including non-null values
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
	Declare @JobFilterListDefined tinyint
	
	Declare @S varchar(7500)
	Declare @continue tinyint

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	Set @PostLogEntryOnSuccess = IsNull(@PostLogEntryOnSuccess, 1)	
 	Set @UpdateNonNullValues = IsNull(@UpdateNonNullValues, 0)
 	
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

	CREATE TABLE #T_Tmp_JobFilterList (
		Job int NOT NULL
	)
	
	---------------------------------------------------
	-- Populate #T_Tmp_JobFilterList
	---------------------------------------------------
	
	Set @JobFilterListDefined = 0
	
	If Len(@JobFilterList) > 0
	Begin
		INSERT INTO #T_Tmp_JobFilterList (Job)
		SELECT Value
		FROM dbo.udfParseDelimitedIntegerList(@JobFilterList, ',')
		ORDER BY Value
		
		Set @JobFilterListDefined = 1
	End
	
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
			-- Alternatively, process all jobs in #T_Tmp_JobFilterList
			Set @S = ''
			Set @S = @S +  'INSERT INTO #T_Tmp_JobsToUpdateMSGF (Job)'
			Set @S = @S + ' SELECT DISTINCT TAD.Job'
			Set @S = @S + ' FROM T_Analysis_Description AS TAD '
			Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Analysis_Description AS PepTAD ON '
			Set @S = @S +         ' TAD.Job = PepTAD.Job '
			Set @S = @S +      ' INNER JOIN T_Peptides AS Pep '
			Set @S = @S +         ' ON Pep.Job = TAD.Job'
			Set @S = @S +      ' INNER JOIN T_Score_Discriminant AS SD ON '
			Set @S = @S +         ' SD.Peptide_ID = Pep.Peptide_ID'
			
			If @JobFilterListDefined = 1
				Set @S = @S +  ' INNER JOIN #T_Tmp_JobFilterList FL ON TAD.Job = FL.Job'
			
			Set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(varchar(12), @PeptideDBID)

			If Not (@JobFilterListDefined = 1 AND @UpdateNonNullValues <> 0)
				Set @S = @S +       ' AND (SD.MSGF_SpecProb IS NULL) '

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
					Set @S = @S + 'SELECT JTU.Job, Count(SD_Target.Peptide_ID) AS Rows_To_Update_T_Score_Discriminant'
				End
				Else
				Begin
					Set @S = @S + 'UPDATE T_Score_Discriminant'
					Set @S = @S + ' Set MSGF_SpecProb = SD_Src.MSGF_SpecProb'
				End

				Set @S = @S + ' FROM T_Peptides P_Target '
				Set @S = @S + ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Peptides P_Src ON'
				Set @S = @S +         ' P_Target.Job = P_Src.Job AND'
				Set @S = @S +         ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				Set @S = @S +         ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				Set @S = @S +         ' P_Target.Charge_State = P_Src.Charge_State AND'
				Set @S = @S +         ' P_Target.Mass_Tag_ID = P_Src.Seq_ID '
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Score_Discriminant SD_Src ON'
				Set @S = @S +         ' P_Src.Peptide_ID = SD_Src.Peptide_ID '
				Set @S = @S +      ' INNER JOIN T_Score_Discriminant SD_Target ON'
				Set @S = @S +         ' P_Target.Peptide_ID = SD_Target.Peptide_ID '
				Set @S = @S +      ' INNER JOIN #T_Tmp_JobsToUpdateMSGF AS JTU ON'
				Set @S = @S +         ' P_Src.Job = JTU.Job'
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
				-- Update T_Analysis_ToolVersion
				---------------------------------------------------					

				Set @S = ''
				Set @S = @S + ' MERGE INTO T_Analysis_ToolVersion AS Target'
				Set @S = @S + ' USING (	SELECT JTU.Job,'
				Set @S = @S +                ' Src.MSGF_Version'
				Set @S = @S +         ' FROM #T_Tmp_JobsToUpdateMSGF JTU'
				Set @S = @S +              ' LEFT OUTER JOIN ' + @PeptideDBPath + '.dbo.T_Analysis_ToolVersion Src'
				Set @S = @S +                ' ON Src.Job = JTU.Job'
				Set @S = @S + ' ) AS Source (Job, MSGF_Version) '
				Set @S = @S +   ' ON Target.Job = Source.Job'
				Set @S = @S + ' WHEN NOT MATCHED THEN'
				Set @S = @S +     ' INSERT (Job, MSGF_Version, Entered, Last_Affected)'
				Set @S = @S +     ' VALUES (Source.Job, Source.MSGF_Version, GETDATE(), GETDATE())'
				Set @S = @S + ' WHEN Matched And (' 
				Set @S = @S +         ' ISNULL(Target.MSGF_Version, '''') <> ISNULL(source.MSGF_Version, '''') ' 
				Set @S = @S +       ') THEN'
				Set @S = @S +      ' UPDATE SET MSGF_Version = Source.MSGF_Version,'
				Set @S = @S +                 ' Last_Affected = GETDATE()'
				Set @S = @S + ' ;'
								
				If @PreviewSql <> 0
					Print @S
				Else
				Begin
					If @infoOnly = 0
						exec (@S)
				End

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
					Select 'InfoOnly: No jobs need to have T_Score_Discriminant updated' As Message
			End
		End
	End

	DROP TABLE #T_Peptide_Database_List
	DROP TABLE #T_Tmp_JobsToUpdateMSGF
			
	return @myError


GO

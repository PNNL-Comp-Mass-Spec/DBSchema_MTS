/****** Object:  StoredProcedure [dbo].[RefreshPeptideHitScores] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure RefreshPeptideHitScores
/****************************************************
**
**	Desc: 
**		Updates scores in T_Score_Sequest, T_Score_Xtandem, etc.
**		using the data in the associated peptide database(s)
**
**		Also updates MSGF_SpecProb in T_Score_Discriminant using RefreshMSMSMSGFValues
**		
**		Use @JobFilterList to only update the specified jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	01/14/2012 mem
**			01/17/2012 mem - Now populating T_Analysis_ToolVersion
**			02/28/2012 mem - Added check for all entries in T_Analysis_Description having PeptideDBID = 0
**    
*****************************************************/
(
 	@jobsUpdated int = 0 output,
 	@peptideRowsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(max) = '',
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
	Declare @JobFilterListDefined tinyint
	
	Declare @S varchar(7500)
	Declare @continue tinyint
	Declare @ContinueSql tinyint
	
	Declare @SqlEntryID int
	Declare @SqlUpdateTarget varchar(32)

	Declare	@PreviewSelect varchar(256)
	Declare	@PreviewSuffix varchar(256)
	

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	Set @PostLogEntryOnSuccess = IsNull(@PostLogEntryOnSuccess, 1)	
 	
	Set @jobsUpdated = 0
	Set @peptideRowsUpdated = 0
	Set @message = ''

	---------------------------------------------------
	-- Create some temporary tables
	---------------------------------------------------
	--
	CREATE TABLE #T_Peptide_Database_List (
		PeptideDBName varchar(128) NULL,
		PeptideDBID int NULL,
		PeptideDBServer varchar(128) NULL,
		PeptideDBPath varchar(256) NULL
	)

	CREATE TABLE #T_Tmp_JobsToUpdate (
		Job int NOT NULL
	)

	CREATE TABLE #T_Tmp_JobFilterList (
		Job int NOT NULL
	)

	CREATE TABLE #T_Tmp_SqlStatements (
		Entry_ID int identity(1,1),
		UpdateTarget varchar(32),
		S varchar(7500)
		
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

	Declare @DBIdMin int = 0
	Declare @DBIdMax int = 0
	
	SELECT @DBIdMin = Min(PeptideDBID), @DBIdMax = Max(PeptideDBID)
	FROM #T_Peptide_Database_List
	
	If @DBIdMin = 0 And @DBIdMax = 0
	Begin
		Set @message = 'All analyses have a Peptide DB ID = 0; nothing to do'
		Set @myError = 0
		goto Done
	End
	
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
	Begin -- <a1>
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
			execute PostLogEntry 'Error', @message, 'RefreshPeptideHitScores'
			Set @message = ''
			
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBName Is Null
		End
	End -- </a1>


	---------------------------------------------------
	-- Define some SQL that will be used several times
	---------------------------------------------------
	
	Set @PreviewSelect = 'SELECT JTU.Job, Count(P_Target.Peptide_ID) AS Rows_To_Update'
	Set @PreviewSuffix = ' GROUP BY JTU.Job ORDER BY JTU.Job'

	---------------------------------------------------
	-- Loop through peptide database(s) and look for jobs
	-- that need to be updated
	---------------------------------------------------
	--

	Set @continue = 1
	While @continue = 1
	Begin -- <a2>
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

			TRUNCATE TABLE #T_Tmp_JobsToUpdate
			Set @jobCountToUpdate = 0
			
			-- Look for Jobs to update
			Set @S = ''
			Set @S = @S +  'INSERT INTO #T_Tmp_JobsToUpdate (Job)'
			Set @S = @S + ' SELECT DISTINCT TAD.Job'
			Set @S = @S + ' FROM T_Analysis_Description AS TAD '
			Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Analysis_Description AS PepTAD ON '
			Set @S = @S +         ' TAD.Job = PepTAD.Job '
			
			If @JobFilterListDefined = 1
				Set @S = @S +  ' INNER JOIN #T_Tmp_JobFilterList FL ON TAD.Job = FL.Job'
			
			Set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(varchar(12), @PeptideDBID)

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
				
				TRUNCATE TABLE #T_Tmp_SqlStatements
				
				
				---------------------------------------------------
				-- 1. Update T_Peptides
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + @PreviewSelect + '_T_Peptides'
				End
				Else
				Begin
					Set @S = @S + ' UPDATE P_Target'
					Set @S = @S + ' SET DelM_PPM = P_Src.DelM_PPM'
				End

				Set @S = @S + ' FROM T_Peptides P_Target'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Peptides P_Src'
				Set @S = @S +        ' ON P_Target.Job = P_Src.Job AND'
				Set @S = @S +           ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				Set @S = @S +           ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				Set @S = @S +           ' P_Target.Charge_State = P_Src.Charge_State AND'
				Set @S = @S +           ' P_Target.Mass_Tag_ID = P_Src.Seq_ID'
				Set @S = @S +      ' INNER JOIN #T_Tmp_JobsToUpdate AS JTU ON'
				Set @S = @S +         ' P_Src.Job = JTU.Job'
				Set @S = @S + ' WHERE IsNull(P_Target.DelM_PPM, -12345) <> IsNull(P_Src.DelM_PPM, -12345)'

				If @infoOnly <> 0
				Begin
					Set @S = @S + @PreviewSuffix
				End
				
				INSERT INTO #T_Tmp_SqlStatements (UpdateTarget, S)
				Values ('T_Peptides', @S)
				
				
				---------------------------------------------------
				-- 2. Update T_Score_Sequest
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + @PreviewSelect + '_T_Score_Sequest'
				End
				Else
				Begin
					Set @S = @S + ' UPDATE SS_Target'
					Set @S = @S + ' SET XCorr = SS_Src.xcorr'
				End
				
				Set @S = @S + ' FROM T_Peptides P_Target'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Peptides P_Src'
				Set @S = @S +        ' ON P_Target.Job = P_Src.Job AND'
				Set @S = @S +           ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				Set @S = @S +           ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				Set @S = @S +           ' P_Target.Charge_State = P_Src.Charge_State AND'
				Set @S = @S +           ' P_Target.Mass_Tag_ID = P_Src.Seq_ID'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Score_Sequest SS_Src'
				Set @S = @S +        ' ON P_Src.Peptide_ID = SS_Src.Peptide_ID'
				Set @S = @S +      ' INNER JOIN T_Score_Sequest SS_Target'
				Set @S = @S +        ' ON P_Target.Peptide_ID = SS_Target.Peptide_ID'
				Set @S = @S +      ' INNER JOIN #T_Tmp_JobsToUpdate AS JTU ON'
				Set @S = @S +         ' P_Src.Job = JTU.Job'
				Set @S = @S + ' WHERE SS_Target.XCorr <> SS_Src.XCorr'

				If @infoOnly <> 0
				Begin
					Set @S = @S + @PreviewSuffix
				End
				
				INSERT INTO #T_Tmp_SqlStatements (UpdateTarget, S)
				Values ('T_Score_Sequest', @S)


				---------------------------------------------------
				-- 3. Update T_Score_Inspect
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + @PreviewSelect + '_T_Score_Inspect'
				End
				Else
				Begin
					Set @S = @S + ' UPDATE Ins_target'
					Set @S = @S + ' SET Normalized_Score = Ins_Src.Normalized_Score,'
					Set @S = @S + '     TotalPRMScore = Ins_Src.TotalPRMScore'
				End
				
				Set @S = @S + ' FROM T_Peptides P_Target'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Peptides P_Src'
				Set @S = @S +        ' ON P_Target.Job = P_Src.Job AND'
				Set @S = @S +           ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				Set @S = @S +           ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				Set @S = @S +           ' P_Target.Charge_State = P_Src.Charge_State AND'
				Set @S = @S +           ' P_Target.Mass_Tag_ID = P_Src.Seq_ID'
				Set @S = @S +      ' INNER JOIN T_Score_Inspect Ins_Target'
				Set @S = @S +        ' ON P_Target.Peptide_ID = Ins_Target.Peptide_ID'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Score_Inspect Ins_Src'
				Set @S = @S +        ' ON P_Src.Peptide_ID = Ins_Src.Peptide_ID'
				Set @S = @S +      ' INNER JOIN #T_Tmp_JobsToUpdate AS JTU ON'
				Set @S = @S +         ' P_Src.Job = JTU.Job'
				Set @S = @S + ' WHERE Ins_target.Normalized_Score <> Ins_Src.Normalized_Score OR'
				Set @S = @S +   '  Ins_target.TotalPRMScore <> Ins_Src.TotalPRMScore'

				If @infoOnly <> 0
				Begin
					Set @S = @S + @PreviewSuffix
				End
				
				INSERT INTO #T_Tmp_SqlStatements (UpdateTarget, S)
				Values ('T_Score_Inspect', @S)


				---------------------------------------------------
				-- 4. Update T_Score_XTandem
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + @PreviewSelect + '_T_Score_XTandem'
				End
				Else
				Begin
					Set @S = @S + ' UPDATE XT_target'
					Set @S = @S + ' SET Normalized_Score = XT_Src.Normalized_Score,'
					Set @S = @S + '     Hyperscore = XT_Src.Hyperscore'
				End
				
				Set @S = @S + ' FROM T_Peptides P_Target'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Peptides P_Src'
				Set @S = @S +        ' ON P_Target.Job = P_Src.Job AND'
				Set @S = @S +           ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				Set @S = @S +           ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				Set @S = @S +           ' P_Target.Charge_State = P_Src.Charge_State AND'
				Set @S = @S +           ' P_Target.Mass_Tag_ID = P_Src.Seq_ID'
				Set @S = @S +      ' INNER JOIN T_Score_XTandem XT_Target'
				Set @S = @S +        ' ON P_Target.Peptide_ID = XT_Target.Peptide_ID'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Score_XTandem XT_Src'
				Set @S = @S +        ' ON P_Src.Peptide_ID = XT_Src.Peptide_ID'
				Set @S = @S +      ' INNER JOIN #T_Tmp_JobsToUpdate AS JTU ON'
				Set @S = @S +         ' P_Src.Job = JTU.Job'
				Set @S = @S + ' WHERE XT_target.Normalized_Score <> XT_Src.Normalized_Score OR'
				Set @S = @S +      '  XT_target.Hyperscore <> XT_Src.Hyperscore'

				If @infoOnly <> 0
				Begin
					Set @S = @S + @PreviewSuffix
				End
				
				INSERT INTO #T_Tmp_SqlStatements (UpdateTarget, S)
				Values ('T_Score_XTandem', @S)
				
				
				---------------------------------------------------
				-- 5. Update T_Score_MSGFDB
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + @PreviewSelect + '_T_Score_MSGFDB'
				End
				Else
				Begin
					Set @S = @S + ' UPDATE MSG_target'
					Set @S = @S + ' SET Normalized_Score = MSG_Src.Normalized_Score,'
					Set @S = @S + '     MSGFScore = MSG_Src.MSGFScore,'
					Set @S = @S + '     PepFDR = MSG_Src.PepFDR'
				End
				
				Set @S = @S + ' FROM T_Peptides P_Target'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Peptides P_Src'
				Set @S = @S +        ' ON P_Target.Job = P_Src.Job AND'
				Set @S = @S +           ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				Set @S = @S +           ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				Set @S = @S +           ' P_Target.Charge_State = P_Src.Charge_State AND'
				Set @S = @S +           ' P_Target.Mass_Tag_ID = P_Src.Seq_ID'
				Set @S = @S +      ' INNER JOIN T_Score_MSGFDB MSG_Target'
				Set @S = @S +        ' ON P_Target.Peptide_ID = MSG_Target.Peptide_ID'
				Set @S = @S +      ' INNER JOIN ' + @PeptideDBPath + '.dbo.T_Score_MSGFDB MSG_Src'
				Set @S = @S +        ' ON P_Src.Peptide_ID = MSG_Src.Peptide_ID'
				Set @S = @S +      ' INNER JOIN #T_Tmp_JobsToUpdate AS JTU ON'
				Set @S = @S +         ' P_Src.Job = JTU.Job'
				Set @S = @S + ' WHERE MSG_target.Normalized_Score <> MSG_Src.Normalized_Score OR'
				Set @S = @S +      '  MSG_target.MSGFScore <> MSG_Src.MSGFScore OR'
				Set @S = @S +      '  IsNull(MSG_target.PepFDR, -1234) <> IsNull(MSG_Src.PepFDR, -1230)'

				If @infoOnly <> 0
				Begin
					Set @S = @S + @PreviewSuffix
				End
				
				INSERT INTO #T_Tmp_SqlStatements (UpdateTarget, S)
				Values ('T_Score_MSGFDB', @S)


				---------------------------------------------------
				-- Process each row in #T_Tmp_SqlStatements
				---------------------------------------------------
				--
				Set @ContinueSql = 1
				Set @SqlEntryID = 0
				
				While @ContinueSql = 1
				Begin -- <d>
					SELECT TOP 1 @SqlEntryID = Entry_ID,
					             @S = S,
					             @SqlUpdateTarget = UpdateTarget
					FROM #T_Tmp_SqlStatements
					WHERE Entry_ID > @SqlEntryID
					ORDER BY Entry_ID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				
					If @myRowCount = 0
						Set @ContinueSql = 0
					Else
					Begin -- <e>
						
						If @PreviewSql <> 0
							Print @S
						Else
							exec (@S)
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						--
						if @myError <> 0
						begin
							Set @message = 'Error updating ' + @SqlUpdateTarget + ' values using ' + @PeptideDBPath
							goto Done
						end
							
						Set @peptideRowsUpdated = @peptideRowsUpdated + @myRowCount
						
					End -- </e>
					
				End -- </d>

				---------------------------------------------------
				-- Update T_Analysis_ToolVersion
				---------------------------------------------------					

				Set @S = ''
				Set @S = @S + ' MERGE INTO T_Analysis_ToolVersion AS Target'
				Set @S = @S + ' USING (	SELECT JTU.Job,'
				Set @S = @S +                ' Src.Tool_Version,'
				Set @S = @S +                ' Src.DataExtractor_Version'
				Set @S = @S +         ' FROM #T_Tmp_JobsToUpdate JTU'
				Set @S = @S +              ' LEFT OUTER JOIN ' + @PeptideDBPath + '.dbo.T_Analysis_ToolVersion Src'
				Set @S = @S +                ' ON Src.Job = JTU.Job'
				Set @S = @S + ' ) AS Source (Job, Tool_Version, DataExtractor_Version) '
				Set @S = @S +   ' ON Target.Job = Source.Job'
				Set @S = @S + ' WHEN NOT MATCHED THEN'
				Set @S = @S +     ' INSERT (Job, Tool_Version, DataExtractor_Version, Entered, Last_Affected)'
				Set @S = @S +     ' VALUES (Source.Job, Source.Tool_Version, Source.DataExtractor_Version, GETDATE(), GETDATE())'
				Set @S = @S + ' WHEN Matched And ('
				Set @S = @S +         ' ISNULL(Target.Tool_Version, '''') <> ISNULL(source.Tool_Version, '''') OR'
				Set @S = @S +         ' ISNULL(Target.DataExtractor_Version, '''') <> ISNULL(source.DataExtractor_Version, '''') '
				Set @S = @S +      ' ) THEN'
				Set @S = @S +      ' UPDATE SET Tool_Version = Source.Tool_Version,'
				Set @S = @S +                 ' DataExtractor_Version = Source.DataExtractor_Version,'
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
	End -- </a2>


	
	---------------------------------------------------
	-- Now update MSGF values
	-- Must drop several temporary tables prior to calling RefreshMSMSMSGFValues
	--   to avoid naming collisions
	---------------------------------------------------
	--
	DROP TABLE #T_Peptide_Database_List
	DROP TABLE #T_Tmp_JobsToUpdate
	DROP TABLE #T_Tmp_JobFilterList

	exec @myError = RefreshMSMSMSGFValues 
							@JobFilterList = @JobFilterList,
 							@PostLogEntryOnSuccess = @PostLogEntryOnSuccess,
							@UpdateNonNullValues = 1,
 							@infoOnly = @infoOnly,
 							@PreviewSql = @PreviewSql

	
	If @jobsUpdated > 0 And @infoOnly = 0 And @PreviewSql = 0
	Begin
		---------------------------------------------------
		-- Make sure the MSMS Processing will occur on the next master update
		-- so that various fields in T_Mass_Tags will get updated
		---------------------------------------------------
		--
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
			Set @message = 'Error updating Peptide_Hit scores, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshPeptideHitScores'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			Set @message = 'Peptide_Hit scores refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs and ' + convert(varchar(12), @peptideRowsUpdated) + ' peptide rows'
			If @infoOnly <> 0 Or @PreviewSql <> 0
			Begin
				Set @message = 'InfoOnly: ' + @message
				Select @message AS Message
			End
			Else
			Begin
				If @PostLogEntryOnSuccess <> 0
					execute PostLogEntry 'Normal', @message, 'RefreshPeptideHitScores'
			End
		End
		Else
		Begin
			If @previewSql <> 0
				Select 'PreviewSql mode; see the messages pane' As Message
			Else
			Begin
				If @infoOnly <> 0			
					Select 'InfoOnly: No jobs need to have Peptide_Hit scores updated' As Message
			End
		End
	End

	return @myError


GO

/****** Object:  StoredProcedure [dbo].[RefreshMSMSPeptideProphetValues] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure RefreshMSMSPeptideProphetValues
/****************************************************
**
**	Desc: 
**		Updates the peptide prophet values in T_Score_Discriminant
**		using the data in the associated peptide database(s)
**		
**		Use @JobFilterList to only update the specified jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/10/2006
**			07/20/2006 mem - Expanded size of @JobFilterList from 1024 to 4000
**			09/19/2006 mem - Added support for peptide DBs being located on a separate MTS server, utilizing MT_Main.dbo.PopulatePeptideDBLocationTable to determine DB location given Peptide DB ID
**			04/23/2008 mem - Now explicitly dropping the temporary table created by this procedure; in addition, uniquified the JobsToUpdate temporary table
**    
*****************************************************/
(
 	@jobsUpdated int = 0 output,
 	@peptideRowsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(4000) = '',
 	@infoOnly tinyint = 0,
 	@PostLogEntryOnSuccess tinyint = 0
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

	Declare @S varchar(7500)
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

	CREATE TABLE #T_Tmp_JobsToUpdatePepProphet (
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
			execute PostLogEntry 'Error', @message, 'RefreshMSMSPeptideProphetValues'
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

			TRUNCATE TABLE #T_Tmp_JobsToUpdatePepProphet
			Set @jobCountToUpdate = 0
			
			Set @S = ''
			Set @S = @S + 'INSERT INTO #T_Tmp_JobsToUpdatePepProphet (Job)'
			Set @S = @S + ' SELECT TAD.Job'
			Set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN '
			Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Analysis_Description AS PepTAD ON '
			Set @S = @S +       ' TAD.Job = PepTAD.Job INNER JOIN '
			Set @S = @S +    '( SELECT DISTINCT Target_ID AS Job'
			Set @S = @S +     ' FROM ' + @PeptideDBPath + '.dbo.T_Event_Log AS EL'
			Set @S = @S +     ' WHERE Prev_Target_State = 96 AND Target_Type = 1) LookupQ ON'
			Set @S = @S +       ' PepTAD.Job = LookupQ.Job'
			Set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(nvarchar(21), @PeptideDBID)

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND TAD.Job In (' + @JobFilterList + ')'

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
					Set @S = @S + 'SELECT JTU.Job, Count(SD_Target.Peptide_ID) AS Peptide_Rows_To_Update'
				End
				Else
				Begin
					Set @S = @S + 'UPDATE T_Score_Discriminant'
					Set @S = @S + ' Set Peptide_Prophet_FScore = SD_Src.Peptide_Prophet_FScore, '
					Set @S = @S +     ' Peptide_Prophet_Probability = SD_Src.Peptide_Prophet_Probability'
				End

				Set @S = @S + ' FROM T_Peptides P_Target INNER JOIN'
				Set @S = @S +      ' ' + @PeptideDBPath + '.dbo.T_Peptides P_Src ON'
				Set @S = @S +      ' P_Target.Analysis_ID = P_Src.Analysis_ID AND'
				Set @S = @S +      ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				Set @S = @S +      ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				Set @S = @S +      ' P_Target.Charge_State = P_Src.Charge_State AND'
				Set @S = @S +      ' P_Target.Mass_Tag_ID = P_Src.Seq_ID INNER JOIN'
				Set @S = @S +      ' ' + @PeptideDBPath + '.dbo.T_Score_Discriminant SD_Src ON'
				Set @S = @S +      ' P_Src.Peptide_ID = SD_Src.Peptide_ID INNER JOIN'
				Set @S = @S +      ' T_Score_Discriminant SD_Target ON'
				Set @S = @S +      ' P_Target.Peptide_ID = SD_Target.Peptide_ID INNER JOIN'
				Set @S = @S +      ' #T_Tmp_JobsToUpdatePepProphet AS JTU ON P_Src.Analysis_ID = JTU.Job'
				Set @S = @S + ' WHERE NOT SD_Src.Peptide_Prophet_Probability IS Null AND SD_Src.Peptide_Prophet_Probability <> IsNull(SD_Target.Peptide_Prophet_Probability, -12345) OR '
				Set @S = @S +      ' (SD_Src.Peptide_Prophet_Probability IS Null AND NOT SD_Target.Peptide_Prophet_Probability IS Null)'

				If @infoOnly <> 0
				Begin
					Set @S = @S + ' GROUP BY JTU.Job'
					Set @S = @S + ' ORDER BY JTU.Job'
				End

				exec (@S)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					Set @message = 'Error updating peptide prophet values using ' + @PeptideDBPath
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

	
	If @jobsUpdated > 0 and @infoOnly = 0
	Begin
		-- Make sure the MSMS Processing will occur on the next master update
		-- so that Peptide_Prophet_Max will get updated in T_Mass_Tags
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
			Set @message = 'Error updating peptide prophet values, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSPeptideProphetValues'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			Set @message = 'Peptide prophet values refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs and ' + convert(varchar(12), @peptideRowsUpdated) + ' peptide rows'
			If @infoOnly <> 0
			Begin
				Set @message = 'InfoOnly: ' + @message
				Select @message AS Message
			End
			Else
			Begin
				If @PostLogEntryOnSuccess <> 0
					execute PostLogEntry 'Normal', @message, 'RefreshMSMSPeptideProphetValues'
			End
		End
		Else
		Begin
			If @infoOnly <> 0
				Select 'InfoOnly: No jobs needing to be updated were found' As Message
		End
	End

	DROP TABLE #T_Peptide_Database_List
	DROP TABLE #T_Tmp_JobsToUpdatePepProphet
			
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[RefreshMSMSPeptideProphetValues] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshMSMSPeptideProphetValues] TO [MTS_DB_Lite] AS [dbo]
GO

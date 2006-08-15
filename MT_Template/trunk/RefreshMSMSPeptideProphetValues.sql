/****** Object:  StoredProcedure [dbo].[RefreshMSMSPeptideProphetValues] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.RefreshMSMSPeptideProphetValues
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

	declare @S varchar(7500)
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
			set @S = @S +       ' TAD.Job = PepTAD.Job INNER JOIN '
			set @S = @S +    '( SELECT DISTINCT Target_ID AS Job'
			set @S = @S +     ' FROM [' + @peptideDBName + '].dbo.T_Event_Log AS EL'
			set @S = @S +     ' WHERE Prev_Target_State = 96 AND Target_Type = 1) LookupQ ON'
			set @S = @S +       ' PepTAD.Job = LookupQ.Job'
			set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(nvarchar(21), @peptideDBID)

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND TAD.Job In (' + @JobFilterList + ')'

			exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			set @jobCountToUpdate = @jobCountToUpdate + @myRowCount
			--
			if @myError <> 0
			begin
				set @message = 'Error comparing jobs to those in ' + @peptideDBName
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
					set @S = @S + 'SELECT JTU.Job, Count(SD_Target.Peptide_ID) AS Peptide_Rows_To_Update'
				End
				Else
				Begin
					set @S = @S + 'UPDATE T_Score_Discriminant'
					set @S = @S + ' SET Peptide_Prophet_FScore = SD_Src.Peptide_Prophet_FScore, '
					set @S = @S +     ' Peptide_Prophet_Probability = SD_Src.Peptide_Prophet_Probability'
				End

				set @S = @S + ' FROM T_Peptides P_Target INNER JOIN'
				set @S = @S +      ' [' + @peptideDBName + '].dbo.T_Peptides P_Src ON'
				set @S = @S +      ' P_Target.Analysis_ID = P_Src.Analysis_ID AND'
				set @S = @S +      ' P_Target.Scan_Number = P_Src.Scan_Number AND'
				set @S = @S +      ' P_Target.Number_Of_Scans = P_Src.Number_Of_Scans AND'
				set @S = @S +      ' P_Target.Charge_State = P_Src.Charge_State AND'
				set @S = @S +      ' P_Target.Mass_Tag_ID = P_Src.Seq_ID INNER JOIN'
				set @S = @S +      ' [' + @peptideDBName + '].dbo.T_Score_Discriminant SD_Src ON'
				set @S = @S +      ' P_Src.Peptide_ID = SD_Src.Peptide_ID INNER JOIN'
				set @S = @S +      ' T_Score_Discriminant SD_Target ON'
				set @S = @S +      ' P_Target.Peptide_ID = SD_Target.Peptide_ID INNER JOIN'
				set @S = @S +      ' #T_Jobs_To_Update AS JTU ON P_Src.Analysis_ID = JTU.Job'
				set @S = @S + ' WHERE NOT SD_Src.Peptide_Prophet_Probability IS Null AND SD_Src.Peptide_Prophet_Probability <> IsNull(SD_Target.Peptide_Prophet_Probability, -12345) OR '
				set @S = @S +      ' (SD_Src.Peptide_Prophet_Probability IS Null AND NOT SD_Target.Peptide_Prophet_Probability IS Null)'

				If @infoOnly <> 0
				Begin
					set @S = @S + ' GROUP BY JTU.Job'
					set @S = @S + ' ORDER BY JTU.Job'
				End

				exec (@S)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					set @message = 'Error updating peptide prophet values using ' + @peptideDBName
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
		SET Enabled = 1
		WHERE Processing_Step_Name = 'ForceLCQProcessingOnNextUpdate'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			set @message = 'Error updating peptide prophet values, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSPeptideProphetValues'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			set @message = 'Peptide prophet values refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs and ' + convert(varchar(12), @peptideRowsUpdated) + ' peptide rows'
			If @infoOnly <> 0
			Begin
				set @message = 'InfoOnly: ' + @message
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
	
	return @myError


GO

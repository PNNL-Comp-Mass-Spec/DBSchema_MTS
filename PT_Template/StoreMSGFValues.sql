/****** Object:  StoredProcedure [dbo].[StoreMSGFValues] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.StoreMSGFValues
/****************************************************
**
**	Desc: 
**		Copies data from #Tmp_MSGF_Results into T_Score_Discriminant
**		Intended to be called from LoadSequestPeptidesBulk, LoadXTandemPeptidesBulk, and LoadInspectPeptidesBulk
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/23/2010 mem - Initial Version (modelled after StorePeptideProphetValues)
**			08/16/2010 mem - Updated log warning message
**    
*****************************************************/
(
	@Job int,
	@numAddedDiscScores int,
	@LogLevel int,
	@LogMessage varchar(512),
	@UsingPhysicalTempTables tinyint,
	@infoOnly tinyint = 0,
	@message varchar(512)='' output
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	declare @numAddedMSGFScores int
	declare @jobStr varchar(12)

	declare @RowCountTotal int
	declare @RowCountNull int
	declare @MessageType varchar(32)

	-----------------------------------------------
	-- Validate the inputs
	-----------------------------------------------
	
	Set @UsingPhysicalTempTables = IsNull(@UsingPhysicalTempTables, 0)
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @message = ''

	Set @jobStr = Convert(varchar(12), @Job)

	
	If @UsingPhysicalTempTables = 1
	Begin
		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_MSGF_DataByPeptideID]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_MSGF_DataByPeptideID]
	End
	
	CREATE TABLE #Tmp_MSGF_DataByPeptideID (
		Peptide_ID int NOT NULL,				-- Corresponds to #Tmp_Unique_Records.Peptide_ID_New and to T_Peptides.Peptide_ID
		SpecProb real NOT NULL
	)

	-----------------------------------------------
	-- Copy selected contents of #Tmp_MSGF_Results
	-- into T_Score_Discriminant
	-----------------------------------------------
	--
	/*
	** Old, one-step query
		UPDATE T_Score_Discriminant
		SET SpecProb = MSGF.SpecProb
		FROM T_Score_Discriminant SD INNER JOIN 
			#Tmp_Unique_Records UR ON SD.Peptide_ID = UR.Peptide_ID_New INNER JOIN
			#Tmp_Peptide_Import TPI ON UR.Result_ID = TPI.Result_ID INNER JOIN
			#Tmp_MSGF_Results MSGF ON TPI.Result_ID = MSGF.Result_ID
	--			
	*/
	
	INSERT INTO #Tmp_MSGF_DataByPeptideID (Peptide_ID, SpecProb)
	SELECT UR.Peptide_ID_New,
	       MSGF.SpecProb
	FROM #Tmp_Unique_Records UR
	     INNER JOIN #Tmp_Peptide_Import TPI
	       ON UR.Result_ID = TPI.Result_ID
	     INNER JOIN #Tmp_MSGF_Results MSGF
	       ON TPI.Result_ID = MSGF.Result_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
		set @message = 'Error populating #Tmp_MSGF_DataByPeptideID with MSGF results for job ' + @jobStr
	Else
	Begin
		UPDATE T_Score_Discriminant
		SET MSGF_SpecProb = MD.SpecProb
		FROM T_Score_Discriminant SD
		     INNER JOIN #Tmp_MSGF_DataByPeptideID MD
		       ON SD.Peptide_ID = MD.Peptide_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
			set @message = 'Error updating T_Score_Discriminant with MSGF results for job ' + @jobStr
	End
	--
	if @myError <> 0
	Begin
		execute PostLogEntry 'Error', @message, 'StoreMSGFValues'
		Set @numAddedMSGFScores = 0
	End
	Else
	Begin
		Set @numAddedMSGFScores = @myRowCount

		Set @LogMessage = 'Updated MSGF values in T_Score_Discriminant for ' + Convert(varchar(12), @myRowCount) + ' rows'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'StoreMSGFValues'
	End
	
	if @myError = 0
	Begin
		-----------------------------------------------
		-- Look for any MSGF results with an error message in the Note column
		-- Append the errors to T_Log_Entries (up to 50 per job)
		-- First, count the number of error rows
		-----------------------------------------------
		Set @myRowCount = 0
		
		SELECT @myRowCount = COUNT(*)
		FROM #Tmp_Unique_Records UR
			INNER JOIN #Tmp_Peptide_Import TPI
			ON UR.Result_ID = TPI.Result_ID
			INNER JOIN #Tmp_MSGF_Results MSGF
			ON TPI.Result_ID = MSGF.Result_ID
		WHERE MSGF.SpecProbNote LIKE '%N/A:%'
		
		If @myRowCount > 0
		Begin
			Set @message = Convert(varchar(12), @myRowCount)
			if @myRowCount = 1
				Set @message = @message + ' entry in the MSGF results for job ' + @jobStr + ' has an error message'
			else
				Set @message = @message + ' entries in the MSGF results for job ' + @jobStr + ' have error messages'
			
			execute PostLogEntry 'Warning', @message, 'StoreMSGFValues'
			
			INSERT INTO T_Log_Entries( posted_by, posting_time, Type, message )
			SELECT TOP 50 'StoreMSGFValues',
			              GETDATE(),
			              'Warning',
			              SpecProbNote + '; scan ' + Convert(varchar(12), MSGF.scan) + '; charge ' + 
			                Convert(varchar(12), MSGF.charge) + '; job ' + @jobstr
			FROM #Tmp_Unique_Records UR
			     INNER JOIN #Tmp_Peptide_Import TPI
			       ON UR.Result_ID = TPI.Result_ID
			     INNER JOIN #Tmp_MSGF_Results MSGF
			       ON TPI.Result_ID = MSGF.Result_ID
			WHERE MSGF.SpecProbNote LIKE '%N/A:%'
			ORDER BY MSGF.Scan
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
		End
	End

	If @myError = 0 And @numAddedMSGFScores < @numAddedDiscScores
	Begin -- <b>
		-----------------------------------------------
		-- If a peptide is mapped to multiple proteins in #Tmp_Peptide_Import, then
		--  #Tmp_MSGF_Results may only contain the results for one of the entries
		-- The following query helps account for this by linking #Tmp_Peptide_Import to itself,
		--  along with linking it to #Tmp_Unique_Records and #Tmp_MSGF_Results
		-- 
		-- This situation was required for Peptide Prophet results; it may never occur for MSGF data
		--
		-- Note also that not all of the loaded data will have MSGF values due to filtering that occurs prior to running MSGF
		-----------------------------------------------

		TRUNCATE TABLE #Tmp_MSGF_DataByPeptideID

		INSERT INTO #Tmp_MSGF_DataByPeptideID (Peptide_ID, SpecProb)
		SELECT DISTINCT UR.Peptide_ID_New,
		                MSGF.SpecProb
		FROM #Tmp_Unique_Records UR
		     INNER JOIN #Tmp_Peptide_Import_MatchedEntries TPIM
		       ON UR.Result_ID = TPIM.Result_ID2
		     INNER JOIN #Tmp_MSGF_Results MSGF
		       ON TPIM.Result_ID1 = MSGF.Result_ID
		WHERE UR.Peptide_ID_New IN ( SELECT SD.Peptide_ID
		                             FROM T_Peptides Pep
		                                  INNER JOIN T_Score_Discriminant SD
		                                    ON Pep.Peptide_ID = SD.Peptide_ID
		                             WHERE (Pep.Analysis_ID = @Job) AND
		                                   (SD.MSGF_SpecProb IS NULL) )
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
			set @message = 'Error populating #Tmp_MSGF_DataByPeptideID with additional MSGF results for job ' + @jobStr
		Else
		Begin
			UPDATE T_Score_Discriminant
			SET MSGF_SpecProb = MD.SpecProb
			FROM T_Score_Discriminant SD
			     INNER JOIN #Tmp_MSGF_DataByPeptideID MD
			       ON SD.Peptide_ID = MD.Peptide_ID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
				set @message = 'Error updating T_Score_Discriminant with additional MSGF results for job ' + @jobStr
		End
		--
		if @myError <> 0
			goto Done

		Set @numAddedMSGFScores = @numAddedMSGFScores + @myRowCount

		Set @LogMessage = 'Updated missing MSGF values in T_Score_Discriminant for ' + Convert(varchar(12), @myRowCount) + ' rows using a multi-column join involving #Tmp_Peptide_Import_MatchedEntries'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'StoreMSGFValues'


		SELECT	@RowCountTotal = COUNT(*),
				@RowCountNull = SUM(CASE WHEN SD.MSGF_SpecProb IS NULL	THEN 1 ELSE 0 END)
		FROM T_Score_Discriminant SD INNER JOIN
			 #Tmp_Unique_Records UR ON SD.Peptide_ID = UR.Peptide_ID_New


		If @RowCountNull > 0
		Begin -- <c>
			set @message = 'Job ' + @jobStr + ' has ' + Convert(varchar(12), @RowCountNull) + ' out of ' + Convert(varchar(12), @RowCountTotal) + ' rows in T_Score_Discriminant with null MSGF values'
			set @MessageType = 'Warning'

			execute PostLogEntry @MessageType, @message, 'StoreMSGFValues'
			Set @message = ''
		End -- </c>
	End -- </b>


Done:
	return @myError

GO

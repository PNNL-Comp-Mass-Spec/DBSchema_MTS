/****** Object:  StoredProcedure [dbo].[StorePeptideProphetValues] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure StorePeptideProphetValues
/****************************************************
**
**	Desc: 
**		Copies data from #Tmp_PepProphet_Results into T_Score_Discriminant
**		Intended to be called from LoadSequestPeptidesBulk, LoadXTandemPeptidesBulk, and LoadInspectPeptidesBulk
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/23/2010 mem - Initial Version (refactored code from LoadSequestPeptidesBulk)
**			12/23/2011 mem - Added a where clause when updating T_Score_Discriminant to avoid unnecessary updates
**						   - Added parameter @UpdateExistingData
**			12/29/2011 mem - Added an index on #Tmp_PepProphet_DataByPeptideID
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@Job int,
	@numAddedDiscScores int,
	@LogLevel int,
	@LogMessage varchar(512),
	@UsingPhysicalTempTables tinyint,
	@UpdateExistingData tinyint,			-- If 1, then will change Peptide_Prophet_FScore and Peptide_Prophet_Probability to Null for entries with Null values for Peptide_ID in #Tmp_Unique_Records
	@infoOnly tinyint = 0,
	@message varchar(512)='' output
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	declare @numAddedPepProphetScores int = 0
	declare @jobStr varchar(12)

	declare @RowCountTotal int
	declare @RowCountNull int
	declare @RowCountNullCharge5OrLess int
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
		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_PepProphet_DataByPeptideID]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_PepProphet_DataByPeptideID]
	End
	
	CREATE TABLE #Tmp_PepProphet_DataByPeptideID (
		Peptide_ID int NOT NULL,				-- Corresponds to #Tmp_Unique_Records.Peptide_ID_New and to T_Peptides.Peptide_ID
		FScore real NOT NULL,
		Probability real NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_PepProphet_DataByPeptideID ON #Tmp_PepProphet_DataByPeptideID (Peptide_ID)

	-----------------------------------------------
	-- Copy selected contents of #Tmp_PepProphet_Results
	-- into T_Score_Discriminant
	-----------------------------------------------
	--
	/*
	** Old, one-step query
		UPDATE T_Score_Discriminant
		SET Peptide_Prophet_FScore = PPR.FScore,
			Peptide_Prophet_Probability = PPR.Probability
		FROM T_Score_Discriminant SD INNER JOIN 
			#Tmp_Unique_Records UR ON SD.Peptide_ID = UR.Peptide_ID_New INNER JOIN
			#Tmp_Peptide_Import TPI ON UR.Result_ID = TPI.Result_ID INNER JOIN
			#Tmp_PepProphet_Results PPR ON TPI.Result_ID = PPR.Result_ID
	--			
	*/
	
	INSERT INTO #Tmp_PepProphet_DataByPeptideID (Peptide_ID, FScore, Probability)
	SELECT UR.Peptide_ID_New,
	       PPR.FScore,
	       PPR.Probability
	FROM #Tmp_Unique_Records UR
	     INNER JOIN #Tmp_Peptide_Import TPI
	       ON UR.Result_ID = TPI.Result_ID
	     INNER JOIN #Tmp_PepProphet_Results PPR
	       ON TPI.Result_ID = PPR.Result_ID
	WHERE NOT UR.Peptide_ID_New Is Null
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
		set @message = 'Error populating #Tmp_PepProphet_DataByPeptideID with Peptide Prophet results for job ' + @jobStr
	Else
	Begin -- <a>
		UPDATE T_Score_Discriminant
		SET Peptide_Prophet_FScore = PPD.FScore,
		    Peptide_Prophet_Probability = PPD.Probability
		FROM T_Score_Discriminant SD
		     INNER JOIN #Tmp_PepProphet_DataByPeptideID PPD
		       ON SD.Peptide_ID = PPD.Peptide_ID
		WHERE IsNull(Peptide_Prophet_FScore,-9999) <> PPD.FScore OR
		      IsNull(Peptide_Prophet_Probability,-1) <> PPD.Probability
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
			set @message = 'Error updating T_Score_Discriminant with Peptide Prophet results for job ' + @jobStr
		Else
		Begin
			Set @numAddedPepProphetScores = @myRowCount
			
			If IsNull(@UpdateExistingData, 0) > 0
			Begin
				-- Change FScore and Probability to Null for entries that are in T_Score_Discriminant
				-- yet are not in #Tmp_PepProphet_DataByPeptideID
				UPDATE T_Score_Discriminant
				SET Peptide_Prophet_FScore = NULL,
				    Peptide_Prophet_Probability = NULL
				FROM T_Score_Discriminant SD
				     INNER JOIN T_Peptides Pep
				       ON SD.Peptide_ID = Pep.Peptide_ID
				     LEFT OUTER JOIN #Tmp_PepProphet_DataByPeptideID PPD
				       ON SD.Peptide_ID = PPD.Peptide_ID
				WHERE Pep.Job = @Job AND
				      PPD.FScore IS NULL AND
				      (NOT SD.Peptide_Prophet_FScore IS NULL OR
				       NOT SD.Peptide_Prophet_Probability IS NULL)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myRowCount > 0
				Begin
					Set @LogMessage = 'Changed Peptide Prophet values to Null for ' + Convert(varchar(12), @myRowCount) + ' entries for job ' + @jobStr + ' since not present in newly loaded results'
					execute PostLogEntry 'Warning', @LogMessage, 'StorePeptideProphetValues'
				End
			End
		End
		
	End -- </a>
	--
	if @myError <> 0
	Begin
		execute PostLogEntry 'Error', @message, 'StorePeptideProphetValues'
		Set @numAddedPepProphetScores = 0
	End
	Else
	Begin
		Set @LogMessage = 'Updated peptide prophet values for ' + Convert(varchar(12), @numAddedPepProphetScores) + ' rows'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'StorePeptideProphetValues'
	End
	
	If @myError = 0 And @numAddedPepProphetScores < @numAddedDiscScores
	Begin -- <b>
		-----------------------------------------------
		-- If a peptide is mapped to multiple proteins in #Tmp_Peptide_Import, then
		--  #Tmp_PepProphet_Results may only contain the results for one of the entries
		-- The following query helps account for this by linking #Tmp_Peptide_Import to itself,
		--  along with linking it to #Tmp_Unique_Records and #Tmp_PepProphet_Results
		-- 
		-- This situation should only be true for a handful of jobs analyzed in July 2006
		--  therefore, we'll post a warning entry to the log if this situation is encountered
		--
		-- Note, however, that Peptide Prophet values are not computed for charge states of 6 or higher,
		-- so data with charge state 6 or higher will not have values present in #Tmp_PepProphet_Results
		--
		-- As with the above Update query, the original query, which tied together numerous tables, becomes
		--  excessively slow when T_Score_Discriminant becomes large.
		-- Therefore, we are again populating #Tmp_PepProphet_DataByPeptideID, then copying that data to T_Score_Discriminant
		-----------------------------------------------
	
		/*
		** Old, one-step query
			
			UPDATE T_Score_Discriminant
			SET Peptide_Prophet_FScore = PPR.FScore,
				Peptide_Prophet_Probability = PPR.Probability
			FROM T_Score_Discriminant SD INNER JOIN
				#Tmp_Unique_Records UR ON SD.Peptide_ID = UR.Peptide_ID_New INNER JOIN
				#Tmp_Peptide_Import TPI2 ON UR.Result_ID = TPI2.Result_ID INNER JOIN
				#Tmp_Peptide_Import TPI ON 
					TPI2.Scan_Number = TPI.Scan_Number AND 
					TPI2.Charge_State = TPI.Charge_State AND 
					TPI2.Peptide_Hyperscore = TPI.Peptide_Hyperscore AND 
					TPI2.DeltaCn2 = TPI.DeltaCn2 AND 
					TPI2.Peptide = TPI.Peptide AND 
					TPI2.Result_ID <> TPI.Result_ID INNER JOIN
				#Tmp_PepProphet_Results PPR ON TPI.Result_ID = PPR.Result_ID
		*/

		TRUNCATE TABLE #Tmp_PepProphet_DataByPeptideID

		INSERT INTO #Tmp_PepProphet_DataByPeptideID (Peptide_ID, FSCore, Probability)
		SELECT DISTINCT UR.Peptide_ID_New,
		                PPR.FScore,
		                PPR.Probability
		FROM #Tmp_Unique_Records UR
		 INNER JOIN #Tmp_Peptide_Import_MatchedEntries TPIM
		       ON UR.Result_ID = TPIM.Result_ID2
		     INNER JOIN #Tmp_PepProphet_Results PPR
		       ON TPIM.Result_ID1 = PPR.Result_ID
		WHERE UR.Peptide_ID_New IN ( SELECT SD.Peptide_ID
		 FROM T_Peptides Pep
		                      INNER JOIN T_Score_Discriminant SD
		                                    ON Pep.Peptide_ID = SD.Peptide_ID
		                             WHERE (Pep.Job = @Job) AND
		                                   (SD.Peptide_Prophet_FScore IS NULL) )
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
			set @message = 'Error populating #Tmp_PepProphet_DataByPeptideID with additional Peptide Prophet results for job ' + @jobStr
		Else
		Begin
			UPDATE T_Score_Discriminant
			SET Peptide_Prophet_FScore = PPD.FScore,
			    Peptide_Prophet_Probability = PPD.Probability
			FROM T_Score_Discriminant SD
			     INNER JOIN #Tmp_PepProphet_DataByPeptideID PPD
			       ON SD.Peptide_ID = PPD.Peptide_ID
			WHERE IsNull(Peptide_Prophet_FScore,-9999) <> PPD.FScore OR
		      IsNull(Peptide_Prophet_Probability,-1) <> PPD.Probability
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
				set @message = 'Error updating T_Score_Discriminant with additional Peptide Prophet results for job ' + @jobStr
		End
		--
		if @myError <> 0
			goto Done

		Set @numAddedPepProphetScores = @numAddedPepProphetScores + @myRowCount

		Set @LogMessage = 'Updated missing peptide prophet values in T_Score_Discriminant for ' + Convert(varchar(12), @myRowCount) + ' rows using a multi-column join involving #Tmp_Peptide_Import'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'StorePeptideProphetValues'


		SELECT	@RowCountTotal = COUNT(*),
				@RowCountNull = SUM(CASE WHEN SD.Peptide_Prophet_FScore IS NULL OR 
												SD.Peptide_Prophet_Probability IS NULL 
									THEN 1 ELSE 0 END),
				@RowCountNullCharge5OrLess = SUM(CASE WHEN UR.Charge_State <= 5 AND (
													SD.Peptide_Prophet_FScore IS NULL OR 
													SD.Peptide_Prophet_Probability IS NULL)
									THEN 1 ELSE 0 END)
		FROM T_Score_Discriminant SD INNER JOIN
				#Tmp_Unique_Records UR ON SD.Peptide_ID = UR.Peptide_ID_New


		If @RowCountNull > 0
		Begin -- <c>
			set @message = 'Job ' + @jobStr + ' has ' + Convert(varchar(12), @RowCountNull) + ' out of ' + Convert(varchar(12), @RowCountTotal) + ' rows in T_Score_Discriminant with null peptide prophet FScore or Probability values'

			If @RowCountNullCharge5OrLess = 0
			Begin
				set @message = @message + '; however, all have charge state 6+ or higher'
				set @MessageType = 'Warning'
			End
			Else
			Begin
				set @message = @message + '; furthermore, ' + Convert(varchar(12), @RowCountNullCharge5OrLess) + ' of the rows have charge state 5+ or less'
				set @MessageType = 'Error'
			End

			execute PostLogEntry @MessageType, @message, 'StorePeptideProphetValues'
			Set @message = ''
		End -- </c>
	End -- </b>


Done:
	return @myError

GO

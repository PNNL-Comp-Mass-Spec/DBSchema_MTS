/****** Object:  StoredProcedure [dbo].[FindMSMSPeptidesPTDBWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.FindMSMSPeptidesPTDBWork
/****************************************************
**
**	Desc: 
**		Searches one or more PT databases to find the confidently identified peptides for one or more proteins.
**
**		The calling procedure must create these tables:
**			#Tmp_PeptideResultsForBatch
**			#Tmp_ProteinFilterCurrent
**			#Tmp_PeptideFilterCurrent
**			#Tmp_ExecutionTimes
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	07/11/2012 mem - Initial version
**			01/09/2013 mem - Added column Peak_SN_Ratio_Max
**			05/10/2013 mem - Factored out code from FindMSMSPeptidesPTDB; results are returned via temporary tables
**
*****************************************************/
(
	@DBPath varchar(256),
	@MinimumCleavageState tinyint = 1,			-- 0 means any peptide; 1 means partially or fully tryptic, 2 means fully tryptic
	@MSGFSpecProb float = 1E-10,	
	@AnalysisToolWhereClause varchar(max) = '',
	@ExperimentsWhereClause varchar(max) = '',
	@previewSql tinyint = 0,					-- Preview the Sql used
	@debugMode tinyint = 0,
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @S varchar(max)
	Declare @StartTime DateTime
	Declare @EndTime DateTime
	
	Declare @UseProteinFilter tinyint = 0
	Declare @UsePeptideFilter tinyint = 0
	
	---------------------------------------------------
	-- Create some temporary tables
	---------------------------------------------------
	
	CREATE TABLE #Tmp_MaxAreaQ (
		Seq_ID int NOT NULL,
		Charge_State smallint NOT NULL,
		Peak_Area_Max real NULL
	)
	
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_MaxAreaQ
	  ON #Tmp_MaxAreaQ (Seq_ID, Charge_State)
	  
	  
	CREATE TABLE #Tmp_BestChargeQ (
		Seq_ID       int NOT NULL,
		Charge_State smallint NOT NULL
	)				
	
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_BestChargeQ
	  ON #Tmp_BestChargeQ (Seq_ID, Charge_State)
	  
	CREATE TABLE #Tmp_BestResultsQ (
	    Dataset_ID              int NOT NULL,
	    Seq_ID                  int NULL,
	    Scan_Number             int NULL,
	    Scan_Time_Peak_Apex     real NULL,
	    Normalized_Elution_Time real NULL,
	    Peak_Area               real NULL,
	    Peak_SN_Ratio           real NULL,
	    DelM_PPM                real NULL,
	    MSGF_SpecProb           real NULL,
	    Peptide_ID              int NULL,
	    Peptide                 varchar(850) NULL
	)

	CREATE NONCLUSTERED INDEX #IX_Tmp_BestResultsQ
	  ON #Tmp_BestResultsQ (Dataset_ID, Seq_ID)
		
	If Exists (SELECT * FROM #Tmp_ProteinFilterCurrent)
		Set @UseProteinFilter = 1

	If Exists (SELECT * FROM #Tmp_PeptideFilterCurrent)
		Set @UsePeptideFilter = 1
	
	If @UseProteinFilter = 0 And @UsePeptideFilter = 0
	Begin
		Set @message = 'No proteins found in #Tmp_ProteinFilterCurrent and no peptides found in #Tmp_PeptideFilterCurrent; unable to continue'
		Set @myError = 50013
		goto Done
	End
	
	---------------------------------------------------
	-- Find matching peptides using the specified filters
	-- Note that for performance reasons we're using Seq.Cleavage_State_Max and not PPM.Cleavage_State
	---------------------------------------------------
	--

	Set @S = ''
	Set @S = @S + ' INSERT INTO #Tmp_PeptideResultsForBatch (Ref_ID, Seq_ID, Charge_State, Cleavage_State, Total_PSMs)'
	Set @S = @S + ' SELECT Ref_ID, Seq_ID, Charge_State, Cleavage_State, COUNT(*) AS Total_PSMs'
	Set @S = @S + ' FROM ( SELECT Prot.Ref_ID,'
	Set @S = @S +               ' Pep.Seq_ID,'
	Set @S = @S +               ' Pep.Charge_State,'
	Set @S = @S +               ' TAD.Dataset_ID,'
	Set @S = @S +               ' Pep.Scan_Number,'
	Set @S = @S +               ' Seq.Cleavage_State_Max AS Cleavage_State'
	Set @S = @S +        ' FROM  ' +          @DBPath + '.dbo.T_Peptides Pep'
	Set @S = @S +            ' INNER JOIN ' + @DBPath + '.dbo.T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
	Set @S = @S +            ' INNER JOIN ' + @DBPath + '.dbo.T_Analysis_Description TAD ON Pep.Job = TAD.Job'
	Set @S = @S +            ' INNER JOIN ' + @DBPath + '.dbo.T_Peptide_to_Protein_Map PPM ON Pep.Peptide_ID = PPM.Peptide_ID'
	Set @S = @S +            ' INNER JOIN ' + @DBPath + '.dbo.T_Proteins Prot ON PPM.Ref_ID = Prot.Ref_ID'
	Set @S = @S +            ' INNER JOIN ' + @DBPath + '.dbo.T_Sequence Seq ON Pep.Seq_ID = Seq.Seq_ID'
	
	If @UseProteinFilter = 1
		Set @S = @S +        ' INNER JOIN #Tmp_ProteinFilterCurrent ON Prot.Reference = #Tmp_ProteinFilterCurrent.Reference'
	
	If @UsePeptideFilter = 1
		Set @S = @S +        ' INNER JOIN #Tmp_PeptideFilterCurrent ON Seq.Clean_Sequence = #Tmp_PeptideFilterCurrent.CleanSequence'
		
	Set @S = @S +        ' WHERE ( Seq.Cleavage_State_Max >= ' + Convert(varchar(6), @MinimumCleavageState)
	Set @S = @S +            ' AND IsNull(SD.MSGF_SpecProb,10) <= ' + Convert(varchar(24), @MSGFSpecProb) + ')'

	If @AnalysisToolWhereClause <> ''
		Set @S = @S +       ' AND (' + @AnalysisToolWhereClause + ')'
		
	If @ExperimentsWhereClause <> ''
		Set @S = @S +       ' AND (' + @ExperimentsWhereClause + ')'
			
	Set @S = @S +        ' GROUP BY Prot.Ref_ID, Pep.Seq_ID, Pep.Charge_State, TAD.Dataset_ID, '
	Set @S = @S +                 ' Pep.Scan_Number, Seq.Cleavage_State_Max ) SourceQ'
	Set @S = @S + ' GROUP BY Ref_ID, Seq_ID, Charge_State, Cleavage_State'

	Set @StartTime = GetDate()
	--
	If @PreviewSql <> 0
		Print @S
	Else
		Exec (@S)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Set @EndTime = GetDate()

	INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
	Values (@DBPath, 'INSERT INTO #Tmp_PeptideResultsForBatch', @StartTime, @EndTime)


	If @myRowCount > 0 OR @PreviewSql <> 0
	Begin -- <c>
		---------------------------------------------------
		-- Determine the best charge state for each Seq_ID
		-- Choose the Charge with the most PSMs, and, if a tie, the one with the highest Peak_Area
		-- Do this in two steps to avoid table-locking issues with large databases				
		---------------------------------------------------
		--
		-- First determine the maximum peak area for each charge state for each peptide
		--
		Set @S = ''
		Set @S = @S +  ' INSERT INTO #Tmp_MaxAreaQ (Seq_ID, Charge_State, Peak_Area_Max)'
		Set @S = @S +  ' SELECT Pep.Seq_ID,'
		Set @S = @S +         ' Pep.Charge_State,'
		Set @S = @S +         ' MAX(Pep.Peak_Area) AS Peak_Area_Max'
		Set @S = @S +  ' FROM #Tmp_PeptideResultsForBatch PR '
		Set @S = @S +      ' INNER JOIN ' + @DBPath + '.dbo.T_Peptides Pep ON Pep.Seq_ID = PR.Seq_ID AND Pep.Charge_State = PR.Charge_State'
		Set @S = @S +      ' INNER JOIN ' + @DBPath + '.dbo.T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +  ' WHERE IsNull(SD.MSGF_SpecProb,10) <= ' + Convert(varchar(24), @MSGFSpecProb)
		Set @S = @S +  ' GROUP BY Pep.Seq_ID, Pep.Charge_State'

        Set @StartTime = GetDate()
		--
        If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		Set @EndTime = GetDate()

		INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
		Values (@DBPath, 'Compute Peak_Area_Max for each Seq_ID', @StartTime, @EndTime)


		-- Now populate the BestChargeQ table
		--
		INSERT INTO #Tmp_BestChargeQ (Seq_ID, Charge_State )
		SELECT Seq_ID, Charge_State
		FROM ( SELECT PR.Seq_ID,
		              PR.Charge_State,
		              ROW_NUMBER() OVER ( PARTITION BY PR.Seq_ID ORDER BY PR.Total_PSMs DESC, AreaQ.Peak_Area_Max DESC ) AS PSM_Rank
		       FROM #Tmp_PeptideResultsForBatch PR
		            INNER JOIN #Tmp_MaxAreaQ AreaQ
		              ON PR.Seq_ID = AreaQ.Seq_ID AND
		                 PR.Charge_State = AreaQ.Charge_State 
             ) RankQ
		WHERE PSM_Rank = 1

		If @PreviewSql=1
		Begin
			Set @S = ''
			Set @S = @S +  ' INSERT INTO #Tmp_BestChargeQ (Seq_ID, Charge_State )'
			Set @S = @S +  ' SELECT Seq_ID, Charge_State'
			Set @S = @S +  ' FROM ( SELECT PR.Seq_ID,'
			Set @S = @S +                ' PR.Charge_State,'
			Set @S = @S +                ' ROW_NUMBER() OVER ( PARTITION BY PR.Seq_ID ORDER BY PR.Total_PSMs DESC, AreaQ.Peak_Area_Max DESC ) AS PSM_Rank'
			Set @S = @S +         ' FROM #Tmp_PeptideResultsForBatch PR'
			Set @S = @S +              ' INNER JOIN #Tmp_MaxAreaQ AreaQ'
			Set @S = @S +                ' ON PR.Seq_ID = AreaQ.Seq_ID AND'
			Set @S = @S +                   ' PR.Charge_State = AreaQ.Charge_State '
			Set @S = @S +        ' ) RankQ'
			Set @S = @S +  ' WHERE PSM_Rank = 1'

			Print @S
		End

		---------------------------------------------------
		-- Compute and store the averages for each peptide
		---------------------------------------------------
		--			
		Set @S = ''
		Set @S = @S +  ' UPDATE target'
		Set @S = @S +  ' SET Dataset_Count = StatsQ.Dataset_Count,'
		Set @S = @S +      ' Normalized_Elution_Time_Avg = StatsQ.Normalized_Elution_Time_Avg,'
		Set @S = @S +      ' Peak_Area_Avg = StatsQ.Peak_Area_Avg,'
		Set @S = @S +      ' Peak_SN_Ratio_Avg = StatsQ.Peak_SN_Ratio_Avg,'
		Set @S = @S +      ' Peak_SN_Ratio_Max = StatsQ.Peak_SN_Ratio_Max,'
		Set @S = @S +      ' DelM_PPM_Avg = StatsQ.DelM_PPM_Avg,'
		Set @S = @S +      ' MSGF_SpecProb_Minimum = StatsQ.MSGF_SpecProb_Minimum'
		Set @S = @S +  ' FROM ( SELECT Ref_ID,'
		Set @S = @S +                ' Seq_ID,'
		Set @S = @S +                ' Charge_State,'
		Set @S = @S +                ' COUNT(DISTINCT Dataset_ID) AS Dataset_Count,'
		Set @S = @S +                ' AVG(GANET_Obs) AS Normalized_Elution_Time_Avg,'
		Set @S = @S +                ' AVG(Peak_Area) AS Peak_Area_Avg,'
		Set @S = @S +                ' AVG(Peak_SN_Ratio) AS Peak_SN_Ratio_Avg,'
		Set @S = @S +                ' MAX(Peak_SN_Ratio) AS Peak_SN_Ratio_Max,'
		Set @S = @S +                ' AVG(DelM_PPM) AS DelM_PPM_Avg,'
		Set @S = @S +                ' MIN(MSGF_SpecProb) AS MSGF_SpecProb_Minimum'
		Set @S = @S +         ' FROM ( SELECT PR.Ref_ID, PR.Seq_ID, BCQ.Charge_State,'
		Set @S = @S +                       ' TAD.Dataset_ID, Pep.Scan_Number, Pep.GANET_Obs,'
		Set @S = @S +                       ' Pep.Peak_Area, Pep.Peak_SN_Ratio, Pep.DelM_PPM, SD.MSGF_SpecProb'
		Set @S = @S +               '  FROM #Tmp_PeptideResultsForBatch PR'
		Set @S = @S +                     ' INNER JOIN #Tmp_BestChargeQ BCQ ON PR.Seq_ID = BCQ.Seq_ID AND PR.Charge_State = BCQ.Charge_State'
		Set @S = @S +                     ' INNER JOIN ' + @DBPath + '.dbo.T_Peptides Pep ON PR.Seq_ID = Pep.Seq_ID'
		Set @S = @S +                     ' INNER JOIN ' + @DBPath + '.dbo.T_Peptide_to_Protein_Map PPM ON Pep.Peptide_ID = PPM.Peptide_ID AND PR.Ref_ID = PPM.Ref_ID'
		Set @S = @S +                     ' INNER JOIN ' + @DBPath + '.dbo.T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                     ' INNER JOIN ' + @DBPath + '.dbo.T_Analysis_Description TAD ON Pep.Job = TAD.Job'
		Set @S = @S +                ' WHERE IsNull(SD.MSGF_SpecProb,10) <= ' + Convert(varchar(24), @MSGFSpecProb)
		
		If @AnalysisToolWhereClause <> ''
			Set @S = @S +                  ' AND (' + @AnalysisToolWhereClause + ')'
		
		If @ExperimentsWhereClause <> ''
			Set @S = @S +                  ' AND (' + @ExperimentsWhereClause + ')'

		Set @S = @S +                ' GROUP BY PR.Ref_ID, PR.Seq_ID, BCQ.Charge_State, TAD.Dataset_ID, Pep.Scan_Number, Pep.GANET_Obs, '
		Set @S = @S +            ' Pep.Peak_Area, Pep.Peak_SN_Ratio, Pep.DelM_PPM, SD.MSGF_SpecProb '
		Set @S = @S +           '  ) SourceQ'
		Set @S = @S +       '   GROUP BY Ref_ID, Seq_ID, Charge_State '
		Set @S = @S +       ' ) StatsQ'
		Set @S = @S +       ' INNER JOIN #Tmp_PeptideResultsForBatch Target'
		Set @S = @S +       '   ON StatsQ.Ref_ID = Target.Ref_ID AND'
		Set @S = @S +            ' StatsQ.Seq_ID = Target.Seq_ID AND'
		Set @S = @S +            ' StatsQ.Charge_State = Target.Charge_State'


	    Set @StartTime = GetDate()
		--
        If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		Set @EndTime = GetDate()

		INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
		Values (@DBPath, 'Compute averages for each Seq_ID', @StartTime, @EndTime)


		---------------------------------------------------
		-- Find the dataset and scan info for the "best" observation
		---------------------------------------------------
		--			
		Set @S = ''
		Set @S = @S +  ' INSERT INTO #Tmp_BestResultsQ ('
		Set @S = @S +     ' Dataset_ID, Seq_ID, Scan_Number, Scan_Time_Peak_Apex, Normalized_Elution_Time, '
		Set @S = @S +     ' Peak_Area, Peak_SN_Ratio, DelM_PPM, MSGF_SpecProb, Peptide_ID, Peptide)'
		Set @S = @S +  ' SELECT Dataset_ID, Seq_ID, Scan_Number, Scan_Time_Peak_Apex, Normalized_Elution_Time,'
		Set @S = @S +         ' Peak_Area, Peak_SN_Ratio, DelM_PPM, MSGF_SpecProb, Peptide_ID, Peptide'
		Set @S = @S +  ' FROM ( SELECT TAD.Dataset_ID, Pep.Seq_ID, Pep.Scan_Number, Pep.Scan_Time_Peak_Apex, Pep.GANET_Obs AS Normalized_Elution_Time,'
		Set @S = @S +                ' Pep.Peak_Area, Pep.Peak_SN_Ratio, Pep.DelM_PPM, SD.MSGF_SpecProb, Pep.Peptide_ID, Pep.Peptide,'
		Set @S = @S +                ' Row_Number() OVER (Partition By TAD.Dataset_ID, Pep.Seq_ID Order By Pep.Peak_Area DESC, SD.MSGF_SpecProb) AS PeakAreaRank'
		Set @S = @S +         ' FROM #Tmp_PeptideResultsForBatch PR'
		Set @S = @S +             ' INNER JOIN #Tmp_BestChargeQ BCQ ON PR.Seq_ID = BCQ.Seq_ID AND PR.Charge_State = BCQ.Charge_State'
		Set @S = @S +             ' INNER JOIN ' + @DBPath + '.dbo.T_Peptides Pep ON PR.Seq_ID = Pep.Seq_ID'
		Set @S = @S +             ' INNER JOIN ' + @DBPath + '.dbo.T_Peptide_to_Protein_Map PPM ON Pep.Peptide_ID = PPM.Peptide_ID AND PR.Ref_ID = PPM.Ref_ID'
		Set @S = @S +             ' INNER JOIN ' + @DBPath + '.dbo.T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +             ' INNER JOIN ' + @DBPath + '.dbo.T_Analysis_Description TAD ON Pep.Job = TAD.Job'
		Set @S = @S +         ' WHERE IsNull(SD.MSGF_SpecProb, 10) <= ' + Convert(varchar(24), @MSGFSpecProb)
		Set @S = @S +         '       AND NOT PR.Dataset_Count IS NULL '
		
		If @AnalysisToolWhereClause <> ''
			Set @S = @S + ' AND (' + @AnalysisToolWhereClause + ')'
		
		If @ExperimentsWhereClause <> ''
			Set @S = @S + ' AND (' + @ExperimentsWhereClause + ')'
		
		Set @S = @S +  ' ) LookupQ'
		Set @S = @S +  ' WHERE PeakAreaRank = 1'

        Set @StartTime = GetDate()
		--
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		Set @EndTime = GetDate()

		INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
		Values (@DBPath, 'Compute Stats for Best Result', @StartTime, @EndTime)
		

		---------------------------------------------------
		-- Store the "best" observation in #Tmp_PeptideResultsForBatch
		---------------------------------------------------
		--			
		Set @S = ''
		Set @S = @S + ' UPDATE Target'
		Set @S = @S + ' SET Dataset_ID = BestResultsQ.Dataset_ID,'
		Set @S = @S +     ' Scan_Highest_Abundance = BestResultsQ.Scan_Number,'
		Set @S = @S +     ' Scan_Time_Peak_Apex = BestResultsQ.Scan_Time_Peak_Apex,'
		Set @S = @S +     ' Normalized_Elution_Time = BestResultsQ.Normalized_Elution_Time,'
		Set @S = @S +     ' Peak_Area = BestResultsQ.Peak_Area,'
		Set @S = @S +     ' Peak_SN_Ratio = BestResultsQ.Peak_SN_Ratio,'
		Set @S = @S +     ' DelM_PPM = BestResultsQ.DelM_PPM,'
		Set @S = @S +     ' MSGF_SpecProb = BestResultsQ.MSGF_SpecProb,'
		Set @S = @S +     ' PeptideID_Highest_Abundance = BestResultsQ.Peptide_ID,'
		Set @S = @S +     ' Peptide = BestResultsQ.Peptide'
		Set @S = @S + ' FROM #Tmp_PeptideResultsForBatch Target'
		Set @S = @S + ' INNER JOIN #Tmp_BestResultsQ BestResultsQ'
		Set @S = @S +      ' ON BestResultsQ.Seq_ID = Target.Seq_ID'
		Set @S = @S + ' WHERE NOT Target.Dataset_Count IS NULL'
		
		Set @StartTime = GetDate()
		--
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		Set @EndTime = GetDate()

		INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
		Values (@DBPath, 'Store Stats for Best Result', @StartTime, @EndTime)
		
		-- Update the Protein_count column
							
		Set @S = ''
		Set @S = @S + ' UPDATE Target'
		Set @S = @S + ' SET Protein_Count = CountQ.Protein_Count'
		Set @S = @S + ' FROM #Tmp_PeptideResultsForBatch Target'
		Set @S = @S +      ' INNER JOIN ( SELECT PR.Seq_ID, COUNT(DISTINCT PPM.Ref_ID) AS Protein_Count'
		Set @S = @S +                   ' FROM #Tmp_PeptideResultsForBatch PR'
		Set @S = @S +                        ' INNER JOIN ' + @DBPath + '.dbo.T_Peptide_to_Protein_Map PPM ON PR.PeptideID_Highest_Abundance = PPM.Peptide_ID'
		Set @S = @S +                   ' GROUP BY PR.Seq_ID '
		Set @S = @S +                 ' ) CountQ'
		Set @S = @S +   ' ON CountQ.Seq_ID = Target.Seq_ID'
				
		Set @StartTime = GetDate()
		--		 
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		Set @EndTime = GetDate()

		INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
		Values (@DBPath, 'Compute Protein_Count for each Seq_ID', @StartTime, @EndTime)

	End -- </c>
			
Done:
	If @myError <> 0
	Begin
		If @previewSql <> 0
			Select @myError as Error_Code, @Message as Error_Message
		Else
			Print @Message
	End

	return @myError

GO

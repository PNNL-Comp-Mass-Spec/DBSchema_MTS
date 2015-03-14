/****** Object:  StoredProcedure [dbo].[ComparePeptideHitResultsAggregateWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.ComparePeptideHitResultsAggregateWork
/****************************************************
**
**	Desc:	Compares the peptide hit results for two jobs (or two sets of jobs) 
**			as defined in temporary tables #Tmp_OverlapJobList1 and  #Tmp_OverlapJobList2
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	01/07/2013 mem - Initial Version
**			01/28/2013 mem - Added @ReturnOverlapPeptides, @ReturnAllSet1Peptides, @ReturnAllSet2Peptides, @ReturnSet1OnlyPeptides, @ReturnSet2OnlyPeptides, and @PairwiseJobComparisonMode
**    
*****************************************************/
(
	@MSGFSpecProbThreshold real = 1E-10,
	@Set1RecordCount int output,
	@Set2RecordCount int output,
	@OverlapCount int output,
	@ReturnOverlapPeptides tinyint=0,
	@ReturnAllSet1Peptides tinyint=0,
	@ReturnAllSet2Peptides tinyint=0,
	@ReturnSet1OnlyPeptides tinyint=0,
	@ReturnSet2OnlyPeptides tinyint=0,
	@PairwiseJobComparisonMode tinyint=0,
	@InfoOnly tinyint = 0
)
AS
	Set NoCount On
	
	-------------------------------------------
	-- Initialize the output parameters
	-------------------------------------------
	--
	Set @Set1RecordCount = 0
	Set @Set2RecordCount = 0
	Set @OverlapCount = 0


	If @infoOnly = 0
	Begin
		CREATE TABLE #Tmp_JobList_Stats1 (
			Datasets int,
			Jobs int,
			Seq_ID int NULL,
			MSGF_SpecProb_Best real NULL
		)

		CREATE INDEX #IX_Tmp_JobList_Stats1_Seq_ID ON #Tmp_JobList_Stats1 (Seq_ID)

		CREATE TABLE #Tmp_JobList_Stats2 (
			Datasets int,
			Jobs int,
			Seq_ID int NULL,
			MSGF_SpecProb_Best real NULL
		)
		CREATE INDEX #IX_Tmp_JobList_Stats2_Seq_ID ON #Tmp_JobList_Stats2 (Seq_ID)
		
		
		-- This table holds the best-scoring observation for each Seq_ID value of the peptides observed in Set1
		CREATE TABLE #Tmp_Peptides_Set1 (
			Dataset_ID int NOT NULL,
			Job int NOT NULL,
			Analysis_Tool varchar(64),
			Scan_Number int NOT NULL,
			Charge_State smallint NULL,
			Seq_ID int NOT NULL,
			MSGF_SpecProb real NULL,
			Peak_Area real NULL,
			Peak_SN_Ratio real NULL,
			Parent_MZ real NULL
		)

		-- This table holds the best-scoring observation for each Seq_ID value of the peptides observed in Set2
		CREATE TABLE #Tmp_Peptides_Set2 (
			Dataset_ID int NOT NULL,
			Job int NOT NULL,
			Analysis_Tool varchar(64),
			Scan_Number int NOT NULL,
			Charge_State smallint NULL,
			Seq_ID int NOT NULL,
			MSGF_SpecProb real NULL,
			Peak_Area real NULL,
			Peak_SN_Ratio real NULL,
			Parent_MZ real NULL
		)
				
		-------------------------------------------
		-- Find the peptides observed in Set1
		-------------------------------------------
		--
		INSERT INTO #Tmp_Peptides_Set1 (Dataset_ID, Job, Analysis_Tool, Scan_Number, Charge_State, Seq_ID, MSGF_SpecProb, Peak_Area, Peak_SN_Ratio, Parent_MZ)
		SELECT Dataset_ID,
		       Job,
		       Analysis_Tool,
		       Scan_Number,
		       Charge_State,
		       Seq_ID,
		       MSGF_SpecProb,
		       Peak_Area, 
		       Peak_SN_Ratio,
		       Parent_MZ
		FROM ( SELECT TAD.Dataset_ID,
		              TAD.Job,
		              TAD.Analysis_Tool,
		              P.Scan_Number,
		              P.Charge_State,
		              P.Seq_ID,
		              SD.MSGF_SpecProb,
		              P.Peak_Area, 
		              P.Peak_SN_Ratio,
		              Row_Number() OVER ( PARTITION BY P.Seq_ID ORDER BY SD.MSGF_SpecProb ) AS ScoreRank,
		              dbo.udfConvoluteMass(P.MH, 1, P.Charge_State) AS Parent_MZ
		       FROM T_Peptides P
		            INNER JOIN T_Analysis_Description TAD
		              ON P.Job = TAD.Job
		            INNER JOIN #Tmp_OverlapJobList1
		              ON TAD.Job = #Tmp_OverlapJobList1.Job
		            INNER JOIN T_Score_Discriminant SD
		              ON P.Peptide_ID = SD.Peptide_ID
		       WHERE NOT Seq_ID IS NULL AND
		             SD.MSGF_SpecProb < @MSGFSpecProbThreshold ) RankQ
		WHERE ScoreRank = 1

		INSERT INTO #Tmp_JobList_Stats1( Datasets,
		         Jobs,
		                                 Seq_ID,
		                                 MSGF_SpecProb_Best )
		SELECT COUNT(DISTINCT Dataset_ID) AS Datasets,
		       COUNT(DISTINCT Job) AS Jobs,
		       Seq_ID,
		       Min(MSGF_SpecProb) AS MSGF_Spec_Prob_Best
		FROM #Tmp_Peptides_Set1
		GROUP BY Seq_ID
		--
		Set @Set1RecordCount = @@RowCount

		-------------------------------------------
		-- Find the Peptides observed in Set2
		-------------------------------------------
		--
		INSERT INTO #Tmp_Peptides_Set2 (Dataset_ID, Job, Analysis_Tool, Scan_Number, Charge_State, Seq_ID, MSGF_SpecProb, Peak_Area, Peak_SN_Ratio, Parent_MZ)
		SELECT Dataset_ID,
		       Job,
		       Analysis_Tool,
		       Scan_Number,
		       Charge_State,
		       Seq_ID,
		       MSGF_SpecProb,
		       Peak_Area, 
		       Peak_SN_Ratio,
		       Parent_MZ
		FROM ( SELECT TAD.Dataset_ID,
		              TAD.Job,
		              TAD.Analysis_Tool,
		              P.Scan_Number,
		              P.Charge_State,
		              P.Seq_ID,
		              SD.MSGF_SpecProb,
		              P.Peak_Area, 
		              P.Peak_SN_Ratio,
		              Row_Number() OVER ( PARTITION BY P.Seq_ID ORDER BY SD.MSGF_SpecProb ) AS ScoreRank,
		              dbo.udfConvoluteMass(P.MH, 1, P.Charge_State) AS Parent_MZ
		       FROM T_Peptides P
		            INNER JOIN T_Analysis_Description TAD
		              ON P.Job = TAD.Job
		            INNER JOIN #Tmp_OverlapJobList2
		              ON TAD.Job = #Tmp_OverlapJobList2.Job
		            INNER JOIN T_Score_Discriminant SD
		              ON P.Peptide_ID = SD.Peptide_ID
		       WHERE NOT Seq_ID IS NULL AND
		             SD.MSGF_SpecProb < @MSGFSpecProbThreshold ) RankQ
		WHERE ScoreRank = 1

		
		INSERT INTO #Tmp_JobList_Stats2( Datasets,
		                                 Jobs,
		                                 Seq_ID,
		                                 MSGF_SpecProb_Best )
		SELECT COUNT(DISTINCT Dataset_ID) AS Datasets,
		       COUNT(DISTINCT Job) AS Jobs,
		       Seq_ID,
		       Min(MSGF_SpecProb) AS MSGF_Spec_Prob_Best
		FROM #Tmp_Peptides_Set2 AS RankQ
		GROUP BY Seq_ID
		--
		Set @Set2RecordCount = @@RowCount


		-------------------------------------------
		-- Count the number of overlapping peptides
		-------------------------------------------
		--
		SELECT @OverlapCount = COUNT(*)
		FROM ( SELECT DISTINCT Set2.Seq_ID
		       FROM #Tmp_JobList_Stats2 Set2
		            INNER JOIN #Tmp_JobList_Stats1 Set1
		              ON Set2.Seq_ID = Set1.Seq_ID 
		     ) OverlapQ


	Declare @Category varchar(64)
	Declare @ParwiseJobCompSet1 varchar(32) = 'Set1'
	Declare @ParwiseJobCompSet2 varchar(32) = 'Set2'
	
	If @PairwiseJobComparisonMode <> 0
	Begin
		SELECT TOP 1 @ParwiseJobCompSet1 = 'Job ' + Convert(varchar(12), Job)
		FROM #Tmp_Peptides_Set1

		SELECT TOP 1 @ParwiseJobCompSet2 = 'Job ' + Convert(varchar(12), Job)
		FROM #Tmp_Peptides_Set2
	End	
		-------------------------------------------
		-- Return detailed stats if requested
		-------------------------------------------
		--
		If @ReturnOverlapPeptides <> 0
		Begin
			Set @Category = 'Overlapping Peptides, Best Match'
			
			SELECT @Category AS Category,
			       Set1.Seq_ID,
			       S.Clean_Sequence AS Peptide,
			       Set1.Dataset_ID AS DatasetID_Set1,
			       Set2.Dataset_ID AS DatasetID_Set2,
			       Set1.Job AS Job_Set1,
			       Set2.Job AS Job_Set2,
			       Set1.Scan_Number AS Scan_Set1,
			       Set2.Scan_Number AS Scan_Set2,
			       Set1.Charge_State AS Charge_Set1,
			       Set2.Charge_State AS Charge_Set2,
			       Set1.MSGF_SpecProb AS MSGF_SpecProb_Set1,
			       Set2.MSGF_SpecProb AS MSGF_SpecProb_Set2,
			       Set1.Peak_Area AS Peak_Area_Set1,
			       Set2.Peak_Area AS Peak_Area_Set2,
			       Set1.Peak_SN_Ratio AS Peak_SN_Ratio_Set1,
			       Set2.Peak_SN_Ratio AS Peak_SN_Ratio_Set2,
			       Set1.Parent_MZ AS Parent_MZ_Set1,
			       Set2.Parent_MZ AS Parent_MZ_Set2
			FROM #Tmp_Peptides_Set1 Set1
			     INNER JOIN #Tmp_Peptides_Set2 Set2
			       ON Set1.Seq_ID = Set2.Seq_ID
			     INNER JOIN T_Sequence S
			       ON Set1.Seq_ID = S.Seq_ID
			ORDER BY Set1.Seq_ID
		End

		If @ReturnAllSet1Peptides <> 0
		Begin
			Set @Category =  'All ' + @ParwiseJobCompSet1 + ' Peptides, Best Match'
			
			SELECT @Category AS Category,
			       Pep.Dataset_ID,
			       Pep.Job,
			       Pep.Analysis_Tool,
			       Pep.Scan_Number,
			       Pep.Charge_State,
			       Pep.Seq_ID,
			       S.Clean_Sequence AS Peptide,
			       Pep.MSGF_SpecProb,
			       Pep.Peak_Area,
			       Pep.Peak_SN_Ratio,
			       Pep.Parent_MZ
			FROM #Tmp_Peptides_Set1 Pep
			     INNER JOIN T_Sequence S
			       ON Pep.Seq_ID = S.Seq_ID
			ORDER BY Pep.Seq_ID

		End

		If @ReturnAllSet2Peptides <> 0
		Begin
			Set @Category =  'All ' + @ParwiseJobCompSet2 + ' Peptides, Best Match'
			
			SELECT @Category As Category,
				   Pep.Dataset_ID,
			       Pep.Job,
			       Pep.Analysis_Tool,
			       Pep.Scan_Number,
			       Pep.Charge_State,
			       Pep.Seq_ID,
			       S.Clean_Sequence AS Peptide,
			       Pep.MSGF_SpecProb,
			       Pep.Peak_Area,
			       Pep.Peak_SN_Ratio,
			       Pep.Parent_MZ
			FROM #Tmp_Peptides_Set2 Pep
			     INNER JOIN T_Sequence S
			       ON Pep.Seq_ID = S.Seq_ID
			ORDER BY Pep.Seq_ID
		End

		If @ReturnSet1OnlyPeptides <> 0
		Begin
			Set @Category =  'Peptides only in ' + @ParwiseJobCompSet1 + ', Best Match'
			
			SELECT @Category As Category,
			       Pep.Dataset_ID,
			       Pep.Job,
			       Pep.Analysis_Tool,
			       Pep.Scan_Number,
			       Pep.Charge_State,
			       Pep.Seq_ID,
			       S.Clean_Sequence AS Peptide,
			       Pep.MSGF_SpecProb,
			       Pep.Peak_Area,
			       Pep.Peak_SN_Ratio,
			       Pep.Parent_MZ
			FROM #Tmp_Peptides_Set1 Pep
			     INNER JOIN T_Sequence S
			       ON Pep.Seq_ID = S.Seq_ID			
			WHERE Pep.Seq_ID IN ( SELECT Set1.Seq_ID
			                  FROM #Tmp_JobList_Stats1 Set1
			                       LEFT OUTER JOIN #Tmp_JobList_Stats2 Set2
			                         ON Set1.Seq_ID = Set2.Seq_ID
			                  WHERE Set2.Seq_ID IS NULL )		
			ORDER BY Pep.MSGF_SpecProb
		End

		If @ReturnSet2OnlyPeptides <> 0
		Begin
			Set @Category =  'Peptides only in ' + @ParwiseJobCompSet2 + ', Best Match'
			
			SELECT @Category AS Category,
			       Pep.Dataset_ID,
			       Pep.Job,
			       Pep.Analysis_Tool,
			       Pep.Scan_Number,
			       Pep.Charge_State,
			       Pep.Seq_ID,
			       S.Clean_Sequence AS Peptide,
			       Pep.MSGF_SpecProb,
			       Pep.Peak_Area,
			       Pep.Peak_SN_Ratio,
			       Pep.Parent_MZ
			FROM #Tmp_Peptides_Set2 Pep
			     INNER JOIN T_Sequence S
			       ON Pep.Seq_ID = S.Seq_ID			
			WHERE Pep.Seq_ID IN ( SELECT Set2.Seq_ID
			                  FROM #Tmp_JobList_Stats2 Set2
			                       LEFT OUTER JOIN #Tmp_JobList_Stats1 Set1
			                         ON Set2.Seq_ID = Set1.Seq_ID
			                  WHERE Set1.Seq_ID IS NULL )
			ORDER BY Pep.MSGF_SpecProb
		End
	
	End
	
	Return 0


GO
GRANT VIEW DEFINITION ON [dbo].[ComparePeptideHitResultsAggregateWork] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComparePeptideHitResultsAggregateWork] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[CreateAMTCollection] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE CreateAMTCollection
/****************************************************
**
**	Desc: 
**		Creates a new entry in T_MT_Collection, 
**		then archives the current AMT Tags passing the given
**		filters
**		
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	05/13/2009
**			05/19/2009 mem - Added filter on State > 1 when populating #Tmp_AMTCollection_Job_List
**						   - Added parameters @UpdateMTStats and @UpdatePMTQS
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@DiscriminantScoreMinimum real = 0,
	@PeptideProphetMinimum real = 0,
	@PMTQualityScoreMinimum real = 0,
	@RecomputeNET tinyint = 0,
	@UpdateMTStats tinyint = 0,
	@UpdatePMTQS tinyint = 0,
	@JobDateMax datetime = '12/31/9999',			-- Ignored if >= '12/31/9999'; otherwise, only matches jobs with Created_PMT_Tag_DB <= @JobDateMax and State > 1 in T_Analysis_Description
	@InfoOnly tinyint = 0
)
AS
	set nocount on

	Declare @myRowCount int
	Declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @JobCount int
	
	Declare @AMTCollectionID int
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------
	Set @DiscriminantScoreMinimum = IsNull(@DiscriminantScoreMinimum, 0)
	Set @PeptideProphetMinimum = IsNull(@PeptideProphetMinimum, 0)
	Set @PMTQualityScoreMinimum = IsNull(@PMTQualityScoreMinimum, 0)
	Set @RecomputeNET = IsNull(@RecomputeNET, 0)
	Set @UpdateMTStats = IsNull(@UpdateMTStats, 0)
	Set @UpdatePMTQS = IsNull(@UpdatePMTQS, 0)
	Set @JobDateMax = IsNull(@JobDateMax, '12/31/9999')
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	
	CREATE TABLE #Tmp_AMTCollection_Job_List (
		Job int NOT NULL
	)
	
	If @JobDateMax >= '12/31/9999'
	Begin
		-- Populate #Tmp_AMTCollection_Job_List with all jobs in T_Analysis_Description
		-- that have state > 1
		INSERT INTO #Tmp_AMTCollection_Job_List (Job)
		SELECT Job
		FROM T_Analysis_Description		
		WHERE State > 1
	End
	Else
	Begin
		-- Populate #Tmp_AMTCollection_Job_List with the jobs in T_Analysis_Description
		-- that have state > 1 and a DB Created date <= @JobDateMax
		INSERT INTO #Tmp_AMTCollection_Job_List (Job)
		SELECT Job
		FROM T_Analysis_Description
		WHERE State > 1 AND
			  IsNull(Created_PMT_Tag_DB, '1/1/1900') <= @JobDateMax
	End	
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	Set @JobCount = @myRowCount

	if @InfoOnly <> 0
	Begin
		SELECT COUNT(DISTINCT #Tmp_AMTCollection_Job_List.Job) AS Job_Count,
		       COUNT(DISTINCT MT.Mass_Tag_ID) AS AMT_Count
		FROM #Tmp_AMTCollection_Job_List
		     INNER JOIN T_Peptides P
		       ON #Tmp_AMTCollection_Job_List.Job = P.Job
		     INNER JOIN T_Score_Discriminant SD
		       ON P.Peptide_ID = SD.Peptide_ID
		     INNER JOIN T_Mass_Tags MT
		       ON P.Mass_Tag_ID = MT.Mass_Tag_ID
		     INNER JOIN T_Mass_Tags_NET MTN
		       ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID
		WHERE (@DiscriminantScoreMinimum = 0 OR IsNull(SD.DiscriminantScoreNorm, 0) >= @DiscriminantScoreMinimum) AND
		      (@PeptideProphetMinimum = 0 OR    IsNull(SD.Peptide_Prophet_Probability, 0) >= @PeptideProphetMinimum) AND
		      (@PMTQualityScoreMinimum = 0 OR   IsNull(MT.PMT_Quality_Score, 0) >= @PMTQualityScoreMinimum)

	End
	Else
	Begin -- <a>

		-----------------------------------------------------
		-- Save the AMT details in T_MT_Collection, 
		-- T_MT_Collection_Jobs, and T_MT_Collection_Members
		-----------------------------------------------------

		-- Possibly make sure the NET values are up-to-date
		if @RecomputeNET <> 0
			exec ComputeMassTagsGANET

		-- Possibly make sure the Obs Counts and stats in T_Mass_Tags are up-to-date
		if @UpdateMTStats <> 0
			exec ComputeMassTagsAnalysisCounts

		if @UpdatePMTQS <> 0
			Exec ComputePMTQualityScore

		-----------------------------------------------------
		-- Create a new AMT collection entry
		-----------------------------------------------------
		--
		INSERT INTO T_MT_Collection( Discriminant_Score_Minimum,
									Peptide_Prophet_Minimum,
									PMT_Quality_Score_Minimum )
		VALUES(@DiscriminantScoreMinimum, @PeptideProphetMinimum, @PMTQualityScoreMinimum)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @AMTCollectionID = SCOPE_IDENTITY()
		
		-----------------------------------------------------
		-- Add the jobs that contain the AMT tags in this collection
		-----------------------------------------------------
		--
		INSERT INTO T_MT_Collection_Jobs( MT_Collection_ID,
										Job )
		SELECT @AMTCollectionID,
			JL.Job
		FROM #Tmp_AMTCollection_Job_List JL
		ORDER BY JL.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-- Store the Job count in T_MT_Collection
		UPDATE T_MT_Collection
		SET Job_Count = @myRowCount
		WHERE MT_Collection_ID = @AMTCollectionID
		
		
		-----------------------------------------------------
		-- Add the AMT tags that are in this collection
		-----------------------------------------------------
		--
		INSERT INTO T_MT_Collection_Members( MT_Collection_ID,
		                                     Mass_Tag_ID,
		                                     Peptide_Obs_Count,
		                                     Peptide_Obs_Count_Passing_Filter,
		                                     High_Normalized_Score,
		                                     High_Discriminant_Score,
		                                     High_Peptide_Prophet_Probability,
		                                     PMT_Quality_Score,
		                                     Cleavage_State_Max,
		                                     NET_Avg,
		                                     NET_Count,
		                                     NET_StDev )
		SELECT DISTINCT @AMTCollectionID,
		                MT.Mass_Tag_ID,
		                IsNull(MT.Number_Of_Peptides, 0) AS Peptide_Obs_Count,
		                IsNull(MT.Peptide_Obs_Count_Passing_Filter, 0),
		                MT.High_Normalized_Score,
		                MT.High_Discriminant_Score,
		                MT.High_Peptide_Prophet_Probability,
		                MT.PMT_Quality_Score,
		                MT.Cleavage_State_Max,
		                MTN.Avg_GANET AS NET_Avg,
		                MTN.Cnt_GANET AS NET_Count,
		                MTN.StD_GANET AS NET_StDev
		FROM #Tmp_AMTCollection_Job_List
		     INNER JOIN T_Peptides P
		       ON #Tmp_AMTCollection_Job_List.Job = P.Job
		     INNER JOIN T_Score_Discriminant SD
		       ON P.Peptide_ID = SD.Peptide_ID
		     INNER JOIN T_Mass_Tags MT
		       ON P.Mass_Tag_ID = MT.Mass_Tag_ID
		     INNER JOIN T_Mass_Tags_NET MTN
		       ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID
		WHERE (@DiscriminantScoreMinimum = 0 OR IsNull(SD.DiscriminantScoreNorm, 0) >= @DiscriminantScoreMinimum) AND
		      (@PeptideProphetMinimum = 0 OR    IsNull(SD.Peptide_Prophet_Probability, 0) >= @PeptideProphetMinimum) AND
		      (@PMTQualityScoreMinimum = 0 OR   IsNull(MT.PMT_Quality_Score, 0) >= @PMTQualityScoreMinimum)

		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-- Store the AMT count in T_MT_Collection
		UPDATE T_MT_Collection
		SET AMT_Count = @myRowCount
		WHERE MT_Collection_ID = @AMTCollectionID
	End -- </a>
	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[CreateAMTCollection] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CreateAMTCollection] TO [MTS_DB_Lite] AS [dbo]
GO

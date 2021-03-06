/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkStepA] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE QuantitationProcessWorkStepA
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006 mem - Initial Version
**			10/13/2010 mem - Added parameters @MinimumUniquenessProbability and @MaximumFDRThreshold; these are only used when Match_Score_Mode <> 0
**			02/29/2012 mem - Refactored population of #MatchingUMCIndices
**
****************************************************/
(
	@QuantitationID int,
	@InternalStdInclusionMode tinyint,		-- 0 for no NET lockers, 1 for PMT tags and NET Lockers, 2 for NET lockers only

	@MinimumMTHighNormalizedScore real,
	@MinimumMTHighDiscriminantScore real,
 	@MinimumMTPeptideProphetProbability real,
	@MinimumPMTQualityScore real,

	@MinimumPeptideLength tinyint,
	@MinimumMatchScore real,
	@MinimumDelMatchScore real,
	
	@MinimumUniquenessProbability real,		-- Should be set to 0 if Match_Score_Mode is 0
	@MaximumFDRThreshold real,				-- Should be set to 1 if Match_Score_Mode is 0
				
	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @FeatureCountWithMatchesAvg int		-- The number of UMCs in UMCMatchResultsByJob with UseValue = 1
	set @FeatureCountWithMatchesAvg = 0
	
	-----------------------------------------------------------
	-- Step 4
	--
	-- Determine the number of UMCs that have one or more matches that pass the various filters
	-- This value is reported as an overall quality statistic
	-- This value does not account for any outlier filtering that may occur later on in this procedure
	-----------------------------------------------------------

	if exists (select * from dbo.sysobjects where id = object_id(N'[#MatchingUMCIndices]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#MatchingUMCIndices]

	CREATE TABLE #MatchingUMCIndices (
		[MD_ID] int NOT NULL ,
		[UMC_Ind] int NOT NULL ,
		[Mass_Tag_ID] int NOT NULL
	) ON [PRIMARY]

	If @InternalStdInclusionMode = 0 OR @InternalStdInclusionMode = 1
	Begin
		-- Note that this query was refactored in February 2012 due to excessively slow query times when trying to filter the peptides using 
		-- @MinimumMTHighNormalizedScore, @MinimumMTHighDiscriminantScore, @MinimumMTPeptideProphetProbability, @MinimumPMTQualityScore, and @MinimumPeptideLength
		-- while populating #MatchingUMCIndices
		--
		-- Instead, we first populate #MatchingUMCIndices, then filter delete extra rows afterward

		INSERT INTO #MatchingUMCIndices (MD_ID, UMC_Ind, Mass_Tag_ID)
		SELECT DISTINCT TMDID.MD_ID, R.UMC_Ind, RD.Mass_Tag_ID
		FROM T_Quantitation_MDIDs TMDID INNER JOIN
			 T_Match_Making_Description MMD on TMDID.MD_ID = MMD.MD_ID INNER JOIN
			 T_FTICR_UMC_Results R ON TMDID.MD_ID = R.MD_ID INNER JOIN
			 T_FTICR_UMC_ResultDetails RD ON R.UMC_Results_ID = RD.UMC_Results_ID
		WHERE	TMDID.Quantitation_ID = @QuantitationID AND 
				RD.Match_State = 6 AND
				ISNULL(RD.Match_Score, -1) >= @MinimumMatchScore AND 
				ISNULL(RD.Del_Match_Score, 0) >= @MinimumDelMatchScore AND
				IsNull(RD.Uniqueness_Probability, 0) >= @MinimumUniquenessProbability AND
				IsNull(RD.FDR_Threshold, 1) <= @MaximumFDRThreshold
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while populating the #MatchingUMCIndices temporary table from T_FTICR_UMC_ResultDetails'
			Set @myError = 115
			Goto Done
		End
		
		-- Delete rows from #MatchingUMCIndices for which the peptides do not pass the filters
		DELETE FROM #MatchingUMCIndices
		WHERE NOT Mass_Tag_ID IN 
		          ( SELECT MT.Mass_Tag_ID
		            FROM T_Mass_Tags MT
		            WHERE ISNULL(MT.High_Normalized_Score, 0) >= @MinimumMTHighNormalizedScore AND
		                  ISNULL(MT.High_Discriminant_Score, 0) >= @MinimumMTHighDiscriminantScore AND
		                  ISNULL(MT.High_Peptide_Prophet_Probability, 0) >= @MinimumMTPeptideProphetProbability AND
		                  ISNULL(MT.PMT_Quality_Score, 0) >= @MinimumPMTQualityScore AND
		                  LEN(MT.Peptide) >= @MinimumPeptideLength 
		          )

	End
	    

	If @InternalStdInclusionMode = 1 OR @InternalStdInclusionMode = 2
	Begin
		INSERT INTO #MatchingUMCIndices (MD_ID, UMC_Ind, Mass_Tag_ID)
		SELECT DISTINCT TMDID.MD_ID, R.UMC_Ind, ISD.Seq_ID
		FROM T_Quantitation_MDIDs TMDID INNER JOIN
			 T_Match_Making_Description MMD on TMDID.MD_ID = MMD.MD_ID INNER JOIN
			 T_FTICR_UMC_Results R ON TMDID.MD_ID = R.MD_ID INNER JOIN
			 T_FTICR_UMC_InternalStdDetails ISD ON R.UMC_Results_ID = ISD.UMC_Results_ID INNER JOIN
			 T_Mass_Tags MT ON ISD.Seq_ID = MT.Mass_Tag_ID
		WHERE	TMDID.Quantitation_ID = @QuantitationID AND 
				ISD.Match_State = 6 AND
				ISNULL(ISD.Match_Score, -1) >= @MinimumMatchScore AND 
				ISNULL(ISD.Del_Match_Score, 0) >= @MinimumDelMatchScore AND
				(MMD.Match_Score_Mode = 0 OR IsNull(ISD.Uniqueness_Probability, 0) >= @MinimumUniquenessProbability) AND
				(MMD.Match_Score_Mode = 0 OR IsNull(ISD.FDR_Threshold, 1) <= @MaximumFDRThreshold) AND
				LEN(MT.Peptide) >= @MinimumPeptideLength
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message =  'Error while populating the #MatchingUMCIndices temporary table from T_FTICR_UMC_InternalStdDetails'
			Set @myError = 116
			Goto Done
		End
   	End

	SELECT @FeatureCountWithMatchesAvg = Avg(DistinctUMCCount)
	FROM (	SELECT MD_ID, COUNT(DISTINCT UMC_Ind) AS DistinctUMCCount
			FROM #MatchingUMCIndices
			GROUP BY MD_ID
		 ) LookupQ
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while computing the average Feature Count with Matches value'
		Set @myError = 117
		Goto Done
	End

	If @myRowCount = 0
		Set @FeatureCountWithMatchesAvg = 0

	-- Populate the relevant statistics in T_Quantitation_Description
	UPDATE T_Quantitation_Description
	SET FeatureCountWithMatchesAvg = @FeatureCountWithMatchesAvg
	WHERE Quantitation_ID = @QuantitationID

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepA] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepA] TO [MTS_DB_Lite] AS [dbo]
GO

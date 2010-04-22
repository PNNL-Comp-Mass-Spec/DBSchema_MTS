/****** Object:  StoredProcedure [dbo].[AssignPeptideStatsToInternalStandards] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE dbo.AssignPeptideStatsToInternalStandards
/****************************************************
**
**	Desc: Assigns a PMT Quality Score to all internal standards in T_Mass_Tags
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	09/22/2008
**    
*****************************************************/
(
	@ProteinNameFilter varchar(64) = '',			-- Optional: Protein name to filter on (must be an exact match to the protein)
	@ObsCount int = 1,
	@ObsCountPassingFilters int = 1,
	@HighNormalizedScore real = 3,
	@HighDiscriminantScore real = 1,
	@HighPeptideProphetProbability real = 1,
	@PMTQS real = 1.5,
	@InfoOnly tinyint = 0,
	@message varchar(255)='' output
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	Set @PMTQS = IsNull(@PMTQS, 1)
	Set @ObsCount = IsNull(@ObsCount, 1)
	Set @ObsCountPassingFilters = IsNull(@ObsCountPassingFilters, 1)
	Set @HighNormalizedScore = IsNull(@HighNormalizedScore, 3)
	Set @HighDiscriminantScore = IsNull(@HighDiscriminantScore, 1)
	Set @HighPeptideProphetProbability = IsNull(@HighPeptideProphetProbability, 1)
	Set @ProteinNameFilter = IsNull(@ProteinNameFilter, '')
	Set @message = ''

	---------------------------------------------------
	-- Find the peptides to update
	---------------------------------------------------

	CREATE TABLE #TmpMTIDs (
		Mass_Tag_ID int
	)
	
	If Len(@ProteinNameFilter) = 0
		INSERT INTO #TmpMTIDs (Mass_Tag_ID)
		SELECT MT.Mass_Tag_ID
		FROM T_Mass_Tags MT
		WHERE (MT.Internal_Standard_Only = 1)
	Else
		INSERT INTO #TmpMTIDs (Mass_Tag_ID)
		SELECT DISTINCT MT.Mass_Tag_ID
		FROM T_Mass_Tags MT INNER JOIN
			T_Mass_Tag_to_Protein_Map MTPM ON 
			MT.Mass_Tag_ID = MTPM.Mass_Tag_ID INNER JOIN
			T_Proteins Prot ON MTPM.Ref_ID = Prot.Ref_ID
		WHERE (MT.Internal_Standard_Only = 1) AND 
			(Prot.Reference = @ProteinNameFilter)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = 'No entries in MT_Main have Internal_Standard_Only = 1'
		
		If Len(@ProteinNameFilter) > 0
			Set @message = @message + ' (limited to peptides for protein "' + @ProteinNameFilter + '")'
	End
			
	If @infoOnly <> 0
	Begin
		SELECT Prot.Reference,
		       MT.Mass_Tag_ID,
		       MT.Number_Of_Peptides,
		       MT.Peptide_Obs_Count_Passing_Filter,
		       MT.High_Normalized_Score,
		       MT.High_Discriminant_Score,
		       MT.High_Peptide_Prophet_Probability,
		       MT.PMT_Quality_Score
		FROM #TmpMTIDs Src
		     INNER JOIN T_Mass_Tags MT
		       ON Src.Mass_Tag_ID = MT.Mass_Tag_ID
		     INNER JOIN T_Mass_Tag_to_Protein_Map MTPM
		       ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
		     INNER JOIN T_Proteins Prot
		       ON MTPM.Ref_ID = Prot.Ref_ID
		ORDER BY Prot.Reference, MT.Mass_Tag_ID
		    
		Goto Done
	End
	
	
	UPDATE T_Mass_Tags
	SET Number_Of_Peptides = @ObsCount,
	    Peptide_Obs_Count_Passing_Filter = @ObsCountPassingFilters,
	    High_Normalized_Score = @HighNormalizedScore,
	    High_Discriminant_Score = @HighDiscriminantScore,
	    High_Peptide_Prophet_Probability = @HighPeptideProphetProbability,
	    PMT_Quality_Score = @PMTQS
	FROM T_Mass_Tags MT
	     INNER JOIN #TmpMTIDs Src
	       ON Src.Mass_Tag_ID = MT.Mass_Tag_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--

	Set @message = 'Updated the PMT Quality Score to ' + convert(varchar(12), @PMTQS) + ' for ' + Convert(varchar(12), @myRowCount) + ' internal standards'
	
	If Len(@ProteinNameFilter) > 0
		Set @message = @message + ' (limited to peptides for protein "' + @ProteinNameFilter + '")'
	
	If @myRowCount > 0
		exec PostLogEntry 'Normal', @message, 'AssignPeptideStatsToInternalStandards'

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[AssignPeptideStatsToInternalStandards] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AssignPeptideStatsToInternalStandards] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[PMLookupDefaultFilterThresholds] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

create Procedure PMLookupDefaultFilterThresholds
/****************************************************	
**  Desc:	
**		Determines the default filter thresholds defined in T_Peak_Matching_Defaults
**
**		Returns the filter thresholds as the output variables
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/19/2009
**
****************************************************/
(
	@MinimumHighNormalizedScore real = 0 output,
	@MinimumHighDiscriminantScore real = 0 output,
	@MinimumPeptideProphetProbability real = 0 output,
	@MinimumPMTQualityScore real = 0 output,
	@message varchar(512) = '' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	

		Set @MinimumHighNormalizedScore = 0
		Set @MinimumHighDiscriminantScore = 0
		Set @MinimumPeptideProphetProbability = 0
		Set @MinimumPMTQualityScore = 0
		Set @message = ''

		-------------------------------------------------
		-- Lookup the default thresholds defined in T_Peak_Matching_Defaults
		-------------------------------------------------	
		
		-- The following query uses the Row_Number() function to determine the median entry
		-- in the T_Peak_Matching_Defaults table
		
		SELECT @MinimumHighNormalizedScore = MIN(ISNULL(LookupQ.Minimum_High_Normalized_Score, 0)),
			   @MinimumHighDiscriminantScore = MIN(ISNULL(LookupQ.Minimum_High_Discriminant_Score, 0)),
			   @MinimumPeptideProphetProbability = MIN(ISNULL(LookupQ.Minimum_Peptide_Prophet_Probability, 0)),
			   @MinimumPMTQualityScore = MIN(ISNULL(LookupQ.Minimum_PMT_Quality_Score, 0))
		FROM ( SELECT Minimum_High_Normalized_Score,
				        Minimum_High_Discriminant_Score,
				        Minimum_Peptide_Prophet_Probability,
				        Minimum_PMT_Quality_Score,
				Row_Number() OVER ( ORDER BY Minimum_PMT_Quality_Score, Minimum_Peptide_Prophet_Probability,
				                Minimum_High_Discriminant_Score, Minimum_High_Normalized_Score ) AS SortOrder
				FROM T_Peak_Matching_Defaults ) LookupQ
				INNER JOIN ( SELECT COUNT(*) AS NumRows
				            FROM T_Peak_Matching_Defaults ) RowCountQ
				       ON LookupQ.SortOrder = CONVERT(int, RowCountQ.NumRows / 2.0)		
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMLookupDefaultFilterThresholds')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto DoneSkipLog
	End Catch
				
Done:
	-----------------------------------------------------------
	-- Done processing
	-----------------------------------------------------------
		
	If @myError <> 0 
	Begin
		Execute PostLogEntry 'Error', @message, 'PMLookupDefaultFilterThresholds'
		Print @message
	End

DoneSkipLog:	
	Return @myError

GO
GRANT EXECUTE ON [dbo].[PMLookupDefaultFilterThresholds] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PMLookupDefaultFilterThresholds] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PMLookupDefaultFilterThresholds] TO [MTS_DB_Lite] AS [dbo]
GO

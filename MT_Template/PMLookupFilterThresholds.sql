/****** Object:  StoredProcedure [dbo].[PMLookupFilterThresholds] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure PMLookupFilterThresholds
/****************************************************	
**  Desc:	
**		Determines the filter thresholds used during the peak matching for the given MDIDs
**
**		If @MDIDs is empty, or if none of the entries in @MDIDs is valid,
**		 then uses the thresholds for all entries in T_Match_Making_Description
**
**		If T_Match_Making_Description is empty, then uses the thresholds in T_Peak_Matching_Defaults
**
**		Returns the filter thresholds as a table listing each of the threshold values,
**		 plus optionally the number of AMT tags that pass the given set of thresholds
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/16/2009
**			10/27/2009 mem - Added support for Minimum_Cleavage_State
**
****************************************************/
(
	@MDIDs varchar(max) = '',				-- If empty (or if no valid MDIDs), then uses all combinations of thresholds in T_Match_Making_Description
	@ComputeMTCounts tinyint = 1,			-- When 1, then computes the number of MTs that pass each of the filter threshold combinations; this could take some time if there is a large number of combinations
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
		Set @MDIDs = IsNull(@MDIDs, '')
		Set @ComputeMTCounts = IsNull(@ComputeMTCounts, 1)

		Set @message = ''

		-------------------------------------------------
		-- Create the Score Thresholds temporary table
		-------------------------------------------------	

		CREATE TABLE #Tmp_ScoreThresholds (
			EntryID int Identity(1,1),
			Minimum_High_Normalized_Score real NOT NULL,
			Minimum_High_Discriminant_Score real NOT NULL,
			Minimum_Peptide_Prophet_Probability real NOT NULL,
			Minimum_PMT_Quality_Score real NOT NULL,
			Minimum_Cleavage_State smallint NOT NULL,
			MDID_Minimum int NOT NULL,
			MDID_Maximum int NOT NULL,
			MTCount int NULL,
			MTLastAffectedMax datetime NULL,
			HashText varchar(2048) NULL
		)
		CREATE UNIQUE INDEX IX_Tmp_ScoreThresholds_EntryID ON #Tmp_ScoreThresholds (EntryID ASC)
		
		Exec @myError = PMLookupFilterThresholdsWork @MDIDs, @ComputeMTCounts, @message = @message output

		-------------------------------------------------	
		-- Now return the data
		-------------------------------------------------
		
		SELECT EntryID,
			Minimum_High_Normalized_Score,
			Minimum_High_Discriminant_Score,
			Minimum_Peptide_Prophet_Probability,
			Minimum_PMT_Quality_Score,
			Minimum_Cleavage_State,
			MDID_Minimum,
			MDID_Maximum,
			MTCount,
			MTLastAffectedMax,
			HashText
		FROM #Tmp_ScoreThresholds
		ORDER BY EntryID
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMLookupFilterThresholds')
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
		Execute PostLogEntry 'Error', @message, 'PMLookupFilterThresholds'
		Print @message
	End

DoneSkipLog:	
	Return @myError

GO
GRANT EXECUTE ON [dbo].[PMLookupFilterThresholds] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PMLookupFilterThresholds] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PMLookupFilterThresholds] TO [MTS_DB_Lite] AS [dbo]
GO

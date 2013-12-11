/****** Object:  StoredProcedure [dbo].[PMExportAMTs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure PMExportAMTs
/****************************************************	
**  Desc:	
**		Exports the Mass_Tag_ID values that pass the given set of filters
**
**		Alternatively, if @CountRowsOnly is 1, then populates 
**		  @AMTCount with the number of AMTs that would be returned
**
**		If @LookupDefaults is non-zero, then will call PMLookupFilterThresholds
**		   to lookup the default filters in T_Peak_Matching_Defaults
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/17/2009
**			10/27/2009 mem - Added parameter @MinimumCleavageState
**			02/21/2011 mem - Added parameter @ReturnIMSConformersTable
**			12/04/2013 mem - Updated default value for @MinimumPeptideProphetProbability to be 0 instead of 0.5
**						   - Updated default value for @MinimumPMTQualityScore to be 2 instead of 1
**
****************************************************/
(
	@LookupDefaults tinyint = 0,
	@MinimumHighNormalizedScore real = 0,			-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumHighDiscriminantScore real = 0,			-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real = 0,		-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
	@MinimumPMTQualityScore real = 2,				-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@MinimumCleavageState smallint = 0,				-- The minimum Max_Cleavage_State to allow; 0 to allow all
	@CountRowsOnly tinyint = 0,						-- When 1, then populates @AMTCount but does not return any data
	@ReturnMTTable tinyint = 1,						-- When 1, then returns a table of Mass Tag IDs and various infor
	@ReturnProteinTable tinyint = 1,				-- When 1, then also returns a table of Proteins that the Mass Tag IDs map to
	@ReturnProteinMapTable tinyint = 1,				-- When 1, then also returns the mapping information of Mass_Tag_ID to Protein
	@ReturnIMSConformersTable tinyint = 1,			-- When 1, then also returns T_Mass_Tag_Conformers_Observed
	@AMTCount int = 0 output,						-- The number of AMT tags that pass the thresholds
	@AMTLastAffectedMax datetime = null output,		-- The maximum Last_Affected value for the AMT tags that pass the thresholds
	@PreviewSql tinyint = 0,
	@DebugMode tinyint = 0,
	@message varchar(512)='' output
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
		Set @LookupDefaults = IsNull(@LookupDefaults, 0)

		Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
		Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
		Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
		Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
		Set @MinimumCleavageState = IsNull(@MinimumCleavageState, 0)

		Set @CountRowsOnly = IsNull(@CountRowsOnly, 0)
		Set @ReturnMTTable = IsNull(@ReturnMTTable, 1)
		Set @ReturnProteinTable = IsNull(@ReturnProteinTable, 1)
		Set @ReturnProteinMapTable = IsNull(@ReturnProteinMapTable, 1)
		Set @ReturnIMSConformersTable = IsNull(@ReturnIMSConformersTable, 1)

		Set @PreviewSql = IsNull(@PreviewSql, 0)

		Set @message = ''
		Set @AMTCount = 0
		Set @AMTLastAffectedMax = Convert(datetime, '2000-01-01')

		If @LookupDefaults <> 0
		Begin
			-------------------------------------------------
			-- Call PMLookupDefaultFilterThresholds to lookup the default thresholds in T_Peak_Matching_Defaults
			-------------------------------------------------	
				
			Exec @myError = PMLookupDefaultFilterThresholds
								@MinimumPMTQualityScore = @MinimumPMTQualityScore output,
								@MinimumHighNormalizedScore = @MinimumHighNormalizedScore output,
								@MinimumHighDiscriminantScore = @MinimumHighDiscriminantScore output,
								@MinimumPeptideProphetProbability = @MinimumPeptideProphetProbability output,
								@message = @message output

		End

	If @DebugMode > 0
		SELECT @MinimumHighNormalizedScore AS MinimumHighNormalizedScore,
		       @MinimumHighDiscriminantScore AS MinimumHighDiscriminantScore,
		       @MinimumPeptideProphetProbability AS MinimumPeptideProphetProbability,
		       @MinimumPMTQualityScore AS MinimumPMTQualityScore

		-------------------------------------------------
		-- Create and populate the Score Thresholds temporary table (with just one row of data)
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
			HashText varchar(2048) NULL,
			Skip tinyint DEFAULT 0
		)
		CREATE UNIQUE INDEX IX_Tmp_ScoreThresholds_EntryID ON #Tmp_ScoreThresholds (EntryID ASC)

		INSERT INTO #Tmp_ScoreThresholds( Minimum_High_Normalized_Score,
		                                  Minimum_High_Discriminant_Score,
		                                  Minimum_Peptide_Prophet_Probability,
		                                  Minimum_PMT_Quality_Score,
		                                  Minimum_Cleavage_State,
		                                  MDID_Minimum, MDID_Maximum 
		                                )
		VALUES(	@MinimumHighNormalizedScore, 
				@MinimumHighDiscriminantScore,
				@MinimumPeptideProphetProbability, 
				@MinimumPMTQualityScore,
				@MinimumCleavageState,
				0, 0 )
			
		-------------------------------------------------
		-- Now call PMExportAMTsWork to do the work
		-------------------------------------------------	

		exec @myError = PMExportAMTsWork
							@CountRowsOnly = @CountRowsOnly,
							@ReturnMTTable = @ReturnMTTable,
							@ReturnProteinTable = @ReturnProteinTable,
							@ReturnProteinMapTable = @ReturnProteinMapTable,
							@ReturnIMSConformersTable = @ReturnIMSConformersTable,
							@AMTCount = @AMTCount output,
							@AMTLastAffectedMax = @AMTLastAffectedMax output,
							@PreviewSql = @PreviewSql,
							@DebugMode = @DebugMode,
							@message = @message output

		If @DebugMode <> 0
			SELECT *
			FROM #Tmp_ScoreThresholds

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMExportAMTs')
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
		Execute PostLogEntry 'Error', @message, 'PMExportAMTs'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO
GRANT EXECUTE ON [dbo].[PMExportAMTs] TO [DMS_SP_User] AS [dbo]
GO

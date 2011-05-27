/****** Object:  StoredProcedure [dbo].[PMExportCandidateAMTsForMDIDs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.PMExportCandidateAMTsForMDIDs
/****************************************************	
**  Desc:	
**		Exports a list of Mass_Tag_ID values that pass the threshold values
**		used for the peak matching tasks given by the MDIDs in @MDIDs
**
**		If @MDIDs is empty, then PMLookupFilterThresholds will return the median
**		threshold entry defined in T_Peak_Matching_Defaults
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/17/2009
**			10/27/2009 mem - Added support for Minimum_Cleavage_State
**			02/21/2011 mem - Added parameter @ReturnIMSConformersTable
**
****************************************************/
(
	@MDIDs varchar(max) = '',
	@CountRowsOnly tinyint = 0,						-- When 1, then populates @AMTCount but does not return any data
	@ReturnMTTable tinyint = 1,						-- When 1, then returns a table of Mass Tag IDs and various information
	@ReturnProteinTable tinyint = 1,				-- When 1, then also returns a table of Proteins that the Mass Tag IDs map to
	@ReturnProteinMapTable tinyint = 1,				-- When 1, then also returns the mapping information of Mass_Tag_ID to Protein
	@ReturnIMSConformersTable tinyint = 1,			-- When 1, then also returns T_Mass_Tag_Conformers_Observed	
	@AMTCount int = 0 output,						-- The number of AMT tags that pass the thresholds
	@AMTLastAffectedMax datetime = null output,		-- The maximum Last_Affected value for the AMT tags that pass the thresholds
	@PreviewSql tinyint=0,
	@DebugMode tinyint = 0,
	@message varchar(512)='' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare	@MinimumHighNormalizedScore real 
	Declare	@MinimumHighDiscriminantScore real
	Declare	@MinimumPeptideProphetProbability real
	Declare	@MinimumPMTQualityScore real 
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	
		Set @MDIDs = IsNull(@MDIDs, '')
		Set @PreviewSql = IsNull(@PreviewSql, 0)

		Set @CountRowsOnly = IsNull(@CountRowsOnly, 0)
		Set @ReturnMTTable = IsNull(@ReturnMTTable, 1)
		Set @ReturnProteinTable = IsNull(@ReturnProteinTable, 1)
		Set @ReturnProteinMapTable = IsNull(@ReturnProteinMapTable, 1)
		Set @ReturnIMSConformersTable = IsNull(@ReturnIMSConformersTable, 1)

		Set @AMTCount = 0
		Set @message = ''

		-------------------------------------------------
		-- Create the temporary table that will be used by
		-- PMLookupFilterThresholdsWork and PMExportAMTsWork
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
	
						   
		-------------------------------------------------
		-- Call PMLookupFilterThresholdsWork to lookup the thresholds for the specified MDIDs
		-- Note that if @MDIDs is blank, then will use all threshold combinations present in T_Match_Making_Description
		-------------------------------------------------	
		
		Exec PMLookupFilterThresholdsWork
				@MDIDs = @MDIDs,
				@ComputeMTCounts = 0,
				@message = @message output

		-------------------------------------------------
		-- Now call PMExportAMTsWork to obtain a unique list of AMTs
		-- that pass the threshold combinations listed in #Tmp_ScoreThresholds
		-------------------------------------------------
		
		Exec PMExportAMTsWork
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
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMExportCandidateAMTsForMDIDs')
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
		Execute PostLogEntry 'Error', @message, 'PMExportCandidateAMTsForMDIDs'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO
GRANT EXECUTE ON [dbo].[PMExportCandidateAMTsForMDIDs] TO [DMS_SP_User] AS [dbo]
GO

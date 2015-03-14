/****** Object:  StoredProcedure [dbo].[PMExportAMTsWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Procedure dbo.PMExportAMTsWork
/****************************************************	
**  Desc:	
**		Constructs a list of filter-passing Mass_Tag_ID values using
**		the thresholds in temporary table #Tmp_ScoreThresholds
**
**		If @CountRowsOnly = 0, returns details of the AMTs
**
**		If @CountRowsOnly is 1, then populates @AMTCount
**		  with the number of AMTs that would be returned
**
**		The calling procedure must create #Tmp_ScoreThresholds
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/19/2009
**			10/27/2009 mem - Added support for Minimum_Cleavage_State
**			10/29/2009 mem - Now calling PMExportAMTTables to export the data
**			11/03/2009 mem - Updated to use #Tmp_FilteredMTs to track the MTs found by SP PMPopulateAMTTable
**			10/12/2010 mem - Explicitly passing @FDRThreshold=0 to PMPopulateAMTTable
**			02/21/2011 mem - Added parameter @ReturnIMSConformersTable
**			11/11/2014 mem - Added parameters @ReturnMTModsTable and @ReturnMTChargesTable
**
****************************************************/
(
	@CountRowsOnly tinyint = 0,						-- When 1, then populates @AMTCount but does not return any data
	@ReturnMTTable tinyint = 1,						-- When 1, then returns a table of Mass Tag IDs and various infor
	@ReturnProteinTable tinyint = 1,				-- When 1, then also returns a table of Proteins that the Mass Tag IDs map to
	@ReturnProteinMapTable tinyint = 1,				-- When 1, then also returns the mapping information of Mass_Tag_ID to Protein
	@ReturnIMSConformersTable tinyint = 1,			-- When 1, then also returns T_Mass_Tag_Conformers_Observed
	@ReturnMTModsTable tinyint = 1,					-- When 1, then also returns T_Mass_Tag_Mod_Info (with mod masses pulled from MT_Main)	
	@ReturnMTChargesTable tinyint = 1,				-- When 1, then also returns a table summarizing the charge state observation stats
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

	Declare @ScoreThresholdCount int
	Declare @LoopingCountRowsOnly tinyint
	Declare @UpdateAMTStats tinyint
	
	Set @ScoreThresholdCount = 0
	Set @UpdateAMTStats = 0
	
	Declare @MinimumHighNormalizedScore real
	Declare @MinimumHighDiscriminantScore real
	Declare @MinimumPeptideProphetProbability real
	Declare @MinimumPMTQualityScore real
	Declare @MinimumCleavageState smallint

	Declare @EntryID int
	Declare @continue tinyint

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	

		Set @CountRowsOnly = IsNull(@CountRowsOnly, 0)
		Set @ReturnMTTable = IsNull(@ReturnMTTable, 1)
		Set @ReturnProteinTable = IsNull(@ReturnProteinTable, 1)
		Set @ReturnProteinMapTable = IsNull(@ReturnProteinMapTable, 1)
		Set @ReturnIMSConformersTable = IsNull(@ReturnIMSConformersTable, 1)
		Set @ReturnMTModsTable = IsNull(@ReturnMTModsTable, 1)
		Set @ReturnMTChargesTable = IsNull(@ReturnMTChargesTable, 1)

		Set @PreviewSql = IsNull(@PreviewSql, 0)
		Set @DebugMode = IsNull(@DebugMode, 0)
		
		Set @message = ''
		Set @AMTCount = 0
		Set @AMTLastAffectedMax = Convert(datetime, '2000-01-01')


		-------------------------------------------------
		-- Create two temporary tables
		-------------------------------------------------	
		
		-- Note: This table is used by SP PMExportAMTTables, so do not rename it
		CREATE TABLE #Tmp_MTs_ToExport (
			Mass_Tag_ID int NOT NULL
		)
		CREATE UNIQUE INDEX IX_Tmp_MTs_ToExport_Mass_Tag_ID ON #Tmp_MTs_ToExport (Mass_Tag_ID ASC)
		
		-- Note: This table is used by SP PMPopulateAMTTable, so do not rename it
		CREATE TABLE #Tmp_FilteredMTs (
			Mass_Tag_ID int NOT NULL
		)
		CREATE UNIQUE INDEX IX_Tmp_FilteredMTs_Mass_Tag_ID ON #Tmp_FilteredMTs (Mass_Tag_ID ASC)
		

		-------------------------------------------------	
		-- Count the number of entries in #Tmp_ScoreThresholds
		-------------------------------------------------	
		
		Set @myRowCount = 0
		SELECT @myRowCount = COUNT(*)
		FROM #Tmp_ScoreThresholds
		
		Set @ScoreThresholdCount = IsNull(@myRowCount, 0)
		
		-------------------------------------------------
		-- Set @LoopingCountRowsOnly to the appropriate value
		-- If @ScoreThresholdCount= 1, then we can set @LoopingCountRowsOnly to 1 (which will speed things up)
		-------------------------------------------------	

		If @CountRowsOnly = 0
			Set @LoopingCountRowsOnly = @CountRowsOnly
		Else
		Begin
			
			If @ScoreThresholdCount <= 1
				Set @LoopingCountRowsOnly = @CountRowsOnly
			Else
				Set @LoopingCountRowsOnly = 0
		End

		If @ScoreThresholdCount > 1
		Begin
			-------------------------------------------------	
			-- See if any of the entries in #Tmp_ScoreThresholds
			-- have thresholds that are all greater than or equal
			-- to other thresholds.  If they do, we can skip them
			-------------------------------------------------	

			UPDATE #Tmp_ScoreThresholds
			SET Skip = 1
			FROM #Tmp_ScoreThresholds Target
				INNER JOIN ( SELECT DISTINCT B.EntryID AS SupersededItem
							FROM #Tmp_ScoreThresholds A
								INNER JOIN #Tmp_ScoreThresholds B
									ON A.EntryID <> B.EntryID AND
										A.Minimum_High_Normalized_Score <= B.Minimum_High_Normalized_Score AND
										A.Minimum_High_Discriminant_Score <= B.Minimum_High_Discriminant_Score AND
										A.Minimum_Peptide_Prophet_Probability <= B.Minimum_Peptide_Prophet_Probability AND
										A.Minimum_PMT_Quality_Score <= B.Minimum_PMT_Quality_Score AND
										A.Minimum_Cleavage_State <= B.Minimum_Cleavage_State
							) Source
				ON Source.SupersededItem = Target.EntryID
		End    
		
		
		-------------------------------------------------	
		-- Step through #Tmp_ScoreThresholds
		--
		-- For each combination of thresholds, call PMPopulateAMTTable
		--  to determine the AMTs that pass the threshold
		-------------------------------------------------	

		Set @EntryID = 0
		Set @continue = 1
		
		While @continue = 1
		Begin -- <c>
			SELECT TOP 1 @EntryID = EntryID,
			             @MinimumHighNormalizedScore = Minimum_High_Normalized_Score,
			             @MinimumHighDiscriminantScore = Minimum_High_Discriminant_Score,
			             @MinimumPeptideProphetProbability = Minimum_Peptide_Prophet_Probability,
			             @MinimumPMTQualityScore = Minimum_PMT_Quality_Score,
			             @MinimumCleavageState = Minimum_Cleavage_State
			FROM #Tmp_ScoreThresholds
			WHERE EntryID > @EntryID And Skip = 0
			ORDER BY EntryID
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
			
			If @myRowCount = 0
				Set @continue = 0
			Else
			Begin -- <d>
				
				TRUNCATE TABLE #Tmp_FilteredMTs
		
				-------------------------------------------------
				-- Populate #Tmp_FilteredMTs with the AMT tags that pass the 
				--  current set of thresholds
				--
				-- If @CountRowsOnly is non-zero, then @AMTCount is populated
				--   but #Tmp_FilteredMTs is not populated.
				-- However, if there are multiple rows in #Tmp_ScoreThresholds, then
				--  we cannot use the @CountRowsOnly = 1 option
				-------------------------------------------------	
				
				exec @myError = PMPopulateAMTTable 
									@FilterByMDID = 0,
									@UseScoreThresholds = 1,
									@MinimumHighNormalizedScore = @MinimumHighNormalizedScore,
									@MinimumHighDiscriminantScore = @MinimumHighDiscriminantScore,
									@MinimumPeptideProphetProbability = @MinimumPeptideProphetProbability,
									@MinimumPMTQualityScore = @MinimumPMTQualityScore,
									@MinimumCleavageState = @MinimumCleavageState,
									@FDRThreshold = 0,
									@CountRowsOnly = @LoopingCountRowsOnly,
									@AMTCount = @AMTCount output,
									@AMTLastAffectedMax = @AMTLastAffectedMax output,
									@previewSql = @previewSql,
									@message = @message output

				If @myError <> 0
					Set @continue = 0

				-------------------------------------------------	
				-- Append the entries in #Tmp_FilteredMTs to #Tmp_MTs_ToExport
				-------------------------------------------------	

				-- Old-style method of merging
				--   INSERT INTO #Tmp_MTs_ToExport (Mass_Tag_ID)
				--   SELECT Source.Mass_Tag_ID
				--   FROM #Tmp_FilteredMTs Source LEFT OUTER JOIN
				--    #Tmp_MTs_ToExport Target ON Source.Mass_Tag_ID = Target.Mass_Tag_ID
				--   WHERE Target.Mass_Tag_ID = Is Null
				
				-- SQL Server 2008 method of merging
				--
				MERGE INTO #Tmp_MTs_ToExport AS Target
				USING #Tmp_FilteredMTs AS Source
				ON Target.Mass_Tag_ID = Source.Mass_Tag_ID
				WHEN NOT MATCHED THEN	
					INSERT (Mass_Tag_ID)
					VALUES (Source.Mass_Tag_ID);
				--
				SELECT @myError = @@Error, @myRowCount = @@RowCount
				
				If @DebugMode <> 0
					Print 'Threshold entry ' + Convert(varchar(12), @EntryID) + '; merged ' + Convert(varchar(12), @myRowCount) + ' rows into #Tmp_MTs_ToExport'
					
				If @myError <> 0
				Begin
					Set @message = 'Error during merge into #Tmp_MTs_ToExport'
					Set @continue = 0
				End
					
			End -- </d>
			
		End -- </c>

		-------------------------------------------------	
		-- Update @AMTCount and @AMTLastAffectedMax	if more than one score threshold was used
		-------------------------------------------------	
		If @ScoreThresholdCount > 1
		Begin
			-- Count the number of filtered AMT tags
			-- Also, lookup the most recent Last_Affected date/time
			SELECT @AMTCount = COUNT(*),
			       @AMTLastAffectedMax = Max(MT.Last_Affected)
			FROM T_Mass_Tags MT
			     INNER JOIN #Tmp_MTs_ToExport F
			       ON MT.Mass_Tag_ID = F.Mass_Tag_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

		End

		If @myError = 0 And @previewSql = 0 And @CountRowsOnly = 0
		Begin	
			-------------------------------------------------	
			-- Return the data
			-------------------------------------------------	

			Exec @myError = PMExportAMTTables 
			                          @ReturnMTTable = @ReturnMTTable, 
			                          @ReturnProteinTable = @ReturnProteinTable, 
			                          @ReturnProteinMapTable = @ReturnProteinMapTable, 
			                          @ReturnIMSConformersTable = @ReturnIMSConformersTable,
				                      @ReturnMTModsTable = @ReturnMTModsTable, 
				                      @ReturnMTChargesTable = @ReturnMTChargesTable, 
				                      @message = @message output

		End
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMExportAMTsWork')
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
		If IsNull(@message, '') = ''
			Set @message = 'Unknown error, code ' + Cast(@myError as Varchar(12))

		Execute PostLogEntry 'Error', @message, 'PMExportAMTsWork'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[PMExportAMTsWork] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PMExportAMTsWork] TO [MTS_DB_Lite] AS [dbo]
GO

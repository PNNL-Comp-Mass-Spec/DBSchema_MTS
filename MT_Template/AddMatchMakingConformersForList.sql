/****** Object:  StoredProcedure [dbo].[AddMatchMakingConformersForList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE AddMatchMakingConformersForList
/****************************************************
**
**	Desc:	Calls AddMatchMakingConformers for each MDID in @MDIDList
**			After all MDIDs have been processed, calls AddConformersViaSplitting using @DriftTimeToleranceFinal
**			to examine the observed drift times for each conformer and create new conformers where needed
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	02/21/2011 mem - Initial version
**			02/22/2011 mem - Added parameter @SortMode
**			11/09/2011 mem - Added @DriftTimeToleranceFinal
**			04/01/2014 mem - Added @MergeChargeStates
**    
*****************************************************/
(
	@MDIDList varchar(max),
	@MaxFDRThreshold real = 0.95,				-- Set to a value less than 1 to filter by FDR
	@MinimumUniquenessProbability real = 0.5,	-- Set to a value greater than 0 to filter by Uniqueness Probability (UP)
	@DriftTimeTolerance real = 1000,			-- When processing each MDID, matching conformers must have drift times within this tolerance; defaults to a large value so we can intially create just one conformer for each charge state of each AMT tag ID
	@MergeChargeStates tinyint = 1,				-- When 1, then ignores charge state when finding conformers
	@FilterByExperimentMSMS tinyint = 1,		-- When 1, then requires that each identified AMT tag also be observed by MS/MS for this experiment
	@SortMode tinyint = 0,						-- 0=Sort by AMT_Count_FDR columns in T_Match_Making_Description; 1=Sort by @MDIDList order
	@message varchar(255) = '' output,
	@MaxIterations int = 0,
	@DriftTimeToleranceFinal real = 0.35,		-- Sent to AddConformersViaSplitting after all MDIDs have been processed
	@InfoOnly tinyint = 0
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @SortKey int
	Declare @Continue tinyint
	Declare @MDID int
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------

	Set @MDIDList = IsNull(@MDIDList, '')
	Set @MaxFDRThreshold = IsNull(@MaxFDRThreshold, 1)
	Set @MinimumUniquenessProbability = IsNull(@MinimumUniquenessProbability, 0)
	Set @DriftTimeTolerance = IsNull(@DriftTimeTolerance, 1000)
	Set @FilterByExperimentMSMS = IsNull(@FilterByExperimentMSMS, 1)
	Set @SortMode = IsNull(@SortMode, 0)
	Set @DriftTimeToleranceFinal = IsNull(@DriftTimeToleranceFinal, 0.35)
	Set @message = ''
	
	Set @MaxIterations = IsNull(@MaxIterations, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	
	-----------------------------------------------------
	-- Create a temporary table to hold the MD_IDs
	-----------------------------------------------------

	CREATE TABLE #Tmp_MDIDs (
		MD_ID int NOT NULL,
		Sort_Key int NULL
	)

	--
	CREATE CLUSTERED INDEX #IX_Tmp_MDIDs_Sort_Key ON #Tmp_MDIDs (Sort_Key)

	-----------------------------------------------------
	-- Populate the temporary table
	-- Populate Sort_Key with EntryID for now
	-----------------------------------------------------
	INSERT INTO #Tmp_MDIDs (MD_ID, Sort_Key)
	SELECT Value, EntryID
	FROM dbo.udfParseDelimitedListOrdered (@MDIDList, ',')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @SortMode = 0
	Begin
		-- First set the Sort_Key to one more than the number of items in the table
		--
		SELECT @myRowCount = COUNT(*)
		FROM #Tmp_MDIDs
		
		UPDATE #Tmp_MDIDs
		SET Sort_Key = @myRowCount
		
		If @InfoOnly <> 0
			select * from #Tmp_MDIDs
		
		-- Now update Sort_Key using T_Match_Making_Description
		--
		UPDATE #Tmp_MDIDs
		SET Sort_Key = LookupQ.Sort_Key
		FROM #Tmp_MDIDs
		     INNER JOIN ( SELECT MMD.MD_ID,
		                  Row_Number() OVER ( ORDER BY AMT_Count_5pct_FDR DESC, 
		                                               AMT_Count_10pct_FDR DESC,
		                                               AMT_Count_25pct_FDR DESC, 
		                                               AMT_Count_50pct_FDR DESC ) AS Sort_Key
		                  FROM T_Match_Making_Description MMD
		                       INNER JOIN #Tmp_MDIDs
		                         ON MMD.MD_ID = #Tmp_MDIDs.MD_ID 
		                 ) LookupQ
		       ON #Tmp_MDIDs.MD_ID = LookupQ.MD_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @InfoOnly <> 0
			select * from #Tmp_MDIDs

		-- Perform one more update, this time to make sure Sort_Key is Unique
		UPDATE #Tmp_MDIDs
		SET Sort_Key = LookupQ.Sort_Key
		FROM #Tmp_MDIDs
		     INNER JOIN ( SELECT MD_ID, Row_Number() OVER ( ORDER BY Sort_Key ) AS Sort_Key
		       FROM #Tmp_MDIDs 
		 ) LookupQ
		       ON #Tmp_MDIDs.MD_ID = LookupQ.MD_ID

		If @InfoOnly <> 0
			select * from #Tmp_MDIDs

	End
	
	-----------------------------------------------------
	-- Step through the entries in #Tmp_MDIDs
	-----------------------------------------------------
	--	

	Set @SortKey = -1
	Set @Continue = 1
	
	While @Continue = 1
	Begin -- <a>
		SELECT TOP 1 @MDID = MD_ID,
		             @SortKey = Sort_Key
		FROM #Tmp_MDIDs
		WHERE Sort_Key > @SortKey
		ORDER BY Sort_Key
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <b>
		
			Exec @myError = AddMatchMakingConformers 
									@MDID = @MDID,
									@MaxFDRThreshold =@MaxFDRThreshold,
									@MinimumUniquenessProbability =@MinimumUniquenessProbability,
									@DriftTimeTolerance = @DriftTimeTolerance,
									@MergeChargeStates = @MergeChargeStates,
									@FilterByExperimentMSMS = @FilterByExperimentMSMS,
									@InfoOnly = @InfoOnly,
									@MaxIterations = @MaxIterations

			
		End	-- </b>
	End -- </a>
	
	-----------------------------------------------------	
	-- Call AddConformersViaSplitting to examine the observed drift times for each conformer and create new conformers where needed
	-----------------------------------------------------
	--
	If @DriftTimeToleranceFinal > 0
		exec @myError = AddConformersViaSplitting @DriftTimeToleranceFinal, @MergeChargeStates, @InfoOnly = @InfoOnly
		
Done:

	Return @myError

GO

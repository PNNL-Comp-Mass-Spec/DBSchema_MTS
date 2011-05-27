/****** Object:  StoredProcedure [dbo].[AddDefaultPeakMatchingTasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.AddDefaultPeakMatchingTasks
/****************************************************
**
**	Desc: 
**		Adds a new entry to the peak matching task table
**		for each FTICR analysis job that isn't already
**		represented there
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	grk
**	Date:	06/24/2003
**			07/22/2003 mem
**			07/30/2003 mem
**			09/11/2003 mem - added new parameters
**			10/06/2003 mem - added use of the Dataset_Name_Filter field in T_Peak_Matching_Defaults
**			01/06/2004 mem - Added support for Minimum_PMT_Quality_Score
**			03/05/2004 mem - Added support for Minimum_PMT_Quality_Score when no entry for @instrumentName exists in T_Peak_Matching_Defaults
**			03/22/2004 mem - Moved lookup of instrument name (in MT_Main.dbo.V_DMS_Analysis_Job_Paths) to be part of the INSERT INTO #TmpJobsToProcess query, drastically increasing the execution speed of this stored procedure when long lists of jobs need to be added to T_Peak_Matching_Task
**			04/08/2004 mem - Added @jobCountAdded output parameter
**			08/18/2004 mem - Added support for the Labelling_Filter field in T_Peak_Matching_Defaults
**			08/31/2004 mem - Fixed bug with null @MinimumPMTQualityScore for instruments without defaults
**			09/07/2004 mem - Changed logic to add multiple tasks for given job if several entries of the same Instrument_Name are present in T_Peak_Matching_Defaults
**			09/20/2004 mem - Updated to new MTDB schema
**			10/08/2004 mem - Switched from using MT_Main..V_DMS_Analysis_Job_Paths to V_DMS_Analysis_Job_Import
**			03/04/2005 mem - Added support for Minimum_High_Discriminant_Score
**			06/28/2005 mem - Increased size of @IniFileName to 255 characters
**			07/18/2005 mem - Now obtaining Instrument and Labelling from T_FTICR_Analysis_Description
**			07/31/2006 mem - Increased size of @JobListFilter parameter to 2048 characters and added check for trailing comma
**			08/29/2006 mem - Updated the default value for @SetStateToHolding to now be 1
**			09/06/2006 mem - Added support for Minimum_Peptide_Prophet_Probability
**			12/01/2006 mem - Now using udfParseDelimitedIntegerList to parse @JobListFilter
**			03/14/2007 mem - Changed @JobListOverride parameter from varchar(8000) to varchar(max)
**			06/16/2009 mem - Updated to allow Instrument_Name, Dataset_Name_Filter, and Labelling_Filter to contain % wildcards in T_Peak_Matching_Defaults
**			06/16/2009 mem - Added parameter @InfoOnly
**			12/07/2009 mem - Changed the "Added job" display to be a Print instead of a Select
**			03/21/2011 mem - Changed default score filters to Discriminant >= 0, Peptide Prophet >= 0, and PMT Quality Score >= 2
**     
*****************************************************/
(
	@message varchar(255)='' output,
	@jobCountAdded int = 0 output,				-- Number of jobs added
	@JobListFilter varchar(max) = '',			-- Optional parameter: a comma separated list of Job Numbers; will only add the given jobs numbers
	@IniFileOverride varchar(255) = '',			-- Optional parameter: Ini FileName to use instead of the default one
	@SetStateToHolding tinyint = 1,				-- If 1, will set the Processing_State to 5 = Holding; otherwise, sets state at 1
	@InfoOnly tinyint = 0
)
AS
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @UsingJobListFilter tinyint
	set @UsingJobListFilter = 0

	Declare @iniFileName varchar(255)
	Declare @confirmedOnly tinyint 
	Declare @modList varchar(128)
	Declare @MinimumHighNormalizedScore float
	Declare @MinimumHighDiscriminantScore float
	Declare @MinimumPeptideProphetProbability real
	Declare @MinimumPMTQualityScore decimal(9,5)
	Declare @priority tinyint
	Declare @SetStateToHoldingThisJob tinyint

	Declare @S varchar(2048)
	Declare @Comparison varchar(12)

	Declare @instrumentFilter varchar(64)
	Declare @DatasetFilter varchar(255)	
	Declare @LabellingFilter varchar(64)
	
	Declare @result int
	Declare @taskID int
	Declare @job int
	declare @Labelling varchar(64)
	
	Declare @Continue int
	Declare @EntryID int

	Declare @DefaultID int
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	--
	Set @message = ''
	Set @jobCountAdded = 0
	Set @JobListFilter = LTrim(RTrim(IsNull(@JobListFilter, '')))
	Set @IniFileOverride = LTrim(RTrim(dbo.udfTrimToCRLF(IsNull(@IniFileOverride, ''))))
	Set @SetStateToHolding = IsNull(@SetStateToHolding, 1)
	If @SetStateToHolding <> 0
		Set @SetStateToHolding = 1
		
	Set @InfoOnly = IsNull(@InfoOnly, 0)
		
	---------------------------------------------------
	-- temporary table to hold list of jobs to process
	---------------------------------------------------
	
	CREATE TABLE #TmpJobsToProcess (
		Job int,
		InstrumentName varchar(200) NULL,
		Dataset varchar(200) NULL,
		Labelling varchar(64) NULL
	) 
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not Create temporary table #TmpJobsToProcess'
		goto Done
	End

	CREATE UNIQUE INDEX #IX_TmpJobsToProcess_Job ON #TmpJobsToProcess (Job)

	CREATE TABLE #TmpJobToPMDefaultMap (
		EntryID int Identity(1,1),
		Job int,
		Default_ID int
	)
	
	CREATE UNIQUE INDEX #IX_TmpJobToPMDefaultMap_EntryID ON #TmpJobToPMDefaultMap (EntryID)
	
	CREATE TABLE #XPMD (
		EntryID int Identity(1,1),
		Default_ID int,		
		Dataset_Name_Filter varchar(255) NULL,
		Labelling_Filter varchar(64) NULL
	) 
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not Create temporary table #XPMD'
		goto Done
	End
	
	If Len(@JobListFilter) > 0
	Begin
		---------------------------------------------------
		-- Populate a temporary table with the jobs in @JobListFilter
		---------------------------------------------------
		--
		CREATE TABLE #T_Tmp_JobListFilter (
			JobFilter int
		)
		
		INSERT INTO #T_Tmp_JobListFilter (JobFilter)
		SELECT DISTINCT Value
		FROM dbo.udfParseDelimitedIntegerList(@JobListFilter, ',')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error parsing Job Filter list'
			goto Done
		end

		Set @UsingJobListFilter = 1
	End

	---------------------------------------------------
	-- populate temporary table with list of FTICR
	-- analysis jobs that are not represented in task table
	---------------------------------------------------

	If @UsingJobListFilter = 1
	Begin
		-- Get list of jobs that match @JobListFilter (stored in table #T_Tmp_JobListFilter)
		INSERT INTO #TmpJobsToProcess (Job, InstrumentName, Dataset, Labelling)
		SELECT DISTINCT T.Job,
		                T.Instrument,
		                T.Dataset,
		                IsNull(T.Labelling, '')
		FROM T_FTICR_Analysis_Description AS T
		     INNER JOIN #T_Tmp_JobListFilter JobListQ
		       ON T.Job = JobListQ.JobFilter
		WHERE NOT T.Analysis_Tool LIKE '%TIC%'
		ORDER BY T.Job
	End
	Else
	Begin
		-- Get list of jobs that have no peak matching tasks
		--
		INSERT INTO #TmpJobsToProcess (Job, InstrumentName, Dataset, Labelling)
		SELECT DISTINCT T.Job,
		                T.Instrument,
		                T.Dataset,
		                IsNull(T.Labelling, '')
		FROM T_FTICR_Analysis_Description AS T
		WHERE (NOT EXISTS ( SELECT *
		                    FROM T_Peak_Matching_Task AS M
		                    WHERE T.job = M.job )) AND
		      (NOT T.Analysis_Tool LIKE '%TIC%') AND
		      (T.State <> 3)			-- Exclude jobs with State 3 = No Interest
		ORDER BY T.Job
	End
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not populate temporary table'
		goto Done
	End                       

	
	---------------------------------------------------
	-- Step through the entries in T_Peak_Matching_Defaults
	-- For each, find the jobs in #TmpJobsToProcess that match the instrument name filter, 
	--  dataset name filter, and labelling filter
	-- If a filter contains a % sign, then a LIKE comparison is used; otherwise, an exact match is used
	---------------------------------------------------
	
	Set @DefaultID = -1
	Set @Continue = 1
	While @Continue = 1
	Begin -- <a>
		
		SELECT TOP 1 @DefaultID = Default_ID,
		             @InstrumentFilter = Instrument_Name,
		             @DatasetFilter = Dataset_Name_Filter,
		             @LabellingFilter = Labelling_Filter
		FROM T_Peak_Matching_Defaults
		WHERE Default_ID > @DefaultID
		ORDER BY Default_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <b>
			Set @S = ''
			Set @S = @S + ' INSERT INTO #TmpJobToPMDefaultMap (Job, Default_ID)'
			Set @S = @S + ' SELECT Job, ' + Convert(varchar(12), @DefaultID)
			Set @S = @S + ' FROM #TmpJobsToProcess'
			Set @S = @S + ' WHERE '
			
			If @InstrumentFilter LIKE '%[%]%'
				Set @Comparison = 'LIKE'
			Else
				Set @Comparison = '='
				
			Set @S = @S + ' InstrumentName ' + @Comparison + ' ''' + @InstrumentFilter + ''''
			
			
			If IsNull(@DatasetFilter, '') <> ''
			Begin
				If @DatasetFilter LIKE '%[%]%'
					Set @Comparison = 'LIKE'
				Else
					Set @Comparison = '='
					
				Set @S = @S + ' AND Dataset ' + @Comparison + ' ''' + @DatasetFilter + ''''

			End

			If IsNull(@LabellingFilter, '') <> ''
			Begin
				If @LabellingFilter LIKE '%[%]%'
					Set @Comparison = 'LIKE'
				Else
					Set @Comparison = '='
					
				Set @S = @S + ' AND Labelling ' + @Comparison + ' ''' + @LabellingFilter + ''''

			End
			
			If @InfoOnly <> 0
				Print @S
			
			Exec (@S)

		End -- </b>
		
	End -- </a>
	
	If @InfoOnly <> 0
		SELECT JP.*,
		       JobMap.Default_ID
		FROM #TmpJobsToProcess JP
		     LEFT OUTER JOIN #TmpJobToPMDefaultMap JobMap
		       ON JP.Job = JobMap.Job
		ORDER BY JobMap.Job, JobMap.Default_ID

	---------------------------------------------------
	-- Create a peak matching task for each entry in #TmpJobToPMDefaultMap
	---------------------------------------------------
	
	Set @EntryID = 0
	Set @Continue = 1
	While @continue = 1
	Begin -- <c>
		-- Get next entry from #TmpJobToPMDefaultMap
		--
		SELECT TOP 1 @EntryID = JobMap.EntryID,
		             @DefaultID = JobMap.Default_ID,
		             @job = JobMap.Job,
		             @iniFileName = PMD.IniFile_Name,
		             @confirmedOnly = PMD.Confirmed_Only,
		             @modList = PMD.Mod_List,
		             @MinimumHighNormalizedScore = PMD.Minimum_High_Normalized_Score,
		             @MinimumHighDiscriminantScore = PMD.Minimum_High_Discriminant_Score,
		             @MinimumPeptideProphetProbability = PMD.Minimum_Peptide_Prophet_Probability,
		             @MinimumPMTQualityScore = PMD.Minimum_PMT_Quality_Score,
		             @priority = PMD.Priority
		FROM #TmpJobToPMDefaultMap JobMap
		     INNER JOIN T_Peak_Matching_Defaults PMD
		       ON JobMap.Default_ID = PMD.Default_ID
		WHERE EntryID > @EntryID
		ORDER BY EntryID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
		Begin
			-- Exit from loop If no more entries to process
			--
			Set @continue = 0
		End
		Else
		Begin -- <d>
			
			If Len(IsNull(@IniFileOverride, '')) > 0
				Set @iniFileName = @IniFileOverride

			Set @message = ''
			If @InfoOnly = 0
				Exec @result = AddUpdatePeakMatchingTask	@job, @iniFileName,
															@confirmedOnly, @modList,
															@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
															@MinimumPeptideProphetProbability, @MinimumPMTQualityScore,
															@priority, @taskID output,
															'add', @message output,
															@SetStateToHolding
						
			-- If AddUpdatePeakMatchingTask returns a message then an error occurred
			If @message <> ''
				exec PostLogEntry 'Error', @message, 'AddDefaultPeakMatchingTasks'				
			Else
			Begin
				If @JobListFilter <> '' OR @InfoOnly <> 0
					Print 'Added job ' + Convert(varchar(19), @job) + ' using default ID ' + Convert(varchar(12), @DefaultID)
				--
				Set @jobCountAdded = @jobCountAdded + 1
			End
			
		End -- </d>
	End -- </c>
   
	---------------------------------------------------
	-- Now process any jobs that didn't have any matching entries in T_Peak_Matching_Defaults
	---------------------------------------------------
	
	DELETE #TmpJobsToProcess
	FROM #TmpJobsToProcess J
	     INNER JOIN #TmpJobToPMDefaultMap JobMap
	       ON J.Job = JobMap.Job
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	
	IF Exists (SELECT * FROM #TmpJobsToProcess)
	Begin
		-- Find the minimum job number in #TmpJobsToProcess
		SELECT @Job = MIN(Job)
		FROM #TmpJobsToProcess
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @Job = IsNull(@Job, 0) - 1
		Set @Continue = 1
	End
	Else
		Set @Continue = 0
		
	While @Continue = 1
	Begin -- <e>
		SELECT TOP 1 @job = J.Job,
		             @Labelling = IsNull(FAD.Labelling, '')
		FROM #TmpJobsToProcess J
		     INNER JOIN T_FTICR_Analysis_Description FAD
		       ON J.Job = FAD.Job
		WHERE J.Job > @Job
		ORDER BY J.Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
		Begin
			-- Exit from loop If no more jobs
			--
			Set @continue = 0
		End
		Else
		Begin -- <f>
		
			-- This did not match an entry in T_Peak_Matching_Defaults
			-- Set @iniFileName to be @IniFileOverride or blank, and the other values to defaults
			-- The exception: If @Labelling is not 'none' or 'Unknown', then 
			--                set @iniFileName to '__' + @Labelling + '__' and @SetStateToHoldingThisJob to 1
			
			Set @iniFileName = IsNull(@IniFileOverride, '')
			Set @confirmedOnly = 0
			Set @modList = ''
			Set @MinimumHighNormalizedScore = 1
			Set @MinimumHighDiscriminantScore = 0
			Set @MinimumPeptideProphetProbability = 0
			Set @MinimumPMTQualityScore = 2
			Set @priority = 6
			Set @SetStateToHoldingThisJob = @SetStateToHolding

			If @Labelling <> 'none' AND @Labelling <> 'Unknown'
			Begin
				If Len(IsNull(@JobListFilter, '')) = 0
				Begin
					Set @iniFileName = '__' + @Labelling + '__'
					Set @SetStateToHoldingThisJob = 1
				End
			End

			Set @message = ''
			If @InfoOnly = 0
				Exec @result = AddUpdatePeakMatchingTask	@job, @iniFileName,
															@confirmedOnly, @modList,
															@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
															@MinimumPeptideProphetProbability, @MinimumPMTQualityScore,
															@priority, @taskID output,
															'add', @message output,
															@SetStateToHoldingThisJob

			-- If AddUpdatePeakMatchingTask returns a message then an error occurred
			If @message <> ''
				exec PostLogEntry 'Error', @message, 'AddDefaultPeakMatchingTasks'				
			Else
			Begin
				If @JobListFilter <> '' OR @InfoOnly <> 0
					Print 'Added job ' + Convert(varchar(19), @job) + ' (did not match a default ID in T_Peak_Matching_Defaults)'
				--
				Set @jobCountAdded = @jobCountAdded + 1
			End
		End -- </f>
	End -- </e>
			
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
Done:

	RETURN @myError


GO
GRANT EXECUTE ON [dbo].[AddDefaultPeakMatchingTasks] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddDefaultPeakMatchingTasks] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddDefaultPeakMatchingTasks] TO [MTS_DB_Lite] AS [dbo]
GO

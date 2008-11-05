/****** Object:  StoredProcedure [dbo].[AddDefaultPeakMatchingTasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE AddDefaultPeakMatchingTasks
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
**	Date:	6/24/2003
**
**			07/22/2003 mem
**			07/30/2003 mem
**			09/11/2003 mem - added new parameters
**			10/06/2003 mem - added use of the Dataset_Name_Filter field in T_Peak_Matching_Defaults
**			01/06/2004 mem - Added support for Minimum_PMT_Quality_Score
**			03/05/2004 mem - Added support for Minimum_PMT_Quality_Score when no entry for @instrumentName exists in T_Peak_Matching_Defaults
**			03/22/2004 mem - Moved lookup of instrument name (in MT_Main.dbo.V_DMS_Analysis_Job_Paths) to be part of the INSERT INTO #XAJ query, drastically increasing the execution speed of this stored procedure when long lists of jobs need to be added to T_Peak_Matching_Task
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
**     
*****************************************************/
(
	@message varchar(255)='' output,
	@jobCountAdded int = 0 output,				-- Number of jobs added
	@JobListFilter varchar(max) = '',			-- Optional parameter: a comma separated list of Job Numbers; will only add the given jobs numbers
	@IniFileOverride varchar(255) = '',			-- Optional parameter: Ini FileName to use instead of the default one
	@SetStateToHolding tinyint = 1				-- If 1, will set the Processing_State to 5 = Holding; otherwise, sets state at 1
)
AS
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @UsingJobListFilter tinyint
	set @UsingJobListFilter = 0
	
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
		
	---------------------------------------------------
	-- temporary table to hold list of jobs to process
	---------------------------------------------------
	
	CREATE TABLE #XAJ (
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
		Set @message = 'Could not Create temporary table #XAJ'
		goto Done
	End

	CREATE TABLE #XPMD (
		Default_ID int,		
		Checked int,
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
		SELECT Value
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
		INSERT INTO #XAJ
		SELECT	T.Job,
				T.Instrument,
				T.Dataset, IsNull(T.Labelling, '')
		FROM	T_FTICR_Analysis_Description AS T INNER JOIN
				#T_Tmp_JobListFilter JobListQ ON T.Job = JobListQ.JobFilter
		WHERE	NOT T.Analysis_Tool LIKE '%TIC%'
		ORDER BY T.Job
	End
	Else
	Begin
		-- Get list of jobs that have no peak matching tasks
		--
		INSERT INTO #XAJ
		SELECT	T.Job, 
				T.Instrument, 
				T.Dataset, IsNull(T.Labelling, '')
		FROM	T_FTICR_Analysis_Description AS T
		WHERE	(NOT EXISTS
					(	SELECT *
						FROM T_Peak_Matching_Task AS M
						WHERE T.job = M.job
					)
				) AND 
			    (NOT T.Analysis_Tool LIKE '%TIC%') AND (T.State <> 3)			-- Exclude jobs with State 3 = No Interest
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
	-- Declare default task parameters
	---------------------------------------------------
	--
	Declare @iniFileName varchar(255)
	Declare @confirmedOnly tinyint 
	Declare @modList varchar(128)
	Declare @MinimumHighNormalizedScore float
	Declare @MinimumHighDiscriminantScore float
	Declare @MinimumPeptideProphetProbability real
	Declare @MinimumPMTQualityScore decimal(9,5)
	Declare @priority tinyint
	Declare @SetStateToHoldingThisJob tinyint

	
	---------------------------------------------------
	-- Create a peak matching task for each job using
	-- the default parameters
	---------------------------------------------------
	Declare @instrumentName varchar(64)
	Declare @Dataset varchar(255)	
	Declare @Labelling varchar(64)
	
	Declare @result int
	Declare @taskID int
	Declare @job int
	Declare @continue int
	Declare @DefaultIDDone tinyint

	Declare @ThisDefaultID int
	Declare @ThisFilter varchar(1024)
	Declare @MatchFound tinyint
		
	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		-- Get next job from temporary table, plus instrument and dataset for the job
		--
		SELECT TOP 1 @job = Job,
					 @instrumentName = InstrumentName,
					 @Dataset = Dataset,
					 @Labelling = Labelling
		FROM #XAJ
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0 OR @myError <> 0
		Begin
			-- Exit from loop If no more jobs to do
			--
			Set @continue = 0
		End
		Else
		Begin -- <b>
			-- Make Sure #XPMD is empty
			TRUNCATE TABLE #XPMD
			
			-- Make sure @MatchFound is 0
			Set @MatchFound = 0
					
			-- Obtain a list of Default_ID values for entries in T_Peak_Matching_Defaults that
			--  match this instrument and have a filter defined
			INSERT INTO #XPMD (Default_ID, Checked, Dataset_Name_Filter, Labelling_Filter)
			SELECT Default_ID, 0 AS Checked, Dataset_Name_Filter, Labelling_Filter
			FROM T_Peak_Matching_Defaults
			WHERE Instrument_Name = @instrumentName AND 
					(Len(IsNull(Dataset_Name_Filter, '')) > 0) AND
					IsNull(Labelling_Filter, '') = @Labelling
			ORDER BY Default_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount > 0 AND Len(IsNull(@IniFileOverride, '')) = 0
			Begin -- <c1>
				-- For each entry in #XPMD, see if Dataset_Name_Filter matches this job's dataset
				-- However, do not do this if @IniFileOverride is defined
				Set @DefaultIDDone = 0
				While @DefaultIDDone = 0
				Begin -- <d>
					Set @ThisFilter = ''
					SELECT TOP 1 @ThisDefaultID = Default_ID, @ThisFilter = IsNull(Dataset_Name_Filter, '')
					FROM #XPMD
					WHERE Checked = 0
					ORDER BY Default_ID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					If @myRowCount = 0
						Set @DefaultIDDone = 1
					Else
					Begin -- <e>
						
						UPDATE #XPMD
						SET Checked = 1
						WHERE Default_ID = @ThisDefaultID

						-- See if the filter matches this dataset
						-- If Match, then Set @MatchFound = 1
						-- If no match, then delete from #XPMD
						
						If PatIndex(@ThisFilter, @Dataset) > 0
							-- A match was found with the filter
							Set @MatchFound = 1
						Else
							DELETE FROM #XPMD
							WHERE Default_ID = @ThisDefaultID
					End -- </e>
				End -- </d>
			End -- </c1>

			-- If @MatchFound = 0, but one or more entries exist in T_Peak_Matching_Defaults having a Null Filter,
			--  then add that entry to #XPMD
			If @MatchFound = 0
			Begin -- <c2>
				TRUNCATE TABLE #XPMD
		
				INSERT INTO #XPMD (Default_ID, Checked)
				SELECT Default_ID, 1 AS Checked
				FROM T_Peak_Matching_Defaults
				WHERE Instrument_Name = @instrumentName AND 
					(Len(IsNull(Dataset_Name_Filter, '')) = 0) AND
					IsNull(Labelling_Filter, '') = @Labelling
				ORDER BY Default_ID Desc
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @myRowCount > 0
					Set @MatchFound = 1
			End -- </c2>

			If @MatchFound <> 0
			Begin -- <c3>
				-- Either a match was found using Dataset_Name_Filter, or the default entry was found
				
				-- #XPMD now contains one or more Default_ID values
				-- Step through #XPMD and obtain the parameters for each Default_ID in the table, calling
				--   AddUpdatePeakMatchingTask for each
				Set @DefaultIDDone = 0
				While @DefaultIDDone = 0
				Begin -- <d3>
					-- Set default task parameters based on instrument for ThisDefaultID
					--

					SELECT TOP 1 @ThisDefaultID = Default_ID
					FROM #XPMD
					ORDER BY Default_ID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount

					If @myRowCount = 0
					Begin
						Set @DefaultIDDone = 1
					End
					Else
					Begin -- <e3>
						
						SELECT TOP 1
							@iniFileName = IniFile_Name, 
							@confirmedOnly = Confirmed_Only, 
							@modList = Mod_List, 
							@MinimumHighNormalizedScore = Minimum_High_Normalized_Score,
							@MinimumHighDiscriminantScore = Minimum_High_Discriminant_Score,
							@MinimumPeptideProphetProbability = Minimum_Peptide_Prophet_Probability,
							@MinimumPMTQualityScore = Minimum_PMT_Quality_Score,
							@priority = Priority
						FROM T_Peak_Matching_Defaults
						WHERE Default_ID = @ThisDefaultID
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						--
						If @myError <> 0
						Begin
							Set @message = 'Could not get default values for peak matching task'
							goto Done
						End
						Else
						Begin -- <f3>
							If Len(IsNull(@IniFileOverride, '')) > 0
								Set @iniFileName = @IniFileOverride

							Exec @result = AddUpdatePeakMatchingTask	@job, @iniFileName,
																		@confirmedOnly, @modList,
																		@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
																		@MinimumPeptideProphetProbability, @MinimumPMTQualityScore,
																		@priority, @taskID output,
																		'add', @message output,
																		@SetStateToHolding

							DELETE FROM #XPMD
							WHERE Default_ID = @ThisDefaultID
						End -- </f3>
					End -- </e3>
				End -- </d3>
			End -- </c3>
			Else
			Begin -- <c4>
				-- Either no entry for @instrumentName exists in T_Peak_Matching_Defaults, or
				--  an entry exists, but the labelling method isn't compatible (or is Null)
				-- In this case, set @iniFileName to be @IniFileOverride or blank, and the other values to defaults
				-- The exception: If @Labelling is not 'none' or 'Unknown', then 
				--                set @iniFileName to '__' + @Labelling + '__' and @SetStateToHoldingThisJob to 1
				

				Set @iniFileName = IsNull(@IniFileOverride, '')
				Set @confirmedOnly = 0
				Set @modList = ''
				Set @MinimumHighNormalizedScore = 1
				Set @MinimumHighDiscriminantScore = 0.2
				Set @MinimumPeptideProphetProbability = 0.2
				Set @MinimumPMTQualityScore = 1
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

				Exec @result = AddUpdatePeakMatchingTask	@job, @iniFileName,
															@confirmedOnly, @modList,
															@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
															@MinimumPeptideProphetProbability, @MinimumPMTQualityScore,
															@priority, @taskID output,
															'add', @message output,
															@SetStateToHoldingThisJob
			End -- </c4>
						
			-- output message if one is returned
			--
			If @message <> ''
			Begin
				exec PostLogEntry 'Error', @message, 'AddDefaultPeakMatchingTasks'				
			End
			Else
			Begin
				Select 'Added job ' + Convert(varchar(19), @job)
				--
				Set @jobCountAdded = @jobCountAdded + 1
			End
			
			-- remove current job from temporary table
			--
			DELETE FROM #XAJ WHERE Job = @job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			If @myError <> 0
			Begin
				Set @message = 'Could not remove job from temporary table'
				goto Done
			End

		End -- </b>
	End -- </a>
   

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
Done:

	RETURN @myError

GO
GRANT EXECUTE ON [dbo].[AddDefaultPeakMatchingTasks] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[AddDefaultPeakMatchingTasks] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[AddDefaultPeakMatchingTasks] TO [MTS_DB_Lite]
GO

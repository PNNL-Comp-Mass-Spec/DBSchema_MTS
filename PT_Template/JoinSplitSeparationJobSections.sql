/****** Object:  StoredProcedure [dbo].[JoinSplitSeparationJobSections] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.JoinSplitSeparationJobSections
/****************************************************
**
**	Desc: 
**		Creates joined Sequest and Masic jobs for a series
**		of datasets that are actually sections from a very long LC-MS/MS analysis
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/03/2006
**			11/06/2006 mem - Added fields Protein_Collection_List and Protein_Options_List to the Insert Queries that add joined jobs to T_Analysis_Description
**			11/02/2007 mem - Added field @UseExistingDatasetAndMASICJob
**			08/14/2008 mem - Renamed Organism field to Experiment_Organism in T_Analysis_Job
**    
*****************************************************/
(
	@DatasetMatch varchar(128) = '',		-- Example: 'EIF_NAF_149C_YS02a%'
	@SectionNumberPatternMatch varchar(24) = '%[_]Sec-%',		-- Used to parse out the section number from the dataset, e.g. '%[_]Sec-%' will match "_Sec-" in EIF_NAF_149C_YS02a_Sec-1_14Jan06_2m-50u-id
	@SectionNumberPatternMatchOffset int = 5,	-- Number of characters that will actually be matched by @SectionNumberPatternMatch
	@SectionNumberExtractLength int = 1,		-- Number of digits to extract following the match to @SectionNumberPatternMatch plus @SectionNumberPatternMatchOffset
	@JoinedDatasetID int = 0,				-- If 0, then picks the next highest value in T_Datasets >= 11000000; Or, specify an explicit value, e.g. 11000100
	@JoinedMASICJobNum int = 0,				-- If 0, then picks the next highest value in T_Analysis_Description >= 11000001; Or, specify an explicit value, e.g. 11000101
	@JoinedSequestJobNum int = 0,			-- If 0, then picks the next highest value in T_Analysis_Description >= 11000001 and > @JoinedMASICJobNum; Or, specify an explicit value, e.g. 11000102
	@UseExistingDatasetAndMASICJob tinyint = 0,		-- If 1, then doesn't try to create a new dataset and MASIC job and only joins the matching Sequest jobs
	@DataAlreadyLoaded tinyint = 1,
	@InfoOnly tinyint = 1,					-- Set to 1 to preview the joined dataset name and joined job IDs
	@message varchar(512) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowcount int
	set @myRowcount = 0
	set @myError = 0

	Declare @MinJoinedJobValue int
	Set @MinJoinedJobValue = 11000000
	
	Declare @Task varchar(512)
	Declare @JoinedDataset varchar(256)
	Declare @MatchCount int
	Declare @TestSectionNum int
	
	-----------------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------------
	Set @JoinedDatasetID = IsNull(@JoinedDatasetID, 0)
	Set @JoinedMASICJobNum = IsNull(@JoinedMASICJobNum, 0)
	Set @JoinedSequestJobNum = IsNull(@JoinedSequestJobNum, 0)
	Set @UseExistingDatasetAndMASICJob = IsNull(@UseExistingDatasetAndMASICJob, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 1)
	
	Set @message = ''
	
	If Len(IsNull(@DatasetMatch, '')) = 0
	Begin
		set @Message = 'Error: @DatasetMatch cannot be blank'
		goto Done
	End
	
	If Right(@DatasetMatch, 1) <> '%'
	Begin
		set @Message = 'Error: @DatasetMatch must end with a % wildcard character'
		goto Done
	End
	
	If @JoinedDatasetID > 0 And @JoinedDatasetID < @MinJoinedJobValue
	Begin
		set @Message = 'Error: Explicit Dataset ID must be >= ' + Convert(varchar(18), @MinJoinedJobValue)
		goto Done
	End

	If @JoinedMASICJobNum > 0 And @JoinedMASICJobNum < @MinJoinedJobValue
	Begin
		set @Message = 'Error: Explicit Masic Job must be >= ' + Convert(varchar(18), @MinJoinedJobValue)
		goto Done
	End
	
	If @JoinedSequestJobNum > 0 And @JoinedSequestJobNum < @MinJoinedJobValue
	Begin
		set @Message = 'Error: Explicit Sequest Job must be >= ' + Convert(varchar(18), @MinJoinedJobValue)
		goto Done
	End

	If @UseExistingDatasetAndMASICJob <> 0 And @JoinedDatasetID = 0
	Begin
		set @Message = 'Error: An explicit JoinedDatasetID must be provided when @UseExistingDatasetAndMASICJob is non-zero'
		goto Done
	End
		
	If @UseExistingDatasetAndMASICJob <> 0 And @JoinedMASICJobNum = 0
	Begin
		set @Message = 'Error: An explicit JoinedMASICJobNum must be provided when @UseExistingDatasetAndMASICJob is non-zero'
		goto Done
	End
		
	
	If @UseExistingDatasetAndMASICJob = 0
	Begin
		-----------------------------------------------------------
		-- Validate that @DatasetMatch matches at least 2 Masic Jobs
		-----------------------------------------------------------
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM T_Analysis_Description
		WHERE Dataset Like @DatasetMatch AND Analysis_Tool Like 'Masic%'
		
		If @MatchCount = 0
		Begin
			set @Message = 'Error: Dataset match spec "' + @DatasetMatch + '" did not match any Masic jobs'
			goto Done
		End
		
		If @MatchCount = 1
		Begin
			set @Message = 'Error: Dataset match spec "' + @DatasetMatch + '" only matched one Masic job'
			goto Done
		End
	End
	
	-----------------------------------------------------------
	-- Validate that @DatasetMatch matches at least 2 Sequest Jobs
	-----------------------------------------------------------
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM T_Analysis_Description
	WHERE Dataset Like @DatasetMatch AND Analysis_Tool = 'Sequest' AND Job < @MinJoinedJobValue
	
	If @MatchCount = 0
	Begin
		set @Message = 'Error: Dataset match spec "' + @DatasetMatch + '" did not match any Sequest jobs'
		goto Done
	End
	
	If @MatchCount = 1
	Begin
		set @Message = 'Error: Dataset match spec "' + @DatasetMatch + '" only matched one Sequest job'
		goto Done
	End
	
	
	-----------------------------------------------------------
	-- Validate that @SectionNumberPatternMatch matches a portion of the dataset names and that
	-- use of @SectionNumberPatternMatchOffset and @SectionNumberExtractLength extracts an integer
	-----------------------------------------------------------
	Set @TestSectionNum = 0
	SELECT @TestSectionNum = CONVERT(int, SUBSTRING(Dataset, PATINDEX(@SectionNumberPatternMatch, Dataset) + @SectionNumberPatternMatchOffset, @SectionNumberExtractLength))
	FROM T_Analysis_Description
	WHERE Dataset Like @DatasetMatch AND Analysis_Tool = 'Sequest' AND Job < @MinJoinedJobValue
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @myError <> 0 OR IsNull(@TestSectionNum, 0) < 1
	Begin
		set @Message = 'Error: Test extraction of section numbers failed'
		If @myError <> 0
			Set @message = @message + '; Error Number ' + Convert(varchar(12), @myError)
		goto Done
	End
	
	If @myRowCount <> @MatchCount
	Begin
		set @Message = 'Error: Test extraction of section numbers matched ' + Convert(varchar(12), @myRowCount) + ' rows instead of ' + Convert(varchar(12), @MatchCount) + ' rows'
		goto Done
	End
	

	If @UseExistingDatasetAndMASICJob = 0
	Begin

		-----------------------------------------------------------
		-- Validate @JoinedDatasetID; auto define if 0
		-----------------------------------------------------------
		If @JoinedDatasetID <= 0
		Begin
			SELECT @JoinedDatasetID = MAX(Dataset_ID)
			FROM T_Datasets
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			If IsNull(@JoinedDatasetID, 0) < @MinJoinedJobValue
				Set @JoinedDatasetID = @MinJoinedJobValue
			Else
				Set @JoinedDatasetID = @JoinedDatasetID + 1
		End

		-- Make sure @JoinedDatasetID doesn't exist yet
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM T_Datasets
		WHERE Dataset_ID = @JoinedDatasetID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @MatchCount > 0
		Begin
			set @Message = 'Error: Dataset ' + Convert(varchar(18), @JoinedDatasetID) + ' already exists; unable to create joined dataset'
			goto Done
		End
		
		-----------------------------------------------------------
		-- Validate @JoinedMASICJobNum; auto define if 0
		-----------------------------------------------------------
		If @JoinedMASICJobNum <= 0
		Begin
			SELECT @JoinedMASICJobNum = MAX(Job)
			FROM T_Analysis_Description
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			If IsNull(@JoinedMASICJobNum, 0) < 11000001
				Set @JoinedMASICJobNum = 11000001
			Else
				Set @JoinedMASICJobNum = @JoinedMASICJobNum + 1
		End

		-----------------------------------------------------------
		-- Make sure @JoinedMASICJobNum doesn't exist yet
		-----------------------------------------------------------
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM T_Analysis_Description
		WHERE Job = @JoinedMASICJobNum
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @MatchCount > 0
		Begin
			set @Message = 'Error: Job ' + Convert(varchar(18), @JoinedMASICJobNum) + ' already exists; unable to create joined Masic job'
			goto Done
		End
	End
	
	-----------------------------------------------------------
	-- Validate @JoinedSequestJobNum; auto define if 0
	-----------------------------------------------------------
	If @JoinedSequestJobNum <= 0
	Begin
		SELECT @JoinedSequestJobNum = MAX(Job)
		FROM T_Analysis_Description
		WHERE Job > @JoinedMASICJobNum
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If IsNull(@JoinedSequestJobNum, 0) < @JoinedMASICJobNum+1
			Set @JoinedSequestJobNum = @JoinedMASICJobNum+1
		Else
			Set @JoinedSequestJobNum = @JoinedSequestJobNum + 1
	End

	-----------------------------------------------------------
	-- Make sure @JoinedSequestJobNum doesn't exist yet
	-----------------------------------------------------------
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM T_Analysis_Description
	WHERE Job = @JoinedSequestJobNum
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @MatchCount > 0
	Begin
		set @Message = 'Error: Job ' + Convert(varchar(18), @JoinedSequestJobNum) + ' already exists; unable to create joined Sequest job'
		goto Done
	End

	If @JoinedSequestJobNum = @JoinedMASICJobNum
	Begin
		set @Message = 'Error: Sequest Job ' + Convert(varchar(18), @JoinedSequestJobNum) + ' matches Masic job '  + Convert(varchar(18), @JoinedMASICJobNum) + '; unable to continue'
		goto Done
	End
	

	If @UseExistingDatasetAndMASICJob = 0
	Begin
		-----------------------------------------------------------
		-- Define @JoinedDataset
		-----------------------------------------------------------
		Set @JoinedDataset = Left(@DatasetMatch, Len(@DatasetMatch)-1) + '_JoinedDataset'

		-----------------------------------------------------------
		-- Make sure @JoinedDataset doesn't exist yet
		-----------------------------------------------------------
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM T_Datasets
		WHERE Dataset = @JoinedDataset
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @MatchCount > 0
		Begin
			set @Message = 'Error: Joined Dataset ' + @JoinedDataset + ' already exists; unable to continue'
			goto Done
		End
	End
	Else
	Begin
		-----------------------------------------------------------
		-- Define @JoinedDataset
		-----------------------------------------------------------
		SELECT @JoinedDataset = Dataset
		FROM T_Datasets
		WHERE Dataset_ID = @JoinedDatasetID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @MatchCount > 0
		Begin
			set @Message = 'Error: Joined Dataset ID' + Convert(varchar(12), @JoinedDatasetID) + ' not found in T_Datasets'
			goto Done
		End
	End
	
	-- Preview the values to use
	SELECT	@JoinedDatasetID as Joined_DatasetID, 
			@JoinedMASICJobNum as Joined_Masic_Job, 
			@JoinedSequestJobNum as Joined_Sequest_Job,  
			@JoinedDataset as Joined_Dataset
	
	If @InfoOnly <> 0
		Goto Done

	-----------------------------------------------------------
	-- Populate a temporary table with the jobs matching the criteria
	-----------------------------------------------------------
	
	CREATE TABLE #TmpSourceJobs (
		Job int NOT NULL,
		ResultType varchar(64) NOT NULL
	)
	
	INSERT INTO #TmpSourceJobs (Job, ResultType)
	SELECT Job, ResultType
	FROM T_Analysis_Description
	WHERE (Dataset LIKE @DatasetMatch) AND (Job < @MinJoinedJobValue) And 
		  Process_State >= 10 AND Not ResultType IS Null
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myRowCount = 0
	Begin
		Set @message = 'Could not find any jobs matching "' + @DatasetMatch + '" and having Process_State >= 10'
		Goto Done
	End
	
	--Update the Source Jobs to be used to Process_State 7
	UPDATE T_Analysis_Description
	SET Process_State = 7
	FROM T_Analysis_Description TAD INNER JOIN 
		 #TmpSourceJobs ON TAD.Job = #TmpSourceJobs.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
	Begin
		Set @message = 'Error setting Process_State to 7 for jobs matching "' + @DatasetMatch + '"'
		Goto Done
	End
	
	/*
	--Preview the datasets in T_Datasets to be joined
	SELECT *
	FROM T_Datasets
	WHERE (Dataset LIKE @DatasetMatch) AND (Job < @MinJoinedJobValue)
	ORDER BY Dataset_ID	
	*/

	If @UseExistingDatasetAndMASICJob = 0
	Begin
		--Create the Joined_Dataset in T_Datasets, keep the SIC job at NULL for now
		INSERT INTO T_Datasets
			(Dataset_ID, Dataset, Type, Created_DMS, Acq_Time_Start, 
			Acq_Time_End, Scan_Count, Created, Dataset_Process_State)
		SELECT @JoinedDatasetID AS Dataset_ID, 
			@JoinedDataset AS Dataset, 
			Type, GetDate() AS Created_DMS, MIN(Acq_Time_Start) 
			AS Acq_Time_Start, MAX(Acq_Time_End) AS Acq_Time_End, 
			SUM(Scan_Count) AS Scan_Count, GetDate() AS Created, 
			10 AS Dataset_Process_State
		FROM T_Datasets
		WHERE (Dataset LIKE @DatasetMatch) AND 
			(Dataset_ID < 10000000)
		GROUP BY Type
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			Set @message = 'Error creating joined dataset "' + @JoinedDataset + '" for jobs matching "' + @DatasetMatch + '"'
			Goto Done
		End
		--
		If @myRowCount <> 1
		Begin
			Set @message = 'Error: Inserted ' + Convert(varchar(12), @myRowCount) + ' rows into  T_Datasets for "' + @JoinedDataset + '"; expecting just 1 row'
			Goto Done
		End
	End
	
	/*
	--Populate Scan_Count for the Joined Dataset with the sum of the Scan_Count values for the joined datasets, keep the SIC job at NULL for now
	--The above INSERT query shold have already populated Scan_Count, but this can be used to update the value if needed
	UPDATE T_Datasets
	SET Scan_Count = 
		(SELECT SUM(Scan_Count) AS ScanCount
		FROM T_Datasets
		WHERE (Dataset LIKE @DatasetMatch) AND Dataset_ID < 10000000)
	*/

	/*
	--Create the Joined_Jobs in T_Analysis_Description; make one SIC job and one Sequest job; set their dataset to the Joined_Dataset's ID
	SELECT *
	FROM T_Analysis_Description
	WHERE (Dataset LIKE @DatasetMatch) AND 
		(Analysis_Tool = 'Sequest')
	*/
	
	If @UseExistingDatasetAndMASICJob = 0
	Begin
		INSERT INTO T_Analysis_Description
			(Job, Dataset, Dataset_ID, Experiment, Campaign, Experiment_Organism, 
			Instrument_Class, Instrument, Analysis_Tool, 
			Parameter_File_Name, Settings_File_Name, 
			Organism_DB_Name, Protein_Collection_List, Protein_Options_List, 
			Vol_Client, Vol_Server, Storage_Path, 
			Dataset_Folder, Results_Folder, Completed, ResultType, 
			Separation_Sys_Type, PreDigest_Internal_Std, 
			PostDigest_Internal_Std, Dataset_Internal_Std, Enzyme_ID, 
			Labelling, Created, Last_Affected, Process_State)
		SELECT  @JoinedMASICJobNum AS Job, 
				@JoinedDataset AS Dataset, 
				@JoinedDatasetID AS DatasetID, TAD.Experiment, TAD.Campaign, TAD.Experiment_Organism, 
				TAD.Instrument_Class, TAD.Instrument, TAD.Analysis_Tool, 
				TAD.Parameter_File_Name, TAD.Settings_File_Name, 
				TAD.Organism_DB_Name, TAD.Protein_Collection_List, TAD.Protein_Options_List, 
				'Virtual' AS Vol_Client, 'Virtual' AS Vol_Server, 'Virtual' AS Storage_Path, 
				'Virtual' AS Dataset_Folder, 'Virtual' AS Results_Folder, 
				GetDate() AS Completed, TAD.ResultType, TAD.Separation_Sys_Type, 
				TAD.PreDigest_Internal_Std, TAD.PostDigest_Internal_Std, 
				TAD.Dataset_Internal_Std, TAD.Enzyme_ID, TAD.Labelling, 
				GetDate() AS Created, GetDate() AS Last_Affected, 
				6 AS Process_State
		FROM T_Analysis_Description TAD INNER JOIN 
			 #TmpSourceJobs ON TAD.Job = #TmpSourceJobs.Job
		WHERE TAD.ResultType = 'SIC'
		GROUP BY TAD.Experiment, TAD.Campaign, TAD.Experiment_Organism, TAD.Instrument_Class, 
			TAD.Instrument, TAD.Analysis_Tool, TAD.Parameter_File_Name, 
			TAD.Settings_File_Name, TAD.Organism_DB_Name, TAD.Protein_Collection_List, TAD.Protein_Options_List, 
			TAD.ResultType, TAD.Separation_Sys_Type, TAD.PreDigest_Internal_Std, 
			TAD.PostDigest_Internal_Std, TAD.Dataset_Internal_Std, TAD.Enzyme_ID, 
			TAD.Labelling
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			Set @message = 'Error creating joined MASIC job ' + Convert(varchar(18), @JoinedMASICJobNum) +  ' for jobs matching "' + @DatasetMatch + '"'
			Goto Done
		End
		--
		If @myRowCount <> 1
		Begin
			Set @message = 'Error: Inserted ' + Convert(varchar(12), @myRowCount) + ' rows into T_Analysis_Description for Masic jobs matching "' + @DatasetMatch + '"; expecting just 1 row'
			Goto Done
		End
	End
	
	INSERT INTO T_Analysis_Description
		(Job, Dataset, Dataset_ID, Experiment, Campaign, Experiment_Organism, 
		Instrument_Class, Instrument, Analysis_Tool, 
		Parameter_File_Name, Settings_File_Name, 
		Organism_DB_Name, Protein_Collection_List, Protein_Options_List, 
		Vol_Client, Vol_Server, Storage_Path, 
		Dataset_Folder, Results_Folder, Completed, ResultType, 
		Separation_Sys_Type, PreDigest_Internal_Std, 
		PostDigest_Internal_Std, Dataset_Internal_Std, Enzyme_ID, 
		Labelling, Created, Last_Affected, Process_State)
	SELECT  @JoinedSequestJobNum AS Job, 
			@JoinedDataset AS Dataset, 
			@JoinedDatasetID AS DatasetID, TAD.Experiment, TAD.Campaign, TAD.Experiment_Organism, 
			TAD.Instrument_Class, TAD.Instrument, TAD.Analysis_Tool, 
			TAD.Parameter_File_Name, TAD.Settings_File_Name, 
			TAD.Organism_DB_Name, TAD.Protein_Collection_List, TAD.Protein_Options_List, 
			'Virtual' AS Vol_Client, 'Virtual' AS Vol_Server, 'Virtual' AS Storage_Path, 
			'Virtual' AS Dataset_Folder, 'Virtual' AS Results_Folder, 
			GetDate() AS Completed, TAD.ResultType, TAD.Separation_Sys_Type, 
			TAD.PreDigest_Internal_Std, TAD.PostDigest_Internal_Std, 
			TAD.Dataset_Internal_Std, TAD.Enzyme_ID, TAD.Labelling, 
			GetDate() AS Created, GetDate() AS Last_Affected, 
			6 AS Process_State
	FROM T_Analysis_Description TAD INNER JOIN 
		 #TmpSourceJobs ON TAD.Job = #TmpSourceJobs.Job
	WHERE (TAD.ResultType = 'Peptide_Hit')
	GROUP BY TAD.Experiment, TAD.Campaign, TAD.Experiment_Organism, TAD.Instrument_Class, 
			TAD.Instrument, TAD.Analysis_Tool, TAD.Parameter_File_Name, 
			TAD.Settings_File_Name, TAD.Organism_DB_Name, TAD.Protein_Collection_List, TAD.Protein_Options_List, 
			TAD.ResultType, TAD.Separation_Sys_Type, TAD.PreDigest_Internal_Std, 
			TAD.PostDigest_Internal_Std, TAD.Dataset_Internal_Std, TAD.Enzyme_ID, 
			TAD.Labelling
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
	Begin
		Set @message = 'Error creating joined Sequest job ' + Convert(varchar(18), @JoinedSequestJobNum) +  ' for jobs matching "' + @DatasetMatch + '"'
		Goto Done
	End
	--
	If @myRowCount <> 1
	Begin
		Set @message = 'Error: Inserted ' + Convert(varchar(12), @myRowCount) + ' rows into T_Analysis_Description for Sequest jobs matching "' + @DatasetMatch + '"; expecting just 1 row'
		Goto Done
	End

	/*
	--Update the Joined_Dataset in T_Datasets to point to the SIC job we just made
	SELECT *
	FROM T_Datasets
	WHERE (Dataset = @JoinedDataset)
	ORDER BY Dataset_ID
	*/
	
	If @UseExistingDatasetAndMASICJob = 0
	Begin
		UPDATE T_Datasets
		SET SIC_Job = @JoinedMASICJobNum, Dataset_Process_State = 20
		WHERE (Dataset = @JoinedDataset) AND 
			  (Dataset_Process_State = 10)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			Set @message = 'Error updating SIC_Job and Dataset_Process_State for Dataset ' + @JoinedDataset
			Goto Done
		End

		-- Populate T_Joined_Job_Details with the MASIC jobs
		INSERT INTO T_Joined_Job_Details
			(Joined_Job_ID, Source_Job, Section)
		SELECT @JoinedMASICJobNum AS Joined_Job_ID, 
			   TAD.Job, 
			   CONVERT(int, SUBSTRING(TAD.Dataset, PATINDEX(@SectionNumberPatternMatch, TAD.Dataset) + @SectionNumberPatternMatchOffset, @SectionNumberExtractLength)) AS Section
		FROM T_Analysis_Description TAD INNER JOIN 
			 #TmpSourceJobs ON TAD.Job = #TmpSourceJobs.Job
		WHERE TAD.ResultType = 'SIC'
		ORDER BY CONVERT(int, SUBSTRING(TAD.Dataset, PATINDEX(@SectionNumberPatternMatch, TAD.Dataset) + @SectionNumberPatternMatchOffset, @SectionNumberExtractLength))
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			Set @message = 'Error Populating T_Joined_Job_Details with the MASIC jobs to join'
			Goto Done
		End
		--
		If @myRowCount = 0
		Begin
			Set @message = 'Error: Inserted 0 rows into T_Joined_Job_Details for MASIC jobs matching "' + @DatasetMatch + '"'
			Goto Done
		End
	End
	
	-- Populate T_Joined_Job_Details with the Sequest jobs
	INSERT INTO T_Joined_Job_Details
		(Joined_Job_ID, Source_Job, Section)
	SELECT @JoinedSequestJobNum AS Joined_Job_ID, 
		   TAD.Job, 
		   CONVERT(int, SUBSTRING(TAD.Dataset, PATINDEX(@SectionNumberPatternMatch, TAD.Dataset) + @SectionNumberPatternMatchOffset, @SectionNumberExtractLength)) AS Section
	FROM T_Analysis_Description TAD INNER JOIN 
		 #TmpSourceJobs ON TAD.Job = #TmpSourceJobs.Job
	WHERE TAD.ResultType = 'Peptide_Hit'
	ORDER BY CONVERT(int, SUBSTRING(TAD.Dataset, PATINDEX(@SectionNumberPatternMatch, TAD.Dataset) + @SectionNumberPatternMatchOffset, @SectionNumberExtractLength))
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
	Begin
		Set @message = 'Error Populating T_Joined_Job_Details with the Sequest jobs to join'
		Goto Done
	End
	--
	If @myRowCount = 0
	Begin
		Set @message = 'Error: Inserted 0 rows into T_Joined_Job_Details for Sequest jobs matching "' + @DatasetMatch + '"'
		Goto Done
	End

	/*
	-- Validate data in T_Joined_Job_Details
	SELECT *
	FROM T_Joined_Job_Details
	WHERE (Joined_Job_ID IN (@JoinedMASICJobNum, @JoinedSequestJobNum))
	*/

	-- Optional: Wait for the data to load
	-- Note: Non-Masic jobs will process up to state 39 and then wait there

	If @DataAlreadyLoaded = 0
	Begin
		Set @message = 'Waiting for data to load; continue updates manually after data loads'
		Goto Done		
	End
	
	If @UseExistingDatasetAndMASICJob = 0
	Begin
		-- Use the SIC data to populate the Scan_Number and Scan_Time Start/End fields
		UPDATE T_Joined_Job_Details
		SET Scan_Number_Start = LookupQ.Scan_Number_Start, 
			Scan_Number_End = LookupQ.Scan_Number_End, 
			Scan_Time_Start = LookupQ.Scan_Time_Start, 
			Scan_Time_End = LookupQ.Scan_Time_End
			FROM (SELECT JJD.Joined_Job_ID, JJD.Section, DSS.Job, 
					MIN(DSS.Scan_Number) AS Scan_Number_Start, 
					MAX(DSS.Scan_Number) AS Scan_Number_End, 
					MIN(DSS.Scan_Time) AS Scan_Time_Start, 
					MAX(DSS.Scan_Time) AS Scan_Time_End
				FROM T_Joined_Job_Details JJD INNER JOIN
					T_Analysis_Description TAD_JoinedJob ON JJD.Joined_Job_ID = TAD_JoinedJob.Job INNER JOIN
					T_Dataset_Stats_Scans DSS ON JJD.Source_Job = DSS.Job
				WHERE (JJD.Joined_Job_ID = @JoinedMASICJobNum)
				GROUP BY JJD.Joined_Job_ID, JJD.Section, DSS.Job
			) LookupQ INNER JOIN
			T_Joined_Job_Details JJD ON 
			LookupQ.Joined_Job_ID = JJD.Joined_Job_ID AND 
			LookupQ.Job = JJD.Source_Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			Set @message = 'Error updating Scan_Number_Start, Scan_Number_End, Scan_Time_Start, and Scan_Time_End in T_Joined_Job_Details'
			Goto Done
		End
		--
		If @myRowCount = 0
		Begin
			Set @message = 'Error: Updated Scan_Number_Start, Scan_Number_End, Scan_Time_Start, and Scan_Time_End for 0 rows into T_Joined_Job_Details'
			Goto Done
		End
	End
	
	-- Populate the Peptide_ID Start/End values for the Sequest jobs
	UPDATE T_Joined_Job_Details
	SET Peptide_ID_Start = LookupQ.Peptide_ID_Start, 
		Peptide_ID_End = LookupQ.Peptide_ID_End
	FROM (	SELECT JJD.Joined_Job_ID, JJD.Section, 
				TAD.Job AS Source_Job, TAD.Dataset, 
				MIN(P.Peptide_ID) AS Peptide_ID_Start, 
				MAX(P.Peptide_ID) AS Peptide_ID_End
			FROM T_Joined_Job_Details JJD INNER JOIN
				T_Analysis_Description TAD_JoinedJob ON JJD.Joined_Job_ID = TAD_JoinedJob.Job INNER JOIN
				T_Analysis_Description TAD ON JJD.Source_Job = TAD.Job INNER JOIN
				T_Peptides P ON TAD.Job = P.Analysis_ID
			WHERE JJD.Joined_Job_Id = @JoinedSequestJobNum
			GROUP BY JJD.Joined_Job_ID, JJD.Section, TAD.Job, TAD.Dataset
		) LookupQ INNER JOIN
		T_Joined_Job_Details JJD ON 
		 LookupQ.Joined_Job_ID = JJD.Joined_Job_ID AND 
		 LookupQ.Source_Job = JJD.Source_Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
	Begin
		Set @message = 'Error updating Peptide_ID_Start and Peptide_ID_End in T_Joined_Job_Details'
		Goto Done
	End
	--
	If @myRowCount = 0
	Begin
		Set @message = 'Error: Updated Peptide_ID_Start and Peptide_ID_End for 0 rows into T_Joined_Job_Details'
		Goto Done
	End

	-- Populate Gap_to_Next_Section_Minutes for the SIC jobs

	--
	-- If the source data is from infusion experiments, then use this:
	--
	--UPDATE T_Joined_Job_Details
	--SET Gap_to_Next_Section_Minutes = (Scan_Time_End - Scan_Time_Start) / CONVERT(real, Scan_Number_End - Scan_Number_Start)
	--FROM T_Joined_Job_Details JJD
	--WHERE (Joined_Job_ID = @JoinedMASICJobNum)

	-- Otherwise, if the source data is from a long separation split into parts, then use this:
	UPDATE T_Joined_Job_Details
	SET Gap_to_Next_Section_Minutes = LookupQ.Gap_Minutes
	FROM (	SELECT JJD.Joined_Job_ID,
				JJD.Source_Job,
				JJD.Section,
				JJDNext.Section AS SectionNext,
				CONVERT(real, DSNext.Acq_Time_Start - DS.Acq_Time_End) * 24 * 60 AS Gap_Minutes
			FROM T_Datasets DS
				INNER JOIN T_Joined_Job_Details JJD
							INNER JOIN T_Analysis_Description TAD
							ON JJD.Source_Job = TAD.Job
				ON DS.Dataset_ID = TAD.Dataset_ID
				INNER JOIN T_Datasets DSNext
							INNER JOIN T_Analysis_Description TADNext
							ON DSNext.Dataset_ID = TADNext.Dataset_ID
							INNER JOIN T_Joined_Job_Details JJDNext
							ON TADNext.Job = JJDNext.Source_Job
				ON JJD.Joined_Job_ID = JJDNext.Joined_Job_ID AND
					JJD.Section = JJDNext.Section - 1
			WHERE (JJD.Joined_Job_ID = @JoinedMASICJobNum)
		) LookupQ INNER JOIN
		T_Joined_Job_Details JJD ON 
		 LookupQ.Joined_Job_ID = JJD.Joined_Job_ID AND 
		 LookupQ.Source_Job = JJD.Source_Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
	Begin
		Set @message = 'Error updating Gap_to_Next_Section_Minutes in T_Joined_Job_Details'
		Goto Done
	End
	--
	If @myRowCount = 0
	Begin
		Set @message = 'Error: Updated Gap_to_Next_Section_Minutes for 0 rows into T_Joined_Job_Details'
		Goto Done
	End


	-- Populate Scan_Number_Added and Scan_Time_Added
	UPDATE T_Joined_Job_Details
	SET Scan_Number_Added = LookupQ.Scan_Number_Added, 
		Scan_Time_Added = LookupQ.Scan_Time_Added
	FROM (	SELECT JJD.Joined_Job_ID,
				JJD.Source_Job,
				JJD.Section,
				SUM(TotalsQ.Total_Scan_Count) AS Scan_Number_Added,
				SUM(TotalsQ.Total_Run_Time) AS Scan_Time_Added
			FROM T_Joined_Job_Details JJD
				INNER JOIN ( SELECT Joined_Job_ID,
									Source_Job,
									Section,
									Scan_Number_End - Scan_Number_Start + 1 AS Total_Scan_Count,
									Scan_Time_End + gap_to_Next_section_Minutes AS Total_Run_Time
							FROM T_Joined_Job_Details JJD
							WHERE Joined_Job_Id = @JoinedMASICJobNum ) TotalsQ
				ON JJD.Joined_Job_ID = TotalsQ.Joined_Job_ID AND
					JJD.Section > TotalsQ.Section
			GROUP BY JJD.Joined_Job_ID, JJD.Source_Job, JJD.Section
		) LookupQ INNER JOIN
		T_Joined_Job_Details JJD ON 
		 LookupQ.Joined_Job_ID = JJD.Joined_Job_ID AND 
		 LookupQ.Section = JJD.Section
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
	Begin
		Set @message = 'Error updating Scan_Number_Added and Scan_Time_Added in T_Joined_Job_Details'
		Goto Done
	End
	--
	If @myRowCount = 0
	Begin
		Set @message = 'Error: Updated Scan_Number_Added and Scan_Time_Added for 0 rows into T_Joined_Job_Details'
		Goto Done
	End

	-- Copy the Scan_Number, Scan_Time, and Gap info from the SIC jobs to the Sequest jobs
	UPDATE T_Joined_Job_Details
	SET Scan_Number_Start = LookupQ.Scan_Number_Start, 
		Scan_Number_End = LookupQ.Scan_Number_End, 
		Scan_Time_Start = LookupQ.Scan_Time_Start, 
		Scan_Time_End = LookupQ.Scan_Time_End, 
		Gap_to_Next_Section_Minutes = LookupQ.Gap_to_Next_Section_Minutes,
		Scan_Number_Added = LookupQ.Scan_Number_Added, 
		Scan_Time_Added = LookupQ.Scan_Time_Added
	FROM (SELECT JJD.Joined_Job_ID, JJD.Section, 
			JJD.Scan_Number_Start, JJD.Scan_Number_End, 
			JJD.Scan_Time_Start, JJD.Scan_Time_End, 
			JJD.Gap_to_Next_Section_Minutes, 
			JJD.Scan_Number_Added, 
			JJD.Scan_Time_Added
		FROM T_Joined_Job_Details JJD INNER JOIN
			 T_Analysis_Description TAD ON JJD.Source_Job = TAD.Job
		WHERE (JJD.Joined_Job_ID = @JoinedMASICJobNum) AND 
			  (TAD.ResultType = 'SIC')) LookupQ INNER JOIN
		T_Joined_Job_Details JJD ON 
		JJD.Joined_Job_ID = @JoinedSequestJobNum AND 
		LookupQ.Section = JJD.Section
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0
	Begin
		Set @message = 'Error copying the Scan_Number, Scan_Time, and Gap info from the SIC jobs to the Sequest jobs in T_Joined_Job_Details'
		Goto Done
	End
	--
	If @myRowCount = 0
	Begin
		Set @message = 'Error: 0 rows in T_Joined_Job_Details were updated when copying Scan_Number, Scan_Time, and Gap info'
		Goto Done
	End

	/*
	-- Preview the old and new Scan_Numbers in T_Peptides
	SELECT TOP 10 JJD.Joined_Job_ID, JJD.Source_Job, JJD.[Section],
		P.Scan_Number, P.Scan_Time_Peak_Apex, 
		P.Scan_Number + JJD.Scan_Number_Added AS Scan_New, 
		P.Scan_Time_Peak_Apex + JJD.Scan_Time_Added AS Scan_Time_New
	FROM T_Joined_Job_Details JJD INNER JOIN
		T_Peptides P ON JJD.Source_Job = P.Analysis_ID
	WHERE JJD.Joined_Job_ID = @JoinedSequestJobNum AND
		(JJD.Scan_Number_Added <> 0 OR JJD.Scan_Time_Added <> 0)
	*/

	-- Increment the Scan_Number and Scan_Time values in T_Peptides
	-- This query takes a while (~1 minute on 3.6 GHz Pogo)
	UPDATE T_Peptides
	SET Scan_Number = Scan_Number + JJD.Scan_Number_Added, 
		Scan_Time_Peak_Apex = Scan_Time_Peak_Apex + JJD.Scan_Time_Added
	FROM T_Joined_Job_Details JJD INNER JOIN
		T_Peptides P ON JJD.Source_Job = P.Analysis_ID
	WHERE JJD.Joined_Job_ID = @JoinedSequestJobNum AND
		 (JJD.Scan_Number_Added <> 0 OR JJD.Scan_Time_Added <> 0)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	Set @task = 'incrementing Scan_Number and Scan_Time_Peak_Apex in T_Peptides using T_Joined_Job_Details'
	If @myError <> 0
	Begin
		Set @message = 'Error ' + @Task
		Goto Done
	End
	Else
	Begin
		If @myRowCount = 0
		Begin
			Set @message = 'Error: No rows updated when ' + @task
			Goto Done
		End
		--
		Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
	End

	If @UseExistingDatasetAndMASICJob = 0
	Begin
		-- Increment the Scan_Number and Scan_Time values in T_Dataset_Stats_Scans
		-- This query takes a while (~1 minute on 3.6 GHz Pogo)
		UPDATE T_Dataset_Stats_Scans
		SET Scan_Number = Scan_Number + JJD.Scan_Number_Added, 
			Scan_Time = Scan_Time + JJD.Scan_Time_Added
		FROM T_Joined_Job_Details JJD  INNER JOIN
			T_Dataset_Stats_Scans DSS ON JJD.Source_Job = DSS.Job
		WHERE JJD.Joined_Job_ID = @JoinedMASICJobNum AND
			 (JJD.Scan_Number_Added <> 0 OR JJD.Scan_Time_Added <> 0)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @task = 'incrementing Scan_Number and Scan_Time in T_Dataset_Stats_Scans using T_Joined_Job_Details'
		If @myError <> 0
		Begin
			Set @message = 'Error ' + @Task
			Goto Done
		End
		Else
		Begin
			If @myRowCount = 0
			Begin
				Set @message = 'Error: No rows updated when ' + @task
				Goto Done
			End
			--
			Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
		End		
			
		-- Increment the Scan_Number values in T_Dataset_Stats_SIC
		-- This query takes a while (~2 minutes on 3.6 GHz Pogo)
		UPDATE T_Dataset_Stats_SIC
		SET Survey_Scan_Number = Survey_Scan_Number + JJD.Scan_Number_Added, 
			Frag_Scan_Number = Frag_Scan_Number + JJD.Scan_Number_Added, 
			Optimal_Peak_Apex_Scan_Number = Optimal_Peak_Apex_Scan_Number + JJD.Scan_Number_Added, 
			Peak_Scan_Start = Peak_Scan_Start + JJD.Scan_Number_Added, 
			Peak_Scan_End = Peak_Scan_End + JJD.Scan_Number_Added, 
			Peak_Scan_Max_Intensity = Peak_Scan_Max_Intensity + JJD.Scan_Number_Added, 
			CenterOfMass_Scan = CenterOfMass_Scan + JJD.Scan_Number_Added
		FROM T_Joined_Job_Details JJD INNER JOIN
			T_Dataset_Stats_SIC DSSIC ON JJD.Source_Job = DSSIC.Job
		WHERE JJD.Joined_Job_ID = @JoinedMASICJobNum AND
			 (JJD.Scan_Number_Added <> 0 OR JJD.Scan_Time_Added <> 0)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @task = 'incrementing Survey_Scan_Number, Frag_Scan_Number, etc. in T_Dataset_Stats_SIC using T_Joined_Job_Details'
		If @myError <> 0
		Begin
			Set @message = 'Error ' + @Task
			Goto Done
		End
		Else
		Begin
			If @myRowCount = 0
			Begin
				Set @message = 'Error: No rows updated when ' + @task
				Goto Done
			End
			--
			Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
		End

		-- Update the job numbers T_Dataset_Stats_Scans to be @JoinedMASICJobNum
		-- This query takes a while (~1 minute on 3.6 GHz Pogo)
		UPDATE T_Dataset_Stats_Scans
		SET Job = JJD.Joined_Job_ID
		FROM T_Joined_Job_Details JJD INNER JOIN
			 T_Dataset_Stats_Scans DSS ON JJD.Source_Job = DSS.Job
		WHERE JJD.Joined_Job_ID = @JoinedMASICJobNum
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @task = 'changing job to Joined Job ID in T_Dataset_Stats_Scans using T_Joined_Job_Details'
		If @myError <> 0
		Begin
			Set @message = 'Error ' + @Task
			Goto Done
		End
		Else
		Begin
			If @myRowCount = 0
			Begin
				Set @message = 'Error: No rows updated when ' + @task
				Goto Done
			End
			--
			Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
		End

		-- Update the job numbers T_Dataset_Stats_SIC to be @JoinedMASICJobNum
		-- This query takes a while (~1 minute on 3.6 GHz Pogo)
		UPDATE T_Dataset_Stats_SIC
		SET Job = JJD.Joined_Job_ID
		FROM T_Joined_Job_Details JJD INNER JOIN
			T_Dataset_Stats_SIC DSSIC ON 
			JJD.Source_Job = DSSIC.Job
		WHERE JJD.Joined_Job_ID = @JoinedMASICJobNum
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @task = 'changing job to Joined Job ID in T_Dataset_Stats_SIC using T_Joined_Job_Details'
		If @myError <> 0
		Begin
			Set @message = 'Error ' + @Task
			Goto Done
		End
		Else
		Begin
			If @myRowCount = 0
			Begin
				Set @message = 'Error: No rows updated when ' + @task
				Goto Done
			End
			--
			Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
		End
	End
	
	-- Update the job numbers in T_Peptides to be @JoinedSequestJobNum
	-- This query takes a while (~2 minutes on 3.6 GHz Pogo)
	UPDATE T_Peptides
	SET Analysis_ID = JJD.Joined_Job_ID
	FROM T_Joined_Job_Details JJD INNER JOIN
		 T_Peptides P ON JJD.Source_Job = P.Analysis_ID
	WHERE JJD.Joined_Job_ID = @JoinedSequestJobNum
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	Set @task = 'changing Analysis_ID to Joined Job ID in T_Peptides using T_Joined_Job_Details'
	If @myError <> 0
	Begin
		Set @message = 'Error ' + @Task
		Goto Done
	End
	Else
	Begin
		If @myRowCount = 0
		Begin
			Set @message = 'Error: No rows updated when ' + @task
			Goto Done
		End
		--
		Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
	End

	-- Update the job numbers in T_Seq_Candidates to be @JoinedSequestJobNum
	-- These queries can take a while (~2 minutes on 3.6 GHz Pogo)
	
	-- We will need to update Seq_ID_Local, so we need a temporary table
	--  to track the mapping between the old and new values
	CREATE TABLE #TmpSeqIDUpdateMap (
		Job int, 
		Seq_ID_Local int, 
		Seq_ID_Local_New int
	)

	-- Populate #TmpSeqIDUpdateMap
	INSERT INTO #TmpSeqIDUpdateMap (Job, Seq_ID_Local, Seq_ID_Local_New)
	SELECT	Job,
			Seq_ID_Local,
			Row_Number() OVER ( ORDER BY Job, Seq_ID_Local ) Seq_ID_Local_New
	FROM (	SELECT JJD.Joined_Job_ID, SC.Job,SC.Seq_ID_Local
			FROM T_Joined_Job_Details JJD
				INNER JOIN T_Seq_Candidates SC
				 ON JJD.Source_Job = SC.Job
			WHERE (JJD.Joined_Job_ID = @JoinedSequestJobNum)
			GROUP BY JJD.Joined_Job_ID, SC.Job, SC.Seq_ID_Local 
		 ) SeqIDQ
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	Set @task = 'populating #TmpSeqIDUpdateMap using the Seq Candidate tables'
	If @myError <> 0
	Begin
		Set @message = 'Error ' + @Task
		Goto Done
	End
	Else
	Begin
		If @myRowCount = 0
		Begin
			Set @message = 'Warning: No data found when ' + @task
		End
		--
		Print 'Found ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
	End


	If @myRowCount > 0
	Begin
		-- Drop the foreign key constraints between the sequence candidate tables
		if exists (select * from sys.objects where name = 'FK_T_Seq_Candidate_to_Peptide_Map_T_Seq_Candidates')
			alter table T_Seq_Candidate_to_Peptide_Map
			DROP CONSTRAINT FK_T_Seq_Candidate_to_Peptide_Map_T_Seq_Candidates

		if exists (select * from sys.objects where name = 'FK_T_Seq_Candidate_ModDetails_T_Seq_Candidates')
			alter table T_Seq_Candidate_ModDetails
			DROP CONSTRAINT FK_T_Seq_Candidate_ModDetails_T_Seq_Candidates

		-- Update the Job and Seq_ID_Local values
		UPDATE T_Seq_Candidates
		SET Job = @JoinedSequestJobNum,
			Seq_ID_Local = #TmpSeqIDUpdateMap.Seq_ID_Local_New
		FROM #TmpSeqIDUpdateMap INNER JOIN
			 T_Seq_Candidates Target ON 
			 #TmpSeqIDUpdateMap.Job = Target.Job AND 
			 #TmpSeqIDUpdateMap.Seq_ID_Local = Target.Seq_ID_Local
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @task = 're-mapping Job and Seq_ID_Local in T_Seq_Candidates'
		If @myError <> 0
		Begin
			Set @message = 'Error ' + @Task
			Goto Done
		End
		Else
		Begin
			If @myRowCount = 0
			Begin
				Set @message = 'Warning: No data found when ' + @task
			End
			--
			Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
		End
	
	
		UPDATE T_Seq_Candidate_to_Peptide_Map
		SET Job = @JoinedSequestJobNum,
			Seq_ID_Local = #TmpSeqIDUpdateMap.Seq_ID_Local_New
		FROM #TmpSeqIDUpdateMap INNER JOIN
			 T_Seq_Candidate_to_Peptide_Map Target ON 
			 #TmpSeqIDUpdateMap.Job = Target.Job AND 
			 #TmpSeqIDUpdateMap.Seq_ID_Local = Target.Seq_ID_Local
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @task = 're-mapping Job and Seq_ID_Local in T_Seq_Candidate_to_Peptide_Map'
		If @myError <> 0
		Begin
			Set @message = 'Error ' + @Task
			Goto Done
		End
		Else
		Begin
			If @myRowCount = 0
			Begin
				Set @message = 'Warning: No data found when ' + @task
			End
			--
			Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
		End


		UPDATE T_Seq_Candidate_ModDetails
		SET Job = @JoinedSequestJobNum,
			Seq_ID_Local = #TmpSeqIDUpdateMap.Seq_ID_Local_New
		FROM #TmpSeqIDUpdateMap INNER JOIN
			 T_Seq_Candidate_ModDetails Target ON 
			 #TmpSeqIDUpdateMap.Job = Target.Job AND 
			 #TmpSeqIDUpdateMap.Seq_ID_Local = Target.Seq_ID_Local
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @task = 're-mapping Job and Seq_ID_Local in T_Seq_Candidate_ModDetails'
		If @myError <> 0
		Begin
			Set @message = 'Error ' + @Task
			Goto Done
		End
		Else
		Begin
			If @myRowCount = 0
			Begin
				Set @message = 'Warning: No data found when ' + @task
			End
			--
			Print 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows ' + @task
		End
		
		
		-- Add back the constraints between the sequence candidate tables
		alter table T_Seq_Candidate_ModDetails add
		constraint FK_T_Seq_Candidate_ModDetails_T_Seq_Candidates foreign key(Job,Seq_ID_Local) references T_Seq_Candidates(Job,Seq_ID_Local)

		alter table T_Seq_Candidate_to_Peptide_Map add
		constraint FK_T_Seq_Candidate_to_Peptide_Map_T_Seq_Candidates foreign key(Job,Seq_ID_Local) references T_Seq_Candidates(Job,Seq_ID_Local)
	End

Done:
	If Len(@message) > 0
		Select @message as ErrorMessage
		
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[JoinSplitSeparationJobSections] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[JoinSplitSeparationJobSections] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[ResetChangedAnalysisJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ResetChangedAnalysisJobs
/****************************************************
**
**	Desc: Looks for entries in the analysis job table
**        that have ResultsFolder paths that differ from DMS
**		  If found, and if @infoOnly = 0, then resets their state to 10
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	mem
**	Date:	01/31/2005
**			02/07/2005 mem - Now updating the Completed column in T_Analysis_Description
**			04/23/2005 mem - Now updating the parameter file, settings file, and organism DB file names, in addition to results folder path
**			11/08/2005 mem - Now updating Vol_Client, Vol_Server, Storage_Path, and Dataset_Folder in addition to Results_Folder
**			11/09/2005 mem - Now updating jobs in state 3 or with a state >= @NextProcessState; previously, was updating jobs with a state > @NextProcessState
**			06/04/2006 mem - Now updating Protein_Collection_List and Protein_Options_List in T_Analysis_Description
**			03/17/2007 mem - Now obtaining StoragePathClient and StoragePathServer from V_DMS_Analysis_Job_Import
**			03/21/2008 mem - Updated to use T_DMS_Analysis_Job_Info_Cached in MT_Main rather than directly polling DMS via the V_DMS view
**			04/26/2008 mem - Now calling RefreshAnalysisDescriptionInfo to perform the updates.  This has the advantage of storing old and new values in T_Analysis_Description_Updates
**			08/14/2008 mem - Renamed Organism field to Experiment_Organism in T_Analysis_Job
**    
*****************************************************/
(
	@NextProcessState int = 10,
	@infoOnly tinyint = 0
)
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @MatchCount int
	
	declare @message varchar(255)
	declare @ExperimentOrganism varchar(128)
	
	Declare @sql varchar(2048)
	Declare @ProcessState varchar(9)
	
	Declare @JobList varchar(max)
	
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	--
	Set @NextProcessState = IsNull(@NextProcessState, 10)
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	---------------------------------------------------
	-- get organism name for this peptide database
	---------------------------------------------------
	--
	SELECT @ExperimentOrganism = PDB_Organism
	FROM MT_Main.dbo.T_Peptide_Database_List
	WHERE (PDB_Name = DB_Name())
	--	
	if @ExperimentOrganism = ''
	begin
		set @message = 'ould not get experiment (and thus dataset) organism name from MT_Main'
		execute PostLogEntry 'Error', @message, 'ResetChangedAnalysisJobs'
		return 33
	end

	Set @ProcessState = Convert(varchar(9), @NextProcessState)

	---------------------------------------------------
	-- Find changed analysis jobs
	---------------------------------------------------
	--
	Set @sql = ''

	If @infoOnly = 0
	Begin
		CREATE Table #TmpJobsWithNewResultsFolder (
			Job int NOT NULL
		)
				
		Set @sql = @sql + ' INSERT INTO #TmpJobsWithNewResultsFolder (Job)'
		Set @sql = @sql + ' SELECT TAD.Job '
	End
	Else
	Begin
		Set @Sql = @Sql + ' SELECT TAD.Job, TAD.Dataset, DAJI.ParameterFileName, DAJI.SettingsFileName,'
		Set @Sql = @Sql +        ' DAJI.OrganismDBName, DAJI.ProteinCollectionList, DAJI.ProteinOptions,'
		Set @Sql = @Sql +        ' TAD.Results_Folder, DAJI.ResultsFolder, TAD.Process_State, TAD.Last_Affected'
	End
	
	Set @sql = @sql + ' FROM T_Analysis_Description TAD INNER JOIN'
	Set @sql = @sql +      ' MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached DAJI ON TAD.Job = DAJI.Job'
	Set @sql = @sql + ' WHERE TAD.Results_Folder <> DAJI.ResultsFolder AND DAJI.Organism = ''' + @ExperimentOrganism + ''''
	Set @sql = @sql +       ' AND (TAD.Process_State >= ' + @ProcessState + ' OR TAD.Process_State = 3)'
	Set @sql = @sql + ' ORDER BY TAD.Job'
	
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @infoOnly = 0
	Begin
		SELECT @myRowCount = COUNT(*)
		FROM #TmpJobsWithNewResultsFolder
		
		If @myRowCount > 0
		Begin
			-- Construct a comma separated list of the jobs in #TmpJobsWithNewResultsFolder
			SELECT @JobList = Coalesce(@JobList + ',', '') + Convert(varchar(19), Job)
			FROM #TmpJobsWithNewResultsFolder
			ORDER BY Job
			
			Exec @myError = RefreshAnalysisDescriptionInfo @UpdateInterval=0, @message=@message output, @infoOnly=0, @JobListForceUpdate = @JobList
			
			If @myError = 0
			Begin
				UPDATE T_Analysis_Description
				SET Process_State = @ProcessState
				FROM T_Analysis_Description TAD INNER JOIN #TmpJobsWithNewResultsFolder U
				     ON TAD.Job = U.Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

			End
			
			
		End
	End
	
	If @infoOnly = 0
	Begin
		-- Post a message to the log if 1 or more jobs were updated
		set @message = 'Reset analysis jobs with changed ResultsFolder names: ' + convert(varchar(11), @myRowCount) + ' jobs updated'
		If @myRowCount > 0
			execute PostLogEntry 'Normal', @message, 'ResetChangedAnalysisJobs'
	End
	Else
	Begin
		set @message = 'Job count needing to be updated: ' + convert(varchar(11), @myRowCount)
		SELECT @message As Message
	End

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ResetChangedAnalysisJobs] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[ResetChangedAnalysisJobs] TO [MTS_DB_Lite]
GO

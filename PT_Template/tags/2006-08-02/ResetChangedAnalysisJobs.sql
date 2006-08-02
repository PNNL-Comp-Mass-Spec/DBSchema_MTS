SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ResetChangedAnalysisJobs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ResetChangedAnalysisJobs]
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
	declare @organism varchar(128)
	
	Declare @sql varchar(2048)
	Declare @ProcessState varchar(9)
	
	---------------------------------------------------
	-- get organism name for this peptide database
	---------------------------------------------------
	--
	SELECT @organism = PDB_Organism
	FROM MT_Main.dbo.T_Peptide_Database_List
	WHERE (PDB_Name = DB_Name())
	--	
	if @organism = ''
	begin
		set @message = 'Could not get organism name from MT_Main'
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
		Set @sql = @sql + ' UPDATE T_Analysis_Description'
		Set @sql = @sql + ' SET process_state = ' + @ProcessState + ','
		Set @sql = @sql +     ' Parameter_File_Name = AJI.ParameterFileName,'
		Set @sql = @sql +     ' Settings_File_Name = AJI.SettingsFileName,'
		Set @sql = @sql +     ' Organism_DB_Name = AJI.OrganismDBName,'
		Set @sql = @sql +     ' Protein_Collection_List = AJI.ProteinCollectionList,'
		Set @sql = @sql +     ' Protein_Options_List = AJI.ProteinOptions,'
		Set @sql = @sql +     ' Vol_Client = AJI.VolClient,' 
		Set @sql = @sql +     ' Vol_Server = AJI.VolServer,'
		Set @sql = @sql +     ' Storage_Path = AJI.StoragePath,'
		Set @sql = @sql +     ' Dataset_Folder = AJI.DatasetFolder,'
		Set @sql = @sql +     ' Results_Folder = AJI.ResultsFolder,'
		Set @sql = @sql +     ' Completed = AJI.Completed,'
		Set @sql = @sql +     ' Last_Affected = GetDate()'
	End
	Else
	Begin
		Set @Sql = @Sql + ' SELECT TAD.Job, TAD.Dataset, AJI.ParameterFileName, AJI.SettingsFileName,'
		Set @Sql = @Sql +        ' AJI.OrganismDBName, AJI.ProteinCollectionList, AJI.ProteinOptions,'
		Set @Sql = @Sql +        ' TAD.Results_Folder, AJI.ResultsFolder, TAD.Process_State, TAD.Last_Affected'
	End
	
	Set @sql = @sql + ' FROM T_Analysis_Description TAD INNER JOIN'
	Set @sql = @sql +      ' MT_Main.dbo.V_DMS_Analysis_Job_Import AJI ON TAD.Job = AJI.Job'
	Set @sql = @sql + ' WHERE TAD.Results_Folder <> AJI.ResultsFolder AND AJI.Organism = ''' + @organism + ''''
	Set @sql = @sql +       ' AND (TAD.Process_State >= ' + @ProcessState + ' OR TAD.Process_State = 3)'
	If @infoOnly <> 0
		Set @sql = @sql + ' ORDER BY TAD.Job'
	
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


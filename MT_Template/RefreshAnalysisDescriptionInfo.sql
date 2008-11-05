/****** Object:  StoredProcedure [dbo].[RefreshAnalysisDescriptionInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.RefreshAnalysisDescriptionInfo
/****************************************************
**
**	Desc: 
**		Find analysis jobs in this database that have different
**		attributes than the corresponding job in DMS (via MT_Main)
**		Corrects any discrepancies found
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/08/2005 mem
**			07/18/2005 mem - Now updating column Labelling
**			11/13/2005 mem - Now updating Dataset_Created_DMS, Dataset_Acq_Time_Start, Dataset_Acq_Time_End, and Dataset_Scan_Count in both T_Analysis_Description and T_FTICR_Analysis_Description
**			12/15/2005 mem - Now updating PreDigest_Internal_Std, PostDigest_Internal_Std, & Dataset_Internal_Std (previously named Internal_Standard)
**			03/08/2006 mem - Now updating column Campaign
**			11/15/2006 mem - Now updating columns Parameter_File_Name & Settings_File_Name
**			03/17/2007 mem - Now obtaining StoragePathClient and StoragePathServer from V_DMS_Analysis_Job_Import_Ex
**			05/09/2007 mem - Now using T_DMS_Analysis_Job_Info_Cached and T_DMS_Dataset_Info_Cached in MT_Main (Ticket:422)
**			02/28/2008 mem - Now checking for key attributes getting changed that might affect results stored in this database
**						   - Now storing old and new values in T_Analysis_Description_Updates when updates are applied
**			08/14/2008 mem - Now updating Experiment_Organism
**    
*****************************************************/
(
	@UpdateInterval int = 30,			-- Minimum interval in hours to limit update frequency; Set to 0 to force update now (looks in T_Log_Entries for last update time)
 	@message varchar(255) = '' output,
 	@infoOnly tinyint = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int

	set @myError = 0
	set @myRowCount = 0

	declare @JobCountUpdated int
	declare @DatasetCountUpdated int
		
	set @JobCountUpdated = 0
	set @DatasetCountUpdated = 0
	
	Declare @JobList varchar(256)
	Declare @S varchar(max)
	
	--------------------------------------------------------------
	-- Validate the inputs
	--------------------------------------------------------------

	Set @UpdateInterval = IsNull(@UpdateInterval, 30)
	Set @infoOnly = IsNull(@infoOnly, 0)
 	set @message = ''

	--------------------------------------------------------------
	-- Lookup the time of the last update in T_Log_Entries
	--------------------------------------------------------------
	
	Declare @LastUpdated datetime
	Set @LastUpdated = '1/1/1900'

	SELECT TOP 1 @LastUpdated = Posting_Time
	FROM T_Log_Entries
	WHERE Posted_By = 'RefreshAnalysisDescriptionInfo'
	ORDER BY Entry_ID DESC
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error looking up last entry from RefreshAnalysisDescriptionInfo in T_Log_Entries'
		Set @myError = 100
		execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
		Goto Done
	End
	
	If GetDate() > DateAdd(hour, @UpdateInterval, @LastUpdated) OR @myRowCount = 0
	Begin -- <a>
		
		--------------------------------------------------------------
		-- Look for changed data
		--------------------------------------------------------------
	
		CREATE TABLE #TmpJobsToUpdate (
			Job int NOT NULL,
			Dataset varchar(255) NULL,
			Dataset_ID int NULL,
			Experiment varchar(255) NULL,
			Campaign varchar(128) NULL,
			Experiment_Organism varchar(128) NULL,
			Vol_Client varchar(128) NOT NULL,
			Vol_Server varchar(128) NULL,
			Storage_Path varchar(255) NOT NULL,
			Dataset_Folder varchar(255) NOT NULL,
			Results_Folder varchar(255) NOT NULL,
			Completed datetime NULL,
			Parameter_File_Name varchar(255) NOT NULL,
			Settings_File_Name varchar(255) NULL,
			Organism_DB_Name varchar(128) NULL, 
			Protein_Collection_List varchar(max) NULL, 
			Protein_Options_List varchar(256) NULL,
			Separation_Sys_Type varchar(64) NULL,
			PreDigest_Internal_Std varchar(64) NULL,
			PostDigest_Internal_Std varchar(64) NULL,
			Dataset_Internal_Std varchar(64) NULL,
			Enzyme_ID int NULL,
			Labelling varchar(64) NULL
		)

		--------------------------------------------------------------
		-- Step 1: Update job information in T_Analysis_Description
		-- First look for jobs that need to be updated
		--------------------------------------------------------------
		--
		TRUNCATE TABLE #TmpJobsToUpdate
		
		INSERT INTO #TmpJobsToUpdate (
			Job, Dataset, Dataset_ID, Experiment, Campaign, Experiment_Organism,
			Vol_Client, Vol_Server,
			Storage_Path, Dataset_Folder, Results_Folder,
			Completed, Parameter_File_Name, Settings_File_Name,
			Organism_DB_Name, Protein_Collection_List, Protein_Options_List,
			Separation_Sys_Type, PreDigest_Internal_Std, 
			PostDigest_Internal_Std, Dataset_Internal_Std,
			Enzyme_ID, Labelling )
		SELECT P.Job, P.Dataset, P.DatasetID, P.Experiment, P.Campaign, P.Organism,
		    P.StoragePathClient, P.StoragePathServer,
			'' AS Storage_Path, P.DatasetFolder, P.ResultsFolder,
			P.Completed, P.ParameterFileName, P.SettingsFileName,
			P.OrganismDBName, P.ProteinCollectionList, P.ProteinOptions,
			P.SeparationSysType, P.[PreDigest Int Std], 
			P.[PostDigest Int Std], P.[Dataset Int Std],
			P.EnzymeID, P.Labelling
		FROM T_Analysis_Description AS TAD INNER JOIN (
			SELECT L.Job, R.Dataset, R.DatasetID, R.Experiment, R.Campaign, R.Organism,
			    R.StoragePathClient, R.StoragePathServer,
				R.DatasetFolder, R.ResultsFolder, R.Completed,
				R.ParameterFileName, R.SettingsFileName,
				R.OrganismDBName, R.ProteinCollectionList, R.ProteinOptions,
				R.SeparationSysType, R.[PreDigest Int Std], R.[PostDigest Int Std], R.[Dataset Int Std], 
				R.EnzymeID, R.Labelling
			FROM T_Analysis_Description AS L INNER JOIN
				MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached AS R ON 
				L.Job = R.Job AND (
					L.Dataset_ID <> R.DatasetID OR
					IsNull(L.Dataset, '') <> R.Dataset OR
					IsNull(L.Experiment, '') <> R.Experiment OR
					IsNull(L.Campaign, '') <> R.Campaign OR
					IsNull(L.Experiment_Organism, '') <> R.Organism OR
					IsNull(L.Vol_Client, '') <> R.StoragePathClient OR 
					IsNull(L.Vol_Server, '') <> R.StoragePathServer OR 
					IsNull(L.Dataset_Folder, '') <> R.DatasetFolder OR 
					IsNull(L.Results_Folder, '') <> R.ResultsFolder OR
					IsNull(L.Completed, '1/1/1980') <> R.Completed OR
					IsNull(L.Parameter_File_Name,'') <> IsNull(R.ParameterFileName,'') OR
					IsNull(L.Settings_File_Name,'') <> IsNull(R.SettingsFileName,'') OR
					IsNull(L.Organism_DB_Name,'') <> IsNull(R.OrganismDBName,'') OR
					IsNull(L.Protein_Collection_List,'') <> IsNull(R.ProteinCollectionList,'') OR
					IsNull(L.Protein_Options_List,'') <> IsNull(R.ProteinOptions,'') OR
					IsNull(L.Separation_Sys_Type,'') <> IsNull(R.SeparationSysType,'') OR
					IsNull(L.PreDigest_Internal_Std,'') <> IsNull(R.[PreDigest Int Std], '') OR
					IsNull(L.PostDigest_Internal_Std,'') <> IsNull(R.[PostDigest Int Std], '') OR
					IsNull(L.Dataset_Internal_Std,'') <> IsNull(R.[Dataset Int Std], '') OR
					IsNull(L.Enzyme_ID,0) <> IsNull(R.EnzymeID,0) OR
					IsNull(L.Labelling,'') <> IsNull(R.Labelling,'')
				) 
			) AS P on P.Job = TAD.Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount > 0
		Begin -- <b1>

			--------------------------------------------------------------
			-- Either insert the old and new info in T_Analysis_Description_Updates
			--  or preview it
			--------------------------------------------------------------

			Set @S = ''
			If @infoOnly = 0
			Begin
				Set @S = @S + ' INSERT INTO T_Analysis_Description_Updates ('
				Set @S = @S +     ' Job, Dataset, Dataset_New, Dataset_ID, Dataset_ID_New, '
				Set @S = @S +     ' Experiment, Experiment_New, Campaign, Campaign_New, '
				Set @S = @S +     ' Vol_Client, Vol_Client_New, Vol_Server, Vol_Server_New, '
				Set @S = @S +     ' Storage_Path, Storage_Path_New, Dataset_Folder, Dataset_Folder_New, '
				Set @S = @S +     ' Results_Folder, Results_Folder_New, Completed, Completed_New, '
				Set @S = @S +     ' Parameter_File_Name, Parameter_File_Name_New, '
				Set @S = @S + ' Settings_File_Name, Settings_File_Name_New, '
				Set @S = @S +     ' Organism_DB_Name, Organism_DB_Name_New, '
				Set @S = @S +     ' Protein_Collection_List, Protein_Collection_List_New, '
				Set @S = @S +     ' Protein_Options_List, Protein_Options_List_New, '
				Set @S = @S +     ' Separation_Sys_Type, Separation_Sys_Type_New, '
				Set @S = @S +     ' PreDigest_Internal_Std, PreDigest_Internal_Std_New, ' 
				Set @S = @S +     ' PostDigest_Internal_Std, PostDigest_Internal_Std_New, '
				Set @S = @S +     ' Dataset_Internal_Std, Dataset_Internal_Std_New, '
				Set @S = @S +     ' Enzyme_ID, Enzyme_ID_New, '
				Set @S = @S +     ' Labelling, Labelling_New)'
			End
			
			Set @S = @S + ' SELECT TAD.Job, TAD.Dataset, U.Dataset AS Dataset_New,'
			Set @S = @S +        ' TAD.Dataset_ID, U.Dataset_ID AS Dataset_ID_New,'
			Set @S = @S +        ' TAD.Experiment, U.Experiment AS Experiment_New,'
			Set @S = @S +        ' TAD.Campaign, U.Campaign AS Campaign_New,'
			Set @S = @S +        ' TAD.Vol_Client, U.Vol_Client AS Vol_Client_New,'
			Set @S = @S +        ' TAD.Vol_Server, U.Vol_Server AS Vol_Server_New,'
			Set @S = @S +        ' TAD.Storage_Path , U.Storage_Path AS Storage_Path_New,'
			Set @S = @S +        ' TAD.Dataset_Folder, U.Dataset_Folder AS Dataset_Folder_New,'
			Set @S = @S +        ' TAD.Results_Folder, U.Results_Folder AS Results_Folder_New,'
			Set @S = @S +        ' TAD.Completed, U.Completed AS Completed_New,'
			Set @S = @S +        ' TAD.Parameter_File_Name, U.Parameter_File_Name AS Parameter_File_Name_New,'
			Set @S = @S +        ' TAD.Settings_File_Name, U.Settings_File_Name AS Settings_File_Name_New,'
			Set @S = @S +        ' TAD.Organism_DB_Name, U.Organism_DB_Name AS Organism_DB_Name_New,'
			Set @S = @S +        ' TAD.Protein_Collection_List, U.Protein_Collection_List AS Protein_Collection_List_New,'
			Set @S = @S +        ' TAD.Protein_Options_List, U.Protein_Options_List AS Protein_Options_List_New,'
			Set @S = @S +        ' TAD.Separation_Sys_Type, U.Separation_Sys_Type AS Separation_Sys_Type_New,'
			Set @S = @S +        ' TAD.PreDigest_Internal_Std, U.PreDigest_Internal_Std AS PreDigest_Internal_Std_New,'
			Set @S = @S +        ' TAD.PostDigest_Internal_Std, U.PostDigest_Internal_Std AS PostDigest_Internal_Std_New,'
			Set @S = @S +        ' TAD.Dataset_Internal_Std, U.Dataset_Internal_Std AS Dataset_Internal_Std_New,'
			Set @S = @S +        ' TAD.Enzyme_ID, U.Enzyme_ID AS Enzyme_ID_New,'
			Set @S = @S +        ' TAD.Labelling, U.Labelling AS Labelling_New'
			Set @S = @S + ' FROM #TmpJobsToUpdate U INNER JOIN '
			Set @S = @S +      ' T_Analysis_Description TAD ON U.Job = TAD.Job'
			Set @S = @S + ' ORDER BY Job'
			
			Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			
			--------------------------------------------------------------
			-- See if any of the jobs have changed one of the key fields
			-- Exclude jobs that are in state 1
			--------------------------------------------------------------

			Set @JobList = Null
			SELECT @JobList = Coalesce(@JobList + ', ', '') + Convert(varchar(12), TAD.job)
			FROM #TmpJobsToUpdate U INNER JOIN 
				 T_Analysis_Description TAD ON U.Job = TAD.Job AND TAD.State <> 1
			WHERE IsNull(TAD.Results_Folder, '')         <> U.Results_Folder OR
				  IsNull(TAD.Completed, '1/1/1980')      <> U.Completed OR
				  IsNull(TAD.Parameter_File_Name, '')    <> ISNULL(U.Parameter_File_Name, '') OR
				  IsNull(TAD.Settings_File_Name, '')     <> ISNULL(U.Settings_File_Name, '') OR
				  IsNull(TAD.Organism_DB_Name,'')        <> IsNull(U.Organism_DB_Name,'') OR
				  IsNull(TAD.Protein_Collection_List,'') <> IsNull(U.Protein_Collection_List,'') OR
				  IsNull(TAD.Protein_Options_List,'')    <> IsNull(U.Protein_Options_List,'')
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount > 0
			Begin
				If @myRowCount = 1
					Set @message = 'MS/MS job found'
				Else
					Set @message = 'MS/MS jobs found'
				
				Set @message = @message + ' with key attributes changed: ' + @JobList + '; data loaded in the database may now be incorrect'

				If @infoOnly = 0
					execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
				Else
					Print @message				
			End

			If @infoOnly = 0
			Begin
				-- Now apply the updated information
				UPDATE T_Analysis_Description
				SET 
					Dataset = U.Dataset,
					Dataset_ID = U.Dataset_ID,
					Experiment = U.Experiment,
					Campaign = U.Campaign,
					Experiment_Organism = U.Experiment_Organism,
					Vol_Client = U.Vol_Client, 
					Vol_Server = U.Vol_Server, 
					Storage_Path = U.Storage_Path,
					Dataset_Folder = U.Dataset_Folder, 
					Results_Folder = U.Results_Folder,
					Completed = U.Completed,
					Parameter_File_Name = U.Parameter_File_Name,
					Settings_File_Name = U.Settings_File_Name,
					Organism_DB_Name = U.Organism_DB_Name, 
					Protein_Collection_List = U.Protein_Collection_List, 
					Protein_Options_List = U.Protein_Options_List,
					Separation_Sys_Type = U.Separation_Sys_Type,
					PreDigest_Internal_Std = U.PreDigest_Internal_Std,
					PostDigest_Internal_Std = U.PostDigest_Internal_Std,
					Dataset_Internal_Std = U.Dataset_Internal_Std,
					Enzyme_ID = U.Enzyme_ID,
					Labelling = U.Labelling
				FROM #TmpJobsToUpdate U INNER JOIN 
					T_Analysis_Description TAD ON U.Job = TAD.Job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End
			Else
			Begin
				SELECT @myRowCount = COUNT(*)
				FROM #TmpJobsToUpdate
			End
						
			set @JobCountUpdated = @myRowCount
			if @myRowCount > 0 and @myError = 0
			begin
				set @message = 'Job attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS/MS analyses'
				
				If @infoOnly = 0
					execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
				Else
					Print @message
			end
			else
			begin
				if @myError <> 0 And @infoOnly = 0
				Begin
					Set @message = 'Error synchronizing T_Analysis_Description with T_DMS_Analysis_Job_Info_Cached'
					Set @myError = 101
					execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
					Goto Done
				End
			end			
		End -- </b1>
		

		If @infoOnly = 0
		Begin -- <b2>
			--------------------------------------------------------------
			-- Step 2: Update dataset information in T_Analysis_Description
			--         We're not tracking this in T_Analysis_Description_Updates since it's not critical
			--------------------------------------------------------------
			--
			UPDATE T_Analysis_Description
			SET 
				Dataset_Created_DMS = P.Created,
				Dataset_Acq_Time_Start = P.[Acquisition Start], 
				Dataset_Acq_Time_End = P.[Acquisition End],
				Dataset_Scan_Count = P.[Scan Count]
			FROM T_Analysis_Description AS TAD INNER JOIN (
				SELECT L.Dataset_ID, R.Created, R.[Acquisition Start], R.[Acquisition End], R.[Scan Count]
				FROM T_Analysis_Description AS L INNER JOIN
					MT_Main.dbo.T_DMS_Dataset_Info_Cached AS R ON 
					L.Dataset_ID = R.ID AND (
						L.Dataset_Created_DMS <> R.Created OR 
						IsNull(L.Dataset_Acq_Time_Start,0) <> IsNull(R.[Acquisition Start],0) OR
						IsNull(L.Dataset_Acq_Time_End,0) <> IsNull(R.[Acquisition End],0) OR
						IsNull(L.Dataset_Scan_Count,0) <> IsNull(R.[Scan Count],0)
					) 
				) AS P on P.Dataset_ID = TAD.Dataset_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			set @DatasetCountUpdated = @myRowCount
			if @myRowCount > 0 and @myError = 0
			begin
				set @message = 'Dataset attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS/MS analyses'
				execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
			end
			else
			begin
				if @myError <> 0
				Begin
					Set @message = 'Error synchronizing T_Analysis_Description with T_DMS_Dataset_Info_Cached'
					Set @myError = 102
					execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
					Goto Done
				End
			end
		End -- </b2>

		--------------------------------------------------------------
		-- Step 3: Update job information in T_FTICR_Analysis_Description
		-- First look for jobs that need to be updated
		--------------------------------------------------------------
		--
		TRUNCATE TABLE #TmpJobsToUpdate
		
		INSERT INTO #TmpJobsToUpdate (
			Job, Dataset, Dataset_ID, Experiment, Campaign, Experiment_Organism,
			Vol_Client, Vol_Server,
			Storage_Path, Dataset_Folder, Results_Folder,
			Completed, Parameter_File_Name, Settings_File_Name,
			Separation_Sys_Type, PreDigest_Internal_Std, 
			PostDigest_Internal_Std, Dataset_Internal_Std,
			Labelling )
		SELECT P.Job, P.Dataset, P.DatasetID, P.Experiment, P.Campaign, P.Organism,
		    P.StoragePathClient, P.StoragePathServer,
			'' AS Storage_Path, P.DatasetFolder, P.ResultsFolder,
			P.Completed, P.ParameterFileName, P.SettingsFileName,
			P.SeparationSysType, P.[PreDigest Int Std], 
			P.[PostDigest Int Std], P.[Dataset Int Std],
			P.Labelling
		FROM T_FTICR_Analysis_Description AS TAD INNER JOIN (
			SELECT L.Job, R.Dataset, R.DatasetID, R.Experiment, R.Campaign, R.Organism,
			    R.StoragePathClient, R.StoragePathServer,
				R.DatasetFolder, R.ResultsFolder, R.Completed,
				R.ParameterFileName, R.SettingsFileName,
				R.SeparationSysType, R.[PreDigest Int Std], R.[PostDigest Int Std], R.[Dataset Int Std], 
				R.Labelling
			FROM T_FTICR_Analysis_Description AS L INNER JOIN
				MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached AS R ON 
				L.Job = R.Job AND (
				    L.Dataset_ID <> R.DatasetID OR
					IsNull(L.Dataset, '') <> R.Dataset OR
					IsNull(L.Experiment, '') <> R.Experiment OR
					IsNull(L.Campaign, '') <> R.Campaign OR
					IsNull(L.Experiment_Organism, '') <> R.Organism OR
					IsNull(L.Vol_Client, '') <> R.StoragePathClient OR 
					IsNull(L.Vol_Server, '') <> R.StoragePathServer OR 
					IsNull(L.Dataset_Folder, '') <> R.DatasetFolder OR 
					IsNull(L.Results_Folder, '') <> R.ResultsFolder OR
					IsNull(L.Completed, '1/1/1980') <> R.Completed OR
					IsNull(L.Parameter_File_Name,'') <> IsNull(R.ParameterFileName,'') OR
					IsNull(L.Settings_File_Name,'') <> IsNull(R.SettingsFileName,'') OR
					IsNull(L.Separation_Sys_Type,'') <> IsNull(R.SeparationSysType,'') OR
					IsNull(L.PreDigest_Internal_Std,'') <> IsNull(R.[PreDigest Int Std], '') OR
					IsNull(L.PostDigest_Internal_Std,'') <> IsNull(R.[PostDigest Int Std], '') OR
					IsNull(L.Dataset_Internal_Std,'') <> IsNull(R.[Dataset Int Std], '') OR
					IsNull(L.Labelling,'') <> IsNull(R.Labelling,'')
				) 
			) AS P on P.Job = TAD.Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount > 0
		Begin -- <b3>

			--------------------------------------------------------------
			-- Either insert the old and new info in T_Analysis_Description_Updates
			--  or preview it
			--------------------------------------------------------------

			Set @S = ''
			If @infoOnly = 0
			Begin
				Set @S = @S + ' INSERT INTO T_Analysis_Description_Updates ('
				Set @S = @S +     ' Job, Dataset, Dataset_New, Dataset_ID, Dataset_ID_New, '
				Set @S = @S +     ' Experiment, Experiment_New, Campaign, Campaign_New, '
				Set @S = @S +     ' Vol_Client, Vol_Client_New, Vol_Server, Vol_Server_New, '
				Set @S = @S +     ' Storage_Path, Storage_Path_New, Dataset_Folder, Dataset_Folder_New, '
				Set @S = @S +     ' Results_Folder, Results_Folder_New, Completed, Completed_New, '
				Set @S = @S +     ' Parameter_File_Name, Parameter_File_Name_New, '
				Set @S = @S +     ' Settings_File_Name, Settings_File_Name_New, '
				Set @S = @S +     ' Separation_Sys_Type, Separation_Sys_Type_New, '
				Set @S = @S +     ' PreDigest_Internal_Std, PreDigest_Internal_Std_New, ' 
				Set @S = @S +     ' PostDigest_Internal_Std, PostDigest_Internal_Std_New, '
				Set @S = @S +     ' Dataset_Internal_Std, Dataset_Internal_Std_New, '
				Set @S = @S +     ' Labelling, Labelling_New)'
			End
			
			Set @S = @S + ' SELECT TAD.Job, TAD.Dataset, U.Dataset AS Dataset_New,'
			Set @S = @S +        ' TAD.Dataset_ID, U.Dataset_ID AS Dataset_ID_New,'
			Set @S = @S +        ' TAD.Experiment, U.Experiment AS Experiment_New,'
			Set @S = @S +        ' TAD.Campaign, U.Campaign AS Campaign_New,'
			Set @S = @S +        ' TAD.Vol_Client, U.Vol_Client AS Vol_Client_New,'
			Set @S = @S +        ' TAD.Vol_Server, U.Vol_Server AS Vol_Server_New,'
			Set @S = @S +        ' TAD.Storage_Path , U.Storage_Path AS Storage_Path_New,'
			Set @S = @S +        ' TAD.Dataset_Folder, U.Dataset_Folder AS Dataset_Folder_New,'
			Set @S = @S +        ' TAD.Results_Folder, U.Results_Folder AS Results_Folder_New,'
			Set @S = @S +        ' TAD.Completed, U.Completed AS Completed_New,'
			Set @S = @S +        ' TAD.Parameter_File_Name, U.Parameter_File_Name AS Parameter_File_Name_New,'
			Set @S = @S +        ' TAD.Settings_File_Name, U.Settings_File_Name AS Settings_File_Name_New,'
			Set @S = @S +        ' TAD.Separation_Sys_Type, U.Separation_Sys_Type AS Separation_Sys_Type_New,'
			Set @S = @S +        ' TAD.PreDigest_Internal_Std, U.PreDigest_Internal_Std AS PreDigest_Internal_Std_New,'
			Set @S = @S +        ' TAD.PostDigest_Internal_Std, U.PostDigest_Internal_Std AS PostDigest_Internal_Std_New,'
			Set @S = @S +        ' TAD.Dataset_Internal_Std, U.Dataset_Internal_Std AS Dataset_Internal_Std_New,'
			Set @S = @S +        ' TAD.Labelling, U.Labelling AS Labelling_New'
			Set @S = @S + ' FROM #TmpJobsToUpdate U INNER JOIN '
			Set @S = @S +      ' T_FTICR_Analysis_Description TAD ON U.Job = TAD.Job'
			Set @S = @S + ' ORDER BY Job'
			
			Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			
			--------------------------------------------------------------
			-- See if any of the jobs have changed one of the key fields
			-- Limit the checking to jobs that have peak matching results in T_Match_Making_Description
			--------------------------------------------------------------
			
			Set @JobList = Null
			SELECT @JobList = Coalesce(@JobList + ', ', '') + Convert(varchar(12), TAD.job)
			FROM #TmpJobsToUpdate U INNER JOIN 
				 T_FTICR_Analysis_Description TAD ON U.Job = TAD.Job INNER JOIN
				 T_Match_Making_Description MMD ON TAD.Job = MMD.MD_Reference_Job
			WHERE IsNull(TAD.Results_Folder, '')         <> U.Results_Folder OR
				  IsNull(TAD.Completed, '1/1/1980')      <> U.Completed OR
				  IsNull(TAD.Parameter_File_Name, '')    <> ISNULL(U.Parameter_File_Name, '') OR
				  IsNull(TAD.Settings_File_Name, '')     <> ISNULL(U.Settings_File_Name, '')
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount > 0
			Begin
				If @myRowCount = 1
					Set @message = 'MS job found'
				Else
					Set @message = 'MS jobs found'
				
				Set @message = @message + ' with key attributes changed: ' + @JobList + '; data loaded in the database may now be incorrect'

				If @infoOnly = 0
					execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'				
				Else
					Print @message
			End
			
			If @infoOnly = 0
			Begin
				-- Now apply the updated information
				UPDATE T_FTICR_Analysis_Description
				SET 
					Dataset = U.Dataset,
					Dataset_ID = U.Dataset_ID,
					Experiment = U.Experiment,
					Campaign = U.Campaign,
					Experiment_Organism = U.Experiment_Organism,
					Vol_Client = U.Vol_Client, 
					Vol_Server = U.Vol_Server, 
					Storage_Path = U.Storage_Path,
					Dataset_Folder = U.Dataset_Folder, 
					Results_Folder = U.Results_Folder,
					Completed = U.Completed,
					Parameter_File_Name = U.Parameter_File_Name,
					Settings_File_Name = U.Settings_File_Name,
					Separation_Sys_Type = U.Separation_Sys_Type,
					PreDigest_Internal_Std = U.PreDigest_Internal_Std,
					PostDigest_Internal_Std = U.PostDigest_Internal_Std,
					Dataset_Internal_Std = U.Dataset_Internal_Std,
					Labelling = U.Labelling
				FROM #TmpJobsToUpdate U INNER JOIN 
					T_FTICR_Analysis_Description TAD ON U.Job = TAD.Job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End
			Else
			Begin
				SELECT @myRowCount = COUNT(*)
				FROM #TmpJobsToUpdate
			End
				
			set @JobCountUpdated = @JobCountUpdated + @myRowCount
			if @myRowCount > 0 and @myError = 0
			begin
				set @message = 'Job attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS analyses'
				
				If @infoOnly = 0
					execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
				Else
					Print @message
			end
			else
			begin
				if @myError <> 0 And @infoOnly = 0
				Begin
					Set @message = 'Error synchronizing T_FTICR_Analysis_Description with T_DMS_Analysis_Job_Info_Cached'
					Set @myError = 102
					execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
					Goto Done
				End
			end
		End -- </b3>


		If @infoOnly = 0
		Begin -- <b4>
			--------------------------------------------------------------
			-- Step 4: Update dataset information in T_FTICR_Analysis_Description
			--         We're not tracking this in T_Analysis_Description_Updates since it's not critical
			--------------------------------------------------------------
			--
			UPDATE T_FTICR_Analysis_Description
			SET 
				Dataset_Created_DMS = P.Created,
				Dataset_Acq_Time_Start = P.[Acquisition Start], 
				Dataset_Acq_Time_End = P.[Acquisition End],
				Dataset_Scan_Count = P.[Scan Count]
			FROM T_FTICR_Analysis_Description AS TAD INNER JOIN (
				SELECT L.Dataset_ID, R.Created, R.[Acquisition Start], R.[Acquisition End], R.[Scan Count]
				FROM T_FTICR_Analysis_Description AS L INNER JOIN
					MT_Main.dbo.T_DMS_Dataset_Info_Cached AS R ON 
					L.Dataset_ID = R.ID AND (
						L.Dataset_Created_DMS <> R.Created OR 
						IsNull(L.Dataset_Acq_Time_Start,0) <> IsNull(R.[Acquisition Start],0) OR
						IsNull(L.Dataset_Acq_Time_End,0) <> IsNull(R.[Acquisition End],0) OR
						IsNull(L.Dataset_Scan_Count,0) <> IsNull(R.[Scan Count],0)
					) 
				) AS P on P.Dataset_ID = TAD.Dataset_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			set @DatasetCountUpdated = @DatasetCountUpdated + @myRowCount
			if @myRowCount > 0 and @myError = 0
			begin
				set @message = 'Dataset attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS analyses'
				execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
			end
			else
			begin
				if @myError <> 0
				Begin
					Set @message = 'Error synchronizing T_FTICR_Analysis_Description with T_DMS_Dataset_Info_Cached'
					Set @myError = 102
					execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
					Goto Done
				End
			end
		End -- </b4>
			
		If @JobCountUpdated > 0 or @DatasetCountUpdated > 0
		Begin
			set @myRowCount = @JobCountUpdated
			If @DatasetCountUpdated > @myRowCount
				Set @myRowCount = @DatasetCountUpdated
				
			set @message = 'Job attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' analyses'
		End
		else
		Begin
			set @message = 'Synchronized analysis job attributes with DMS'
			
			If @infoOnly = 0
				execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
			Else
				Print @message
		End
	End -- </a>
	Else
		Set @message = 'Update skipped since ' + Convert(varchar(12), DateDiff(hour, @LastUpdated, GetDate())) + ' hours have elapsed since the last update (update interval is ' + Convert(varchar(12), @UpdateInterval) + ' hours)'

Done:
	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[RefreshAnalysisDescriptionInfo] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshAnalysisDescriptionInfo] TO [MTS_DB_Lite]
GO

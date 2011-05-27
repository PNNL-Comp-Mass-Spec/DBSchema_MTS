/****** Object:  StoredProcedure [dbo].[RefreshAnalysisStoragePathsNonCached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.RefreshAnalysisStoragePathsNonCached
/****************************************************
**
**	Desc: 
**		Update analysis jobs in this database that have different storage paths than defined in DMS
**		Directly queries DMS (using MT_Main.dbo.V_DMS_Analysis_Job_Import_Storage_Path) and can thus be a bit slow
**
**		Has the advantage that Jobs in state "No Export" and jobs from datasets with a rating of "Not Released" will still get updated
**
**		You'll typically want to use RefreshAnalysisDescriptionInfo, which uses MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	01/06/2011 - mem
**    
*****************************************************/
(
 	@message varchar(4000) = '' output,
 	@infoOnly tinyint = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int

	set @myError = 0
	set @myRowCount = 0
	
	--------------------------------------------------------------
	-- Validate the inputs
	--------------------------------------------------------------

	Set @infoOnly = IsNull(@infoOnly, 0)
 	set @message = ''


	-- View V_DMS_Analysis_Job_Import_Storage_Path directly queries Gigasax (and is thus slower)
	-- It includes jobs that have state 14=No Export, and it includes datasets that are not released

	If @infoOnly <> 0
	Begin -- <c1>
		-- Preview MS/MS jobs that would be updated
		--
		SELECT L.Job,
		       L.Vol_Client,
		       L.Vol_Server,
		       L.Dataset_Folder,
		       L.Results_Folder,
		       R.StoragePathClient AS Vol_Client_New,
		       R.StoragePathServer AS Vol_Server_New,
		       R.DatasetFolder AS Dataset_Folder_New,
		       R.ResultsFolder AS Results_Folder_New
		FROM T_Analysis_Description L
		     INNER JOIN MT_Main.dbo.V_DMS_Analysis_Job_Import_Storage_Path R
		       ON L.Job = R.Job AND
		          L.Dataset = R.Dataset
		WHERE (ISNULL(L.Vol_Client, '') <> R.StoragePathClient) OR
		      (ISNULL(L.Vol_Server, '') <> R.StoragePathServer) OR
		      (ISNULL(L.Dataset_Folder, '') <> R.DatasetFolder) OR
		      (ISNULL(L.Results_Folder, '') <> R.ResultsFolder)
	
		-- Preview MS jobs that would be updated
		--
		SELECT L.Job,
		       L.Vol_Client,
		       L.Vol_Server,
		       L.Dataset_Folder,
		       L.Results_Folder,
		       R.StoragePathClient AS Vol_Client_New,
		       R.StoragePathServer AS Vol_Server_New,
		       R.DatasetFolder AS Dataset_Folder_New,
		       R.ResultsFolder AS Results_Folder_New
		FROM T_FTICR_Analysis_Description L
		     INNER JOIN MT_Main.dbo.V_DMS_Analysis_Job_Import_Storage_Path R
		       ON L.Job = R.Job AND
		          L.Dataset = R.Dataset
		WHERE (ISNULL(L.Vol_Client, '') <> R.StoragePathClient) OR
		      (ISNULL(L.Vol_Server, '') <> R.StoragePathServer) OR
		      (ISNULL(L.Dataset_Folder, '') <> R.DatasetFolder) OR
		      (ISNULL(L.Results_Folder, '') <> R.ResultsFolder)
		      
	End	 -- </c1>		
	Else
	Begin -- <c2>
		-- First MS/MS jobs
		--
		UPDATE T_Analysis_Description
		SET Vol_Client = R.StoragePathClient,
		    Vol_Server = R.StoragePathServer,
		    Dataset_Folder = R.DatasetFolder,
		    Results_Folder = R.ResultsFolder
		FROM T_Analysis_Description L
		     INNER JOIN MT_Main.dbo.V_DMS_Analysis_Job_Import_Storage_Path R
		       ON L.Job = R.Job AND
		          L.Dataset = R.Dataset
		WHERE (ISNULL(L.Vol_Client, '') <> R.StoragePathClient) OR
		      (ISNULL(L.Vol_Server, '') <> R.StoragePathServer) OR
		      (ISNULL(L.Dataset_Folder, '') <> R.DatasetFolder) OR
		      (ISNULL(L.Results_Folder, '') <> R.ResultsFolder)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount > 0
		Begin
			set @message = 'Storage path info was updated from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS/MS analyses using MT_Main.dbo.V_DMS_Analysis_Job_Import_Storage_Path; these are likely jobs with state "No Export" or jobs associated with non-released datasets'
			execute PostLogEntry 'Normal', @message, 'RefreshAnalysisStoragePathsNonCached'
		End

		-- Next MS jobs
		--
		UPDATE T_FTICR_Analysis_Description
		SET Vol_Client = R.StoragePathClient,
		    Vol_Server = R.StoragePathServer,
		    Dataset_Folder = R.DatasetFolder,
		    Results_Folder = R.ResultsFolder
		FROM T_FTICR_Analysis_Description L
		     INNER JOIN MT_Main.dbo.V_DMS_Analysis_Job_Import_Storage_Path R
		       ON L.Job = R.Job AND
		          L.Dataset = R.Dataset
		WHERE (ISNULL(L.Vol_Client, '') <> R.StoragePathClient) OR
		      (ISNULL(L.Vol_Server, '') <> R.StoragePathServer) OR
		      (ISNULL(L.Dataset_Folder, '') <> R.DatasetFolder) OR
		      (ISNULL(L.Results_Folder, '') <> R.ResultsFolder)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount > 0
		Begin
			set @message = 'Storage path info was updated from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS analyses using MT_Main.dbo.V_DMS_Analysis_Job_Import_Storage_Path; these are likely jobs with state "No Export" or jobs associated with non-released datasets'
			execute PostLogEntry 'Normal', @message, 'RefreshAnalysisStoragePathsNonCached'
		End

	End -- </c2>	


Done:
	
	return @myError


GO

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
**    
*****************************************************/
(
	@UpdateInterval int = 96,			-- Minimum interval in hours to limit update frequency; Set to 0 to force update now (looks in T_Log_Entries for last update time)
 	@message varchar(255) = '' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int

	set @myError = 0
	set @myRowCount = 0

 	set @message = ''

	declare @JobCountUpdated int
	declare @DatasetCountUpdated int
	
	set @JobCountUpdated = 0
	set @DatasetCountUpdated = 0
	
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
	Begin
		--------------------------------------------------------------
		-- Step 1: Update job information in T_Analysis_Description
		--------------------------------------------------------------
		--
		UPDATE T_Analysis_Description
		SET 
			Campaign = P.Campaign,
			Vol_Client = P.VolClient, 
			Vol_Server = P.VolServer, 
			Storage_Path = P.StoragePath, 
			Dataset_Folder = P.DatasetFolder, 
			Results_Folder = P.ResultsFolder,
			Completed = P.Completed,
			Parameter_File_Name = P.ParameterFileName,
			Settings_File_Name = P.SettingsFileName,
			Separation_Sys_Type = P.SeparationSysType,
			PreDigest_Internal_Std = P.[PreDigest Int Std],
			PostDigest_Internal_Std = P.[PostDigest Int Std],
			Dataset_Internal_Std = P.[Dataset Int Std],
			Enzyme_ID = P.EnzymeID,
			Labelling = P.Labelling
		FROM T_Analysis_Description AS TAD INNER JOIN (
			SELECT L.Job, R.Campaign, R.VolClient, R.VolServer, R.StoragePath, 
				R.DatasetFolder, R.ResultsFolder, R.Completed,
				R.ParameterFileName, R.SettingsFileName,
				R.SeparationSysType, R.[PreDigest Int Std], R.[PostDigest Int Std], R.[Dataset Int Std], 
				R.EnzymeID, R.Labelling
			FROM T_Analysis_Description AS L INNER JOIN
				MT_Main.dbo.V_DMS_Analysis_Job_Import_Ex AS R ON 
				L.Job = R.Job AND (
					IsNull(L.Campaign, '') <> R.Campaign OR
					IsNull(L.Vol_Client, '') <> R.VolClient OR 
					IsNull(L.Vol_Server, '') <> R.VolServer OR 
					IsNull(L.Storage_Path, '') <> R.StoragePath OR 
					IsNull(L.Dataset_Folder, '') <> R.DatasetFolder OR 
					IsNull(L.Results_Folder, '') <> R.ResultsFolder OR
					IsNull(L.Completed, '1/1/1980') <> R.Completed OR
					IsNull(L.Parameter_File_Name,'') <> IsNull(R.ParameterFileName,'') OR
					IsNull(L.Settings_File_Name,'') <> IsNull(R.SettingsFileName,'') OR
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
		--
		set @JobCountUpdated = @myRowCount
		if @JobCountUpdated > 0 and @myError = 0
		begin
			set @message = 'Job attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS/MS analyses'
			execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
		end
		else
			if @myError <> 0
			Begin
				Set @message = 'Error synchronizing T_Analysis_Description with V_DMS_Analysis_Job_Import_Ex'
				Set @myError = 101
				execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
				Goto Done
			End

		--------------------------------------------------------------
		-- Step 2: Update dataset information in T_Analysis_Description
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
				MT_Main.dbo.V_DMS_Dataset_Import_Ex AS R ON 
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
		if @DatasetCountUpdated > 0 and @myError = 0
		begin
			set @message = 'Dataset attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS/MS analyses'
			execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
		end
		else
			if @myError <> 0
			Begin
				Set @message = 'Error synchronizing T_Analysis_Description with V_DMS_Dataset_Import_Ex'
				Set @myError = 102
				execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
				Goto Done
			End


		--------------------------------------------------------------
		-- Step 3: Update job information in T_FTICR_Analysis_Description
		--------------------------------------------------------------
		--
		UPDATE T_FTICR_Analysis_Description
		SET 
			Campaign = P.Campaign,
			Vol_Client = P.VolClient, 
			Vol_Server = P.VolServer, 
			Storage_Path = P.StoragePath, 
			Dataset_Folder = P.DatasetFolder, 
			Results_Folder = P.ResultsFolder,
			Completed = P.Completed,
			Parameter_File_Name = P.ParameterFileName,
			Settings_File_Name = P.SettingsFileName,
			Separation_Sys_Type = P.SeparationSysType,
			PreDigest_Internal_Std = P.[PreDigest Int Std],
			PostDigest_Internal_Std = P.[PostDigest Int Std],
			Dataset_Internal_Std = P.[Dataset Int Std],
			Labelling = P.Labelling
		FROM T_FTICR_Analysis_Description AS TAD JOIN (
			SELECT L.Job, R.Campaign, R.VolClient, R.VolServer, R.StoragePath, 
				R.DatasetFolder, R.ResultsFolder, R.Completed,
				R.ParameterFileName, R.SettingsFileName,
				R.SeparationSysType, R.[PreDigest Int Std], R.[PostDigest Int Std], R.[Dataset Int Std], 
				R.Labelling
			FROM T_FTICR_Analysis_Description AS L INNER JOIN
				MT_Main.dbo.V_DMS_Analysis_Job_Import_Ex AS R ON 
				L.Job = R.Job AND (
					IsNull(L.Campaign, '') <> R.Campaign OR
					IsNull(L.Vol_Client, '') <> R.VolClient OR 
					IsNull(L.Vol_Server, '') <> R.VolServer OR 
					IsNull(L.Storage_Path, '') <> R.StoragePath OR 
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
		--
		set @JobCountUpdated = @JobCountUpdated + @myRowCount
		if @myRowCount > 0 and @myError = 0
		begin
			set @message = 'Job attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' MS analyses'
			execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
		end	
		else
			if @myError <> 0
			Begin
				Set @message = 'Error synchronizing T_FTICR_Analysis_Description with V_DMS_Analysis_Job_Import_Ex'
				Set @myError = 102
				execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
				Goto Done
			End

		--------------------------------------------------------------
		-- Step 4: Update dataset information in T_FTICR_Analysis_Description
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
				MT_Main.dbo.V_DMS_Dataset_Import_Ex AS R ON 
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
			if @myError <> 0
			Begin
				Set @message = 'Error synchronizing T_Analysis_Description with V_DMS_Dataset_Import_Ex'
				Set @myError = 102
				execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
				Goto Done
			End
			
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
			execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
		End
	End
	Else
		Set @message = 'Update skipped since ' + Convert(varchar(12), DateDiff(hour, @LastUpdated, GetDate())) + ' hours have elapsed since the last update (update interval is ' + Convert(varchar(12), @UpdateInterval) + ' hours)'

Done:
	
	return @myError


GO

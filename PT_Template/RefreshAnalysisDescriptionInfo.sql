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
**		Note: Use ResetChangedAnalysisJobs to look for jobs that have 
**			  ResultsFolder paths that differ from DMS.  If found, it
**			  updates the folder paths and resets the job's Process_State to 10
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/08/2005 mem
**			07/18/2005 mem - Now updating column Labelling
**			11/13/2005 mem - Now updating Created_DMS, Acq_Time_Start, Acq_Time_End, and Scan_Count in T_Datasets
**			11/16/2005 mem - Added IsNull() checking around all of the fields being compared to DMS
**			12/15/2005 mem - Now updating PreDigest_Internal_Std, PostDigest_Internal_Std, & Dataset_Internal_Std (previously named Internal_Standard)
**			03/08/2006 mem - Now updating column Campaign
**			11/15/2006 mem - Now updating columns Parameter_File_Name & Settings_File_Name
**			03/17/2007 mem - Now obtaining StoragePathClient and StoragePathServer from V_DMS_Analysis_Job_Import_Ex
**			05/09/2007 mem - Now using T_DMS_Analysis_Job_Info_Cached and T_DMS_Dataset_Info_Cached in MT_Main (Ticket:422)
**    
*****************************************************/
(
	@UpdateInterval int = 30,			-- Minimum interval in hours to limit update frequency; Set to 0 to force update now (looks in T_Log_Entries for last update time)
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
			Vol_Client = P.StoragePathClient, 
			Vol_Server = P.StoragePathServer, 
			Storage_Path = '', 
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
			SELECT L.Job, R.Campaign, R.StoragePathClient, R.StoragePathServer, 
				R.DatasetFolder, R.ResultsFolder, R.Completed,
				R.ParameterFileName, R.SettingsFileName,
				R.SeparationSysType, R.[PreDigest Int Std], R.[PostDigest Int Std], R.[Dataset Int Std], 
				R.EnzymeID, R.Labelling
			FROM T_Analysis_Description AS L INNER JOIN
				MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached AS R ON 
				L.Job = R.Job AND (
					IsNull(L.Campaign, '') <> R.Campaign OR
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
				Set @message = 'Error synchronizing T_Analysis_Description with T_DMS_Analysis_Job_Info_Cached'
				Set @myError = 101
				execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
				Goto Done
			End

		--------------------------------------------------------------
		-- Step 2: Update dataset information in T_Datasets
		--------------------------------------------------------------
		--
		UPDATE T_Datasets
		SET 
			Created_DMS = P.Created,
			Acq_Time_Start = P.[Acquisition Start], 
			Acq_Time_End = P.[Acquisition End],
			Scan_Count = P.[Scan Count]
		FROM T_Datasets AS DS INNER JOIN (
			SELECT L.Dataset_ID, R.Created, R.[Acquisition Start], R.[Acquisition End], R.[Scan Count]
			FROM T_Datasets AS L INNER JOIN
				MT_Main.dbo.T_DMS_Dataset_Info_Cached AS R ON 
				L.Dataset_ID = R.ID AND (
					L.Created_DMS <> R.Created OR 
					IsNull(L.Acq_Time_Start,0) <> IsNull(R.[Acquisition Start],0) OR
					IsNull(L.Acq_Time_End,0) <> IsNull(R.[Acquisition End],0) OR
					IsNull(L.Scan_Count,0) <> IsNull(R.[Scan Count],0)
				) 
			) AS P on P.Dataset_ID = DS.Dataset_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		set @DatasetCountUpdated = @myRowCount
		if @DatasetCountUpdated > 0 and @myError = 0
		begin
			set @message = 'Dataset attributes were refreshed from DMS for ' + Convert(varchar(12), @myRowCount) + ' datasets'
			execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
		end
		else
			if @myError <> 0
			Begin
				Set @message = 'Error synchronizing T_Datasets with T_DMS_Dataset_Info_Cached'
				Set @myError = 102
				execute PostLogEntry 'Error', @message, 'RefreshAnalysisDescriptionInfo'
				Goto Done
			End

		If @JobCountUpdated = 0 AND @DatasetCountUpdated = 0
		begin
			set @message = 'Synchronized analysis job and dataset attributes with DMS'
			execute PostLogEntry 'Normal', @message, 'RefreshAnalysisDescriptionInfo'
		end
		
	End
	Else
		Set @message = 'Update skipped since ' + Convert(varchar(12), DateDiff(hour, @LastUpdated, GetDate())) + ' hours have elapsed since the last update (update interval is ' + Convert(varchar(12), @UpdateInterval) + ' hours)'

Done:
	
	return @myError


GO

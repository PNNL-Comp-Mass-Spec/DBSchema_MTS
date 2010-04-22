/****** Object:  StoredProcedure [dbo].[PMExportDatasetJobInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure PMExportDatasetJobInfo
/****************************************************	
**  Desc:	Exports Dataset and Job information
**			for the peak matching tasks specified by the given MDID list
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/15/2009
**			08/24/2009 jds - Rearranged queries to reference #Tmp_MDIDList first
**
****************************************************/
(
	@MDIDs varchar(max) = '',
	@infoOnly tinyint = 0,
	@message varchar(512)='' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	
		Set @MDIDs = IsNull(@MDIDs, '')
		
		Set @infoOnly = IsNull(@infoOnly, 0)

		Set @message = ''
		
		If @MDIDs = ''
		Begin
			Set @message = '@MDIDs is empty; nothing to do'
			Goto Done
		End
		

		-------------------------------------------------
		-- Create and populate a temporary table with the data in @MDIDs
		-------------------------------------------------	

		CREATE TABLE #Tmp_MDIDList (
			MD_ID int NOT NULL
		)
		CREATE UNIQUE INDEX IX_Tmp_MDIDList_MDID ON #Tmp_MDIDList (MD_ID ASC)

		exec @myError = PMPopulateMDIDTable @MDIDs, @message = @message output
		if @myError <> 0
			Goto Done


		-------------------------------------------------	
		-- Return the data
		-------------------------------------------------	

		If @infoOnly <> 0
		Begin
			SELECT COUNT(DISTINCT FAD.Dataset_ID) AS Dataset_Count,
			       COUNT(DISTINCT FAD.Job) AS Job_Count,
			       COUNT(*) AS MDID_Count
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_Match_Making_Description MMD
			       ON MMD.MD_ID = ML.MD_ID
			     INNER JOIN T_FTICR_Analysis_Description FAD
			       ON MMD.MD_Reference_Job = FAD.Job
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		End
		Else
		Begin	
			SELECT ML.MD_ID,
			       FAD.Dataset,
			       FAD.Dataset_ID,
			       FAD.Dataset_Created_DMS,
			       FAD.Dataset_Acq_Time_Start,
			       FAD.Dataset_Acq_Time_End,
			       FAD.Dataset_Scan_Count,
			       FAD.Experiment,
			       FAD.Campaign,
			       FAD.Experiment_Organism,
			       FAD.Instrument_Class,
			       FAD.Instrument,
			       FAD.Vol_Server + FAD.Dataset_Folder + '\' + FAD.Results_Folder AS Storage_Path_Local,
			       FAD.Vol_Client + FAD.Dataset_Folder + '\' + FAD.Results_Folder AS Storage_Path_Archive,
			       FAD.Job,
			       FAD.Completed AS Job_Date,
			       FAD.Analysis_Tool,
			       FAD.Parameter_File_Name,
			       FAD.Settings_File_Name,
			       FAD.ResultType,
			       FAD.Separation_Sys_Type,
			       FAD.PreDigest_Internal_Std,
			       FAD.PostDigest_Internal_Std,
			       FAD.Dataset_Internal_Std,
			       FAD.Labelling
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_Match_Making_Description MMD
			       ON MMD.MD_ID = ML.MD_ID
			     INNER JOIN T_FTICR_Analysis_Description FAD
			       ON MMD.MD_Reference_Job = FAD.Job
			ORDER BY MMD.MD_ID

			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMExportDatasetJobInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto DoneSkipLog
	End Catch
				
Done:
	-----------------------------------------------------------
	-- Done processing
	-----------------------------------------------------------
		
	If @myError <> 0 
	Begin
		Execute PostLogEntry 'Error', @message, 'PMExportDatasetJobInfo'
		Print @message
	End

	-- DROP TABLE #Tmp_MDIDList

DoneSkipLog:	
	Return @myError

GO
GRANT EXECUTE ON [dbo].[PMExportDatasetJobInfo] TO [DMS_SP_User] AS [dbo]
GO

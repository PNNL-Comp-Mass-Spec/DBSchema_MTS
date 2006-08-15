/****** Object:  StoredProcedure [dbo].[UpdateDatasetToSICMapping] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateDatasetToSICMapping
/****************************************************
**
**	Desc: Associates Datasets with SIC jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**	
**
**		Auth: mem
**		Date: 12/13/2004
**			  01/24/2005 mem - Added @SkipDefinedDatasets parameter
**    
*****************************************************/
	@ProcessStateMatch int = 10,
	@NextProcessState int = 20,
	@entriesUpdated int = 0 output,
	@infoOnly tinyint = 0,
	@SICJobProcessStateMatch int = 75,
	@SkipDefinedDatasets tinyint = 0
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @message varchar(255)

	Declare @sql varchar(2048)
	Set @sql = ''


	---------------------------------------------------
	-- Update datasets in T_Datasets with state @ProcessStateMatch
	-- to point to the newest SIC job in T_Analysis_Description
	---------------------------------------------------
	--
	if @infoOnly = 0
	begin	
		Set @sql = @sql + ' UPDATE T_Datasets'
		Set @sql = @sql + ' SET SIC_Job = LookupQ.SIC_Job,'
		Set @sql = @sql + '     Dataset_Process_State = ' + Convert(varchar(9), @NextProcessState)
	end
	else
	begin
	  	Set @sql = @sql + ' SELECT T_Datasets.Dataset_ID, LookupQ.SIC_Job, LookupQ.Analysis_Tool'
	end
	Set @sql = @sql + ' FROM T_Datasets INNER JOIN'
	Set @sql = @sql + '   (SELECT Dataset_ID, Max(Job) As SIC_Job, Max(Analysis_Tool) As Analysis_Tool'
	Set @sql = @sql + '    FROM T_Analysis_Description AS AD'
	Set @sql = @sql + '    WHERE AD.ResultType = ''SIC'' AND'
	Set @sql = @sql + '       AD.Process_State = ' + Convert(varchar(9), @SICJobProcessStateMatch)
	Set @sql = @sql + '    GROUP BY Dataset_ID'
	Set @sql = @sql + '   ) As LookupQ ON'
	Set @sql = @sql + '    T_Datasets.Dataset_ID = LookupQ.Dataset_ID'
	Set @sql = @sql + ' WHERE T_Datasets.Dataset_Process_State = ' + convert(varchar(9), @ProcessStateMatch)
	if @SkipDefinedDatasets = 1
		Set @sql = @sql + ' AND T_Datasets.SIC_Job Is Null'

	if @infoOnly = 1
		Set @sql = @sql + ' ORDER BY T_Datasets.Dataset_ID'

	Exec (@sql)
	--
	SELECT @entriesUpdated = @@rowcount, @myError = @@error
	--
	If @myError <> 0 and @infoOnly = 0
	Begin
		Set @message = 'Error updating T_Datasets with new SIC jobs: ' + Convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'UpdateDatasetToSICMapping'
		Goto Done
	End

	
	-- Post the log entry messages
	--
	set @message = 'Updated mapping between dataset and SIC Job for ' + convert(varchar(11), @entriesUpdated) + ' datasets'
	If @infoOnly = 0 And (@entriesUpdated > 0)
		execute PostLogEntry 'Normal', @message, 'UpdateDatasetToSICMapping'

Done:
	return @myError



GO

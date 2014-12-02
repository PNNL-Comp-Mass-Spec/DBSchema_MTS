/****** Object:  StoredProcedure [dbo].[UpdateDatasetToSICMapping] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE UpdateDatasetToSICMapping
/****************************************************
**
**	Desc: Associates Datasets with SIC jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**	
**
**	Auth:	mem
**	Date:	12/13/2004
**			01/24/2005 mem - Added @SkipDefinedDatasets parameter
**			06/11/2013 mem - Changed logic for choosing SIC jobs
**			12/01/2014 mem - Added new MASIC parameter files
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
	-- Create a table listing the preference order for SIC jobs
	---------------------------------------------------
	
	CREATE TABLE #Tmp_PrefOrder (
		Entry_ID int IDENTITY(1,1),
		Param_File_Name varchar(128) NOT NULL
	)

	Insert into #Tmp_PrefOrder (Param_file_Name) 
	Values 
	    ('ITRAQ_LTQ-FT_10ppm_ReporterTol0.015Da_2014-08-06.xml'),
	    ('ITRAQ_LTQ-FT_10ppm_ReporterTol0.015Da_2009-12-22.xml'), 
	    ('ITRAQ8_LTQ-FT_10ppm_ReporterTol0.015Da_2014-08-06.xml'),
		('ITRAQ8_LTQ-FT_10ppm_ReporterTol0.015Da_2009-12-22.xml'), 
		('ITRAQ_LTQ-FT_10ppm_2008-09-05.xml'), 
		('ITRAQ8_LTQ-FT_10ppm_2009-12-24.xml'), 
		('TMT10_LTQ-FT_10ppm_ReporterTol0.003Da_2014-08-06.xml'),
		('TMT6_LTQ-FT_10ppm_ReporterTol0.015Da_2014-08-06.xml'),
		('TMT6_LTQ-FT_10ppm_ReporterTol0.015Da_2010-12-13.xml'), 
		('LTQ-FT_10ppm_2014-08-06.xml'),
		('LTQ-FT_10ppm_2008-08-22.xml'), 
		('Default_2008-08-22.xml'), 
		('TIC_Only_2008-11-07.xml')


	If @infoOnly > 0
		SELECT * FROM #Tmp_PrefOrder
		
	---------------------------------------------------
	-- Update datasets in T_Datasets with state @ProcessStateMatch
	-- to point to the most appropriate SIC job in T_Analysis_Description
	---------------------------------------------------
	--
	if @infoOnly = 0
	begin	
		Set @sql = @sql + ' UPDATE T_Datasets'
		Set @sql = @sql + ' SET SIC_Job = BestJobQ.SIC_Job,'
		Set @sql = @sql + '     Dataset_Process_State = ' + Convert(varchar(9), @NextProcessState)
	end
	else
	begin
	  	Set @sql = @sql + ' SELECT T_Datasets.Dataset_ID, BestJobQ.SIC_Job, BestJobQ.Analysis_Tool, BestJobQ.Parameter_File_Name'
	end
	Set @sql = @sql + ' FROM T_Datasets INNER JOIN'
	Set @sql = @sql +     ' ( SELECT Dataset_ID, SIC_Job, Analysis_Tool, Parameter_File_Name'
	Set @sql = @sql +       ' FROM ( SELECT AD.Dataset_ID, AD.Job AS SIC_Job, AD.Analysis_Tool AS Analysis_Tool, AD.Parameter_File_Name,'
	Set @sql = @sql +                     ' Row_Number() OVER ( Partition BY AD.Dataset_ID ORDER BY IsNull(Entry_ID, 999), Job DESC ) AS SICJobRank'
	Set @sql = @sql +              ' FROM T_Analysis_Description AD'
	Set @sql = @sql +              ' LEFT OUTER JOIN #Tmp_PrefOrder PrefOrder ON AD.Parameter_File_Name = PrefOrder.Param_File_Name'
	Set @sql = @sql +              ' WHERE AD.ResultType = ''SIC'' AND AD.Process_State = ' + Convert(varchar(9), @SICJobProcessStateMatch)
	Set @sql = @sql +            ' ) RankQ'
	Set @sql = @sql +       ' WHERE SICJobRank = 1'
	Set @sql = @sql +     ' ) AS BestJobQ ON T_Datasets.Dataset_ID = BestJobQ.Dataset_ID'
	Set @sql = @sql + ' WHERE T_Datasets.Dataset_Process_State = ' + convert(varchar(9), @ProcessStateMatch)
	if @SkipDefinedDatasets = 1
		Set @sql = @sql + ' AND T_Datasets.SIC_Job Is Null'

	if @infoOnly > 0
		Set @sql = @sql + ' ORDER BY T_Datasets.Dataset_ID'

	If @infoOnly > 0
		Print @Sql
		
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
GRANT VIEW DEFINITION ON [dbo].[UpdateDatasetToSICMapping] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateDatasetToSICMapping] TO [MTS_DB_Lite] AS [dbo]
GO

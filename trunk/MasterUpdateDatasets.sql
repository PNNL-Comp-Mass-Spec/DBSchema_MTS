/****** Object:  StoredProcedure [dbo].[MasterUpdateDatasets] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.MasterUpdateDatasets
/****************************************************
**
**	Desc: Updates the datasets in T_Datasets
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**	
**
**		Auth: mem
**		Date: 12/13/2004
**			  01/24/2005 mem - Updated call to UpdateDatasetToSICMapping to utilize @SkipDefinedDatasets
**    
*****************************************************/
	@numDatasetsToProcess int = 50000
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @result int
	declare @count int
	declare @countAddnl int
	declare @logLevel int
	set @logLevel = 1		-- Default to normal logging

	declare @ProcessStateMatch int
	declare @NextProcessState int
	declare @SICJobProcessStateMatch int
	declare @SkipDefinedDatasets int
	
	declare @message varchar(255)
	set @message = ''

	declare @PeptideDatabase varchar(128)
	set @PeptideDatabase = DB_Name()
	
	--------------------------------------------------------------
	-- Lookup the LogLevel state
	-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
	--------------------------------------------------------------
	--
	set @result = @logLevel
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')
	Set @logLevel = @result

	set @message = 'Begin Dataset Master Update for ' + @PeptideDatabase
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateDatasets'

	--------------------------------------------------------------
	-- Associate Datasets with loaded SIC jobs
	--------------------------------------------------------------
	--
	-- < 1 >
	--
	Set @ProcessStateMatch = 10
	Set @NextProcessState = 20
	Set @SICJobProcessStateMatch = 75
	Set @count = 0
	Set @countAddnl = 0
	
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdateDatasetToSICMapping')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped UpdateDatasetToSICMapping', 'MasterUpdateDatasets'
	end
	else
	begin
		-- First update the mapping for datasets in state 10
		Set @SkipDefinedDatasets = 0
		EXEC @result = UpdateDatasetToSICMapping @ProcessStateMatch, @NextProcessState, @count OUTPUT, 0, @SICJobProcessStateMatch, @SkipDefinedDatasets
		
		-- Now update the mapping for datasets in state 20, but with null SIC_Job values
		Set @ProcessStateMatch = 20
		Set @SkipDefinedDatasets = 1
		EXEC @result = UpdateDatasetToSICMapping @ProcessStateMatch, @NextProcessState, @countAddnl OUTPUT, 0, @SICJobProcessStateMatch, @SkipDefinedDatasets
		Set @count = @count + @countAddnl
	end


Done:
	
	--------------------------------------------------------------
	-- Normal Exit
	--------------------------------------------------------------
	set @message = 'Completed master update datasets for ' + @PeptideDatabase + ': ' + convert(varchar(32), @myError)
	If (@logLevel >=1 AND @myError <> 0) OR @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateDatasets'

	return @myError



GO

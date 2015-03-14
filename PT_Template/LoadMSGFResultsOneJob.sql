/****** Object:  StoredProcedure [dbo].[LoadMSGFResultsOneJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure LoadMSGFResultsOneJob
/****************************************************
**
**	Desc:	Load MSGF results for one job
**			The calling procedure must create table #Tmp_MSGF_Results
**			 before calling this procedure
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/22/2010
**			10/12/2010 mem - Now setting @myError to 52099 when ValidateDelimitedFile returns a result code = 63
**
*****************************************************/
(
	@job int,
	@MSGFResultsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_MSGF.txt',
	@MSGFCountLoaded int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT,
	@RaiseErrorIfFileNotFound tinyint = 0				-- If 0 and if file not found, then returns 0; if non-zero and file not found, then returns 52002
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @fileExists tinyint
	declare @LineCountToSkip int	-- This will be set to a positive number if the file contains a header line
	declare @columnCount int
	
	declare @columnCountExpected int

	-- Clear the outputs
	Set @MSGFCountLoaded = 0
	Set @message = ''
	
	declare @jobStr varchar(12)
	set @jobStr = convert(varchar(12), @Job)
	
	-----------------------------------------------
	-- See if the MSGF results file exists and validate that it has 7 columns
	-----------------------------------------------
	Set @ColumnCountExpected = 7

	-- Could set @LineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
	-- However, this validation works by looking for a numeric value in the first column, and MSGF files have text in the first column
	Set @LineCountToSkip = 1
	Exec @myError = ValidateDelimitedFile @MSGFResultsFilePath, @lineCountToSkip OUTPUT, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT
	
	-- Note: ValidateDelimitedFile should return 62 if the file does not exist
	if @myError <> 0 AND @myError <> 62
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @MSGFResultsFilePath + ' (Code ' + Convert(varchar(11), @myError) + ')'

		if @myError = 63
			-- OpenTextFile was unable to open the file
			-- We need to set the completion code to 9, meaning we want to retry the load
			-- Error code 52099 is used by LoadPeptidesForOneAnalysis
			set @myError = 52099
		else
			Set @myError = 52001
			
		Goto Done
	End
	else
	Begin
		If @fileExists = 0 Or @columnCount = 0
		Begin
			-- File does not exist or file is empty; do not proceed
			If @RaiseErrorIfFileNotFound = 0
			Begin
				-- set @myError to 0 and clear @message since this is not an error
				Set @myError = 0
				Set @message = ''
			End
			Else
			Begin
				If @myError = 0
					Set @myError = 52002
				If Len(@message) = 0
					Set @message = 'MSGF file is empty for job ' + @jobStr + ' (' + @MSGFResultsFilePath + ')'
			End
			Goto Done
		End
		Else
		Begin
			If @columnCount < @ColumnCountExpected
			Begin
				Set @message = 'MSGF file only contains ' + convert(varchar(11), @columnCount) + ' columns for job ' + @jobStr + ' (Expecting ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
				set @myError = 52003
				Goto Done
			End
		End
	End

	-----------------------------------------------
	-- Make sure table #Tmp_MSGF_Results is empty
	-----------------------------------------------
	--
	TRUNCATE TABLE #Tmp_MSGF_Results
	--
	if @myError <> 0
	begin
		set @message = 'Problem clearing table #Tmp_MSGF_Results'
		goto Done
	end

	-----------------------------------------------
	-- Bulk load contents of MSGF file into temporary table
	-----------------------------------------------
	--
	declare @c nvarchar(2048)

	Set @c = 'BULK INSERT #Tmp_MSGF_Results FROM ' + '''' + @MSGFResultsFilePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @LineCountToSkip+1) + ')' 
	exec @myError = sp_executesql @c
	--
	if @myError <> 0
	begin
		set @message = 'Problem executing bulk insert into #Tmp_MSGF_Results for job ' + @jobStr
		Set @myError = 51006
		goto Done
	end

	SELECT @MSGFCountLoaded = Count(*)
	FROM #Tmp_MSGF_Results
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
		
	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadMSGFResultsOneJob] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadMSGFResultsOneJob] TO [MTS_DB_Lite] AS [dbo]
GO

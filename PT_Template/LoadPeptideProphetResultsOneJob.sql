/****** Object:  StoredProcedure [dbo].[LoadPeptideProphetResultsOneJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadPeptideProphetResultsOneJob
/****************************************************
**
**	Desc:	Load Peptide Prophet results for one job
**			The calling procedure must create table #Tmp_PepProphet_Results
**			 before calling this procedure
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	08/01/2006
**			10/12/2010 mem - Now setting @myError to 52099 when ValidateDelimitedFile returns a result code = 63
**
*****************************************************/
(
	@job int,
	@PeptideProphetResultsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_PepProphet.txt',
	@PeptideProphetCountLoaded int = 0 OUTPUT,
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
	Set @PeptideProphetCountLoaded = 0
	Set @message = ''
	
	declare @jobStr varchar(12)
	set @jobStr = convert(varchar(12), @Job)
	
	-----------------------------------------------
	-- See if the Peptide Prophet results file exists and validate that it has 4 columns
	-----------------------------------------------
	Set @ColumnCountExpected = 4

	-- Set @LineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
	Set @LineCountToSkip = -1
	Exec @myError = ValidateDelimitedFile @PeptideProphetResultsFilePath, @lineCountToSkip OUTPUT, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT
	
	-- Note: ValidateDelimitedFile should return 62 if the file does not exist
	if @myError <> 0 AND @myError <> 62
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideProphetResultsFilePath + ' (Code ' + Convert(varchar(11), @myError) + ')'

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
					Set @message = 'PepProphet file is empty for job ' + @jobStr + ' (' + @PeptideProphetResultsFilePath + ')'
			End
			Goto Done
		End
		Else
		Begin
			If @columnCount < @ColumnCountExpected
			Begin
				Set @message = 'PepProphet file only contains ' + convert(varchar(11), @columnCount) + ' columns for job ' + @jobStr + ' (Expecting ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
				set @myError = 52003
				Goto Done
			End
		End
	End

	-----------------------------------------------
	-- Make sure table #Tmp_PepProphet_Results is empty
	-----------------------------------------------
	--
	TRUNCATE TABLE #Tmp_PepProphet_Results
	--
	if @myError <> 0
	begin
		set @message = 'Problem clearing table #Tmp_PepProphet_Results'
		goto Done
	end

	-----------------------------------------------
	-- Bulk load contents of PepProphet file into temporary table
	-----------------------------------------------
	--
	declare @c nvarchar(2048)

	Set @c = 'BULK INSERT #Tmp_PepProphet_Results FROM ' + '''' + @PeptideProphetResultsFilePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @LineCountToSkip+1) + ')' 
	exec @myError = sp_executesql @c
	--
	if @myError <> 0
	begin
		set @message = 'Problem executing bulk insert into #Tmp_PepProphet_Results for job ' + @jobStr
		Set @myError = 51006
		goto Done
	end

	SELECT @PeptideProphetCountLoaded = Count(*)
	FROM #Tmp_PepProphet_Results
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
		
	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadPeptideProphetResultsOneJob] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadPeptideProphetResultsOneJob] TO [MTS_DB_Lite] AS [dbo]
GO

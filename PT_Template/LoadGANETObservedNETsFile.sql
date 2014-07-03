/****** Object:  StoredProcedure [dbo].[LoadGANETObservedNETsFile] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure LoadGANETObservedNETsFile
/****************************************************
**
**	Desc: 
**		Loads observed NET values for each scan of each job
**
**	Parameters:
**
**	Auth:	mem
**	Date:	03/17/2010 mem
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			03/25/2013 mem - Now updating #Tmp_NET_Update_Jobs
**    
*****************************************************/
(
	@file varchar(255) = 'ObservedNETsAfterRegression.txt',
	@ResultsFolderPath varchar(255) = '',
	@message varchar(255) = '' output,
	@numLoaded int = 0 output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	
	Declare @PeptidesUpdated int
	Declare @JobCount int
	Declare @result int
	
	declare @filePath varchar(512)
	
	declare @c nvarchar(2048)

	declare @fileExists tinyint
	declare @LineCountToSkip int	-- This will be set to a positive number if the file contains a header line
	declare @columnCount int

	set @myError = 0
	set @myRowCount = 0

	set @message = ''
	set @numLoaded = 0
	set @PeptidesUpdated = 0
	set @JobCount = 0

	-----------------------------------------------
	-- Set up file names and paths
	-----------------------------------------------
	set @filePath = dbo.udfCombinePaths(@ResultsFolderPath, @file)


	-----------------------------------------------
	-- Verify that input file exists and count the number of columns
	-----------------------------------------------
	-- Set @LineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
	Set @LineCountToSkip = -1
	Exec @result = ValidateDelimitedFile @filePath, @LineCountToSkip OUTPUT, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 3
	
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @filePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 50000		
	End
	else
	Begin
		if @columnCount <> 5
		begin
			If @columnCount = 0
			Begin
				Set @message = 'Empty Observed NETs file: ' + @filePath
				set @myError = 50001
			End
			Else
			Begin
				Set @message = 'Observed NETs file contains ' + convert(varchar(11), @columnCount) + ' columns; (Expecting exactly 5 columns): ' + @file
				set @myError = 50002
			End
		end
	End

	-----------------------------------------------
	-- Load Observed NETs from file
	-----------------------------------------------
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done
	
	-----------------------------------------------
	-- create temporary table to hold contents of file
	-----------------------------------------------
	--
	CREATE TABLE #Tmp_ObservedNETs (
		Job	int NOT NULL,
		MassTagID int NOT NULL,
		Scan int NOT NULL,
		ElutionTime	real NULL,			-- Note the ElutionTime value in the Observed NETs file comes from column Scan_Time_Peak_Apex in T_Peptides (see ExportGANETPeptideFile)
		ObservedNET real NULL
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table'
		goto Done
	end

	-----------------------------------------------
	-- Add index to temporary table to improve the 
	-- speed of the Update query
	-----------------------------------------------
	--
	CREATE NONCLUSTERED INDEX #IX_Tmp_ObservedNETs ON #Tmp_ObservedNETs (Job, MassTagID, Scan)

	
	-----------------------------------------------
	-- bulk load contents of results file into temporary table
	-- using bulk insert function
	-----------------------------------------------
	--

	Set @c = 'BULK INSERT #Tmp_ObservedNETs FROM ' + '''' + @filePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @LineCountToSkip+1) + ')' 
	exec @result = sp_executesql @c
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	set @numLoaded = @myRowCount
	--
	if @result <> 0
	begin
		set @message = 'Problem executing bulk insert'
		set @myError = @result
		goto Done
	end

	If Not Exists (SELECT * FROM #Tmp_ObservedNETs)
	Begin
		Set @message = 'No results in Observed NETs file: ' + @filePath
		set @myError = 50004
		Goto Done
	End
	
	-----------------------------------------------
	-- Clear the Observed NET values for the affected jobs
	-----------------------------------------------
	UPDATE T_Peptides
	SET GANET_Obs = NULL
	FROM T_Peptides
	WHERE Job IN ( SELECT DISTINCT Job FROM #Tmp_ObservedNETs ) AND
	      NOT GANET_Obs IS NULL
	
	-----------------------------------------------
	-- Populate Observed NET values from imported values
	-----------------------------------------------

	-- copy imported values into T_Sequence table, joining
	-- on Seq_ID
	--
	UPDATE T_Peptides
	SET GANET_Obs = Src.ObservedNET
	FROM T_Peptides AS Target
	     INNER JOIN #Tmp_ObservedNETs Src
	       ON Target.Job = Src.Job AND
	          Target.Seq_ID = Src.MassTagID AND
	          Target.Scan_Number = Src.Scan
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem copying data from temp table'
		goto Done
	end
	
	set @PeptidesUpdated = @myRowCount

	SELECT @JobCount = COUNT(DISTINCT Job)
	FROM #Tmp_ObservedNETs


	-----------------------------------------------
	-- Keep track of which jobs were processed
	-----------------------------------------------
	--
	UPDATE #Tmp_NET_Update_Jobs
	SET ObservedNETsLoaded = 1
	WHERE Job IN ( SELECT DISTINCT Job FROM #Tmp_ObservedNETs )


	-----------------------------------------------
	-- Define log message
	-----------------------------------------------

	set @message = 'Updated observed NETs for ' + Convert(varchar(12), @PeptidesUpdated) + ' peptides in T_Peptides (' + Convert(varchar(12), @numLoaded) + ' distinct scans in ' +  Convert(varchar(12), @JobCount)

	if @JobCount = 1
		Set @message = @message + ' job)'
	else
		Set @message = @message + ' jobs)'


	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError


GO

/****** Object:  StoredProcedure [dbo].[LoadGANETJobFile] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure LoadGANETJobFile
/****************************************************
**
**	Desc: 
**		Loads GANET fits for analysis jobs using the bulk insert function
**
**	Parameters:
**
**	Auth:	grk
**	Date:	05/14/2002
**			03/23/2004 mem - Changed to multiply the slopes in the input file by 1000 when reading since new version of GANET normalization SW outputs the true slope, but T_Analysis_Description stores the slope multiplied by 1000
**			04/08/2004 mem - Removed final call to PostLogEntry since the MasterUpdateNET procedure will post @message
**			07/05/2004 mem - Updated procedure for use in Peptide DB's
**			11/27/2004 mem - Updated to read the R-squared column (if present)
**			01/22/2005 mem - Switched to storing the results in the ScanTime_NET columns
**			05/28/2005 mem - Switched from @InFolder to @ResultsFolderPath, which is the full path to the results folder)
**			06/04/2006 mem - Increased size of the @filePath variable and the @c variable (used for Bulk Insert)
**			07/04/2006 mem - Now checking for a header row in the input file; also, updated to use udfCombinePaths and to correct some comments
**			03/17/2010 mem - Now populating Regression_Order, Regression_Filtered_Data_Count, Regression_Equation, and Regression_Equation_XML to T_Analysis_Description
**
*****************************************************/
(
	@file varchar(255) = 'JobGANETs.txt',
	@ResultsFolderPath varchar(255) = 'F:\GA_Net_Xfer\In\',
	@message varchar(255) = '' output,
	@numLoaded int = 0 out
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @completionCode tinyint
	set @completionCode = 3

	set @message = ''
	set @numLoaded = 0

	declare @S varchar(1024)	
	declare @result int
	declare @filePath varchar(512)
	
	-----------------------------------------------
	-- Set up file names and paths
	-----------------------------------------------
	set @filePath = dbo.udfCombinePaths(@ResultsFolderPath, @file)

	declare @fileExists tinyint
	declare @LineCountToSkip int	-- This will be set to a positive number if the file contains a header line
	declare @columnCount int
	
	-----------------------------------------------
	-- Verify that input file exists and count the number of columns
	-----------------------------------------------
	-- Set @LineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
	Set @LineCountToSkip = -1
	Exec @result = ValidateDelimitedFile @filePath, @LineCountToSkip OUTPUT, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 1
	
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @filePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 50001
	End
	else
	Begin
		If @columnCount = 0
		Begin
			Set @message = 'GANET Job File is empty'
			set @myError = 50002
		End
		Else
		Begin
			If @columnCount <> 5 And @columnCount <> 9
			Begin
				Set @message = 'GANET job file contains ' + convert(varchar(11), @columnCount) + ' columns (Expecting 5 columns or 9 columns)'
				set @myError = 50003
			End
		End
	End
	
	-----------------------------------------------
	-- Load updated GANETs from file
	-----------------------------------------------
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done

	-----------------------------------------------
	-- create temporary table to hold contents 
	-- of file
	-----------------------------------------------
	--
	CREATE TABLE #T_GAImport (
		Job int NOT NULL ,
		Intercept float NULL ,
		Slope float NULL ,
		Fit float NULL,
		RSquared float NULL
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table'
		goto Done
	end
	
	If @columnCount > 5
	Begin
		-- Add the additional columns now so they 
		--  will be populated during the Bulk Insert operation
		ALTER TABLE #T_GAImport ADD
			Regression_Order tinyint NULL,
			Regression_Filtered_Data_Count int NULL,
			Regression_Equation varchar(512),
			Regression_Equation_XML varchar(max) NULL
	End
	
	-----------------------------------------------
	-- bulk load contents of results file into temporary table
	-- using bulk insert function
	-----------------------------------------------
	--
	declare @c nvarchar(2024)

	Set @c = 'BULK INSERT #T_GAImport FROM ' + '''' + @filePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @LineCountToSkip+1) + ')' 
	exec @result = sp_executesql @c
	--
	if @result <> 0
	begin
		set @message = 'Problem executing bulk insert'
		set @myError = @result
		goto Done
	end

	-----------------------------------------------
	-- update GA NET parameters in analysis description
	-- table from contents of temporary table
	-----------------------------------------------
	--
	Set @S = ''
	
	If @columnCount = 5
	Begin
		Set @S = @S + ' UPDATE TAD '
		Set @S = @S +   ' SET TAD.ScanTime_NET_Slope = GA.Slope, '
		Set @S = @S +   ' TAD.ScanTime_NET_Intercept = GA.Intercept, '
		Set @S = @S +   ' TAD.ScanTime_NET_Fit = GA.Fit,'
		Set @S = @S +   ' TAD.ScanTime_NET_RSquared = GA.RSquared'
		Set @S = @S + ' FROM T_Analysis_Description AS TAD'
		Set @S = @S +   ' INNER JOIN #T_GAImport AS GA ON TAD.Job = GA.Job'
	End
	Else
	Begin	
		Set @S = @S + ' UPDATE TAD '
		Set @S = @S +   ' SET TAD.ScanTime_NET_Slope = GA.Slope, '
		Set @S = @S +   ' TAD.ScanTime_NET_Intercept = GA.Intercept, '
		Set @S = @S +   ' TAD.ScanTime_NET_Fit = GA.Fit,'
		Set @S = @S +   ' TAD.ScanTime_NET_RSquared = GA.RSquared,'
		Set @S = @S +   ' TAD.Regression_Order = GA.Regression_Order,'
		Set @S = @S +   ' TAD.Regression_Filtered_Data_Count = GA.Regression_Filtered_Data_Count,'
		Set @S = @S +   ' TAD.Regression_Equation = GA.Regression_Equation, '
		Set @S = @S +   ' TAD.Regression_Equation_XML = GA.Regression_Equation_XML'
		Set @S = @S + ' FROM T_Analysis_Description AS TAD'
		Set @S = @S +   ' INNER JOIN #T_GAImport AS GA ON TAD.Job = GA.Job'
	End
	
	EXEC (@S)
	--
	SELECT @myError = @@error, @myRowCount = @myRowCount + @@rowcount
	--
	set @numLoaded = @myRowCount

	-----------------------------------------------
	-- log entry
	-----------------------------------------------

	set @message = 'Updated Analysis Job GANETs: ' + cast(@myRowCount as varchar(12))

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[LoadGANETJobFile] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadGANETJobFile] TO [MTS_DB_Lite] AS [dbo]
GO

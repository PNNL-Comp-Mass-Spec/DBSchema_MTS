SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LoadGANETJobFile]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[LoadGANETJobFile]
GO


CREATE Procedure dbo.LoadGANETJobFile
/****************************************************
**
**	Desc: 
**		Loads GANET fits for analysis jobs
**
**		Uses bulk insert function
**
**	Parameters:
**
**		Auth: grk
**		Date: 5/14/2002
**
**		Updated:    
**			 03/23/2004 mem - Changed to multiply the slopes in the input file by 1000 when reading since new version of GANET normalization SW outputs the true slope, but T_Analysis_Description stores the slope multiplied by 1000
**			 04/08/2004 mem - Removed final call to PostLogEntry since the MasterUpdateNET procedure will post @message
**			 07/05/2004 mem - Updated procedure for use in Peptide DB's
**			 11/27/2004 mem - Updated to read the R-squared column (if present)
**			 01/22/2005 mem - Switched to storing the results in the ScanTime_NET columns
**			 05/28/2005 mem - Switched from @InFolder to @ResultsFolderPath, which is the full path to the results folder)
**
*****************************************************/
	@file varchar(255) = 'JobGANETs.txt',
	@ResultsFolderPath varchar(255) = 'F:\GA_Net_Xfer\In\',
	@message varchar(255) = '' out,
	@numLoaded int = 0 out
AS
	set nocount on
	declare @myError int
	set @myError = 0

	declare @myRowcount int
	
	declare @completionCode tinyint
	set @completionCode = 3

	set @message = ''
	set @numLoaded = 0
	
	declare @result int
	
	declare @filePath varchar(255)
	
	If Right(@ResultsFolderPath,1) <> '\'
		Set @ResultsFolderPath = @ResultsFolderPath + '\'

	set @filePath = @ResultsFolderPath + @file

	declare @fileExists tinyint
	declare @columnCount int
	
	-----------------------------------------------
	-- Verify that input file exists and count the number of columns
	-----------------------------------------------
	Exec @result = ValidateDelimitedFile @filePath, 0, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT
	
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
			set @myError = 50002	-- Note that this error code is used in SP LoadPeptidesForAvailableAnalyses; do not change
		End
		Else
		Begin
			If @columnCount <> 5
			Begin
				Set @message = 'GANET job file contains ' + convert(varchar(11), @columnCount) + ' columns (Expecting 5 columns)'
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
	-- of synopsis file
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
	
	-----------------------------------------------
	-- bulk load contents of synopsis file into temporary table
	-- using bulk loading function (very fast)
	-----------------------------------------------
	--
	declare @c nvarchar(255)

	Set @c = 'BULK INSERT #T_GAImport FROM ' + '''' + @filePath + ''''

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

	UPDATE TAD
	SET	TAD.ScanTime_NET_Slope = GA.Slope,
		TAD.ScanTime_NET_Intercept = GA.Intercept, 
		TAD.ScanTime_NET_Fit = GA.Fit,
		TAD.ScanTime_NET_RSquared = GA.RSquared
	FROM T_Analysis_Description AS TAD
	INNER JOIN #T_GAImport AS GA ON TAD.Job = GA.Job
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


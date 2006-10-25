/****** Object:  StoredProcedure [dbo].[LoadMASICScanStatsBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadMASICScanStatsBulk
/****************************************************
**
**	Desc: 
**		Load Scan Stats for MASIC job into T_Dataset_Stats_Scans
**		for given analysis job using bulk loading techniques
**
**	Parameters:	Returns 0 if no error, error code if an error
**
**	Auth:	mem
**	Date:	12/12/2004
**			10/23/2005 mem - Increased size of @ScanStatsFilePath from varchar(255) to varchar(512)
**			06/04/2006 mem - Added parameter @ScanStatsLineCountToSkip, which is used to skip the header line, if present in the input file
**						   - Increased size of the @c variable (used for Bulk Insert)
**			09/26/2006 mem - Added support for ScanStats files containing 10 columns
**    
*****************************************************/
(
	@ScanStatsFilePath varchar(512),
	@Job int,
	@ScanStatsColumnCount smallint=0,		-- If this is 0, then this SP will call ValidateDelimitedFile; if non-zero, then assumes the calling procedure called ValidateDelimitedFile to get this value
	@ScanStatsLineCountToSkip int=0,
	@numLoaded int=0 output,
	@message varchar(512)='' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @numLoaded = 0
	set @message = ''

	declare @jobStr varchar(12)
	set @jobStr = cast(@Job as varchar(12))

	declare @fileExists tinyint
	declare @result int

	-----------------------------------------------
	-- Create a temporary table to hold the contents of the file
	-- Additional columns will be added to this table depending on
	--  the column count in the input file
	-----------------------------------------------
	--
	CREATE TABLE #T_ScanStats_Import (
		Dataset_ID int NOT NULL ,
		Scan_Number int NOT NULL ,
		Scan_Time real NULL ,
		Scan_Type tinyint NULL ,
		Total_Ion_Intensity float NULL ,
		Base_Peak_Intensity float NULL ,
		Base_Peak_MZ float NULL ,
		Base_Peak_SN_Ratio real NULL 
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #T_ScanStats_Import for job ' + @jobStr
		goto Done
	end

	-----------------------------------------------
	-- Verify that input file exists and count the number of columns
	-----------------------------------------------

	If IsNull(@ScanStatsColumnCount, 0) <= 0
	Begin
		-- Set @ScanStatsLineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
		Set @ScanStatsLineCountToSkip = -1
		Exec @result = ValidateDelimitedFile @ScanStatsFilePath, @ScanStatsLineCountToSkip OUTPUT, @fileExists OUTPUT, @ScanStatsColumnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 2
	End
	Else
		Set @result = 0
		
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @ScanStatsFilePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 50001
	End
	else
	Begin
		If @ScanStatsColumnCount = 0
		Begin
			Set @message = 'Scan Stats File is empty'
			set @myError = 50002
		End
		Else
		Begin
			If @ScanStatsColumnCount <> 8 and @ScanStatsColumnCount <> 10
			Begin
				Set @message = 'Scan Stats file contains ' + convert(varchar(11), @ScanStatsColumnCount) + ' columns (Expecting 8 or 10 columns)'
				set @myError = 50003
			End
		End
	End

	-- Don't do any more if errors at this point
	--
	if @myError <> 0 goto done

	If @ScanStatsColumnCount = 10
	Begin
		-- Add the additional columns now so they 
		--  will be populated during the Bulk Insert operation
		ALTER TABLE #T_ScanStats_Import ADD
			Ion_Count int NULL,				-- Not actually stored in the database
			Ion_Count_Raw int NULL			-- Not actually stored in the database
	End
		
	-----------------------------------------------
	-- Bulk load contents of SIC stats file into temporary table
	-----------------------------------------------
	--
	declare @c nvarchar(2048)

	Set @c = 'BULK INSERT #T_ScanStats_Import FROM ' + '''' + @ScanStatsFilePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @ScanStatsLineCountToSkip+1) + ')'
	exec @result = sp_executesql @c
	--
	if @result <> 0
	begin
		set @message = 'Problem executing bulk insert for job ' + @jobStr
		Set @myError = 50004
		goto Done
	end

	/*
	**	If @ScanStatsColumnCount <> 10
	**	Begin
	**		-- Could add additional columns to #T_ScanStats_Import if needed
	**		ALTER TABLE #T_ScanStats_Import ADD
	**			Ion_Count int NULL,
	**			Ion_Count_Raw int NULL
	**	End
	*/

	-----------------------------------------------
	-- Delete any existing results for @Job in T_Dataset_Stats_Scans
	-----------------------------------------------
	DELETE FROM T_Dataset_Stats_Scans
	WHERE Job = @Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error deleting existing entries in T_Dataset_Stats_Scans for job ' + @jobStr
		goto Done
	end


	-----------------------------------------------
	-- copy contents of temporary table into T_Dataset_Stats_Scans
	-----------------------------------------------
	--
	INSERT INTO T_Dataset_Stats_Scans
	(
		Job,
		Scan_Number,
		Scan_Time,
		Scan_Type,
		Total_Ion_Intensity,
		Base_Peak_Intensity,
		Base_Peak_MZ,
		Base_Peak_SN_Ratio
	)
	SELECT
		@Job,	
		Scan_Number,
		Scan_Time,
		Scan_Type,
		Total_Ion_Intensity,
		Base_Peak_Intensity,
		Base_Peak_MZ,
		Base_Peak_SN_Ratio
	FROM #T_ScanStats_Import
	ORDER BY Scan_Number
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting into T_Dataset_Stats_Scans for job ' + @jobStr
		goto Done
	end

	Set @numLoaded = @myRowCount

Done:
	return @myError


GO

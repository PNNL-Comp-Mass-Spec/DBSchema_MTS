/****** Object:  StoredProcedure [dbo].[LoadMASICSICStatsBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadMASICSICStatsBulk
/****************************************************
**
**	Desc: 
**		Load SIC Stats for MASIC job into T_Dataset_Stats_SIC
**		for given analysis job using bulk loading techniques
**
**	Parameters:	Returns 0 if no error, error code if an error
**
**	Auth:	mem
**	Date:	12/12/2004
**			11/01/2005 mem - Added new columns: Parent_Ion_Intensity, Peak_Baseline_Noise_Level, Peak_Baseline_Noise_StDev, 
**							 Peak_Baseline_Points_Used, Peak_CenterOfMass_Scan, Peak_StDev, and Peak_Skew
**						   - Total column count is now 22
**						   - Added parameter @SICStatsColumnCount
**						   - Increased size of @SICStatsFilePath from varchar(255) to varchar(512)
**			11/07/2005 mem - Switched alternate SICStats column count from 22 to 25 columns, adding columns StatMoments_Area, Peak_KSStat, and StatMoments_DataCount_Used
**			06/04/2006 mem - Added parameter @SICStatsLineCountToSkip, which is used to skip the header line, if present in the input file
**						   - Increased size of the @c variable (used for Bulk Insert)
**			03/25/2013 mem - No longer storing the last 9 columns from MASIC SICResults files
**    
*****************************************************/
(
	@SICStatsFilePath varchar(512),
	@Job int,
	@SICStatsColumnCount smallint=0,		-- If this is 0, then this SP will call ValidateDelimitedFile; if non-zero, then assumes the calling procedure called ValidateDelimitedFile to get this value
	@SICStatsLineCountToSkip int=0,
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

	declare @Sql varchar(2048)

	declare @fileExists tinyint
	declare @result int
	
	-----------------------------------------------
	-- Create a temporary table to hold the contents of the file
	-- Additional columns will be added to this table depending on
	--  the column count in the input file
	-----------------------------------------------
	--
	CREATE TABLE #T_SICStats_Import (
		Dataset_ID int NOT NULL ,
		Parent_Ion_Index int NOT NULL ,
		MZ float NULL ,
		Survey_Scan_Number int NULL ,
		Frag_Scan_Number int NULL ,
		Optimal_Peak_Apex_Scan_Number int NULL ,
		Peak_Apex_Override_Parent_Ion_Index int NULL ,
		Custom_SIC_Peak tinyint NULL ,
		Peak_Scan_Start int NULL ,
		Peak_Scan_End int NULL ,
		Peak_Scan_Max_Intensity int NULL ,
		Peak_Intensity float NULL ,
		Peak_SN_Ratio real NULL ,
		FWHM_In_Scans int NULL ,
		Peak_Area float NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #T_SICStats_Import for job ' + @jobStr
		goto Done
	end

	-----------------------------------------------
	-- Verify that input file exists and count the number of columns
	-----------------------------------------------

	If IsNull(@SICStatsColumnCount, 0) <= 0
	Begin
		-- Set @ScanStatsLineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
		Set @SICStatsLineCountToSkip = -1
		Exec @result = ValidateDelimitedFile @SICStatsFilePath, @SICStatsLineCountToSkip OUTPUT, @fileExists OUTPUT, @SICStatsColumnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 2
	End
	Else
		Set @result = 0
		
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @SICStatsFilePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 50001
	End
	else
	Begin
		If @SICStatsColumnCount = 0
		Begin
			Set @message = 'SIC Stats File is empty'
			set @myError = 50002
		End
		Else
		Begin
			If @SICStatsColumnCount <> 15 and @SICStatsColumnCount <> 25
			Begin
				Set @message = 'SIC Stats file contains ' + convert(varchar(11), @SICStatsColumnCount) + ' columns (Expecting 15 or 25 columns)'
				set @myError = 50003
			End
		End
	End

	-- Don't do any more if errors at this point
	--
	if @myError <> 0 goto done

	If @SICStatsColumnCount = 25
	Begin
		-- Add the additional columns now so they 
		--  will be populated during the Bulk Insert operation
		ALTER TABLE #T_SICStats_Import ADD
			Parent_Ion_Intensity real NULL,

			-- Note that the following 9 columns are not stored in T_Dataset_Stats_SIC
			Peak_Baseline_Noise_Level real NULL,
			Peak_Baseline_Noise_StDev real NULL,
			Peak_Baseline_Points_Used int NULL,			-- Stored in T_Dataset_Stats_SIC as a SmallInt; max value is 32767
			StatMoments_Area real NULL,
			CenterOfMass_Scan int NULL,
			Peak_StDev real NULL,
			Peak_Skew real NULL,
			Peak_KSStat real NULL,
			StatMoments_DataCount_Used int NULL			-- Stored in T_Dataset_Stats_SIC as a SmallInt; max value is 32767
	End
		
	-----------------------------------------------
	-- Bulk load contents of SIC stats file into temporary table
	-----------------------------------------------
	--
	declare @c nvarchar(2048)

	Set @c = 'BULK INSERT #T_SICStats_Import FROM ' + '''' + @SICStatsFilePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @SICStatsLineCountToSkip+1) + ')'
	exec @result = sp_executesql @c
	--
	if @result <> 0
	begin
		set @message = 'Problem executing bulk insert for job ' + @jobStr
		Set @myError = 50004
		goto Done
	end

	If @SICStatsColumnCount <> 25
	Begin
		-- Need to add the additional columns to #T_SICStats_Import now
		--  prior to appending the data to T_Dataset_Stats_SIC
		ALTER TABLE #T_SICStats_Import ADD
			Parent_Ion_Intensity real NULL,

			-- Note that the following 9 columns are not stored in T_Dataset_Stats_SIC
			Peak_Baseline_Noise_Level real NULL,
			Peak_Baseline_Noise_StDev real NULL,
			Peak_Baseline_Points_Used int NULL,			-- Stored in T_Dataset_Stats_SIC as a SmallInt; max value is 32767
			StatMoments_Area real NULL,
			CenterOfMass_Scan int NULL,
			Peak_StDev real NULL,
			Peak_Skew real NULL,
			Peak_KSStat real NULL,
			StatMoments_DataCount_Used int NULL			-- Stored in T_Dataset_Stats_SIC as a SmallInt; max value is 32767
	End


	-----------------------------------------------
	-- Delete any existing results for @Job in T_Dataset_Stats_SIC
	-----------------------------------------------
	DELETE FROM T_Dataset_Stats_SIC
	WHERE Job = @Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error deleting existing entries in T_Dataset_Stats_SIC for job ' + @jobStr
		goto Done
	end

	-----------------------------------------------
	-- Copy contents of temporary table into T_Dataset_Stats_SIC
	-- We have to use dynamic Sql to do this since the stored procedure
	--  throws an error of "Invalid column name 'Parent_Ion_Intensity'"
	--  if normal Sql is used.  This error occurs because that column
	--  is appended to the table after the table is created, but the
	--  stored procedure parser doesn't realize this
	-----------------------------------------------
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' INSERT INTO T_Dataset_Stats_SIC'
	Set @Sql = @Sql +   ' (Job,Parent_Ion_Index,MZ,Survey_Scan_Number,Frag_Scan_Number,'
	Set @Sql = @Sql +   ' Optimal_Peak_Apex_Scan_Number,Peak_Apex_Override_Parent_Ion_Index,Custom_SIC_Peak,'
	Set @Sql = @Sql +   ' Peak_Scan_Start,Peak_Scan_End,Peak_Scan_Max_Intensity,Peak_Intensity,Peak_SN_Ratio,'
	Set @Sql = @Sql +   ' FWHM_In_Scans,Peak_Area,Parent_Ion_Intensity)'
	Set @Sql = @Sql + ' SELECT '
	Set @Sql = @Sql +   Convert(varchar(19), @Job) + ',Parent_Ion_Index,MZ,Survey_Scan_Number,Frag_Scan_Number,'
	Set @Sql = @Sql +   ' Optimal_Peak_Apex_Scan_Number,Peak_Apex_Override_Parent_Ion_Index,Custom_SIC_Peak,'
	Set @Sql = @Sql +   ' Peak_Scan_Start,Peak_Scan_End,Peak_Scan_Max_Intensity,Peak_Intensity,Peak_SN_Ratio,'
	Set @Sql = @Sql +   ' FWHM_In_Scans,Peak_Area,Parent_Ion_Intensity'
	Set @Sql = @Sql + ' FROM #T_SICStats_Import'
	Set @Sql = @Sql + ' ORDER BY Parent_Ion_Index'
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting into T_Dataset_Stats_SIC for job ' + @jobStr
		goto Done
	end

	Set @numLoaded = @myRowCount

Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadMASICSICStatsBulk] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadMASICSICStatsBulk] TO [MTS_DB_Lite] AS [dbo]
GO

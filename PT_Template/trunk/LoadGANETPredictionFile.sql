/****** Object:  StoredProcedure [dbo].[LoadGANETPredictionFile] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadGANETPredictionFile
/****************************************************
**
**	Desc: 
**		Loads GANET elution time prediction for peptide sequences
**
**	Parameters:
**
**	Auth:	grk
**	Date:	08/09/2002
**			04/08/2004 mem - Removed final call to PostLogEntry since the MasterUpdateNET procedure will post @message
**			06/12/2004 mem - Removed filtering on Dyn_Mod_ID = 1 and Static_Mod_Id = 1 when looking up the mass tag ID values
**			08/06/2004 mem - Updated procedure for use in Peptide DB's
**			08/10/2004 mem - added updating of GANET_Predicted in the Master Sequences DB
**			08/30/2004 mem - Added support for mod descriptions in the input file
**			09/06/2004 mem - Added index to temporary table #Tmp_TGA
**			10/15/2004 mem - Switched to using Seq_ID from PredictGANETs.txt file to update tables, rather than linking on sequence and modification
**			11/24/2004 mem - Increased size of Dynamic_Mod_List field from 255 to 2048 characters
**			02/21/2005 mem - Switched Master_Sequences location from PrismDev to Albert
**			05/29/2005 mem - Switched from @InFolder to @ResultsFolderPath, which is the full path to the results folder)
**			07/01/2005 mem - Now updating column Last_Affected in Master_Sequences.dbo.T_Sequence
**			05/03/2006 mem - Switched Master_Sequences location from Albert to Daffy
**			05/13/2006 mem - Switched to using CreateTempPNETTables and UpdatePNETDataForSequences in the Master_Sequences database rather than directly linking to table T_Sequence
**			06/04/2006 mem - Increased size of the @filePath variable and the @c variable (used for Bulk Insert)
**			07/04/2006 mem - Now checking for a header row in the input file; also, updated to use udfCombinePaths and to correct some comments
**    
*****************************************************/
(
	@file varchar(255) = 'PredictGANETs.txt',
	@ResultsFolderPath varchar(255) = '',
	@message varchar(255) = '' output,
	@numLoaded int = 0 output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @completionCode tinyint
	set @completionCode = 3

	declare @MasterSequencesServerName varchar(64)
	set @MasterSequencesServerName = 'Daffy'

	set @message = ''
	set @numLoaded = 0
	
	declare @result int
	
	declare @filePath varchar(512)
	
	declare @PNetTableName varchar(256)
	declare @DeleteTempTables tinyint
	declare @processCount int

	set @DeleteTempTables = 0
	set @processCount = 0

	declare @Sql varchar(1024)

	declare @logLevel int
	set @logLevel = 1		-- Default to normal logging

	--------------------------------------------------------------
	-- Lookup the LogLevel state
	-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
	--------------------------------------------------------------
	--
	SELECT @logLevel = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')
	
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
	Exec @result = ValidateDelimitedFile @filePath, @LineCountToSkip OUTPUT, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 3
	
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @filePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 50000		
	End
	else
	Begin
		if @columnCount <> 4
		begin
			If @columnCount = 0
			Begin
				Set @message = 'Empty Predicted NET file: ' + @filePath
				set @myError = 50001
			End
			Else
			Begin
				Set @message = 'Predicted NET file contains ' + convert(varchar(11), @columnCount) + ' columns; (Expecting exactly 4 columns): ' + @file
				set @myError = 5002
			End
		end
	End

	-----------------------------------------------
	-- Load GANET predicted elution times from file
	-----------------------------------------------
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done
	
	-----------------------------------------------
	-- create temporary table to hold contents of file
	-----------------------------------------------
	--
	CREATE TABLE #Tmp_TGA (
		pep_seq varchar(900) NOT NULL ,
		Dynamic_Mod_List varchar(2048) NULL ,
		Seq_ID int NOT NULL,
		PNET float NULL
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
	CREATE NONCLUSTERED INDEX #IX_TempTable_TGA_Seq_ID ON #Tmp_TGA (Seq_ID)

	
	-----------------------------------------------
	-- bulk load contents of results file into temporary table
	-- using bulk insert function
	-----------------------------------------------
	--
	declare @c nvarchar(2048)

	Set @c = 'BULK INSERT #Tmp_TGA FROM ' + '''' + @filePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @LineCountToSkip+1) + ')' 
	exec @result = sp_executesql @c
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	set @numLoaded = @myRowCount
	--
	if @result <> 0
	begin
		set @message = 'Problem executing bulk insert'
		goto Done
	end

	
	-----------------------------------------------
	-- Populate GANET predicted NET values from imported values
	-----------------------------------------------

	-- copy imported values into T_Sequence table, joining
	-- on Seq_ID
	--
	UPDATE T_Sequence
	SET T_Sequence.GANET_Predicted = #Tmp_TGA.PNET
	FROM T_Sequence AS T INNER JOIN #Tmp_TGA ON 
		 #Tmp_TGA.Seq_ID = T.Seq_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem copying data from temp table'
		goto Done
	end
	
	set @numLoaded = @myRowCount


	-----------------------------------------------
	-- Populate GANET predicted in the Master Sequences DB
	-----------------------------------------------

	-- If the Master Sequences DB is on the same server as this DB, then we can use this query
	--  UPDATE MST
	--  SET GANET_Predicted = #Tmp_TGA.PNET, Last_Affected = GetDate()
	--  FROM Daffy.Master_Sequences.dbo.T_Sequence AS MST INNER JOIN
	--  	 #Tmp_TGA ON #Tmp_TGA.Seq_ID = MST.Seq_ID
	--  WHERE MST.GANET_Predicted <> #Tmp_TGA.PNET OR MST.GANET_Predicted Is Null
	
	-- However, since the Master Sequences DB could be on a different server, we need to use Master_Seq_Scratch

	-----------------------------------------------------------
	-- Create a table on the master sequences server to cache the NET data
	-----------------------------------------------------------
	--
	set @message = 'Call Master_Sequences.dbo.CreateTempPNETTables for file ' + @file
	If @logLevel >= 2
		execute PostLogEntry 'Progress', @message, 'LoadGANETPredictionFile'
	--
	-- Warning: Update @MasterSequencesServerName above if changing from Daffy to another computer
	exec Daffy.Master_Sequences.dbo.CreateTempPNETTables @PNetTableName output
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem calling CreateTempPNETTables to create the temporary PNET data table for file ' + @file
		goto Done
	end
	else
		set @DeleteTempTables = 1

	-----------------------------------------------------------
	-- Populate @PNetTableName with the PNET data
	-----------------------------------------------------------
	--
	set @message = 'Populate the TempPNETTable with the PNET data for file ' + @file
	If @logLevel >= 2
		execute PostLogEntry 'Progress', @message, 'LoadGANETPredictionFile'
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' INSERT INTO ' + @MasterSequencesServerName + '.' + @PNetTableName + ' (Seq_ID, PNET)'
	Set @Sql = @Sql + ' SELECT Seq_ID, PNET'
	Set @Sql = @Sql + ' FROM #Tmp_TGA'
	--
	Exec (@Sql)
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem populating ' + @PNetTableName + ' with the PNET data for file ' + @file
		goto Done
	end


	-----------------------------------------------------------
	-- Call UpdatePNETDataForSequences to update the PNET values
	-----------------------------------------------------------
	--
	set @message = 'Call Master_Sequences.dbo.UpdatePNETDataForSequences for file ' + @file
	If @logLevel >= 2
		execute PostLogEntry 'Progress', @message, 'LoadGANETPredictionFile'
	--
	exec @myError = Daffy.Master_Sequences.dbo.UpdatePNETDataForSequences @PNetTableName, @processCount output, @message output
	--
	if @myError <> 0
	begin
		If Len(@message) = 0
			set @message = 'Error calling Master_Sequences.dbo.UpdatePNETDataForSequences for file ' + @file + ': ' + convert(varchar(12), @myError)
		else
			set @message = 'Error calling Master_Sequences.dbo.UpdatePNETDataForSequences for file ' + @file + ': ' + @message
			
		goto Done
	end

	-----------------------------------------------
	-- log entry
	-----------------------------------------------

	set @message = 'Updated predicted NETs for ' + cast(@numLoaded as varchar(12)) + ' sequences'

	
	-----------------------------------------------------------
	-- Delete the temporary PNET data table, since no longer needed
	-----------------------------------------------------------
	--
	If @DeleteTempTables = 1
		exec Daffy.Master_Sequences.dbo.DropTempSequenceTables @PNetTableName


	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError


GO

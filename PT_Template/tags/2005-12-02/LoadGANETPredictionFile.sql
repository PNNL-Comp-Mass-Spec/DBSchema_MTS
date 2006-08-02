SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LoadGANETPredictionFile]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[LoadGANETPredictionFile]
GO


CREATE Procedure dbo.LoadGANETPredictionFile
/****************************************************
**
**	Desc: 
**		Loads GANET elution time prediction for peptide sequences
**
**	Parameters:
**
**		Auth: grk
**		Date: 8/9/2002
**
**		Updated:    
**			 04/08/2004 mem - Removed final call to PostLogEntry since the MasterUpdateNET procedure will post @message
**			 06/12/2004 mem - Removed filtering on Dyn_Mod_ID = 1 and Static_Mod_Id = 1 when looking up the mass tag ID values
**			 08/06/2004 mem - Updated procedure for use in Peptide DB's
**			 08/10/2004 mem - added updating of GANET_Predicted in the Master Sequences DB
**			 08/30/2004 mem - Added support for mod descriptions in the input file
**			 09/06/2004 mem - Added index to temporary table #TGA
**			 10/15/2004 mem - Switched to using Seq_ID from PredictGANETs.txt file to update tables, rather than linking on sequence and modification
**			 11/24/2004 mem - Increased size of Dynamic_Mod_List field from 255 to 2048 characters
**			 02/21/2005 mem - Switched Master_Sequences location from PrismDev to Albert
**			 05/29/2005 mem - Switched from @InFolder to @ResultsFolderPath, which is the full path to the results folder)
**			 07/01/2005 mem - Now updating column Last_Affected in Master_Sequences.dbo.T_Sequence
**    
*****************************************************/
	@file varchar(255) = 'PredictGANETs.txt',
	@ResultsFolderPath varchar(255) = '',
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
	declare @fileExists tinyint
	declare @columnCount int
	
	-----------------------------------------------
	-- Set up file names and paths
	-----------------------------------------------
	
	If Right(@ResultsFolderPath,1) <> '\'
		Set @ResultsFolderPath = @ResultsFolderPath + '\'
	
	set @filePath = @ResultsFolderPath + @file

	
	-----------------------------------------------
	-- Verify that input file exists and count the number of columns
	-----------------------------------------------
	Exec @result = ValidateDelimitedFile @filePath, 0, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT
	
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
	CREATE TABLE #TGA (
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
	CREATE NONCLUSTERED INDEX IX_TempTable_TGA_Seq_ID ON #TGA (Seq_ID)

	
	-----------------------------------------------
	-- bulk load contents of synopsis file into temporary table
	-- using bulk loading function (very fast)
	-----------------------------------------------
	--
	declare @c nvarchar(255)

	Set @c = 'BULK INSERT #TGA FROM ' + '''' + @filePath + ''''
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
	SET T_Sequence.GANET_Predicted = #TGA.PNET
	FROM T_Sequence AS T INNER JOIN #TGA ON 
		 #TGA.Seq_ID = T.Seq_ID
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
	UPDATE MST
	SET GANET_Predicted = #TGA.PNET, Last_Affected = GetDate()
	FROM Albert.Master_Sequences.dbo.T_Sequence AS MST INNER JOIN
		 #TGA ON #TGA.Seq_ID = MST.Seq_ID
	WHERE MST.GANET_Predicted <> #TGA.PNET OR MST.GANET_Predicted Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	begin
		Set @numLoaded = 0
		Set @message = 'Error updating GANET_Predicted value in the Master Sequences DB'
		goto done
	end

	-----------------------------------------------
	-- log entry
	-----------------------------------------------

	set @message = 'Updated predicted NETs for ' + cast(@numLoaded as varchar(12)) + ' sequences'

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


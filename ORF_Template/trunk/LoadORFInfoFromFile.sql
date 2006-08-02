SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LoadORFInfoFromFile]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[LoadORFInfoFromFile]
GO

CREATE Procedure dbo.LoadORFInfoFromFile
/****************************************************
** 
**		Desc: 
**			Loads ORF sequences from a tab delimeted
**			text file using Bulk Insert
**
**			The text file should have data for ORF, Description, Sequence, and Mass (optional)
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: mem
**		Date: 04/13/2004
**			  04/29/2004 by mem - Changed to load the file from the path given by @FolderPath,
**								  no longer appending the database name to @FolderPath prior to loading
**    
*****************************************************/
(
	@file varchar(255) = 'OrfInputFile.txt',						-- Input file name
	@FolderPath varchar(255) = '\\Gigasax\DMS_Organism_Files\',		-- Path that @file is located in
	@ClearExistingORFs tinyint = 1,									-- If 1, then clears T_ORF before loading; otherwise, appends and updates
	@message varchar(255) = '' output,
	@numLoaded int = 0 output
)
As
	Set NoCount On

	declare @myError int
	set @myError = 0

	declare @myRowcount int
	
	set @message = ''
	set @numLoaded = 0
	
	declare @result int
	
	-----------------------------------------------
	-- Set up file names and paths
	-----------------------------------------------

	declare @filePath varchar(255)
	If Right(@FolderPath,1) <> '\'
		Set @FolderPath = @FolderPath + '\'
		
	set @filePath = @FolderPath + @file
	
	-----------------------------------------------
	-- Deal with existing files
	-----------------------------------------------

	DECLARE @FSOObject int
	DECLARE @TxSObject int
	DECLARE @hr int
	
	-- Create a FileSystemObject object.
	--
	EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @FSOObject OUT
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
		goto Done
	END
	-- verify that the input file exists
	--
	EXEC @hr = sp_OAMethod  @FSOObject, 'FileExists', @result OUT, @filePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
	    goto DestroyFSO
	END
	--
	If @result = 0
	begin
		set @message = 'file does not exist' + @filePath
		set @myError = 60
	    goto DestroyFSO
	end

	-----------------------------------------------
	-- clean up file system object
	-----------------------------------------------
  
DestroyFSO:
	-- Destroy the FileSystemObject object.
	--
	EXEC @hr = sp_OADestroy @FSOObject
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
		goto done
	END
	
	-----------------------------------------------
	-- Load ORFs from input file
	-- Should be a tab-delimeted file with:
	--  ORF_Name	Description	Sequence	Mass
	-----------------------------------------------
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done
	
	-----------------------------------------------
	-- create temporary table to hold contents 
	-- of  file
	-----------------------------------------------
	--
	CREATE TABLE #ORFsImport (
		Reference varchar(128) NOT NULL ,
		Description text NULL ,
		Protein_Sequence text NOT NULL,
		Monoisotopic_Mass float NULL
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
	-- bulk load contents of file into temporary table
	-----------------------------------------------
	--
	declare @c nvarchar(255)

	Set @c = 'BULK INSERT #ORFsImport FROM ' + '''' + @filePath + ''''
	exec @result = sp_executesql @c
	--
	if @result <> 0
	begin
		set @message = 'Problem executing bulk insert'
		goto Done
	end

	-----------------------------------------------
	-- update ORFs by copying contents from #ORFsImport
	-- into T_ORF
	-----------------------------------------------
	--
	If @ClearExistingORFs <> 0
	Begin
		DELETE FROM T_ORF
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		Set @numLoaded = 0
	End
	Else
	Begin
		-- Update existing ORFs
		UPDATE T_ORF
		SET Description_From_FASTA = OI.Description, 
			Protein_Sequence = OI.Protein_Sequence, 
			Monoisotopic_Mass = OI.Monoisotopic_Mass
		FROM #ORFsImport AS OI INNER JOIN T_ORF ON T_ORF.Reference = OI.Reference
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		Set @numLoaded = @myRowCount
		
		DELETE #ORFsImport
		FROM #ORFsImport AS OI INNER JOIN T_ORF ON T_ORF.Reference = OI.Reference
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
	End	
	
	-- Add any new ORFs
	INSERT INTO T_ORF
		(Reference, Description_From_FASTA, Protein_Sequence, Monoisotopic_Mass, Date_Created)
	SELECT Reference, Description, Protein_Sequence, Monoisotopic_Mass, GetDate()
	FROM #ORFsImport
	WHERE #ORFsImport.Reference NOT IN (SELECT Reference FROM T_ORF)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	set @numLoaded = @numLoaded + @myRowCount

	-----------------------------------------------
	-- log entry
	-----------------------------------------------

	set @message = 'Loaded ORFs from text file: ' + cast(@numLoaded as varchar(12))

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	execute PostLogEntry 'Normal', @message, 'LoadORFInfoFromFile'
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


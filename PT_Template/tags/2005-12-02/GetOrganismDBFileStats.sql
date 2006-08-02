SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetOrganismDBFileStats]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetOrganismDBFileStats]
GO


CREATE PROCEDURE dbo.GetOrganismDBFileStats
/****************************************************
**
**	Desc: 
**		Returns various statistics concerning the 
**		Organism DB (aka FASTA file) given by @OrganismDBFileName
**
**	Return values: 0: end of line not yet encountered
**
**	Parameters:
**
**		Auth: mem
**		Date: 08/06/2004
**			  08/31/2004 mem - Updated to use MT_Main..V_Organism_DB_File_Export
**			  10/04/2005 mem - Updated log entries to include Job number
**    
*****************************************************/
	@Job int,
	@ORFCount int = 0 OUTPUT,
	@ResidueCount int = 0 OUTPUT
AS
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @message varchar(255)
	set @message = ''
	
	Set @ORFCount = 0
	Set @ResidueCount = 0

	Declare @OrganismDBFileName varchar(128),
			@OrganismDBFilePath varchar(255)

	-----------------------------------------------
	--  Lookup the Fasta file name and stats for this Job
	-----------------------------------------------
	SELECT	TOP 1 
			@ORFCount = OFI.NumProteins,
			@ResidueCount = OFI.NumResidues
	FROM	T_Analysis_Description AS AD INNER JOIN MT_Main.dbo.V_DMS_Organism_DB_File_Import AS OFI ON
			AD.Organism_DB_Name = OFI.Filename
	WHERE AD.Job = @Job
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error while looking up Organism DB File Stats from MT_Main'
		Set @myError = 201
		goto done
	end
	
	if @myRowCount <> 1
	begin
		-- Post an error entry to the log
		set @message = 'Match not found in MT_Main..V_DMS_Organism_DB_File_Import for Job''s organism filename; Job ' + Convert(varchar(12), @Job)
		execute PostLogEntry 'Error', @message, 'GetOrganismDBFileStats'
		set @message = ''
		
		-----------------------------------------------
		-- Look up the FASTA file's size (in bytes) using the fso
		-----------------------------------------------
		--	
		-- Lookup the Fasta file name for this Job
		SELECT	TOP 1 @OrganismDBFileName = Organism_DB_Name,
				@OrganismDBFilePath = OFP.OG_OrganismDBPath
		FROM	T_Analysis_Description AS AD INNER JOIN MT_Main.dbo.V_DMS_OrganismDB_Folder_Path AS OFP ON
				AD.Organism = OFP.OG_Name
		WHERE Job = @Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Error while looking up Organism DB File Path from MT_Main for Job ' + Convert(varchar(12), @Job)
			Set @myError = 203
			goto done
		end
		
		if @myRowCount <> 1
		begin
			set @message = 'Match not found in T_Analysis_Description or MT_Main..V_DMS_OrganismDB_Folder_Path for Job ' + Convert(varchar(12), @Job)
			Set @myError = 204
			goto done
		end
		
		-----------------------------------------------
		-- Define the path to the file
		-----------------------------------------------
		--
		If Right(@OrganismDBFilePath,1) <> '\'
			Set @OrganismDBFilePath = @OrganismDBFilePath + '\'

		Set @OrganismDBFilePath = @OrganismDBFilePath + @OrganismDBFileName
		
		
		-----------------------------------------------
		-- Verify the file exists, then determine the size
		-----------------------------------------------

		DECLARE @FSOObject int
		DECLARE @FileObject int
		DECLARE @hr int
		DECLARE @result int
		
		-- Create a FileSystemObject object.
		--
		EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @FSOObject OUT
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			set @myError = 60
			goto Done
		END
		-- verify that the file exists
		--
		EXEC @hr = sp_OAMethod  @FSOObject, 'FileExists', @result OUT, @OrganismDBFilePath
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			set @myError = 60
			goto DestroyFSO
		END
		--
		If @result = 0
		begin
			set @message = 'File does not exist: ' + @OrganismDBFilePath
			set @myError = 203
			goto DestroyFSO
		end

		-- Create a File object.
		--
		EXEC @hr = sp_OAMethod  @FSOObject, 'GetFile', @FileObject OUT, @OrganismDBFilePath
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			set @myError = 60
			goto Done
		END
		
		-- Lookup the size of the file
		--
		EXEC @hr = sp_OAMethod  @FileObject, 'Size', @result OUT
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			set @myError = 60
			goto DestroyFSO
		END

		Declare @FileSizeBytes int
		SET @FileSizeBytes = @result
		
		-- Estimate the ORF count and residue count values:
		Set @ORFCount = Round(Convert(float, @FileSizeBytes) * 0.002, 0)
		Set @ResidueCount = Round(Convert(float, @FileSizeBytes) * 0.84, 0)
		
		-----------------------------------------------
		-- clean up file object and file system object
		-----------------------------------------------
	  
	DestroyFSO:
		-- Destroy the File object
		If @FileObject <> 0
		BEGIN
			EXEC @hr = sp_OADestroy @FileObject
			IF @hr <> 0
			BEGIN
				EXEC LoadGetOAErrorMessage @FileObject, @hr, @message OUT
				set @myError = 60
				goto done
			END
		END
		
		-- Destroy the FileSystemObject object.
		--
		EXEC @hr = sp_OADestroy @FSOObject
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			set @myError = 60
			goto done
		END
	End
	

Done:
	if len(@message) > 0
		execute PostLogEntry 'Error', @message, 'GetOrganismDBFileStats'
		
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


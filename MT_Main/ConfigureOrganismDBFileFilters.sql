/****** Object:  StoredProcedure [dbo].[ConfigureOrganismDBFileFilters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE ConfigureOrganismDBFileFilters
/****************************************************
**
**	Desc: 	Configures the Organism DB File and/or Protein Collection 
**			entries in T_Process_Config in the given database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/27/2006
**			12/01/2006 mem - Now using udfParseDelimitedIntegerList to parse @OrganismDBFileList
**    
*****************************************************/
(
	@DatabaseName varchar(64) = '',
	@OrganismDBFileList varchar(1024) = '',				-- Optional, comma separated list of fasta files or comma separated list of protein collection names; e.g. 'PCQ_ETJ_2004-01-21.fasta,PCQ_ETJ_2004-01-21'
	@message varchar(512) = '' output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	Set @message = ''

	Declare @Sql varchar(1024)
	Declare @OrganismDBListCurrent varchar(1024)
	Declare @ParameterUpdateCount int
	Set @ParameterUpdateCount = 0
	
	---------------------------------------------------
	-- Create a temporary table to hold the fasta file or protein collection names
	---------------------------------------------------
	CREATE TABLE #Tmp_OrganismDBFiles (
		Organism_DB_File varchar(255)
	)
	
	---------------------------------------------------
	-- Split @OrganismDBFileList on ',' and populate #Tmp_OrganismDBFiles
	---------------------------------------------------
	INSERT INTO #Tmp_OrganismDBFiles(Organism_DB_File)
	SELECT Value
	FROM dbo.udfParseDelimitedList(@OrganismDBFileList, ',')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = 'Parameter @OrganismDBFileList should not be blank'
		Set @myError = 200
		Goto Done
	End
	Else
	Begin
		---------------------------------------------------
		-- Add an entry for Organism_DB_File_Name for each .Fasta file in #Tmp_OrganismDBFiles
		-- Since AddUpdateConfigEntry takes a comma-separated list, we'll
		--  generate a list using #Tmp_OrganismDBFiles
		---------------------------------------------------
		Set @OrganismDBListCurrent = ''
		SELECT @OrganismDBListCurrent = @OrganismDBListCurrent + Organism_DB_File + ','
		FROM #Tmp_OrganismDBFiles
		WHERE Organism_DB_File LIKE '%.Fasta'
		ORDER BY Organism_DB_File
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount > 0
		Begin
			Set @ParameterUpdateCount = @ParameterUpdateCount + @myRowCount
			
			-- Remove the trailing comma from @OrganismDBListCurrent
			Set @OrganismDBListCurrent = Left(@OrganismDBListCurrent, Len(@OrganismDBListCurrent)-1)

			Exec AddUpdateConfigEntry @DatabaseName, 'Organism_DB_File_Name', @OrganismDBListCurrent
		
			DELETE FROM #Tmp_OrganismDBFiles
			WHERE Organism_DB_File LIKE '%.Fasta'
		End

		---------------------------------------------------
		-- Add an entry for Protein_Collection_Filter for each remaining entry in #Tmp_OrganismDBFiles
		---------------------------------------------------
		Set @OrganismDBListCurrent = ''
		SELECT @OrganismDBListCurrent = @OrganismDBListCurrent + Organism_DB_File + ','
		FROM #Tmp_OrganismDBFiles
		ORDER BY Organism_DB_File
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount > 0
		Begin
			Set @ParameterUpdateCount = @ParameterUpdateCount + @myRowCount

			-- Remove the trailing comma from @OrganismDBListCurrent
			Set @OrganismDBListCurrent = Left(@OrganismDBListCurrent, Len(@OrganismDBListCurrent)-1)
			
			Exec AddUpdateConfigEntry @DatabaseName, 'Protein_Collection_Filter', @OrganismDBListCurrent
		End
		
		If @ParameterUpdateCount > 0
		Begin
			---------------------------------------------------
			-- One or more valid entries was defined, so delete
			--  any '<Fill In>' entries that remain in T_Process_Config
			---------------------------------------------------

			Set @sql = ''
			Set @sql = @sql + ' DELETE FROM [' + @DatabaseName + '].dbo.T_Process_Config'
			Set @sql = @sql + ' WHERE [Name] IN (''Organism_DB_File_Name'', ''Protein_Collection_Filter'')'
			Set @sql = @sql +       ' AND Value = ''<Fill In>'''
			
			Exec (@Sql)
    
		End
	End

   	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ConfigureOrganismDBFileFilters] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ConfigureOrganismDBFileFilters] TO [MTS_DB_Lite] AS [dbo]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RefreshLocalProteinTable]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RefreshLocalProteinTable]
GO


CREATE Procedure dbo.RefreshLocalProteinTable
/****************************************************
**
**	Desc: 
**		Updates local copy of the Protein table from 
**		associated Protein database.
**
**	Return values: 0: end of line not yet encountered
**
**	Parameters:
**
**		Auth: grk
**		Date: 12/18/2001
**
**		11/20/2003 added @noImport and function
**		04/08/2004 mem - Renamed @noImport to be @importAllProteins and updated logic accordingly
**						 Added check to validate that the ORF database exists
**		09/22/2004 mem - Replaced ORF references with Protein references
**		12/15/2004 mem - Updated to lookup the Protein DB ID in MT_Main and to record in the Protein_DB_ID column
**						 Updated to allow multiple Protein_DB_Name database entries in T_Process_Config
**		12/01/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**					   - Increased size of @ProteinDBName from 64 to 128 characters
**    
*****************************************************/
	@message varchar(512) = '' output,
	@infoOnly int = 0,
	@importAllProteins int = 1
As
	set nocount on 

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	declare @S nvarchar(2048)
	declare @DBIDString nvarchar(30)
	
	declare @continue int
	declare @result int
	declare @numAdded int

	set @result = 0
	set @numAdded = 0

	---------------------------------------------------
	-- Create the temporary table to hold the protein DB names and IDs
	---------------------------------------------------
	--
	CREATE TABLE #T_Protein_Database_List (
		ProteinDBName varchar(128) NOT NULL,
		ProteinDBID int NULL
	)

	---------------------------------------------------
	-- Get protein database name(s)
	---------------------------------------------------
	--
	INSERT INTO #T_Protein_Database_List (ProteinDBName)
	SELECT Value
	FROM T_Process_Config
	WHERE [Name] = 'Protein_DB_Name' AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount < 1
	begin
		set @message = 'No protein databases are defined in T_Process_Config'
		set @myError = 22
		goto Done
	end


	declare @ProteinDBName varchar(128)
	declare @ProteinDBID int
	declare @MissingProteinDB tinyint
	
	-- Loop through the protein database(s) and add or update the protein entries
	--

	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @ProteinDBName = ProteinDBName
		FROM #T_Protein_Database_List
		ORDER BY ProteinDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>

			-- Lookup the ODB_ID value for @ProteinDBName in MT_Main
			--
			Set @ProteinDBID = 0
			
			SELECT @ProteinDBID = ODB_ID
			FROM MT_Main.dbo.T_ORF_Database_List
			WHERE ODB_Name = @ProteinDBName
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			If @myRowCount = 0
				Set @MissingProteinDB = 1
			Else
				Set @MissingProteinDB = 0
			
			Set @DBIDString = Convert(nvarchar(25), @ProteinDBID)
			
			---------------------------------------------------
			-- Construct the Sql to populate T_Proteins
			---------------------------------------------------
			
			set @S = ''

			---------------------------------------------------
			-- add new entries
			---------------------------------------------------
			if @importAllProteins = 1
			begin
				--
				if @infoOnly = 0
				begin
					set @S = @S + 'INSERT INTO T_Proteins '
					set @S = @S + ' (Protein_ID, Reference, Protein_Sequence, Monoisotopic_Mass, Protein_DB_ID) '
				end
				--
				set @S = @S + ' SELECT '
				set @S = @S + '  P.ORF_ID, P.Reference, P.Protein_Sequence, P.Monoisotopic_Mass, ' + @DBIDString + ' AS Protein_DB_ID'
				set @S = @S + ' FROM '
				set @S = @S +   '[' + @ProteinDBName + '].dbo.T_ORF AS P LEFT OUTER JOIN '
				set @S = @S + '  T_Proteins ON P.Reference = T_Proteins.Reference '
				set @S = @S + ' WHERE T_Proteins.Reference IS NULL AND Protein_DB_ID IS NULL'

				exec @result = sp_executesql @S
				--
				select @myError = @result, @myRowcount = @@rowcount
				--
				if @myError  <> 0
				begin
					set @message = 'Could not add new Protein entries'
					set @myError = 24
					goto Done
				end
				
				set @numAdded = @numAdded + @myRowCount
			end


			if @infoOnly = 0 
			begin

				---------------------------------------------------
				-- update existing entries
				---------------------------------------------------
				set @S = ''

				set @S = @S + ' UPDATE T_Proteins '
				set @S = @S + ' SET '
				set @S = @S + '  Protein_ID = P.ORF_ID, Protein_Sequence = P.Protein_Sequence, '
				set @S = @S + '  Monoisotopic_Mass = P.Monoisotopic_Mass, Protein_DB_ID = ' + @DBIDString
				set @S = @S + ' FROM '
				set @S = @S + '  T_Proteins INNER JOIN '
				set @S = @S +    '[' + @ProteinDBName + '].dbo.T_ORF AS P ON '
				set @S = @S + '  T_Proteins.Reference = P.Reference AND'
				set @S = @S + '  IsNull(Protein_DB_ID, ' + @DBIDString + ') = ' + @DBIDString
				--
				exec @result = sp_executesql @S
				--
				select @myError = @result, @myRowcount = @@rowcount
				--
				if @myError  <> 0
				begin
					set @message = 'Could not update Protein entries'
					set @myError = 25
					goto Done
				end

				
				IF @myRowCount > 0 and @infoOnly = 0 And @MissingProteinDB = 1
				Begin
					-- New proteins were added, but the Protein DB was unknown
					-- Post an entry to the log, but do not return an error
					Set @message = 'Protein database ' + @ProteinDBName + ' was not found in MT_Main..T_ORF_Database_List; newly imported Proteins have been assigned a Protein_DB_ID value of 0'
					execute PostLogEntry 'Error', @message, 'RefreshLocalProteinTable'
					Set @message = ''
				End
			end
		
			DELETE FROM #T_Protein_Database_List
			WHERE ProteinDBName = @ProteinDBName
			
		End -- </b>
	End -- </a>


	set @message = 'Refresh local Protein reference table: ' +  convert(varchar(12), @numAdded)

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


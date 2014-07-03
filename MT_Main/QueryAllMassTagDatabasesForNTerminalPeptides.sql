/****** Object:  StoredProcedure [dbo].[QueryAllMassTagDatabasesForNTerminalPeptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure QueryAllMassTagDatabasesForNTerminalPeptides
/****************************************************
** 
**		Desc: Runs a query against all mass tag databases with MTL_State <= 10,
**		      storing the results in a table in this DB
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	08/25/2005
**			    11/23/2005 mem - Added brackets around @MTL_Name as needed to allow for DBs with dashes in the name
**				03/20/2006 mem - Added parameters @DBFilterList and @PopulateLocalTable
**				04/02/2009 mem - Updated query to obtain the peptide closest to the N-terminus of each protein
**    
*****************************************************/
(
	@DBsToProcess int = 0,					-- If this number is > 0, then only processes the first @DBsToProcess databases, ordered by MTL_ID
	@DBListToUse varchar(max) = '',			-- Databases to use; leave blank to use all DBs with state <= 10, skipping those defined by @DBsToSkip
	@DBsToSkip varchar(max) = '',			-- Databases to skip; ignored if @DBListToUse is defined
	@PopulateLocalTable tinyint = 0,
	@PreviewSql tinyint = 0,
	@message varchar(255) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int

	declare @MTL_Name varchar(64)
	declare @MTL_ID int
	set @MTL_ID = 0

	declare @done int
	declare @processCount int
	declare @Sql varchar(max)

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	-----------------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------------
	
	Set @DBsToProcess = IsNull(@DBsToProcess, 0)
	Set @DBListToUse = IsNull(@DBListToUse, '')
	Set @DBsToSkip = IsNull(@DBsToSkip, '')
	Set @PopulateLocalTable = IsNull(@PopulateLocalTable, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	Set @message = ''

	-----------------------------------------------------------
	-- Create the output table if it doesn't yet exist
	-- If it does exist, we will not delete it or re-create it
	-----------------------------------------------------------

	If @PreviewSql = 0 AND 
	   @PopulateLocalTable <> 0 AND 
	   Not Exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[T_Tmp_MTDB_NTermPeptides]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	Begin

		CREATE TABLE dbo.T_Tmp_MTDB_NTermPeptides (
			MTDB varchar(128) NOT NULL,
			Ref_ID int NOT NULL,
			Protein_Collection_ID int NULL,
			External_Protein_ID int NULL,
			Reference varchar(128) NOT NULL,
			Protein_Residue_Count int NULL,
			Protein_Mass float NULL,
			Residue_Start int NULL,
			Mass_Tag_ID int NOT NULL,
			Peptide varchar(300) NOT NULL,
			Monoisotopic_Mass float NULL,
			Peptide_Obs_Count_Passing_Filter int NULL,
			High_Normalized_Score real NULL,
			High_Peptide_Prophet_Probability real NULL,
			Mod_Count int NOT NULL,
			Mod_Description varchar(2048) NOT NULL,
			PMT_Quality_Score numeric(9, 5) NULL,
			Cleavage_State tinyint NULL,
			Terminus_State tinyint NULL,
			Missed_Cleavage_Count smallint NULL,
			PeptideWithExtra varchar(300) NULL,
			PepLengthRank int NULL,
			PepObsRank int NULL
		)
	
		-- Define a primary key using MTDB, Ref_ID, and Mass_Tag_ID,
		-- This will prevent duplicate results from being added to the table
		--  (which could happen if this procedure is run multiple times 
		--   without manually clearing the table between each run)

		ALTER TABLE dbo.T_Tmp_MTDB_NTermPeptides ADD 
			CONSTRAINT PK_T_Tmp_MTDB_NTermPeptides PRIMARY KEY CLUSTERED (MTDB, Ref_ID, Mass_Tag_ID)

		CREATE INDEX IX_T_Tmp_MTDB_NTermPeptides_MTDB_Mass_Tag_ID ON T_Tmp_MTDB_NTermPeptides (MTDB, Mass_Tag_ID)

	End
	
	-- Create a table to track the databases to process
	CREATE TABLE #DBsToProcess (
		MTL_Name varchar(128),
		MTL_ID int
	)


	-----------------------------------------------------------
	-- process each entry in T_MT_Database_List
	-----------------------------------------------------------

	Declare @DBListWhereClause varchar(max)
	Declare @SkipDBWhereClause varchar(max)

	Exec Prism_IFC.dbo.ConvertListToWhereClause @DBListToUse, 'MTL_Name', @entryListWhereClause = @DBListWhereClause OUTPUT
	Exec Prism_IFC.dbo.ConvertListToWhereClause @DBsToSkip, 'MTL_Name', @entryListWhereClause = @SkipDBWhereClause OUTPUT
	
	set @sql = ''
	Set @Sql = @Sql + ' INSERT INTO #DBsToProcess (MTL_Name, MTL_ID)'
	Set @Sql = @Sql + ' SELECT MTL_Name, MTL_ID'
	Set @Sql = @Sql + ' FROM T_MT_Database_List'

	If Len(@DBListToUse) > 0 
		Set @Sql = @Sql + ' WHERE (' + @DBListWhereClause + ')'
	Else
	Begin
		Set @Sql = @Sql + ' WHERE MTL_State <= 10'
		If Len(@SkipDBWhereClause) > 0
			Set @Sql = @Sql + ' AND NOT (' + @SkipDBWhereClause + ')'
	End
	
	Exec (@Sql)

	If @PreviewSql <> 0
	Begin
		Print @Sql
		select * FROM #DBsToProcess
	End


	set @done = 0
	set @processCount = 0

	While @done = 0 and @myError = 0  
	Begin -- <a>

		-----------------------------------------------------------
		-- get next available entry from mass tag database list table
		-----------------------------------------------------------
		--
		SELECT TOP 1 @MTL_Name = MTL_Name, @MTL_ID = MTL_ID
		FROM  #DBsToProcess
		WHERE MTL_ID > @MTL_ID
		ORDER BY MTL_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from MT DB table'
			set @myError = 39
			goto Done
		end
		
		-- We are done if we didn't find any more records
		--
		if @myRowCount = 0 OR (@DBsToProcess > 0 AND @ProcessCount >= @DBsToProcess)
			set @done = 1
		else
		Begin -- <b>

			-- Lookup the DB Schema Version
			--
			exec GetDBSchemaVersionByDBName @MTL_Name, @DBSchemaVersion output

			Set @processCount = @processCount + 1

			If @DBSchemaVersion >= 2
			Begin
				-- Grab data and place in T_Tmp_MTDB_NTermPeptides
				--
				Set @Sql = ''
				

				-- This first part of the query sets up a Common Table Expression (CTE)
				Set @Sql = @Sql + ' WITH SrcMTs (Mass_Tag_ID)'
				Set @Sql = @Sql + ' AS ('
				Set @Sql = @Sql +    ' SELECT Mass_Tag_ID'
				Set @Sql = @Sql +    ' FROM DATABASE..T_Mass_Tags MT'
				Set @Sql = @Sql +    ' WHERE IsNull(MT.Internal_Standard_Only, 0) = 0 AND '
				Set @Sql = @Sql +          ' (MT.PMT_Quality_Score >= 1 OR MT.High_Peptide_Prophet_Probability >= 0.99) AND'
				Set @Sql = @Sql +          ' MT.Peptide_Obs_Count_Passing_Filter >= 2 '
				Set @Sql = @Sql + ' )'

				If @PopulateLocalTable <> 0
				Begin
					-- Populate T_Tmp_MTDB_NTermPeptides
					Set @Sql = @Sql + ' INSERT INTO T_Tmp_MTDB_NTermPeptides (MTDB, Ref_ID, Protein_Collection_ID, External_Protein_ID, '
					Set @Sql = @Sql + ' Reference, Protein_Residue_Count, Protein_Mass, '
					Set @Sql = @Sql + ' Residue_Start, Mass_Tag_ID, Peptide, Monoisotopic_Mass, '
					Set @Sql = @Sql + ' Peptide_Obs_Count_Passing_Filter, High_Normalized_Score, '
					Set @Sql = @Sql + ' High_Peptide_Prophet_Probability, Mod_Count, '
					Set @Sql = @Sql + ' Mod_Description, PMT_Quality_Score, Cleavage_State, '
					Set @Sql = @Sql + ' Terminus_State, Missed_Cleavage_Count)'
				End
				-- Join together the Results from MinStartQ with T_Proteins, T_Mass_Tags, and T_Mass_Tag_to_Protein_Map
				Set @Sql = @Sql + ' SELECT ''' + @MTL_Name + ''', '
				Set @Sql = @Sql +       ' Prot.Ref_ID,'
				Set @Sql = @Sql +       ' Prot.Protein_Collection_ID,'
				Set @Sql = @Sql +       ' Prot.External_Protein_ID,'
				Set @Sql = @Sql +       ' Prot.Reference,'
				Set @Sql = @Sql +       ' Prot.Protein_Residue_Count,'
				Set @Sql = @Sql +       ' Prot.Monoisotopic_Mass AS Protein_Mass,'
				Set @Sql = @Sql +       ' MTPM.Residue_Start,'
				Set @Sql = @Sql +       ' MT.Mass_Tag_ID,'
				Set @Sql = @Sql +       ' MT.Peptide,'
				Set @Sql = @Sql +     ' MT.Monoisotopic_Mass,'
				Set @Sql = @Sql +      ' MT.Peptide_Obs_Count_Passing_Filter,'
				Set @Sql = @Sql +       ' MT.High_Normalized_Score,'
				Set @Sql = @Sql +       ' MT.High_Peptide_Prophet_Probability,'
				Set @Sql = @Sql +       ' MT.Mod_Count,'
				Set @Sql = @Sql +       ' MT.Mod_Description,'
				Set @Sql = @Sql +       ' MT.PMT_Quality_Score,'
				Set @Sql = @Sql +       ' MTPM.Cleavage_State,'
				Set @Sql = @Sql +       ' MTPM.Terminus_State,'
				Set @Sql = @Sql +       ' MTPM.Missed_Cleavage_Count'
				Set @Sql = @Sql + ' FROM DATABASE..T_Mass_Tag_to_Protein_Map MTPM'
				Set @Sql = @Sql +      ' INNER JOIN ( '  -- For each protein, find the residue position of the first confidently identified peptide
				Set @Sql = @Sql +                   ' SELECT MTPM.Ref_ID, MIN(MTPM.Residue_Start) AS Residue_Start_Min'
				Set @Sql = @Sql +                   ' FROM DATABASE..T_Mass_Tag_to_Protein_Map MTPM'
				Set @Sql = @Sql +                        ' INNER JOIN DATABASE..T_Proteins Prot '
				Set @Sql = @Sql +                          ' ON MTPM.Ref_ID = Prot.Ref_ID '
				Set @Sql = @Sql +                        ' INNER JOIN SrcMTs '
				Set @Sql = @Sql +                          ' ON MTPM.Mass_Tag_ID = SrcMTs.Mass_Tag_ID'
				Set @Sql = @Sql +                   ' WHERE NOT Prot.Reference LIKE ''Reversed%'''
				Set @Sql = @Sql +                   ' GROUP BY MTPM.Ref_ID '
				Set @Sql = @Sql +                 ' ) MinStartQ'
				Set @Sql = @Sql +         ' ON MTPM.Ref_ID = MinStartQ.Ref_ID AND'
				Set @Sql = @Sql +           ' MTPM.Residue_Start = MinStartQ.Residue_Start_Min'
				Set @Sql = @Sql +     ' INNER JOIN DATABASE..T_Proteins Prot'
				Set @Sql = @Sql +         ' ON MTPM.Ref_ID = Prot.Ref_ID'
				Set @Sql = @Sql +     ' INNER JOIN SrcMTs '
				Set @Sql = @Sql +         ' ON MTPM.Mass_Tag_ID = SrcMTs.Mass_Tag_ID'
				Set @Sql = @Sql +     ' INNER JOIN DATABASE..T_Mass_Tags MT'
				Set @Sql = @Sql +         ' ON MTPM.Mass_Tag_ID = MT.Mass_Tag_ID'
				    
				Set @Sql = Replace (@Sql, 'DATABASE..', '[' + @MTL_Name + ']..')
				
				If @PreviewSql <> 0
					Print @sql
				Else				
					Exec (@sql)
				
				-- Now populate the PeptideWithExtra column in T_Tmp_MTDB_NTermPeptides
				Set @Sql = ''
				Set @Sql = @Sql + ' UPDATE T_Tmp_MTDB_NTermPeptides'
				Set @Sql = @Sql + ' SET PeptideWithExtra = LookupQ.PeptideWithExtra'
				Set @Sql = @Sql + ' FROM T_Tmp_MTDB_NTermPeptides Target'
				Set @Sql = @Sql +      ' INNER JOIN ( '
				Set @Sql = @Sql +                    ' SELECT Pep.Mass_Tag_ID,'
				Set @Sql = @Sql +                           ' MIN(Pep.Peptide) AS PeptideWithExtra'
				Set @Sql = @Sql +                    ' FROM DATABASE..T_Peptides Pep'
				Set @Sql = @Sql +                    ' GROUP BY Pep.Mass_Tag_ID '
				Set @Sql = @Sql +                 ' ) LookupQ'
				Set @Sql = @Sql +          ' ON Target.Mass_Tag_ID = LookupQ.Mass_Tag_ID'
				Set @Sql = @Sql + ' WHERE Target.MTDB = ''' + @MTL_Name + ''''

				Set @Sql = Replace (@Sql, 'DATABASE..', '[' + @MTL_Name + ']..')
				
				If @PreviewSql <> 0
					Print @sql
				Else				
					Exec (@sql)
				
				
				-- Populate the PepLengthRank column
				-- This column will be 1 for the longest peptide identified for a given protein, 2 for the next longest peptide, etc.
				-- A protein can have two identified peptides that have the same start residue if the peptides have different modified residues
				
				UPDATE T_Tmp_MTDB_NTermPeptides
				SET PepLengthRank = PepRankQ.PepLengthRank
				FROM T_Tmp_MTDB_NTermPeptides NTermPeps
				     INNER JOIN ( SELECT MTDB,
				                         Ref_ID,
				                         Peptide,
				                         Rank() OVER ( PARTITION BY MTDB, Ref_ID 
				                                       ORDER BY Len(Peptide) DESC ) AS PepLengthRank
				                  FROM T_Tmp_MTDB_NTermPeptides NTermPeps ) PepRankQ
				       ON NTermPeps.MTDB = PepRankQ.MTDB AND
				          NTermPeps.Ref_ID = PepRankQ.Ref_ID AND
				          NTermPeps.Peptide = PepRankQ.Peptide

				-- Populate the PepObsRank column
				-- This columns will be 1 for the peptide with the highest Peptide_Obs_Count_Passing_Filter value for each protein
				
				UPDATE T_Tmp_MTDB_NTermPeptides
				SET PepObsRank = PepRankQ.PepObsRank
				FROM T_Tmp_MTDB_NTermPeptides NTermPeps
				     INNER JOIN ( SELECT MTDB,
				                         Ref_ID,
				                         Peptide,
				                         Rank() OVER ( PARTITION BY MTDB, Ref_ID 
				                                       ORDER BY Peptide_Obs_Count_Passing_Filter DESC ) AS PepObsRank
				                  FROM T_Tmp_MTDB_NTermPeptides NTermPeps ) PepRankQ
				       ON NTermPeps.MTDB = PepRankQ.MTDB AND
				          NTermPeps.Ref_ID = PepRankQ.Ref_ID AND
				          NTermPeps.Peptide = PepRankQ.Peptide

			End
		End -- </b>

		If @PreviewSql <> 0
			Set @ProcessCount = @DBsToProcess
	End -- </a>

Done:

	if @myError <> 0
		SELECT @message As Message
	else
		SELECT 'Done: Processed ' + Convert(varchar(9), @processCount) + ' databases' As Message

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[QueryAllMassTagDatabasesForNTerminalPeptides] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QueryAllMassTagDatabasesForNTerminalPeptides] TO [MTS_DB_Lite] AS [dbo]
GO

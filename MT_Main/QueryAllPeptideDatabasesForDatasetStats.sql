/****** Object:  StoredProcedure [dbo].[QueryAllPeptideDatabasesForDatasetStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.QueryAllPeptideDatabasesForDatasetStats
/****************************************************
** 
**		Desc: Runs a query against all peptide databases,
**		      storing the results in a table in this DB
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	03/20/2006
**    
*****************************************************/
(
	@MinimumDiscriminantScore real = 0.9,
	@MinimumPeptideCountPassingFilters int = 20,
	@DBsToProcess int = 0,						-- If this number is > 0, then only processes the first @DBsToProcess databases, ordered by PDB_ID
	@DBFilterList varchar(1024) = '',
	@DBsToSkip varchar(1024) = 'PT_Human_Reversed_A81, PT_Mouse_Reversed_A88, PT_R_Sphaeroides_Reversed_A82, PT_R_Sphaeroides_X77, PT_S_Typhimurium_Reversed_X92, PT_S_typhimurium_STOS_A78, PT_Shewanella_Reversed_X93, PT_S_typhimurium_A115',
	@PopulateLocalTable tinyint = 0,
	@message varchar(255) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int

	declare @PDB_Name varchar(64)
	declare @PDB_ID int
	set @PDB_ID = 0

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	-----------------------------------------------------------
	-- Create the output table
	-----------------------------------------------------------

	If @PopulateLocalTable <> 0 And Not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[T_Tmp_PeptideDB_Data]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	Begin
	--	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[T_Tmp_PeptideDB_Data]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	--		drop table [dbo].[T_Tmp_PeptideDB_Data]

		CREATE TABLE dbo.T_Tmp_PeptideDB_Data (
			PeptideDB varchar (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
			Organism_DB_Name varchar (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
			InstrumentClass varchar (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
			DatasetCount int NOT NULL,
			PeptideCount_Avg int NULL,
			PeptideCount_Min int NULL,
			PeptideCount_Max int NULL,
			PeptideCount_StDev int NULL
		)

		ALTER TABLE dbo.T_Tmp_PeptideDB_Data WITH NOCHECK ADD 
			CONSTRAINT [PK_T_Tmp_PeptideDB_Data] PRIMARY KEY  CLUSTERED (PeptideDB, Organism_DB_Name, InstrumentClass)
	End
	
	CREATE TABLE #DBsToProcess (
		PDB_Name varchar(128),
		PDB_ID int
	)


	-----------------------------------------------------------
	-- process each entry in T_Peptide_Database_List
	-----------------------------------------------------------
	declare @done int
	declare @processCount int
	declare @Sql varchar(2048)

	Declare @FilterDBWhereClause varchar(2048)
	Declare @SkipDBWhereClause varchar(2048)

	Exec Prism_IFC.dbo.ConvertListToWhereClause @DBFilterList, 'PDB_Name', @entryListWhereClause = @FilterDBWhereClause OUTPUT
	Exec Prism_IFC.dbo.ConvertListToWhereClause @DBsToSkip, 'PDB_Name', @entryListWhereClause = @SkipDBWhereClause OUTPUT
	
	set @sql = ''
	Set @Sql = @Sql + ' INSERT INTO #DBsToProcess (PDB_Name, PDB_ID)'
	Set @Sql = @Sql + ' SELECT PDB_Name, PDB_ID'
	Set @Sql = @Sql + ' FROM T_Peptide_Database_List'
	Set @Sql = @Sql + ' WHERE PDB_State <= 10'
	If Len(@FilterDBWhereClause) > 0
		Set @Sql = @Sql + ' AND ' + @FilterDBWhereClause
		
	If Len(@SkipDBWhereClause) > 0
		Set @Sql = @Sql + ' AND NOT ' + @SkipDBWhereClause
	
	Exec (@Sql)
	
	set @done = 0
	set @processCount = 0

	While @done = 0 and @myError = 0  
	Begin --<a>

		-----------------------------------------------------------
		-- get next available entry from peptide database list table
		-----------------------------------------------------------
		--
		SELECT TOP 1 @PDB_Name = PDB_Name, @PDB_ID = PDB_ID
		FROM  #DBsToProcess
		WHERE PDB_ID > @PDB_ID
		ORDER BY PDB_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from Peptide DB table'
			set @myError = 39
			goto Done
		end
		
		-- We are done if we didn't find any more records
		--
		if @myRowCount = 0 OR (@DBsToProcess > 0 AND @ProcessCount >= @DBsToProcess)
			set @done = 1
		else
		Begin

			-- Lookup the DB Schema Version
			--
			exec GetDBSchemaVersionByDBName @PDB_Name, @DBSchemaVersion output

			Set @processCount = @processCount + 1

			If @DBSchemaVersion >= 2
			Begin
				-- Grab data and optionally place in T_Tmp_PeptideDB_Data
				--
				Set @Sql = ''

				If @PopulateLocalTable <> 0
				Begin
					Set @Sql = @Sql + ' INSERT INTO T_Tmp_PeptideDB_Data (PeptideDB, Organism_DB_Name, InstrumentClass, DatasetCount,'
					Set @Sql = @Sql +                                   ' PeptideCount_Avg, PeptideCount_Min, PeptideCount_Max, PeptideCount_StDev)'
				End
				
				Set @Sql = @Sql + ' SELECT ''' + @PDB_Name + ''', Organism_DB_Name, InstrumentClass, '
				Set @Sql = @Sql +        ' COUNT(DISTINCT Dataset) AS DatasetCount,'
				Set @Sql = @Sql +        ' AVG(PeptideCount) AS PeptideCount_Avg, MIN(PeptideCount) AS PeptideCount_Min,'
				Set @Sql = @Sql +        ' MAX(PeptideCount) AS PeptideCount_Max, CONVERT(int, STDEV(PeptideCount)) AS PeptideCount_StDev'
				Set @Sql = @Sql + ' FROM ( SELECT TAD.Dataset, TAD.Job, TAD.Organism_DB_Name,'
				Set @Sql = @Sql +               ' CASE'
				Set @Sql = @Sql +                ' WHEN TAD.Instrument LIKE ''LCQ%'' THEN ''LCQ'''
				Set @Sql = @Sql +                ' WHEN TAD.Instrument LIKE ''LTQ_FT%'' THEN ''LTQ_FT''' 
				Set @Sql = @Sql +                ' WHEN TAD.Instrument LIKE ''%orb%'' THEN ''LTQ_Orb'''
				Set @Sql = @Sql +                ' WHEN TAD.Instrument LIKE ''LTQ%'' THEN ''LTQ''' 
				Set @Sql = @Sql +                ' WHEN TAD.Instrument LIKE ''Agilent%'' THEN ''Agilent_Ion_Trap'''
				Set @Sql = @Sql +                ' ELSE TAD.Instrument'
				Set @Sql = @Sql +               ' END AS InstrumentClass,'
				Set @Sql = @Sql +               ' COUNT(*) AS PeptideCount'
				Set @Sql = @Sql +        ' FROM  DATABASE..T_Analysis_Description TAD INNER JOIN'
				Set @Sql = @Sql +              ' DATABASE..T_Peptides P ON TAD.Job = P.Analysis_ID INNER JOIN'
				Set @Sql = @Sql +              ' DATABASE..T_Peptide_Filter_Flags PFF ON P.Peptide_ID = PFF.Peptide_ID INNER JOIN'
				Set @Sql = @Sql +              ' DATABASE..T_Score_Discriminant DS ON P.Peptide_ID = DS.Peptide_ID'
				Set @Sql = @Sql +        ' WHERE TAD.ResultType LIKE ''%peptide_hit'' AND PFF.Filter_ID = 117 AND'
				Set @Sql = @Sql +              ' DS.DiscriminantScoreNorm >= ' + Convert(varchar(9), @MinimumDiscriminantScore)
				Set @Sql = @Sql +        ' GROUP BY TAD.Dataset, TAD.Job, TAD.Organism_DB_Name, TAD.Instrument'
				Set @Sql = @Sql +      ' ) LookupQ'
				Set @Sql = @Sql + ' WHERE PeptideCount >= ' + Convert(varchar(9), @MinimumPeptideCountPassingFilters)
				Set @Sql = @Sql + ' GROUP BY Organism_DB_Name, InstrumentClass'
				
				Set @Sql = Replace (@Sql, 'DATABASE..', '[' + @PDB_Name + ']..')
				
				Exec (@sql)
			End
		End

	End --<a>

Done:

	if @myError <> 0
		SELECT @message As Message
	else
		SELECT 'Done: Processed ' + Convert(varchar(9), @processCount) + ' databases' As Message

	return @myError

GO

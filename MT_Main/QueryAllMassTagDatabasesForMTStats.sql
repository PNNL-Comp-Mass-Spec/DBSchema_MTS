/****** Object:  StoredProcedure [dbo].[QueryAllMassTagDatabasesForMTStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.QueryAllMassTagDatabasesForMTStats
/****************************************************
** 
**		Desc: Runs a query against all mass tag databases,
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
**    
*****************************************************/
(
	@MinimumDiscriminantScore real = 0.9,
	@DBsToProcess int = 0,						-- If this number is > 0, then only processes the first @DBsToProcess databases, ordered by MTL_ID
	@DBFilterList varchar(1024) = '',
	@DBsToSkip varchar(1024) = 'MT_Mixed_P191, MT_Shewanella_X202, MT_S_Typhimurium_X245',
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

	declare @MTL_Name varchar(64)
	declare @MTL_ID int
	set @MTL_ID = 0

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0


	-----------------------------------------------------------
	-- Create the output table
	-----------------------------------------------------------

	If @PopulateLocalTable <> 0 And Not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[T_Tmp_MTDB_Data]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	Begin
	--	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[T_Tmp_MTDB_Data]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	--		drop table [dbo].[T_Tmp_MTDB_Data]

		CREATE TABLE dbo.T_Tmp_MTDB_Data (
			MTDB varchar (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
			Mass_Tag_ID int NOT NULL ,
			Monoisotopic_Mass float NULL ,
			High_Discriminant_Score real NULL ,
			Avg_GANET real NULL ,
			StD_GANET real NULL ,
			Cnt_GANET int NULL ,
			PNET real NULL ,
			Max_Cleavage_State tinyint NULL 
		)

		ALTER TABLE [dbo].[T_Tmp_MTDB_Data] WITH NOCHECK ADD 
			CONSTRAINT [PK_T_Tmp_MTDB_Data] PRIMARY KEY  CLUSTERED (MTDB, Mass_Tag_ID)
	End
	
	CREATE TABLE #DBsToProcess (
		MTL_Name varchar(128),
		MTL_ID int
	)


	-----------------------------------------------------------
	-- process each entry in T_MT_Database_List
	-----------------------------------------------------------
	declare @done int
	declare @processCount int
	declare @Sql varchar(2048)

	Declare @FilterDBWhereClause varchar(2048)
	Declare @SkipDBWhereClause varchar(2048)

	Exec Prism_IFC.dbo.ConvertListToWhereClause @DBFilterList, 'MTL_Name', @entryListWhereClause = @FilterDBWhereClause OUTPUT
	Exec Prism_IFC.dbo.ConvertListToWhereClause @DBsToSkip, 'MTL_Name', @entryListWhereClause = @SkipDBWhereClause OUTPUT
	
	set @sql = ''
	Set @Sql = @Sql + ' INSERT INTO #DBsToProcess (MTL_Name, MTL_ID)'
	Set @Sql = @Sql + ' SELECT MTL_Name, MTL_ID'
	Set @Sql = @Sql + ' FROM T_MT_Database_List'
	Set @Sql = @Sql + ' WHERE MTL_State IN (1,2,5)'
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
		Begin

			-- Lookup the DB Schema Version
			--
			exec GetDBSchemaVersionByDBName @MTL_Name, @DBSchemaVersion output

			Set @processCount = @processCount + 1

			If @DBSchemaVersion >= 2
			Begin
				-- Grab data and place in T_Tmp_MTDB_Data
				--
				Set @Sql = ''
				
				If @PopulateLocalTable <> 0
				Begin
					Set @Sql = @Sql + ' INSERT INTO T_Tmp_MTDB_Data (MTDB, Mass_Tag_ID, Monoisotopic_Mass, High_Discriminant_Score,'
					Set @Sql = @Sql +                              ' Avg_GANET, StD_GANET, Cnt_GANET, PNET, Max_Cleavage_State)'
				End
				Set @Sql = @Sql + ' SELECT ''' + @MTL_Name + ''', MT.Mass_Tag_ID, MT.Monoisotopic_Mass, MT.High_Discriminant_Score,'
				Set @Sql = @Sql +          ' MTN.Avg_GANET, MTN.StD_GANET, MTN.Cnt_GANET, MTN.PNET, MAX(MTPM.Cleavage_State) AS Max_Cleavage_State'
				Set @Sql = @Sql + ' FROM DATABASE..T_Mass_Tags MT INNER JOIN'
				Set @Sql = @Sql +      ' DATABASE..T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID INNER JOIN'
				Set @Sql = @Sql +      ' DATABASE..T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
				Set @Sql = @Sql + ' WHERE MT.High_Discriminant_Score >= ' + Convert(varchar(9), @MinimumDiscriminantScore) + ' AND NOT MTN.Avg_GANET Is Null'
				Set @Sql = @Sql + ' GROUP BY MT.Mass_Tag_ID, MT.Monoisotopic_Mass, MT.High_Discriminant_Score, '
				Set @Sql = @Sql +          ' MTN.Avg_GANET, MTN.StD_GANET, MTN.Cnt_GANET, MTN.PNET'

				Set @Sql = Replace (@Sql, 'DATABASE..', '[' + @MTL_Name + ']..')
				
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
GRANT VIEW DEFINITION ON [dbo].[QueryAllMassTagDatabasesForMTStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QueryAllMassTagDatabasesForMTStats] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[GenerateMergeStatement] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[GenerateMergeStatement]
/****************************************************
**
**	Desc: Creates a Merge statement for the specified table
**        Does not actually perform the merge, just generates the code required to do so
**        Intended for use when you need to add a merge statement to a stored procedure
**
**        Modeled after code from http://weblogs.sqlteam.com/billg/archive/2011/02/15/generate-merge-statements-FROM-a-table.aspx
**
**	Auth:	mem
**	Date:	10/26/2015 mem - Initial version
**	        10/27/2015 mem - Add @includeCreateTableSql
**    
*****************************************************/
(
	@tableName varchar(128),
	@sourceDatabase varchar(128) = 'SourceDBName',
	@includeDeleteTest tinyint = 1,
	@includeActionSummary tinyint = 1,
	@includeCreateTableSql tinyint = 1,		-- When @includeActionSummary is non-zero, includes the T-Sql for creating table #Tmp_SummaryOfChanges
	@message varchar(512) = '' output
)
As
	
	set nocount on

	Declare @myError int
	Declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @newLine varchar(2) = Char(13) + Char(10)
	
	Set @tableName = IsNull(@tableName, '')
	Set @sourceDatabase = IsNull(@sourceDatabase, '')
	Set @includeDeleteTest = IsNull(@includeDeleteTest, 1)
	Set @includeActionSummary = IsNull(@includeActionSummary, 1)
	Set @includeCreateTableSql = IsNull(@includeCreateTableSql, 1)
	Set @message = ''

	If @tableName = ''
	Begin
		Set @message = '@tableName cannot be empty'
		PRINT @message
		Goto Done
	End

	If @sourceDatabase = ''
	Begin
		Set @message = '@sourceDatabase cannot be empty'
		PRINT @message
		Goto Done
	End
	
	---------------------------------------------------
	-- Validate the table name
	---------------------------------------------------

	If Not Exists (Select * FROM sys.columns WHERE object_id = object_id(@tableName))
	Begin
		Set @message = 'Cannot generate a merge statement for ' + @tableName + ': Table not found'
		PRINT @message
		Goto Done
	End

	---------------------------------------------------
	-- Populate a table with list of data types that we can compare
	---------------------------------------------------
	
	Declare @PrimaryKeyColumns TABLE  (ColumnName varchar(255) NOT NULL, user_type_id int not NULL, IsNumberCol tinyint NOT NULL, IsDateCol tinyint NOT NULL)
	Declare @UpdatableColumns TABLE  (ColumnName varchar(255) NOT NULL, user_type_id int not NULL, is_nullable tinyint NOT NULL)
	Declare @InsertableColumns TABLE (ColumnName varchar(255) NOT NULL)
	
	Declare @Types TABLE (user_type_id int not NULL, [IsNumber] tinyint NOT null, [IsDate] tinyint NOT null)

	INSERT Into @Types Values (36, 0, 0)  -- uniqueidentifier; compatible with IsNull(ColumnName, '')
	INSERT Into @Types Values (167, 0, 0) -- varchar
	INSERT Into @Types Values (175, 0, 0) -- char
	INSERT Into @Types Values (231, 0, 0) -- nvarchar
	INSERT Into @Types Values (239, 0, 0) -- nchar
	INSERT Into @Types Values (241, 0, 0) -- XML; Note: cannot be compared using the ISNULL(NULLIF()) test used below

	INSERT Into @Types VALUES(40, 0, 1)  -- date
	INSERT Into @Types VALUES(41, 0, 1)  -- time
	INSERT Into @Types VALUES(42, 0, 1)  -- datetime2
	INSERT Into @Types VALUES(58, 0, 1)  -- smalldatetime
	INSERT Into @Types VALUES(61, 0, 1)  -- datetime

	INSERT Into @Types Values (48, 1, 0)  -- tinyint
	INSERT Into @Types Values (52, 1, 0)  -- smallint
	INSERT Into @Types Values (56, 1, 0)  -- int
	INSERT Into @Types Values (59, 1, 0)  -- real
	INSERT Into @Types Values (60, 1, 0)  -- money
	INSERT Into @Types Values (62, 1, 0)  -- float
	INSERT Into @Types Values (104, 1, 0) -- bit
	INSERT Into @Types Values (106, 1, 0) -- decimal
	INSERT Into @Types Values (108, 1, 0) -- numeric
	INSERT Into @Types Values (122, 1, 0) -- smallmoney
	INSERT Into @Types Values (127, 1, 0) -- bigint

	---------------------------------------------------
	-- Include Action Summary statements if specified
	---------------------------------------------------

	If @includeActionSummary <> 0
	Begin
		If @includeCreateTableSql <> 0
		Begin
			Print 'Create Table #Tmp_SummaryOfChanges ('
			Print '    TableName varchar(128),'
			Print '    UpdateAction varchar(20),'
			Print '    InsertedKey varchar(128),'
			Print '    DeletedKey varchar(128)'
			Print ')'
			Print ''
			Print 'Declare @tableName varchar(128)'
			Print 'Set @tableName = ''' + @tableName + ''''
			Print ''
		End
		
		Print 'Truncate Table #Tmp_SummaryOfChanges'
	End

	---------------------------------------------------
	-- Turn identity insert off for tables with identities
	---------------------------------------------------
	
	Declare @TableHasIdentity int = objectproperty(object_id(@tableName), 'TableHasIdentity')
	
	If @TableHasIdentity = 1
	Begin
		PRINT 'SET IDENTITY_INSERT [dbo].[' + @tableName + '] ON;'		
	End
	
	---------------------------------------------------
	-- Construct the merge statment
	---------------------------------------------------

	Declare @list varchar(max) = ''

	Print ''
	PRINT 'MERGE [dbo].[' + @tableName + '] AS t'
	PRINT 'USING (SELECT * FROM [' + @sourceDatabase + '].[dbo].[' + @tableName + ']) as s'

	-- Lookup the names of the primary key columns
	INSERT INTO @PrimaryKeyColumns (ColumnName, user_type_id, IsNumberCol, IsDateCol)
	SELECT C.[name],
		C.user_type_id,
		T.[IsNumber],
		T.[IsDate]
	FROM sys.columns C
		INNER JOIN @Types T
		  ON C.user_type_id = T.user_type_id
		INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk
		  ON pk.TABLE_NAME = @tableName AND
			  pk.CONSTRAINT_TYPE = 'PRIMARY KEY'
		INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE KeyCol
		  ON KeyCol.TABLE_NAME = pk.TABLE_NAME AND
			  keycol.COLUMN_NAME = C.[name] AND
			  KeyCol.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
	WHERE C.object_id = object_id(@tableName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If Not Exists (Select * From @PrimaryKeyColumns)
	Begin
		Set @message = 'Cannot generate a merge statement for ' + @tableName + ' because it does not have a primary key'
		PRINT @message
		Goto Done
	End

	-- Use the primary key(s) to define the column(s) to join on
	--
	SET @list = ''
	
	SELECT @list = @list + 't.[' + ColumnName + '] = s.[' + ColumnName + '] AND '
	FROM @PrimaryKeyColumns

	-- Remove the trailing "AND"
	--
	SELECT @list =  LEFT(@list, LEN(@list) - 4)
	PRINT 'ON ( ' + @list + ')'


	-- Find the updatable columns (those that are not primary keys, identity columns, computed columns, or timestamp columns)
	--
	INSERT INTO @UpdatableColumns (ColumnName, user_type_id, is_nullable)
	SELECT [name], user_type_id, is_nullable
	FROM sys.columns
	WHERE object_id = object_id(@tableName) AND
	      [name] NOT IN ( SELECT ColumnName FROM @PrimaryKeyColumns) AND
	      is_identity = 0 AND     -- Identity column
	      is_computed = 0 AND     -- Computed column
	      user_type_id <> 189     -- Timestamp column
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If Not Exists (Select * from @UpdatableColumns)
	Begin
		PRINT '-- Note: all of the columns in table ' + @tableName + ' are primary keys or identity columns; there are no updatable columns'
	End
	Else
	Begin -- <UpdateMatchingRows>
	      
		---------------------------------------------------
		-- Sql for updating when rows match
		-- Do not update primary keys or identity columns
		---------------------------------------------------
		--
		PRINT 'WHEN MATCHED AND ('
			
		---------------------------------------------------
		-- Sql to determine if matched rows have different values
		--
		-- Comparison option #1 (misses edge cases where either value is null and the other is 0)
		--  WHERE ((IsNull(Source.ColumnA, 0) <> IsNull(Target.ColumnA, 1))) OR
		--        ((IsNull(Source.ColumnA, 'BogusNonWordValue12345') <> IsNull(Target.ColumnA, 'BogusNonWordValue67890')))
		--
		-- Comparison option #2 (contributed by WileCau at http://stackoverflow.com/questions/1075142/how-to-compare-values-which-may-both-be-null-is-t-sql )
		--  NullIf returns Null if the two values are equal, or returns the first value if the fields are not equal
		--  This expression is a bit hard to follow, but it's a compact way to compare two fields to see if they are equal
		--
		--  WHERE ISNULL(NULLIF(Target.Field1, Source.Field1),
		--               NULLIF(Source.Field1, Target.Field1)
		--         ) IS NOT NULL
		---------------------------------------------------
		
		Declare @WhereListA varchar(max) = ''
		Declare @WhereListB varchar(max) = ''

		-- Compare the non-nullable columns
		--
		SELECT @WhereListA = @WhereListA + '    t.[' + [ColumnName] +  '] <> s.[' + [ColumnName] +'] OR' + @newLine
		FROM @UpdatableColumns
		WHERE is_nullable = 0 AND
			  user_type_id <> 241   -- Exclude XML columns
		

		-- Compare the nullable columns
		--	
		SELECT @WhereListB = @WhereListB + '    ISNULL( NULLIF(t.[' + [ColumnName] +  '], s.[' + [ColumnName] +']),' + @newLine
										 + '            NULLIF(s.[' + [ColumnName] +'], t.[' + [ColumnName] +  '])) IS NOT NULL OR' + @newLine
		FROM @UpdatableColumns C
			INNER JOIN @Types T
			ON C.user_type_id = T.user_type_id
		WHERE C.is_nullable <> 0 AND
			  C.user_type_id <> 241   -- Exclude XML columns

		-- Compare XML columns
		--
		SELECT @WhereListB = @WhereListB + '    ISNULL(Cast(t.[' + [ColumnName] + '] AS varchar(max)), '''') <>' + 
										   '    ISNULL(Cast(s.[' + [ColumnName] + '] AS varchar(max)), '''') OR' + @newLine
		FROM @UpdatableColumns C
			INNER JOIN @Types T
			ON C.user_type_id = T.user_type_id
		WHERE C.user_type_id = 241
		
		-- Remove the trailing OR's
		If @WhereListA <> ''
			Set @WhereListA = Left(@WhereListA, Len(@WhereListA) - 5)
		
		If @WhereListB <> ''
			Set @WhereListB = Left(@WhereListB, Len(@WhereListB) - 5)

		If @WhereListA <> '' And @WhereListB <> ''
		Begin
			PRINT @WhereListA + ' OR' + @newline + @WhereListB
		End
		Else
		Begin
			If @WhereListA <> ''
				PRINT @WhereListA
			Else
				PRINT @WhereListB
		End

		PRINT '    )'

		-- Sql that actually updates the data
		--
		SELECT @list = '';
		SELECT @list = @list + '    [' + [ColumnName] +  '] = s.[' + [ColumnName] +'],' + @newLine
		FROM @UpdatableColumns

		-- Remove the trailing comma
		PRINT 'THEN UPDATE SET ' + @newLine + left(@list, len(@list) - 3)
	
	End -- </UpdateMatchingRows>
	
	
	---------------------------------------------------
	-- Sql for inserting new rows
	---------------------------------------------------
	--
	PRINT 'WHEN NOT MATCHED BY TARGET THEN';

	INSERT INTO @InsertableColumns (ColumnName)
	SELECT [name]
	FROM sys.columns
	WHERE object_id = object_id(@tableName) AND
	      is_computed = 0 AND     -- Computed column
	      user_type_id <> 189     -- Timestamp column

	If Not Exists (Select * from @InsertableColumns)
	Begin
		Set @message = 'Error: table ' + @tableName + ' does not have any columns compatible with a merge statement'
		PRINT @message
		Goto Done
	End
	
	
	SET @list = ''
	SELECT @list = @list + '[' + ColumnName +'], '
	FROM @InsertableColumns

	-- Remove the trailing comma
	SELECT @list = LEFT(@list, LEN(@list) - 1)

	PRINT '    INSERT(' + @list + ')'

	SET @list = ''
	SELECT @list = @list + 's.[' + ColumnName +'], '
	FROM @InsertableColumns

	-- Remove the trailing comma
	SELECT @list = LEFT(@list, LEN(@list) - 1)

	PRINT '    VALUES(' + @list + ')'

	---------------------------------------------------
	-- Sql for deleting extra rows
	---------------------------------------------------
	--
	If @includeDeleteTest = 0
		PRINT 'WHEN NOT MATCHED BY SOURCE THEN DELETE'
	Else
		PRINT 'WHEN NOT MATCHED BY SOURCE And @DeleteExtras <> 0 THEN DELETE'

	If @includeActionSummary = 0
		PRINT ';'
	Else
	Begin -- <ActionSummaryTable>
	
		---------------------------------------------------
		-- Sql to populate the action summary table
		---------------------------------------------------
		--
		PRINT 'OUTPUT @tableName, $action,'
		
		Declare @continue tinyint = 1
		Declare @CurrentColumn varchar(128) = ''
		Declare @IsNumberColumn tinyint
		Declare @IsDateColumn tinyint
		
		Declare @InsertedList varchar(1024) = ''
		Declare @DeletedList varchar(1024) = ''
		Declare @castCharCount varchar(2)

		---------------------------------------------------
		-- Loop through the the list of primary keys
		---------------------------------------------------
		--
		While @continue = 1
		Begin -- <IteratePrimaryKeys>
		
			SELECT Top 1 @CurrentColumn = ColumnName,
			             @IsNumberColumn = IsNumberCol,
			             @IsDateColumn = IsDateCol
			FROM @PrimaryKeyColumns
			WHERE ColumnName > @CurrentColumn
			ORDER BY ColumnName
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount = 0
				Set @continue = 0
			Else
			Begin -- <UpdateInsertdDeletedLists>

				If @InsertedList <> '' 
				Begin
					-- Concatenate updated values
					--
					Set @InsertedList = @InsertedList + ' + '', '' + '
					Set @DeletedList  = @DeletedList  + ' + '', '' + '
				End
				
				If @IsNumberColumn = 0 And @IsDateColumn = 0
				Begin
					-- Text column
					--
					Set @InsertedList = @InsertedList + 'Inserted.[' + @CurrentColumn + ']'
					Set @DeletedList =  @DeletedList +  'Deleted.['  + @CurrentColumn + ']'
				End
				Else
				Begin					
					-- Number or Date column
					--
										
					If @IsDateColumn = 0
						Set @castCharCount = '12'  -- varchar(12)
					Else
						Set @castCharCount = '32'  -- varchar(32)
						
					Set @InsertedList = @InsertedList + 'Cast(Inserted.[' + @CurrentColumn + '] as varchar(' + @castCharCount + '))'
					Set @DeletedList =  @DeletedList +  'Cast(Deleted.['  + @CurrentColumn + '] as varchar(' + @castCharCount + '))'
				End
				
			End -- </UpdateInsertdDeletedLists>
			
		End -- </IteratePrimaryKeys>

		PRINT '       ' + @InsertedList + ','
		PRINT '       ' + @DeletedList
		PRINT '       INTO #Tmp_SummaryOfChanges;'

		PRINT '--'
		PRINT 'SELECT @myError = @@error, @myRowCount = @@rowcount'
		PRINT ''
		
	End -- </ActionSummaryTable>
	
	---------------------------------------------------
	-- Turn identity insert back on for tables with identities
	---------------------------------------------------
		
	If @TableHasIdentity = 1 
		PRINT 'SET IDENTITY_INSERT [dbo].[' + @tableName + '] OFF;' + @newLine

	
Done:
	return 0


GO

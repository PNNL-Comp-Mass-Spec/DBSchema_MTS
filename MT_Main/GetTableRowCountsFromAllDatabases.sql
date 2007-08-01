/****** Object:  StoredProcedure [dbo].[GetTableRowCountsFromAllDatabases] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE GetTableRowCountsFromAllDatabases
/****************************************************
** 
**	Desc: Returns the table row counts for the specific table
**		      in all databases of the given type
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	02/18/2006
**    
*****************************************************/
(
	@DBType varchar(128) = '0',					-- 0 for PT and MT Databases, 1 for PT Databases, 2 for MT Databases
	@TableName varchar(64) = 'T_Peptides',
	@OrderByName tinyint = 0,					-- 0 to order by TableRowCount, 1 to order by DBName
	@message varchar(256)='' OUTPUT
)
As
	Set nocount on
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	Declare @DBName varchar(128)
	Declare @Matchcount int
	Declare @Sql varchar(2048)
	Declare @DBTypeCurrent int
	Declare @DBsProcessed int
	
	-- Validate @DBType
	Set @DBType = IsNull(@DBType, 0)
	
	CREATE TABLE #DBJobStats (
		DBName varchar(128),
		TableRowCount int
	)

	Set @DBsProcessed = 0

	If @DBType = 0
		Set @DBTypeCurrent = 1
	Else
		Set @DBTypeCurrent = @DBType
	
	While @DBTypeCurrent <= 2
	Begin

		Set @DBName = ''
		Set @Matchcount = 1
		
		While @Matchcount = 1
		Begin
			Set @Matchcount = 0

			If @DBTypeCurrent = 1
			Begin
				SELECT TOP 1 @DBName = PDB_Name	
				FROM T_Peptide_Database_List
				WHERE PDB_State < 10 AND PDB_Name > @DBName
				--
				SELECT @Matchcount = @@Rowcount, @myError = @@Error
				--
				If @myError <> 0
				Begin
					Set @Message = 'Error querying T_Peptide_Database_List; Error code = ' + Convert(varchar(12), @myError)
					Goto Done
				End
			End
			Else
				If @DBTypeCurrent = 2
				Begin
					SELECT TOP 1 @DBName = MTL_Name	
					FROM T_MT_Database_List
					WHERE MTL_State < 10 AND MTL_Name > @DBName
					--
					SELECT @Matchcount = @@Rowcount, @myError = @@Error
					--
					If @myError <> 0
					Begin
						Set @Message = 'Error querying T_MT_Database_List; Error code = ' + Convert(varchar(12), @myError)
						Goto Done
					End
				End

			If @Matchcount = 1
			Begin
				Set @Sql = ''
				Set @Sql = @Sql + ' INSERT INTO #DBJobStats(DBName, TableRowCount)'
				Set @Sql = @Sql + ' SELECT ''' + @DBName + ''' As ThisDB, TableRowCount'
				Set @Sql = @Sql + ' FROM [' + @DBName + '].dbo.V_Table_Row_Counts'
				Set @Sql = @Sql + ' WHERE Tablename = ''' + @TableName + ''''
				
				exec (@Sql)
				Set @DBsProcessed = @DBsProcessed + 1
				print @DBName
				
			End
		End

		If @DBType = 0
			Set @DBTypeCurrent = @DBTypeCurrent + 1
		Else
			Set @DBTypeCurrent = 100		-- This will exit the loop		
	End

ShowResults:
	If @OrderByName = 1
		SELECT * FROM #DBJobStats order by DBName
	Else
		SELECT * FROM #DBJobStats order by tablerowcount desc
		
	DROP Table #DBJobStats

Done:
	Return @myError
	
GO

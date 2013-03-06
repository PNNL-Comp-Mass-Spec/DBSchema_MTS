Declare @ObjectId int = 0
Declare @Table varchar(256)
Declare @continue tinyint= 1
Declare @S varchar(1024)

CREATE TABLE #Tmp_Results (
    TableName varchar(256) NOT NULL,
    TotalRows int NOT NULL
)
	
While @Continue = 1
Begin
	SELECT TOP 1 @ObjectID = [Object_id],
	             @Table = name
	FROM sys.tables
	WHERE [Object_ID] > @ObjectID
	ORDER BY [Object_ID]
	
	If @@RowCount = 0
		Set @Continue = 0
	Else
	Begin
		Print 'Process table ' + @Table
		
		Set @S = ''
		Set @S = @S + ' INSERT INTO #Tmp_Results (TableName, TotalRows)'
		Set @S = @S + ' SELECT ''' + @Table + ''' as TableName, COUNT(*) as TotalRows'
		Set @S = @S + ' FROM [' + @Table + ']'
		
		Exec (@S)
	End
End

SELECT *
FROM #Tmp_Results
ORDER BY TableName

DROP TABLE #Tmp_Results

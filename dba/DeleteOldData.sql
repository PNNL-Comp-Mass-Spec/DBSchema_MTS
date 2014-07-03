/****** Object:  StoredProcedure [dbo].[DeleteOldData] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE DeleteOldData
/****************************************************
**
**	Desc: 
**		Deletes old data from the various tables in the dba database
**
**	Auth:	mem
**	Date:	06/28/2013 mem - Initial release
**			04/01/2014 mem - Now calling DeleteOldQueryStats
**    
*****************************************************/
(
	@infoOnly tinyint = 1,				-- 1 to preview changes, 0 to delete old data
	@BlockingHistoryMonthsToRetain tinyint = 1,
	@QueryHistoryMonthsToRetain tinyint = 1,
	@JobStatsHistoryMonthsToRetain tinyint = 1,
	@QueryStatsMonthsToRetain tinyint = 3,
	@QueryStatsExpensiveMonthsToRetain tinyint = 15,
	@message varchar(1024) = ''
)
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set @message = ''
	
	Set @BlockingHistoryMonthsToRetain     = IsNull(@BlockingHistoryMonthsToRetain, 1)
	Set @QueryHistoryMonthsToRetain        = IsNull(@QueryHistoryMonthsToRetain, 1)
	Set @JobStatsHistoryMonthsToRetain     = IsNull(@JobStatsHistoryMonthsToRetain, 1)
	Set @QueryStatsMonthsToRetain          = IsNull(@QueryStatsMonthsToRetain, 3)
	Set @QueryStatsExpensiveMonthsToRetain = IsNull(@QueryStatsExpensiveMonthsToRetain, 15)		

	If @BlockingHistoryMonthsToRetain < 1
		Set @BlockingHistoryMonthsToRetain = 1

	If @QueryHistoryMonthsToRetain < 1
		Set @QueryHistoryMonthsToRetain = 1
		
	If @JobStatsHistoryMonthsToRetain < 1
		Set @JobStatsHistoryMonthsToRetain = 1

	If @QueryStatsMonthsToRetain < 1
		Set @QueryStatsMonthsToRetain = 1

	If @QueryStatsExpensiveMonthsToRetain < 6
		Set @QueryStatsExpensiveMonthsToRetain = 6
		
	---------------------------------------------------
	-- Create a temporary table to hold the dba tables to cleanup
	---------------------------------------------------
	--
	Create Table #Tmp_Table_Stats
	(
		Entry_ID int identity(1,1) primary key,
		SourceTable varchar(128) NOT NULL,
		DateStampColName varchar(32) NOT NULL,
		MonthsToRetain int NOT NULL,
		RowsToKeep int NULL,
		RowsToDelete int NULL
	)


	---------------------------------------------------
	-- Add the names of the tables, the name of the datestamp column, 
	-- and the number of months of data to retain
	---------------------------------------------------
	--	
	INSERT INTO #Tmp_Table_Stats (SourceTable, DateStampColName, MonthsToRetain)
	VALUES ('BlockingHistory',    'DateStamp',          @BlockingHistoryMonthsToRetain), 
	       ('QueryHistory',       'DateStamp',          @QueryHistoryMonthsToRetain),
	       ('JobStatsHistory',    'JobStatsDateStamp',  @JobStatsHistoryMonthsToRetain),
	       ('FileStatsHistory',   'FileStatsDateStamp', 6),
	       ('CPUStatsHistory',    'DateStamp',          12),
	       ('MemoryUsageHistory', 'DateStamp',          12),
	       ('PerfStatsHistory',   'StatDate',           12),
	       ('HealthReport',       'DateStamp',          12)


	---------------------------------------------------
	-- Process each table in #Tmp_Summary
	---------------------------------------------------
	--
	Declare @Continue tinyint
	Declare @EntryID int = 0
	Declare @SourceTable varchar(128)
	Declare @DateStampColName varchar(32)
	Declare @MonthsToRetain int
	Declare @RowsToKeep int
	Declare @RowsToDelete int
	       
	Declare @S nvarchar(1024)
	Declare @params nvarchar(512)

	Set @Continue = 1
	While @continue = 1
	Begin
		SELECT TOP 1 @EntryID = Entry_ID,
		             @SourceTable = SourceTable,
		             @DateStampColName = DateStampColName,
		             @MonthsToRetain = MonthsToRetain
		FROM #Tmp_Table_Stats
		WHERE Entry_ID > @EntryID
		ORDER BY Entry_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--

		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin
			Set @S = ''
			Set @S = @S + ' SELECT @Count = COUNT(*)'
			Set @S = @S + ' FROM [' + @SourceTable + ']'
			Set @S = @S + ' WHERE [' + @DateStampColName + '] < DATEADD(month, -' + Convert(varchar(4), @MonthsToRetain) + ', GETDATE())'
		
			Set @params = '@Count int output'
			
			Exec sp_executeSql @S, @params, @Count = @RowsToDelete output

			Set @S = ''
			Set @S = @S + ' SELECT @Count = COUNT(*)'
			Set @S = @S + ' FROM [' + @SourceTable + ']'
		
			Set @params = '@Count int output'
			
			Exec sp_executeSql @S, @params, @Count = @RowsToKeep output
			
			Set @RowsToKeep = @RowsToKeep - @RowsToDelete
			
			UPDATE #Tmp_Table_Stats 
			SET RowsToKeep = @RowsToKeep,
			    RowsToDelete = @RowsToDelete
			WHERE Entry_ID = @EntryID
		End

	End
			
		
	If @infoOnly <> 0
	Begin
		---------------------------------------------------
		-- Preview rows to delete
		---------------------------------------------------
		
		SELECT TStats.SourceTable,
		       TStats.MonthsToRetain,
		       TStats.RowsToKeep,
		       TStats.RowsToDelete,
		       CONVERT(decimal(7, 2), TSize.Space_Used_MB) AS Space_Used_MB,
		       TSize.Percent_Total_Used_MB,
		       TSize.Percent_Total_Rows
		FROM #Tmp_Table_Stats TStats
		     INNER JOIN dbo.V_Table_Size_Summary TSize
		       ON TStats.SourceTable = TSize.Table_Name
		ORDER BY TStats.SourceTable

		Exec DeleteOldQueryStats @infoOnly, @QueryStatsMonthsToRetain, @QueryStatsExpensiveMonthsToRetain
	End
	Else
	Begin
		---------------------------------------------------
		-- Delete old data
		---------------------------------------------------
		
		Set @Continue = 1
		Set @EntryID = 0
		
		While @continue = 1
		Begin
			SELECT TOP 1 @EntryID = Entry_ID,
						@SourceTable = SourceTable,
						@DateStampColName = DateStampColName,
						@MonthsToRetain = MonthsToRetain,
						@RowsToDelete = RowsToDelete
			FROM #Tmp_Table_Stats
			WHERE Entry_ID > @EntryID
			ORDER BY Entry_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount = 0
				Set @Continue = 0
			Else
			Begin
				if @RowsToDelete > 0
				Begin
					Set @S = ''
					Set @S = @S + ' DELETE'
					Set @S = @S + ' FROM [' + @SourceTable + ']'
					Set @S = @S + ' WHERE [' + @DateStampColName + '] < DATEADD(month, -' + Convert(varchar(4), @MonthsToRetain) + ', GETDATE())'
				
					Exec (@S)
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount

					If Len(@message) > 0
						Set @message = @message + ', ' 
						
					Set @message = @message + 'Deleted ' + Convert(varchar(12), @myRowCount) + ' rows from ' + @SourceTable
					
				End
				
			End

		End

		If Len(@message) > 0
			Exec PostLogEntry 'Normal', @message, 'DeleteOldData'
				
		Exec DeleteOldQueryStats @infoOnly, @QueryStatsMonthsToRetain, @QueryStatsExpensiveMonthsToRetain
			
	End


Done:
	return @myError

GO

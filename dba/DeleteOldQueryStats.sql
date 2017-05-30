/****** Object:  StoredProcedure [dbo].[DeleteOldQueryStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DeleteOldQueryStats]
/****************************************************
**
**	Desc: 
**		Deletes old data from T_QueryStats, 
**		T_QueryStatsExpensive, and T_QueryText tables
**
**	Auth:	mem
**	Date:	04/01/2014 mem - Initial release
**    
*****************************************************/
(
	@infoOnly tinyint = 1,					-- 1 to preview changes, 0 to delete old data
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
	
	Set @QueryStatsMonthsToRetain          = IsNull(@QueryStatsMonthsToRetain, 3)
	Set @QueryStatsExpensiveMonthsToRetain = IsNull(@QueryStatsExpensiveMonthsToRetain, 15)		

	If @QueryStatsMonthsToRetain < 1
		Set @QueryStatsMonthsToRetain = 1

	If @QueryStatsExpensiveMonthsToRetain < 6
		Set @QueryStatsExpensiveMonthsToRetain = 6

	---------------------------------------------------
	-- Define the deletion thresholds
	---------------------------------------------------
	--
	Declare @QueryStatsThreshold Datetime = DateAdd(month, -@QueryStatsMonthsToRetain, GetDate())
	
	Declare @QueryStatsExpensiveThreshold Datetime = DateAdd(month, -@QueryStatsExpensiveMonthsToRetain, GetDate())
	
		
	If @infoOnly <> 0
	Begin
		---------------------------------------------------
		-- Preview rows to delete
		---------------------------------------------------
		
		SELECT TStats.SourceTable,
		       TStats.RowsToDelete,
		       TStats.RowsToKeep,
		       CONVERT(decimal(7, 2), TSize.Space_Used_MB) AS Space_Used_MB,
		       TSize.Percent_Total_Used_MB,
		       TSize.Percent_Total_Rows
		FROM (SELECT 'T_QueryStats_Expensive' AS SourceTable,
		             Sum(CASE WHEN Entered < @QueryStatsExpensiveThreshold THEN 1 ELSE 0 END) AS RowsToDelete,
		             Sum(CASE WHEN Entered >=  @QueryStatsExpensiveThreshold THEN 1 ELSE 0 END) AS RowsToKeep
		      FROM T_QueryStats_Expensive
		      UNION
		      SELECT 'T_QueryStats' AS SourceTable,
		             Sum(CASE WHEN interval_end < @QueryStatsThreshold THEN 1 ELSE 0 END) AS RowsToDelete,
		             Sum(CASE WHEN interval_end >=  @QueryStatsThreshold THEN 1 ELSE 0 END) AS RowsToKeep
		      FROM T_QueryStats 
		     ) TStats
		     INNER JOIN dbo.V_Table_Size_Summary TSize
		       ON TStats.SourceTable = TSize.Table_Name
	
	End
	Else
	Begin
		---------------------------------------------------
		-- Delete old data
		---------------------------------------------------
		
		DELETE
		FROM T_QueryStats_Expensive
		WHERE Entered < @QueryStatsExpensiveThreshold
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myRowCount > 0
		Begin
			If Len(@message) > 0
				Set @message = @message + ', '
			Set @message = 'Deleted ' + Convert(varchar(12), @myRowCount) + ' old rows from T_QueryStats_Expensive'
		End


		DELETE
		FROM T_QueryStats
		WHERE interval_end < @QueryStatsThreshold
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myRowCount > 0
		Begin
			If Len(@message) > 0
				Set @message = @message + ', '
			Set @message = 'Deleted ' + Convert(varchar(12), @myRowCount) + ' old rows from T_QueryStats'
		End


		DELETE T_QueryText
		FROM T_QueryText QT
		     LEFT OUTER JOIN T_QueryStats QS
		       ON QT.sql_handle = QS.sql_handle
		     LEFT OUTER JOIN T_QueryStats_Expensive QE
		       ON QT.sql_handle = QE.sql_handle
		WHERE (QS.Entry_ID IS NULL) AND
		      (QE.Entry_ID IS NULL)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myRowCount > 0
		Begin
			If Len(@message) > 0
				Set @message = @message + ', '
			Set @message = 'Deleted ' + Convert(varchar(12), @myRowCount) + ' old rows from T_QueryText'
		End

		If Len(@message) > 0
			Exec PostLogEntry 'Normal', @message, 'DeleteOldQueryStats'
			
	End


Done:
	return @myError

GO

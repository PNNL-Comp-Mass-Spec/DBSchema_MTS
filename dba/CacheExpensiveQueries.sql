/****** Object:  StoredProcedure [dbo].[CacheExpensiveQueries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CacheExpensiveQueries
/****************************************************
**
**	Desc:
**		Looks for expensive queries cached in T_QueryStats
**		Stores details in T_QueryStats_Expensive
**
**		Note that the query text string is tracked by T_QueryText
**		(populated by CacheQueryStats)
**
**		The expensive Sql Statement is visible using V_QueryStats_Expensive, which uses
**			SUBSTRING(QT.QueryText, QS.statement_start_offset / 2 + 1, 
**		           (CASE WHEN (QS.statement_end_offset = -1) 
**		                 THEN LEN(QT.QueryText) * 2
**		                 ELSE QS.statement_end_offset
**		            END - QS.statement_start_offset) / 2 + 1) AS Sql_Stmt,
**	
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**			03/31/2014 - Initial release
**
*****************************************************/
(
	@MinTimeThresholdMsec int = 2000,
	@TotalTimeThresholdMsec int = 10000,
	@infoOnly tinyint = 0
)
AS
	set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	------------------------------------------------------
	-- Validate the inputs
	------------------------------------------------------
	--
	Set @MinTimeThresholdMsec = IsNull(@MinTimeThresholdMsec, 1000)
	Set @TotalTimeThresholdMsec = IsNull(@TotalTimeThresholdMsec, 5000)
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	If @MinTimeThresholdMsec < 200
		Set @MinTimeThresholdMsec = 200
		
	If @TotalTimeThresholdMsec < 1000
		Set @TotalTimeThresholdMsec = 1000

	------------------------------------------------------
	-- Create the temporary table to hold the stats
	------------------------------------------------------
	--
	CREATE TABLE [dbo].[#Tmp_Expensive_Queries] (
		Entry_ID int NOT NULL,
		Min_Time_Threshold_Exceeded tinyint NOT NULL,
		Total_Time_Threshold_Exceeded tinyint NOT NULL
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	------------------------------------------------------
	-- Look for queries that have processing times longer than the thresholds
	------------------------------------------------------
	--
	INSERT INTO #Tmp_Expensive_Queries( Entry_ID,
	                                    Min_Time_Threshold_Exceeded,
	                                    Total_Time_Threshold_Exceeded )
	SELECT QS.Entry_ID,
	       CASE
	           WHEN QS.min_elapsed_time_ms >= @MinTimeThresholdMsec OR
	                QS.min_worker_time_ms >= @MinTimeThresholdMsec THEN 1
	           ELSE 0
	       END AS Min_Time_Threshold_Exceeded,
	       CASE
	           WHEN QS.total_elapsed_time_ms >= @TotalTimeThresholdMsec OR
	                QS.total_worker_time_ms >= @TotalTimeThresholdMsec THEN 1
	           ELSE 0
	       END AS Total_Time_Threshold_Exceeded
	FROM T_QueryStats QS
	WHERE QS.min_elapsed_time_ms >= @MinTimeThresholdMsec OR			-- Wall-clock time
	      QS.min_worker_time_ms >= @MinTimeThresholdMsec OR				-- CPU time
	      QS.total_elapsed_time_ms >= @TotalTimeThresholdMsec OR        -- Wall-clock time
	      QS.total_worker_time_ms >= @TotalTimeThresholdMsec			-- CPU time
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	If @InfoOnly <> 0
	Begin
		SELECT EQ.*,
		       QS.min_worker_time_ms,
		       QS.min_elapsed_time_ms,
		       QS.total_worker_time_ms,
		       QS.total_elapsed_time_ms,
		       QT.DatabaseName,
		       QT.objtype,
		       SUBSTRING(QT.QueryText, QS.statement_start_offset / 2 + 1, 
		           (CASE WHEN (QS.statement_end_offset = -1) 
		                 THEN LEN(QT.QueryText) * 2
		                 ELSE QS.statement_end_offset
		            END - QS.statement_start_offset) / 2 + 1) AS Sql_Stmt,
		       QS.sql_handle,
		       QT.QueryText
		FROM #Tmp_Expensive_Queries EQ
		     INNER JOIN T_QueryStats QS
		       ON EQ.Entry_ID = QS.Entry_ID
		     INNER JOIN T_QueryText QT
		       ON QS.sql_handle = QT.sql_handle
		ORDER BY Min_Time_Threshold_Exceeded DESC, min_worker_time_ms + min_elapsed_time_ms DESC,
		           Total_Time_Threshold_Exceeded DESC, total_worker_time_ms + total_elapsed_time_ms DESC
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Goto Done
	End

	------------------------------------------------------
	-- Append the expensive queries to T_QueryStats_Expensive
	------------------------------------------------------
	--	
	INSERT INTO T_QueryStats_Expensive( Entry_ID,
	                                    Min_Time_Threshold,
	                                    Total_Time_Threshold,
	                                    Min_Time_Threshold_Exceeded,
	                                    Total_Time_Threshold_Exceeded,
	                                    sql_handle,
	                                    statement_start_offset,
	                                    statement_end_offset,
	                                    execution_count,
	                                    total_elapsed_time_ms,
	                                    min_elapsed_time_ms,
	                                    max_elapsed_time_ms,
	                                    total_worker_time_ms,
	                                    min_worker_time_ms,
	                                    max_worker_time_ms,
	                                    total_logical_reads,
	                                    min_logical_reads,
	                                    max_logical_reads,
	                                    total_physical_reads,
	                                    min_physical_reads,
	                                    max_physical_reads,
	                                    total_logical_writes,
	                                    min_logical_writes,
	                                    max_logical_writes,
	                                    creation_time,
	                                    last_execution_time,
	                                    Entered )
	SELECT EQ.Entry_ID,
	       @MinTimeThresholdMsec,
	       @TotalTimeThresholdMsec,
	       EQ.Min_Time_Threshold_Exceeded,
	       EQ.Total_Time_Threshold_Exceeded,
	       QS.sql_handle,
	       QS.statement_start_offset,
	       QS.statement_end_offset,
	       QS.execution_count,
	       QS.total_elapsed_time_ms,
	       QS.min_elapsed_time_ms,
	       QS.max_elapsed_time_ms,
	       QS.total_worker_time_ms,
	       QS.min_worker_time_ms,
	       QS.max_worker_time_ms,
	       QS.total_logical_reads,
	       QS.min_logical_reads,
	       QS.max_logical_reads,
	       QS.total_physical_reads,
	       QS.min_physical_reads,
	       QS.max_physical_reads,
	       QS.total_logical_writes,
	       QS.min_logical_writes,
	       QS.max_logical_writes,
	       QS.creation_time,
	       QS.last_execution_time,
	       GetDate()
	FROM #Tmp_Expensive_Queries EQ
	     INNER JOIN T_QueryStats QS
	       ON EQ.Entry_ID = QS.Entry_ID
	     LEFT OUTER JOIN T_QueryStats_Expensive target
	       ON EQ.Entry_ID = target.Entry_ID
	WHERE target.Entry_ID Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError
	


GO

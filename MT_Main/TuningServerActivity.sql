/****** Object:  StoredProcedure [dbo].[TuningServerActivity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.TuningServerActivity
/****************************************************
**
**	Desc: 
**		Displays a list of the currently executing processes
**		Based on code from Jason Massie at http://sqlserverpedia.com/wiki/Misc_DMV_queries
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	12/09/2008 mem
**    
*****************************************************/
(
	@RefreshIntervalSeconds int = 1,
	@RunContinuously tinyint = 0,			-- Although this can run continuously, the results likely won't be displayed real time (it depends on the calling application)
	@MaximumRunTimeHours real = 12,			-- Only used if @RunContinuously is non-zero
	@message varchar(255)='' output
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @UpdateDelay varchar(20)
	Declare @Continue tinyint
	Declare @IterationCount int
	Declare @StopTime DateTime

/*
	Declare @QueryText nvarchar(2048)
	Declare @CpuTime int
	Declare @LogicalReads bigint
	Declare @WaitType nvarchar(60)
	Declare @WaitTime int
	Declare @LastWaitType nvarchar(60)
	Declare @WaitResource nvarchar(256)
	Declare @Command nvarchar(16)
	Declare @DatabaseID smallint
	Declare @BlockingSessionID smallint
	Declare @GrantedQueryMemory int
	Declare @SessionID smallint
	Declare @Reads bigint
	Declare @Writes bigint
	Declare @RowCount bigint
	Declare @HostName nvarchar(128)
	Declare @ProgramName nvarchar(128)
	Declare @LoginName nvarchar(128)
*/
	
	---------------------------------------------------
	-- Create the temporary table
	---------------------------------------------------

	CREATE TABLE dbo.#TmpServerActivity (
		cpu_time int NULL ,
		logical_reads bigint NULL ,
		Session_cpu_time int NOT NULL ,
		Session_logical_reads bigint NOT NULL ,
		session_id smallint NOT NULL 
	)


	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @RefreshIntervalSeconds = IsNull(@RefreshIntervalSeconds, 1)
	Set @MaximumRunTimeHours = IsNull(@MaximumRunTimeHours, 12)
	Set @RunContinuously = IsNull(@RunContinuously, 0)
	Set @message= ''

	If @RefreshIntervalSeconds < 1
		Set @RefreshIntervalSeconds = 1
	
	If @MaximumRunTimeHours < 0
		Set @MaximumRunTimeHours = 0.5
	
	If @RunContinuously <> 0
		Print 'CpuTime, LogicalReads, WaitType, WaitTime, LastWaitType, WaitResource, Command, DatabaseID, BlockingSessionID, GrantedQueryMemory, SessionID, Reads, Writes, RowCount, HostName, ProgramName, LoginName'	

	Set @StopTime = DateAdd(minute, @MaximumRunTimeHours*60.0, GetDate())
		
	Set @UpdateDelay = '00:00:' + Convert(varchar(12), @RefreshIntervalSeconds)
	
	Set @IterationCount = 0
	Set @Continue = 1
	While @Continue = 1
	Begin
		TRUNCATE TABLE #TmpServerActivity
		
		INSERT INTO #TmpServerActivity( cpu_time,
		                                logical_reads,
		                                Session_cpu_time,
		                                Session_logical_reads,
		                                session_id )
		SELECT r.cpu_time,
			  r.logical_reads,
			  s.cpu_time,
			  s.logical_reads,
			  s.session_id
		FROM sys.dm_exec_sessions AS s
			LEFT OUTER JOIN sys.dm_exec_requests AS r
			ON s.session_id = r.session_id AND
				s.last_request_start_time = r.start_time
		WHERE s.is_user_process = 1     --and r.cpu_time > 0

		WAITFOR delay @UpdateDelay

/*		
		If @RunContinuously <> 0
		Begin
				-- Warning: This will only cache one of the running tasks in the variables
				
				SELECT @QueryText = SUBSTRING(h.TEXT, (r.statement_start_offset / 2) + 1, ((CASE r.statement_end_offset
																			WHEN - 1 THEN datalength(h.TEXT)
																			ELSE r.statement_end_offset
																		END - r.statement_start_offset) / 2) 
																		+ 1),
				@CpuTime = r.cpu_time - t.cpu_time,
				@LogicalReads = r.logical_reads - t.logical_reads,
				@WaitType = r.wait_type,
				@WaitTime = r.wait_time,
				@LastWaitType = r.last_wait_type,
				@WaitResource = r.wait_resource,
				@Command = r.command,
				@DatabaseID = r.database_id,
				@BlockingSessionID = r.blocking_session_id,
				@GrantedQueryMemory = r.granted_query_memory,
				@SessionID = r.session_id,
				@Reads = r.Reads,
				@Writes = r.writes,
				@RowCount = r.row_count,
				@HostName = s.[host_name],
				@ProgramName = s.program_name,
				@LoginName = s.login_name
			FROM sys.dm_exec_sessions AS s
				INNER JOIN sys.dm_exec_requests AS r
				ON s.session_id = r.session_id AND
					s.last_request_start_time = r.start_time
				LEFT JOIN #TmpServerActivity AS t
				ON t.session_id = s.session_id
				CROSS APPLY sys.dm_exec_sql_text ( r.sql_handle ) h
			WHERE is_user_process = 1 AND
				  h.Text NOT LIKE 'CREATE Procedure dbo.ServerActivityDashboard%'
			
			Print   Convert(varchar(19), @CpuTime) + ', ' + 
					Convert(varchar(19), @LogicalReads) + ', ' + 
					IsNull(@WaitType, '')  + ', ' + 
					Convert(varchar(19), @WaitTime) + ', ' + 
					IsNull(@LastWaitType, '')  + ', ' + 
					IsNull(@WaitResource, '')  + ', ' + 
					IsNull(@Command, '')  + ', ' + 
					Convert(varchar(19), @DatabaseID) + ', ' + 
					Convert(varchar(19), @BlockingSessionID) + ', ' + 
					Convert(varchar(19), @GrantedQueryMemory) + ', ' + 
					Convert(varchar(19), @SessionID) + ', ' + 
					Convert(varchar(19), @Reads) + ', ' + 
					Convert(varchar(19), @Writes) + ', ' + 
					Convert(varchar(19), @RowCount) + ', ' + 
					IsNull(@HostName, '')  + ', ' + 
					IsNull(@ProgramName, '')  + ', ' + 
					IsNull(@LoginName, '') + ', ' + 
					SubString(IsNull(@QueryText, ''), 1, 25)

		End
		Else		
*/

			SELECT *
			FROM ( SELECT s.login_name,
			              s.login_time,
			              s.[host_name],
			              s.program_name,
			              s.client_interface_name,
			              s.status,
			              s.total_scheduled_time,
			              s.total_elapsed_time,
			              s.last_request_start_time,
			              s.reads AS Session_Reads,
			              s.writes AS Session_Writes,
			              s.row_count AS Session_RowCount,
			              s.logical_reads AS Session_LogicalReads,
			              s.cpu_time AS Session_CpuTime,
			              QT.QueryText,
			              r.cpu_time,
			              r.logical_reads,
			              r.cpu_time - t.cpu_time AS CPUDiff,
			              r.logical_reads - t.logical_reads AS ReadDiff,
			              r.wait_type,
			              r.wait_time,
			              r.last_wait_type,
			              r.wait_resource,
			              r.command,
			              DB_Name(r.database_id) AS DatabaseName,
			              r.blocking_session_id,
			              r.granted_query_memory,
			              r.session_id,
			              r.reads,
			              r.writes,
			              r.row_count
			       FROM sys.dm_exec_sessions AS s
			            LEFT OUTER JOIN sys.dm_exec_requests AS r
			              ON s.session_id = r.session_id AND
			                 s.last_request_start_time = r.start_time
			            LEFT OUTER JOIN #TmpServerActivity AS t
			              ON t.session_id = s.session_id
			            LEFT OUTER JOIN ( SELECT r.session_id,
			                                     SUBSTRING(h.text, (r.statement_start_offset / 2) + 1, 
			                                       ((CASE r.statement_end_offset
			                                             WHEN - 1 THEN datalength(h.text)
			                                             ELSE r.statement_end_offset
			                                         END - r.statement_start_offset) / 2) + 1) AS QueryText
			                              FROM sys.dm_exec_requests AS r
			                                   CROSS APPLY sys.dm_exec_sql_text ( r.sql_handle ) h ) QT
			              ON S.session_id = QT.session_ID
			       WHERE s.is_user_process = 1 ) LookupQ 
			
			--			WHERE QueryText NOT LIKE 'SELECT * FROM (SELECT s.login_name, s.login_time,%'
			ORDER BY status, login_name
	
	
		If @RunContinuously = 0
			Set @Continue = 0
		
		If GetDate() >= @StopTime
			Set @Continue = 0
			
		Set @IterationCount = @IterationCount + 1
	End

Done:

	DROP TABLE #TmpServerActivity
	
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[TuningServerActivity] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[TuningServerActivity] TO [MTS_DB_Lite] AS [dbo]
GO

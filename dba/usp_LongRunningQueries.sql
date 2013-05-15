/****** Object:  StoredProcedure [dbo].[usp_LongRunningQueries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC dbo.usp_LongRunningQueries
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.0					Comments creation
**	08/31/2012		Michael Rounds			1.1					Changed VARCHAR to NVARCHAR
**	04/22/2013		Michael Rounds			1.2					Simplified to use DMV's to gather session information
**	04/23/2013		Michael Rounds			1.2.1				Adjusted INSERT based on schema changes to QueryHistory, Added Formatted_SQL_Text.
**	05/02/2013		Michael Rounds			1.2.2				Switched login_time to start_time for determining individual long running queries
**																Changed TEMP table to use Formatted_SQL_Text instead of SQL_Text
**																Changed how variables are gathered in AlertSettings and AlertContacts
**	05/03/2013		Volker.Bachmann								Added "[dba]" to the start of all email subject lines
**						from SSC
**	05/14/2013		Matthew Monroe			1.2.3				Now using Exclusion entries in AlertSettings to optionally ignore some long running queries
***************************************************************************************************************/

BEGIN


	INSERT INTO dbo.QueryHistory (DateStamp,Login_Time,Start_Time,RunTime,Session_ID,CPU_Time,Reads,Writes,Logical_Reads,[Host_Name],DBName,Login_Name,Formatted_SQL_Text,SQL_Text,[Program_Name])
	SELECT
	GETDATE() AS DateStamp,
	s.login_time,
	s.last_request_start_time as start_time,	
		(r.total_elapsed_time/1000.0) as RunTime,
		r.session_id,                                    
		r.cpu_time,
		r.Reads,
		r.Writes,
		r.Logical_Reads,
		s.[Host_Name],
		DB_Name(r.database_id) as DBName,
		s.login_name,
		SUBSTRING(qt.[text],r.statement_start_offset/2,(LTRIM(LEN(CONVERT(NVARCHAR(MAX), qt.[text]))) * 2 - r.statement_start_offset)/2)
		AS Formatted_SQL_Text,
		qt.[text] AS SQL_Text,		
		[Program_Name]
	FROM sys.dm_exec_requests r (nolock)
	JOIN sys.dm_exec_sessions s (nolock) 
		ON r.session_id = s.session_id
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) as qt
	WHERE r.session_id > 50
	AND r.session_id <> @@SPID

	DECLARE @QueryValue INT, @QueryValue2 INT, @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @ServerName NVARCHAR(50), @EmailSubject NVARCHAR(100)

	SELECT @ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'))

	SELECT @QueryValue = CAST(Value AS INT) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue' AND AlertName = 'LongRunningQueries'

	SELECT @QueryValue2 = CAST(Value AS INT) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue2' AND AlertName = 'LongRunningQueries'
		
	SELECT @EmailList = EmailList,
			@CellList = CellList	
	FROM [dba].dbo.AlertContacts WHERE AlertName = 'LongRunningQueries'

	DECLARE @LastQueryHistoryID INT, @LastCollectionTime DATETIME

	SELECT @LastQueryHistoryID =  MIN(a.queryhistoryID) -1
	FROM [dba].dbo.queryhistory a
	WHERE a.DateStamp = (SELECT MAX(DateStamp) FROM [dba].dbo.QueryHistory WHERE DateStamp > GETDATE() -1) 

	SELECT @LastCollectionTime = DateStamp FROM [dba].dbo.QueryHistory WHERE QueryHistoryID = @LastQueryHistoryID

	CREATE TABLE #TEMP (
		QueryHistoryID INT,
		DateStamp DATETIME,
		login_time DATETIME,
		Start_Time DATETIME,
		Session_ID SMALLINT,
		CPU_Time INT,
		Reads BIGINT,
		Writes BIGINT,
		Logical_Reads BIGINT,
		[Host_Name] NVARCHAR(128),
		[DBName] NVARCHAR(128),
		Login_name NVARCHAR(128),
		SQL_Text NVARCHAR(MAX),
		[Program_name] NVARCHAR(128)
		)

	INSERT INTO #TEMP (QueryHistoryID, DateStamp, Login_Time, Start_Time, session_id, CPU_Time, reads, writes, Logical_Reads, [host_name], [DBName], login_name, SQL_Text, [program_name])
		SELECT QueryHistoryID, DateStamp, Login_Time, Start_Time, session_id, CPU_Time, reads, writes, Logical_Reads, [host_name], [DBName], login_name, Formatted_SQL_Text AS SQL_Text, [program_name]
		FROM [dba].dbo.QueryHistory QH
			LEFT OUTER JOIN (SELECT Value FROM AlertSettings 
			                 WHERE AlertName = 'LongRunningQueries' AND 
			                       VariableName LIKE 'Exclusion%' AND 
			                       Not Value Is Null AND Enabled = 1) AlertEx
				ON QH.Formatted_SQL_Text LIKE AlertEx.Value
	WHERE (DATEDIFF(ss,Start_Time,DateStamp)) >= @QueryValue
		AND (DATEDIFF(mi,DateStamp,GETDATE())) < (DATEDIFF(mi,@LastCollectionTime, DateStamp))
		AND [DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
		AND Formatted_SQL_Text NOT LIKE '%BACKUP DATABASE%'
		AND Formatted_SQL_Text NOT LIKE '%RESTORE VERIFYONLY%'
		AND Formatted_SQL_Text NOT LIKE '%ALTER INDEX%'
		AND Formatted_SQL_Text NOT LIKE '%DECLARE @BlobEater%'
		AND Formatted_SQL_Text NOT LIKE '%DBCC%'
		AND Formatted_SQL_Text NOT LIKE '%WAITFOR(RECEIVE%'
		AND AlertEx.Value Is Null

	IF EXISTS (SELECT * FROM #TEMP)
	BEGIN

		DECLARE @HTML NVARCHAR(MAX)

		SET	@HTML =
			'<html><head><style type="text/css">
			table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
			th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
			th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
			td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
			</style></head><body>
			<table width="900"> <tr><th class="header" width="900">Long Running Queries</th></tr></table>
			<table width="900">
			<tr>  
			<th width="100">DateStamp</th>
			<th width="100">ElapsedTime(ss)</th>
			<th width="50">SPID</th>
			<th width="75">Database</th>
			<th width="100">Login</th> 	
			<th width="475">QueryText</th>
			</tr>'
		SELECT @HTML =  @HTML +   
			'<tr>
			<td bgcolor="#E0E0E0" width="100">' + CAST(DateStamp AS NVARCHAR) +'</td>	
			<td bgcolor="#F0F0F0" width="100">' + CAST(DATEDIFF(ss,Start_Time,DateStamp) AS NVARCHAR) +'</td>
			<td bgcolor="#E0E0E0" width="50">' + CAST(Session_id AS NVARCHAR) +'</td>
			<td bgcolor="#F0F0F0" width="75">' + CAST([DBName] AS NVARCHAR) +'</td>	
			<td bgcolor="#E0E0E0" width="100">' + CAST(login_name AS NVARCHAR) +'</td>	
			<td bgcolor="#F0F0F0" width="475">' + LEFT(SQL_Text,100) +'</td>			
			</tr>'
		FROM #TEMP

		SELECT @HTML =  @HTML + '</table></body></html>'

		SELECT @EmailSubject = '[dba]Long Running QUERIES on ' + @ServerName + '!'

		EXEC msdb..sp_send_dbmail
			@recipients= @EmailList,
			@subject = @EmailSubject,
			@body = @HTML,
			@body_format = 'HTML'

		IF IsNull(@CellList, '') <> ''
		BEGIN

			IF IsNull(@QueryValue2, '') <> ''
			BEGIN
				TRUNCATE TABLE #TEMP
				INSERT INTO #TEMP (QueryHistoryID, DateStamp, login_time, Start_Time, session_id, CPU_Time, reads, writes, Logical_Reads, [host_name], [DBName], login_name, SQL_Text, [program_name])
				SELECT QueryHistoryID, DateStamp, login_time, Start_Time, session_id, CPU_Time, reads, writes, Logical_Reads, [host_name], [DBName], login_name, Formatted_SQL_Text AS SQL_Text, [program_name]
				FROM [dba].dbo.QueryHistory QH
					LEFT OUTER JOIN (SELECT Value FROM AlertSettings 
					                 WHERE AlertName = 'LongRunningQueries' AND 
					                       VariableName LIKE 'Exclusion%' AND 
					                       Not Value Is Null AND Enabled = 1) AlertEx
						ON QH.Formatted_SQL_Text LIKE AlertEx.Value
				WHERE (DATEDIFF(ss,Start_Time,DateStamp)) >= @QueryValue2
					AND (DATEDIFF(mi,DateStamp,GETDATE())) < (DATEDIFF(mi,@LastCollectionTime, DateStamp))
					AND [DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
					AND Formatted_SQL_Text NOT LIKE '%BACKUP DATABASE%'
					AND Formatted_SQL_Text NOT LIKE '%RESTORE VERIFYONLY%'
					AND Formatted_SQL_Text NOT LIKE '%ALTER INDEX%'
					AND Formatted_SQL_Text NOT LIKE '%DECLARE @BlobEater%'
					AND Formatted_SQL_Text NOT LIKE '%DBCC%'
					AND Formatted_SQL_Text NOT LIKE '%WAITFOR(RECEIVE%'
					AND AlertEx.Value Is Null
			END

			/*TEXT MESSAGE*/
			IF EXISTS (SELECT * FROM #TEMP)
			BEGIN
				SET	@HTML =
					'<html><head></head><body><table><tr><td>Time,</td><td>SPID,</td><td>Login</td></tr>'
				SELECT @HTML =  @HTML +   
					'<tr><td>' + CAST(DATEDIFF(ss,Start_Time,DateStamp) AS NVARCHAR) +',</td><td>' + CAST(Session_id AS NVARCHAR) +',</td><td>' + CAST(login_name AS NVARCHAR) +'</td></tr>'
				FROM #TEMP

				SELECT @HTML =  @HTML + '</table></body></html>'

				SELECT @EmailSubject = '[dba]LongQueries-' + @ServerName

				EXEC msdb..sp_send_dbmail
					@recipients= @CellList,
					@subject = @EmailSubject,
					@body = @HTML,
					@body_format = 'HTML'

			END
		END
		DROP TABLE #TEMP
	END
END


GO

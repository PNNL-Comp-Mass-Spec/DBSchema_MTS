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
**	05/10/2013		Michael Rounds			1.2.3				Changed INSERT into QueryHistory to use EXEC sp_Query
**	05/14/2013		Matthew Monroe			1.2.4				Now using Exclusion entries in AlertSettings to optionally ignore some long running queries
**	05/28/2013		Michael	Rounds			1.3					Changed proc to INSERT into TEMP table and query from TEMP table before INSERT into QueryHistory, improves performance
**																	and resolves a very infrequent bug with the Long Running Queries Job
***************************************************************************************************************/
BEGIN

	DECLARE @QueryValue INT, @QueryValue2 INT, @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @ServerName NVARCHAR(50), @EmailSubject NVARCHAR(100), @HTML NVARCHAR(MAX)

	SELECT @ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'))
	SELECT @QueryValue = CAST(Value AS INT) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue' AND AlertName = 'LongRunningQueries'
	SELECT @QueryValue2 = COALESCE(CAST(Value AS INT),@QueryValue) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue2' AND AlertName = 'LongRunningQueries'
	SELECT @EmailList = EmailList,
			@CellList = CellList	
	FROM [dba].dbo.AlertContacts WHERE AlertName = 'LongRunningQueries'

	CREATE TABLE #QUERYHISTORY (
		[Session_ID] SMALLINT NOT NULL,
		[DBName] NVARCHAR(128) NULL,		
		[RunTime] NUMERIC(20,4) NULL,		
		[Login_Name] NVARCHAR(128) NOT NULL,
		[Formatted_SQL_Text] NVARCHAR(MAX) NULL,
		[SQL_Text] NVARCHAR(MAX) NULL,
		[CPU_Time] BIGINT NULL,	
		[Logical_Reads] BIGINT NULL,
		[Reads] BIGINT NULL,		
		[Writes] BIGINT NULL,
		Wait_Time INT,
		Last_Wait_Type NVARCHAR(60),
		[Status] NVARCHAR(50),
		Blocking_Session_ID SMALLINT,
		Open_Transaction_Count INT,
		Percent_Complete NUMERIC(12,2),
		[Host_Name] NVARCHAR(128) NULL,		
		Client_net_address NVARCHAR(50),
		[Program_Name] NVARCHAR(128) NULL,
		[Start_Time] DATETIME NOT NULL,
		[Login_Time] DATETIME NULL,
		[DateStamp] DATETIME NULL
			CONSTRAINT [DF_QueryHistory_DateStamp]  DEFAULT (GETDATE())
		)

	INSERT INTO #QUERYHISTORY (session_id,DBName,RunTime,login_name,Formatted_SQL_Text,SQL_Text,cpu_time,Logical_Reads,Reads,Writes,wait_time,last_wait_type,[status],blocking_session_id,
								open_transaction_count,percent_complete,[Host_Name],Client_Net_Address,[Program_Name],start_time,login_time,DateStamp)
	EXEC dbo.sp_Sessions;

	-- Flag long-running queries to exclude
	ALTER TABLE #QUERYHISTORY
	Add NotifyExclude bit

	UPDATE #QUERYHISTORY
	SET NotifyExclude = 1
	FROM #QUERYHISTORY QH
	     INNER JOIN ( SELECT Value
	                  FROM AlertSettings
	                  WHERE AlertName = 'LongRunningQueries' AND
	                        VariableName LIKE 'Exclusion%' AND
	                        NOT VALUE IS NULL AND
	                        Enabled = 1 ) AlertEx
	       ON QH.Formatted_SQL_Text LIKE AlertEx.Value

	IF EXISTS (SELECT * FROM #QUERYHISTORY 
				WHERE RunTime >= @QueryValue
				AND [DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
				AND Formatted_SQL_Text NOT LIKE '%BACKUP DATABASE%'
				AND Formatted_SQL_Text NOT LIKE '%RESTORE VERIFYONLY%'
				AND Formatted_SQL_Text NOT LIKE '%ALTER INDEX%'
				AND Formatted_SQL_Text NOT LIKE '%DECLARE @BlobEater%'
				AND Formatted_SQL_Text NOT LIKE '%DBCC%'
				AND Formatted_SQL_Text NOT LIKE '%WAITFOR(RECEIVE%'
				AND IsNull(NotifyExclude, 0) = 0)
	BEGIN
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
			<td bgcolor="#F0F0F0" width="475">' + LEFT(COALESCE(LTRIM(RTRIM(SQL_Text)),'N/A'),100) +'</td>			
			</tr>'
		FROM #QUERYHISTORY 
		WHERE RunTime >= @QueryValue
		AND [DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
		AND Formatted_SQL_Text NOT LIKE '%BACKUP DATABASE%'
		AND Formatted_SQL_Text NOT LIKE '%RESTORE VERIFYONLY%'
		AND Formatted_SQL_Text NOT LIKE '%ALTER INDEX%'
		AND Formatted_SQL_Text NOT LIKE '%DECLARE @BlobEater%'
		AND Formatted_SQL_Text NOT LIKE '%DBCC%'
		AND Formatted_SQL_Text NOT LIKE '%WAITFOR(RECEIVE%'
		AND IsNull(NotifyExclude, 0) = 0

		SELECT @HTML =  @HTML + '</table></body></html>'

		SELECT @EmailSubject = '[dba]Long Running QUERIES on ' + @ServerName + '!'

		EXEC msdb..sp_send_dbmail
		@recipients= @EmailList,
		@subject = @EmailSubject,
		@body = @HTML,
		@body_format = 'HTML'

		IF COALESCE(@CellList,'') <> '' AND IsNull(@QueryValue2, '') <> ''
		BEGIN
			/*TEXT MESSAGE*/
			SET	@HTML =
				'<html><head></head><body><table><tr><td>Time,</td><td>SPID,</td><td>Login</td></tr>'
			SELECT @HTML =  @HTML +   
				'<tr><td>' + CAST(DATEDIFF(ss,Start_Time,DateStamp) AS NVARCHAR) +',</td><td>' + CAST(Session_id AS NVARCHAR) +',</td><td>' + CAST(login_name AS NVARCHAR) +'</td></tr>'
			FROM #QUERYHISTORY 
			WHERE RunTime >= @QueryValue2
			AND [DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
			AND Formatted_SQL_Text NOT LIKE '%BACKUP DATABASE%'
			AND Formatted_SQL_Text NOT LIKE '%RESTORE VERIFYONLY%'
			AND Formatted_SQL_Text NOT LIKE '%ALTER INDEX%'
			AND Formatted_SQL_Text NOT LIKE '%DECLARE @BlobEater%'
			AND Formatted_SQL_Text NOT LIKE '%DBCC%'
			AND Formatted_SQL_Text NOT LIKE '%WAITFOR(RECEIVE%'
			AND IsNull(NotifyExclude, 0) = 0

			SELECT @HTML =  @HTML + '</table></body></html>'

			SELECT @EmailSubject = '[dba]LongQueries-' + @ServerName

			EXEC msdb..sp_send_dbmail
			@recipients= @CellList,
			@subject = @EmailSubject,
			@body = @HTML,
			@body_format = 'HTML'
		END
	END
	
	IF EXISTS (SELECT * FROM #QUERYHISTORY)
	BEGIN
		INSERT INTO dbo.QueryHistory (session_id,DBName,RunTime,login_name,Formatted_SQL_Text,SQL_Text,cpu_time,Logical_Reads,Reads,Writes,wait_time,last_wait_type,[status],blocking_session_id,
								open_transaction_count,percent_complete,[Host_Name],Client_Net_Address,[Program_Name],start_time,login_time,DateStamp)
		SELECT session_id,DBName,RunTime,login_name,Formatted_SQL_Text,SQL_Text,cpu_time,Logical_Reads,Reads,Writes,wait_time,last_wait_type,[status],blocking_session_id,
								open_transaction_count,percent_complete,[Host_Name],Client_Net_Address,[Program_Name],start_time,login_time,DateStamp
		FROM #QUERYHISTORY
	END
	DROP TABLE #QUERYHISTORY
END

GO

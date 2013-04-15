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
**	04/15/2013		Matthew Monroe			1.11				Now using table T_Alert_Exclusions to optionally ignore some long running queries
***************************************************************************************************************/

BEGIN

	EXEC master..sp_WhoIsActive
			@format_output = 0,
			@output_column_list = '[Collection_Time][Start_Time][Login_Time][Session_ID][CPU][Reads][Writes][Physical_Reads][Host_Name][Database_Name][Login_Name][SQL_Text][Program_Name]',
			@destination_table = '[dba].dbo.QueryHistory'       

	DECLARE @QueryValue INT, @QueryValue2 INT, @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @ServerName NVARCHAR(50), @EmailSubject NVARCHAR(100)

	SELECT @ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'))

	SELECT @QueryValue = QueryValue,
		@QueryValue2 = QueryValue2,
		@EmailList = EmailList,
		@CellList = CellList
	FROM [dba].dbo.AlertSettings WHERE Name = 'LongRunningQueries'

	DECLARE @LastQueryHistoryID INT, @LastCollectionTime DATETIME

	SELECT @LastQueryHistoryID =  MIN(a.queryhistoryID) -1
	FROM [dba].dbo.queryhistory a
	WHERE a.collection_time = (SELECT MAX(collection_time) FROM [dba].dbo.QueryHistory WHERE collection_time > GETDATE() -1) 

	SELECT @LastCollectionTime = Collection_Time FROM [dba].dbo.QueryHistory WHERE QueryHistoryID = @LastQueryHistoryID

	CREATE TABLE #TEMP (
		QueryHistoryID INT,
		Collection_time DATETIME,
		Start_Time DATETIME,
		Login_Time DATETIME,
		Session_ID SMALLINT,
		CPU INT,
		Reads BIGINT,
		Writes BIGINT,
		Physical_reads BIGINT,
		[Host_Name] NVARCHAR(128),
		[DBName] NVARCHAR(128),
		Login_name NVARCHAR(128),
		SQL_Text NVARCHAR(MAX),
		[Program_name] NVARCHAR(128)
		)

	INSERT INTO #TEMP (QueryHistoryID, collection_time, start_time, login_time, session_id, CPU, reads, writes, physical_reads, [host_name], [DBName], login_name, sql_text, [program_name])
	SELECT QueryHistoryID, collection_time, start_time, login_time, session_id, CPU, reads, writes, physical_reads, [host_name], [Database_Name], login_name, sql_text, [program_name]
	FROM [dba].dbo.QueryHistory QH
		LEFT OUTER JOIN [dba].dbo.T_Alert_Exclusions AlertEx 
			ON AlertEx.Category_Name = 'LongRunningQueries' AND QH.sql_text LIKE AlertEx.FilterLikeClause
	WHERE (DATEDIFF(ss,start_time,collection_time)) >= @QueryValue
		AND (DATEDIFF(mi,collection_time,GETDATE())) < (DATEDIFF(mi,@LastCollectionTime, collection_time))
		AND [Database_Name] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
		AND sql_text NOT LIKE 'BACKUP DATABASE%'
		AND sql_text NOT LIKE 'RESTORE VERIFYONLY%'
		AND sql_text NOT LIKE 'ALTER INDEX%'
		AND sql_text NOT LIKE 'DECLARE @BlobEater%'
		AND sql_text NOT LIKE 'DBCC%'
		AND sql_text NOT LIKE 'WAITFOR(RECEIVE%'
		AND AlertEx.Category_Name Is Null

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
			<td bgcolor="#E0E0E0" width="100">' + CAST(collection_time AS NVARCHAR) +'</td>	
			<td bgcolor="#F0F0F0" width="100">' + CAST(DATEDIFF(ss,start_time,collection_time) AS NVARCHAR) +'</td>
			<td bgcolor="#E0E0E0" width="50">' + CAST(Session_id AS NVARCHAR) +'</td>
			<td bgcolor="#F0F0F0" width="75">' + CAST([DBName] AS NVARCHAR) +'</td>	
			<td bgcolor="#E0E0E0" width="100">' + CAST(login_name AS NVARCHAR) +'</td>	
			<td bgcolor="#F0F0F0" width="475">' + LEFT(sql_text,100) +'</td>			
			</tr>'
		FROM #TEMP

		SELECT @HTML =  @HTML + '</table></body></html>'

		SELECT @EmailSubject = 'Long Running QUERIES on ' + @ServerName + '!'

		EXEC msdb.dbo.sp_send_dbmail
			@recipients= @EmailList,
			@subject = @EmailSubject,
			@body = @HTML,
			@body_format = 'HTML'

		IF IsNull(@CellList, '') <> ''
		BEGIN

			IF IsNull(@QueryValue2, '') <> ''
			BEGIN
				TRUNCATE TABLE #TEMP
				INSERT INTO #TEMP (QueryHistoryID, collection_time, start_time, login_time, session_id, CPU, reads, writes, physical_reads, [host_name], [DBName], login_name, sql_text, [program_name])
				SELECT QueryHistoryID, collection_time, start_time, login_time, session_id, CPU, reads, writes, physical_reads, [host_name], [Database_Name], login_name, sql_text, [program_name]
				FROM [dba].dbo.QueryHistory QH
					LEFT OUTER JOIN [dba].dbo.T_Alert_Exclusions AlertEx 
						ON AlertEx.Category_Name = 'LongRunningQueries' AND QH.sql_text LIKE AlertEx.FilterLikeClause
				WHERE (DATEDIFF(ss,start_time,collection_time)) >= @QueryValue2
					AND (DATEDIFF(mi,collection_time,GETDATE())) < (DATEDIFF(mi,@LastCollectionTime, collection_time))
					AND [Database_Name] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
					AND sql_text NOT LIKE 'BACKUP DATABASE%'
					AND sql_text NOT LIKE 'RESTORE VERIFYONLY%'
					AND sql_text NOT LIKE 'ALTER INDEX%'
					AND sql_text NOT LIKE 'DECLARE @BlobEater%'
					AND sql_text NOT LIKE 'DBCC%'
					AND sql_text NOT LIKE 'WAITFOR(RECEIVE%'
					AND AlertEx.Category_Name Is Null
			END

			/*TEXT MESSAGE*/
			IF EXISTS (SELECT * FROM #TEMP)
			BEGIN
				SET	@HTML =
					'<html><head></head><body><table><tr><td>Time,</td><td>SPID,</td><td>Login</td></tr>'
				SELECT @HTML =  @HTML +   
					'<tr><td>' + CAST(DATEDIFF(ss,start_time,collection_time) AS NVARCHAR) +',</td><td>' + CAST(Session_id AS NVARCHAR) +',</td><td>' + CAST(login_name AS NVARCHAR) +'</td></tr>'
				FROM #TEMP

				SELECT @HTML =  @HTML + '</table></body></html>'

				SELECT @EmailSubject = 'LongQueries-' + @ServerName

				EXEC msdb.dbo.sp_send_dbmail
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

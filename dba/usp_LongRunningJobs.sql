/****** Object:  StoredProcedure [dbo].[usp_LongRunningJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_LongRunningJobs]
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
**	01/16/2013		Michael Rounds			1.2					Added "AND JobName <> 'dba_LongRunningJobsAlert'" to INSERT into TEMP table
**	05/03/2013		Michael Rounds			1.3					Changed how variables are gathered in AlertSettings and AlertContacts
**					Volker.Bachmann								Added "[dba]" to the start of all email subject lines
**						from SSC
**	06/13/2013		Michael Rounds			1.4					Added SET NOCOUNT ON
**																Added AlertSettings Enabled column to determine if the alert is enabled.
**	07/23/2013		Michael Rounds			1.5					Tweaked to support Case-sensitive
***************************************************************************************************************/
BEGIN
	SET NOCOUNT ON

	EXEC [dba].dbo.usp_JobStats @InsertFlag=1

	DECLARE @JobStatsID INT, @QueryValue INT, @QueryValue2 INT, @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @HTML NVARCHAR(MAX), @ServerName NVARCHAR(50), @EmailSubject NVARCHAR(100)

	SELECT @ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'))

	SET @JobStatsID = (SELECT MAX(JobStatsID) FROM [dba].dbo.JobStatsHistory)

	SELECT @QueryValue = CAST(Value AS INT) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue' AND AlertName = 'LongRunningJobs' AND [Enabled] = 1

	SELECT @QueryValue2 = CAST(Value AS INT) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue2' AND AlertName = 'LongRunningJobs' AND [Enabled] = 1
		
	SELECT @EmailList = EmailList,
			@CellList = CellList	
	FROM [dba].dbo.AlertContacts WHERE AlertName = 'LongRunningJobs'

	CREATE TABLE #TEMP (
		JobStatsHistoryID INT,
		JobStatsID INT,
		JobStatsDateStamp DATETIME,
		JobName NVARCHAR(255),
		[Enabled] INT,
		StartTime DATETIME,
		StopTime DATETIME,
		AvgRunTime NUMERIC(12,2),
		LastRunTime NUMERIC(12,2),
		RunTimeStatus NVARCHAR(30),
		LastRunOutcome NVARCHAR(20)
		)

	INSERT INTO #TEMP (JobStatsHistoryId, JobStatsID, JobStatsDateStamp, JobName, [Enabled], StartTime, StopTime, AvgRunTime, LastRunTime, RunTimeStatus, LastRunOutcome)
	SELECT JobStatsHistoryId, JobStatsID, JobStatsDateStamp, JobName, [Enabled], StartTime, StopTime, AvgRunTime, LastRunTime, RunTimeStatus, LastRunOutcome
	FROM [dba].dbo.JobStatsHistory
	WHERE RunTimeStatus = 'LongRunning-NOW'
	AND JobName <> 'dba_LongRunningJobsAlert'
	AND LastRunTime > @QueryValue AND JobStatsID = @JobStatsID

	IF EXISTS (SELECT * FROM #TEMP)
	BEGIN
		SET	@HTML =
			'<html><head><style type="text/css">
			table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
			th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
			th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
			td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
			</style></head><body>
			<table width="725"> <tr><th class="header" width="725">Long Running Jobs</th></tr></table>	
			<table width="725">
			<tr>  
			<th width="250">JobName</th>	
			<th width="100">AvgRunTime</th>  
			<th width="100">LastRunTime</th>  
			<th width="150">RunTimeStatus</th>  	
			<th width="125">LastRunOutcome</th>
			</tr>'
		SELECT @HTML =  @HTML +   
			'<tr>
			<td bgcolor="#E0E0E0" width="250">' + JobName +'</td>
			<td bgcolor="#E0E0E0" width="100">' + COALESCE(CAST(AvgRunTime AS NVARCHAR), '') +'</td>
			<td bgcolor="#F0F0F0" width="100">' + CAST(LastRunTime AS NVARCHAR) +'</td>
			<td bgcolor="#E0E0E0" width="150">' + RunTimeStatus +'</td>	
			<td bgcolor="#F0F0F0" width="125">' + LastRunOutcome +'</td>		
			</tr>'
		FROM #TEMP

		SELECT @HTML =  @HTML + '</table></body></html>'

		SELECT @EmailSubject = '[dba]ACTIVE Long Running JOBS on ' + @ServerName + '! - IMMEDIATE Action Required'

		EXEC msdb..sp_send_dbmail
		@recipients= @EmailList,
		@subject = @EmailSubject,
		@body = @HTML,
		@body_format = 'HTML'

		IF COALESCE(@CellList, '') <> ''
		BEGIN
			IF @QueryValue2 IS NOT NULL
			BEGIN
				TRUNCATE TABLE #TEMP
				
				INSERT INTO #TEMP (JobStatsHistoryId, JobStatsID, JobStatsDateStamp, JobName, [Enabled], StartTime, StopTime, AvgRunTime, LastRunTime, RunTimeStatus, LastRunOutcome)
				SELECT JobStatsHistoryId, JobStatsID, JobStatsDateStamp, JobName, [Enabled], StartTime, StopTime, AvgRunTime, LastRunTime, RunTimeStatus, LastRunOutcome
				FROM [dba].dbo.JobStatsHistory
				WHERE RunTimeStatus = 'LongRunning-NOW'
				AND JobName <> 'dba_LongRunningJobsAlert'
				AND LastRunTime > @QueryValue2 AND JobStatsID = @JobStatsID
			END
			/*TEXT MESSAGE*/
			IF EXISTS (SELECT * FROM #TEMP)
			BEGIN
				SET	@HTML =
					'<html><head></head><body><table><tr><td>Name,</td><td>AvgRun,</td><td>LastRun</td></tr>'
				SELECT @HTML =  @HTML +   
					'<tr><td>' + COALESCE(CAST(LOWER(LEFT(JobName,17)) AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(AvgRunTime AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(LastRunTime AS NVARCHAR), '') +'</td></tr>'
				FROM #TEMP

				SELECT @HTML =  @HTML + '</table></body></html>'

				SELECT @EmailSubject = '[dba]JobsPastDue-' + @ServerName

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

/****** Object:  Table [dbo].[BlockingHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BlockingHistory](
	[BlockingHistoryID] [int] IDENTITY(1,1) NOT NULL,
	[DateStamp] [datetime] NOT NULL,
	[Blocked_SPID] [smallint] NOT NULL,
	[Blocking_SPID] [smallint] NOT NULL,
	[Blocked_Login] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Blocked_HostName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Blocked_WaitTime_Seconds] [numeric](12, 2) NULL,
	[Blocked_LastWaitType] [nvarchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Blocked_Status] [nvarchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Blocked_Program] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Blocked_SQL_Text] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Offending_SPID] [smallint] NOT NULL,
	[Offending_Login] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Offending_NTUser] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Offending_HostName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Offending_WaitType] [bigint] NOT NULL,
	[Offending_LastWaitType] [nvarchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Offending_Status] [nvarchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Offending_Program] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Offending_SQL_Text] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DBName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [pk_BlockingHistory] PRIMARY KEY CLUSTERED 
(
	[BlockingHistoryID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Trigger [dbo].[ti_blockinghistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE TRIGGER [dbo].[ti_blockinghistory] ON [dbo].[BlockingHistory]
AFTER INSERT
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
**	05/03/2013		Michael Rounds			1.2					Changed how variables are gathered in AlertSettings and AlertContacts
**					Volker.Bachmann								Added "[dba]" to the start of all email subject lines
**						from SSC
**	05/28/2013		Michael Rounds			1.2.1				Adjusted HTML table column widths
***************************************************************************************************************/

BEGIN
DECLARE @HTML NVARCHAR(MAX), @QueryValue INT, @QueryValue2 INT, @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @ServerName NVARCHAR(50), @EmailSubject NVARCHAR(100)

SELECT @ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'))

SELECT @QueryValue = CAST(Value AS INT) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue' AND AlertName = 'BlockingAlert'

SELECT @QueryValue2 = CAST(Value AS INT) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue2' AND AlertName = 'BlockingAlert'
	
SELECT @EmailList = EmailList,
		@CellList = CellList	
FROM [dba].dbo.AlertContacts WHERE AlertName = 'BlockingAlert'

SELECT *
INTO #TEMP
FROM Inserted

IF EXISTS (SELECT * FROM #TEMP WHERE CAST(Blocked_WaitTime_Seconds AS DECIMAL) > @QueryValue)
BEGIN

SET	@HTML =
	'<html><head><style type="text/css">
	table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
	th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
	th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
	td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
	</style></head><body>
	<table width="1250"> <tr><th class="header" width="1250">Most Recent Blocking</th></tr></table>
	<table width="1250">
	<tr> 
	<th width="150">Date Stamp</th> 
	<th width="150">Database</th> 	
	<th width="60">Time(ss)</th> 
	<th width="60">Victim SPID</th>
	<th width="145">Victim Login</th>
	<th width="240">Victim SQL Text</th> 
	<th width="60">Blocking SPID</th> 	
	<th width="145">Blocking Login</th>
	<th width="240">Blocking SQL Text</th> 
	</tr>'

SELECT @HTML =  @HTML +   
	'<tr>
	<td width="150" bgcolor="#E0E0E0">' + CAST(DateStamp AS NVARCHAR) +'</td>
	<td width="150" bgcolor="#F0F0F0">' + [DBName] + '</td>
	<td width="60" bgcolor="#E0E0E0">' + CAST(Blocked_WaitTime_Seconds AS NVARCHAR) +'</td>
	<td width="60" bgcolor="#F0F0F0">' + CAST(Blocked_SPID AS NVARCHAR) +'</td>
	<td width="145" bgcolor="#E0E0E0">' + Blocked_Login +'</td>		
	<td width="240" bgcolor="#F0F0F0">' + REPLACE(REPLACE(REPLACE(LEFT(Blocked_SQL_Text,100),'CREATE',''),'TRIGGER',''),'PROCEDURE','') +'</td>
	<td width="60" bgcolor="#E0E0E0">' + CAST(Blocking_SPID AS NVARCHAR) +'</td>
	<td width="145" bgcolor="#F0F0F0">' + Offending_Login +'</td>
	<td width="240" bgcolor="#E0E0E0">' + REPLACE(REPLACE(REPLACE(LEFT(Offending_SQL_Text,100),'CREATE',''),'TRIGGER',''),'PROCEDURE','') +'</td>	
	</tr>'
FROM #TEMP
WHERE CAST(Blocked_WaitTime_Seconds AS DECIMAL) > @QueryValue

SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = '[dba]Blocking on ' + @ServerName + '!'

EXEC msdb..sp_send_dbmail
@recipients= @EmailList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

END

IF @CellList IS NOT NULL
BEGIN
SELECT @EmailSubject = '[dba]Blocking-' + @ServerName

IF @QueryValue2 IS NOT NULL
BEGIN
IF EXISTS (SELECT * FROM #TEMP WHERE CAST(BLOCKED_WAITTIME_SECONDS AS DECIMAL) > @QueryValue2)
BEGIN
SET	@HTML = '<html><head></head><body><table><tr><td>BlockingSPID,</td><td>Login,</td><td>Time</td></tr>'
SELECT @HTML =  @HTML +   
	'<tr><td>' + CAST(OFFENDING_SPID AS NVARCHAR) +',</td><td>' + LEFT(OFFENDING_LOGIN,7) +',</td><td>' + CAST(BLOCKED_WAITTIME_SECONDS AS NVARCHAR) +'</td></tr>'
FROM #TEMP
WHERE BLOCKED_WAITTIME_SECONDS > @QueryValue2
SELECT @HTML =  @HTML + '</table></body></html>'

EXEC msdb..sp_send_dbmail
@recipients= @CellList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'
END
END
END

IF @QueryValue2 IS NULL AND @CellList IS NOT NULL
BEGIN
/*TEXT MESSAGE*/
SET	@HTML = '<html><head></head><body><table><tr><td>BlockingSPID,</td><td>Login,</td><td>Time</td></tr>'
SELECT @HTML =  @HTML +   
	'<tr><td>' + CAST(OFFENDING_SPID AS NVARCHAR) +',</td><td>' + LEFT(OFFENDING_LOGIN,7) +',</td><td>' + CAST(BLOCKED_WAITTIME_SECONDS AS NVARCHAR) +'</td></tr>'
FROM #TEMP
WHERE BLOCKED_WAITTIME_SECONDS > @QueryValue
SELECT @HTML =  @HTML + '</table></body></html>'

EXEC msdb..sp_send_dbmail
@recipients= @CellList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'
END

DROP TABLE #TEMP
END

GO
ALTER TABLE [dbo].[BlockingHistory] ADD  CONSTRAINT [DF_BlockingHistory_DateStamp]  DEFAULT (getdate()) FOR [DateStamp]
GO

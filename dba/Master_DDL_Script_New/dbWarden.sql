/*******************************************************************************************************************************************************
**  Purpose: This script creates a dba database and all objects necessary to setup a database monitoring solution that notifies via email/texting. 
**			Historical data is kept for future trending/reporting.
**
**  Requirements: SQL Server 2005 and above. This script assumes you already have DBMail setup. It will create two new Operators which are used to populate the AlertSettings table.
**				These INSERTS will need to be modified if you are planning on using existing Operators already on your system.
**
**		*****MUST CHANGE*****
**
**		The TABLE INSERTS FOR DATABASESETTINGS MUST BE EDITED PRIOR TO RUNNING THIS SCRIPT (List of Databases)!!!
**		The TABLE INSERTS FOR DBMail OPERATORS MUST BE EDITED PRIOR TO RUNNING THIS SCRIPT (Email Addresses)!!!
**			**** SEARCH/REPLACE "CHANGEME" ****
**
**  
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  06/01/2011		Michael Rounds			1.0					Original Version
**  01/12/2012		Michael Rounds			1.1					Cleanup,many bugfixes  
**  01/17/2012		Michael Rounds			1.1.1				Replaced CURSORS with WHILE LOOPS
**	02/09/2012		Michael Rounds			1.2					New sections to the HealthReport; more compatibility bug fixes
**	02/16/2012		Michael Rounds			1.2.1				Added separate values for Email and Cell notifications; Display Server Uptime; bug fixes
**	02/20/2012		Michael Rounds			1.2.2				Fixed Blocking alert trigger bug when cell list is null
**	02/29/2012		Michael Rounds			1.3					Added CPU stats gathering and Alerting
**  08/31/2012		Michael Rounds			1.4					NVARCHAR now used everywhere. Updated HealthReport to be stand-alone
**	09/11/2012		Michael Rounds			1.4.1				Updated HealthReport, merged Long Running Jobs into Jobs section
**	11/05/2012		Michael Rounds			2.0					New database trigger, many HealthReport changes, small bug fixes, added data dictionary
**	11/27/2012		Michael Rounds			2.1					Tweaked Health Report to show certain elements even if there is no data (eg Trace flags)
**	12/17/2012		Michael Rounds			2.1.1				Changed usp_filestats and rpt_HealthReport so use new logic for gathering file stats (no longer using sysaltfiles)
**	12/27/2012		Michael Rounds			2.1.2				Fixed a bug in usp_filestats and rpt_healthreport gathering data on db's with different coallation
**	12/31/2012		Michael Rounds			2.2 				Added Deadlock section when trace flag 1222 is On.
**	01/07/2013		Michael Rounds			2.2.1				Fixed Divide by zero bug in file stats section
**	01/16/2013		Michael Rounds			2.2.2				Fixed a bug in usp_LongRunningJobs where the LongRunningJobs proc would show up in the alert
**	02/20/2013		Michael Rounds			2.2.3				Fixed a bug in the Deadlock section where some deadlocks weren't be included in the report
**	03/19/2013		Michael Rounds			2.3					Added new proc, usp_TodaysDeadlocks to display current days deadlocks (if tracelog 1222 is on)
**	04/07/2013		Michael Rounds			2.3.1				Expanded KBytesRead and KBytesWritten from NUMERIC 12,2 to 20,2 in table FileStatsHistory
**																Expanded lengths in temp table in usp_FileStats and rpt_HealthReport
**	04/11/2013		Michael Rounds			2.3.1				Changed Health Report to only show last 24 hours worth of File Stats instead of since server restart																
**	04/12/2013		Michael Rounds			2.3.2				Modified usp_MemoryUsageStats, usp_FileStats and rpt_HealthReport to be SQL Server 2012 compatible.
**																Fixed bug in rpt_HealthReport - Changed #TEMPDATES from SELECT INTO - > CREATE, INSERT INTO
**	04/14/2013		Michael Rounds			2.3.3				Expanded Cum_IO_GB in FileStatsHistory, usp_FileStats and rpt_HealthReport to NUMERIC(20,2) FROM NUMERIC(12,2)																
**																REMOVED gen_GetHealthReport stored procs for now. BCP has different behaviour in 2012 that needs tweaking															
**																Fixed update in rpt_HealthReport, CASTing as INT by mistake
********************************************************************************************************************************************************
**
**		:::::CONTENTS:::::
**
**		:::OVERVIEW OF FEATURES:::
**		Blocking Alerts
**		Long Running Queries Alerts
**		Long Running Jobs Alers
**		Database Health Report
**		LDF and TempDB Monitoring and Alerts
**		Performance Statistics Gathering
**		CPU Stats and Alerts
**		Memory Usage Stats Gathering
**		Deadlock Reporting
**
**				:::::OBJECTS:::::
**
**				====MASTER DB:
**				==Procs:
**				dbo.sp_whoisactive == Author: Adam Machanic v11.11
**
**				====MSDB DB:
**				==Operators:
**					Email group
**					Cell(Text) group
**
**				==Job Category:
**					Database Monitoring
**
**				====DATABASE(S) TO MONITOR:
**				==Tables:
**				dbo.SchemaChangeLog
**				
**				==Triggers:
**				dbo.tr_DDL_SchemaChangeLog
**
**				====DBA DB:
**				==Tabes:
**				dbo.AlertSettings
**				dbo.DatabaseSettings
**				dbo.BlockingHistory
**				dbo.HealthReport
**				dbo.JobStatsHistory
**				dbo.FileStatsHistory
**				dbo.MemoryUsageHistory
**				dbo.PerfStatsHistory
**				dbo.QueryHistory
**				dbo.CPUStatsHistory
**				dbo.DataDictionary_Fields
**				dbo.DataDictionary_Tables
**
**				==Triggers:
**				ti_blockinghistory
**
**				==Procs:
**				dbo.usp_CheckBlocking
**				dbo.usp_CheckFiles
**				dbo.usp_FileStats (@InsertFlag BIT = 0)
**				dbo.usp_JobStats (@InsertFlag BIT = 0)
**				dbo.usp_LongRunningJobs
**				dbo.usp_LongRunningQueries
**				dbo.usp_MemoryUsageStats (@InsertFlag BIT = 0)
**				dbo.usp_PerfStats (@InsertFlag BIT = 0) == Autor: Unknown
**				dbo.usp_CPUStats
**				dbo.usp_CPUProcessAlert
**				dbo.rpt_Blocking (@DateRangeInDays INT)
**				dbo.rpt_HealthReport (@Recepients NVARCHAR(200) = NULL, @CC NVARCHAR(200) = NULL, @InsertFlag BIT = 0)
**				dbo.rpt_JobHistory (@JobName NVARCHAR(50), @DateRangeInDays INT)
**				dbo.rpt_Queries (@DateRangeInDays INT)
**				dbo.dd_ApplyDataDictionary
**				dbo.dd_PopulateDataDictionary
**				dbo.dd_ScavengeDataDictionaryFields
**				dbo.dd_ScavengeDataDictionaryTables
**				dbo.dd_TestDataDictionaryFields
**				dbo.dd_TestDataDictionaryTables
**				dbo.dd_UpdateDataDictionaryField
**				dbo.dd_UpdateDataDictionaryTable
**				dbo.sp_ViewTableExtendedProperties
**				dbo.usp_TodaysDeadlocks
**
**				==Jobs: (ALL JOBS DISABLED BY DEFAULT)
**				dba_BlockingAlert (DEFAULT Schedule: Runs every 15 seconds)
**				dba_CheckFiles (DEFAULT Schedule: Runs every 1 hour starting at 12:30am)
**				dba_HealthReport (DEFAULT Schedule: Runs every day at 6:05am)
**				dba_LongRunningJobsAlert (DEFAULT Schedule: Runs every 1 hour starting as 12:05am)
**				dba_LongRunningQueriesAlert (DEFAULT Schedule: Runs every 5 minutes Mon-Sat. SUNDAY Schedule is every 5 minutes from 7:02am - 5:01:59pm)
**				dba_MemoryUsageStats (DEFAULT Schedule: Runs every 15 minutes)
**				dba_PerfStats (DEFAULT Schedule: Runs every 5 minutes)
**				dba_CPUAlert (DEFAULT Schedule: Runs every 5 minutes)
**/
/*=======================================================================================================================
=============================================DBMAIL OPERATORS============================================================
=======================================================================================================================*/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA')
BEGIN
EXEC msdb.dbo.sp_add_operator @name=N'SQL_DBA', 
		@enabled=1,
		@email_address=N'CHANGEME'
END
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA_vtext')
BEGIN
EXEC msdb.dbo.sp_add_operator @name=N'SQL_DBA_vtext', 
		@enabled=1,
		@email_address=N'CHANGEME'
END
GO
/*=======================================================================================================================
=============================================DBA DB CREATE===============================================================
=======================================================================================================================*/
USE [master]
GO

IF NOT EXISTS (SELECT name FROM master..sysdatabases WHERE name = 'dba')
BEGIN
CREATE DATABASE [dba]

ALTER DATABASE [dba] SET RECOVERY SIMPLE
END
GO
/*========================================================================================================================
====================================================DBA TABLES============================================================
========================================================================================================================*/
USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DatabaseSettings' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE dbo.DatabaseSettings (
	[DBName] NVARCHAR(128) NOT NULL
		CONSTRAINT pk_DatabaseSettings
			PRIMARY KEY CLUSTERED ([DBName]),
	SchemaTracking BIT,
	LogFileAlerts BIT,
	LongQueryAlerts BIT,
	Reindex BIT
	)
	
INSERT INTO [dba].dbo.DatabaseSettings ([DBName], SchemaTracking, LogFileAlerts, LongQueryAlerts, Reindex)
SELECT name,1,1,1,1
FROM master..sysdatabases
WHERE [dbid] > 4

END
GO

USE [dba]
GO

IF EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DatabaseSettings' AND TABLE_SCHEMA = 'dbo')
BEGIN

UPDATE [dba].dbo.DatabaseSettings
SET SchemaTracking = 0,
	LogFileAlerts = 0,
	LongQueryAlerts = 0,
	Reindex = 0
WHERE [DBName] IN ('CHANGEME')

END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'AlertSettings' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE [dba].dbo.AlertSettings (
	Name NVARCHAR(50) NOT NULL
		CONSTRAINT pk_AlertSettings
			PRIMARY KEY CLUSTERED (Name),
	QueryValue INT,
	QueryValueDesc NVARCHAR(255),
	QueryValue2 NVARCHAR(255),
	QueryValue2Desc NVARCHAR(255),
	EmailList NVARCHAR(255),
	EmailList2 NVARCHAR(255),
	CellList NVARCHAR(255)
	)

INSERT INTO [dba].dbo.AlertSettings (Name,QueryValue,QueryValueDesc,QueryValue2,QueryValue2Desc,EmailList,CellList)
SELECT 'LongRunningJobs',60,'Seconds',NULL,NULL,(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA'),(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA_vtext') UNION ALL
SELECT 'LongRunningQueries',615,'Seconds',1200,'Seconds',(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA'),(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA_vtext') UNION ALL
SELECT 'BlockingAlert',10,'Seconds',20,'Seconds',(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA'),(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA_vtext') UNION ALL
SELECT 'LogFiles',50,'Percent',20,'Percent',(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA'),(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA_vtext') UNION ALL
SELECT 'TempDB',50,'Percent',20,'Percent',(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA'),(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA_vtext') UNION ALL
SELECT 'HealthReport',1,'NA',NULL,NULL,(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA'),NULL UNION ALL
SELECT 'CPUAlert',85,'Percent',95,'Percent',(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA'),(SELECT email_address FROM msdb.dbo.sysoperators WHERE name = 'SQL_DBA_vtext') 
END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'JobStatsHistory' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE [dba].dbo.JobStatsHistory (
	JobStatsHistoryId INT IDENTITY(1,1) NOT NULL
		CONSTRAINT pk_JobStatsHistory
			PRIMARY KEY CLUSTERED (JobStatsHistoryId),
	JobStatsID INT,
	JobStatsDateStamp DATETIME NOT NULL CONSTRAINT [DF_JobStatsHistory_JobStatsDateStamp] DEFAULT (GETDATE()),
	JobName NVARCHAR(255),
	Category NVARCHAR(255),
	[Enabled] INT,
	StartTime DATETIME,
	StopTime DATETIME,
	[AvgRunTime] NUMERIC(12,2),
	[LastRunTime] NUMERIC(12,2),
	RunTimeStatus NVARCHAR(30),
	LastRunOutcome NVARCHAR(20)
	)
END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'QueryHistory' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE [dba].dbo.QueryHistory (
	[QueryHistoryID] INT IDENTITY(1,1) NOT NULL
			CONSTRAINT pk_QueryHistory
				PRIMARY KEY CLUSTERED ([QueryHistoryID]),
	[Collection_Time] DATETIME NOT NULL,
	[Start_Time] DATETIME NOT NULL,
	[Login_Time] DATETIME NULL,
	[Session_ID] SMALLINT NOT NULL,
	[CPU] INT NULL,
	[Reads] BIGINT NULL,
	[Writes] BIGINT NULL,
	[Physical_Reads] BIGINT NULL,
	[Host_Name] NVARCHAR(128) NULL,
	[Database_Name] NVARCHAR(128) NULL,
	[Login_Name] NVARCHAR(128) NOT NULL,
	[SQL_Text] NVARCHAR(MAX) NULL,
	[Program_Name] NVARCHAR(128)
	)
END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'BlockingHistory' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE [dbo].[BlockingHistory](
	[BlockingHistoryID] INT IDENTITY(1,1) NOT NULL
		CONSTRAINT pk_BlockingHistory
			PRIMARY KEY CLUSTERED ([BlockingHistoryID]),	
	[DateStamp] DATETIME NOT NULL CONSTRAINT [DF_BlockingHistory_DateStamp]  DEFAULT (GETDATE()),
	Blocked_SPID SMALLINT NOT NULL,
	Blocking_SPID SMALLINT NOT NULL,
	Blocked_Login NVARCHAR(128) NOT NULL,
	Blocked_HostName NVARCHAR(128) NOT NULL,
	Blocked_WaitTime_Seconds NUMERIC(12, 2) NULL,
	Blocked_LastWaitType NVARCHAR(32) NOT NULL,
	Blocked_Status NVARCHAR(30) NOT NULL,
	Blocked_Program NVARCHAR(128) NOT NULL,
	Blocked_SQL_Text NVARCHAR(MAX) NULL,
	Offending_SPID SMALLINT NOT NULL,
	Offending_Login NVARCHAR(128) NOT NULL,
	Offending_NTUser NVARCHAR(128) NOT NULL,
	Offending_HostName NVARCHAR(128) NOT NULL,
	Offending_WaitType BIGINT NOT NULL,
	Offending_LastWaitType NVARCHAR(32) NOT NULL,
	Offending_Status NVARCHAR(30) NOT NULL,
	Offending_Program NVARCHAR(128) NOT NULL,
	Offending_SQL_Text NVARCHAR(MAX) NULL,
	[DBName] NVARCHAR(128) NULL
	)

END
GO

USE [dba]
GO

IF NOT EXISTS	(SELECT *
				FROM sys.triggers
				WHERE [name] = 'ti_blockinghistory')
BEGIN
	EXEC ('CREATE TRIGGER ti_blockinghistory ON BlockingHistory INSTEAD OF INSERT AS SELECT 1')
END
GO

ALTER TRIGGER [dbo].[ti_blockinghistory] ON [dbo].[BlockingHistory]
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
***************************************************************************************************************/

BEGIN
DECLARE @HTML NVARCHAR(MAX), @QueryValue INT, @QueryValue2 INT, @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @ServerName NVARCHAR(50), @EmailSubject NVARCHAR(100)

SELECT @ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'))

SELECT @QueryValue = QueryValue,
		@QueryValue2 = QueryValue2,
		@EmailList = EmailList,
		@CellList = CellList 
FROM [dba].dbo.AlertSettings WHERE Name = 'BlockingAlert'

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
	<table width="1150"> <tr><th class="header" width="1150">Most Recent Blocking</th></tr></table>
	<table width="1150">
	<tr> 
	<th width="150">Date Stamp</th> 
	<th width="150">Database</th> 	
	<th width="60">Time(ss)</th> 
	<th width="60">Victim SPID</th>
	<th width="145">Victim Login</th>
	<th width="190">Victim SQL Text</th> 
	<th width="60">Blocking SPID</th> 	
	<th width="145">Blocking Login</th>
	<th width="190">Blocking SQL Text</th> 
	</tr>'

SELECT @HTML =  @HTML +   
	'<tr>
	<td width="150" bgcolor="#E0E0E0">' + CAST(DateStamp AS NVARCHAR) +'</td>
	<td width="130" bgcolor="#F0F0F0">' + [DBName] + '</td>
	<td width="60" bgcolor="#E0E0E0">' + CAST(Blocked_WaitTime_Seconds AS NVARCHAR) +'</td>
	<td width="60" bgcolor="#F0F0F0">' + CAST(Blocked_SPID AS NVARCHAR) +'</td>
	<td width="145" bgcolor="#E0E0E0">' + Blocked_Login +'</td>		
	<td width="200" bgcolor="#F0F0F0">' + REPLACE(REPLACE(REPLACE(LEFT(Blocked_SQL_Text,100),'CREATE',''),'TRIGGER',''),'PROCEDURE','') +'</td>
	<td width="60" bgcolor="#E0E0E0">' + CAST(Blocking_SPID AS NVARCHAR) +'</td>
	<td width="145" bgcolor="#F0F0F0">' + Offending_Login +'</td>
	<td width="200" bgcolor="#E0E0E0">' + REPLACE(REPLACE(REPLACE(LEFT(Offending_SQL_Text,100),'CREATE',''),'TRIGGER',''),'PROCEDURE','') +'</td>	
	</tr>'
FROM #TEMP
WHERE CAST(Blocked_WaitTime_Seconds AS DECIMAL) > @QueryValue

SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'Blocking on ' + @ServerName + '!'

EXEC msdb.dbo.sp_send_dbmail
@recipients= @EmailList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

END

IF @CellList IS NOT NULL
BEGIN
SELECT @EmailSubject = 'Blocking-' + @ServerName

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

EXEC msdb.dbo.sp_send_dbmail
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

EXEC msdb.dbo.sp_send_dbmail
@recipients= @CellList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'
END

DROP TABLE #TEMP
END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FileStatsHistory' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE dbo.FileStatsHistory (
	FileStatsHistoryID INT IDENTITY(1,1) NOT NULL
		CONSTRAINT pk_FileStatsHistory
			PRIMARY KEY CLUSTERED (FileStatsHistoryID),
	FileStatsID INT, 
	FileStatsDateStamp DATETIME NOT NULL CONSTRAINT DF_FileStatsHistory_DateStamp DEFAULT (GETDATE()),
		[DBName] NVARCHAR(128),
	[DBID] INT,
	[FileID] INT,
	[FileName] NVARCHAR(255),
	[LogicalFileName] NVARCHAR(255),
	[VLFCount] INT,
	DriveLetter NCHAR(1),
	FileMBSize NVARCHAR(30),
	[FileMaxSize] NVARCHAR(30),
	FileGrowth NVARCHAR(30),
	FileMBUsed NVARCHAR(30),
	FileMBEmpty NVARCHAR(30),
	FilePercentEmpty NUMERIC(12,2),
	LargeLDF INT,
	[FileGroup] NVARCHAR(100),
	NumberReads NVARCHAR(30),
	KBytesRead NUMERIC(20,2),
	NumberWrites NVARCHAR(30),
	KBytesWritten NUMERIC(20,2),
	IoStallReadMS NVARCHAR(30),
	IoStallWriteMS NVARCHAR(30),
	Cum_IO_GB NUMERIC(20,2),
	IO_Percent NUMERIC(12,2)
	)
END
GO

--This was added on 4/14/2013
USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'FileStatsHistory' AND TABLE_SCHEMA = 'dbo' 
AND COLUMN_NAME = 'Cum_IO_GB' AND NUMERIC_PRECISION=20)
BEGIN
ALTER TABLE dbo.FileStatsHistory
ALTER COLUMN Cum_IO_GB NUMERIC(20,2)
END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'HealthReport' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE [dba].dbo.HealthReport (
	HealthReportID INT IDENTITY(1,1) NOT NULL 
		CONSTRAINT PK_HealthReport
			PRIMARY KEY CLUSTERED (HealthReportID),
	DateStamp DATETIME NOT NULL CONSTRAINT [DF_HealthReport_datestamp] DEFAULT (GETDATE()),
	GeneratedHTML NVARCHAR(MAX)
	)
END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'PerfStatsHistory' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE [dbo].[PerfStatsHistory](
	[PerfStatsHistoryID] [INT] IDENTITY(1,1) NOT NULL
		CONSTRAINT PK_PerfStatsHistory
			PRIMARY KEY CLUSTERED (PerfStatsHistoryID),
	[BufferCacheHitRatio] NUMERIC(38, 13) NULL,
	[PageLifeExpectency] BIGINT NULL,
	[BatchRequestsPerSecond] BIGINT NULL,
	[CompilationsPerSecond] BIGINT NULL,
	[ReCompilationsPerSecond] BIGINT NULL,
	[UserConnections] BIGINT NULL,
	[LockWaitsPerSecond] BIGINT NULL,
	[PageSplitsPerSecond] BIGINT NULL,
	[ProcessesBlocked] BIGINT NULL,
	[CheckpointPagesPerSecond] BIGINT NULL,
	[StatDate] DATETIME NOT NULL
	)
END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'MemoryUsageHistory' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE dbo.MemoryUsageHistory (
	MemoryUsageHistoryID INT IDENTITY(1,1) NOT NULL
		CONSTRAINT pk_MemoryUsageHistory
			PRIMARY KEY CLUSTERED (MemoryUsageHistoryID),
	DateStamp DATETIME NOT NULL CONSTRAINT [DF_MemoryUsageHistory_DateStamp] DEFAULT (GETDATE()),
	SystemPhysicalMemoryMB NVARCHAR(20),
	SystemVirtualMemoryMB NVARCHAR(20),
	DBUsageMB NVARCHAR(20),
	DBMemoryRequiredMB NVARCHAR(20),
	BufferCacheHitRatio NVARCHAR(20),
	BufferPageLifeExpectancy NVARCHAR(20),	
	BufferPoolCommitMB NVARCHAR(20),
	BufferPoolCommitTgtMB NVARCHAR(20),
	BufferPoolTotalPagesMB NVARCHAR(20),
	BufferPoolDataPagesMB NVARCHAR(20),
	BufferPoolFreePagesMB NVARCHAR(20),
	BufferPoolReservedPagesMB NVARCHAR(20),
	BufferPoolStolenPagesMB NVARCHAR(20),
	BufferPoolPlanCachePagesMB NVARCHAR(20),
	DynamicMemConnectionsMB NVARCHAR(20),
	DynamicMemLocksMB NVARCHAR(20),
	DynamicMemSQLCacheMB NVARCHAR(20),
	DynamicMemQueryOptimizeMB NVARCHAR(20),
	DynamicMemHashSortIndexMB NVARCHAR(20),
	CursorUsageMB NVARCHAR(20)
	)
END
GO

USE [dba]
GO

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CPUStatsHistory' AND TABLE_SCHEMA = 'dbo')
BEGIN
CREATE TABLE dbo.CPUStatsHistory (
	CPUStatsHistoryID INT IDENTITY NOT NULL
			CONSTRAINT [PK_CPUStatsHistory]
				PRIMARY KEY CLUSTERED (CPUStatsHistoryID),
	SQLProcessPercent INT,
	SystemIdleProcessPercent INT,
	OtherProcessPerecnt INT,
	DateStamp DATETIME
	)
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='DataDictionary_Tables')
BEGIN
CREATE TABLE dbo.DataDictionary_Tables(
	SchemaName SYSNAME NOT NULL,
	TableName SYSNAME NOT NULL,
	TableDescription VARCHAR(4000) NOT NULL
		CONSTRAINT DF_DataDictionary_TableDescription DEFAULT (''),
		CONSTRAINT PK_DataDictionary_Tables 
			PRIMARY KEY CLUSTERED (SchemaName,TableName)
	)
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='DataDictionary_Fields')
BEGIN
CREATE TABLE dbo.DataDictionary_Fields(
	SchemaName SYSNAME NOT NULL,
	TableName SYSNAME NOT NULL,
	FieldName SYSNAME NOT NULL,
	FieldDescription VARCHAR(4000) NOT NULL
		CONSTRAINT DF_DataDictionary_FieldDescription DEFAULT (''),
		CONSTRAINT PK_DataDictionary_Fields 
			PRIMARY KEY CLUSTERED (SchemaName,TableName,FieldName)
)
END
GO
/*========================================================================================================================
====================================================DBA INDEXES===========================================================
========================================================================================================================*/
IF NOT EXISTS (SELECT name FROM SYSINDEXES WHERE NAME = 'IDX_JobStatHistory_JobStatsID_INC')
BEGIN
CREATE INDEX IDX_JobStatHistory_JobStatsID_INC
	ON [dba].[dbo].[JobStatsHistory] ([JobStatsID]) INCLUDE ([JobStatsHistoryId])
END
GO

IF NOT EXISTS (SELECT name FROM SYSINDEXES WHERE NAME = 'IDX_JobStatHistory_JobStatsID_Status_RunTime_INC')
BEGIN
CREATE INDEX IDX_JobStatHistory_JobStatsID_Status_RunTime_INC 
	ON [dba].[dbo].[JobStatsHistory] ([JobStatsID], [RunTimeStatus],[LastRunTime]) INCLUDE ([StopTime])
END
GO

IF NOT EXISTS (SELECT name FROM SYSINDEXES WHERE NAME = 'IDX_JobStatHistory_JobStatsID_Status_RunTime')
BEGIN
CREATE INDEX IDX_JobStatHistory_JobStatsID_Status_RunTime 
	ON [dba].[dbo].[JobStatsHistory] ([JobStatsID], [RunTimeStatus],[LastRunTime])
END
GO
/*========================================================================================================================
===========================================SCHEMA CHANGE TRACKING TABLE AND TRIGGER=======================================
========================================================================================================================*/
DECLARE @DBName NVARCHAR(128)

CREATE TABLE #TEMP ([DBName] NVARCHAR(128), [Status] INT)

INSERT INTO #TEMP ([DBName], [Status])
SELECT [DBName], 0
FROM [dba].dbo.DatabaseSettings WHERE SchemaTracking = 1 AND [DBName] NOT LIKE 'AdventureWorks%'

SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP WHERE [Status] = 0)

WHILE @DBName IS NOT NULL
BEGIN

DECLARE @SQL NVARCHAR(MAX)

SET @SQL = 
'USE ' + '[' + @DBName + ']' +';

IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''SchemaChangeLog'' AND TABLE_SCHEMA = ''dbo'')
BEGIN
CREATE TABLE [dbo].[SchemaChangeLog](
	[SchemaChangeLogID] INT IDENTITY(1,1) NOT NULL
		CONSTRAINT PK_SchemaChangeLog
			PRIMARY KEY CLUSTERED (SchemaChangeLogID),	
	[CreateDate] DATETIME NULL,
	[LoginName] SYSNAME NULL,
	[ComputerName] SYSNAME NULL,
	[DBName] SYSNAME NOT NULL,
	[SQLEvent] SYSNAME NOT NULL,
	[Schema] SYSNAME NULL,
	[ObjectName] SYSNAME NULL,
	[SQLCmd] NVARCHAR(MAX) NOT NULL,
	[XmlEvent] XML NOT NULL
	)
END;

DECLARE @triggersql1 NVARCHAR(MAX)

SET @triggersql1 = ''IF NOT EXISTS (SELECT *
				FROM sys.triggers
				WHERE [name] = ''''tr_DDL_SchemaChangeLog'''')
BEGIN
	EXEC (''''CREATE TRIGGER tr_DDL_SchemaChangeLog ON DATABASE FOR CREATE_TABLE AS SELECT 1'''')
END;''

EXEC(@triggersql1)

DECLARE @triggersql2 NVARCHAR(MAX)

SET @triggersql2 = ''ALTER TRIGGER [tr_DDL_SchemaChangeLog] ON DATABASE 
FOR DDL_DATABASE_LEVEL_EVENTS AS 

    SET NOCOUNT ON

    DECLARE @data XML
    DECLARE @schema SYSNAME
    DECLARE @object SYSNAME
    DECLARE @eventType SYSNAME

    SET @data = EVENTDATA()
    SET @eventType = @data.value(''''(/EVENT_INSTANCE/EventType)[1]'''', ''''SYSNAME'''')
    SET @schema = @data.value(''''(/EVENT_INSTANCE/SchemaName)[1]'''', ''''SYSNAME'''')
    SET @object = @data.value(''''(/EVENT_INSTANCE/ObjectName)[1]'''', ''''SYSNAME'''') 

    INSERT [dbo].[SchemaChangeLog] 
        (
        [CreateDate],
        [LoginName], 
        [ComputerName],
        [DBName],
        [SQLEvent], 
        [Schema], 
        [ObjectName], 
        [SQLCmd], 
        [XmlEvent]
        ) 
    SELECT
        GETDATE(),
        SUSER_NAME(), 
		HOST_NAME(),   
        @data.value(''''(/EVENT_INSTANCE/DatabaseName)[1]'''', ''''SYSNAME''''),
        @eventType, 
        @schema, 
        @object, 
        @data.value(''''(/EVENT_INSTANCE/TSQLCommand)[1]'''', ''''NVARCHAR(MAX)''''), 
        @data
;''

EXEC(@triggersql2)
'

EXEC(@SQL)

UPDATE #TEMP
SET [Status] = 1
WHERE [DBName] = @DBName

SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP WHERE [Status] = 0)

END

DROP TABLE #TEMP
GO
/*========================================================================================================================
======================================================DBA PROCS===========================================================
========================================================================================================================*/
USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_JobStats' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_JobStats AS SELECT 1')
END
GO

ALTER PROC [dbo].[usp_JobStats] (@InsertFlag BIT = 0)
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.0				Comments creation
**  03/13/2012		Michael Rounds			1.1				Added join to syscategories to pull in Category name
***************************************************************************************************************/

BEGIN

SELECT sj.job_id, 
		sj.name,
		sc.name AS Category,
		sj.[Enabled], 
		sjs.last_run_outcome,
        (SELECT MAX(run_date) 
			FROM msdb..sysjobhistory(nolock) sjh 
			WHERE sjh.job_id = sj.job_id) AS last_run_date
INTO #TEMP
FROM msdb..sysjobs(nolock) sj
JOIN msdb..sysjobservers(nolock) sjs
    ON sjs.job_id = sj.job_id
JOIN msdb..syscategories sc
	ON sj.category_id = sc.category_id	

SELECT
	t.name AS JobName,
	t.Category,
	t.[Enabled],
	MAX(ja.start_execution_date) AS [StartTime],
	MAX(ja.stop_execution_date) AS [StopTime],
	COALESCE(AvgRunTime,0) AS AvgRunTime,
	CASE 
		WHEN ja.stop_execution_date IS NULL THEN DATEDIFF(ss,ja.start_execution_date,GETDATE())
		ELSE DATEDIFF(ss,ja.start_execution_date,ja.stop_execution_date) END AS [LastRunTime],
	CASE 
			WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL THEN
				CASE WHEN DATEDIFF(ss,ja.start_execution_date,GETDATE())
					> (AvgRunTime + AvgRunTime * .25) THEN 'LongRunning-NOW'				
				ELSE 'NormalRunning-NOW'
				END
			WHEN DATEDIFF(ss,ja.start_execution_date,ja.stop_execution_date) 
				> (AvgRunTime + AvgRunTime * .25) THEN 'LongRunning-History'
			WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NULL THEN 'NA'
			ELSE 'NormalRunning-History'
	END AS [RunTimeStatus],	
	CASE
		WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL THEN 'InProcess'
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 3 THEN 'CANCELLED'
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 0 THEN 'ERROR'			
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 1 THEN 'SUCCESS'			
		ELSE 'NA'
	END AS [LastRunOutcome]
INTO #TEMP2
FROM #TEMP AS t
LEFT OUTER
JOIN (SELECT MAX(session_id) as session_id,job_id FROM msdb.dbo.sysjobactivity(nolock) WHERE run_requested_date IS NOT NULL GROUP BY job_id) AS ja2
	ON t.job_id = ja2.job_id
LEFT OUTER
JOIN msdb.dbo.sysjobactivity(nolock) ja
	ON ja.session_id = ja2.session_id and ja.job_id = t.job_id
LEFT OUTER 
JOIN (SELECT job_id,
			AVG	((run_duration/10000 * 3600) + ((run_duration%10000)/100*60) + (run_duration%10000)%100) + 	STDEV ((run_duration/10000 * 3600) + ((run_duration%10000)/100*60) + (run_duration%10000)%100) AS [AvgRuntime]
		FROM msdb..sysjobhistory(nolock)
		WHERE step_id = 0 AND run_status = 1 and run_duration >= 0
		GROUP BY job_id) art 
	ON t.job_id = art.job_id
GROUP BY t.name,t.Category,t.[Enabled],t.last_run_outcome,ja.start_execution_date,ja.stop_execution_date,AvgRunTime
ORDER BY t.name

SELECT * FROM #TEMP2

IF @InsertFlag = 1
BEGIN

INSERT INTO [dba].dbo.JobStatsHistory (JobName,Category,[Enabled],StartTime,StopTime,[AvgRunTime],[LastRunTime],RunTimeStatus,LastRunOutcome) 
SELECT JobName,Category,[Enabled],StartTime,StopTime,[AvgRunTime],[LastRunTime],RunTimeStatus,LastRunOutcome
FROM #TEMP2

UPDATE [dba].dbo.JobStatsHistory
SET JobStatsID = (SELECT COALESCE(MAX(JobStatsID),0) + 1 FROM [dba].dbo.JobStatsHistory)
WHERE JobStatsID IS NULL

END
DROP TABLE #TEMP
DROP TABLE #TEMP2
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_PerfStats' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_PerfStats AS SELECT 1')
END
GO

ALTER PROC dbo.usp_PerfStats (@InsertFlag BIT = 0)
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.0					Comments creation
**	08/31/2012		Michael Rounds			1.1					Changed to use temp tables, Changed VARCHAR to NVARCHAR
***************************************************************************************************************/

BEGIN
SET NOCOUNT ON
 
DECLARE @BatchRequestsPerSecond BIGINT, 
		@CompilationsPerSecond BIGINT, 
		@ReCompilationsPerSecond BIGINT, 
		@LockWaitsPerSecond BIGINT, 
		@PageSplitsPerSecond BIGINT, 
		@CheckpointPagesPerSecond BIGINT, 
		@stat_date DATETIME,
		@PerfStatsID INT

CREATE TABLE #RatioStatsX (
	[object_name] NVARCHAR(128),
    [counter_name] NVARCHAR(128),
    [instance_name] NVARCHAR(128),
    [cntr_value] BIGINT,
    [cntr_type] INT
    )

CREATE TABLE #RatioStatsY (
    [object_name] NVARCHAR(128),
    [counter_name] NVARCHAR(128),
    [instance_name] NVARCHAR(128),
    [cntr_value] BIGINT,
    [cntr_type] INT
    )

SET @stat_date = GETDATE();
 
INSERT INTO #RatioStatsX ([object_name],[counter_name],[instance_name],[cntr_value],[cntr_type])
SELECT [object_name],[counter_name],[instance_name],[cntr_value],[cntr_type] 
FROM sys.dm_os_performance_counters;
 
SELECT TOP 1 @BatchRequestsPerSecond = cntr_value
FROM #RatioStatsX
WHERE counter_name = 'Batch Requests/sec'
AND object_name LIKE '%SQL Statistics%';

SELECT TOP 1 @CompilationsPerSecond = cntr_value
FROM #RatioStatsX
WHERE counter_name = 'SQL Compilations/sec'
AND object_name LIKE '%SQL Statistics%';

SELECT TOP 1 @ReCompilationsPerSecond = cntr_value
FROM #RatioStatsX
WHERE counter_name = 'SQL Re-Compilations/sec'
AND object_name LIKE '%SQL Statistics%';

SELECT TOP 1 @LockWaitsPerSecond = cntr_value
FROM #RatioStatsX
WHERE counter_name = 'Lock Waits/sec'
AND instance_name = '_Total'
AND object_name LIKE '%Locks%';

SELECT TOP 1 @PageSplitsPerSecond = cntr_value
FROM #RatioStatsX
WHERE counter_name = 'Page Splits/sec'
AND object_name LIKE '%Access Methods%'; 

SELECT TOP 1 @CheckpointPagesPerSecond = cntr_value
FROM #RatioStatsX
WHERE counter_name = 'Checkpoint Pages/sec'
AND object_name LIKE '%Buffer Manager%';                                         
 
WAITFOR DELAY '00:00:01'

INSERT INTO #RatioStatsY ([object_name],[counter_name],[instance_name],[cntr_value],[cntr_type])
SELECT [object_name],[counter_name],[instance_name],[cntr_value],[cntr_type]
FROM sys.dm_os_performance_counters

SELECT (a.cntr_value * 1.0 / b.cntr_value) * 100.0 [BufferCacheHitRatio],
	c.cntr_value  AS [PageLifeExpectency],
	d.[BatchRequestsPerSecond],
	e.[CompilationsPerSecond],
	f.[ReCompilationsPerSecond],
	g.cntr_value AS [UserConnections],
	h.LockWaitsPerSecond,
	i.PageSplitsPerSecond,
	j.cntr_value AS [ProcessesBlocked],
	k.CheckpointPagesPerSecond,
	GETDATE() AS StatDate                           
INTO #TEMP
FROM (SELECT * FROM #RatioStatsY
               WHERE counter_name = 'Buffer cache hit ratio'
               AND object_name LIKE '%Buffer Manager%') a  
     CROSS JOIN  
      (SELECT * FROM #RatioStatsY
                WHERE counter_name = 'Buffer cache hit ratio base'
                AND object_name LIKE '%Buffer Manager%') b    
     CROSS JOIN
      (SELECT * FROM #RatioStatsY
                WHERE counter_name = 'Page life expectancy '
                AND object_name LIKE '%Buffer Manager%') c
     CROSS JOIN
     (SELECT (cntr_value - @BatchRequestsPerSecond) /
                     (CASE WHEN DATEDIFF(ss,@stat_date, GETDATE()) = 0
                           THEN  1
                           ELSE DATEDIFF(ss,@stat_date, GETDATE()) END) AS [BatchRequestsPerSecond]
                FROM #RatioStatsY
                WHERE counter_name = 'Batch Requests/sec'
                AND object_name LIKE '%SQL Statistics%') d   
     CROSS JOIN
     (SELECT (cntr_value - @CompilationsPerSecond) /
                     (CASE WHEN DATEDIFF(ss,@stat_date, GETDATE()) = 0
                           THEN  1
                           ELSE DATEDIFF(ss,@stat_date, GETDATE()) END) AS [CompilationsPerSecond]
                FROM #RatioStatsY
                WHERE counter_name = 'SQL Compilations/sec'
                AND object_name LIKE '%SQL Statistics%') e 
     CROSS JOIN
     (SELECT (cntr_value - @ReCompilationsPerSecond) /
                     (CASE WHEN DATEDIFF(ss,@stat_date, GETDATE()) = 0
                           THEN  1
                           ELSE DATEDIFF(ss,@stat_date, GETDATE()) END) AS [ReCompilationsPerSecond]
                FROM #RatioStatsY
                WHERE counter_name = 'SQL Re-Compilations/sec'
                AND object_name LIKE '%SQL Statistics%') f
     CROSS JOIN
     (SELECT * FROM #RatioStatsY
               WHERE counter_name = 'User Connections'
               AND object_name LIKE '%General Statistics%') g
     CROSS JOIN
     (SELECT (cntr_value - @LockWaitsPerSecond) /
                     (CASE WHEN DATEDIFF(ss,@stat_date, GETDATE()) = 0
                           THEN  1
                           ELSE DATEDIFF(ss,@stat_date, GETDATE()) END) AS [LockWaitsPerSecond]
                FROM #RatioStatsY
                WHERE counter_name = 'Lock Waits/sec'
                AND instance_name = '_Total'
                AND object_name LIKE '%Locks%') h
     CROSS JOIN
     (SELECT (cntr_value - @PageSplitsPerSecond) /
                     (CASE WHEN DATEDIFF(ss,@stat_date, GETDATE()) = 0
                           THEN  1
                           ELSE DATEDIFF(ss,@stat_date, GETDATE()) END) AS [PageSplitsPerSecond]
                FROM #RatioStatsY
                WHERE counter_name = 'Page Splits/sec'
                AND object_name LIKE '%Access Methods%') i
     CROSS JOIN
     (SELECT * FROM #RatioStatsY
               WHERE counter_name = 'Processes blocked'
               AND object_name LIKE '%General Statistics%') j
     CROSS JOIN
     (SELECT (cntr_value - @CheckpointPagesPerSecond) /
                     (CASE WHEN DATEDIFF(ss,@stat_date, GETDATE()) = 0
                           THEN  1
                           ELSE DATEDIFF(ss,@stat_date, GETDATE()) END) AS [CheckpointPagesPerSecond]
                FROM #RatioStatsY
                WHERE counter_name = 'Checkpoint Pages/sec'
                AND object_name LIKE '%Buffer Manager%') k
                
DROP TABLE #RatioStatsX
DROP TABLE #RatioStatsY
SELECT * FROM #TEMP

IF @InsertFlag = 1
BEGIN
INSERT INTO [dba].dbo.PerfStatsHistory (BufferCacheHitRatio, PageLifeExpectency, BatchRequestsPerSecond, CompilationsPerSecond, ReCompilationsPerSecond, UserConnections, LockWaitsPerSecond, PageSplitsPerSecond, ProcessesBlocked, CheckpointPagesPerSecond, StatDate)
SELECT BufferCacheHitRatio, PageLifeExpectency, BatchRequestsPerSecond, CompilationsPerSecond, ReCompilationsPerSecond, UserConnections, LockWaitsPerSecond, PageSplitsPerSecond, ProcessesBlocked, CheckpointPagesPerSecond, StatDate
FROM #TEMP
END
DROP TABLE #TEMP
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_MemoryUsageStats' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_MemoryUsageStats AS SELECT 1')
END
GO

ALTER PROC dbo.usp_MemoryUsageStats (@InsertFlag BIT = 0)
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
**	04/12/2013		Michael Rounds			1.2					Added SQL Server 2012 compatibility - column differences in sys.dm_os_sys_info
***************************************************************************************************************/

BEGIN

SET NOCOUNT ON 

DECLARE @pg_size INT, @Instancename NVARCHAR(50), @MemoryUsageHistoryID INT, @SQLVer NVARCHAR(20)

SELECT @pg_size = low from master..spt_values where number = 1 and type = 'E'

SELECT @Instancename = LEFT([object_name], (CHARINDEX(':',[object_name]))) FROM sys.dm_os_performance_counters WHERE counter_name = 'Buffer cache hit ratio'

CREATE TABLE #TEMP (
	DateStamp DATETIME NOT NULL CONSTRAINT [DF_TEMP_TEMP] DEFAULT (GETDATE()),
	SystemPhysicalMemoryMB NVARCHAR(20),
	SystemVirtualMemoryMB NVARCHAR(20),
	DBUsageMB NVARCHAR(20),
	DBMemoryRequiredMB NVARCHAR(20),
	BufferCacheHitRatio NVARCHAR(20),
	BufferPageLifeExpectancy NVARCHAR(20),	
	BufferPoolCommitMB NVARCHAR(20),
	BufferPoolCommitTgtMB NVARCHAR(20),
	BufferPoolTotalPagesMB NVARCHAR(20),
	BufferPoolDataPagesMB NVARCHAR(20),
	BufferPoolFreePagesMB NVARCHAR(20),
	BufferPoolReservedPagesMB NVARCHAR(20),
	BufferPoolStolenPagesMB NVARCHAR(20),
	BufferPoolPlanCachePagesMB NVARCHAR(20),
	DynamicMemConnectionsMB NVARCHAR(20),
	DynamicMemLocksMB NVARCHAR(20),
	DynamicMemSQLCacheMB NVARCHAR(20),
	DynamicMemQueryOptimizeMB NVARCHAR(20),
	DynamicMemHashSortIndexMB NVARCHAR(20),
	CursorUsageMB NVARCHAR(20)
	)

SELECT @SQLVer = LEFT(CONVERT(NVARCHAR(20),SERVERPROPERTY('productversion')),4)

IF CAST(@SQLVer AS NUMERIC(4,2)) < 11
BEGIN
-- (SQL 2008R2 And Below)
EXEC sp_executesql
	N'INSERT INTO #TEMP (SystemPhysicalMemoryMB, SystemVirtualMemoryMB, BufferPoolCommitMB, BufferPoolCommitTgtMB)
	SELECT physical_memory_in_bytes/1048576.0 as [SystemPhysicalMemoryMB],
		 virtual_memory_in_bytes/1048576.0 as [SystemVirtualMemoryMB],
		 (bpool_committed*8)/1024.0 as [BufferPoolCommitMB],
		 (bpool_commit_target*8)/1024.0 as [BufferPoolCommitTgtMB]
	FROM sys.dm_os_sys_info'	
END
ELSE BEGIN
-- (SQL 2012 And Above)
EXEC sp_executesql
	N'INSERT INTO #TEMP (SystemPhysicalMemoryMB, SystemVirtualMemoryMB, BufferPoolCommitMB, BufferPoolCommitTgtMB)
	SELECT physical_memory_kb/1024.0 as [SystemPhysicalMemoryMB],
		virtual_memory_kb/1024.0 as [SystemVirtualMemoryMB],
		(committed_kb)/1024.0 as [BufferPoolCommitMB],
		(committed_target_kb)/1024.0 as [BufferPoolCommitTgtMB]
FROM sys.dm_os_sys_info'
END

UPDATE #TEMP
SET [DBUsageMB] = (cntr_value/1024.0)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Total Server Memory (KB)'

UPDATE #TEMP
SET [DBMemoryRequiredMB] = (cntr_value/1024.0)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Target Server Memory (KB)'

UPDATE #TEMP
SET [BufferPoolTotalPagesMB] = ((cntr_value*@pg_size)/1048576.0)
FROM sys.dm_os_performance_counters
WHERE object_name= @Instancename+'Buffer Manager' and counter_name = 'Total pages' 

UPDATE #TEMP
SET [BufferPoolDataPagesMB] = ((cntr_value*@pg_size)/1048576.0)
FROM sys.dm_os_performance_counters
WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Database pages' 

UPDATE #TEMP
SET [BufferPoolFreePagesMB] = ((cntr_value*@pg_size)/1048576.0)
FROM sys.dm_os_performance_counters
WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Free pages'

UPDATE #TEMP
SET [BufferPoolReservedPagesMB] = ((cntr_value*@pg_size)/1048576.0)
FROM sys.dm_os_performance_counters
WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Reserved pages'

UPDATE #TEMP
SET [BufferPoolStolenPagesMB] = ((cntr_value*@pg_size)/1048576.0)
FROM sys.dm_os_performance_counters
WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Stolen pages'

UPDATE #TEMP
SET [BufferPoolPlanCachePagesMB] = ((cntr_value*@pg_size)/1048576.0)
FROM sys.dm_os_performance_counters
WHERE object_name=@Instancename+'Plan Cache' and counter_name = 'Cache Pages'  and instance_name = '_Total'

UPDATE #TEMP
SET [DynamicMemConnectionsMB] = (cntr_value/1024.0)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Connection Memory (KB)'

UPDATE #TEMP
SET [DynamicMemLocksMB] = (cntr_value/1024.0)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Lock Memory (KB)'

UPDATE #TEMP
SET [DynamicMemSQLCacheMB] = (cntr_value/1024.0)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'SQL Cache Memory (KB)'

UPDATE #TEMP
SET [DynamicMemQueryOptimizeMB] = (cntr_value/1024.0)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Optimizer Memory (KB) '

UPDATE #TEMP
SET [DynamicMemHashSortIndexMB] = (cntr_value/1024.0)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Granted Workspace Memory (KB) '

UPDATE #TEMP
SET [CursorUsageMB] = (cntr_value/1024.0)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Cursor memory usage' and instance_name = '_Total'

UPDATE #TEMP
SET [BufferCacheHitRatio] = (a.cntr_value * 1.0 / b.cntr_value) * 100.0
FROM sys.dm_os_performance_counters  a
JOIN  (SELECT cntr_value,OBJECT_NAME 
		FROM sys.dm_os_performance_counters  
		WHERE counter_name = 'Buffer cache hit ratio base'
		AND OBJECT_NAME = 'SQLServer:Buffer Manager') b 
ON  a.OBJECT_NAME = b.OBJECT_NAME
WHERE a.counter_name = 'Buffer cache hit ratio'
AND a.OBJECT_NAME = 'SQLServer:Buffer Manager'

UPDATE #TEMP
SET [BufferPageLifeExpectancy] = cntr_value
FROM sys.dm_os_performance_counters  
WHERE counter_name = 'Page life expectancy'
AND OBJECT_NAME = 'SQLServer:Buffer Manager'

SELECT SystemPhysicalMemoryMB, SystemVirtualMemoryMB, DBUsageMB, DBMemoryRequiredMB, BufferCacheHitRatio, BufferPageLifeExpectancy, BufferPoolCommitMB, BufferPoolCommitTgtMB, BufferPoolTotalPagesMB, BufferPoolDataPagesMB, BufferPoolFreePagesMB, BufferPoolReservedPagesMB, BufferPoolStolenPagesMB, BufferPoolPlanCachePagesMB, DynamicMemConnectionsMB, DynamicMemLocksMB, DynamicMemSQLCacheMB, DynamicMemQueryOptimizeMB, DynamicMemHashSortIndexMB, CursorUsageMB FROM #TEMP

IF @InsertFlag = 1
BEGIN

INSERT INTO [dba].dbo.MemoryUsageHistory (SystemPhysicalMemoryMB, SystemVirtualMemoryMB, DBUsageMB, DBMemoryRequiredMB, BufferCacheHitRatio, BufferPageLifeExpectancy, BufferPoolCommitMB, BufferPoolCommitTgtMB, BufferPoolTotalPagesMB, BufferPoolDataPagesMB, BufferPoolFreePagesMB, BufferPoolReservedPagesMB, BufferPoolStolenPagesMB, BufferPoolPlanCachePagesMB, DynamicMemConnectionsMB, DynamicMemLocksMB, DynamicMemSQLCacheMB, DynamicMemQueryOptimizeMB, DynamicMemHashSortIndexMB, CursorUsageMB)
SELECT SystemPhysicalMemoryMB, SystemVirtualMemoryMB, DBUsageMB, DBMemoryRequiredMB, BufferCacheHitRatio, BufferPageLifeExpectancy, BufferPoolCommitMB, BufferPoolCommitTgtMB, BufferPoolTotalPagesMB, BufferPoolDataPagesMB, BufferPoolFreePagesMB, BufferPoolReservedPagesMB, BufferPoolStolenPagesMB, BufferPoolPlanCachePagesMB, DynamicMemConnectionsMB, DynamicMemLocksMB, DynamicMemSQLCacheMB, DynamicMemQueryOptimizeMB, DynamicMemHashSortIndexMB, CursorUsageMB
FROM #TEMP
END

DROP TABLE #TEMP
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_CPUStats' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_CPUStats AS SELECT 1')
END
GO

ALTER PROC dbo.usp_CPUStats
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/28/2012		Michael Rounds			1.0					New Proc to gather CPU stats
**	08/31/2012		Michael Rounds			1.1					Changed VARCHAR to NVARCHAR
***************************************************************************************************************/

BEGIN
SET NOCOUNT ON

DECLARE @ts_now BIGINT, @ts_now2 BIGINT, @SQLVer NVARCHAR(20), @sql NVARCHAR(MAX) 

CREATE TABLE #TEMP (
	[SQLProcessPercent] INT,
	[SystemIdleProcessPercent] INT,
	[OtherProcessPerecnt] INT,
	DateStamp DATETIME
	)

SELECT @SQLVer = LEFT(CONVERT(NVARCHAR(20),SERVERPROPERTY('productversion')),4)

IF CAST(@SQLVer AS NUMERIC(4,2)) < 10
BEGIN
EXEC sp_executesql
	N'SELECT @ts_now = cpu_ticks / CONVERT(float, cpu_ticks_in_ms) FROM sys.dm_os_sys_info',
	N'@ts_now BIGINT OUTPUT',
	@ts_now = @ts_now2 OUTPUT

	INSERT INTO #TEMP ([SQLProcessPercent],[SystemIdleProcessPercent],[OtherProcessPerecnt],DateStamp)
    SELECT SQLProcessUtilization AS [SQLProcessPercent],
                   SystemIdle AS [SystemIdleProcessPercent],
                   100 - SystemIdle - SQLProcessUtilization AS [OtherProcessPerecnt],
                   DATEADD(ms, -1 * (@ts_now2 - [timestamp]), GETDATE()) AS [DateStamp]
    FROM (
          SELECT record.value('(./Record/@id)[1]', 'int') AS record_id,
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')
                AS [SystemIdle],
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]',
                'int')
                AS [SQLProcessUtilization], [timestamp]
          FROM (
                SELECT [timestamp], CONVERT(xml, record) AS [record]
                FROM sys.dm_os_ring_buffers
                WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
                AND record LIKE '%<SystemHealth>%') AS x
          ) AS y
    ORDER BY record_id DESC
END
ELSE BEGIN
-- Get CPU Utilization History (SQL 2008 Only)
    SELECT @ts_now = cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info
	INSERT INTO #TEMP ([SQLProcessPercent],[SystemIdleProcessPercent],[OtherProcessPerecnt],DateStamp)
    SELECT SQLProcessUtilization AS [SQLProcessPercent],
                   SystemIdle AS [SystemIdleProcessPercent],
                   100 - SystemIdle - SQLProcessUtilization AS [OtherProcessPerecnt],
                   DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [DateStamp]
    FROM (
          SELECT record.value('(./Record/@id)[1]', 'int') AS record_id,
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')
                AS [SystemIdle],
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]',
                'int')
                AS [SQLProcessUtilization], [timestamp]
          FROM (
                SELECT [timestamp], convert(xml, record) AS [record]
                FROM sys.dm_os_ring_buffers
                WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
                AND record LIKE '%<SystemHealth>%') AS x
          ) AS y
    ORDER BY record_id DESC
END

SELECT * FROM #TEMP

DROP TABLE #TEMP
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_CPUProcessAlert' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_CPUProcessAlert AS SELECT 1')
END
GO

ALTER PROC dbo.usp_CPUProcessAlert
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/29/2012		Michael Rounds			1.0					New Proc to alert on CPU usage
**	08/31/2012		Michael Rounds			1.1					Changed VARCHAR to NVARCHAR
***************************************************************************************************************/

BEGIN
SET NOCOUNT ON

DECLARE @QueryValue INT, @QueryValue2 INT, @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @HTML NVARCHAR(MAX), @ServerName NVARCHAR(50), @EmailSubject NVARCHAR(100), @LastDateStamp DATETIME

SELECT @LastDateStamp = MAX(DateStamp) FROM [dba].dbo.CPUStatsHistory

SELECT @ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'))

SELECT @QueryValue = QueryValue,
	@QueryValue2 = QueryValue2,
	@EmailList = EmailList,
	@CellList = CellList	
FROM [dba].dbo.AlertSettings WHERE Name = 'CPUAlert'

CREATE TABLE #TEMP (
	[SQLProcessPercent] INT,
	[SystemIdleProcessPercent] INT,
	[OtherProcessPerecnt] INT,
	DateStamp DATETIME
	)

INSERT INTO #TEMP
EXEC [dba].dbo.usp_CPUStats

IF EXISTS (SELECT * FROM #TEMP WHERE SQLProcessPercent > @QueryValue AND DateStamp > COALESCE(@LastDateStamp, GETDATE() -1))
BEGIN
SET	@HTML =
	'<html><head><style type="text/css">
	table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
	th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
	th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
	td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
	</style></head><body>
	<table width="700"> <tr><th class="header" width="700">High CPU Alert</th></tr></table>	
	<table width="700">
	<tr>  
	<th width="150">SQL Percent</th>	
	<th width="150">System Idle Percent</th>  
	<th width="150">Other Process Percent</th>  
	<th width="200">Date Stamp</th>
	</tr>'
SELECT @HTML =  @HTML +   
	'<tr>
	<td bgcolor="#E0E0E0" width="150">' + CAST(SQLProcessPercent AS NVARCHAR) +'</td>
	<td bgcolor="#F0F0F0" width="150">' + CAST(SystemIdleProcessPercent AS NVARCHAR) +'</td>
	<td bgcolor="#E0E0E0" width="150">' + CAST(OtherProcessPerecnt AS NVARCHAR) +'</td>
	<td bgcolor="#F0F0F0" width="200">' + CAST(DateStamp AS NVARCHAR) +'</td>	
	</tr>'
FROM #TEMP WHERE SQLProcessPercent > @QueryValue AND DateStamp > COALESCE(@LastDateStamp, GETDATE() -1)

SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'High CPU Alert on ' + @ServerName + '!'

EXEC msdb.dbo.sp_send_dbmail
@recipients= @EmailList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

IF @CellList IS NOT NULL
BEGIN

/*TEXT MESSAGE*/
IF EXISTS (SELECT * FROM #TEMP WHERE SQLProcessPercent > COALESCE(@QueryValue2, @QueryValue))
BEGIN
	SET	@HTML =
		'<html><head></head><body><table><tr><td>CPU,</td><td>Idle,</td><td>Other,</td><td>Date</td></tr>'
	SELECT @HTML =  @HTML +   
		'<tr><td>' + CAST(SQLProcessPercent AS NVARCHAR) +',</td><td>' + CAST(SystemIdleProcessPercent AS NVARCHAR) +',</td><td>' + CAST(OtherProcessPerecnt AS NVARCHAR) +',</td><td>' + CAST(DateStamp AS NVARCHAR) + '</td></tr>'
	FROM #TEMP WHERE SQLProcessPercent > COALESCE(@QueryValue2, @QueryValue)

	SELECT @HTML =  @HTML + '</table></body></html>'

	SELECT @EmailSubject = 'HighCPUAlert-' + @ServerName

	EXEC msdb.dbo.sp_send_dbmail
	@recipients= @CellList,
	@subject = @EmailSubject,
	@body = @HTML,
	@body_format = 'HTML'

END
END
END

INSERT INTO [dba].dbo.CPUStatsHistory ([SQLProcessPercent],[SystemIdleProcessPercent],[OtherProcessPerecnt],DateStamp)
SELECT [SQLProcessPercent],[SystemIdleProcessPercent],[OtherProcessPerecnt],DateStamp
FROM #TEMP
WHERE CONVERT(DATETIME, DateStamp, 120) > CONVERT(DATETIME,COALESCE(@LastDateStamp, GETDATE() -1), 120)
ORDER BY DATESTAMP ASC

DROP TABLE #TEMP
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_LongRunningJobs' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_LongRunningJobs AS SELECT 1')
END
GO

ALTER PROC [dbo].[usp_LongRunningJobs]
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
***************************************************************************************************************/

BEGIN

EXEC [dba].dbo.usp_JobStats @InsertFlag=1

DECLARE @JobStatsID INT, @QueryValue INT, @QueryValue2 INT, @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @HTML NVARCHAR(MAX), @ServerName NVARCHAR(50), @EmailSubject NVARCHAR(100)

SELECT @ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'))

SET @JobStatsID = (SELECT MAX(JobStatsID) FROM [dba].dbo.JobStatsHistory)
SELECT @QueryValue = QueryValue,
	@QueryValue2 = QueryValue2,
	@EmailList = EmailList,
	@CellList = CellList	
FROM [dba].dbo.AlertSettings WHERE Name = 'LongRunningJobs'

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

SELECT @EmailSubject = 'ACTIVE Long Running JOBS on ' + @ServerName + '! - IMMEDIATE Action Required'

EXEC msdb.dbo.sp_send_dbmail
@recipients= @EmailList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

IF @CellList IS NOT NULL
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

	SELECT @EmailSubject = 'JobsPastDue-' + @ServerName

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

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_LongRunningQueries' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_LongRunningQueries AS SELECT 1')
END
GO

ALTER PROC dbo.usp_LongRunningQueries
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
FROM [dba].dbo.QueryHistory 
WHERE (DATEDIFF(ss,start_time,collection_time)) >= @QueryValue
AND (DATEDIFF(mi,collection_time,GETDATE())) < (DATEDIFF(mi,@LastCollectionTime, collection_time))
AND [Database_Name] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
AND sql_text NOT LIKE 'BACKUP DATABASE%'
AND sql_text NOT LIKE 'RESTORE VERIFYONLY%'
AND sql_text NOT LIKE 'ALTER INDEX%'
AND sql_text NOT LIKE 'DECLARE @BlobEater%'
AND sql_text NOT LIKE 'DBCC%'
AND sql_text NOT LIKE 'WAITFOR(RECEIVE%'

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

IF @CellList IS NOT NULL
BEGIN

IF @QueryValue2 IS NOT NULL
BEGIN
TRUNCATE TABLE #TEMP
INSERT INTO #TEMP (QueryHistoryID, collection_time, start_time, login_time, session_id, CPU, reads, writes, physical_reads, [host_name], [DBName], login_name, sql_text, [program_name])
SELECT QueryHistoryID, collection_time, start_time, login_time, session_id, CPU, reads, writes, physical_reads, [host_name], [Database_Name], login_name, sql_text, [program_name]
FROM [dba].dbo.QueryHistory 
WHERE (DATEDIFF(ss,start_time,collection_time)) >= @QueryValue2
AND (DATEDIFF(mi,collection_time,GETDATE())) < (DATEDIFF(mi,@LastCollectionTime, collection_time))
AND [Database_Name] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
AND sql_text NOT LIKE 'BACKUP DATABASE%'
AND sql_text NOT LIKE 'RESTORE VERIFYONLY%'
AND sql_text NOT LIKE 'ALTER INDEX%'
AND sql_text NOT LIKE 'DECLARE @BlobEater%'
AND sql_text NOT LIKE 'DBCC%'
AND sql_text NOT LIKE 'WAITFOR(RECEIVE%'
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

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_CheckBlocking' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_CheckBlocking AS SELECT 1')
END
GO

ALTER PROCEDURE [dbo].[usp_CheckBlocking] 
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
***************************************************************************************************************/

BEGIN
SET NOCOUNT ON
 
IF EXISTS (SELECT * FROM master..sysprocesses WHERE spid > 50 AND blocked != 0 AND ((CAST(waittime AS DECIMAL) /1000) > 0))
BEGIN

INSERT INTO [dba].dbo.BlockingHistory (Blocked_SPID, Blocking_SPID, Blocked_Login, Blocked_HostName, Blocked_WaitTime_Seconds, Blocked_LastWaitType, Blocked_Status, 
	Blocked_Program, Blocked_SQL_Text, Offending_SPID, Offending_Login, Offending_NTUser, Offending_HostName, Offending_WaitType, Offending_LastWaitType, Offending_Status, 
	Offending_Program, Offending_SQL_Text, [DBName])

SELECT
a.spid AS Blocked_SPID,
a.blocked AS Blocking_SPID,
a.loginame AS Blocked_Login,
a.hostname AS Blocked_HostName,
(CAST(a.waittime AS DECIMAL) /1000) AS Blocked_WaitTime_Seconds,
a.lastwaittype AS Blocked_LastWaitType,
a.[status] AS Blocked_Status,
a.[program_name] AS Blocked_Program,
CAST(st1.[text] AS NVARCHAR(MAX)) as Blocked_SQL_Text,
b.spid AS Offending_SPID,
b.loginame AS Offending_Login,
b.nt_username AS Offending_NTUser,
b.hostname AS Offending_HostName,
b.waittime AS Offending_WaitType,
b.lastwaittype AS Offending_LastWaitType,
b.[status] AS Offending_Status,
b.[program_name] AS Offending_Program,
CAST(st2.text AS NVARCHAR(MAX)) as Offending_SQL_Text,
(SELECT name from master..sysdatabases WHERE [dbid] = a.[dbid]) AS [DBName]
FROM master..sysprocesses as a CROSS APPLY sys.dm_exec_sql_text (a.sql_handle) as st1
JOIN master..sysprocesses as b CROSS APPLY sys.dm_exec_sql_text (b.sql_handle) as st2
ON a.blocked = b.spid
WHERE a.spid > 50 AND a.blocked != 0 AND ((CAST(a.waittime AS DECIMAL) /1000) > 0)

END
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_FileStats' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_FileStats AS SELECT 1')
END
GO

ALTER PROC [dbo].[usp_FileStats] (@InsertFlag BIT = 0)
AS
/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.0					Comments creation
**  06/10/2012		Michael Rounds			1.1					Updated to use new FileStatsHistory table
**	08/31/2012		Michael Rounds			1.2					Changed VARCHAR to NVARCHAR
**	11/05/2012		Michael Rounds			2.0					Rewrote to use sysaltfiles instead of looping through sysfiles, gathering more data now too
**  12/17/2012		Michael Rounds			2.1					Apparently sysaltfiles is not good to use, went back to sysfiles, but still using new data gathering method
**	12/27/2012		Michael Rounds			2.1.2				Fixed a bug in gathering data on db's with different coallation
**	01/07/2012		Michael Rounds			2.1.3				Fixed Divide by zero bug
**	04/07/2013		Michael Rounds			2.1.4				Extended the lengths of KBytesRead and KBytesWritte in temp table FILESTATS - NUMERIC(12,2) to (20,2)
**	04/12/2013		Michael Rounds			2.1.5				Added SQL Server 2012 compatibility
**	04/15/2013		Michael Rounds			2.1.6				Expanded Cum_IO_GB
***************************************************************************************************************/

BEGIN

CREATE TABLE #FILESTATS (
	[DBName] NVARCHAR(128),
	[DBID] INT,
	[FileID] INT,	
	[FileName] NVARCHAR(255),
	[LogicalFileName] NVARCHAR(255),
	[VLFCount] INT,
	DriveLetter NCHAR(1),
	FileMBSize NVARCHAR(30),
	[FileMaxSize] NVARCHAR(30),
	FileGrowth NVARCHAR(30),
	FileMBUsed NVARCHAR(30),
	FileMBEmpty NVARCHAR(30),
	FilePercentEmpty NUMERIC(12,2),
	LargeLDF INT,
	[FileGroup] NVARCHAR(100),
	NumberReads NVARCHAR(30),
	KBytesRead NUMERIC(20,2),
	NumberWrites NVARCHAR(30),
	KBytesWritten NUMERIC(20,2),
	IoStallReadMS NVARCHAR(30),
	IoStallWriteMS NVARCHAR(30),
	Cum_IO_GB NUMERIC(20,2),
	IO_Percent NUMERIC(12,2)
	)

CREATE TABLE #LOGSPACE (
	[DBName] NVARCHAR(128) NOT NULL,
	[LogSize] NUMERIC(12,2) NOT NULL,
	[LogPercentUsed] NUMERIC(12,2) NOT NULL,
	[LogStatus] INT NOT NULL
	)

CREATE TABLE #DATASPACE (
	[DBName] NVARCHAR(128) NULL,
	[Fileid] INT NOT NULL,
	[FileGroup] INT NOT NULL,
	[TotalExtents] NUMERIC(12,2) NOT NULL,
	[UsedExtents] NUMERIC(12,2) NOT NULL,
	[FileLogicalName] NVARCHAR(128) NULL,
	[Filename] NVARCHAR(255) NOT NULL
	)

CREATE TABLE #TMP_DB (
	[DBName] NVARCHAR(128)
	) 

DECLARE @SQL NVARCHAR(MAX), @DBName NVARCHAR(128), @SQLVer NVARCHAR(20)

SELECT @SQLVer = LEFT(CONVERT(NVARCHAR(20),SERVERPROPERTY('productversion')),4)

SET @SQL = 'DBCC SQLPERF (LOGSPACE) WITH NO_INFOMSGS' 

INSERT INTO #LOGSPACE ([DBName],LogSize,LogPercentUsed,LogStatus)
EXEC(@SQL)

CREATE INDEX IDX_tLogSpace_Database ON #LOGSPACE ([DBName])

INSERT INTO #TMP_DB 
SELECT LTRIM(RTRIM(name)) AS [DBName]
FROM master..sysdatabases 
WHERE category IN ('0', '1','16')
AND DATABASEPROPERTYEX(name,'STATUS')='ONLINE'
ORDER BY name

CREATE INDEX IDX_TMPDB_Database ON #TMP_DB ([DBName])

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB)

WHILE @DBName IS NOT NULL 
BEGIN

SET @SQL = 'USE ' + '[' +@DBName + ']' + '
DBCC SHOWFILESTATS WITH NO_INFOMSGS'

INSERT INTO #DATASPACE ([Fileid],[FileGroup],[TotalExtents],[UsedExtents],[FileLogicalName],[Filename])
EXEC (@SQL)

UPDATE #DATASPACE
SET [DBName] = @DBName
WHERE COALESCE([DBName],'') = ''

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB WHERE [DBName] > @DBName)

END

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB)

WHILE @DBName IS NOT NULL 
BEGIN
 
SET @SQL = 'USE ' + '[' +@DBName + ']' + '
INSERT INTO #FILESTATS (
	[DBName],
	[DBID],
	[FileID],	
	[DriveLetter],
	[Filename],
	[LogicalFileName],
	[Filegroup],
	[FileMBSize],
	[FileMaxSize],
	[FileGrowth],
	[FileMBUsed],
	[FileMBEmpty],
	[FilePercentEmpty])
SELECT	DBName = ''' + '[' + @dbname + ']' + ''',
		DB_ID() AS [DBID],
		SF.FileID AS [FileID],
		LEFT(SF.[FileName], 1) AS DriveLetter,		
		LTRIM(RTRIM(REVERSE(SUBSTRING(REVERSE(SF.[Filename]),0,CHARINDEX(''\'',REVERSE(SF.[Filename]),0))))) AS [Filename],
		SF.name AS LogicalFileName,
		COALESCE(filegroup_name(SF.groupid),'''') AS [Filegroup],
		CAST((SF.size * 8)/1024 AS NVARCHAR) AS [FileMBSize], 
		CASE SF.maxsize 
			WHEN -1 THEN N''Unlimited'' 
			ELSE CONVERT(NVARCHAR(15), (CAST(SF.maxsize AS BIGINT) * 8)/1024) + N'' MB'' 
			END AS FileMaxSize, 
		(CASE WHEN SF.[status] & 0x100000 = 0 THEN CONVERT(NVARCHAR,CEILING((growth * 8192)/(1024.0*1024.0))) + '' MB''
			ELSE CONVERT (NVARCHAR, growth) + '' %'' 
			END) AS FileGrowth,
		CAST(COALESCE(((DSP.UsedExtents * 64.00) / 1024), LSP.LogSize *(LSP.LogPercentUsed/100)) AS BIGINT) AS [FileMBUsed],
		(SF.size * 8)/1024 - CAST(COALESCE(((DSP.UsedExtents * 64.00) / 1024), LSP.LogSize *(LSP.LogPercentUsed/100)) AS BIGINT) AS [FileMBEmpty],
		(CAST(((SF.size * 8)/1024 - CAST(COALESCE(((DSP.UsedExtents * 64.00) / 1024), LSP.LogSize *(LSP.LogPercentUsed/100)) AS BIGINT)) AS DECIMAL) / 
			CAST(CASE WHEN COALESCE((SF.size * 8)/1024,0) = 0 THEN 1 ELSE (SF.size * 8)/1024 END AS DECIMAL)) * 100 AS [FilePercentEmpty]			
FROM sys.sysfiles SF
JOIN master..sysdatabases SDB
	ON db_id() = SDB.[dbid]
JOIN sys.dm_io_virtual_file_stats(NULL,NULL) b
	ON db_id() = b.[database_id] AND SF.fileid = b.[file_id]
LEFT OUTER 
JOIN #DATASPACE DSP
	ON DSP.[Filename] COLLATE DATABASE_DEFAULT = SF.[Filename] COLLATE DATABASE_DEFAULT
LEFT OUTER 
JOIN #LOGSPACE LSP
	ON LSP.[DBName] = SDB.Name
GROUP BY SDB.Name,SF.FileID,SF.[FileName],SF.name,SF.groupid,SF.size,SF.maxsize,SF.[status],growth,DSP.UsedExtents,LSP.LogSize,LSP.LogPercentUsed'

EXEC(@SQL)

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB WHERE [DBName] > @DBName)
END

DROP TABLE #LOGSPACE
DROP TABLE #DATASPACE

UPDATE f
SET f.NumberReads = b.num_of_reads,
	f.KBytesRead = b.num_of_bytes_read / 1024,
	f.NumberWrites = b.num_of_writes,
	f.KBytesWritten = b.num_of_bytes_written / 1024,
	f.IoStallReadMS = b.io_stall_read_ms,
	f.IoStallWriteMS = b.io_stall_write_ms,
	f.Cum_IO_GB = b.CumIOGB,
	f.IO_Percent = b.IOPercent
FROM #FILESTATS f
JOIN (SELECT database_ID, [file_id], num_of_reads, num_of_bytes_read, num_of_writes, num_of_bytes_written, io_stall_read_ms, io_stall_write_ms, 
			CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) / 1024 AS CumIOGB,
			CAST(CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 AS DECIMAL(12,2)) / 1024 / 
				SUM(CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) / 1024) OVER() * 100 AS DECIMAL(5, 2)) AS IOPercent
		FROM sys.dm_io_virtual_file_stats(NULL,NULL)
		GROUP BY database_id, [file_id],num_of_reads, num_of_bytes_read, num_of_writes, num_of_bytes_written, io_stall_read_ms, io_stall_write_ms) AS b
ON f.[DBID] = b.[database_id] AND f.fileid = b.[file_id]

UPDATE b
SET b.LargeLDF = 
	CASE WHEN CAST(b.FileMBSize AS INT) > CAST(a.FileMBSize AS INT) THEN 1
	ELSE 2 
	END
FROM #FILESTATS a
JOIN #FILESTATS b
ON a.[DBName] = b.[DBName] 
AND a.[FileName] LIKE '%mdf' 
AND b.[FileName] LIKE '%ldf'

/* VLF INFO - USES SAME TMP_DB TO GATHER STATS */
CREATE TABLE #VLFINFO (
	[DBName] NVARCHAR(128) NULL,
	RecoveryUnitId NVARCHAR(3),
	FileID NVARCHAR(3), 
	FileSize NUMERIC(20,0),
	StartOffset BIGINT, 
	FSeqNo BIGINT, 
	[Status] CHAR(1),
	Parity NVARCHAR(4),
	CreateLSN NUMERIC(25,0)
	)

IF CAST(@SQLVer AS NUMERIC(4,2)) < 11
BEGIN
-- (SQL 2008R2 And Below)
SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB)

WHILE @DBName IS NOT NULL 
BEGIN

SET @SQL = 'USE ' + '[' +@DBName + ']' + '
INSERT INTO #VLFINFO (FileID,FileSize,StartOffset,FSeqNo,[Status],Parity,CreateLSN)
EXEC(''DBCC LOGINFO WITH NO_INFOMSGS'');'
EXEC(@SQL)

SET @SQL = 'UPDATE #VLFINFO SET DBName = ''' +@DBName+ ''' WHERE DBName IS NULL;'
EXEC(@SQL)

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB WHERE [DBName] > @DBName)
END
END
ELSE BEGIN
-- (SQL 2012 And Above)
SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB)

WHILE @DBName IS NOT NULL 
BEGIN
 
SET @SQL = 'USE ' + '[' +@DBName + ']' + '
INSERT INTO #VLFINFO (RecoveryUnitID, FileID,FileSize,StartOffset,FSeqNo,[Status],Parity,CreateLSN)
EXEC(''DBCC LOGINFO WITH NO_INFOMSGS'');'
EXEC(@SQL)

SET @SQL = 'UPDATE #VLFINFO SET DBName = ''' +@DBName+ ''' WHERE DBName IS NULL;'
EXEC(@SQL)

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB WHERE [DBName] > @DBName)
END
END

DROP TABLE #TMP_DB

UPDATE a
SET a.VLFCount = (SELECT COUNT(1) FROM #VLFINFO WHERE [DBName] = REPLACE(REPLACE(a.DBName,'[',''),']',''))
FROM #FILESTATS a
WHERE COALESCE(a.[FileGroup],'') = ''

DROP TABLE #VLFINFO

SELECT * FROM #FILESTATS

IF @InsertFlag = 1
BEGIN

DECLARE @FileStatsID INT

SELECT @FileStatsID = COALESCE(MAX(FileStatsID),0) + 1 FROM [dba].dbo.FileStatsHistory

INSERT INTO dbo.FileStatsHistory (FileStatsID, [DBName], [DBID], [FileID], [FileName], LogicalFileName, VLFCount, DriveLetter, FileMBSize, FileMaxSize, FileGrowth, FileMBUsed, 
	FileMBEmpty, FilePercentEmpty, LargeLDF, [FileGroup], NumberReads, KBytesRead, NumberWrites, KBytesWritten, IoStallReadMS, IoStallWriteMS, Cum_IO_GB, IO_Percent)
SELECT @FileStatsID AS FileStatsID,[DBName], [DBID], [FileID], [FileName], LogicalFileName, VLFCount, DriveLetter, FileMBSize, FileMaxSize, FileGrowth, FileMBUsed, 
	FileMBEmpty, FilePercentEmpty, LargeLDF, [FileGroup], NumberReads, KBytesRead, NumberWrites, KBytesWritten, IoStallReadMS, IoStallWriteMS, Cum_IO_GB, IO_Percent
FROM #FILESTATS

END
DROP TABLE #FILESTATS
END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_CheckFiles' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_CheckFiles AS SELECT 1')
END
GO

ALTER PROC [dbo].[usp_CheckFiles]
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.0					Comments creation
**  06/10/2012		Michael Rounds			1.1					Updated to use new FileStatsHistory table
**	08/31/2012		Michael Rounds			1.2					Changed VARCHAR to NVARCHAR
***************************************************************************************************************/

BEGIN

SET NOCOUNT ON

/* GET STATS */

/*Populate File Stats tables*/
EXEC [dba].dbo.usp_FileStats @InsertFlag=1

DECLARE @FileStatsID INT, @QueryValue INT, @QueryValue2 INT, @HTML NVARCHAR(MAX), @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @ServerName NVARCHAR(128), @EmailSubject NVARCHAR(100)

SELECT @ServerName = CONVERT(NVARCHAR(128), SERVERPROPERTY('servername'))  

SET @FileStatsID = (SELECT MAX(FileStatsID) FROM [dba].dbo.FileStatsHistory)

/*Populate Main TEMP table*/
SELECT FileStatsHistoryID, FileStatsID, FileStatsDateStamp, [DBName], [FileName], DriveLetter, FileMBSize, FileGrowth, FileMBUsed, FileMBEmpty, FilePercentEmpty
INTO #TEMP
FROM [dba].dbo.FileStatsHistory
WHERE FileStatsID IN (@FileStatsID,(@FileStatsID -1 ))

/* LOG FILES */

/*Grab AlertSettings for LogFiles*/
SELECT @QueryValue = QueryValue,
		@QueryValue2 = QueryValue2,
		@EmailList = EmailList,
		@CellList = CellList
FROM [dba].dbo.AlertSettings WHERE Name = 'LogFiles'

CREATE TABLE #TEMP2 (
	[DBName] NVARCHAR(128),
	FileMBSize BIGINT,
	FileMBUsed BIGINT,
	FileMBEmpty BIGINT,
	FilePercentEmpty NUMERIC(12,2)
	)

INSERT INTO #TEMP2 ([DBName],FileMBSize,FileMBUsed,FileMBEmpty,FilePercentEmpty)
SELECT t2.[DBName],t2.FileMBSize,t2.FileMBUsed,t2.FileMBEmpty,CAST(t2.FilePercentEmpty AS NUMERIC(12,2))
FROM #TEMP t
JOIN #TEMP t2
	ON t.[DBName] = t2.[DBName] 
	AND t.[Filename] = t2.[FileName] 
	AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
	AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
WHERE CAST(t2.FilePercentEmpty AS NUMERIC(12,2)) < @QueryValue
AND t2.[Filename] like '%ldf'
AND t.FileMBSize <> t2.FileMBSize
AND t2.[DBName] NOT IN ('model','tempdb')
AND t2.[DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LogFileAlerts = 0)

/*Populate TEMPLogFiles table used for Already Grown LOG files*/

CREATE TABLE #TEMPLogFiles (
	[DBName] NVARCHAR(128),
	[Filename] NVARCHAR(255),
	PreviousFileSize BIGINT,
	PrevPercentEmpty NUMERIC(12,2),
	CurrentFileSize BIGINT,
	CurrPercentEmpty NUMERIC(12,2)	
	)

INSERT INTO #TEMPLogFiles ([DBName],[Filename],PreviousFileSize,PrevPercentEmpty,CurrentFileSize,CurrPercentEmpty)
SELECT t.[DBName],t.[Filename],t.FileMBSize AS PreviousFileSize,t.FilePercentEmpty AS PrevPercentEmpty,t2.FileMBSize AS CurrentFileSize,t2.FilePercentEmpty AS CurrPercentEmpty
FROM #TEMP t
JOIN #TEMP t2
	ON t.[DBName] = t2.[DBName] 
	AND t.[Filename] = t2.[FileName] 
	AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
	AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
WHERE t2.[Filename] like '%ldf'
AND t.FileMBSize < t2.FileMBSize
AND t2.[DBName] NOT IN ('model','tempdb')
AND t2.[DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LogFileAlerts = 0)

/*Start of Growing Log files*/
IF EXISTS (SELECT * FROM #TEMP2)
BEGIN
SET	@HTML =
	'<html><head><style type="text/css">
	table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
	th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
	th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
	td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
	</style></head><body>
	<table width="725"> <tr><th class="header" width="725">Growing Log Files</th></tr></table>
	<table width="725" >
	<tr>  
	<th width="250">Database</th>
	<th width="250">FileMBSize</th>
	<th width="250">FileMBUsed</th> 
	<th width="250">FileMBEmpty</th>
	<th width="250">FilePercentEmpty</th>
	</tr>'
SELECT @HTML =  @HTML +   
	'<tr>
	<td bgcolor="#E0E0E0" width="250">' + [DBName] +'</td>
	<td bgcolor="#F0F0F0" width="250">' + CAST(FileMBSize AS NVARCHAR) + '</td>	
	<td bgcolor="#E0E0E0" width="250">' + CAST(FileMBUsed AS NVARCHAR) + '</td>	
	<td bgcolor="#F0F0F0" width="250">' + CAST(FileMBEmpty AS NVARCHAR) + '</td>	
	<td bgcolor="#E0E0E0" width="250">' + CAST(FilePercentEmpty AS NVARCHAR) + '</td>			
	</tr>'
FROM #TEMP2

SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'Log files are about to Auto-Grow on ' + @ServerName + '!'

EXEC msdb.dbo.sp_send_dbmail
@recipients= @EmailList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

IF @CellList IS NOT NULL
BEGIN

IF @QueryValue2 IS NOT NULL
BEGIN
TRUNCATE TABLE #TEMP2
INSERT INTO #TEMP2 ([DBName],FileMBSize,FileMBUsed,FileMBEmpty,FilePercentEmpty)
SELECT t2.[DBName],t2.FileMBSize,t2.FileMBUsed,t2.FileMBEmpty,t2.FilePercentEmpty
FROM #TEMP t
JOIN #TEMP t2
	ON t.[DBName] = t2.[DBName] 
	AND t.[Filename] = t2.[FileName] 
	AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
	AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
WHERE t2.FilePercentEmpty < @QueryValue2
AND t2.[Filename] like '%ldf'
AND t.FileMBSize <> t2.FileMBSize
AND t2.[DBName] NOT IN ('model','tempdb')
AND t2.[DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LogFileAlerts = 0)
END

/*TEXT MESSAGE*/
IF EXISTS (SELECT * FROM #TEMP2)
BEGIN
SET	@HTML =
	'<html><head></head><body><table><tr><td>Database,</td><td>FileSize,</td><td>Percent</td></tr>'
SELECT @HTML =  @HTML +   
	'<tr><td>' + COALESCE([DBName], '') +',</td><td>' + COALESCE(CAST(FileMBSize AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(FilePercentEmpty AS NVARCHAR), '') +'</td></tr>'
FROM #TEMP2
SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'LDFGrowing-' + @ServerName

EXEC msdb.dbo.sp_send_dbmail
@recipients= @CellList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

END
END
END
/*Stop of Growing Log files*/
/*Start of Already Grown Log files*/
IF EXISTS (SELECT * FROM #TEMPLogFiles)
BEGIN
SET	@HTML =
	'<html><head><style type="text/css">
	table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
	th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
	th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
	td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
	</style></head><body>
	<table width="725"> <tr><th class="header" width="725">Recent Log File Auto-Growth</th></tr></table>
	<table width="725" >
	<tr>  
	<th width="250">Database</th>
	<th width="250">PreviousFileSize</th>
	<th width="250">PrevPercentEmpty</th>
	<th width="250">CurrentFileSize</th>
	<th width="250">CurrPercentEmpty</th>
	</tr>'
SELECT @HTML =  @HTML +   
	'<tr>
	<td bgcolor="#E0E0E0" width="250">' + [DBName] +'</td>
	<td bgcolor="#F0F0F0" width="250">' + CAST(PreviousFileSize AS NVARCHAR) + '</td>	
	<td bgcolor="#E0E0E0" width="250">' + CAST(PrevPercentEmpty AS NVARCHAR) + '</td>	
	<td bgcolor="#F0F0F0" width="250">' + CAST(CurrentFileSize AS NVARCHAR) + '</td>	
	<td bgcolor="#E0E0E0" width="250">' + CAST(CurrPercentEmpty AS NVARCHAR) + '</td>			
	</tr>'
FROM #TEMPLogFiles

SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'Log files have Auto-Grown on ' + @ServerName + '!'

EXEC msdb.dbo.sp_send_dbmail
@recipients= @EmailList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

IF @CellList IS NOT NULL
BEGIN
/*TEXT MESSAGE*/
SET	@HTML =
	'<html><head></head><body><table><tr><td>Database,</td><td>PrevFileSize,</td><td>CurrFileSize</td></tr>'
SELECT @HTML =  @HTML +   
	'<tr><td>' + COALESCE([DBName], '') +',</td><td>' + COALESCE(CAST(PreviousFileSize AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(CurrentFileSize AS NVARCHAR), '') +'</td></tr>'
FROM #TEMPLogFiles
SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'LDFAutoGrowth-' + @ServerName

EXEC msdb.dbo.sp_send_dbmail
@recipients= @CellList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

END
END
/*Stop of Already Grown Log files*/

/* TEMP DB */

/*Grab AlertSettings for TEMPDB*/
SELECT @QueryValue = QueryValue,
		@QueryValue2 = QueryValue2,
		@EmailList = EmailList,
		@CellList = CellList
FROM [dba].dbo.AlertSettings WHERE Name = 'TempDB'

CREATE TABLE #TEMP3 (
	[DBName] NVARCHAR(128),
	FileMBSize BIGINT,
	FileMBUsed BIGINT,
	FileMBEmpty BIGINT,
	FilePercentEmpty NUMERIC(12,2)
	)

INSERT INTO #TEMP3
SELECT t2.[DBName],t2.FileMBSize,t2.FileMBUsed,t2.FileMBEmpty,CAST(t2.FilePercentEmpty AS NUMERIC(12,2))
FROM #TEMP t
JOIN #TEMP t2
	ON t.[DBName] = t2.[DBName] 
	AND t.[Filename] = t2.[FileName] 
	AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
	AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
WHERE CAST(t2.FilePercentEmpty AS NUMERIC(12,2)) < @QueryValue
AND t2.[Filename] like '%mdf'
AND t.FileMBSize <> t2.FileMBSize
AND t2.[DBName] = 'tempdb'

/*Populate TEMPdb table used for Already Grown TEMPDB files*/
CREATE TABLE #TEMPdb (
	[DBName] NVARCHAR(128),
	[Filename] NVARCHAR(255),
	PreviousFileSize BIGINT,
	PrevPercentEmpty NUMERIC(12,2),
	CurrentFileSize BIGINT,
	CurrPercentEmpty NUMERIC(12,2)	
	)

INSERT INTO #TEMPdb
SELECT t2.[DBName],t2.[Filename],t.FileMBSize AS PreviousFileSize,t.FilePercentEmpty AS PrevPercentEmpty,t2.FileMBSize AS CurrentFileSize,t2.FilePercentEmpty AS CurrPercentEmpty
FROM #TEMP t
JOIN #TEMP t2
	ON t.[DBName] = t2.[DBName] 
	AND t.[Filename] = t2.[FileName] 
	AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
	AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
WHERE t2.[Filename] like '%mdf'
AND t.FileMBSize < t2.FileMBSize
AND t2.[DBName] = 'tempdb'

/*Start of TempDB Growing*/
IF EXISTS (SELECT * FROM #TEMP3)
BEGIN
SET	@HTML =
	'<html><head><style type="text/css">
	table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
	th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
	th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
	td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
	</style></head><body>
	<table width="725"> <tr><th class="header" width="725">TempDB Growth</th></tr></table>
	<table width="725" >
	<tr>  
	<th width="250">Database</th>
	<th width="250">FileMBSize</th>
	<th width="250">FileMBUsed</th> 
	<th width="250">FileMBEmpty</th>
	<th width="250">FilePercentEmpty</th>
	</tr>'
SELECT @HTML =  @HTML +   
	'<tr>
	<td bgcolor="#E0E0E0" width="250">' + [DBName] +'</td>
	<td bgcolor="#F0F0F0" width="250">' + CAST(FileMBSize AS NVARCHAR) + '</td>	
	<td bgcolor="#E0E0E0" width="250">' + CAST(FileMBUsed AS NVARCHAR) + '</td>	
	<td bgcolor="#F0F0F0" width="250">' + CAST(FileMBEmpty AS NVARCHAR) + '</td>	
	<td bgcolor="#E0E0E0" width="250">' + CAST(FilePercentEmpty AS NVARCHAR) + '</td>			
	</tr>'
FROM #TEMP3

SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'TempDB is growing on ' + @ServerName + '!'

EXEC msdb.dbo.sp_send_dbmail
@recipients= @EmailList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

IF @CellList IS NOT NULL
BEGIN

IF @QueryValue2 IS NOT NULL
BEGIN
TRUNCATE TABLE #TEMP3
INSERT INTO #TEMP3
SELECT t2.[DBName],t2.FileMBSize,t2.FileMBUsed,t2.FileMBEmpty,t2.FilePercentEmpty
FROM #TEMP t
JOIN #TEMP t2
	ON t.[DBName] = t2.[DBName] 
	AND t.[Filename] = t2.[FileName] 
	AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
	AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
WHERE t2.FilePercentEmpty < @QueryValue
AND t2.[Filename] like '%mdf'
AND t.FileMBSize <> t2.FileMBSize
AND t2.[DBName] = 'tempdb'
END

/*TEXT MESSAGE*/
IF EXISTS (SELECT * FROM #TEMP3)
BEGIN
SET	@HTML =
	'<html><head></head><body><table><tr><td>FileSize,</td><td>FileEmpty,</td><td>Percent</td></tr>'
SELECT @HTML =  @HTML +   
	'<tr><td>' + COALESCE(CAST(FileMBSize AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(FileMBEmpty AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(FilePercentEmpty AS NVARCHAR), '') +'</td></tr>'
FROM #TEMP3

SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'TempDBGrowing-' + @ServerName

EXEC msdb.dbo.sp_send_dbmail
@recipients= @CellList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

END
END
END
/*Stop of TempDB Growing*/
/*Start of TempDB Already Grown*/

/*TempDB */
IF EXISTS (SELECT * FROM #TEMPdb)
BEGIN
SET	@HTML =
	'<html><head><style type="text/css">
	table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
	th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
	th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
	td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
	</style></head><body>
	<table width="725"> <tr><th class="header" width="725">Recent TempDB Auto-Growth</th></tr></table>
	<table width="725" >
	<tr>  
	<th width="250">Database</th>
	<th width="250">PreviousFileSize</th>
	<th width="250">PrevPercentEmpty</th>
	<th width="250">CurrentFileSize</th>
	<th width="250">CurrPercentEmpty</th>
	</tr>'
SELECT @HTML =  @HTML +   
	'<tr>
	<td bgcolor="#E0E0E0" width="250">' + [DBName] +'</td>
	<td bgcolor="#F0F0F0" width="250">' + CAST(PreviousFileSize AS NVARCHAR) + '</td>	
	<td bgcolor="#E0E0E0" width="250">' + CAST(PrevPercentEmpty AS NVARCHAR) + '</td>	
	<td bgcolor="#F0F0F0" width="250">' + CAST(CurrentFileSize AS NVARCHAR) + '</td>	
	<td bgcolor="#E0E0E0" width="250">' + CAST(CurrPercentEmpty AS NVARCHAR) + '</td>			
	</tr>'
FROM #TEMPdb

SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'TempDB has Auto-Grown on ' + @ServerName + '!'

EXEC msdb.dbo.sp_send_dbmail
@recipients= @EmailList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

IF @CellList IS NOT NULL
BEGIN
/*TEXT MESSAGE*/
SET	@HTML =
	'<html><head></head><body><table><tr><td>Database,</td><td>PrevFileSize,</td><td>CurrFileSize</td></tr>'
SELECT @HTML =  @HTML +   
	'<tr><td>' + COALESCE([DBName], '') +',</td><td>' + COALESCE(CAST(PreviousFileSize AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(CurrentFileSize AS NVARCHAR), '') +'</td></tr>'
FROM #TEMPdb
SELECT @HTML =  @HTML + '</table></body></html>'

SELECT @EmailSubject = 'TempDBAutoGrowth-' + @ServerName

EXEC msdb.dbo.sp_send_dbmail
@recipients= @CellList,
@subject = @EmailSubject,
@body = @HTML,
@body_format = 'HTML'

END
END
DROP TABLE #TEMPLogFiles
DROP TABLE #TEMPdb
DROP TABLE #TEMP
DROP TABLE #TEMP2
DROP TABLE #TEMP3

END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'dd_PopulateDataDictionary' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.dd_PopulateDataDictionary AS SELECT 1')
END
GO

ALTER PROC dbo.dd_PopulateDataDictionary
AS

/**************************************************************************************************************
**  Purpose: RUN THIS TO POPULATE DATA DICTIONARY PROCESS TABLES
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

    SET NOCOUNT ON
    DECLARE @TableCount INT,
        @FieldCount INT
    INSERT  INTO dbo.DataDictionary_Tables ( SchemaName, TableName )
            SELECT  SRC.TABLE_SCHEMA,
                    TABLE_NAME
            FROM    INFORMATION_SCHEMA.TABLES AS SRC
                    LEFT JOIN dbo.DataDictionary_Tables AS DEST
                        ON SRC.table_Schema = DEST.SchemaName
                           AND SRC.table_name = DEST.TableName
            WHERE   DEST.SchemaName IS NULL
                    AND SRC.table_Type = 'BASE TABLE'
                    AND OBJECTPROPERTY(OBJECT_ID(QUOTENAME(SRC.TABLE_SCHEMA)
                                                 + '.'
                                                 + QUOTENAME(SRC.TABLE_NAME)),
                                       'IsMSShipped') = 0
    SET @TableCount = @@ROWCOUNT
    INSERT  INTO dbo.DataDictionary_Fields
            (
              SchemaName,
              TableName,
              FieldName
            )
            SELECT  C.TABLE_SCHEMA,
                    C.TABLE_NAME,
                    C.COLUMN_NAME
            FROM    INFORMATION_SCHEMA.COLUMNS AS C
                    INNER JOIN dbo.DataDictionary_Tables AS T
                        ON C.TABLE_SCHEMA = T.SchemaName
                           AND C.TABLE_NAME = T.TableName
                    LEFT JOIN dbo.DataDictionary_Fields AS F
                        ON C.TABLE_SCHEMA = F.SchemaName
                           AND C.TABLE_NAME = F.TableName
                           AND C.COLUMN_NAME = F.FieldName
            WHERE   F.SchemaName IS NULL
                    AND OBJECTPROPERTY(OBJECT_ID(QUOTENAME(C.TABLE_SCHEMA)
                                                 + '.'
                                                 + QUOTENAME(C.TABLE_NAME)),
                                       'IsMSShipped') = 0
    SET @FieldCount = @@ROWCOUNT
    RAISERROR ( 'DATA DICTIONARY: %i tables & %i fields added', 10, 1,
        @TableCount, @FieldCount ) WITH NOWAIT
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'dd_UpdateDataDictionaryTable' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.dd_UpdateDataDictionaryTable AS SELECT 1') 
END
GO

ALTER PROC dbo.dd_UpdateDataDictionaryTable
    @SchemaName sysname = N'dbo',
    @TableName sysname, 
    @TableDescription VARCHAR(7000) = '' 
AS

/**************************************************************************************************************
**  Purpose: USE THIS TO MANUALLY UPDATE AN INDIVIDUAL TABLE/FIELD, THEN RUN POPULATE SCRIPT AGAIN
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

    SET NOCOUNT ON
    UPDATE  dbo.DataDictionary_Tables
    SET     TableDescription = ISNULL(@TableDescription, '')
    WHERE   SchemaName = @SchemaName
            AND TableName = @TableName
    RETURN @@ROWCOUNT
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'dd_UpdateDataDictionaryField' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.dd_UpdateDataDictionaryField AS SELECT 1')
END
GO

ALTER PROC dbo.dd_UpdateDataDictionaryField
    @SchemaName sysname = N'dbo',
    @TableName sysname, 
    @FieldName sysname, 
    @FieldDescription VARCHAR(7000) = '' 
AS

/**************************************************************************************************************
**  Purpose: USE THIS TO MANUALLY UPDATE AN INDIVIDUAL TABLE/FIELD, THEN RUN POPULATE SCRIPT AGAIN
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

    SET NOCOUNT ON
    UPDATE  dbo.DataDictionary_Fields
    SET     FieldDescription = ISNULL(@FieldDescription, '')
    WHERE   SchemaName = @SchemaName
            AND TableName = @TableName
            AND FieldName = @FieldName
    RETURN @@ROWCOUNT
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'dd_TestDataDictionaryTables' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.dd_TestDataDictionaryTables AS SELECT 1')
END
GO

ALTER PROC dbo.dd_TestDataDictionaryTables
AS

/**************************************************************************************************************
**  Purpose: RUN THIS TO FIND TABLES AND/OR FIELDS THAT ARE MISSING DATA
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

    SET NOCOUNT ON
    DECLARE @TableList TABLE
        (
          SchemaName sysname NOT NULL,
          TableName SYSNAME NOT NULL,
          PRIMARY KEY CLUSTERED ( SchemaName, TableName )
        )
    DECLARE @RecordCount INT
    EXEC dbo.dd_PopulateDataDictionary -- Ensure the dbo.DataDictionary tables are up-to-date.
    INSERT  INTO @TableList ( SchemaName, TableName )
            SELECT  SchemaName,
                    TableName
            FROM    dbo.DataDictionary_Tables
            WHERE   TableName NOT LIKE 'MSp%' -- ???
                    AND TableName NOT LIKE 'sys%' -- Exclude standard system tables.
                    AND TableDescription = ''
    SET @RecordCount = @@ROWCOUNT
    IF @RecordCount > 0 
        BEGIN
            PRINT ''
            PRINT 'The following recordset shows the tables for which data dictionary descriptions are missing'
            PRINT ''
            SELECT  LEFT(SchemaName, 15) AS SchemaName,
                    LEFT(TableName, 30) AS TableName
            FROM    @TableList
            UNION ALL
            SELECT  '',
                    '' -- Used to force a blank line
            RAISERROR ( '%i table(s) lack descriptions', 16, 1, @RecordCount )
                WITH NOWAIT
        END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'dd_TestDataDictionaryFields' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.dd_TestDataDictionaryFields AS SELECT 1')
END
GO

ALTER PROC dbo.dd_TestDataDictionaryFields
AS

/**************************************************************************************************************
**  Purpose: RUN THIS TO FIND TABLES AND/OR FIELDS THAT ARE MISSING DATA
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

    SET NOCOUNT ON
    DECLARE @RecordCount INT
    DECLARE @FieldList TABLE
        (
          SchemaName sysname NOT NULL,
          TableName SYSNAME NOT NULL,
          FieldName sysname NOT NULL,
          PRIMARY KEY CLUSTERED ( SchemaName, TableName, FieldName )
        )
    EXEC dbo.dd_PopulateDataDictionary -- Ensure the dbo.DataDictionary tables are up-to-date.
    INSERT  INTO @FieldList
            (
              SchemaName,
              TableName,
              FieldName
            )
            SELECT  SchemaName,
                    TableName,
                    FieldName
            FROM    dbo.DataDictionary_Fields
            WHERE   TableName NOT LIKE 'MSp%' -- ???
                    AND TableName NOT LIKE 'sys%' -- Exclude standard system tables.
                    AND FieldDescription = ''
    SET @RecordCount = @@ROWCOUNT
    IF @RecordCount > 0 
        BEGIN
            PRINT ''
            PRINT 'The following recordset shows the tables/fields for which data dictionary descriptions are missing'
            PRINT ''
            SELECT  LEFT(SchemaName, 15) AS SchemaName,
                    LEFT(TableName, 30) AS TableName,
                    LEFT(FieldName, 30) AS FieldName
            FROM    @FieldList
            UNION ALL
            SELECT  '',
                    '',
                    '' -- Used to force a blank line
            RAISERROR ( '%i field(s) lack descriptions', 16, 1, @RecordCount )
                WITH NOWAIT
        END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'dd_ApplyDataDictionary' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.dd_ApplyDataDictionary AS SELECT 1') 
END
GO

ALTER PROC dbo.dd_ApplyDataDictionary
AS

/**************************************************************************************************************
**  Purpose: RUN THIS WHEN YOU ARE READY TO APPLY DATA DICTIONARY TO THE EXTENDED PROPERTIES TABLES
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

    SET NOCOUNT ON
    DECLARE @SQLVersion VARCHAR(30),
        @SchemaOrUser sysname

    SET @SQLVersion = CONVERT(VARCHAR, SERVERPROPERTY('ProductVersion'))
    IF CAST(LEFT(@SQLVersion, CHARINDEX('.', @SQLVersion) - 1) AS TINYINT) < 9 
        SET @SchemaOrUser = 'User'
    ELSE 
        SET @SchemaOrUser = 'Schema'

    DECLARE @SchemaName sysname,
        @TableName sysname,
        @FieldName sysname,
        @ObjectDescription VARCHAR(7000)
	
    DECLARE csr_dd CURSOR FAST_FORWARD
        FOR SELECT  DT.SchemaName,
                    DT.TableName,
                    DT.TableDescription
            FROM    dbo.DataDictionary_Tables AS DT
                    INNER JOIN INFORMATION_SCHEMA.TABLES AS T
                        ON DT.SchemaName COLLATE Latin1_General_CI_AS = T.TABLE_SCHEMA COLLATE Latin1_General_CI_AS
                           AND DT.TableName COLLATE Latin1_General_CI_AS = T.TABLE_NAME COLLATE Latin1_General_CI_AS
            WHERE   DT.TableDescription <> ''
	
    OPEN csr_dd
    FETCH NEXT FROM csr_dd INTO @SchemaName, @TableName, @ObjectDescription
    WHILE @@FETCH_STATUS = 0
        BEGIN
            IF EXISTS ( SELECT  1
                        FROM    ::fn_listextendedproperty(NULL, @SchemaOrUser,
                                                        @SchemaName, 'table',
                                                        @TableName, default,
                                                        default) ) 
                EXECUTE sp_updateextendedproperty N'MS_Description',
                    @ObjectDescription, @SchemaOrUser, @SchemaName, N'table',
                    @TableName, NULL, NULL
            ELSE 
                EXECUTE sp_addextendedproperty N'MS_Description',
                    @ObjectDescription, @SchemaOrUser, @SchemaName, N'table',
                    @TableName, NULL, NULL
	
            RAISERROR ( 'DOCUMENTED TABLE: %s', 10, 1, @TableName ) WITH NOWAIT
            FETCH NEXT FROM csr_dd INTO @SchemaName, @TableName,
                @ObjectDescription
        END
    CLOSE csr_dd
    DEALLOCATE csr_dd
    DECLARE csr_ddf CURSOR FAST_FORWARD
        FOR SELECT  DT.SchemaName,
                    DT.TableName,
                    DT.FieldName,
                    DT.FieldDescription
            FROM    dbo.DataDictionary_Fields AS DT
                    INNER JOIN INFORMATION_SCHEMA.COLUMNS AS T
                        ON DT.SchemaName COLLATE Latin1_General_CI_AS = T.TABLE_SCHEMA COLLATE Latin1_General_CI_AS
                           AND DT.TableName COLLATE Latin1_General_CI_AS = T.TABLE_NAME COLLATE Latin1_General_CI_AS
                           AND DT.FieldName COLLATE Latin1_General_CI_AS = T.COLUMN_NAME COLLATE Latin1_General_CI_AS
            WHERE   DT.FieldDescription <> ''
    OPEN csr_ddf
    FETCH NEXT FROM csr_ddf INTO @SchemaName, @TableName, @FieldName,
        @ObjectDescription
    WHILE @@FETCH_STATUS = 0
        BEGIN
            IF EXISTS ( SELECT  *
                        FROM    ::fn_listextendedproperty(NULL, @SchemaOrUser,
                                                        @SchemaName, 'table',
                                                        @TableName, 'column',
                                                        @FieldName) ) 
                EXECUTE sp_updateextendedproperty N'MS_Description',
                    @ObjectDescription, @SchemaOrUser, @SchemaName, N'table',
                    @TableName, N'column', @FieldName
            ELSE 
                EXECUTE sp_addextendedproperty N'MS_Description',
                    @ObjectDescription, @SchemaOrUser, @SchemaName, N'table',
                    @TableName, N'column', @FieldName
            RAISERROR ( 'DOCUMENTED FIELD: %s.%s', 10, 1, @TableName,
                @FieldName ) WITH NOWAIT
            FETCH NEXT FROM csr_ddf INTO @SchemaName, @TableName, @FieldName,
                @ObjectDescription
        END
    CLOSE csr_ddf
    DEALLOCATE csr_ddf
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'dd_ScavengeDataDictionaryTables' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.dd_ScavengeDataDictionaryTables AS SELECT 1')
END
GO

ALTER PROC dbo.dd_ScavengeDataDictionaryTables
AS

/**************************************************************************************************************
**  Purpose:
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

    SET NOCOUNT ON
    IF OBJECT_ID('tempdb..#DataDictionaryTables') IS NOT NULL 
        DROP TABLE #DataDictionaryTables
    DECLARE @SchemaOrUser sysname,
        @SQLVersion VARCHAR(30),
        @SchemaName sysname 
    SET @SQLVersion = CONVERT(VARCHAR, SERVERPROPERTY('ProductVersion'))
    SET @SchemaName = ''
    DECLARE @SchemaList TABLE
        (
          SchemaName sysname NOT NULL
                             PRIMARY KEY CLUSTERED
        )
    INSERT  INTO @SchemaList ( SchemaName )
            SELECT DISTINCT
                    TABLE_SCHEMA
            FROM    INFORMATION_SCHEMA.TABLES
            WHERE   TABLE_TYPE = 'BASE TABLE'
    IF CAST(LEFT(@SQLVersion, CHARINDEX('.', @SQLVersion) - 1) AS TINYINT) < 9 
        SET @SchemaOrUser = 'User'
    ELSE 
        SET @SchemaOrUser = 'Schema'
	
    CREATE TABLE #DataDictionaryTables
        (
          objtype sysname NOT NULL,
          TableName sysname NOT NULL,
          PropertyName sysname NOT NULL,
          TableDescription VARCHAR(7000) NULL
        )
    WHILE @SchemaName IS NOT NULL
        BEGIN
            TRUNCATE TABLE #DataDictionaryTables
		
            SELECT  @SchemaName = MIN(SchemaName)
            FROM    @SchemaList
            WHERE   SchemaName > @SchemaName
		
            IF @SchemaName IS NOT NULL 
                BEGIN
                    RAISERROR ( 'Scavenging schema %s', 10, 1, @SchemaName )
                        WITH NOWAIT
                    INSERT  INTO #DataDictionaryTables
                            (
                              objtype,
                              TableName,
                              PropertyName,
                              TableDescription
						
                            )
                            SELECT  objtype,
                                    objname,
                                    name,
                                    CONVERT(VARCHAR(7000), value)
                            FROM    ::fn_listextendedproperty(NULL,
                                                            @SchemaOrUser,
                                                            @SchemaName,
                                                            'table', default,
                                                            default, default)
                            WHERE   name = 'MS_DESCRIPTION'
                    UPDATE  DT_DEST
                    SET     DT_DEST.TableDescription = DT_SRC.TableDescription
                    FROM    #DataDictionaryTables AS DT_SRC
                            INNER JOIN dbo.DataDictionary_Tables AS DT_DEST
                                ON DT_SRC.TableName COLLATE Latin1_General_CI_AS = DT_DEST.TableName COLLATE Latin1_General_CI_AS
                    WHERE   DT_DEST.SchemaName COLLATE Latin1_General_CI_AS = @SchemaName COLLATE Latin1_General_CI_AS
                            AND DT_SRC.TableDescription IS NOT NULL
                            AND DT_SRC.TableDescription <> ''
                END
        END
    IF OBJECT_ID('tempdb..#DataDictionaryTables') IS NOT NULL 
        DROP TABLE #DataDictionaryTables
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'dd_ScavengeDataDictionaryFields' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.dd_ScavengeDataDictionaryFields AS SELECT 1')
END
GO

ALTER PROC dbo.dd_ScavengeDataDictionaryFields
AS

/**************************************************************************************************************
**  Purpose:
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

SET NOCOUNT ON
IF OBJECT_ID('tempdb..#DataDictionaryFields') IS NOT NULL
     DROP TABLE #DataDictionaryFields
IF OBJECT_ID('tempdb..#TableList') IS NOT NULL
     DROP TABLE #TableList
DECLARE 
    @SchemaOrUser sysname,
    @SQLVersion VARCHAR(30),
    @SchemaName sysname ,
    @TableName sysname
SET @SQLVersion = CONVERT(VARCHAR,SERVERPROPERTY('ProductVersion'))

CREATE TABLE #TableList(SchemaName sysname NOT null,TableName sysname NOT NULL)
INSERT INTO #TableList(SchemaName,TableName)
SELECT TABLE_SCHEMA,TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE='BASE TABLE'

IF CAST(LEFT(@SQLVersion,CHARINDEX('.',@SQLVersion)-1) AS TINYINT) <9
    SET @SchemaOrUser = 'User'
ELSE
    SET @SchemaOrUser='Schema'

CREATE TABLE #DataDictionaryFields (
    objtype sysname  NOT NULL,
    FieldName sysname NOT NULL,
    PropertyName sysname NOT NULL,
    FieldDescription VARCHAR(7000) NULL
)
DECLARE csr_dd CURSOR FAST_FORWARD FOR
    SELECT SchemaName,TableName
    FROM #TableList
OPEN csr_dd

FETCH NEXT FROM csr_dd INTO @SchemaName, @TableName
WHILE @@FETCH_STATUS = 0
    BEGIN
        TRUNCATE TABLE #DataDictionaryFields

        RAISERROR('Scavenging schema.table %s.%s',10,1,@SchemaName,@TableName) WITH NOWAIT
    INSERT INTO #DataDictionaryFields
                ( objtype ,
                  FieldName ,
                  PropertyName ,
                  FieldDescription
                )
        SELECT objtype ,
                objname ,
                   name ,
                   CONVERT(VARCHAR(7000),value )
        FROM   ::fn_listextendedproperty(NULL, @SchemaOrUser, @SchemaName, 'table', @TableName, 'column', default)
        WHERE name='MS_DESCRIPTION'

        UPDATE DT_DEST
        SET DT_DEST.FieldDescription = DT_SRC.FieldDescription
        FROM #DataDictionaryFields AS DT_SRC
            INNER JOIN dbo.DataDictionary_Fields AS DT_DEST
            ON DT_SRC.FieldName COLLATE Latin1_General_CI_AS = DT_DEST.FieldName COLLATE Latin1_General_CI_AS
        WHERE DT_DEST.SchemaName COLLATE Latin1_General_CI_AS = @SchemaName	COLLATE Latin1_General_CI_AS
        AND DT_DEST.TableName COLLATE Latin1_General_CI_AS = @TableName	COLLATE Latin1_General_CI_AS
        AND DT_SRC.FieldDescription IS NOT NULL AND DT_SRC.FieldDescription<>''
        FETCH NEXT FROM csr_dd INTO @SchemaName, @TableName
    END
CLOSE csr_dd
DEALLOCATE csr_dd
IF OBJECT_ID('tempdb..#DataDictionaryFields') IS NOT NULL
     DROP TABLE #DataDictionaryFields
IF OBJECT_ID('tempdb..#TableList') IS NOT NULL
     DROP TABLE #TableList
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'sp_ViewTableExtendedProperties' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.sp_ViewTableExtendedProperties AS SELECT 1')
END
GO

ALTER PROCEDURE dbo.sp_ViewTableExtendedProperties (@tablename nvarchar(255))
AS

/**************************************************************************************************************
**  Purpose:
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  11/06/2012		Michael Rounds			1.0					Comments creation
***************************************************************************************************************/

DECLARE @cmd NVARCHAR (255)

SET @cmd = 'SELECT objtype, objname, name, value FROM fn_listextendedproperty (NULL, ''schema'', ''dbo'', ''table'', ''' + @TABLENAME + ''', ''column'', default);'

EXEC sp_executesql @cmd

GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'usp_TodaysDeadlocks' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.usp_TodaysDeadlocks AS SELECT 1')
END
GO

ALTER PROC [dbo].[usp_TodaysDeadlocks]
AS
BEGIN
SET NOCOUNT ON

CREATE TABLE #DEADLOCKINFO (
	DeadlockDate DATETIME,
	DBName NVARCHAR(128),	
	ProcessInfo NVARCHAR(50),
	VictimHostname NVARCHAR(128),
	VictimLogin NVARCHAR(128),	
	VictimSPID NVARCHAR(5),
	VictimSQL NVARCHAR(MAX),
	LockingHostname NVARCHAR(128),
	LockingLogin NVARCHAR(128),
	LockingSPID NVARCHAR(5),
	LockingSQL NVARCHAR(MAX)
	)

CREATE TABLE #ERRORLOG (
	ID INT IDENTITY(1,1) NOT NULL,
	LogDate DATETIME, 
	ProcessInfo NVARCHAR(100), 
	[Text] NVARCHAR(4000),
	PRIMARY KEY (ID)
	)

INSERT INTO #ERRORLOG
EXEC sp_readerrorlog 0, 1

CREATE TABLE #TEMPDATES (LogDate DATETIME)

INSERT INTO #TEMPDATES (LogDate)
SELECT DISTINCT CONVERT(VARCHAR(30),LogDate,120) as LogDate
FROM #ERRORLOG
WHERE ProcessInfo LIKE 'spid%'
and [text] LIKE '   process id=%'

INSERT INTO #DEADLOCKINFO (DeadLockDate, DBName, ProcessInfo, VictimHostname, VictimLogin, VictimSPID, LockingHostname, LockingLogin, LockingSPID)
SELECT 
DISTINCT CONVERT(VARCHAR(30),b.LogDate,120) AS DeadlockDate,
DB_NAME(SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%currentdb=%',b.[text]),SUM((PATINDEX('%lockTimeout%',b.[text])) - (PATINDEX('%currentdb=%',b.[text])) ) )),11,50)) as DBName,
b.processinfo,
SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%hostname=%',a.[text]),SUM((PATINDEX('%hostpid%',a.[text])) - (PATINDEX('%hostname=%',a.[text])) ) )),10,50)
	AS VictimHostname,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%loginname=%',a.[text]),SUM((PATINDEX('%isolationlevel%',a.[text])) - (PATINDEX('%loginname=%',a.[text])) ) )),11,50) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%loginname=%',a.[text]),SUM((PATINDEX('%isolationlevel%',a.[text])) - (PATINDEX('%loginname=%',a.[text])) ) )),11,50)
	ELSE NULL END AS VictimLogin,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%spid=%',a.[text]),SUM((PATINDEX('%sbid%',a.[text])) - (PATINDEX('%spid=%',a.[text])) ) )),6,10) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%spid=%',a.[text]),SUM((PATINDEX('%sbid%',a.[text])) - (PATINDEX('%spid=%',a.[text])) ) )),6,10)
	ELSE NULL END AS VictimSPID,
SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%hostname=%',b.[text]),SUM((PATINDEX('%hostpid%',b.[text])) - (PATINDEX('%hostname=%',b.[text])) ) )),10,50)
	AS LockingHostname,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%loginname=%',b.[text]),SUM((PATINDEX('%isolationlevel%',b.[text])) - (PATINDEX('%loginname=%',b.[text])) ) )),11,50) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%loginname=%',b.[text]),SUM((PATINDEX('%isolationlevel%',b.[text])) - (PATINDEX('%loginname=%',b.[text])) ) )),11,50)
	ELSE NULL END AS LockingLogin,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%spid=%',b.[text]),SUM((PATINDEX('%sbid=%',b.[text])) - (PATINDEX('%spid=%',b.[text])) ) )),6,10) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%spid=%',b.[text]),SUM((PATINDEX('%sbid=%',b.[text])) - (PATINDEX('%spid=%',b.[text])) ) )),6,10)
	ELSE NULL END AS LockingSPID
FROM #TEMPDATES t
JOIN #ERRORLOG a
	ON CONVERT(VARCHAR(30),t.LogDate,120) = CONVERT(VARCHAR(30),a.LogDate,120)
JOIN #ERRORLOG b
	ON CONVERT(VARCHAR(30),t.LogDate,120) = CONVERT(VARCHAR(30),b.LogDate,120) AND a.[text] LIKE '   process id=%' AND b.[text] LIKE '   process id=%' AND a.ID < b.ID 
GROUP BY b.LogDate,b.processinfo, a.[Text], b.[Text]

SELECT 
DeadlockDate, 
DBName, 
CASE WHEN VictimLogin IS NOT NULL THEN VictimHostname ELSE NULL END AS VictimHostname, 
VictimLogin, 
CASE WHEN VictimLogin IS NOT NULL THEN VictimSPID ELSE NULL END AS VictimSPID, 
LockingHostname, 
LockingLogin,
LockingSPID
FROM #DEADLOCKINFO 
WHERE DeadlockDate >=  CONVERT(DATETIME, CONVERT (VARCHAR(10), GETDATE(), 101)) AND
(VictimLogin IS NOT NULL OR LockingLogin IS NOT NULL)
ORDER BY DeadlockDate ASC

DROP TABLE #ERRORLOG
DROP TABLE #DEADLOCKINFO
DROP TABLE #TEMPDATES

END


GO
/*========================================================================================================================
=================================================REPORT PROCS=============================================================
========================================================================================================================*/
USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'rpt_Queries' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.rpt_Queries AS SELECT 1')
END
GO

ALTER PROC dbo.rpt_Queries (@DateRangeInDays INT)
AS

BEGIN

DECLARE @QueryValue INT

SET @QueryValue = (SELECT QueryValue FROM [dba].dbo.AlertSettings (nolock) WHERE Name = 'LongRunningQueries')

SELECT
collection_time AS DateStamp,
CAST(DATEDIFF(ss,start_time,collection_time) AS INT) AS [ElapsedTime(ss)],
Session_ID AS Session_ID,
[Database_Name] AS [DBName],	
Login_Name AS Login_Name,
SQL_Text AS SQL_Text
FROM [dba].dbo.QueryHistory (nolock) 
WHERE (DATEDIFF(ss,start_time,collection_time)) >= @QueryValue 
AND (DATEDIFF(dd,collection_time,GETDATE())) <= @DateRangeInDays
AND [Database_Name] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
AND sql_text NOT LIKE 'BACKUP DATABASE%'
AND sql_text NOT LIKE 'RESTORE VERIFYONLY%'
AND sql_text NOT LIKE 'ALTER INDEX%'
AND sql_text NOT LIKE 'DECLARE @BlobEater%'
AND sql_text NOT LIKE 'DBCC%'
AND sql_text NOT LIKE 'WAITFOR(RECEIVE%'
ORDER BY collection_time DESC

END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'rpt_Blocking' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.rpt_Blocking AS SELECT 1')
END
GO

ALTER PROC dbo.rpt_Blocking (@DateRangeInDays INT)
AS

BEGIN

SELECT 
DateStamp,
[DBName],
Blocked_Waittime_Seconds AS [ElapsedTime(ss)],
Blocked_Spid AS VictimSPID,
Blocked_Login AS VictimLogin,
Blocked_SQL_Text AS Victim_SQL,
Blocking_Spid AS BlockerSPID,
Offending_Login AS BlockerLogin,
Offending_SQL_Text AS Blocker_SQL
FROM [dba].dbo.BlockingHistory (nolock)
WHERE (DATEDIFF(dd,DateStamp,GETDATE())) <= @DateRangeInDays
ORDER BY DateStamp DESC

END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'rpt_JobHistory' 
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.rpt_JobHistory AS SELECT 1')
END
GO

ALTER PROC dbo.rpt_JobHistory (@JobName NVARCHAR(50), @DateRangeInDays INT)
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.2					Comments creation
***************************************************************************************************************/

BEGIN

SELECT Job_Name AS [JobName], Run_datetime AS [RunDate], run_duration AS [RunTime], CASE WHEN run_status = 1 THEN 'Sucess' WHEN run_status = 3 THEN 'Cancelled' WHEN run_status = 0 THEN 'Error' ELSE 'N/A' END AS [RunOutcome]
FROM
(SELECT job_name, run_datetime,
        SUBSTRING(run_duration, 1, 2) + ':' + SUBSTRING(run_duration, 3, 2) + ':' +
        SUBSTRING(run_duration, 5, 2) AS run_duration, run_status
    FROM
    (SELECT j.name AS job_name,
            run_datetime = CONVERT(DATETIME, RTRIM(run_date)) +  
                (run_time * 9 + run_time % 10000 * 6 + run_time % 100 * 10) / 216e4,
            run_duration = RIGHT('000000' + CONVERT(NVARCHAR(6), run_duration), 6),
            run_status
        FROM msdb..sysjobhistory h
        JOIN msdb..sysjobs j
        ON h.job_id = j.job_id AND h.step_id = 0) t
) t
WHERE (DATEDIFF(dd,run_datetime,GETDATE())) <= @DateRangeInDays
AND job_name = @JobName
ORDER BY run_datetime DESC

END
GO

USE [dba]
GO

IF NOT EXISTS(SELECT * 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE ROUTINE_NAME = 'rpt_HealthReport'
		  AND ROUTINE_SCHEMA = 'dbo'
		  AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
	EXEC ('CREATE PROC dbo.rpt_HealthReport AS SELECT 1')
END
GO

ALTER PROCEDURE [dbo].[rpt_HealthReport] (@Recepients NVARCHAR(200) = NULL, @CC NVARCHAR(200) = NULL, @InsertFlag BIT = 0, @IncludePerfStats BIT = 0, @EmailFlag BIT = 1)
AS

/**************************************************************************************************************
**  Purpose: This procedure generates and emails (using DBMail) an HMTL formatted health report of the server
**
**	EXAMPLE USAGE:
**
**	SEND EMAIL WITHOUT RETAINING DATA
**		EXEC dbo.rpt_HealthReport @Recepients = 'mrounds@quiktrak.com', @CC ='mrounds@quiktrak.com', @InsertFlag = 0, @IncludePerfStats = 1
**	
**	TO POPULATE THE TABLES
**		EXEC dbo.rpt_HealthReport @Recepients = 'mrounds@quiktrak.com', @CC ='mrounds@quiktrak.com', @InsertFlag = 1, @IncludePerfStats = 1
**
**	PULL EMAIL ADDRESSES FROM ALERTSETTINGS TABLE:
**		EXEC dbo.rpt_HealthReport @Recepients = NULL, @CC = NULL, @InsertFlag = 1, @IncludePerfStats = 1
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.2					Comments creation
**	02/29/2012		Michael Rounds			1.3					Added CPU usage to PerfStats section
**  03/13/2012		Michael Rounds			1.3.1				Added Category to Job Stats section
**	03/20/2012		Michael Rounds			1.3.2				Bug fixes, optimizations
**  06/10/2012		Michael Rounds			1.3					Updated to use new FileStatsHistory table, optimized use of #JOBSTATUS
**  08/31/2012		Michael Rounds			1.4					NVARCHAR now used everywhere. Now a stand-alone proc (doesn't need DBA database or objects to run)
**	09/11/2012		Michael Rounds			1.4.1				Combined Long Running Jobs section into Jobs section
**	11/05/2012		Michael Rounds			2.0					Split out System and Server Info, Added VLF info, Added Trace Flag reporting, many bug fixes
**																	Added more File information (split out into File Info and File Stats), cleaned up error log gathering
**	11/27/2012		Michael Rounds			2.1					Tweaked Health Report to show certain elements even if there is no data (eg Trace flags)
**	12/17/2012		Michael Rounds			2.1.1				Changed Health Report to use new logic to gather file stats
**	12/27/2012		Michael Rounds			2.1.2				Fixed a bug in gathering data on db's with different coallation
**	12/31/2012		Michael Rounds			2.2					Added Deadlock section when trace flag 1222 is On.
**	01/07/2013		Michael Rounds			2.2.1				Fixed Divide by zero bug in file stats section
**	02/20/2013		Michael Rounds			2.2.3				Fixed a bug in the Deadlock section where some deadlocks weren't be included in the report
**	04/07/2013		Michael Rounds			2.2.4				Extended the lengths of KBytesRead and KBytesWritte in temp table FILESTATS - NUMERIC(12,2) to (20,2)
**	04/11/2013		Michael Rounds			2.3					Changed the File Stats section to only display last 24 hours of data instead of since last restart
**	04/12/2013		Michael Rounds			2.3.1				Added SQL Server 2012 Compatibility, Changed #TEMPDATES from SELECT INTO - > CREATE, INSERT INTO
**	04/15/2013		Michael Rounds			2.3.2				Expanded Cum_IO_GB, added COALESCE to columns in HTML output to avoid blank HTML blobs, CHAGNED CASTs to BIGINT
***************************************************************************************************************/
    
BEGIN

SET NOCOUNT ON 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @HTML NVARCHAR(MAX),    
		@ReportTitle NVARCHAR(255),  
		@ServerName NVARCHAR(128),
		@Processor NVARCHAR(255),
		@ServerOS NVARCHAR(100),
		@SystemMemory NVARCHAR(20),
		@Days NVARCHAR(5),
		@Hours NVARCHAR(5),
		@Minutes NVARCHAR(5),
		@ISClustered NVARCHAR(10),		
		@SQLVersion NVARCHAR(500),
		@ServerStartDate DATETIME,
		@ServerMemory NVARCHAR(20),
		@ServerCollation NVARCHAR(128),
		@SingleUser NVARCHAR(5),
		@SQLAgent NVARCHAR(10),
		@StartDate DATETIME,
		@EndDate DATETIME,
		@LongQueriesQueryValue INT,
		@BlockingQueryValue INT,
		@DBName NVARCHAR(128),
		@SQL NVARCHAR(MAX),
		@Distributor NVARCHAR(128),
		@DistributionDB NVARCHAR(128),
		@DistSQL NVARCHAR(MAX),
		@MinFileStatsDateStamp DATETIME,
		@SQLVer NVARCHAR(20)

/* STEP 1: GATHER DATA */
IF @@Language <> 'us_english'
BEGIN
SET LANGUAGE us_english
END

SELECT @ReportTitle = 'Database Health Report ('+ CONVERT(NVARCHAR(128), SERVERPROPERTY('ServerName')) + ')'
SELECT @ServerName = CONVERT(NVARCHAR(128), SERVERPROPERTY('ServerName'))

CREATE TABLE #SYSTEMMEMORY (SystemMemory NUMERIC(12,2))

SELECT @SQLVer = LEFT(CONVERT(NVARCHAR(20),SERVERPROPERTY('productversion')),4)

IF CAST(@SQLVer AS NUMERIC(4,2)) < 11
BEGIN
-- (SQL 2008R2 And Below)
EXEC sp_executesql
	N'INSERT INTO #SYSTEMMEMORY (SystemMemory)
	SELECT CAST((physical_memory_in_bytes/1048576.0) / 1024 AS NUMERIC(12,2)) AS SystemMemory FROM sys.dm_os_sys_info'	
END
ELSE BEGIN
-- (SQL 2012 And Above)
EXEC sp_executesql
	N'INSERT INTO #SYSTEMMEMORY (SystemMemory)
	SELECT CAST((physical_memory_kb/1024.0) / 1024 AS NUMERIC(12,2)) AS SystemMemory FROM sys.dm_os_sys_info'
END

SELECT @SystemMemory = SystemMemory FROM #SYSTEMMEMORY

DROP TABLE #SYSTEMMEMORY

CREATE TABLE #SYSINFO (
	[Index] INT,
	Name NVARCHAR(100),
	Internal_Value BIGINT,
	Character_Value NVARCHAR(1000)
	)

INSERT INTO #SYSINFO
EXEC master.dbo.xp_msver

SELECT @ServerOS = 'Windows ' + a.[Character_Value] + ' Version ' + b.[Character_Value] 
FROM #SYSINFO a
CROSS APPLY #SYSINFO b
WHERE a.Name = 'Platform'
AND b.Name = 'WindowsVersion'

CREATE TABLE #PROCESSOR (Value NVARCHAR(128), DATA NVARCHAR(255))

INSERT INTO #PROCESSOR
EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE',
            N'HARDWARE\DESCRIPTION\System\CentralProcessor\0',
            N'ProcessorNameString';
            
SELECT @Processor = Data FROM #Processor

SELECT @ISClustered = CASE SERVERPROPERTY('IsClustered')
						WHEN 0 THEN 'No'
						WHEN 1 THEN 'Yes'
						ELSE 
						'NA' END

SELECT @ServerStartDate = crdate FROM master..sysdatabases WHERE NAME='tempdb'
SELECT @EndDate = GETDATE()
SELECT @Days = DATEDIFF(hh, @ServerStartDate, @EndDate) / 24
SELECT @Hours = DATEDIFF(hh, @ServerStartDate, @EndDate) % 24
SELECT @Minutes = DATEDIFF(mi, @ServerStartDate, @EndDate) % 60

SELECT @SQLVersion = 'Microsoft SQL Server ' + CONVERT(NVARCHAR(128), SERVERPROPERTY('productversion')) + ' ' + 
	CONVERT(NVARCHAR(128), SERVERPROPERTY('productlevel')) + ' ' + CONVERT(NVARCHAR(128), SERVERPROPERTY('edition'))

SELECT @ServerMemory = cntr_value/1024.0 FROM sys.dm_os_performance_counters WHERE counter_name = 'Total Server Memory (KB)'
SELECT @ServerCollation = CONVERT(NVARCHAR(128), SERVERPROPERTY('Collation')) 

SELECT @SingleUser = CASE SERVERPROPERTY ('IsSingleUser')
						WHEN 1 THEN 'Single'
						WHEN 0 THEN 'Multi'
						ELSE
						'NA' END

IF EXISTS (SELECT 1 FROM master..sysprocesses WHERE program_name LIKE N'SQLAgent%')
BEGIN
SET @SQLAgent = 'Up'
END ELSE
BEGIN
SET @SQLAgent = 'Down'
END

/* Cluster Info */
CREATE TABLE #CLUSTER (
	NodeName NVARCHAR(50), 
	Active BIT
	)

IF @ISClustered = 'Yes'
BEGIN

INSERT INTO #CLUSTER (NodeName)
SELECT NodeName FROM sys.dm_os_cluster_nodes 

UPDATE #CLUSTER
SET Active = 1
WHERE NodeName = (SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))
END

/* Trace Flag Status */
CREATE TABLE #TRACESTATUS (TraceFlag INT,[Status] BIT,[Global] BIT,[Session] BIT)

INSERT INTO #TRACESTATUS (TraceFlag, [Status], [Global], [Session])
EXEC ('DBCC TRACESTATUS(-1) WITH NO_INFOMSGS')

/* Disk Stats */
CREATE TABLE #DRIVES ([DriveLetter] NVARCHAR(5),[FreeSpace] BIGINT, ClusterShare BIT)

INSERT INTO #DRIVES (DriveLetter,Freespace)
EXEC master..xp_fixeddrives

IF @ISClustered = 'Yes'
BEGIN
UPDATE #DRIVES
SET ClusterShare = 0

UPDATE #DRIVES
SET ClusterShare = 1
WHERE DriveLetter IN (SELECT DriveName FROM sys.dm_io_cluster_shared_drives)
END

CREATE TABLE #PERFSTATS (
	PerfStatsHistoryID INT, 
	BufferCacheHitRatio NUMERIC(38,13), 
	PageLifeExpectency BIGINT, 
	BatchRequestsPerSecond BIGINT, 
	CompilationsPerSecond BIGINT, 
	ReCompilationsPerSecond BIGINT, 
	UserConnections BIGINT, 
	LockWaitsPerSecond BIGINT, 
	PageSplitsPerSecond BIGINT, 
	ProcessesBlocked BIGINT, 
	CheckpointPagesPerSecond BIGINT, 
	StatDate DATETIME
	)
	
CREATE TABLE #CPUSTATS (
	CPUStatsHistoryID INT, 
	SQLProcessPercent INT, 
	SystemIdleProcessPercent INT, 
	OtherProcessPerecnt INT, 
	DateStamp DATETIME
	)
	
CREATE TABLE #LONGQUERIES (
	DateStamp DATETIME,
	[ElapsedTime(ss)] INT,
	session_id SMALLINT, 
	[DBName] NVARCHAR(128), 
	login_name NVARCHAR(128), 
	sql_text NVARCHAR(MAX)
	)
	
CREATE TABLE #BLOCKING (
	DateStamp DATETIME,
	[DBName] NVARCHAR(128),
	Blocked_Spid SMALLINT,
	Blocking_Spid SMALLINT,
	Blocked_Login NVARCHAR(128),
	Blocked_Waittime_Seconds NUMERIC(12,2),
	Blocked_SQL_Text NVARCHAR(MAX),
	Offending_Login NVARCHAR(128),
	Offending_SQL_Text NVARCHAR(MAX)
	)

CREATE TABLE #SCHEMACHANGES (
	ObjectName NVARCHAR(128), 
	CreateDate DATETIME, 
	LoginName NVARCHAR(128), 
	ComputerName NVARCHAR(128), 
	SQLEvent NVARCHAR(255), 
	[DBName] NVARCHAR(128)
	)
	
CREATE TABLE #FILESTATS (
	[DBName] NVARCHAR(128),
	[DBID] INT,
	[FileID] INT,
	[FileName] NVARCHAR(255),
	[LogicalFileName] NVARCHAR(255),
	[VLFCount] INT,
	DriveLetter NCHAR(1),
	FileMBSize NVARCHAR(30),
	[FileMaxSize] NVARCHAR(30),
	FileGrowth NVARCHAR(30),
	FileMBUsed NVARCHAR(30),
	FileMBEmpty NVARCHAR(30),
	FilePercentEmpty NUMERIC(12,2),
	LargeLDF INT,
	[FileGroup] NVARCHAR(100),
	NumberReads NVARCHAR(30),
	KBytesRead NUMERIC(20,2),
	NumberWrites NVARCHAR(30),
	KBytesWritten NUMERIC(20,2),
	IoStallReadMS NVARCHAR(30),
	IoStallWriteMS NVARCHAR(30),
	Cum_IO_GB NUMERIC(20,2),
	IO_Percent NUMERIC(12,2)
	)
	
CREATE TABLE #JOBSTATUS (
	JobName NVARCHAR(255),
	Category NVARCHAR(255),
	[Enabled] INT,
	StartTime DATETIME,
	StopTime DATETIME,
	AvgRunTime NUMERIC(12,2),
	LastRunTime NUMERIC(12,2),
	RunTimeStatus NVARCHAR(30),
	LastRunOutcome NVARCHAR(20)
	)	

IF EXISTS (SELECT TOP 1 * FROM [dba].dbo.HealthReport)
BEGIN
	SELECT @StartDate = MAX(DateStamp) FROM [dba].dbo.HealthReport
END
ELSE BEGIN
	SELECT @StartDate = GETDATE() -1
END

SELECT @LongQueriesQueryValue = COALESCE(QueryValue,0) FROM [dba].dbo.AlertSettings WHERE Name = 'LongRunningQueries'
SELECT @BlockingQueryValue = COALESCE(QueryValue,0) FROM [dba].dbo.AlertSettings WHERE Name = 'BlockingAlert'	

IF @Recepients IS NULL
BEGIN
SELECT @Recepients = EmailList FROM [dba].dbo.AlertSettings WHERE Name = 'HealthReport'
END

IF @CC IS NULL
BEGIN
SELECT @CC = EmailList2 FROM [dba].dbo.AlertSettings WHERE Name = 'HealthReport'
END

/* PerfStats */
IF @IncludePerfStats = 1
BEGIN
	INSERT INTO #PERFSTATS (PerfStatsHistoryID, BufferCacheHitRatio, PageLifeExpectency, BatchRequestsPerSecond, CompilationsPerSecond, ReCompilationsPerSecond, 
		UserConnections, LockWaitsPerSecond, PageSplitsPerSecond, ProcessesBlocked, CheckpointPagesPerSecond, StatDate)
	SELECT PerfStatsHistoryID, BufferCacheHitRatio, PageLifeExpectency, BatchRequestsPerSecond, CompilationsPerSecond, ReCompilationsPerSecond, UserConnections, 
		LockWaitsPerSecond, PageSplitsPerSecond, ProcessesBlocked, CheckpointPagesPerSecond, StatDate
	FROM [dba].dbo.PerfStatsHistory WHERE StatDate >= GETDATE() -1
	AND DATEPART(mi,StatDate) = 0

	INSERT INTO #CPUSTATS (CPUStatsHistoryID, SQLProcessPercent, SystemIdleProcessPercent, OtherProcessPerecnt, DateStamp)
	SELECT CPUStatsHistoryID, SQLProcessPercent, SystemIdleProcessPercent, OtherProcessPerecnt, DateStamp
	FROM [dba].dbo.CPUStatsHistory WHERE DateStamp >= GETDATE() -1
	AND DATEPART(mi,DateStamp) = 0
END

/* LongQueries */
INSERT INTO #LONGQUERIES (DateStamp, [ElapsedTime(ss)], Session_ID, [DBName], Login_Name, SQL_Text)
SELECT MAX(collection_time) AS DateStamp,MAX(CAST(DATEDIFF(ss,start_time,collection_time) AS INT)) AS [ElapsedTime(ss)],Session_ID,
	[Database_Name] AS [DBName],Login_Name,SQL_Text
FROM [dba].dbo.QueryHistory
WHERE (DATEDIFF(ss,start_time,collection_time)) >= @LongQueriesQueryValue 
AND (DATEDIFF(dd,collection_time,@StartDate)) < 1
AND [Database_Name] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
AND sql_text NOT LIKE 'BACKUP DATABASE%'
AND sql_text NOT LIKE 'RESTORE VERIFYONLY%'
AND sql_text NOT LIKE 'ALTER INDEX%'
AND sql_text NOT LIKE 'DECLARE @BlobEater%'
AND sql_text NOT LIKE 'DBCC%'
AND sql_text NOT LIKE 'WAITFOR(RECEIVE%'
GROUP BY Session_ID, [Database_Name], Login_Name, SQL_Text

/* Blocking */
INSERT INTO #BLOCKING (DateStamp,[DBName],Blocked_Spid,Blocking_Spid,Blocked_Login,Blocked_Waittime_Seconds,Blocked_SQL_Text,Offending_Login,Offending_SQL_Text)
SELECT DateStamp,[DBName],Blocked_Spid,Blocking_Spid,Blocked_Login,Blocked_Waittime_Seconds,Blocked_SQL_Text,Offending_Login,Offending_SQL_Text
FROM [dba].dbo.BlockingHistory
WHERE DateStamp > @StartDate
AND Blocked_Waittime_Seconds >= @BlockingQueryValue

/* SchemaChanges */
CREATE TABLE #TEMP ([DBName] NVARCHAR(128), [Status] INT)

INSERT INTO #TEMP ([DBName], [Status])
SELECT [DBName], 0
FROM [dba].dbo.DatabaseSettings WHERE SchemaTracking = 1 AND [DBName] NOT LIKE 'AdventureWorks%'

SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP WHERE [Status] = 0)

WHILE @DBName IS NOT NULL
BEGIN

SET @SQL = 

'SELECT ObjectName,CreateDate,LoginName,ComputerName,SQLEvent,[DBName]
FROM '+ '[' + @DBName + ']' +'.dbo.SchemaChangeLog
WHERE CreateDate >'''+CONVERT(NVARCHAR(30),@StartDate,121)+'''
AND SQLEvent <> ''UPDATE_STATISTICS''
ORDER BY CreateDate DESC'

INSERT INTO #SCHEMACHANGES (ObjectName,CreateDate,LoginName,ComputerName,SQLEvent,[DBName])
EXEC(@SQL)

UPDATE #TEMP
SET [Status] = 1
WHERE [DBName] = @DBName

SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP WHERE [Status] = 0)

END
DROP TABLE #TEMP

/* FileStats */
CREATE TABLE #LOGSPACE (
	[DBName] NVARCHAR(128) NOT NULL,
	[LogSize] NUMERIC(12,2) NOT NULL,
	[LogPercentUsed] NUMERIC(12,2) NOT NULL,
	[LogStatus] INT NOT NULL
	)

CREATE TABLE #DATASPACE (
	[DBName] NVARCHAR(128) NULL,
	[Fileid] INT NOT NULL,
	[FileGroup] INT NOT NULL,
	[TotalExtents] NUMERIC(12,2) NOT NULL,
	[UsedExtents] NUMERIC(12,2) NOT NULL,
	[FileLogicalName] NVARCHAR(128) NULL,
	[Filename] NVARCHAR(255) NOT NULL
	)

CREATE TABLE #TMP_DB (
	[DBName] NVARCHAR(128)
	) 

SET @SQL = 'DBCC SQLPERF (LOGSPACE) WITH NO_INFOMSGS' 

INSERT INTO #LOGSPACE ([DBName],LogSize,LogPercentUsed,LogStatus)
EXEC(@SQL)

CREATE INDEX IDX_tLogSpace_Database ON #LOGSPACE ([DBName])

INSERT INTO #TMP_DB 
SELECT LTRIM(RTRIM(name)) AS [DBName]
FROM master..sysdatabases 
WHERE category IN ('0', '1','16')
AND DATABASEPROPERTYEX(name,'STATUS')='ONLINE'
ORDER BY name

CREATE INDEX IDX_TMPDB_Database ON #TMP_DB ([DBName])

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB)

WHILE @DBName IS NOT NULL 
BEGIN

SET @SQL = 'USE ' + '[' +@DBName + ']' + '
DBCC SHOWFILESTATS WITH NO_INFOMSGS'

INSERT INTO #DATASPACE ([Fileid],[FileGroup],[TotalExtents],[UsedExtents],[FileLogicalName],[Filename])
EXEC (@SQL)

UPDATE #DATASPACE
SET [DBName] = @DBName
WHERE COALESCE([DBName],'') = ''

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB WHERE [DBName] > @DBName)

END

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB)

WHILE @DBName IS NOT NULL 
BEGIN
 
SET @SQL = 'USE ' + '[' +@DBName + ']' + '
INSERT INTO #FILESTATS (
	[DBName],
	[DBID],
	[FileID],	
	[DriveLetter],
	[Filename],
	[LogicalFileName],
	[Filegroup],
	[FileMBSize],
	[FileMaxSize],
	[FileGrowth],
	[FileMBUsed],
	[FileMBEmpty],
	[FilePercentEmpty])
SELECT	DBName = ''' + '[' + @dbname + ']' + ''',
		DB_ID() AS [DBID],
		SF.FileID AS [FileID],
		LEFT(SF.[FileName], 1) AS DriveLetter,		
		LTRIM(RTRIM(REVERSE(SUBSTRING(REVERSE(SF.[Filename]),0,CHARINDEX(''\'',REVERSE(SF.[Filename]),0))))) AS [Filename],
		SF.name AS LogicalFileName,
		COALESCE(filegroup_name(SF.groupid),'''') AS [Filegroup],
		CAST((SF.size * 8)/1024 AS NVARCHAR) AS [FileMBSize], 
		CASE SF.maxsize 
			WHEN -1 THEN N''Unlimited'' 
			ELSE CONVERT(NVARCHAR(15), (CAST(SF.maxsize AS BIGINT) * 8)/1024) + N'' MB'' 
			END AS FileMaxSize, 
		(CASE WHEN SF.[status] & 0x100000 = 0 THEN CONVERT(NVARCHAR,CEILING((growth * 8192)/(1024.0*1024.0))) + '' MB''
			ELSE CONVERT (NVARCHAR, growth) + '' %'' 
			END) AS FileGrowth,
		CAST(COALESCE(((DSP.UsedExtents * 64.00) / 1024), LSP.LogSize *(LSP.LogPercentUsed/100)) AS BIGINT) AS [FileMBUsed],
		(SF.size * 8)/1024 - CAST(COALESCE(((DSP.UsedExtents * 64.00) / 1024), LSP.LogSize *(LSP.LogPercentUsed/100)) AS BIGINT) AS [FileMBEmpty],
		(CAST(((SF.size * 8)/1024 - CAST(COALESCE(((DSP.UsedExtents * 64.00) / 1024), LSP.LogSize *(LSP.LogPercentUsed/100)) AS BIGINT)) AS DECIMAL) / 
			CAST(CASE WHEN COALESCE((SF.size * 8)/1024,0) = 0 THEN 1 ELSE (SF.size * 8)/1024 END AS DECIMAL)) * 100 AS [FilePercentEmpty]			
FROM sys.sysfiles SF
JOIN master..sysdatabases SDB
	ON db_id() = SDB.[dbid]
JOIN sys.dm_io_virtual_file_stats(NULL,NULL) b
	ON db_id() = b.[database_id] AND SF.fileid = b.[file_id]
LEFT OUTER 
JOIN #DATASPACE DSP
	ON DSP.[Filename] COLLATE DATABASE_DEFAULT = SF.[Filename] COLLATE DATABASE_DEFAULT
LEFT OUTER 
JOIN #LOGSPACE LSP
	ON LSP.[DBName] = SDB.Name
GROUP BY SDB.Name,SF.FileID,SF.[FileName],SF.name,SF.groupid,SF.size,SF.maxsize,SF.[status],growth,DSP.UsedExtents,LSP.LogSize,LSP.LogPercentUsed'

EXEC(@SQL)

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB WHERE [DBName] > @DBName)
END

DROP TABLE #LOGSPACE
DROP TABLE #DATASPACE

UPDATE f
SET f.NumberReads = b.num_of_reads,
	f.KBytesRead = b.num_of_bytes_read / 1024,
	f.NumberWrites = b.num_of_writes,
	f.KBytesWritten = b.num_of_bytes_written / 1024,
	f.IoStallReadMS = b.io_stall_read_ms,
	f.IoStallWriteMS = b.io_stall_write_ms,
	f.Cum_IO_GB = b.CumIOGB,
	f.IO_Percent = b.IOPercent
FROM #FILESTATS f
JOIN (SELECT database_ID, [file_id], num_of_reads, num_of_bytes_read, num_of_writes, num_of_bytes_written, io_stall_read_ms, io_stall_write_ms, 
			CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) / 1024 AS CumIOGB,
			CAST(CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) / 1024 / 
				SUM(CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) / 1024) OVER() * 100 AS DECIMAL(5, 2)) AS IOPercent
		FROM sys.dm_io_virtual_file_stats(NULL,NULL)
		GROUP BY database_id, [file_id],num_of_reads, num_of_bytes_read, num_of_writes, num_of_bytes_written, io_stall_read_ms, io_stall_write_ms) AS b
ON f.[DBID] = b.[database_id] AND f.fileid = b.[file_id]

UPDATE b
SET b.LargeLDF = 
	CASE WHEN CAST(b.FileMBSize AS INT) > CAST(a.FileMBSize AS INT) THEN 1
	ELSE 2 
	END
FROM #FILESTATS a
JOIN #FILESTATS b
ON a.[DBName] = b.[DBName] 
AND a.[FileName] LIKE '%mdf' 
AND b.[FileName] LIKE '%ldf'

/* VLF INFO - USES SAME TMP_DB TO GATHER STATS */
CREATE TABLE #VLFINFO (
	[DBName] NVARCHAR(128) NULL,
	RecoveryUnitId NVARCHAR(3),
	FileID NVARCHAR(3), 
	FileSize NUMERIC(20,0),
	StartOffset BIGINT, 
	FSeqNo BIGINT, 
	[Status] CHAR(1),
	Parity NVARCHAR(4),
	CreateLSN NUMERIC(25,0)
	)

IF CAST(@SQLVer AS NUMERIC(4,2)) < 11
BEGIN
-- (SQL 2008R2 And Below)
SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB)

WHILE @DBName IS NOT NULL 
BEGIN

SET @SQL = 'USE ' + '[' +@DBName + ']' + '
INSERT INTO #VLFINFO (FileID,FileSize,StartOffset,FSeqNo,[Status],Parity,CreateLSN)
EXEC(''DBCC LOGINFO WITH NO_INFOMSGS'');'
EXEC(@SQL)

SET @SQL = 'UPDATE #VLFINFO SET DBName = ''' +@DBName+ ''' WHERE DBName IS NULL;'
EXEC(@SQL)

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB WHERE [DBName] > @DBName)
END
END
ELSE BEGIN
-- (SQL 2012 And Above)
SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB)

WHILE @DBName IS NOT NULL 
BEGIN
 
SET @SQL = 'USE ' + '[' +@DBName + ']' + '
INSERT INTO #VLFINFO (RecoveryUnitID, FileID,FileSize,StartOffset,FSeqNo,[Status],Parity,CreateLSN)
EXEC(''DBCC LOGINFO WITH NO_INFOMSGS'');'
EXEC(@SQL)

SET @SQL = 'UPDATE #VLFINFO SET DBName = ''' +@DBName+ ''' WHERE DBName IS NULL;'
EXEC(@SQL)

SET @DBName = (SELECT MIN([DBName]) FROM #TMP_DB WHERE [DBName] > @DBName)
END
END

DROP TABLE #TMP_DB

UPDATE a
SET a.VLFCount = (SELECT COUNT(1) FROM #VLFINFO WHERE [DBName] = REPLACE(REPLACE(a.DBName,'[',''),']',''))
FROM #FILESTATS a
WHERE COALESCE(a.[FileGroup],'') = ''

SELECT @MinFileStatsDateStamp = FileStatsDateStamp FROM [dba].dbo.FileStatsHistory WHERE FileStatsDateStamp <= DateAdd(hh, -24, GETDATE())

UPDATE c
SET c.NumberReads = d.NumberReads,
	c.KBytesRead = d.KBytesRead,
	c.NumberWrites = d.NumberWrites,
	c.KBytesWritten = d.KBytesWritten,
	c.IoStallReadMS = d.IoStallReadMS,
	c.IoStallWriteMS = d.IoStallWriteMS,
	c.Cum_IO_GB = d.Cum_IO_GB
FROM #FILESTATS c
LEFT OUTER
JOIN (SELECT
		b.dbname,
		b.[FileName],
		SUM(CAST(b.NumberReads AS BIGINT) - CAST(a.NumberReads AS BIGINT)) AS NumberReads,
		SUM(b.KBytesRead - a.KBytesRead) AS KBytesRead,
		SUM(CAST(b.NumberWrites AS BIGINT) - CAST(a.NumberWrites AS BIGINT)) AS NumberWrites,
		SUM(b.KBytesWritten - a.KBytesWritten) AS KBytesWritten,
		SUM(CAST(b.IoStallReadMS AS BIGINT) - CAST(a.IoStallReadMS AS BIGINT)) AS IoStallReadMS,
		SUM(CAST(b.IoStallWriteMS AS BIGINT) - CAST(a.IoStallWriteMS AS BIGINT)) AS IoStallWriteMS,
		SUM(b.Cum_IO_GB - a.Cum_IO_GB) AS Cum_IO_GB
		FROM [dba].dbo.FileStatsHistory a
		LEFT OUTER
		JOIN #FILESTATS b
			ON a.dbname = b.dbname 
			AND a.[FileName] = b.[FileName]
		WHERE a.FileStatsDateStamp = @MinFileStatsDateStamp
		GROUP BY b.DBName,b.[FileName]) d
	ON c.dbname = d.dbname 
	AND c.[FileName] = d.[FileName]

/* JobStats */
SELECT sj.job_id, 
		sj.name,
		sc.name AS Category,
		sj.[Enabled], 
		sjs.last_run_outcome,
		(SELECT MAX(run_date) 
			FROM msdb..sysjobhistory(nolock) sjh 
			WHERE sjh.job_id = sj.job_id) AS last_run_date
INTO #TEMPJOB
FROM msdb..sysjobs(nolock) sj
JOIN msdb..sysjobservers(nolock) sjs
	ON sjs.job_id = sj.job_id
JOIN msdb..syscategories sc
	ON sj.category_id = sc.category_id	

INSERT INTO #JOBSTATUS (JobName,Category,[Enabled],StartTime,StopTime,AvgRunTime,LastRunTime,RunTimeStatus,LastRunOutcome)
SELECT
	t.name AS JobName,
	t.Category,
	t.[Enabled],
	MAX(ja.start_execution_date) AS [StartTime],
	MAX(ja.stop_execution_date) AS [StopTime],
	COALESCE(AvgRunTime,0) AS AvgRunTime,
	CASE 
		WHEN ja.stop_execution_date IS NULL THEN COALESCE(DATEDIFF(ss,ja.start_execution_date,GETDATE()),0)
		ELSE DATEDIFF(ss,ja.start_execution_date,ja.stop_execution_date) END AS [LastRunTime],
	CASE 
			WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL THEN
				CASE WHEN DATEDIFF(ss,ja.start_execution_date,GETDATE())
					> (AvgRunTime + AvgRunTime * .25) THEN 'LongRunning-NOW'				
				ELSE 'NormalRunning-NOW'
				END
			WHEN DATEDIFF(ss,ja.start_execution_date,ja.stop_execution_date) 
				> (AvgRunTime + AvgRunTime * .25) THEN 'LongRunning-History'
			WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NULL THEN 'NA'
			ELSE 'NormalRunning-History'
	END AS [RunTimeStatus],	
	CASE
		WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL THEN 'InProcess'
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 3 THEN 'CANCELLED'
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 0 THEN 'ERROR'			
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 1 THEN 'SUCCESS'			
		ELSE 'NA'
	END AS [LastRunOutcome]
FROM #TEMPJOB AS t
LEFT OUTER
JOIN (SELECT MAX(session_id) as session_id,job_id FROM msdb.dbo.sysjobactivity(nolock) WHERE run_requested_date IS NOT NULL GROUP BY job_id) AS ja2
	ON t.job_id = ja2.job_id
LEFT OUTER
JOIN msdb.dbo.sysjobactivity(nolock) ja
	ON ja.session_id = ja2.session_id and ja.job_id = t.job_id
LEFT OUTER 
JOIN (SELECT job_id,
			AVG	((run_duration/10000 * 3600) + ((run_duration%10000)/100*60) + (run_duration%10000)%100) + 	STDEV ((run_duration/10000 * 3600) + 
				((run_duration%10000)/100*60) + (run_duration%10000)%100) AS [AvgRuntime]
		FROM msdb..sysjobhistory(nolock)
		WHERE step_id = 0 AND run_status = 1 and run_duration >= 0
		GROUP BY job_id) art 
	ON t.job_id = art.job_id
GROUP BY t.name,t.Category,t.[Enabled],t.last_run_outcome,ja.start_execution_date,ja.stop_execution_date,AvgRunTime
ORDER BY t.name

DROP TABLE #TEMPJOB

/* Replication Distributor */
CREATE TABLE #REPLINFO (
	distributor NVARCHAR(128) NULL, 
	[distribution database] NVARCHAR(128) NULL, 
	directory NVARCHAR(500), 
	account NVARCHAR(200), 
	[min distrib retention] INT, 
	[max distrib retention] INT, 
	[history retention] INT,
	[history cleanup agent] NVARCHAR(500),
	[distribution cleanup agent] NVARCHAR(500),
	[rpc server name] NVARCHAR(200),
	[rpc login name] NVARCHAR(200),
	publisher_type NVARCHAR(200)
	)

INSERT INTO #REPLINFO
EXEC sp_helpdistributor

/* Replication Publisher */	
CREATE TABLE #PUBINFO (
	publisher_db NVARCHAR(128),
	publication NVARCHAR(128),
	publication_id INT,
	publication_type INT,
	[status] INT,
	warning INT,
	worst_latency INT,
	best_latency INT,
	average_latency INT,
	last_distsync DATETIME,
	[retention] INT,
	latencythreshold INT,
	expirationthreshold INT,
	agentnotrunningthreshold INT,
	subscriptioncount INT,
	runningdisagentcount INT,
	snapshot_agentname NVARCHAR(128) NULL,
	logreader_agentname NVARCHAR(128) NULL,
	qreader_agentname NVARCHAR(128) NULL,
	worst_runspeedPerf INT,
	best_runspeedPerf INT,
	average_runspeedPerf INT,
	retention_period_unit INT
	)
	
SELECT @Distributor = distributor, @DistributionDB = [distribution database] FROM #REPLINFO

IF @Distributor = @@SERVERNAME
BEGIN

SET @DistSQL = 
'USE ' + @DistributionDB + '; EXEC sp_replmonitorhelppublication @@SERVERNAME

INSERT 
INTO #PUBINFO
EXEC sp_replmonitorhelppublication @@SERVERNAME'

EXEC(@DistSQL)

END

/* Replication Subscriber */
CREATE TABLE #REPLSUB (
	Publisher NVARCHAR(128),
	Publisher_DB NVARCHAR(128),
	Publication NVARCHAR(128),
	Distribution_Agent NVARCHAR(128),
	[Time] DATETIME,
	Immediate_Sync BIT
	)

INSERT INTO #REPLSUB
EXEC master.sys.sp_MSForEachDB 'USE [?]; 
								IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE Table_Name = ''MSreplication_subscriptions'') 
								BEGIN 
								SELECT Publisher,Publisher_DB,Publication,Distribution_Agent,[time],immediate_sync FROM MSreplication_subscriptions 
								END'

/* Databases */
CREATE TABLE #DATABASES (
	[DBName] NVARCHAR(128),
	CreateDate DATETIME,
	RestoreDate DATETIME,
	[Size(GB] NUMERIC(20,5),
	[State] NVARCHAR(20),
	[Recovery] NVARCHAR(20),
	[Replication] NVARCHAR(5) DEFAULT('No'),
	Mirroring NVARCHAR(5) DEFAULT('No')
	)

INSERT INTO #DATABASES ([DBName],CreateDate,RestoreDate,[Size(GB],[State],[Recovery])
SELECT MST.Name,MST.create_date,rs.RestoreDate,SUM(CONVERT(DECIMAL,(f.FileMBSize)) / 1024) AS [Size(GB],MST.state_desc,MST.recovery_model_desc
FROM sys.databases MST
JOIN #FILESTATS F
	ON MST.database_id = f.[dbID]
LEFT OUTER
JOIN (SELECT destination_database_name AS DBName,
		MAX(restore_date) AS RestoreDate
		FROM msdb..restorehistory
		GROUP BY destination_database_name) AS rs
	ON MST.Name = rs.DBName	
GROUP BY MST.Name,MST.create_date,rs.RestoreDate,MST.state_desc,MST.recovery_model_desc

UPDATE d
SET d.Mirroring = 'Yes'
FROM #Databases d
JOIN master..sysdatabases a
	ON d.[DBName] = a.Name
JOIN sys.database_mirroring b
	ON b.database_id = a.[dbid]
WHERE b.mirroring_state IS NOT NULL

UPDATE d
SET d.[Replication] = 'Yes'
FROM #Databases d
JOIN #REPLSUB r
	ON d.[DBName] = r.Publication

UPDATE d
SET d.[Replication] = 'Yes'
FROM #Databases d
JOIN #PUBINFO p
	ON d.[DBName] = p.Publisher_DB

UPDATE d
SET d.[Replication] = 'Yes'
FROM #Databases d
JOIN #REPLINFO r
	ON d.[DBName] = r.[distribution database]

/* LogShipping */
SELECT b.primary_server, b.primary_database, a.monitor_server, c.secondary_server, c.secondary_database, a.last_backup_date, a.last_backup_file, backup_share
INTO #LOGSHIP
FROM msdb..log_shipping_primary_databases a
JOIN  msdb..log_shipping_monitor_primary b
	ON a.primary_id = b.primary_id
JOIN msdb..log_shipping_primary_secondaries c
	ON a.primary_id = c.primary_id

/* Mirroring */

CREATE TABLE #MIRRORING (
	[DBName] NVARCHAR(128),
	[State] NVARCHAR(50),
	[ServerRole] NVARCHAR(25),
	[PartnerInstance] NVARCHAR(128),
	[SafetyLevel] NVARCHAR(25),
	[AutomaticFailover] NVARCHAR(5),
	WitnessServer NVARCHAR(5)
	)

INSERT INTO #MIRRORING ([DBName], [State], [ServerRole], [PartnerInstance], [SafetyLevel], [AutomaticFailover], [WitnessServer])
SELECT s.name AS [DBName], 
	m.mirroring_state_desc AS [State], 
	m.mirroring_role_desc AS [ServerRole], 
	m.mirroring_partner_instance AS [PartnerInstance],
	CASE WHEN m.mirroring_safety_level_desc = 'FULL' THEN 'HIGH SAFETY' ELSE 'HIGH PERFORMANCE' END AS [SafetyLevel], 
	CASE WHEN m.mirroring_witness_name <> '' THEN 'Yes' ELSE 'No' END AS [AutomaticFailover],
	CASE WHEN m.mirroring_witness_name <> '' THEN m.mirroring_witness_name ELSE 'N/A' END AS [WitnessServer]
FROM master..sysdatabases s
JOIN sys.database_mirroring m
	ON s.[dbid] = m.database_id
WHERE m.mirroring_state IS NOT NULL


/* ErrorLog */
CREATE TABLE #DEADLOCKINFO (
	DeadlockDate DATETIME,
	DBName NVARCHAR(128),	
	ProcessInfo NVARCHAR(50),
	VictimHostname NVARCHAR(128),
	VictimLogin NVARCHAR(128),	
	VictimSPID NVARCHAR(5),
	VictimSQL NVARCHAR(500),
	LockingHostname NVARCHAR(128),
	LockingLogin NVARCHAR(128),
	LockingSPID NVARCHAR(5),
	LockingSQL NVARCHAR(500)
	)

CREATE TABLE #ERRORLOG (
	ID INT IDENTITY(1,1) NOT NULL
		CONSTRAINT PK_ERRORLOGTEMP
			PRIMARY KEY CLUSTERED (ID),
	LogDate DATETIME, 
	ProcessInfo NVARCHAR(100), 
	[Text] NVARCHAR(4000)
	)
	
CREATE TABLE #TEMPDATES (LogDate DATETIME)

INSERT INTO #ERRORLOG
EXEC sp_readerrorlog 0, 1

IF EXISTS (SELECT * FROM #TRACESTATUS WHERE TraceFlag = 1222)
BEGIN
INSERT INTO #TEMPDATES (LogDate)
SELECT DISTINCT CONVERT(VARCHAR(30),LogDate,120) as LogDate
FROM #ERRORLOG
WHERE ProcessInfo LIKE 'spid%'
and [text] LIKE '   process id=%'

INSERT INTO #DEADLOCKINFO (DeadLockDate, DBName, ProcessInfo, VictimHostname, VictimLogin, VictimSPID, LockingHostname, LockingLogin, LockingSPID)
SELECT 
DISTINCT CONVERT(VARCHAR(30),b.LogDate,120) AS DeadlockDate,
DB_NAME(SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%currentdb=%',b.[text]),SUM((PATINDEX('%lockTimeout%',b.[text])) - (PATINDEX('%currentdb=%',b.[text])) ) )),11,50)) as DBName,
b.processinfo,
SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%hostname=%',a.[text]),SUM((PATINDEX('%hostpid%',a.[text])) - (PATINDEX('%hostname=%',a.[text])) ) )),10,50)
	AS VictimHostname,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%loginname=%',a.[text]),SUM((PATINDEX('%isolationlevel%',a.[text])) - (PATINDEX('%loginname=%',a.[text])) ) )),11,50) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%loginname=%',a.[text]),SUM((PATINDEX('%isolationlevel%',a.[text])) - (PATINDEX('%loginname=%',a.[text])) ) )),11,50)
	ELSE NULL END AS VictimLogin,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%spid=%',a.[text]),SUM((PATINDEX('%sbid%',a.[text])) - (PATINDEX('%spid=%',a.[text])) ) )),6,10) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%spid=%',a.[text]),SUM((PATINDEX('%sbid%',a.[text])) - (PATINDEX('%spid=%',a.[text])) ) )),6,10)
	ELSE NULL END AS VictimSPID,
SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%hostname=%',b.[text]),SUM((PATINDEX('%hostpid%',b.[text])) - (PATINDEX('%hostname=%',b.[text])) ) )),10,50)
	AS LockingHostname,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%loginname=%',b.[text]),SUM((PATINDEX('%isolationlevel%',b.[text])) - (PATINDEX('%loginname=%',b.[text])) ) )),11,50) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%loginname=%',b.[text]),SUM((PATINDEX('%isolationlevel%',b.[text])) - (PATINDEX('%loginname=%',b.[text])) ) )),11,50)
	ELSE NULL END AS LockingLogin,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%spid=%',b.[text]),SUM((PATINDEX('%sbid=%',b.[text])) - (PATINDEX('%spid=%',b.[text])) ) )),6,10) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%spid=%',b.[text]),SUM((PATINDEX('%sbid=%',b.[text])) - (PATINDEX('%spid=%',b.[text])) ) )),6,10)
	ELSE NULL END AS LockingSPID
FROM #TEMPDATES t
JOIN #ERRORLOG a
	ON CONVERT(VARCHAR(30),t.LogDate,120) = CONVERT(VARCHAR(30),a.LogDate,120)
JOIN #ERRORLOG b
	ON CONVERT(VARCHAR(30),t.LogDate,120) = CONVERT(VARCHAR(30),b.LogDate,120) AND a.[text] LIKE '   process id=%' AND b.[text] LIKE '   process id=%' AND a.ID < b.ID 
GROUP BY b.LogDate,b.processinfo, a.[Text], b.[Text]

DELETE FROM #ERRORLOG
WHERE CONVERT(VARCHAR(30),LogDate,120) IN (SELECT DeadlockDate FROM #DEADLOCKINFO)

DELETE FROM #DEADLOCKINFO
WHERE (DeadlockDate <  CONVERT(DATETIME, CONVERT (VARCHAR(10), GETDATE(), 101)) -1)
OR (DeadlockDate >= CONVERT(DATETIME, CONVERT (VARCHAR(10), GETDATE(), 101)))

END

DELETE FROM #ERRORLOG
WHERE LogDate < (GETDATE() -1)
OR ProcessInfo = 'Backup'

/* BackupStats */
CREATE TABLE #BACKUPS (
	ID INT IDENTITY(1,1) NOT NULL
		CONSTRAINT PK_BACKUPS
			PRIMARY KEY CLUSTERED (ID),
	[DBName] NVARCHAR(128),
	[Type] NVARCHAR(50),
	[Filename] NVARCHAR(128),
	Backup_Set_Name NVARCHAR(128),
	Backup_Start_Date DATETIME,
	Backup_Finish_Date DATETIME,
	Backup_Size NUMERIC(20,2),
	Backup_Age INT
	)

INSERT INTO #BACKUPS ([DBName],[Type],[Filename],Backup_Set_Name,backup_start_date,backup_finish_date,backup_size,backup_age)
SELECT a.database_name AS [DBName],
		CASE a.[Type]
		WHEN 'D' THEN 'Full'
		WHEN 'I' THEN 'Diff'
		WHEN 'L' THEN 'Log'
		WHEN 'F' THEN 'File/Filegroup'
		WHEN 'G' THEN 'File Diff'
		WHEN 'P' THEN 'Partial'
		WHEN 'Q' THEN 'Partial Diff'
		ELSE 'Unknown' END AS [Type],
		COALESCE(b.Physical_Device_Name,'N/A') AS [Filename],
		a.name AS Backup_Set_Name,		
		a.backup_start_date,
		a.backup_finish_date,
		CAST((a.backup_size/1024)/1024/1024 AS DECIMAL(10,2)) AS Backup_Size,
		DATEDIFF(hh, MAX(a.backup_finish_date), GETDATE()) AS [Backup_Age] 
FROM msdb..backupset a
JOIN msdb..backupmediafamily b
	ON a.media_set_id = b.media_set_id
WHERE a.backup_start_date > GETDATE() -1
GROUP BY a.database_name, a.[Type],a.name, b.Physical_Device_Name,a.backup_start_date,a.backup_finish_date,a.backup_size

/* STEP 2: CREATE HTML BLOB */

SET @HTML =    
	'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"><html><head><style type="text/css">
	table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
	th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
	th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;border-top-left-radius: 15px 10px; 
		border-top-right-radius: 15px 10px;}  
	td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
	td.c2 {background-color: #F0F0F0}
	td.c1 {background-color: #E0E0E0}
	td.master {border-bottom:0px}
	.Perfth {text-align:center; vertical-align:bottom; color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;
		border-right: 1px solid #41627E; padding: 3px 3px 3px 3px;}
	.Perfthheader {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;border-top-left-radius: 15px 10px; 
		border-top-right-radius: 15px 10px;}  
	.Perftd {text-align:center; vertical-align:bottom; font-size:9px; font-family:arial;border-right: 1px solid #C1DAD7;border-bottom: 1px solid #C1DAD7;
		padding: 3px 1px 3px 1px;}
	.Text {background-color: #E0E0E0}
	.Text2 {background-color: #F0F0F0}	
	.Alert {background-color: #FF0000}
	.Warning {background-color: #FFFF00} 	
	</style></head><body><div>
	<table width="1150"> <tr><th class="header" width="1150">System</th></tr></table></div><div>
	<table width="1150">
	<tr>
	<th width="200">Name</th>
	<th width="300">Processor</th>	
	<th width="250">Operating System</th>	
	<th width="125">Total Memory (GB)</th>
	<th width="200">Uptime</th>
	<th width="75">Clustered</th>	
	</tr>'
SELECT @HTML = @HTML + 
	'<tr><td width="200" class="c1">'+@ServerName +'</td>' +
	'<td width="300" class="c2">'+@Processor +'</td>' +
	'<td width="250" class="c1">'+@ServerOS +'</td>' +
	'<td width="125" class="c2">'+@SystemMemory+'</td>' +	
	'<td width="200" class="c1">'+@Days+' days, '+@Hours+' hours & '+@Minutes+' minutes' +'</td>' +
	'<td width="75" class="c2"><b>'+@ISClustered+'</b></td></tr>'
SELECT @HTML = @HTML + 	'</table></div>'

SELECT @HTML = @HTML + 
'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">SQL Server</th></tr></table></div><div>
	<table width="1150">
	<tr>
	<th width="350">Version</th>	
	<th width="150">Start Up Date</th>
	<th width="100">Used Memory (MB)</th>
	<th width="100">Collation</th>
	<th width="75">User Mode</th>
	<th width="75">SQL Agent</th>	
	</tr>'
SELECT @HTML = @HTML + 
	'<tr><td width="350" class="c1">'+@SQLVersion +'</td>' +
	'<td width="150" class="c2">'+CAST(@ServerStartDate AS NVARCHAR)+'</td>' +
	'<td width="100" class="c1">'+CAST(@ServerMemory AS NVARCHAR)+'</td>' +
	'<td width="100" class="c2">'+@ServerCollation+'</td>' +
	CASE WHEN @SingleUser = 'Multi' THEN '<td width="75" class="c1"><b>Multi</b></td>'  
		 WHEN @SingleUser = 'Single' THEN '<td width="75" bgcolor="#FFFF00"><b>Single</b></td>'
	ELSE '<td width="75" bgcolor="#FF0000"><b>UNKNOWN</b></td>'
	END +	
	CASE WHEN @SQLAgent = 'Up' THEN '<td width="75" bgcolor="#00FF00"><b>Up</b></td></tr>'  
		 WHEN @SQLAgent = 'Down' THEN '<td width="75" bgcolor="#FF0000"><b>DOWN</b></td></tr>'  
	ELSE '<td width="75" bgcolor="#FF0000"><b>UNKNOWN</b></td></tr>'  
	END

SELECT @HTML = @HTML + '</table></div>'

SELECT @HTML = @HTML +
'&nbsp;<table width="1150"><tr><td class="master" width="850" rowspan="3">
	<div><table width="850"> <tr><th class="header" width="850">Databases</th></tr></table></div><div>
	<table width="850">
	  <tr>
		<th width="175">Database</th>
		<th width="150">Create Date</th>
		<th width="150">Restore Date</th>
		<th width="80">Size (GB)</th>
		<th width="70">State</th>
		<th width="75">Recovery</th>
		<th width="75">Replicated</th>
		<th width="75">Mirrored</th>				
	 </tr>'
SELECT @HTML = @HTML +   
	'<tr><td width="175" class="c1">' + [DBName] +'</td>' +
	'<td width="150" class="c2">' + CAST(CreateDate AS NVARCHAR) +'</td>' +
	'<td width="150" class="c1">' + COALESCE(CAST(RestoreDate AS NVARCHAR),'N/A') +'</td>' +   	 
	'<td width="80" class="c2">' + CAST([Size(GB] AS NVARCHAR) +'</td>' +    
 	CASE [State]    
		WHEN 'OFFLINE' THEN '<td width="70" bgColor="#FF0000"><b>OFFLINE</b></td>'
		WHEN 'ONLINE' THEN '<td width="70" class="c1">ONLINE</td>'  
	ELSE '<td width="70" bgcolor="#FF0000"><b>UNKNOWN</b></td>'
	END +
	'<td width="75" class="c2">' + [Recovery] +'</td>' +
	'<td width="75" class="c1">' + [Replication] +'</td>' +
	'<td width="75" class="c2">' + Mirroring +'</td></tr>'		
FROM #DATABASES
ORDER BY [DBName]

SELECT @HTML = @HTML + '</table></div>'

SELECT @HTML = @HTML + '</td><td class="master" width="250" valign="top">'

SELECT @HTML = @HTML + 
	'<div><table width="250"> <tr><th class="header" width="250">Disks</th></tr></table></div><div>
	<table width="250">
	  <tr>
		<th width="50">Drive</th>
		<th width="100">Free Space (GB)</th>
		<th width="100">Cluster Share</th>		
	 </tr>'
SELECT @HTML = @HTML +   
	'<tr><td width="50" class="c1">' + DriveLetter + ':' +'</td>' +    
	CASE  
		WHEN (COALESCE(CAST(CAST(FreeSpace AS DECIMAL(10,2))/1024 AS DECIMAL(10,2)), 0) <= 20) 
			THEN '<td width="100" bgcolor="#FF0000"><b>' + COALESCE(CONVERT(NVARCHAR(50), COALESCE(CAST(CAST(FreeSpace AS DECIMAL(10,2))/1024 AS DECIMAL(10,2)), 0)),'') +'</b></td>'
		ELSE '<td width="100" class="c2">' + COALESCE(CONVERT(NVARCHAR(50), COALESCE(CAST(CAST(FreeSpace AS DECIMAL(10,2))/1024 AS DECIMAL(10,2)), 0)),'') +'</td>' 
		END +
	CASE ClusterShare
		WHEN 1 THEN '<td width="100" class="c1">Yes</td></tr>'
		WHEN 0 THEN '<td width="100" class="c1">No</td></tr>'
		ELSE '<td width="100" class="c1">N/A</td></tr>'
		END
FROM #DRIVES

SELECT @HTML = @HTML + '</table></div>'

SELECT @HTML = @HTML + '<tr><td class="master" width="250" valign="top">'

IF EXISTS (SELECT * FROM #CLUSTER)
BEGIN
SELECT @HTML = @HTML + 
	'&nbsp;<div><table width="250"> <tr><th class="header" width="250">Clustering</th></tr></table></div><div>
	<table width="250">
	  <tr>
		<th width="175">Cluster Name</th>
		<th width="75">Active</th>
	 </tr>'
SELECT @HTML = @HTML +   
	'<tr><td width="175" class="c1">' + NodeName +'</td>' +    
	CASE Active
		WHEN 1 THEN '<td width="75" class="c2">Yes</td></tr>'
		ELSE '<td width="75" class="c2">No</td></tr>'
		END
FROM #CLUSTER

SELECT @HTML = @HTML + '</table></div>'
END

SELECT @HTML = @HTML + '<tr><td class="master" width="250" valign="top">'

IF EXISTS (SELECT * FROM #TRACESTATUS)
BEGIN
SELECT @HTML = @HTML + 
	'&nbsp;<div><table width="250"> <tr><th class="header" width="250">Trace Flags</th></tr></table></div><div>
	<table width="250">
	  <tr>
		<th width="65">Trace Flag</th>
		<th width="65">Status</th>
		<th width="60">Global</th>
		<th width="60">Session</th>				
	 </tr>'
SELECT @HTML = @HTML + '<tr><td width="65" class="c1">' + CAST([TraceFlag] AS NVARCHAR) + '</td>' +    
	CASE [Status]
		WHEN 1 THEN '<td width="65" class="c2">Active</td>'
		ELSE '<td width="65" class="c2">Inactive</td>'
		END +
	CASE [Global]
		WHEN 1 THEN '<td width="60" class="c1">On</td>'
		ELSE '<td width="60" class="c1">Off</td>'
		END +
	CASE [Session]
		WHEN 1 THEN '<td width="60" class="c2">On</td></tr>'
		ELSE '<td width="60" class="c2">Off</td></tr>'
		END	
FROM #TRACESTATUS

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT @HTML = @HTML + 
	'&nbsp;<div><table width="250"> <tr><th class="header" width="250">Trace Flags</th></tr></table></div><div>
	<table width="250">
	  <tr>
		<th width="250"><b>No Trace Flags Are Active</b></th>			
	 </tr>'

SELECT @HTML = @HTML + '</table></div>'
END

SELECT @HTML = @HTML + '</td></tr></table>'

SELECT @HTML = @HTML + 
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">File Info</th></tr></table></div><div>
	<table width="1150">
	  <tr>
		<th width="150">Database</th>
		<th width="50">Drive</th>
		<th width="250">Filename</th>
		<th width="150">Logical Name</th>
		<th width="100">Group</th>
		<th width="75">VLF Count</th>
		<th width="75">Size (MB)</th>
		<th width="75">Growth</th>
		<th width="75">Used (MB)</th>
		<th width="75">Empty (MB)</th>
		<th width="75">% Empty</th>
	 </tr>'
SELECT @HTML = @HTML +
	'<tr><td width="150" class="c1">' + [DBName] +'</td>' +
	'<td width="50" class="c2">' + COALESCE(DriveLetter,'N/A') + ':' +'</td>' +
	'<td width="250" class="c1">' + [Filename] +'</td>' +
	'<td width="150" class="c2">' + [LogicalFilename] +'</td>' +	
	CASE
		WHEN COALESCE([FileGroup],'') <> '' THEN '<td width="100" class="c1">' + [FileGroup] +'</td>'
		ELSE '<td width="100" class="c1">' + 'N/A' +'</td>'
		END +
	'<td width="75" class="c2">' + CAST(COALESCE(VLFCount,'') AS NVARCHAR) +'</td>' +
	CASE
		WHEN (LargeLDF = 1 AND [FileName] LIKE '%ldf') THEN '<td width="75" bgColor="#FFFF00">' + FileMBSize +'</td>'
		ELSE '<td width="75" class="c1">' + FileMBSize +'</td>'
		END +
	'<td width="75" class="c2">' + FileGrowth +'</td>' +
	'<td width="75" class="c1">' + FileMBUsed +'</td>' +
	'<td width="75" class="c2">' + FileMBEmpty +'</td>' +
	'<td width="75" class="c1">' + CAST(FilePercentEmpty AS NVARCHAR) + '</td>' + '</tr>'
FROM #FILESTATS

SELECT @HTML = @HTML + '</table></div>'

SELECT @HTML = @HTML + 
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">File Stats - Last 24 Hours</th></tr></table></div><div>
	<table width="1150">
	  <tr>
		<th width="200">Filename</th>
		<th width="75"># Reads</th>
		<th width="175">KBytes Read</th>
		<th width="75"># Writes</th>
		<th width="175">KBytes Written</th>
		<th width="125">IO Read Wait (MS)</th>
		<th width="125">IO Write Wait (MS)</th>
		<th width="125">Cumulative IO (GB)</th>
		<th width="75">IO %</th>				
	 </tr>'
SELECT @HTML = @HTML +
	'<tr><td width="200" class="c1">' + COALESCE([FileName],'N/A') +'</td>' +
	'<td width="75" class="c2">' + COALESCE(NumberReads,'0') +'</td>' +
	'<td width="175" class="c1">' + COALESCE(CONVERT(NVARCHAR(50), KBytesRead),'') + ' (' + COALESCE(CONVERT(NVARCHAR(50), CAST(KBytesRead / 1024 AS NUMERIC(18,2))),'') +
		  ' MB)' +'</td>' +
	'<td width="75" class="c2">' + COALESCE(NumberWrites,'0') +'</td>' +
	'<td width="175" class="c1">' + COALESCE(CONVERT(NVARCHAR(50), KBytesWritten),'') + ' (' + COALESCE(CONVERT(NVARCHAR(50), CAST(KBytesWritten / 1024 AS NUMERIC(18,2)) ),'') +
		  ' MB)' +'</td>' +
	'<td width="125" class="c2">' + COALESCE(IoStallReadMS,'0') +'</td>' +
	'<td width="125" class="c1">' + COALESCE(IoStallWriteMS,'0') + '</td>' +
	'<td width="125" class="c2">' + CAST(COALESCE(Cum_IO_GB,'0') AS VARCHAR) + '</td>' +
	'<td width="75" class="c1">' + CAST(COALESCE(IO_Percent,'0') AS VARCHAR) + '</td>' + '</tr>'	
FROM #FILESTATS

SELECT @HTML = @HTML + '</table></div>'

IF EXISTS (SELECT * FROM #MIRRORING)
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Mirroring</th></tr></table></div><div>
	<table width="1150">   
	<tr> 
	<th width="150">Database</th>      
	<th width="150">State</th>   
	<th width="150">Server Role</th>   
	<th width="150">Partner Instance</th>
	<th width="150">Safety Level</th>
	<th width="200">Automatic Failover</th>
	<th width="250">Witness Server</th>   
	</tr>'	
SELECT
	@HTML = @HTML +   
	'<tr><td width="150" class="c1">' + COALESCE([DBName],'N/A') +'</td>' +
	'<td width="150" class="c2">' + COALESCE([State],'N/A') +'</td>' +  
	'<td width="150" class="c1">' + COALESCE([ServerRole],'N/A') +'</td>' +  
	'<td width="150" class="c2">' + COALESCE([PartnerInstance],'N/A') +'</td>' +  
	'<td width="150" class="c1">' + COALESCE([SafetyLevel],'N/A') +'</td>' +  
	'<td width="200" class="c2">' + COALESCE([AutomaticFailover],'N/A') +'</td>' +  
	'<td width="250" class="c1">' + COALESCE([WitnessServer],'N/A') +'</td>' +  
	 '</tr>'
FROM #MIRRORING
ORDER BY [DBName]

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Mirroring</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">Mirroring is not setup on this system</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #LOGSHIP)
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Log Shipping</th></tr></table></div><div>
	<table width="1150">   
	<tr> 
	<th width="150">Primary Server</th>      
	<th width="150">Primary DB</th>   
	<th width="150">Monitoring Server</th>   
	<th width="150">Secondary Server</th>
	<th width="150">Secondary DB</th>
	<th width="200">Last Backup Date</th>
	<th width="250">Backup Share</th>   
	</tr>'
SELECT
	@HTML = @HTML +   
	'<tr><td width="150" class="c1">' + COALESCE(primary_server,'N/A') +'</td>' +
	'<td width="150" class="c2">' + COALESCE(primary_database,'N/A') +'</td>' +  
	'<td width="150" class="c1">' + COALESCE(monitor_server,'N/A') +'</td>' +  
	'<td width="150" class="c2">' + COALESCE(secondary_server,'N/A') +'</td>' +  
	'<td width="150" class="c1">' + COALESCE(secondary_database,'N/A') +'</td>' +  
	'<td width="200" class="c2">' + COALESCE(CAST(last_backup_date AS NVARCHAR),'N/A') +'</td>' +  
	'<td width="250" class="c1">' + COALESCE(backup_share,'N/A') +'</td>' +  
	 '</tr>'
FROM #LOGSHIP
ORDER BY Primary_Database

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Log Shipping</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">Log Shipping is not setup on this system</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #REPLINFO WHERE Distributor IS NOT NULL)
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Replication Distributor</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="150">Distributor</th>      
			<th width="150">Distribution DB</th>   
			<th width="500">Replcation Share</th>   
			<th width="200">Replication Account</th>
			<th width="150">Publisher Type</th>
		</tr>'
SELECT
	@HTML = @HTML +   
	'<tr><td width="150" class="c1">' + COALESCE(Distributor,'N/A') +'</td>' +
	'<td width="150" class="c2">' + COALESCE([distribution database],'N/A') +'</td>' +  
	'<td width="500" class="c1">' + COALESCE(CAST(directory AS NVARCHAR),'N/A') +'</td>' +  
	'<td width="200" class="c2">' + COALESCE(CAST(account AS NVARCHAR),'N/A') +'</td>' +  
	'<td width="150" class="c1">' + COALESCE(CAST(publisher_type AS NVARCHAR),'N/A') +'</td></tr>'
FROM #REPLINFO

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Replication Distributor</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">Distributor is not setup on this system</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #PUBINFO)
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Replication Publisher</th></tr></table></div><div>
	<table width="1150">   
	<tr> 
	<th width="150">Publisher DB</th>      
	<th width="150">Publication</th>   
	<th width="150">Publication Type</th>   
	<th width="75">Status</th>
	<th width="100">Warnings</th>
	<th width="125">Best Latency</th>
	<th width="125">Worst Latency</th>
	<th width="125">Average Latency</th>
	<th width="150">Last Dist Sync</th>				
	</tr>'
SELECT
	@HTML = @HTML +   
	'<tr> 
	<td width="150" class="c1">' + COALESCE(publisher_db,'N/A') +'</td>' +
	'<td width="150" class="c2">' + COALESCE(publication,'N/A') +'</td>' +  
	CASE
		WHEN publication_type = 0 THEN '<td width="150" class="c1">' + 'Transactional Publication' +'</td>'
		WHEN publication_type = 1 THEN '<td width="150" class="c1">' + 'Snapshot Publication' +'</td>'
		WHEN publication_type = 2 THEN '<td width="150" class="c1">' + 'Merge Publication' +'</td>'
		ELSE '<td width="150" class="c1">' + 'N/A' +'</td>'
	END +
	CASE
		WHEN [status] = 1 THEN '<td width="75" class="c2">' + 'Started' +'</td>'
		WHEN [status] = 2 THEN '<td width="75" class="c2">' + 'Succeeded' +'</td>'
		WHEN [status] = 3 THEN '<td width="75" class="c2">' + 'In Progress' +'</td>'
		WHEN [status] = 4 THEN '<td width="75" class="c2">' + 'Idle' +'</td>'
		WHEN [status] = 5 THEN '<td width="75" class="c2">' + 'Retrying' +'</td>'
		WHEN [status] = 6 THEN '<td width="75" class="c2">' + 'Failed' +'</td>'
		ELSE '<td width="75" class="c2">' + 'N/A' +'</td>'
	END +
	CASE
		WHEN Warning = 1 THEN '<td width="100" bgcolor="#FFFF00">' + 'Expiration' +'</td>'
		WHEN Warning = 2 THEN '<td width="100" bgcolor="#FFFF00">' + 'Latency' +'</td>'
		WHEN Warning = 4 THEN '<td width="100" bgcolor="#FFFF00">' + 'Merge Expiration' +'</td>'
		WHEN Warning = 8 THEN '<td width="100" bgcolor="#FFFF00">' + 'Merge Fast Run Duration' +'</td>'
		WHEN Warning = 16 THEN '<td width="100" bgcolor="#FFFF00">' + 'Merge Slow Run Duration' +'</td>'
		WHEN Warning = 32 THEN '<td width="100" bgcolor="#FFFF00">' + 'Marge Fast Run Speed' +'</td>'
		WHEN Warning = 64 THEN '<td width="100" bgcolor="#FFFF00">' + 'Merge Slow Run Speed' +'</td>'
		ELSE '<td width="100" class="c1">' + 'N/A'														
	END +
	CASE
		WHEN publication_type = 0 THEN '<td width="125" class="c2">' + CAST(Best_Latency AS NVARCHAR) +'</td>'
		WHEN publication_type = 1 THEN '<td width="125" class="c2">' + CAST(Best_RunSpeedPerf AS NVARCHAR) +'</td>'
	END +
	CASE
		WHEN publication_type = 0 THEN '<td width="125" class="c1">' + CAST(Worst_Latency AS NVARCHAR) +'</td>'
		WHEN publication_type = 1 THEN '<td width="125" class="c1">' + CAST(Worst_RunSpeedPerf AS NVARCHAR) +'</td>'
	END +
	CASE
		WHEN publication_type = 0 THEN '<td width="125" class="c2">' + CAST(Average_Latency AS NVARCHAR) +'</td>'
		WHEN publication_type = 1 THEN '<td width="125" class="c2">' + CAST(Average_RunSpeedPerf AS NVARCHAR) +'</td>'
	END +
	'<td width="150" class="c1">' + CAST(Last_DistSync AS NVARCHAR) +'</td>' + 
	'</tr>'
FROM #PUBINFO

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Replication Publisher</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">Publisher is not setup on this system</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #REPLSUB)
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Replication Subscriptions</th></tr></table></div><div>
	<table width="1150">   
	<tr> 
	<th width="150">Publisher</th>      
	<th width="150">Publisher DB</th>   
	<th width="150">Publication</th>   
	<th width="450">Distribution Job</th>
	<th width="150">Last Sync</th>
	<th width="100">Immediate Sync</th>
	</tr>'
SELECT
	@HTML = @HTML +   
	'<tr><td width="150" class="c1">' + COALESCE(Publisher,'N/A') +'</td>' +
	'<td width="150" class="c2">' + COALESCE(Publisher_DB,'N/A') +'</td>' +  
	'<td width="150" class="c1">' + COALESCE(Publication,'N/A') +'</td>' +  
	'<td width="450" class="c2">' + COALESCE(Distribution_Agent,'N/A') +'</td>' +  
	'<td width="150" class="c1">' + COALESCE(CAST([time] AS NVARCHAR),'N/A') +'</td>' +  
	CASE [Immediate_sync]
		WHEN 0 THEN '<td width="100" class="c2">' + 'No'  +'</td>'
		WHEN 1 THEN '<td width="100" class="c2">' + 'Yes'  +'</td>'
		ELSE 'N/A'
	END +
	 '</tr>'
FROM #REPLSUB

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Replication Subscriptions</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">Subscriptions are not setup on this system</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #PERFSTATS)
BEGIN
	SELECT @HTML = @HTML + 
		'&nbsp;<div><table width="1150"> <tr><th class="Perfthheader" width="1150">Connections - Last 24 Hours</th></tr></table></div><div>
		<table width="1150">
			<tr>'
	SELECT @HTML = @HTML + '<th class="Perfth"><img src="foo" style="background-color:white;" height="'+ CAST((COALESCE(UserConnections,0) / 2) AS NVARCHAR) +'" width="10" /></th>'
	FROM #PERFSTATS
	GROUP BY StatDate, UserConnections
	ORDER BY StatDate ASC

	SELECT @HTML = @HTML + '</tr><tr>'
	SELECT @HTML = @HTML + '<td class="Perftd"><p class="Text2">'+ CAST(COALESCE(UserConnections,0) AS NVARCHAR) +'</p></td>'
	FROM #PERFSTATS
	GROUP BY StatDate, UserConnections
	ORDER BY StatDate ASC

	SELECT @HTML = @HTML + '</tr><tr>'
	SELECT @HTML = @HTML + '<td class="Perftd"><div class="Text">'+ 
	CAST(CAST(DATEPART(mm, StatDate)AS NVARCHAR) + '/' + 
	CAST(DATEPART(dd, StatDate)AS NVARCHAR) + '/' + 
	CAST(DATEPART(yyyy, StatDate)AS NVARCHAR)
	 + '  ' + 
	RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(hh, StatDate)), 2) + ':' +
	RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(mi, StatDate)), 2)
	 AS NVARCHAR) +'</div></td>'
	FROM #PERFSTATS
	GROUP BY StatDate, UserConnections
	ORDER BY StatDate ASC

	SELECT @HTML = @HTML + '</tr></table></div>&nbsp;'
	SELECT @HTML = @HTML +
		'<div><table width="1150"> <tr><th class="Perfthheader" width="1150">Buffer Hit Cache Ratio - Last 24 Hours</th></tr></table></div><div>
		<table width="1150">
			<tr>'
	SELECT @HTML = @HTML + '<th class="Perfth"><img src="foo" style="background-color:white;" height="'+ CAST((BufferCacheHitRatio/2) AS NVARCHAR) +'" width="10" /></th>'
	FROM #PERFSTATS
	GROUP BY StatDate, BufferCacheHitRatio
	ORDER BY StatDate ASC

	SELECT @HTML = @HTML + '</tr><tr>'
	SELECT @HTML = @HTML + '<td class="Perftd">' + 

	CASE WHEN BufferCacheHitRatio < 98 THEN '<p class="Alert">'+ LEFT(CAST(BufferCacheHitRatio AS NVARCHAR),6) 
		WHEN BufferCacheHitRatio < 99.5 THEN '<p class="Warning">'+ LEFT(CAST(BufferCacheHitRatio AS NVARCHAR),6) 
	ELSE '<p class="Text2">'+ LEFT(CAST(BufferCacheHitRatio AS NVARCHAR),6) 
	END + '</p></td>'
	FROM #PERFSTATS
	GROUP BY StatDate, BufferCacheHitRatio
	ORDER BY StatDate ASC

	SELECT @HTML = @HTML + '</tr><tr>'
	SELECT @HTML = @HTML + '<td class="Perftd"><div class="Text">'+ 
	CAST(CAST(DATEPART(mm, StatDate)AS NVARCHAR) + '/' + 
	CAST(DATEPART(dd, StatDate)AS NVARCHAR) + '/' + 
	CAST(DATEPART(yyyy, StatDate)AS NVARCHAR)
	 + '  ' + 
	RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(hh, StatDate)), 2) + ':' +
	RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(mi, StatDate)), 2)
	 AS NVARCHAR) +'</div></td>'
	FROM #PERFSTATS
	GROUP BY StatDate, BufferCacheHitRatio
	ORDER BY StatDate ASC

	SELECT @HTML = @HTML + '</tr></table></div>'
END

IF EXISTS (SELECT * FROM #CPUSTATS)
BEGIN
	SELECT @HTML = @HTML + 
		'&nbsp;<div><table width="1150"> <tr><th class="Perfthheader" width="1150">SQL Server CPU Usage (Percent) - Last 24 Hours</th></tr></table></div><div>
		<table width="1150">
			<tr>'
	SELECT @HTML = @HTML + '<th class="Perfth"><img src="foo" style="background-color:white;" height="'+ CAST((COALESCE(SQLProcessPercent,0) / 2) AS NVARCHAR) +'" width="10" /></th>'
	FROM #CPUSTATS
	GROUP BY DateStamp, SQLProcessPercent
	ORDER BY DateStamp ASC

	SELECT @HTML = @HTML + '</tr><tr>'
	SELECT @HTML = @HTML + '<td class="Perftd"><p class="Text2">'+ CAST(COALESCE(SQLProcessPercent,0) AS NVARCHAR) +'</p></td>'
	FROM #CPUSTATS
	GROUP BY DateStamp, SQLProcessPercent
	ORDER BY DateStamp ASC

	SELECT @HTML = @HTML + '</tr><tr>'
	SELECT @HTML = @HTML + '<td class="Perftd"><div class="Text">'+ 
	CAST(CAST(DATEPART(mm, DateStamp)AS NVARCHAR) + '/' + 
	CAST(DATEPART(dd, DateStamp)AS NVARCHAR) + '/' + 
	CAST(DATEPART(yyyy, DateStamp)AS NVARCHAR)
	 + '  ' + 
	RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(hh, DateStamp)), 2) + ':' +
	RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(mi, DateStamp)), 2)
	 AS NVARCHAR) +'</div></td>'
	FROM #CPUSTATS
	GROUP BY DateStamp, SQLProcessPercent
	ORDER BY DateStamp ASC

	SELECT @HTML = @HTML + '</tr></table></div>'
END

IF EXISTS (SELECT * FROM #JOBSTATUS)
BEGIN
SELECT @HTML = @HTML + 
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">SQL Agent Jobs</th></tr></table></div><div>
	<table width="1150"> 
	<tr> 
	<th width="275">Job Name</th>
	<th width="150">Category</th> 
	<th width="75">Enabled</th> 
	<th width="100">Last Outcome</th> 
	<th width="150">Last Date Run</th> 
	<th width="200">Avg Run Time ss(Mi)</th> 
	<th width="200">Execution Time ss(Mi)</th>
	</tr>'
SELECT @HTML = @HTML +   
	'<tr><td width="275" class="c1">' + LEFT(JobName,60) +'</td>' +    
	'<td width="150" class="c2">' + COALESCE(Category,'N/A') +'</td>' +    
	CASE [Enabled]
		WHEN 0 THEN '<td width="75" bgcolor="#FFFF00">False</td>'  
		WHEN 1 THEN '<td width="75" class="c1">True</td>'  
	ELSE '<td width="75" class="c1"><b>Unknown</b></td>'  
	END  +   
 	CASE      
		WHEN LastRunOutcome = 'ERROR' AND RunTimeStatus = 'NormalRunning-History' THEN '<td width="150" bgColor="#FF0000"><b>FAILED</b></td>'
		WHEN LastRunOutcome = 'ERROR' AND RunTimeStatus = 'LongRunning-History' THEN '<td width="150"  bgColor="#FF0000"><b>ERROR - Long Running</b></td>'  
		WHEN LastRunOutcome = 'SUCCESS' AND RunTimeStatus = 'NormalRunning-History' THEN '<td width="150"  bgColor="#00FF00">Success</td>'  
		WHEN LastRunOutcome = 'Success' AND RunTimeStatus = 'LongRunning-History' THEN '<td width="150"  bgColor="#99FF00">Success - Long Running</td>'  
		WHEN LastRunOutcome = 'InProcess' THEN '<td width="150" bgColor="#00FFFF">InProcess</td>'  
		WHEN LastRunOutcome = 'InProcess' AND RunTimeStatus = 'LongRunning-NOW' THEN '<td width="150" bgColor="#00FFFF">InProcess</td>'  
		WHEN LastRunOutcome = 'CANCELLED' THEN '<td width="150" bgColor="#FFFF00"><b>CANCELLED</b></td>'  
		WHEN LastRunOutcome = 'NA' THEN '<td width="150" class="c2">NA</td>'  
	ELSE '<td width="150" class="c2">NA</td>' 
	END + 
	'<td width="150" class="c1">' + COALESCE(CAST(StartTime AS NVARCHAR),'N/A') + '</td>' +
	'<td width="200" class="c2">' + COALESCE(CONVERT(NVARCHAR(50), AvgRuntime),'') + ' (' + COALESCE(CONVERT(NVARCHAR(50), AvgRuntime / 60),'') +  ')' + '</td>' +
	'<td width="200" class="c1">' + COALESCE(CONVERT(NVARCHAR(50), LastRunTime),'') + ' (' + COALESCE(CONVERT(NVARCHAR(50), LastRunTime / 60),'') +  ')' + '</td></tr>'   
FROM #JOBSTATUS
ORDER BY JobName

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #LONGQUERIES)
BEGIN
SELECT @HTML = @HTML +   
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Long Running Queries</th></tr></table></div><div>
	<table width="1150">
	<tr>
	<th width="150">Date Stamp</th> 	
	<th width="150">Database</th>
	<th width="75">Time (ss)</th> 
	<th width="75">SPID</th> 	
	<th width="175">Login</th> 	
	<th width="425">Query Text</th>
	</tr>'
SELECT @HTML = @HTML +   
	'<tr>
	<td width="150" class="c1">' + CAST(DateStamp AS NVARCHAR) +'</td>	
	<td width="150" class="c2">' + COALESCE([DBName],'N/A') +'</td>
	<td width="75" class="c1">' + CAST([ElapsedTime(ss)] AS NVARCHAR) +'</td>
	<td width="75" class="c2">' + CAST(Session_id AS NVARCHAR) +'</td>
	<td width="175" class="c1">' + COALESCE(login_name,'N/A') +'</td>	
	<td width="425" class="c2">' + COALESCE(LEFT(sql_text,100),'N/A') +'</td>			
	</tr>'
FROM #LONGQUERIES
ORDER BY DateStamp

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Long Running Queries</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">There has been no recent recorded long running queries</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #BLOCKING)
BEGIN
SELECT @HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Blocking</th></tr></table></div><div>
	<table width="1150">
	<tr> 
	<th width="150">Date Stamp</th> 
	<th width="150">Database</th> 	
	<th width="60">Time (ss)</th> 
	<th width="60">Victim SPID</th>
	<th width="145">Victim Login</th>
	<th width="190">Victim SQL Text</th> 
	<th width="60">Blocking SPID</th> 	
	<th width="145">Blocking Login</th>
	<th width="190">Blocking SQL Text</th> 
	</tr>'
SELECT @HTML = @HTML +   
	'<tr>
	<td width="150" class="c1">' + CAST(DateStamp AS NVARCHAR) +'</td>
	<td width="130" class="c2">' + COALESCE([DBName],'N/A') + '</td>
	<td width="60" class="c1">' + CAST(Blocked_WaitTime_Seconds AS NVARCHAR) +'</td>
	<td width="60" class="c2">' + CAST(Blocked_SPID AS NVARCHAR) +'</td>
	<td width="145" class="c1">' + COALESCE(Blocked_Login,'NA') +'</td>		
	<td width="200" class="c2">' + REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LEFT(Blocked_SQL_Text,100),'CREATE',''),'TRIGGER',''),'PROCEDURE',''),'FUNCTION',''),'PROC','') +'</td>
	<td width="60" class="c1">' + CAST(Blocking_SPID AS NVARCHAR) +'</td>
	<td width="145" class="c2">' + COALESCE(Offending_Login,'NA') +'</td>
	<td width="200" class="c1">' + REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LEFT(Offending_SQL_Text,100),'CREATE',''),'TRIGGER',''),'PROCEDURE',''),'FUNCTION',''),'PROC','') +'</td>	
	</tr>'
FROM #BLOCKING
ORDER BY DateStamp

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Blocking</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">There has been no recent recorded blocking</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #DEADLOCKINFO)
BEGIN
SELECT @HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Deadlocks - Prior Day</th></tr></table></div><div>
	<table width="1150">
	<tr> 
	<th width="150">Date Stamp</th> 
	<th width="150">Database</th> 	
	<th width="75">Victim Hostname</th> 
	<th width="75">Victim Login</th>
	<th width="75">Victim SPID</th>
	<th width="200">Victim Objects</th> 	
	<th width="75">Locking Hostname</th>
	<th width="75">Locking Login</th> 
	<th width="75">Locking SPID</th> 
	<th width="200">Locking Objects</th>
	</tr>'
SELECT @HTML = @HTML +   
	'<tr>
	<td width="150" class="c1">' + CAST(DeadlockDate AS NVARCHAR) +'</td>
	<td width="150" class="c2">' + COALESCE([DBName],'N/A') + '</td>' +
	CASE 
		WHEN VictimLogin IS NOT NULL THEN '<td width="75" class="c1">' + COALESCE(VictimHostname,'NA') +'</td>'
	ELSE '<td width="75" class="c1">NA</td>' 
	END +
	'<td width="75" class="c2">' + COALESCE(VictimLogin,'NA') +'</td>' +
	CASE 
		WHEN VictimLogin IS NOT NULL THEN '<td width="75" class="c1">' + COALESCE(VictimSPID,'NA') +'</td>'
	ELSE '<td width="75" class="c1">NA</td>' 
	END +	
	'<td width="200" class="c2">' + COALESCE(VictimSQL,'N/A') +'</td>
	<td width="75" class="c1">' + COALESCE(LockingHostname,'N/A') +'</td>
	<td width="75" class="c2">' + COALESCE(LockingLogin,'N/A') +'</td>
	<td width="75" class="c1">' + COALESCE(LockingSPID,'N/A') +'</td>		
	<td width="200" class="c2">' + COALESCE(LockingSQL,'N/A') +'</td>
	</tr>'
FROM #DEADLOCKINFO 
WHERE (VictimLogin IS NOT NULL OR LockingLogin IS NOT NULL)
ORDER BY DeadlockDate ASC

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Deadlocks - Previous Day</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">There has been no recent recorded Deadlocks OR TraceFlag 1222 is not Active</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #SCHEMACHANGES)
BEGIN
SELECT @HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Schema Changes</th></tr></table></div><div>
	<table width="1150">
	  <tr>
	  	<th width="150">Create Date</th>
	  	<th width="150">Database</th>
		<th width="150">SQL Event</th>	  		
		<th width="350">Object Name</th>
		<th width="175">Login Name</th>
		<th width="175">Computer Name</th>
	 </tr>'
SELECT @HTML = @HTML +   
	'<tr><td width="150" class="c1">' + CAST(CreateDate AS NVARCHAR) +'</td>' +  
	'<td width="150" class="c2">' + COALESCE([DBName],'N/A') +'</td>' +
	'<td width="150" class="c1">' + COALESCE(SQLEvent,'N/A') +'</td>' +
	'<td width="350" class="c2">' + COALESCE(ObjectName,'N/A') +'</td>' +  
	'<td width="175" class="c1">' + COALESCE(LoginName,'N/A') +'</td>' +  
	'<td width="175" class="c2">' + COALESCE(ComputerName,'N/A') +'</td></tr>'
FROM #SCHEMACHANGES
ORDER BY [DBName], CreateDate

SELECT 
	@HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Schema Changes</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">There has been no recent recorded schema changes</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #ERRORLOG)
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Error Log - Last 24 Hours (Does not include Backup or Deadlock info)</th></tr></table></div><div>
	<table width="1150">
	<tr>
	<th width="150">Log Date</th>
	<th width="150">Process Info</th>
	<th width="850">Message</th>
	</tr>'
SELECT
	@HTML = @HTML +
	'<tr>
	<td width="150" class="c1">' + COALESCE(CAST(LogDate AS NVARCHAR),'N/A') +'</td>' +
	'<td width="150" class="c2">' + COALESCE(ProcessInfo,'N/A') +'</td>' +
	'<td width="850" class="c1">' + COALESCE([text],'N/A') +'</td>' +
	 '</tr>'
FROM #ERRORLOG
ORDER BY LogDate DESC

SELECT @HTML = @HTML + '</table></div>'
END

IF EXISTS (SELECT * FROM #BACKUPS)
BEGIN
SELECT
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Backup Stats - Last 24 Hours</th></tr></table></div><div>
	<table width="1150">
	<tr>
	<th width="150">Database</th>
	<th width="90">Type</th>
	<th width="300">File Name</th>
	<th width="160">Backup Set Name</th>		
	<th width="150">Start Date</th>
	<th width="150">End Date</th>
	<th width="75">Size (GB)</th>
	<th width="75">Age (hh)</th>
	</tr>'
SELECT
	@HTML = @HTML +   
	'<tr> 
	<td width="150" class="c1">' + COALESCE([DBName],'N/A') +'</td>' +
	'<td width="90" class="c2">' + COALESCE([Type],'N/A') +'</td>' +
	'<td width="300" class="c1">' + COALESCE([Filename],'N/A') +'</td>' +
	'<td width="160" class="c2">' + COALESCE(backup_set_name,'N/A') +'</td>' +	
	'<td width="150" class="c1">' + COALESCE(CAST(backup_start_date AS NVARCHAR),'N/A') +'</td>' +  
	'<td width="150" class="c2">' + COALESCE(CAST(backup_finish_date AS NVARCHAR),'N/A') +'</td>' +  
	'<td width="75" class="c1">' + COALESCE(CAST(backup_size AS NVARCHAR),'N/A') +'</td>' +  
	'<td width="75" class="c2">' + COALESCE(CAST(backup_age AS NVARCHAR),'N/A') +'</td>' +  	
	 '</tr>'
FROM #BACKUPS
ORDER BY backup_start_date DESC

SELECT @HTML = @HTML + '</table></div>'
END ELSE
BEGIN
SELECT 
	@HTML = @HTML +
	'&nbsp;<div><table width="1150"> <tr><th class="header" width="1150">Backup Stats - Last 24 Hours</th></tr></table></div><div>
	<table width="1150">   
		<tr> 
			<th width="1150">No backups have been created on this server in the last 24 hours</th>
		</tr>'

SELECT @HTML = @HTML + '</table></div>'
END

SELECT @HTML = @HTML + '&nbsp;<div><table width="1150"><tr><td class="master">Generated on ' + CAST(GETDATE() AS NVARCHAR) + '</td></tr></table></div>'

SELECT @HTML = @HTML + '</body></html>'

/* STEP 3: SEND REPORT */

IF @EmailFlag = 1
BEGIN
EXEC msdb..sp_send_dbmail
	@recipients=@Recepients,
	@copy_recipients=@CC,  
	@subject = @ReportTitle,    
	@body = @HTML,    
	@body_format = 'HTML'
END

/* STEP 4: PRESERVE DATA */

IF @InsertFlag = 1
BEGIN
IF EXISTS (SELECT name FROM master..sysdatabases WHERE name = 'dba')
BEGIN
	INSERT INTO [dba].dbo.HealthReport (GeneratedHTML)
	SELECT @HTML
END
END

DROP TABLE #SYSINFO
DROP TABLE #PROCESSOR
DROP TABLE #DRIVES
DROP TABLE #CLUSTER
DROP TABLE #TRACESTATUS
DROP TABLE #DATABASES
DROP TABLE #FILESTATS
DROP TABLE #VLFINFO
DROP TABLE #JOBSTATUS
DROP TABLE #LONGQUERIES
DROP TABLE #BLOCKING
DROP TABLE #SCHEMACHANGES
DROP TABLE #REPLINFO
DROP TABLE #PUBINFO
DROP TABLE #REPLSUB
DROP TABLE #LOGSHIP
DROP TABLE #MIRRORING
DROP TABLE #ERRORLOG
DROP TABLE #BACKUPS
DROP TABLE #PERFSTATS
DROP TABLE #CPUSTATS
DROP TABLE #DEADLOCKINFO
DROP TABLE #TEMPDATES

END
GO
IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'gen_GetHealthReportHTML' AND ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'PROCEDURE')
BEGIN
DROP PROC dbo.gen_GetHealthReportHTML
END
GO
IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'gen_GetHealthReportToEmail' AND ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'PROCEDURE')
BEGIN
DROP PROC dbo.gen_GetHealthReportToEmail
END
GO
IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'gen_GetHealthReportToFile' AND ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'PROCEDURE')
BEGIN
DROP PROC dbo.gen_GetHealthReportToFile
END
GO
/*======================================================================================================================================================
========================================================================================================================================================
========================================================================================================================================================
========================================================================================================================================================
=============================================================== JOBS ===================================================================================
========================================================================================================================================================
========================================================================================================================================================
========================================================================================================================================================
======================================================================================================================================================*/
	/* CATEGORY */
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Monitoring' AND category_class=1)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Monitoring'
END

	/* JOBS */
USE [msdb]
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'dba_BlockingAlert')
BEGIN
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_BlockingAlert', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Monitoring',
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'SQL_DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run proc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dba].dbo.usp_CheckBlocking', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Check for blocking', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=127, 
		@freq_subday_type=2, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20110308, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=190000
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
END
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'dba_HealthReport')
BEGIN
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_HealthReport', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Monitoring',
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run proc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dba].dbo.rpt_HealthReport @Recepients = NULL, @CC = NULL, @InsertFlag = 1', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20110204, 
		@active_end_date=99991231, 
		@active_start_time=60500, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
END
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'dba_LongRunningJobsAlert')
BEGIN
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_LongRunningJobsAlert', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Monitoring',
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'SQL_DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run proc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dba].dbo.usp_LongRunningJobs', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20110531, 
		@active_end_date=99991231, 
		@active_start_time=500, 
		@active_end_time=459
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
END
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'dba_CheckFiles')
BEGIN
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_CheckFiles', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Monitoring',
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'SQL_DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run proc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dba].dbo.usp_CheckFiles', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20110623, 
		@active_end_date=99991231, 
		@active_start_time=3000, 
		@active_end_time=2959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
END
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'dba_LongRunningQueriesAlert')
BEGIN
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_LongRunningQueriesAlert', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Monitoring',
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'SQL_DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run proc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dba].dbo.usp_LongRunningQueries', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schedule', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=126, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20110616, 
		@active_end_date=99991231, 
		@active_start_time=200, 
		@active_end_time=159
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Sunday schedule', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20110718, 
		@active_end_date=99991231, 
		@active_start_time=190200, 
		@active_end_time=170159
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
END
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'dba_PerfStats')
BEGIN
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_PerfStats', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Monitoring',
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'SQL_DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run exec', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dba].dbo.usp_PerfStats 1', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'perfstats schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20110809, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
END
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'dba_MemoryUsageStats')
BEGIN
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_MemoryUsageStats', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Monitoring', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'SQL_DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run proc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dba].dbo.usp_MemoryUsageStats 1', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20111101, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
END
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'dba_CPUAlert')
BEGIN
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_CPUAlert', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Monitoring', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'SQL_DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [run proc]    Script Date: 02/29/2012 11:32:46 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run proc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dba].dbo.usp_CPUProcessAlert', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20120229, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
END
GO

/*============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
=========================================================Data Dictionary Execution============================================================================
==============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
============================================================================================================================================================*/
USE [dba]
GO

----RUN THIS TO POPULATE DATA DICTIONARY PROCESS TABLES
EXEC [dba].dbo.dd_PopulateDataDictionary
GO
----RUN ALL THESE UPDATES TO POPULATE THE TABLES AND FIELDS
--TABLES

UPDATE dbo.DataDictionary_Tables SET TableDescription = 'List of fields' WHERE TableName = 'DataDictionary_Fields'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'List of tables' WHERE TableName = 'DataDictionary_Tables'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'Contains config data for SQL Jobs such as email, query parameters' WHERE TableName = 'AlertSettings'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'Contains history on blocking sessions and the victims' WHERE TableName = 'BlockingHistory'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'Storage for historical generated HealthReports' WHERE TableName = 'HealthReport'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'Contains statistical inforamtion on SQL Jobs' WHERE TableName = 'JobStatsHistory'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'Contains statistics on ' WHERE TableName = 'PerfStatsHistory'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'Storage for long running queries' WHERE TableName = 'QueryHistory'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'History table on CPU statistics' WHERE TableName = 'CPUStatsHistory'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'Settings to turn on/off schema tracking, reindexing and alerts on specific databases' WHERE TableName = 'DatabaseSettings'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'History table on DB file statistics ' WHERE TableName = 'FileStatsHistory'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'History table on memory usage statistics' WHERE TableName = 'MemoryUsageHistory'
UPDATE dbo.DataDictionary_Tables SET TableDescription = 'Database trigger to audit all of the DDL changes made to the database.' WHERE TableName = 'SchemaChangeLog'

--FIELDS

UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Field Description' WHERE TableName = 'DataDictionary_Fields' AND FieldName = 'FieldDescription'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Field Name' WHERE TableName = 'DataDictionary_Fields' AND FieldName = 'FieldName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Schema Name' WHERE TableName = 'DataDictionary_Fields' AND FieldName = 'SchemaName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Table Name' WHERE TableName = 'DataDictionary_Fields' AND FieldName = 'TableName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Schema Name' WHERE TableName = 'DataDictionary_Tables' AND FieldName = 'SchemaName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Table Description' WHERE TableName = 'DataDictionary_Tables' AND FieldName = 'TableDescription'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Table Name' WHERE TableName = 'DataDictionary_Tables' AND FieldName = 'TableName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Cell numbers for texting alerts' WHERE TableName = 'AlertSettings' AND FieldName = 'CellList'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Email addresses for emailing alerts' WHERE TableName = 'AlertSettings' AND FieldName = 'EmailList'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Secondary email address for emailing alerts' WHERE TableName = 'AlertSettings' AND FieldName = 'EmailList2'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Stores a value sometimes used by SQL Jobs' WHERE TableName = 'AlertSettings' AND FieldName = 'JobValue'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The description of what is stored in the JobValue column' WHERE TableName = 'AlertSettings' AND FieldName = 'JobValueDesc'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The name of the alert, corresponding to a SQL Job' WHERE TableName = 'AlertSettings' AND FieldName = 'Name'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Stores the values used by the query run by the SQL Job or stored proc' WHERE TableName = 'AlertSettings' AND FieldName = 'QueryValue'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The description of what is stored in the QueryValue column' WHERE TableName = 'AlertSettings' AND FieldName = 'QueryValueDesc'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The hostname of the victim session' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKED_HOSTNAME'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The Last WAITTYPE of the victim session' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKED_LASTWAITTYPE'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The Login name of the victim session' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKED_LOGIN'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The program used by the victim session' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKED_PROGRAM'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The SPID of the victim session' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKED_SPID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The SQL text run by the victim session' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKED_SQL_TEXT'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The Status of the victim session' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKED_STATUS'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The time in seconds the victim session was being blocked' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKED_WAITTIME_SECONDS'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The SPID of the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'BLOCKING_SPID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The PK on the table' WHERE TableName = 'BlockingHistory' AND FieldName = 'BlockingHistoryID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The datestamp on when the data was collected' WHERE TableName = 'BlockingHistory' AND FieldName = 'DateStamp'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The hostname of the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_HOSTNAME'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The Last WAITTYPE of the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_LASTWAITTYPE'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The Login ' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_LOGIN'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The NTUser of the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_NTUSER'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The program used by the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_PROGRAM'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'DUPLICATE - The SPID of the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_SPID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The SQL Text run by the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_SQL_TEXT'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The Status of the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_STATUS'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The WAITTYPE of the offending session' WHERE TableName = 'BlockingHistory' AND FieldName = 'OFFENDING_WAITTYPE'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The datestamp the HealthReport was generated' WHERE TableName = 'HealthReport' AND FieldName = 'DateStamp'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The HTML blob that represents the HealthReport' WHERE TableName = 'HealthReport' AND FieldName = 'GeneratedHTML'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The PK for the HealthReport' WHERE TableName = 'HealthReport' AND FieldName = 'HealthReportID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The average runtime of the SQL Job' WHERE TableName = 'JobStatsHistory' AND FieldName = 'AvgRunTime'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Stores the status of the job, enabled or disabled' WHERE TableName = 'JobStatsHistory' AND FieldName = 'Enabled'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The name of the SQL Job' WHERE TableName = 'JobStatsHistory' AND FieldName = 'JobName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The datestamp that the job stats were gathered' WHERE TableName = 'JobStatsHistory' AND FieldName = 'JobStatsDateStamp'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The PK on the table' WHERE TableName = 'JobStatsHistory' AND FieldName = 'JobStatsHistoryId'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The grouping ID for all records gathered for that time stamp' WHERE TableName = 'JobStatsHistory' AND FieldName = 'JobStatsID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The outcome of the SQL Job, whether is succeeded or failed' WHERE TableName = 'JobStatsHistory' AND FieldName = 'LastRunOutcome'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The last time the SQL Job was run' WHERE TableName = 'JobStatsHistory' AND FieldName = 'LastRunTime'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Whether the job is currently running or not (at the time the information was gathered)' WHERE TableName = 'JobStatsHistory' AND FieldName = 'RunTimeStatus'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The time the SQL Job started' WHERE TableName = 'JobStatsHistory' AND FieldName = 'StartTime'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The time the SQL Job stopped' WHERE TableName = 'JobStatsHistory' AND FieldName = 'StopTime'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of batches SQL Server is receiving per second' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'BatchRequestsPerSecond'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'How often SQL Server is able data pages in its buffer cache' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'BufferCacheHitRatio'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of checkpoint pages per second' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'CheckpointPagesPerSecond'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of compilations per second' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'CompilationsPerSecond'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of lock waits per second' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'LockWaitsPerSecond'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The life expectancy of hte page' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'PageLifeExpectency'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of page splits per second' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'PageSplitsPerSecond'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The PK on the table' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'PerfStatsHistoryID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of processes blocked' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'ProcessesBlocked'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of recompilations per second' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'ReCompilationsPerSecond'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The timestamp the data was gathered' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'StatDate'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of users connected' WHERE TableName = 'PerfStatsHistory' AND FieldName = 'UserConnections'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The timestamp the data was collected' WHERE TableName = 'QueryHistory' AND FieldName = 'collection_time'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The amount of CPU cycles the query has performed' WHERE TableName = 'QueryHistory' AND FieldName = 'CPU'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The name of the database' WHERE TableName = 'QueryHistory' AND FieldName = 'database_name'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The host name the query originated from' WHERE TableName = 'QueryHistory' AND FieldName = 'host_name'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The login name that ran the query' WHERE TableName = 'QueryHistory' AND FieldName = 'login_name'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The timestamp of when the user logged in' WHERE TableName = 'QueryHistory' AND FieldName = 'login_time'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of physical reads the query performed' WHERE TableName = 'QueryHistory' AND FieldName = 'physical_reads'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The name of the program that initiated the query' WHERE TableName = 'QueryHistory' AND FieldName = 'program_name'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The PK on the table' WHERE TableName = 'QueryHistory' AND FieldName = 'QueryHistoryID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of reads the query performed' WHERE TableName = 'QueryHistory' AND FieldName = 'reads'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The SPID of the query' WHERE TableName = 'QueryHistory' AND FieldName = 'session_id'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The SQL Text of the query' WHERE TableName = 'QueryHistory' AND FieldName = 'sql_text'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The timestamp the query started' WHERE TableName = 'QueryHistory' AND FieldName = 'start_time'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The number of writes the query performed' WHERE TableName = 'QueryHistory' AND FieldName = 'writes'


UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Stores the values used by the query run by the SQL Job or stored proc' WHERE TableName = 'AlertSettings' AND FieldName = 'QueryValue2'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The description of what is stored in the QueryValue column' WHERE TableName = 'AlertSettings' AND FieldName = 'QueryValue2Desc'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The Database where the blocking occured' WHERE TableName = 'BlockingHistory' AND FieldName = 'DBName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Primary Key' WHERE TableName = 'CPUStatsHistory' AND FieldName = 'CPUStatsHistoryID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Datestamp when record was inserted' WHERE TableName = 'CPUStatsHistory' AND FieldName = 'DateStamp'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Percentage all other system processes' WHERE TableName = 'CPUStatsHistory' AND FieldName = 'OtherProcessPerecnt'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Percentage of SQL Server process' WHERE TableName = 'CPUStatsHistory' AND FieldName = 'SQLProcessPercent'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Percentage of system idle process' WHERE TableName = 'CPUStatsHistory' AND FieldName = 'SystemIdleProcessPercent'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The name of the Database' WHERE TableName = 'DatabaseSettings' AND FieldName = 'DBName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Flag to turn on/off Log File Alerts' WHERE TableName = 'DatabaseSettings' AND FieldName = 'LogFileAlerts'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Flag to turn on/off Long running query alerts' WHERE TableName = 'DatabaseSettings' AND FieldName = 'LongQueryAlerts'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Flag to turn on/off reindexing, requires reindex wrapper proc' WHERE TableName = 'DatabaseSettings' AND FieldName = 'Reindex'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Flag to turn on/off Schema tracking' WHERE TableName = 'DatabaseSettings' AND FieldName = 'SchemaTracking'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Database name' WHERE TableName = 'FileStatsHistory' AND FieldName = 'DBName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Drive Letter the file is located' WHERE TableName = 'FileStatsHistory' AND FieldName = 'DriveLetter'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Growth setting for the file' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FileGrowth'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'How much space is available' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FileMBEmpty'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Size of the file in MB' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FileMBSize'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Total space allocated for the file' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FileMBUsed'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Filename' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FileName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Percentage of file that is not being used' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FilePercentEmpty'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Datestamp when record was inserted' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FileStatsDateStamp'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Primary Key' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FileStatsHistoryID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Grouping of records' WHERE TableName = 'FileStatsHistory' AND FieldName = 'FileStatsID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The category of the job' WHERE TableName = 'JobStatsHistory' AND FieldName = 'Category'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferCacheHitRatio' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferCacheHitRatio'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPageLifeExpectancy' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPageLifeExpectancy'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPoolCommitMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPoolCommitMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPoolCommitTgtMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPoolCommitTgtMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPoolDataPagesMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPoolDataPagesMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPoolFreePagesMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPoolFreePagesMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPoolPlanCachePagesMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPoolPlanCachePagesMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPoolReservedPagesMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPoolReservedPagesMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPoolStolenPagesMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPoolStolenPagesMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'BufferPoolTotalPagesMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'BufferPoolTotalPagesMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'CursorUsageMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'CursorUsageMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Datestamp when record was inserted' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'DateStamp'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'DBMemoryRequiredMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'DBMemoryRequiredMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'DBUsageMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'DBUsageMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'DynamicMemConnectionsMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'DynamicMemConnectionsMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'DynamicMemHashSortIndexMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'DynamicMemHashSortIndexMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'DynamicMemLocksMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'DynamicMemLocksMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'DynamicMemQueryOptimizeMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'DynamicMemQueryOptimizeMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'DynamicMemSQLCacheMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'DynamicMemSQLCacheMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Primary Key' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'MemoryUsageHistoryID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'SystemPhysicalMemoryMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'SystemPhysicalMemoryMB'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'SystemVirtualMemoryMB' WHERE TableName = 'MemoryUsageHistory' AND FieldName = 'SystemVirtualMemoryMB'

UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Name of computer that made the DDL change' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'ComputerName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The date and time the DDL change occurred.' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'CreateDate'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Name of the database' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'DBName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Login of who made the DDL change' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'LoginName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Primary Key' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'SchemaChangeLogID'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The name of the object' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'ObjectName'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The sql text that was run' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'SQLCmd'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'Specifies what type of change, IE ALTER_PROCEDURE, CREATE_FUNCTION, etc' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'SQLEvent'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The schema to which the changed object belongs.' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'Schema'
UPDATE dbo.DataDictionary_Fields SET FieldDescription = 'The raw XML data generated by database trigger.' WHERE TableName = 'SchemaChangeLog' AND FieldName = 'XmlEvent'


----RUN THIS AFTER YOU RUN ALL THE UPDATES BELOW
EXEC [dba].dbo.dd_ApplyDataDictionary
GO
/*============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
=========================================================MASTER DB PROC - sp_WhoIsActive======================================================================
==============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
==============================================================================================================================================================
============================================================================================================================================================*/
USE master
GO

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'sp_WhoIsActive')
	EXEC ('CREATE PROC dbo.sp_WhoIsActive AS SELECT ''stub version, to be replaced''')
GO

/*********************************************************************************************
Who Is Active? v11.11 (2012-03-22)
(C) 2007-2012, Adam Machanic

Feedback: mailto:amachanic@gmail.com
Updates: http://sqlblog.com/blogs/adam_machanic/archive/tags/who+is+active/default.aspx
"Beta" Builds: http://sqlblog.com/files/folders/beta/tags/who+is+active/default.aspx

Donate! Support this project: http://tinyurl.com/WhoIsActiveDonate

License: 
	Who is Active? is free to download and use for personal, educational, and internal 
	corporate purposes, provided that this header is preserved. Redistribution or sale 
	of Who is Active?, in whole or in part, is prohibited without the author's express 
	written consent.
*********************************************************************************************/
ALTER PROC dbo.sp_WhoIsActive
(
--~
	--Filters--Both inclusive and exclusive
	--Set either filter to '' to disable
	--Valid filter types are: session, program, database, login, and host
	--Session is a session ID, and either 0 or '' can be used to indicate "all" sessions
	--All other filter types support % or _ as wildcards
	@filter sysname = '',
	@filter_type VARCHAR(10) = 'session',
	@not_filter sysname = '',
	@not_filter_type VARCHAR(10) = 'session',

	--Retrieve data about the calling session?
	@show_own_spid BIT = 0,

	--Retrieve data about system sessions?
	@show_system_spids BIT = 0,

	--Controls how sleeping SPIDs are handled, based on the idea of levels of interest
	--0 does not pull any sleeping SPIDs
	--1 pulls only those sleeping SPIDs that also have an open transaction
	--2 pulls all sleeping SPIDs
	@show_sleeping_spids TINYINT = 1,

	--If 1, gets the full stored procedure or running batch, when available
	--If 0, gets only the actual statement that is currently running in the batch or procedure
	@get_full_inner_text BIT = 0,

	--Get associated query plans for running tasks, if available
	--If @get_plans = 1, gets the plan based on the request's statement offset
	--If @get_plans = 2, gets the entire plan based on the request's plan_handle
	@get_plans TINYINT = 0,

	--Get the associated outer ad hoc query or stored procedure call, if available
	@get_outer_command BIT = 0,

	--Enables pulling transaction log write info and transaction duration
	@get_transaction_info BIT = 0,

	--Get information on active tasks, based on three interest levels
	--Level 0 does not pull any task-related information
	--Level 1 is a lightweight mode that pulls the top non-CXPACKET wait, giving preference to blockers
	--Level 2 pulls all available task-based metrics, including: 
	--number of active tasks, current wait stats, physical I/O, context switches, and blocker information
	@get_task_info TINYINT = 1,

	--Gets associated locks for each request, aggregated in an XML format
	@get_locks BIT = 0,

	--Get average time for past runs of an active query
	--(based on the combination of plan handle, sql handle, and offset)
	@get_avg_time BIT = 0,

	--Get additional non-performance-related information about the session or request
	--text_size, language, date_format, date_first, quoted_identifier, arithabort, ansi_null_dflt_on, 
	--ansi_defaults, ansi_warnings, ansi_padding, ansi_nulls, concat_null_yields_null, 
	--transaction_isolation_level, lock_timeout, deadlock_priority, row_count, command_type
	--
	--If a SQL Agent job is running, an subnode called agent_info will be populated with some or all of
	--the following: job_id, job_name, step_id, step_name, msdb_query_error (in the event of an error)
	--
	--If @get_task_info is set to 2 and a lock wait is detected, a subnode called block_info will be
	--populated with some or all of the following: lock_type, database_name, object_id, file_id, hobt_id, 
	--applock_hash, metadata_resource, metadata_class_id, object_name, schema_name
	@get_additional_info BIT = 0,

	--Walk the blocking chain and count the number of 
	--total SPIDs blocked all the way down by a given session
	--Also enables task_info Level 1, if @get_task_info is set to 0
	@find_block_leaders BIT = 0,

	--Pull deltas on various metrics
	--Interval in seconds to wait before doing the second data pull
	@delta_interval TINYINT = 0,

	--List of desired output columns, in desired order
	--Note that the final output will be the intersection of all enabled features and all 
	--columns in the list. Therefore, only columns associated with enabled features will 
	--actually appear in the output. Likewise, removing columns from this list may effectively
	--disable features, even if they are turned on
	--
	--Each element in this list must be one of the valid output column names. Names must be
	--delimited by square brackets. White space, formatting, and additional characters are
	--allowed, as long as the list contains exact matches of delimited valid column names.
	@output_column_list VARCHAR(8000) = '[dd%][session_id][sql_text][sql_command][login_name][wait_info][tasks][tran_log%][cpu%][temp%][block%][reads%][writes%][context%][physical%][query_plan][locks][%]',

	--Column(s) by which to sort output, optionally with sort directions. 
		--Valid column choices:
		--session_id, physical_io, reads, physical_reads, writes, tempdb_allocations,
		--tempdb_current, CPU, context_switches, used_memory, physical_io_delta, 
		--reads_delta, physical_reads_delta, writes_delta, tempdb_allocations_delta, 
		--tempdb_current_delta, CPU_delta, context_switches_delta, used_memory_delta, 
		--tasks, tran_start_time, open_tran_count, blocking_session_id, blocked_session_count,
		--percent_complete, host_name, login_name, database_name, start_time, login_time
		--
		--Note that column names in the list must be bracket-delimited. Commas and/or white
		--space are not required. 
	@sort_order VARCHAR(500) = '[start_time] ASC',

	--Formats some of the output columns in a more "human readable" form
	--0 disables outfput format
	--1 formats the output for variable-width fonts
	--2 formats the output for fixed-width fonts
	@format_output TINYINT = 1,

	--If set to a non-blank value, the script will attempt to insert into the specified 
	--destination table. Please note that the script will not verify that the table exists, 
	--or that it has the correct schema, before doing the insert.
	--Table can be specified in one, two, or three-part format
	@destination_table VARCHAR(4000) = '',

	--If set to 1, no data collection will happen and no result set will be returned; instead,
	--a CREATE TABLE statement will be returned via the @schema parameter, which will match 
	--the schema of the result set that would be returned by using the same collection of the
	--rest of the parameters. The CREATE TABLE statement will have a placeholder token of 
	--<table_name> in place of an actual table name.
	@return_schema BIT = 0,
	@schema VARCHAR(MAX) = NULL OUTPUT,

	--Help! What do I do?
	@help BIT = 0
--~
)
/*
OUTPUT COLUMNS
--------------
Formatted/Non:	[session_id] [smallint] NOT NULL
	Session ID (a.k.a. SPID)

Formatted:		[dd hh:mm:ss.mss] [varchar](15) NULL
Non-Formatted:	<not returned>
	For an active request, time the query has been running
	For a sleeping session, time since the last batch completed

Formatted:		[dd hh:mm:ss.mss (avg)] [varchar](15) NULL
Non-Formatted:	[avg_elapsed_time] [int] NULL
	(Requires @get_avg_time option)
	How much time has the active portion of the query taken in the past, on average?

Formatted:		[physical_io] [varchar](30) NULL
Non-Formatted:	[physical_io] [bigint] NULL
	Shows the number of physical I/Os, for active requests

Formatted:		[reads] [varchar](30) NULL
Non-Formatted:	[reads] [bigint] NULL
	For an active request, number of reads done for the current query
	For a sleeping session, total number of reads done over the lifetime of the session

Formatted:		[physical_reads] [varchar](30) NULL
Non-Formatted:	[physical_reads] [bigint] NULL
	For an active request, number of physical reads done for the current query
	For a sleeping session, total number of physical reads done over the lifetime of the session

Formatted:		[writes] [varchar](30) NULL
Non-Formatted:	[writes] [bigint] NULL
	For an active request, number of writes done for the current query
	For a sleeping session, total number of writes done over the lifetime of the session

Formatted:		[tempdb_allocations] [varchar](30) NULL
Non-Formatted:	[tempdb_allocations] [bigint] NULL
	For an active request, number of TempDB writes done for the current query
	For a sleeping session, total number of TempDB writes done over the lifetime of the session

Formatted:		[tempdb_current] [varchar](30) NULL
Non-Formatted:	[tempdb_current] [bigint] NULL
	For an active request, number of TempDB pages currently allocated for the query
	For a sleeping session, number of TempDB pages currently allocated for the session

Formatted:		[CPU] [varchar](30) NULL
Non-Formatted:	[CPU] [int] NULL
	For an active request, total CPU time consumed by the current query
	For a sleeping session, total CPU time consumed over the lifetime of the session

Formatted:		[context_switches] [varchar](30) NULL
Non-Formatted:	[context_switches] [bigint] NULL
	Shows the number of context switches, for active requests

Formatted:		[used_memory] [varchar](30) NOT NULL
Non-Formatted:	[used_memory] [bigint] NOT NULL
	For an active request, total memory consumption for the current query
	For a sleeping session, total current memory consumption

Formatted:		[physical_io_delta] [varchar](30) NULL
Non-Formatted:	[physical_io_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of physical I/Os reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[reads_delta] [varchar](30) NULL
Non-Formatted:	[reads_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of reads reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[physical_reads_delta] [varchar](30) NULL
Non-Formatted:	[physical_reads_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of physical reads reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[writes_delta] [varchar](30) NULL
Non-Formatted:	[writes_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of writes reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[tempdb_allocations_delta] [varchar](30) NULL
Non-Formatted:	[tempdb_allocations_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of TempDB writes reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[tempdb_current_delta] [varchar](30) NULL
Non-Formatted:	[tempdb_current_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of allocated TempDB pages reported on the first and second 
	collections. If the request started after the first collection, the value will be NULL

Formatted:		[CPU_delta] [varchar](30) NULL
Non-Formatted:	[CPU_delta] [int] NULL
	(Requires @delta_interval option)
	Difference between the CPU time reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[context_switches_delta] [varchar](30) NULL
Non-Formatted:	[context_switches_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the context switches count reported on the first and second collections
	If the request started after the first collection, the value will be NULL

Formatted:		[used_memory_delta] [varchar](30) NULL
Non-Formatted:	[used_memory_delta] [bigint] NULL
	Difference between the memory usage reported on the first and second collections
	If the request started after the first collection, the value will be NULL

Formatted:		[tasks] [varchar](30) NULL
Non-Formatted:	[tasks] [smallint] NULL
	Number of worker tasks currently allocated, for active requests

Formatted/Non:	[status] [varchar](30) NOT NULL
	Activity status for the session (running, sleeping, etc)

Formatted/Non:	[wait_info] [nvarchar](4000) NULL
	Aggregates wait information, in the following format:
		(Ax: Bms/Cms/Dms)E
	A is the number of waiting tasks currently waiting on resource type E. B/C/D are wait
	times, in milliseconds. If only one thread is waiting, its wait time will be shown as B.
	If two tasks are waiting, each of their wait times will be shown (B/C). If three or more 
	tasks are waiting, the minimum, average, and maximum wait times will be shown (B/C/D).
	If wait type E is a page latch wait and the page is of a "special" type (e.g. PFS, GAM, SGAM), 
	the page type will be identified.
	If wait type E is CXPACKET, the nodeId from the query plan will be identified

Formatted/Non:	[locks] [xml] NULL
	(Requires @get_locks option)
	Aggregates lock information, in XML format.
	The lock XML includes the lock mode, locked object, and aggregates the number of requests. 
	Attempts are made to identify locked objects by name

Formatted/Non:	[tran_start_time] [datetime] NULL
	(Requires @get_transaction_info option)
	Date and time that the first transaction opened by a session caused a transaction log 
	write to occur.

Formatted/Non:	[tran_log_writes] [nvarchar](4000) NULL
	(Requires @get_transaction_info option)
	Aggregates transaction log write information, in the following format:
	A:wB (C kB)
	A is a database that has been touched by an active transaction
	B is the number of log writes that have been made in the database as a result of the transaction
	C is the number of log kilobytes consumed by the log records

Formatted:		[open_tran_count] [varchar](30) NULL
Non-Formatted:	[open_tran_count] [smallint] NULL
	Shows the number of open transactions the session has open

Formatted:		[sql_command] [xml] NULL
Non-Formatted:	[sql_command] [nvarchar](max) NULL
	(Requires @get_outer_command option)
	Shows the "outer" SQL command, i.e. the text of the batch or RPC sent to the server, 
	if available

Formatted:		[sql_text] [xml] NULL
Non-Formatted:	[sql_text] [nvarchar](max) NULL
	Shows the SQL text for active requests or the last statement executed
	for sleeping sessions, if available in either case.
	If @get_full_inner_text option is set, shows the full text of the batch.
	Otherwise, shows only the active statement within the batch.
	If the query text is locked, a special timeout message will be sent, in the following format:
		<timeout_exceeded />
	If an error occurs, an error message will be sent, in the following format:
		<error message="message" />

Formatted/Non:	[query_plan] [xml] NULL
	(Requires @get_plans option)
	Shows the query plan for the request, if available.
	If the plan is locked, a special timeout message will be sent, in the following format:
		<timeout_exceeded />
	If an error occurs, an error message will be sent, in the following format:
		<error message="message" />

Formatted/Non:	[blocking_session_id] [smallint] NULL
	When applicable, shows the blocking SPID

Formatted:		[blocked_session_count] [varchar](30) NULL
Non-Formatted:	[blocked_session_count] [smallint] NULL
	(Requires @find_block_leaders option)
	The total number of SPIDs blocked by this session,
	all the way down the blocking chain.

Formatted:		[percent_complete] [varchar](30) NULL
Non-Formatted:	[percent_complete] [real] NULL
	When applicable, shows the percent complete (e.g. for backups, restores, and some rollbacks)

Formatted/Non:	[host_name] [sysname] NOT NULL
	Shows the host name for the connection

Formatted/Non:	[login_name] [sysname] NOT NULL
	Shows the login name for the connection

Formatted/Non:	[database_name] [sysname] NULL
	Shows the connected database

Formatted/Non:	[program_name] [sysname] NULL
	Shows the reported program/application name

Formatted/Non:	[additional_info] [xml] NULL
	(Requires @get_additional_info option)
	Returns additional non-performance-related session/request information
	If the script finds a SQL Agent job running, the name of the job and job step will be reported
	If @get_task_info = 2 and the script finds a lock wait, the locked object will be reported

Formatted/Non:	[start_time] [datetime] NOT NULL
	For active requests, shows the time the request started
	For sleeping sessions, shows the time the last batch completed

Formatted/Non:	[login_time] [datetime] NOT NULL
	Shows the time that the session connected

Formatted/Non:	[request_id] [int] NULL
	For active requests, shows the request_id
	Should be 0 unless MARS is being used

Formatted/Non:	[collection_time] [datetime] NOT NULL
	Time that this script's final SELECT ran
*/
AS
BEGIN;
	SET NOCOUNT ON; 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET QUOTED_IDENTIFIER ON;
	SET ANSI_PADDING ON;
	SET CONCAT_NULL_YIELDS_NULL ON;
	SET ANSI_WARNINGS ON;
	SET NUMERIC_ROUNDABORT OFF;
	SET ARITHABORT ON;

	IF
		@filter IS NULL
		OR @filter_type IS NULL
		OR @not_filter IS NULL
		OR @not_filter_type IS NULL
		OR @show_own_spid IS NULL
		OR @show_system_spids IS NULL
		OR @show_sleeping_spids IS NULL
		OR @get_full_inner_text IS NULL
		OR @get_plans IS NULL
		OR @get_outer_command IS NULL
		OR @get_transaction_info IS NULL
		OR @get_task_info IS NULL
		OR @get_locks IS NULL
		OR @get_avg_time IS NULL
		OR @get_additional_info IS NULL
		OR @find_block_leaders IS NULL
		OR @delta_interval IS NULL
		OR @format_output IS NULL
		OR @output_column_list IS NULL
		OR @sort_order IS NULL
		OR @return_schema IS NULL
		OR @destination_table IS NULL
		OR @help IS NULL
	BEGIN;
		RAISERROR('Input parameters cannot be NULL', 16, 1);
		RETURN;
	END;
	
	IF @filter_type NOT IN ('session', 'program', 'database', 'login', 'host')
	BEGIN;
		RAISERROR('Valid filter types are: session, program, database, login, host', 16, 1);
		RETURN;
	END;
	
	IF @filter_type = 'session' AND @filter LIKE '%[^0123456789]%'
	BEGIN;
		RAISERROR('Session filters must be valid integers', 16, 1);
		RETURN;
	END;
	
	IF @not_filter_type NOT IN ('session', 'program', 'database', 'login', 'host')
	BEGIN;
		RAISERROR('Valid filter types are: session, program, database, login, host', 16, 1);
		RETURN;
	END;
	
	IF @not_filter_type = 'session' AND @not_filter LIKE '%[^0123456789]%'
	BEGIN;
		RAISERROR('Session filters must be valid integers', 16, 1);
		RETURN;
	END;
	
	IF @show_sleeping_spids NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @show_sleeping_spids are: 0, 1, or 2', 16, 1);
		RETURN;
	END;
	
	IF @get_plans NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @get_plans are: 0, 1, or 2', 16, 1);
		RETURN;
	END;

	IF @get_task_info NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @get_task_info are: 0, 1, or 2', 16, 1);
		RETURN;
	END;

	IF @format_output NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @format_output are: 0, 1, or 2', 16, 1);
		RETURN;
	END;
	
	IF @help = 1
	BEGIN;
		DECLARE 
			@header VARCHAR(MAX),
			@params VARCHAR(MAX),
			@outputs VARCHAR(MAX);

		SELECT 
			@header =
				REPLACE
				(
					REPLACE
					(
						CONVERT
						(
							VARCHAR(MAX),
							SUBSTRING
							(
								t.text, 
								CHARINDEX('/' + REPLICATE('*', 93), t.text) + 94,
								CHARINDEX(REPLICATE('*', 93) + '/', t.text) - (CHARINDEX('/' + REPLICATE('*', 93), t.text) + 94)
							)
						),
						CHAR(13)+CHAR(10),
						CHAR(13)
					),
					'	',
					''
				),
			@params =
				CHAR(13) +
					REPLACE
					(
						REPLACE
						(
							CONVERT
							(
								VARCHAR(MAX),
								SUBSTRING
								(
									t.text, 
									CHARINDEX('--~', t.text) + 5, 
									CHARINDEX('--~', t.text, CHARINDEX('--~', t.text) + 5) - (CHARINDEX('--~', t.text) + 5)
								)
							),
							CHAR(13)+CHAR(10),
							CHAR(13)
						),
						'	',
						''
					),
				@outputs = 
					CHAR(13) +
						REPLACE
						(
							REPLACE
							(
								REPLACE
								(
									CONVERT
									(
										VARCHAR(MAX),
										SUBSTRING
										(
											t.text, 
											CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32,
											CHARINDEX('*/', t.text, CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32) - (CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32)
										)
									),
									CHAR(9),
									CHAR(255)
								),
								CHAR(13)+CHAR(10),
								CHAR(13)
							),
							'	',
							''
						) +
						CHAR(13)
		FROM sys.dm_exec_requests AS r
		CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
		WHERE
			r.session_id = @@SPID;

		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@header) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		)
		SELECT
			RTRIM(LTRIM(
				SUBSTRING
				(
					@header,
					number + 1,
					CHARINDEX(CHAR(13), @header, number + 1) - number - 1
				)
			)) AS [------header---------------------------------------------------------------------------------------------------------------]
		FROM numbers
		WHERE
			SUBSTRING(@header, number, 1) = CHAR(13);

		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@params) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		),
		tokens AS
		(
			SELECT 
				RTRIM(LTRIM(
					SUBSTRING
					(
						@params,
						number + 1,
						CHARINDEX(CHAR(13), @params, number + 1) - number - 1
					)
				)) AS token,
				number,
				CASE
					WHEN SUBSTRING(@params, number + 1, 1) = CHAR(13) THEN number
					ELSE COALESCE(NULLIF(CHARINDEX(',' + CHAR(13) + CHAR(13), @params, number), 0), LEN(@params)) 
				END AS param_group,
				ROW_NUMBER() OVER
				(
					PARTITION BY
						CHARINDEX(',' + CHAR(13) + CHAR(13), @params, number),
						SUBSTRING(@params, number+1, 1)
					ORDER BY 
						number
				) AS group_order
			FROM numbers
			WHERE
				SUBSTRING(@params, number, 1) = CHAR(13)
		),
		parsed_tokens AS
		(
			SELECT
				MIN
				(
					CASE
						WHEN token LIKE '@%' THEN token
						ELSE NULL
					END
				) AS parameter,
				MIN
				(
					CASE
						WHEN token LIKE '--%' THEN RIGHT(token, LEN(token) - 2)
						ELSE NULL
					END
				) AS description,
				param_group,
				group_order
			FROM tokens
			WHERE
				NOT 
				(
					token = '' 
					AND group_order > 1
				)
			GROUP BY
				param_group,
				group_order
		)
		SELECT
			CASE
				WHEN description IS NULL AND parameter IS NULL THEN '-------------------------------------------------------------------------'
				WHEN param_group = MAX(param_group) OVER() THEN parameter
				ELSE COALESCE(LEFT(parameter, LEN(parameter) - 1), '')
			END AS [------parameter----------------------------------------------------------],
			CASE
				WHEN description IS NULL AND parameter IS NULL THEN '----------------------------------------------------------------------------------------------------------------------'
				ELSE COALESCE(description, '')
			END AS [------description-----------------------------------------------------------------------------------------------------]
		FROM parsed_tokens
		ORDER BY
			param_group, 
			group_order;
		
		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@outputs) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		),
		tokens AS
		(
			SELECT 
				RTRIM(LTRIM(
					SUBSTRING
					(
						@outputs,
						number + 1,
						CASE
							WHEN 
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) < 
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2, @outputs, number + 1), 0), LEN(@outputs))
								THEN COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) - number - 1
							ELSE
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2, @outputs, number + 1), 0), LEN(@outputs)) - number - 1
						END
					)
				)) AS token,
				number,
				COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) AS output_group,
				ROW_NUMBER() OVER
				(
					PARTITION BY 
						COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs))
					ORDER BY
						number
				) AS output_group_order
			FROM numbers
			WHERE
				SUBSTRING(@outputs, number, 10) = CHAR(13) + 'Formatted'
				OR SUBSTRING(@outputs, number, 2) = CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2
		),
		output_tokens AS
		(
			SELECT 
				*,
				CASE output_group_order
					WHEN 2 THEN MAX(CASE output_group_order WHEN 1 THEN token ELSE NULL END) OVER (PARTITION BY output_group)
					ELSE ''
				END COLLATE Latin1_General_Bin2 AS column_info
			FROM tokens
		)
		SELECT
			CASE output_group_order
				WHEN 1 THEN '-----------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN
							SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+1, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info))
						ELSE
							SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)-1)
					END
				ELSE ''
			END AS formatted_column_name,
			CASE output_group_order
				WHEN 1 THEN '-----------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN
							SUBSTRING(column_info, CHARINDEX(']', column_info)+2, LEN(column_info))
						ELSE
							SUBSTRING(column_info, CHARINDEX(']', column_info)+2, CHARINDEX('Non-Formatted:', column_info, CHARINDEX(']', column_info)+2) - CHARINDEX(']', column_info)-3)
					END
				ELSE ''
			END AS formatted_column_type,
			CASE output_group_order
				WHEN 1 THEN '---------------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN ''
						ELSE
							CASE
								WHEN SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, 1) = '<' THEN
									SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, CHARINDEX('>', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info)))
								ELSE
									SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info)))
							END
					END
				ELSE ''
			END AS unformatted_column_name,
			CASE output_group_order
				WHEN 1 THEN '---------------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN ''
						ELSE
							CASE
								WHEN SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, 1) = '<' THEN ''
								ELSE
									SUBSTRING(column_info, CHARINDEX(']', column_info, CHARINDEX('Non-Formatted:', column_info))+2, CHARINDEX('Non-Formatted:', column_info, CHARINDEX(']', column_info)+2) - CHARINDEX(']', column_info)-3)
							END
					END
				ELSE ''
			END AS unformatted_column_type,
			CASE output_group_order
				WHEN 1 THEN '----------------------------------------------------------------------------------------------------------------------'
				ELSE REPLACE(token, CHAR(255) COLLATE Latin1_General_Bin2, '')
			END AS [------description-----------------------------------------------------------------------------------------------------]
		FROM output_tokens
		WHERE
			NOT 
			(
				output_group_order = 1 
				AND output_group = LEN(@outputs)
			)
		ORDER BY
			output_group,
			CASE output_group_order
				WHEN 1 THEN 99
				ELSE output_group_order
			END;

		RETURN;
	END;

	WITH
	a0 AS
	(SELECT 1 AS n UNION ALL SELECT 1),
	a1 AS
	(SELECT 1 AS n FROM a0 AS a, a0 AS b),
	a2 AS
	(SELECT 1 AS n FROM a1 AS a, a1 AS b),
	a3 AS
	(SELECT 1 AS n FROM a2 AS a, a2 AS b),
	a4 AS
	(SELECT 1 AS n FROM a3 AS a, a3 AS b),
	numbers AS
	(
		SELECT TOP(LEN(@output_column_list))
			ROW_NUMBER() OVER
			(
				ORDER BY (SELECT NULL)
			) AS number
		FROM a4
		ORDER BY
			number
	),
	tokens AS
	(
		SELECT 
			'|[' +
				SUBSTRING
				(
					@output_column_list,
					number + 1,
					CHARINDEX(']', @output_column_list, number) - number - 1
				) + '|]' AS token,
			number
		FROM numbers
		WHERE
			SUBSTRING(@output_column_list, number, 1) = '['
	),
	ordered_columns AS
	(
		SELECT
			x.column_name,
			ROW_NUMBER() OVER
			(
				PARTITION BY
					x.column_name
				ORDER BY
					tokens.number,
					x.default_order
			) AS r,
			ROW_NUMBER() OVER
			(
				ORDER BY
					tokens.number,
					x.default_order
			) AS s
		FROM tokens
		JOIN
		(
			SELECT '[session_id]' AS column_name, 1 AS default_order
			UNION ALL
			SELECT '[dd hh:mm:ss.mss]', 2
			WHERE
				@format_output IN (1, 2)
			UNION ALL
			SELECT '[dd hh:mm:ss.mss (avg)]', 3
			WHERE
				@format_output IN (1, 2)
				AND @get_avg_time = 1
			UNION ALL
			SELECT '[avg_elapsed_time]', 4
			WHERE
				@format_output = 0
				AND @get_avg_time = 1
			UNION ALL
			SELECT '[physical_io]', 5
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[reads]', 6
			UNION ALL
			SELECT '[physical_reads]', 7
			UNION ALL
			SELECT '[writes]', 8
			UNION ALL
			SELECT '[tempdb_allocations]', 9
			UNION ALL
			SELECT '[tempdb_current]', 10
			UNION ALL
			SELECT '[CPU]', 11
			UNION ALL
			SELECT '[context_switches]', 12
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[used_memory]', 13
			UNION ALL
			SELECT '[physical_io_delta]', 14
			WHERE
				@delta_interval > 0	
				AND @get_task_info = 2
			UNION ALL
			SELECT '[reads_delta]', 15
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[physical_reads_delta]', 16
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[writes_delta]', 17
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tempdb_allocations_delta]', 18
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tempdb_current_delta]', 19
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[CPU_delta]', 20
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[context_switches_delta]', 21
			WHERE
				@delta_interval > 0
				AND @get_task_info = 2
			UNION ALL
			SELECT '[used_memory_delta]', 22
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tasks]', 23
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[status]', 24
			UNION ALL
			SELECT '[wait_info]', 25
			WHERE
				@get_task_info > 0
				OR @find_block_leaders = 1
			UNION ALL
			SELECT '[locks]', 26
			WHERE
				@get_locks = 1
			UNION ALL
			SELECT '[tran_start_time]', 27
			WHERE
				@get_transaction_info = 1
			UNION ALL
			SELECT '[tran_log_writes]', 28
			WHERE
				@get_transaction_info = 1
			UNION ALL
			SELECT '[open_tran_count]', 29
			UNION ALL
			SELECT '[sql_command]', 30
			WHERE
				@get_outer_command = 1
			UNION ALL
			SELECT '[sql_text]', 31
			UNION ALL
			SELECT '[query_plan]', 32
			WHERE
				@get_plans >= 1
			UNION ALL
			SELECT '[blocking_session_id]', 33
			WHERE
				@get_task_info > 0
				OR @find_block_leaders = 1
			UNION ALL
			SELECT '[blocked_session_count]', 34
			WHERE
				@find_block_leaders = 1
			UNION ALL
			SELECT '[percent_complete]', 35
			UNION ALL
			SELECT '[host_name]', 36
			UNION ALL
			SELECT '[login_name]', 37
			UNION ALL
			SELECT '[database_name]', 38
			UNION ALL
			SELECT '[program_name]', 39
			UNION ALL
			SELECT '[additional_info]', 40
			WHERE
				@get_additional_info = 1
			UNION ALL
			SELECT '[start_time]', 41
			UNION ALL
			SELECT '[login_time]', 42
			UNION ALL
			SELECT '[request_id]', 43
			UNION ALL
			SELECT '[collection_time]', 44
		) AS x ON 
			x.column_name LIKE token ESCAPE '|'
	)
	SELECT
		@output_column_list =
			STUFF
			(
				(
					SELECT
						',' + column_name as [text()]
					FROM ordered_columns
					WHERE
						r = 1
					ORDER BY
						s
					FOR XML
						PATH('')
				),
				1,
				1,
				''
			);
	
	IF COALESCE(RTRIM(@output_column_list), '') = ''
	BEGIN;
		RAISERROR('No valid column matches found in @output_column_list or no columns remain due to selected options.', 16, 1);
		RETURN;
	END;
	
	IF @destination_table <> ''
	BEGIN;
		SET @destination_table = 
			--database
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 3)) + '.', '') +
			--schema
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 2)) + '.', '') +
			--table
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 1)), '');
			
		IF COALESCE(RTRIM(@destination_table), '') = ''
		BEGIN;
			RAISERROR('Destination table not properly formatted.', 16, 1);
			RETURN;
		END;
	END;

	WITH
	a0 AS
	(SELECT 1 AS n UNION ALL SELECT 1),
	a1 AS
	(SELECT 1 AS n FROM a0 AS a, a0 AS b),
	a2 AS
	(SELECT 1 AS n FROM a1 AS a, a1 AS b),
	a3 AS
	(SELECT 1 AS n FROM a2 AS a, a2 AS b),
	a4 AS
	(SELECT 1 AS n FROM a3 AS a, a3 AS b),
	numbers AS
	(
		SELECT TOP(LEN(@sort_order))
			ROW_NUMBER() OVER
			(
				ORDER BY (SELECT NULL)
			) AS number
		FROM a4
		ORDER BY
			number
	),
	tokens AS
	(
		SELECT 
			'|[' +
				SUBSTRING
				(
					@sort_order,
					number + 1,
					CHARINDEX(']', @sort_order, number) - number - 1
				) + '|]' AS token,
			SUBSTRING
			(
				@sort_order,
				CHARINDEX(']', @sort_order, number) + 1,
				COALESCE(NULLIF(CHARINDEX('[', @sort_order, CHARINDEX(']', @sort_order, number)), 0), LEN(@sort_order)) - CHARINDEX(']', @sort_order, number)
			) AS next_chunk,
			number
		FROM numbers
		WHERE
			SUBSTRING(@sort_order, number, 1) = '['
	),
	ordered_columns AS
	(
		SELECT
			x.column_name +
				CASE
					WHEN tokens.next_chunk LIKE '%asc%' THEN ' ASC'
					WHEN tokens.next_chunk LIKE '%desc%' THEN ' DESC'
					ELSE ''
				END AS column_name,
			ROW_NUMBER() OVER
			(
				PARTITION BY
					x.column_name
				ORDER BY
					tokens.number
			) AS r,
			tokens.number
		FROM tokens
		JOIN
		(
			SELECT '[session_id]' AS column_name
			UNION ALL
			SELECT '[physical_io]'
			UNION ALL
			SELECT '[reads]'
			UNION ALL
			SELECT '[physical_reads]'
			UNION ALL
			SELECT '[writes]'
			UNION ALL
			SELECT '[tempdb_allocations]'
			UNION ALL
			SELECT '[tempdb_current]'
			UNION ALL
			SELECT '[CPU]'
			UNION ALL
			SELECT '[context_switches]'
			UNION ALL
			SELECT '[used_memory]'
			UNION ALL
			SELECT '[physical_io_delta]'
			UNION ALL
			SELECT '[reads_delta]'
			UNION ALL
			SELECT '[physical_reads_delta]'
			UNION ALL
			SELECT '[writes_delta]'
			UNION ALL
			SELECT '[tempdb_allocations_delta]'
			UNION ALL
			SELECT '[tempdb_current_delta]'
			UNION ALL
			SELECT '[CPU_delta]'
			UNION ALL
			SELECT '[context_switches_delta]'
			UNION ALL
			SELECT '[used_memory_delta]'
			UNION ALL
			SELECT '[tasks]'
			UNION ALL
			SELECT '[tran_start_time]'
			UNION ALL
			SELECT '[open_tran_count]'
			UNION ALL
			SELECT '[blocking_session_id]'
			UNION ALL
			SELECT '[blocked_session_count]'
			UNION ALL
			SELECT '[percent_complete]'
			UNION ALL
			SELECT '[host_name]'
			UNION ALL
			SELECT '[login_name]'
			UNION ALL
			SELECT '[database_name]'
			UNION ALL
			SELECT '[start_time]'
			UNION ALL
			SELECT '[login_time]'
		) AS x ON 
			x.column_name LIKE token ESCAPE '|'
	)
	SELECT
		@sort_order = COALESCE(z.sort_order, '')
	FROM
	(
		SELECT
			STUFF
			(
				(
					SELECT
						',' + column_name as [text()]
					FROM ordered_columns
					WHERE
						r = 1
					ORDER BY
						number
					FOR XML
						PATH('')
				),
				1,
				1,
				''
			) AS sort_order
	) AS z;

	CREATE TABLE #sessions
	(
		recursion SMALLINT NOT NULL,
		session_id SMALLINT NOT NULL,
		request_id INT NOT NULL,
		session_number INT NOT NULL,
		elapsed_time INT NOT NULL,
		avg_elapsed_time INT NULL,
		physical_io BIGINT NULL,
		reads BIGINT NULL,
		physical_reads BIGINT NULL,
		writes BIGINT NULL,
		tempdb_allocations BIGINT NULL,
		tempdb_current BIGINT NULL,
		CPU INT NULL,
		thread_CPU_snapshot BIGINT NULL,
		context_switches BIGINT NULL,
		used_memory BIGINT NOT NULL, 
		tasks SMALLINT NULL,
		status VARCHAR(30) NOT NULL,
		wait_info NVARCHAR(4000) NULL,
		locks XML NULL,
		transaction_id BIGINT NULL,
		tran_start_time DATETIME NULL,
		tran_log_writes NVARCHAR(4000) NULL,
		open_tran_count SMALLINT NULL,
		sql_command XML NULL,
		sql_handle VARBINARY(64) NULL,
		statement_start_offset INT NULL,
		statement_end_offset INT NULL,
		sql_text XML NULL,
		plan_handle VARBINARY(64) NULL,
		query_plan XML NULL,
		blocking_session_id SMALLINT NULL,
		blocked_session_count SMALLINT NULL,
		percent_complete REAL NULL,
		host_name sysname NULL,
		login_name sysname NOT NULL,
		database_name sysname NULL,
		program_name sysname NULL,
		additional_info XML NULL,
		start_time DATETIME NOT NULL,
		login_time DATETIME NULL,
		last_request_start_time DATETIME NULL,
		PRIMARY KEY CLUSTERED (session_id, request_id, recursion) WITH (IGNORE_DUP_KEY = ON),
		UNIQUE NONCLUSTERED (transaction_id, session_id, request_id, recursion) WITH (IGNORE_DUP_KEY = ON)
	);

	IF @return_schema = 0
	BEGIN;
		--Disable unnecessary autostats on the table
		CREATE STATISTICS s_session_id ON #sessions (session_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_request_id ON #sessions (request_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_transaction_id ON #sessions (transaction_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_session_number ON #sessions (session_number)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_status ON #sessions (status)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_start_time ON #sessions (start_time)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_last_request_start_time ON #sessions (last_request_start_time)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_recursion ON #sessions (recursion)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;

		DECLARE @recursion SMALLINT;
		SET @recursion = 
			CASE @delta_interval
				WHEN 0 THEN 1
				ELSE -1
			END;

		DECLARE @first_collection_ms_ticks BIGINT;
		DECLARE @last_collection_start DATETIME;

		--Used for the delta pull
		REDO:;
		
		IF 
			@get_locks = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[locks|]%' ESCAPE '|'
		BEGIN;
			SELECT
				y.resource_type,
				y.database_name,
				y.object_id,
				y.file_id,
				y.page_type,
				y.hobt_id,
				y.allocation_unit_id,
				y.index_id,
				y.schema_id,
				y.principal_id,
				y.request_mode,
				y.request_status,
				y.session_id,
				y.resource_description,
				y.request_count,
				s.request_id,
				s.start_time,
				CONVERT(sysname, NULL) AS object_name,
				CONVERT(sysname, NULL) AS index_name,
				CONVERT(sysname, NULL) AS schema_name,
				CONVERT(sysname, NULL) AS principal_name,
				CONVERT(NVARCHAR(2048), NULL) AS query_error
			INTO #locks
			FROM
			(
				SELECT
					sp.spid AS session_id,
					CASE sp.status
						WHEN 'sleeping' THEN CONVERT(INT, 0)
						ELSE sp.request_id
					END AS request_id,
					CASE sp.status
						WHEN 'sleeping' THEN sp.last_batch
						ELSE COALESCE(req.start_time, sp.last_batch)
					END AS start_time,
					sp.dbid
				FROM sys.sysprocesses AS sp
				OUTER APPLY
				(
					SELECT TOP(1)
						CASE
							WHEN 
							(
								sp.hostprocess > ''
								OR r.total_elapsed_time < 0
							) THEN
								r.start_time
							ELSE
								DATEADD
								(
									ms, 
									1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())), 
									DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
								)
						END AS start_time
					FROM sys.dm_exec_requests AS r
					WHERE
						r.session_id = sp.spid
						AND r.request_id = sp.request_id
				) AS req
				WHERE
					--Process inclusive filter
					1 =
						CASE
							WHEN @filter <> '' THEN
								CASE @filter_type
									WHEN 'session' THEN
										CASE
											WHEN
												CONVERT(SMALLINT, @filter) = 0
												OR sp.spid = CONVERT(SMALLINT, @filter)
													THEN 1
											ELSE 0
										END
									WHEN 'program' THEN
										CASE
											WHEN sp.program_name LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'login' THEN
										CASE
											WHEN sp.loginame LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'host' THEN
										CASE
											WHEN sp.hostname LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'database' THEN
										CASE
											WHEN DB_NAME(sp.dbid) LIKE @filter THEN 1
											ELSE 0
										END
									ELSE 0
								END
							ELSE 1
						END
					--Process exclusive filter
					AND 0 =
						CASE
							WHEN @not_filter <> '' THEN
								CASE @not_filter_type
									WHEN 'session' THEN
										CASE
											WHEN sp.spid = CONVERT(SMALLINT, @not_filter) THEN 1
											ELSE 0
										END
									WHEN 'program' THEN
										CASE
											WHEN sp.program_name LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'login' THEN
										CASE
											WHEN sp.loginame LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'host' THEN
										CASE
											WHEN sp.hostname LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'database' THEN
										CASE
											WHEN DB_NAME(sp.dbid) LIKE @not_filter THEN 1
											ELSE 0
										END
									ELSE 0
								END
							ELSE 0
						END
					AND 
					(
						@show_own_spid = 1
						OR sp.spid <> @@SPID
					)
					AND 
					(
						@show_system_spids = 1
						OR sp.hostprocess > ''
					)
					AND sp.ecid = 0
			) AS s
			INNER HASH JOIN
			(
				SELECT
					x.resource_type,
					x.database_name,
					x.object_id,
					x.file_id,
					CASE
						WHEN x.page_no = 1 OR x.page_no % 8088 = 0 THEN 'PFS'
						WHEN x.page_no = 2 OR x.page_no % 511232 = 0 THEN 'GAM'
						WHEN x.page_no = 3 OR x.page_no % 511233 = 0 THEN 'SGAM'
						WHEN x.page_no = 6 OR x.page_no % 511238 = 0 THEN 'DCM'
						WHEN x.page_no = 7 OR x.page_no % 511239 = 0 THEN 'BCM'
						WHEN x.page_no IS NOT NULL THEN '*'
						ELSE NULL
					END AS page_type,
					x.hobt_id,
					x.allocation_unit_id,
					x.index_id,
					x.schema_id,
					x.principal_id,
					x.request_mode,
					x.request_status,
					x.session_id,
					x.request_id,
					CASE
						WHEN COALESCE(x.object_id, x.file_id, x.hobt_id, x.allocation_unit_id, x.index_id, x.schema_id, x.principal_id) IS NULL THEN NULLIF(resource_description, '')
						ELSE NULL
					END AS resource_description,
					COUNT(*) AS request_count
				FROM
				(
					SELECT
						tl.resource_type +
							CASE
								WHEN tl.resource_subtype = '' THEN ''
								ELSE '.' + tl.resource_subtype
							END AS resource_type,
						COALESCE(DB_NAME(tl.resource_database_id), N'(null)') AS database_name,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_type = 'OBJECT' THEN tl.resource_associated_entity_id
								WHEN tl.resource_description LIKE '%object_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('object_id = ', tl.resource_description) + 12), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('object_id = ', tl.resource_description) + 12),
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('object_id = ', tl.resource_description) + 12)
										)
									)
								ELSE NULL
							END
						) AS object_id,
						CONVERT
						(
							INT,
							CASE 
								WHEN tl.resource_type = 'FILE' THEN CONVERT(INT, tl.resource_description)
								WHEN tl.resource_type IN ('PAGE', 'EXTENT', 'RID') THEN LEFT(tl.resource_description, CHARINDEX(':', tl.resource_description)-1)
								ELSE NULL
							END
						) AS file_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_type IN ('PAGE', 'EXTENT', 'RID') THEN 
									SUBSTRING
									(
										tl.resource_description, 
										CHARINDEX(':', tl.resource_description) + 1, 
										COALESCE
										(
											NULLIF
											(
												CHARINDEX(':', tl.resource_description, CHARINDEX(':', tl.resource_description) + 1), 
												0
											), 
											DATALENGTH(tl.resource_description)+1
										) - (CHARINDEX(':', tl.resource_description) + 1)
									)
								ELSE NULL
							END
						) AS page_no,
						CASE
							WHEN tl.resource_type IN ('PAGE', 'KEY', 'RID', 'HOBT') THEN tl.resource_associated_entity_id
							ELSE NULL
						END AS hobt_id,
						CASE
							WHEN tl.resource_type = 'ALLOCATION_UNIT' THEN tl.resource_associated_entity_id
							ELSE NULL
						END AS allocation_unit_id,
						CONVERT
						(
							INT,
							CASE
								WHEN
									/*TODO: Deal with server principals*/ 
									tl.resource_subtype <> 'SERVER_PRINCIPAL' 
									AND tl.resource_description LIKE '%index_id or stats_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23)
										)
									)
								ELSE NULL
							END 
						) AS index_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_description LIKE '%schema_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('schema_id = ', tl.resource_description) + 12), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('schema_id = ', tl.resource_description) + 12), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('schema_id = ', tl.resource_description) + 12)
										)
									)
								ELSE NULL
							END 
						) AS schema_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_description LIKE '%principal_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('principal_id = ', tl.resource_description) + 15), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('principal_id = ', tl.resource_description) + 15), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('principal_id = ', tl.resource_description) + 15)
										)
									)
								ELSE NULL
							END
						) AS principal_id,
						tl.request_mode,
						tl.request_status,
						tl.request_session_id AS session_id,
						tl.request_request_id AS request_id,

						/*TODO: Applocks, other resource_descriptions*/
						RTRIM(tl.resource_description) AS resource_description,
						tl.resource_associated_entity_id
						/*********************************************/
					FROM 
					(
						SELECT 
							request_session_id,
							CONVERT(VARCHAR(120), resource_type) COLLATE Latin1_General_Bin2 AS resource_type,
							CONVERT(VARCHAR(120), resource_subtype) COLLATE Latin1_General_Bin2 AS resource_subtype,
							resource_database_id,
							CONVERT(VARCHAR(512), resource_description) COLLATE Latin1_General_Bin2 AS resource_description,
							resource_associated_entity_id,
							CONVERT(VARCHAR(120), request_mode) COLLATE Latin1_General_Bin2 AS request_mode,
							CONVERT(VARCHAR(120), request_status) COLLATE Latin1_General_Bin2 AS request_status,
							request_request_id
						FROM sys.dm_tran_locks
					) AS tl
				) AS x
				GROUP BY
					x.resource_type,
					x.database_name,
					x.object_id,
					x.file_id,
					CASE
						WHEN x.page_no = 1 OR x.page_no % 8088 = 0 THEN 'PFS'
						WHEN x.page_no = 2 OR x.page_no % 511232 = 0 THEN 'GAM'
						WHEN x.page_no = 3 OR x.page_no % 511233 = 0 THEN 'SGAM'
						WHEN x.page_no = 6 OR x.page_no % 511238 = 0 THEN 'DCM'
						WHEN x.page_no = 7 OR x.page_no % 511239 = 0 THEN 'BCM'
						WHEN x.page_no IS NOT NULL THEN '*'
						ELSE NULL
					END,
					x.hobt_id,
					x.allocation_unit_id,
					x.index_id,
					x.schema_id,
					x.principal_id,
					x.request_mode,
					x.request_status,
					x.session_id,
					x.request_id,
					CASE
						WHEN COALESCE(x.object_id, x.file_id, x.hobt_id, x.allocation_unit_id, x.index_id, x.schema_id, x.principal_id) IS NULL THEN NULLIF(resource_description, '')
						ELSE NULL
					END
			) AS y ON
				y.session_id = s.session_id
				AND y.request_id = s.request_id
			OPTION (HASH GROUP);

			--Disable unnecessary autostats on the table
			CREATE STATISTICS s_database_name ON #locks (database_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_id ON #locks (object_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_hobt_id ON #locks (hobt_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_allocation_unit_id ON #locks (allocation_unit_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_index_id ON #locks (index_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_id ON #locks (schema_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_principal_id ON #locks (principal_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_id ON #locks (request_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_start_time ON #locks (start_time)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_resource_type ON #locks (resource_type)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_name ON #locks (object_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_name ON #locks (schema_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_page_type ON #locks (page_type)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_mode ON #locks (request_mode)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_status ON #locks (request_status)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_resource_description ON #locks (resource_description)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_index_name ON #locks (index_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_principal_name ON #locks (principal_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
		END;
		
		DECLARE 
			@sql VARCHAR(MAX), 
			@sql_n NVARCHAR(MAX);

		SET @sql = 
			CONVERT(VARCHAR(MAX), '') +
			'DECLARE @blocker BIT;
			SET @blocker = 0;
			DECLARE @i INT;
			SET @i = 2147483647;

			DECLARE @sessions TABLE
			(
				session_id SMALLINT NOT NULL,
				request_id INT NOT NULL,
				login_time DATETIME,
				last_request_end_time DATETIME,
				status VARCHAR(30),
				statement_start_offset INT,
				statement_end_offset INT,
				sql_handle BINARY(20),
				host_name NVARCHAR(128),
				login_name NVARCHAR(128),
				program_name NVARCHAR(128),
				database_id SMALLINT,
				memory_usage INT,
				open_tran_count SMALLINT, 
				' +
				CASE
					WHEN 
					(
						@get_task_info <> 0 
						OR @find_block_leaders = 1 
					) THEN
						'wait_type NVARCHAR(32),
						wait_resource NVARCHAR(256),
						wait_time BIGINT, 
						'
					ELSE 
						''
				END +
				'blocked SMALLINT,
				is_user_process BIT,
				cmd VARCHAR(32),
				PRIMARY KEY CLUSTERED (session_id, request_id) WITH (IGNORE_DUP_KEY = ON)
			);

			DECLARE @blockers TABLE
			(
				session_id INT NOT NULL PRIMARY KEY
			);

			BLOCKERS:;

			INSERT @sessions
			(
				session_id,
				request_id,
				login_time,
				last_request_end_time,
				status,
				statement_start_offset,
				statement_end_offset,
				sql_handle,
				host_name,
				login_name,
				program_name,
				database_id,
				memory_usage,
				open_tran_count, 
				' +
				CASE
					WHEN 
					(
						@get_task_info <> 0
						OR @find_block_leaders = 1 
					) THEN
						'wait_type,
						wait_resource,
						wait_time, 
						'
					ELSE
						''
				END +
				'blocked,
				is_user_process,
				cmd 
			)
			SELECT TOP(@i)
				spy.session_id,
				spy.request_id,
				spy.login_time,
				spy.last_request_end_time,
				spy.status,
				spy.statement_start_offset,
				spy.statement_end_offset,
				spy.sql_handle,
				spy.host_name,
				spy.login_name,
				spy.program_name,
				spy.database_id,
				spy.memory_usage,
				spy.open_tran_count,
				' +
				CASE
					WHEN 
					(
						@get_task_info <> 0  
						OR @find_block_leaders = 1 
					) THEN
						'spy.wait_type,
						CASE
							WHEN
								spy.wait_type LIKE N''PAGE%LATCH_%''
								OR spy.wait_type = N''CXPACKET''
								OR spy.wait_type LIKE N''LATCH[_]%''
								OR spy.wait_type = N''OLEDB'' THEN
									spy.wait_resource
							ELSE
								NULL
						END AS wait_resource,
						spy.wait_time, 
						'
					ELSE
						''
				END +
				'spy.blocked,
				spy.is_user_process,
				spy.cmd
			FROM
			(
				SELECT TOP(@i)
					spx.*, 
					' +
					CASE
						WHEN 
						(
							@get_task_info <> 0 
							OR @find_block_leaders = 1 
						) THEN
							'ROW_NUMBER() OVER
							(
								PARTITION BY
									spx.session_id,
									spx.request_id
								ORDER BY
									CASE
										WHEN spx.wait_type LIKE N''LCK[_]%'' THEN 
											1
										ELSE
											99
									END,
									spx.wait_time DESC,
									spx.blocked DESC
							) AS r 
							'
						ELSE 
							'1 AS r 
							'
					END +
				'FROM
				(
					SELECT TOP(@i)
						sp0.session_id,
						sp0.request_id,
						sp0.login_time,
						sp0.last_request_end_time,
						LOWER(sp0.status) AS status,
						CASE
							WHEN sp0.cmd = ''CREATE INDEX'' THEN
								0
							ELSE
								sp0.stmt_start
						END AS statement_start_offset,
						CASE
							WHEN sp0.cmd = N''CREATE INDEX'' THEN
								-1
							ELSE
								COALESCE(NULLIF(sp0.stmt_end, 0), -1)
						END AS statement_end_offset,
						sp0.sql_handle,
						sp0.host_name,
						sp0.login_name,
						sp0.program_name,
						sp0.database_id,
						sp0.memory_usage,
						sp0.open_tran_count, 
						' +
						CASE
							WHEN 
							(
								@get_task_info <> 0 
								OR @find_block_leaders = 1 
							) THEN
								'CASE
									WHEN sp0.wait_time > 0 AND sp0.wait_type <> N''CXPACKET'' THEN
										sp0.wait_type
									ELSE
										NULL
								END AS wait_type,
								CASE
									WHEN sp0.wait_time > 0 AND sp0.wait_type <> N''CXPACKET'' THEN 
										sp0.wait_resource
									ELSE
										NULL
								END AS wait_resource,
								CASE
									WHEN sp0.wait_type <> N''CXPACKET'' THEN
										sp0.wait_time
									ELSE
										0
								END AS wait_time, 
								'
							ELSE
								''
						END +
						'sp0.blocked,
						sp0.is_user_process,
						sp0.cmd
					FROM
					(
						SELECT TOP(@i)
							sp1.session_id,
							sp1.request_id,
							sp1.login_time,
							sp1.last_request_end_time,
							sp1.status,
							sp1.cmd,
							sp1.stmt_start,
							sp1.stmt_end,
							MAX(NULLIF(sp1.sql_handle, 0x00)) OVER (PARTITION BY sp1.session_id, sp1.request_id) AS sql_handle,
							sp1.host_name,
							MAX(sp1.login_name) OVER (PARTITION BY sp1.session_id, sp1.request_id) AS login_name,
							sp1.program_name,
							sp1.database_id,
							MAX(sp1.memory_usage)  OVER (PARTITION BY sp1.session_id, sp1.request_id) AS memory_usage,
							MAX(sp1.open_tran_count)  OVER (PARTITION BY sp1.session_id, sp1.request_id) AS open_tran_count,
							sp1.wait_type,
							sp1.wait_resource,
							sp1.wait_time,
							sp1.blocked,
							sp1.hostprocess,
							sp1.is_user_process
						FROM
						(
							SELECT TOP(@i)
								sp2.spid AS session_id,
								CASE sp2.status
									WHEN ''sleeping'' THEN
										CONVERT(INT, 0)
									ELSE
										sp2.request_id
								END AS request_id,
								MAX(sp2.login_time) AS login_time,
								MAX(sp2.last_batch) AS last_request_end_time,
								MAX(CONVERT(VARCHAR(30), RTRIM(sp2.status)) COLLATE Latin1_General_Bin2) AS status,
								MAX(CONVERT(VARCHAR(32), RTRIM(sp2.cmd)) COLLATE Latin1_General_Bin2) AS cmd,
								MAX(sp2.stmt_start) AS stmt_start,
								MAX(sp2.stmt_end) AS stmt_end,
								MAX(sp2.sql_handle) AS sql_handle,
								MAX(CONVERT(sysname, RTRIM(sp2.hostname)) COLLATE SQL_Latin1_General_CP1_CI_AS) AS host_name,
								MAX(CONVERT(sysname, RTRIM(sp2.loginame)) COLLATE SQL_Latin1_General_CP1_CI_AS) AS login_name,
								MAX
								(
									CASE
										WHEN blk.queue_id IS NOT NULL THEN
											N''Service Broker
												database_id: '' + CONVERT(NVARCHAR, blk.database_id) +
												N'' queue_id: '' + CONVERT(NVARCHAR, blk.queue_id)
										ELSE
											CONVERT
											(
												sysname,
												RTRIM(sp2.program_name)
											)
									END COLLATE SQL_Latin1_General_CP1_CI_AS
								) AS program_name,
								MAX(sp2.dbid) AS database_id,
								MAX(sp2.memusage) AS memory_usage,
								MAX(sp2.open_tran) AS open_tran_count,
								RTRIM(sp2.lastwaittype) AS wait_type,
								RTRIM(sp2.waitresource) AS wait_resource,
								MAX(sp2.waittime) AS wait_time,
								COALESCE(NULLIF(sp2.blocked, sp2.spid), 0) AS blocked,
								MAX
								(
									CASE
										WHEN blk.session_id = sp2.spid THEN
											''blocker''
										ELSE
											RTRIM(sp2.hostprocess)
									END
								) AS hostprocess,
								CONVERT
								(
									BIT,
									MAX
									(
										CASE
											WHEN sp2.hostprocess > '''' THEN
												1
											ELSE
												0
										END
									)
								) AS is_user_process
							FROM
							(
								SELECT TOP(@i)
									session_id,
									CONVERT(INT, NULL) AS queue_id,
									CONVERT(INT, NULL) AS database_id
								FROM @blockers

								UNION ALL

								SELECT TOP(@i)
									CONVERT(SMALLINT, 0),
									CONVERT(INT, NULL) AS queue_id,
									CONVERT(INT, NULL) AS database_id
								WHERE
									@blocker = 0

								UNION ALL

								SELECT TOP(@i)
									CONVERT(SMALLINT, spid),
									queue_id,
									database_id
								FROM sys.dm_broker_activated_tasks
								WHERE
									@blocker = 0
							) AS blk
							INNER JOIN sys.sysprocesses AS sp2 ON
								sp2.spid = blk.session_id
								OR
								(
									blk.session_id = 0
									AND @blocker = 0
								)
							' +
							CASE 
								WHEN 
								(
									@get_task_info = 0 
									AND @find_block_leaders = 0
								) THEN
									'WHERE
										sp2.ecid = 0 
									' 
								ELSE
									''
							END +
							'GROUP BY
								sp2.spid,
								CASE sp2.status
									WHEN ''sleeping'' THEN
										CONVERT(INT, 0)
									ELSE
										sp2.request_id
								END,
								RTRIM(sp2.lastwaittype),
								RTRIM(sp2.waitresource),
								COALESCE(NULLIF(sp2.blocked, sp2.spid), 0)
						) AS sp1
					) AS sp0
					WHERE
						@blocker = 1
						OR
						(1=1 
						' +
							--inclusive filter
							CASE
								WHEN @filter <> '' THEN
									CASE @filter_type
										WHEN 'session' THEN
											CASE
												WHEN CONVERT(SMALLINT, @filter) <> 0 THEN
													'AND sp0.session_id = CONVERT(SMALLINT, @filter) 
													'
												ELSE
													''
											END
										WHEN 'program' THEN
											'AND sp0.program_name LIKE @filter 
											'
										WHEN 'login' THEN
											'AND sp0.login_name LIKE @filter 
											'
										WHEN 'host' THEN
											'AND sp0.host_name LIKE @filter 
											'
										WHEN 'database' THEN
											'AND DB_NAME(sp0.database_id) LIKE @filter 
											'
										ELSE
											''
									END
								ELSE
									''
							END +
							--exclusive filter
							CASE
								WHEN @not_filter <> '' THEN
									CASE @not_filter_type
										WHEN 'session' THEN
											CASE
												WHEN CONVERT(SMALLINT, @not_filter) <> 0 THEN
													'AND sp0.session_id <> CONVERT(SMALLINT, @not_filter) 
													'
												ELSE
													''
											END
										WHEN 'program' THEN
											'AND sp0.program_name NOT LIKE @not_filter 
											'
										WHEN 'login' THEN
											'AND sp0.login_name NOT LIKE @not_filter 
											'
										WHEN 'host' THEN
											'AND sp0.host_name NOT LIKE @not_filter 
											'
										WHEN 'database' THEN
											'AND DB_NAME(sp0.database_id) NOT LIKE @not_filter 
											'
										ELSE
											''
									END
								ELSE
									''
							END +
							CASE @show_own_spid
								WHEN 1 THEN
									''
								ELSE
									'AND sp0.session_id <> @@spid 
									'
							END +
							CASE 
								WHEN @show_system_spids = 0 THEN
									'AND sp0.hostprocess > '''' 
									' 
								ELSE
									''
							END +
							CASE @show_sleeping_spids
								WHEN 0 THEN
									'AND sp0.status <> ''sleeping'' 
									'
								WHEN 1 THEN
									'AND
									(
										sp0.status <> ''sleeping''
										OR sp0.open_tran_count > 0
									)
									'
								ELSE
									''
							END +
						')
				) AS spx
			) AS spy
			WHERE
				spy.r = 1; 
			' + 
			CASE @recursion
				WHEN 1 THEN 
					'IF @@ROWCOUNT > 0
					BEGIN;
						INSERT @blockers
						(
							session_id
						)
						SELECT TOP(@i)
							blocked
						FROM @sessions
						WHERE
							NULLIF(blocked, 0) IS NOT NULL

						EXCEPT

						SELECT TOP(@i)
							session_id
						FROM @sessions; 
						' +

						CASE
							WHEN
							(
								@get_task_info > 0
								OR @find_block_leaders = 1
							) THEN
								'IF @@ROWCOUNT > 0
								BEGIN;
									SET @blocker = 1;
									GOTO BLOCKERS;
								END; 
								'
							ELSE 
								''
						END +
					'END; 
					'
				ELSE 
					''
			END +
			'SELECT TOP(@i)
				@recursion AS recursion,
				x.session_id,
				x.request_id,
				DENSE_RANK() OVER
				(
					ORDER BY
						x.session_id
				) AS session_number,
				' +
				CASE
					WHEN @output_column_list LIKE '%|[dd hh:mm:ss.mss|]%' ESCAPE '|' THEN 
						'x.elapsed_time '
					ELSE 
						'0 '
				END + 
					'AS elapsed_time, 
					' +
				CASE
					WHEN
						(
							@output_column_list LIKE '%|[dd hh:mm:ss.mss (avg)|]%' ESCAPE '|' OR 
							@output_column_list LIKE '%|[avg_elapsed_time|]%' ESCAPE '|'
						)
						AND @recursion = 1
							THEN 
								'x.avg_elapsed_time / 1000 '
					ELSE 
						'NULL '
				END + 
					'AS avg_elapsed_time, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[physical_io|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[physical_io_delta|]%' ESCAPE '|'
							THEN 
								'x.physical_io '
					ELSE 
						'NULL '
				END + 
					'AS physical_io, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[reads|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[reads_delta|]%' ESCAPE '|'
							THEN 
								'x.reads '
					ELSE 
						'0 '
				END + 
					'AS reads, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[physical_reads|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[physical_reads_delta|]%' ESCAPE '|'
							THEN 
								'x.physical_reads '
					ELSE 
						'0 '
				END + 
					'AS physical_reads, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[writes|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[writes_delta|]%' ESCAPE '|'
							THEN 
								'x.writes '
					ELSE 
						'0 '
				END + 
					'AS writes, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tempdb_allocations|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[tempdb_allocations_delta|]%' ESCAPE '|'
							THEN 
								'x.tempdb_allocations '
					ELSE 
						'0 '
				END + 
					'AS tempdb_allocations, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tempdb_current|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[tempdb_current_delta|]%' ESCAPE '|'
							THEN 
								'x.tempdb_current '
					ELSE 
						'0 '
				END + 
					'AS tempdb_current, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[CPU|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
							THEN
								'x.CPU '
					ELSE
						'0 '
				END + 
					'AS CPU, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
						AND @get_task_info = 2
							THEN 
								'x.thread_CPU_snapshot '
					ELSE 
						'0 '
				END + 
					'AS thread_CPU_snapshot, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[context_switches|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[context_switches_delta|]%' ESCAPE '|'
							THEN 
								'x.context_switches '
					ELSE 
						'NULL '
				END + 
					'AS context_switches, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[used_memory|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[used_memory_delta|]%' ESCAPE '|'
							THEN 
								'x.used_memory '
					ELSE 
						'0 '
				END + 
					'AS used_memory, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tasks|]%' ESCAPE '|'
						AND @recursion = 1
							THEN 
								'x.tasks '
					ELSE 
						'NULL '
				END + 
					'AS tasks, 
					' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[status|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[sql_command|]%' ESCAPE '|'
						)
						AND @recursion = 1
							THEN 
								'x.status '
					ELSE 
						''''' '
				END + 
					'AS status, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[wait_info|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								CASE @get_task_info
									WHEN 2 THEN
										'COALESCE(x.task_wait_info, x.sys_wait_info) '
									ELSE
										'x.sys_wait_info '
								END
					ELSE 
						'NULL '
				END + 
					'AS wait_info, 
					' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[tran_start_time|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[tran_log_writes|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 
								'x.transaction_id '
					ELSE 
						'NULL '
				END + 
					'AS transaction_id, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[open_tran_count|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.open_tran_count '
					ELSE 
						'NULL '
				END + 
					'AS open_tran_count, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.sql_handle '
					ELSE 
						'NULL '
				END + 
					'AS sql_handle, 
					' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 
								'x.statement_start_offset '
					ELSE 
						'NULL '
				END + 
					'AS statement_start_offset, 
					' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 
								'x.statement_end_offset '
					ELSE 
						'NULL '
				END + 
					'AS statement_end_offset, 
					' +
				'NULL AS sql_text, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.plan_handle '
					ELSE 
						'NULL '
				END + 
					'AS plan_handle, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[blocking_session_id|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'NULLIF(x.blocking_session_id, 0) '
					ELSE 
						'NULL '
				END + 
					'AS blocking_session_id, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[percent_complete|]%' ESCAPE '|'
						AND @recursion = 1
							THEN 
								'x.percent_complete '
					ELSE 
						'NULL '
				END + 
					'AS percent_complete, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[host_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.host_name '
					ELSE 
						''''' '
				END + 
					'AS host_name, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[login_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.login_name '
					ELSE 
						''''' '
				END + 
					'AS login_name, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[database_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'DB_NAME(x.database_id) '
					ELSE 
						'NULL '
				END + 
					'AS database_name, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[program_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.program_name '
					ELSE 
						''''' '
				END + 
					'AS program_name, 
					' +
				CASE
					WHEN
						@output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
						AND @recursion = 1
							THEN
								'(
									SELECT TOP(@i)
										x.text_size,
										x.language,
										x.date_format,
										x.date_first,
										CASE x.quoted_identifier
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS quoted_identifier,
										CASE x.arithabort
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS arithabort,
										CASE x.ansi_null_dflt_on
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_null_dflt_on,
										CASE x.ansi_defaults
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_defaults,
										CASE x.ansi_warnings
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_warnings,
										CASE x.ansi_padding
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_padding,
										CASE ansi_nulls
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_nulls,
										CASE x.concat_null_yields_null
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS concat_null_yields_null,
										CASE x.transaction_isolation_level
											WHEN 0 THEN ''Unspecified''
											WHEN 1 THEN ''ReadUncomitted''
											WHEN 2 THEN ''ReadCommitted''
											WHEN 3 THEN ''Repeatable''
											WHEN 4 THEN ''Serializable''
											WHEN 5 THEN ''Snapshot''
										END AS transaction_isolation_level,
										x.lock_timeout,
										x.deadlock_priority,
										x.row_count,
										x.command_type, 
										' +
										CASE
											WHEN @output_column_list LIKE '%|[program_name|]%' ESCAPE '|' THEN
												'(
													SELECT TOP(1)
														CONVERT(uniqueidentifier, CONVERT(XML, '''').value(''xs:hexBinary( substring(sql:column("agent_info.job_id_string"), 0) )'', ''binary(16)'')) AS job_id,
														agent_info.step_id,
														(
															SELECT TOP(1)
																NULL
															FOR XML
																PATH(''job_name''),
																TYPE
														),
														(
															SELECT TOP(1)
																NULL
															FOR XML
																PATH(''step_name''),
																TYPE
														)
													FROM
													(
														SELECT TOP(1)
															SUBSTRING(x.program_name, CHARINDEX(''0x'', x.program_name) + 2, 32) AS job_id_string,
															SUBSTRING(x.program_name, CHARINDEX('': Step '', x.program_name) + 7, CHARINDEX('')'', x.program_name, CHARINDEX('': Step '', x.program_name)) - (CHARINDEX('': Step '', x.program_name) + 7)) AS step_id
														WHERE
															x.program_name LIKE N''SQLAgent - TSQL JobStep (Job 0x%''
													) AS agent_info
													FOR XML
														PATH(''agent_job_info''),
														TYPE
												),
												'
											ELSE ''
										END +
										CASE
											WHEN @get_task_info = 2 THEN
												'CONVERT(XML, x.block_info) AS block_info, 
												'
											ELSE
												''
										END +
										'x.host_process_id 
									FOR XML
										PATH(''additional_info''),
										TYPE
								) '
					ELSE
						'NULL '
				END + 
					'AS additional_info, 
				x.start_time, 
					' +
				CASE
					WHEN
						@output_column_list LIKE '%|[login_time|]%' ESCAPE '|'
						AND @recursion = 1
							THEN
								'x.login_time '
					ELSE 
						'NULL '
				END + 
					'AS login_time, 
				x.last_request_start_time
			FROM
			(
				SELECT TOP(@i)
					y.*,
					CASE
						WHEN DATEDIFF(day, y.start_time, GETDATE()) > 24 THEN
							DATEDIFF(second, GETDATE(), y.start_time)
						ELSE DATEDIFF(ms, y.start_time, GETDATE())
					END AS elapsed_time,
					COALESCE(tempdb_info.tempdb_allocations, 0) AS tempdb_allocations,
					COALESCE
					(
						CASE
							WHEN tempdb_info.tempdb_current < 0 THEN 0
							ELSE tempdb_info.tempdb_current
						END,
						0
					) AS tempdb_current, 
					' +
					CASE
						WHEN 
							(
								@get_task_info <> 0
								OR @find_block_leaders = 1
							) THEN
								'N''('' + CONVERT(NVARCHAR, y.wait_duration_ms) + N''ms)'' +
									y.wait_type +
										CASE
											WHEN y.wait_type LIKE N''PAGE%LATCH_%'' THEN
												N'':'' +
												COALESCE(DB_NAME(CONVERT(INT, LEFT(y.resource_description, CHARINDEX(N'':'', y.resource_description) - 1))), N''(null)'') +
												N'':'' +
												SUBSTRING(y.resource_description, CHARINDEX(N'':'', y.resource_description) + 1, LEN(y.resource_description) - CHARINDEX(N'':'', REVERSE(y.resource_description)) - CHARINDEX(N'':'', y.resource_description)) +
												N''('' +
													CASE
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 1 OR
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 8088 = 0
																THEN 
																	N''PFS''
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 2 OR
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511232 = 0
																THEN 
																	N''GAM''
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 3 OR
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511233 = 0
																THEN
																	N''SGAM''
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 6 OR
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511238 = 0 
																THEN 
																	N''DCM''
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 7 OR
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511239 = 0 
																THEN 
																	N''BCM''
														ELSE 
															N''*''
													END +
												N'')''
											WHEN y.wait_type = N''CXPACKET'' THEN
												N'':'' + SUBSTRING(y.resource_description, CHARINDEX(N''nodeId'', y.resource_description) + 7, 4)
											WHEN y.wait_type LIKE N''LATCH[_]%'' THEN
												N'' ['' + LEFT(y.resource_description, COALESCE(NULLIF(CHARINDEX(N'' '', y.resource_description), 0), LEN(y.resource_description) + 1) - 1) + N'']''
											WHEN
												y.wait_type = N''OLEDB''
												AND y.resource_description LIKE N''%(SPID=%)'' THEN
													N''['' + LEFT(y.resource_description, CHARINDEX(N''(SPID='', y.resource_description) - 2) +
														N'':'' + SUBSTRING(y.resource_description, CHARINDEX(N''(SPID='', y.resource_description) + 6, CHARINDEX(N'')'', y.resource_description, (CHARINDEX(N''(SPID='', y.resource_description) + 6)) - (CHARINDEX(N''(SPID='', y.resource_description) + 6)) + '']''
											ELSE
												N''''
										END COLLATE Latin1_General_Bin2 AS sys_wait_info, 
										'
							ELSE
								''
						END +
						CASE
							WHEN @get_task_info = 2 THEN
								'tasks.physical_io,
								tasks.context_switches,
								tasks.tasks,
								tasks.block_info,
								tasks.wait_info AS task_wait_info,
								tasks.thread_CPU_snapshot,
								'
							ELSE
								'' 
					END +
					CASE 
						WHEN NOT (@get_avg_time = 1 AND @recursion = 1) THEN
							'CONVERT(INT, NULL) '
						ELSE 
							'qs.total_elapsed_time / qs.execution_count '
					END + 
						'AS avg_elapsed_time 
				FROM
				(
					SELECT TOP(@i)
						sp.session_id,
						sp.request_id,
						COALESCE(r.logical_reads, s.logical_reads) AS reads,
						COALESCE(r.reads, s.reads) AS physical_reads,
						COALESCE(r.writes, s.writes) AS writes,
						COALESCE(r.CPU_time, s.CPU_time) AS CPU,
						sp.memory_usage + COALESCE(r.granted_query_memory, 0) AS used_memory,
						LOWER(sp.status) AS status,
						COALESCE(r.sql_handle, sp.sql_handle) AS sql_handle,
						COALESCE(r.statement_start_offset, sp.statement_start_offset) AS statement_start_offset,
						COALESCE(r.statement_end_offset, sp.statement_end_offset) AS statement_end_offset,
						' +
						CASE
							WHEN 
							(
								@get_task_info <> 0
								OR @find_block_leaders = 1 
							) THEN
								'sp.wait_type COLLATE Latin1_General_Bin2 AS wait_type,
								sp.wait_resource COLLATE Latin1_General_Bin2 AS resource_description,
								sp.wait_time AS wait_duration_ms, 
								'
							ELSE
								''
						END +
						'NULLIF(sp.blocked, 0) AS blocking_session_id,
						r.plan_handle,
						NULLIF(r.percent_complete, 0) AS percent_complete,
						sp.host_name,
						sp.login_name,
						sp.program_name,
						s.host_process_id,
						COALESCE(r.text_size, s.text_size) AS text_size,
						COALESCE(r.language, s.language) AS language,
						COALESCE(r.date_format, s.date_format) AS date_format,
						COALESCE(r.date_first, s.date_first) AS date_first,
						COALESCE(r.quoted_identifier, s.quoted_identifier) AS quoted_identifier,
						COALESCE(r.arithabort, s.arithabort) AS arithabort,
						COALESCE(r.ansi_null_dflt_on, s.ansi_null_dflt_on) AS ansi_null_dflt_on,
						COALESCE(r.ansi_defaults, s.ansi_defaults) AS ansi_defaults,
						COALESCE(r.ansi_warnings, s.ansi_warnings) AS ansi_warnings,
						COALESCE(r.ansi_padding, s.ansi_padding) AS ansi_padding,
						COALESCE(r.ansi_nulls, s.ansi_nulls) AS ansi_nulls,
						COALESCE(r.concat_null_yields_null, s.concat_null_yields_null) AS concat_null_yields_null,
						COALESCE(r.transaction_isolation_level, s.transaction_isolation_level) AS transaction_isolation_level,
						COALESCE(r.lock_timeout, s.lock_timeout) AS lock_timeout,
						COALESCE(r.deadlock_priority, s.deadlock_priority) AS deadlock_priority,
						COALESCE(r.row_count, s.row_count) AS row_count,
						COALESCE(r.command, sp.cmd) AS command_type,
						COALESCE
						(
							CASE
								WHEN
								(
									s.is_user_process = 0
									AND r.total_elapsed_time >= 0
								) THEN
									DATEADD
									(
										ms,
										1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())),
										DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
									)
							END,
							NULLIF(COALESCE(r.start_time, sp.last_request_end_time), CONVERT(DATETIME, ''19000101'', 112)),
							(
								SELECT TOP(1)
									DATEADD(second, -(ms_ticks / 1000), GETDATE())
								FROM sys.dm_os_sys_info
							)
						) AS start_time,
						sp.login_time,
						CASE
							WHEN s.is_user_process = 1 THEN
								s.last_request_start_time
							ELSE
								COALESCE
								(
									DATEADD
									(
										ms,
										1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())),
										DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
									),
									s.last_request_start_time
								)
						END AS last_request_start_time,
						r.transaction_id,
						sp.database_id,
						sp.open_tran_count
					FROM @sessions AS sp
					LEFT OUTER LOOP JOIN sys.dm_exec_sessions AS s ON
						s.session_id = sp.session_id
						AND s.login_time = sp.login_time
					LEFT OUTER LOOP JOIN sys.dm_exec_requests AS r ON
						sp.status <> ''sleeping''
						AND r.session_id = sp.session_id
						AND r.request_id = sp.request_id
						AND
						(
							(
								s.is_user_process = 0
								AND sp.is_user_process = 0
							)
							OR
							(
								r.start_time = s.last_request_start_time
								AND s.last_request_end_time = sp.last_request_end_time
							)
						)
				) AS y
				' + 
				CASE 
					WHEN @get_task_info = 2 THEN
						CONVERT(VARCHAR(MAX), '') +
						'LEFT OUTER HASH JOIN
						(
							SELECT TOP(@i)
								task_nodes.task_node.value(''(session_id/text())[1]'', ''SMALLINT'') AS session_id,
								task_nodes.task_node.value(''(request_id/text())[1]'', ''INT'') AS request_id,
								task_nodes.task_node.value(''(physical_io/text())[1]'', ''BIGINT'') AS physical_io,
								task_nodes.task_node.value(''(context_switches/text())[1]'', ''BIGINT'') AS context_switches,
								task_nodes.task_node.value(''(tasks/text())[1]'', ''INT'') AS tasks,
								task_nodes.task_node.value(''(block_info/text())[1]'', ''NVARCHAR(4000)'') AS block_info,
								task_nodes.task_node.value(''(waits/text())[1]'', ''NVARCHAR(4000)'') AS wait_info,
								task_nodes.task_node.value(''(thread_CPU_snapshot/text())[1]'', ''BIGINT'') AS thread_CPU_snapshot
							FROM
							(
								SELECT TOP(@i)
									CONVERT
									(
										XML,
										REPLACE
										(
											CONVERT(NVARCHAR(MAX), tasks_raw.task_xml_raw) COLLATE Latin1_General_Bin2,
											N''</waits></tasks><tasks><waits>'',
											N'', ''
										)
									) AS task_xml
								FROM
								(
									SELECT TOP(@i)
										CASE waits.r
											WHEN 1 THEN
												waits.session_id
											ELSE
												NULL
										END AS [session_id],
										CASE waits.r
											WHEN 1 THEN
												waits.request_id
											ELSE
												NULL
										END AS [request_id],											
										CASE waits.r
											WHEN 1 THEN
												waits.physical_io
											ELSE
												NULL
										END AS [physical_io],
										CASE waits.r
											WHEN 1 THEN
												waits.context_switches
											ELSE
												NULL
										END AS [context_switches],
										CASE waits.r
											WHEN 1 THEN
												waits.thread_CPU_snapshot
											ELSE
												NULL
										END AS [thread_CPU_snapshot],
										CASE waits.r
											WHEN 1 THEN
												waits.tasks
											ELSE
												NULL
										END AS [tasks],
										CASE waits.r
											WHEN 1 THEN
												waits.block_info
											ELSE
												NULL
										END AS [block_info],
										REPLACE
										(
											REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
											REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
											REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
												CONVERT
												(
													NVARCHAR(MAX),
													N''('' +
														CONVERT(NVARCHAR, num_waits) + N''x: '' +
														CASE num_waits
															WHEN 1 THEN
																CONVERT(NVARCHAR, min_wait_time) + N''ms''
															WHEN 2 THEN
																CASE
																	WHEN min_wait_time <> max_wait_time THEN
																		CONVERT(NVARCHAR, min_wait_time) + N''/'' + CONVERT(NVARCHAR, max_wait_time) + N''ms''
																	ELSE
																		CONVERT(NVARCHAR, max_wait_time) + N''ms''
																END
															ELSE
																CASE
																	WHEN min_wait_time <> max_wait_time THEN
																		CONVERT(NVARCHAR, min_wait_time) + N''/'' + CONVERT(NVARCHAR, avg_wait_time) + N''/'' + CONVERT(NVARCHAR, max_wait_time) + N''ms''
																	ELSE 
																		CONVERT(NVARCHAR, max_wait_time) + N''ms''
																END
														END +
													N'')'' + wait_type COLLATE Latin1_General_Bin2
												),
												NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''),
												NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''),
												NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''),
											NCHAR(0),
											N''''
										) AS [waits]
									FROM
									(
										SELECT TOP(@i)
											w1.*,
											ROW_NUMBER() OVER
											(
												PARTITION BY
													w1.session_id,
													w1.request_id
												ORDER BY
													w1.block_info DESC,
													w1.num_waits DESC,
													w1.wait_type
											) AS r
										FROM
										(
											SELECT TOP(@i)
												task_info.session_id,
												task_info.request_id,
												task_info.physical_io,
												task_info.context_switches,
												task_info.thread_CPU_snapshot,
												task_info.num_tasks AS tasks,
												CASE
													WHEN task_info.runnable_time IS NOT NULL THEN
														''RUNNABLE''
													ELSE
														wt2.wait_type
												END AS wait_type,
												NULLIF(COUNT(COALESCE(task_info.runnable_time, wt2.waiting_task_address)), 0) AS num_waits,
												MIN(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS min_wait_time,
												AVG(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS avg_wait_time,
												MAX(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS max_wait_time,
												MAX(wt2.block_info) AS block_info
											FROM
											(
												SELECT TOP(@i)
													t.session_id,
													t.request_id,
													SUM(CONVERT(BIGINT, t.pending_io_count)) OVER (PARTITION BY t.session_id, t.request_id) AS physical_io,
													SUM(CONVERT(BIGINT, t.context_switches_count)) OVER (PARTITION BY t.session_id, t.request_id) AS context_switches, 
													' +
													CASE
														WHEN @output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
															THEN
																'SUM(tr.usermode_time + tr.kernel_time) OVER (PARTITION BY t.session_id, t.request_id) '
														ELSE
															'CONVERT(BIGINT, NULL) '
													END + 
														' AS thread_CPU_snapshot, 
													COUNT(*) OVER (PARTITION BY t.session_id, t.request_id) AS num_tasks,
													t.task_address,
													t.task_state,
													CASE
														WHEN
															t.task_state = ''RUNNABLE''
															AND w.runnable_time > 0 THEN
																w.runnable_time
														ELSE
															NULL
													END AS runnable_time
												FROM sys.dm_os_tasks AS t
												CROSS APPLY
												(
													SELECT TOP(1)
														sp2.session_id
													FROM @sessions AS sp2
													WHERE
														sp2.session_id = t.session_id
														AND sp2.request_id = t.request_id
														AND sp2.status <> ''sleeping''
												) AS sp20
												LEFT OUTER HASH JOIN
												(
													SELECT TOP(@i)
														(
															SELECT TOP(@i)
																ms_ticks
															FROM sys.dm_os_sys_info
														) -
															w0.wait_resumed_ms_ticks AS runnable_time,
														w0.worker_address,
														w0.thread_address,
														w0.task_bound_ms_ticks
													FROM sys.dm_os_workers AS w0
													WHERE
														w0.state = ''RUNNABLE''
														OR @first_collection_ms_ticks >= w0.task_bound_ms_ticks
												) AS w ON
													w.worker_address = t.worker_address 
												' +
												CASE
													WHEN @output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
														THEN
															'LEFT OUTER HASH JOIN sys.dm_os_threads AS tr ON
																tr.thread_address = w.thread_address
																AND @first_collection_ms_ticks >= w.task_bound_ms_ticks
															'
													ELSE
														''
												END +
											') AS task_info
											LEFT OUTER HASH JOIN
											(
												SELECT TOP(@i)
													wt1.wait_type,
													wt1.waiting_task_address,
													MAX(wt1.wait_duration_ms) AS wait_duration_ms,
													MAX(wt1.block_info) AS block_info
												FROM
												(
													SELECT DISTINCT TOP(@i)
														wt.wait_type +
															CASE
																WHEN wt.wait_type LIKE N''PAGE%LATCH_%'' THEN
																	'':'' +
																	COALESCE(DB_NAME(CONVERT(INT, LEFT(wt.resource_description, CHARINDEX(N'':'', wt.resource_description) - 1))), N''(null)'') +
																	N'':'' +
																	SUBSTRING(wt.resource_description, CHARINDEX(N'':'', wt.resource_description) + 1, LEN(wt.resource_description) - CHARINDEX(N'':'', REVERSE(wt.resource_description)) - CHARINDEX(N'':'', wt.resource_description)) +
																	N''('' +
																		CASE
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 1 OR
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 8088 = 0
																					THEN 
																						N''PFS''
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 2 OR
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511232 = 0 
																					THEN 
																						N''GAM''
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 3 OR
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511233 = 0 
																					THEN 
																						N''SGAM''
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 6 OR
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511238 = 0 
																					THEN 
																						N''DCM''
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 7 OR
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511239 = 0
																					THEN 
																						N''BCM''
																			ELSE
																				N''*''
																		END +
																	N'')''
																WHEN wt.wait_type = N''CXPACKET'' THEN
																	N'':'' + SUBSTRING(wt.resource_description, CHARINDEX(N''nodeId'', wt.resource_description) + 7, 4)
																WHEN wt.wait_type LIKE N''LATCH[_]%'' THEN
																	N'' ['' + LEFT(wt.resource_description, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description), 0), LEN(wt.resource_description) + 1) - 1) + N'']''
																ELSE 
																	N''''
															END COLLATE Latin1_General_Bin2 AS wait_type,
														CASE
															WHEN
															(
																wt.blocking_session_id IS NOT NULL
																AND wt.wait_type LIKE N''LCK[_]%''
															) THEN
																(
																	SELECT TOP(@i)
																		x.lock_type,
																		REPLACE
																		(
																			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																				DB_NAME
																				(
																					CONVERT
																					(
																						INT,
																						SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''dbid='', wt.resource_description), 0) + 5, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''dbid='', wt.resource_description) + 5), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''dbid='', wt.resource_description) - 5)
																					)
																				),
																				NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''),
																				NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''),
																				NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''),
																			NCHAR(0),
																			N''''
																		) AS database_name,
																		CASE x.lock_type
																			WHEN N''objectlock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''objid='', wt.resource_description), 0) + 6, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''objid='', wt.resource_description) + 6), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''objid='', wt.resource_description) - 6)
																			ELSE
																				NULL
																		END AS object_id,
																		CASE x.lock_type
																			WHEN N''filelock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''fileid='', wt.resource_description), 0) + 7, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''fileid='', wt.resource_description) + 7), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''fileid='', wt.resource_description) - 7)
																			ELSE
																				NULL
																		END AS file_id,
																		CASE
																			WHEN x.lock_type in (N''pagelock'', N''extentlock'', N''ridlock'') THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''associatedObjectId='', wt.resource_description), 0) + 19, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''associatedObjectId='', wt.resource_description) + 19), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''associatedObjectId='', wt.resource_description) - 19)
																			WHEN x.lock_type in (N''keylock'', N''hobtlock'', N''allocunitlock'') THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''hobtid='', wt.resource_description), 0) + 7, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''hobtid='', wt.resource_description) + 7), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''hobtid='', wt.resource_description) - 7)
																			ELSE
																				NULL
																		END AS hobt_id,
																		CASE x.lock_type
																			WHEN N''applicationlock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''hash='', wt.resource_description), 0) + 5, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''hash='', wt.resource_description) + 5), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''hash='', wt.resource_description) - 5)
																			ELSE
																				NULL
																		END AS applock_hash,
																		CASE x.lock_type
																			WHEN N''metadatalock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''subresource='', wt.resource_description), 0) + 12, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''subresource='', wt.resource_description) + 12), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''subresource='', wt.resource_description) - 12)
																			ELSE
																				NULL
																		END AS metadata_resource,
																		CASE x.lock_type
																			WHEN N''metadatalock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''classid='', wt.resource_description), 0) + 8, COALESCE(NULLIF(CHARINDEX(N'' dbid='', wt.resource_description) - CHARINDEX(N''classid='', wt.resource_description), 0), LEN(wt.resource_description) + 1) - 8)
																			ELSE
																				NULL
																		END AS metadata_class_id
																	FROM
																	(
																		SELECT TOP(1)
																			LEFT(wt.resource_description, CHARINDEX(N'' '', wt.resource_description) - 1) COLLATE Latin1_General_Bin2 AS lock_type
																	) AS x
																	FOR XML
																		PATH('''')
																)
															ELSE NULL
														END AS block_info,
														wt.wait_duration_ms,
														wt.waiting_task_address
													FROM
													(
														SELECT TOP(@i)
															wt0.wait_type COLLATE Latin1_General_Bin2 AS wait_type,
															wt0.resource_description COLLATE Latin1_General_Bin2 AS resource_description,
															wt0.wait_duration_ms,
															wt0.waiting_task_address,
															CASE
																WHEN wt0.blocking_session_id = p.blocked THEN
																	wt0.blocking_session_id
																ELSE
																	NULL
															END AS blocking_session_id
														FROM sys.dm_os_waiting_tasks AS wt0
														CROSS APPLY
														(
															SELECT TOP(1)
																s0.blocked
															FROM @sessions AS s0
															WHERE
																s0.session_id = wt0.session_id
																AND COALESCE(s0.wait_type, N'''') <> N''OLEDB''
																AND wt0.wait_type <> N''OLEDB''
														) AS p
													) AS wt
												) AS wt1
												GROUP BY
													wt1.wait_type,
													wt1.waiting_task_address
											) AS wt2 ON
												wt2.waiting_task_address = task_info.task_address
												AND wt2.wait_duration_ms > 0
												AND task_info.runnable_time IS NULL
											GROUP BY
												task_info.session_id,
												task_info.request_id,
												task_info.physical_io,
												task_info.context_switches,
												task_info.thread_CPU_snapshot,
												task_info.num_tasks,
												CASE
													WHEN task_info.runnable_time IS NOT NULL THEN
														''RUNNABLE''
													ELSE
														wt2.wait_type
												END
										) AS w1
									) AS waits
									ORDER BY
										waits.session_id,
										waits.request_id,
										waits.r
									FOR XML
										PATH(N''tasks''),
										TYPE
								) AS tasks_raw (task_xml_raw)
							) AS tasks_final
							CROSS APPLY tasks_final.task_xml.nodes(N''/tasks'') AS task_nodes (task_node)
							WHERE
								task_nodes.task_node.exist(N''session_id'') = 1
						) AS tasks ON
							tasks.session_id = y.session_id
							AND tasks.request_id = y.request_id 
						'
					ELSE
						''
				END +
				'LEFT OUTER HASH JOIN
				(
					SELECT TOP(@i)
						t_info.session_id,
						COALESCE(t_info.request_id, -1) AS request_id,
						SUM(t_info.tempdb_allocations) AS tempdb_allocations,
						SUM(t_info.tempdb_current) AS tempdb_current
					FROM
					(
						SELECT TOP(@i)
							tsu.session_id,
							tsu.request_id,
							tsu.user_objects_alloc_page_count +
								tsu.internal_objects_alloc_page_count AS tempdb_allocations,
							tsu.user_objects_alloc_page_count +
								tsu.internal_objects_alloc_page_count -
								tsu.user_objects_dealloc_page_count -
								tsu.internal_objects_dealloc_page_count AS tempdb_current
						FROM sys.dm_db_task_space_usage AS tsu
						CROSS APPLY
						(
							SELECT TOP(1)
								s0.session_id
							FROM @sessions AS s0
							WHERE
								s0.session_id = tsu.session_id
						) AS p

						UNION ALL

						SELECT TOP(@i)
							ssu.session_id,
							NULL AS request_id,
							ssu.user_objects_alloc_page_count +
								ssu.internal_objects_alloc_page_count AS tempdb_allocations,
							ssu.user_objects_alloc_page_count +
								ssu.internal_objects_alloc_page_count -
								ssu.user_objects_dealloc_page_count -
								ssu.internal_objects_dealloc_page_count AS tempdb_current
						FROM sys.dm_db_session_space_usage AS ssu
						CROSS APPLY
						(
							SELECT TOP(1)
								s0.session_id
							FROM @sessions AS s0
							WHERE
								s0.session_id = ssu.session_id
						) AS p
					) AS t_info
					GROUP BY
						t_info.session_id,
						COALESCE(t_info.request_id, -1)
				) AS tempdb_info ON
					tempdb_info.session_id = y.session_id
					AND tempdb_info.request_id =
						CASE
							WHEN y.status = N''sleeping'' THEN
								-1
							ELSE
								y.request_id
						END
				' +
				CASE 
					WHEN 
						NOT 
						(
							@get_avg_time = 1 
							AND @recursion = 1
						) THEN 
							''
					ELSE
						'LEFT OUTER HASH JOIN
						(
							SELECT TOP(@i)
								*
							FROM sys.dm_exec_query_stats
						) AS qs ON
							qs.sql_handle = y.sql_handle
							AND qs.plan_handle = y.plan_handle
							AND qs.statement_start_offset = y.statement_start_offset
							AND qs.statement_end_offset = y.statement_end_offset
						'
				END + 
			') AS x
			OPTION (KEEPFIXED PLAN, OPTIMIZE FOR (@i = 1)); ';

		SET @sql_n = CONVERT(NVARCHAR(MAX), @sql);

		SET @last_collection_start = GETDATE();

		IF @recursion = -1
		BEGIN;
			SELECT
				@first_collection_ms_ticks = ms_ticks
			FROM sys.dm_os_sys_info;
		END;

		INSERT #sessions
		(
			recursion,
			session_id,
			request_id,
			session_number,
			elapsed_time,
			avg_elapsed_time,
			physical_io,
			reads,
			physical_reads,
			writes,
			tempdb_allocations,
			tempdb_current,
			CPU,
			thread_CPU_snapshot,
			context_switches,
			used_memory,
			tasks,
			status,
			wait_info,
			transaction_id,
			open_tran_count,
			sql_handle,
			statement_start_offset,
			statement_end_offset,		
			sql_text,
			plan_handle,
			blocking_session_id,
			percent_complete,
			host_name,
			login_name,
			database_name,
			program_name,
			additional_info,
			start_time,
			login_time,
			last_request_start_time
		)
		EXEC sp_executesql 
			@sql_n,
			N'@recursion SMALLINT, @filter sysname, @not_filter sysname, @first_collection_ms_ticks BIGINT',
			@recursion, @filter, @not_filter, @first_collection_ms_ticks;

		--Collect transaction information?
		IF
			@recursion = 1
			AND
			(
				@output_column_list LIKE '%|[tran_start_time|]%' ESCAPE '|'
				OR @output_column_list LIKE '%|[tran_log_writes|]%' ESCAPE '|' 
			)
		BEGIN;	
			DECLARE @i INT;
			SET @i = 2147483647;

			UPDATE s
			SET
				tran_start_time =
					CONVERT
					(
						DATETIME,
						LEFT
						(
							x.trans_info,
							NULLIF(CHARINDEX(NCHAR(254) COLLATE Latin1_General_Bin2, x.trans_info) - 1, -1)
						),
						121
					),
				tran_log_writes =
					RIGHT
					(
						x.trans_info,
						LEN(x.trans_info) - CHARINDEX(NCHAR(254) COLLATE Latin1_General_Bin2, x.trans_info)
					)
			FROM
			(
				SELECT TOP(@i)
					trans_nodes.trans_node.value('(session_id/text())[1]', 'SMALLINT') AS session_id,
					COALESCE(trans_nodes.trans_node.value('(request_id/text())[1]', 'INT'), 0) AS request_id,
					trans_nodes.trans_node.value('(trans_info/text())[1]', 'NVARCHAR(4000)') AS trans_info				
				FROM
				(
					SELECT TOP(@i)
						CONVERT
						(
							XML,
							REPLACE
							(
								CONVERT(NVARCHAR(MAX), trans_raw.trans_xml_raw) COLLATE Latin1_General_Bin2, 
								N'</trans_info></trans><trans><trans_info>', N''
							)
						)
					FROM
					(
						SELECT TOP(@i)
							CASE u_trans.r
								WHEN 1 THEN u_trans.session_id
								ELSE NULL
							END AS [session_id],
							CASE u_trans.r
								WHEN 1 THEN u_trans.request_id
								ELSE NULL
							END AS [request_id],
							CONVERT
							(
								NVARCHAR(MAX),
								CASE
									WHEN u_trans.database_id IS NOT NULL THEN
										CASE u_trans.r
											WHEN 1 THEN COALESCE(CONVERT(NVARCHAR, u_trans.transaction_start_time, 121) + NCHAR(254), N'')
											ELSE N''
										END + 
											REPLACE
											(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
													CONVERT(VARCHAR(128), COALESCE(DB_NAME(u_trans.database_id), N'(null)')),
													NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
													NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
													NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
												NCHAR(0),
												N'?'
											) +
											N': ' +
										CONVERT(NVARCHAR, u_trans.log_record_count) + N' (' + CONVERT(NVARCHAR, u_trans.log_kb_used) + N' kB)' +
										N','
									ELSE
										N'N/A,'
								END COLLATE Latin1_General_Bin2
							) AS [trans_info]
						FROM
						(
							SELECT TOP(@i)
								trans.*,
								ROW_NUMBER() OVER
								(
									PARTITION BY
										trans.session_id,
										trans.request_id
									ORDER BY
										trans.transaction_start_time DESC
								) AS r
							FROM
							(
								SELECT TOP(@i)
									session_tran_map.session_id,
									session_tran_map.request_id,
									s_tran.database_id,
									COALESCE(SUM(s_tran.database_transaction_log_record_count), 0) AS log_record_count,
									COALESCE(SUM(s_tran.database_transaction_log_bytes_used), 0) / 1024 AS log_kb_used,
									MIN(s_tran.database_transaction_begin_time) AS transaction_start_time
								FROM
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_active_transactions
									WHERE
										transaction_begin_time <= @last_collection_start
								) AS a_tran
								INNER HASH JOIN
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_database_transactions
									WHERE
										database_id < 32767
								) AS s_tran ON
									s_tran.transaction_id = a_tran.transaction_id
								LEFT OUTER HASH JOIN
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_session_transactions
								) AS tst ON
									s_tran.transaction_id = tst.transaction_id
								CROSS APPLY
								(
									SELECT TOP(1)
										s3.session_id,
										s3.request_id
									FROM
									(
										SELECT TOP(1)
											s1.session_id,
											s1.request_id
										FROM #sessions AS s1
										WHERE
											s1.transaction_id = s_tran.transaction_id
											AND s1.recursion = 1
											
										UNION ALL
									
										SELECT TOP(1)
											s2.session_id,
											s2.request_id
										FROM #sessions AS s2
										WHERE
											s2.session_id = tst.session_id
											AND s2.recursion = 1
									) AS s3
									ORDER BY
										s3.request_id
								) AS session_tran_map
								GROUP BY
									session_tran_map.session_id,
									session_tran_map.request_id,
									s_tran.database_id
							) AS trans
						) AS u_trans
						FOR XML
							PATH('trans'),
							TYPE
					) AS trans_raw (trans_xml_raw)
				) AS trans_final (trans_xml)
				CROSS APPLY trans_final.trans_xml.nodes('/trans') AS trans_nodes (trans_node)
			) AS x
			INNER HASH JOIN #sessions AS s ON
				s.session_id = x.session_id
				AND s.request_id = x.request_id
			OPTION (OPTIMIZE FOR (@i = 1));
		END;

		--Variables for text and plan collection
		DECLARE	
			@session_id SMALLINT,
			@request_id INT,
			@sql_handle VARBINARY(64),
			@plan_handle VARBINARY(64),
			@statement_start_offset INT,
			@statement_end_offset INT,
			@start_time DATETIME,
			@database_name sysname;

		IF 
			@recursion = 1
			AND @output_column_list LIKE '%|[sql_text|]%' ESCAPE '|'
		BEGIN;
			DECLARE sql_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT 
					session_id,
					request_id,
					sql_handle,
					statement_start_offset,
					statement_end_offset
				FROM #sessions
				WHERE
					recursion = 1
					AND sql_handle IS NOT NULL
			OPTION (KEEPFIXED PLAN);

			OPEN sql_cursor;

			FETCH NEXT FROM sql_cursor
			INTO 
				@session_id,
				@request_id,
				@sql_handle,
				@statement_start_offset,
				@statement_end_offset;

			--Wait up to 5 ms for the SQL text, then give up
			SET LOCK_TIMEOUT 5;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					UPDATE s
					SET
						s.sql_text =
						(
							SELECT
								REPLACE
								(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
										N'--' + NCHAR(13) + NCHAR(10) +
										CASE 
											WHEN @get_full_inner_text = 1 THEN est.text
											WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN est.text
											WHEN SUBSTRING(est.text, (@statement_start_offset/2), 2) LIKE N'[a-zA-Z0-9][a-zA-Z0-9]' THEN est.text
											ELSE
												CASE
													WHEN @statement_start_offset > 0 THEN
														SUBSTRING
														(
															est.text,
															((@statement_start_offset/2) + 1),
															(
																CASE
																	WHEN @statement_end_offset = -1 THEN 2147483647
																	ELSE ((@statement_end_offset - @statement_start_offset)/2) + 1
																END
															)
														)
													ELSE RTRIM(LTRIM(est.text))
												END
										END +
										NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2,
										NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
										NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
										NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
									NCHAR(0),
									N''
								) AS [processing-instruction(query)]
							FOR XML
								PATH(''),
								TYPE
						),
						s.statement_start_offset = 
							CASE 
								WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN 0
								WHEN SUBSTRING(CONVERT(VARCHAR(MAX), est.text), (@statement_start_offset/2), 2) LIKE '[a-zA-Z0-9][a-zA-Z0-9]' THEN 0
								ELSE @statement_start_offset
							END,
						s.statement_end_offset = 
							CASE 
								WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN -1
								WHEN SUBSTRING(CONVERT(VARCHAR(MAX), est.text), (@statement_start_offset/2), 2) LIKE '[a-zA-Z0-9][a-zA-Z0-9]' THEN -1
								ELSE @statement_end_offset
							END
					FROM 
						#sessions AS s,
						(
							SELECT TOP(1)
								text
							FROM
							(
								SELECT 
									text, 
									0 AS row_num
								FROM sys.dm_exec_sql_text(@sql_handle)
								
								UNION ALL
								
								SELECT 
									NULL,
									1 AS row_num
							) AS est0
							ORDER BY
								row_num
						) AS est
					WHERE 
						s.session_id = @session_id
						AND s.request_id = @request_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END TRY
				BEGIN CATCH;
					UPDATE s
					SET
						s.sql_text = 
							CASE ERROR_NUMBER() 
								WHEN 1222 THEN '<timeout_exceeded />'
								ELSE '<error message="' + ERROR_MESSAGE() + '" />'
							END
					FROM #sessions AS s
					WHERE 
						s.session_id = @session_id
						AND s.request_id = @request_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END CATCH;

				FETCH NEXT FROM sql_cursor
				INTO
					@session_id,
					@request_id,
					@sql_handle,
					@statement_start_offset,
					@statement_end_offset;
			END;

			--Return this to the default
			SET LOCK_TIMEOUT -1;

			CLOSE sql_cursor;
			DEALLOCATE sql_cursor;
		END;

		IF 
			@get_outer_command = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[sql_command|]%' ESCAPE '|'
		BEGIN;
			DECLARE @buffer_results TABLE
			(
				EventType VARCHAR(30),
				Parameters INT,
				EventInfo NVARCHAR(4000),
				start_time DATETIME,
				session_number INT IDENTITY(1,1) NOT NULL PRIMARY KEY
			);

			DECLARE buffer_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT 
					session_id,
					MAX(start_time) AS start_time
				FROM #sessions
				WHERE
					recursion = 1
				GROUP BY
					session_id
				ORDER BY
					session_id
				OPTION (KEEPFIXED PLAN);

			OPEN buffer_cursor;

			FETCH NEXT FROM buffer_cursor
			INTO 
				@session_id,
				@start_time;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					--In SQL Server 2008, DBCC INPUTBUFFER will throw 
					--an exception if the session no longer exists
					INSERT @buffer_results
					(
						EventType,
						Parameters,
						EventInfo
					)
					EXEC sp_executesql
						N'DBCC INPUTBUFFER(@session_id) WITH NO_INFOMSGS;',
						N'@session_id SMALLINT',
						@session_id;

					UPDATE br
					SET
						br.start_time = @start_time
					FROM @buffer_results AS br
					WHERE
						br.session_number = 
						(
							SELECT MAX(br2.session_number)
							FROM @buffer_results br2
						);
				END TRY
				BEGIN CATCH
				END CATCH;

				FETCH NEXT FROM buffer_cursor
				INTO 
					@session_id,
					@start_time;
			END;

			UPDATE s
			SET
				sql_command = 
				(
					SELECT 
						REPLACE
						(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								CONVERT
								(
									NVARCHAR(MAX),
									N'--' + NCHAR(13) + NCHAR(10) + br.EventInfo + NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2
								),
								NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
								NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
								NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
							NCHAR(0),
							N''
						) AS [processing-instruction(query)]
					FROM @buffer_results AS br
					WHERE 
						br.session_number = s.session_number
						AND br.start_time = s.start_time
						AND 
						(
							(
								s.start_time = s.last_request_start_time
								AND EXISTS
								(
									SELECT *
									FROM sys.dm_exec_requests r2
									WHERE
										r2.session_id = s.session_id
										AND r2.request_id = s.request_id
										AND r2.start_time = s.start_time
								)
							)
							OR 
							(
								s.request_id = 0
								AND EXISTS
								(
									SELECT *
									FROM sys.dm_exec_sessions s2
									WHERE
										s2.session_id = s.session_id
										AND s2.last_request_start_time = s.last_request_start_time
								)
							)
						)
					FOR XML
						PATH(''),
						TYPE
				)
			FROM #sessions AS s
			WHERE
				recursion = 1
			OPTION (KEEPFIXED PLAN);

			CLOSE buffer_cursor;
			DEALLOCATE buffer_cursor;
		END;

		IF 
			@get_plans >= 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|'
		BEGIN;
			DECLARE plan_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT
					session_id,
					request_id,
					plan_handle,
					statement_start_offset,
					statement_end_offset
				FROM #sessions
				WHERE
					recursion = 1
					AND plan_handle IS NOT NULL
			OPTION (KEEPFIXED PLAN);

			OPEN plan_cursor;

			FETCH NEXT FROM plan_cursor
			INTO 
				@session_id,
				@request_id,
				@plan_handle,
				@statement_start_offset,
				@statement_end_offset;

			--Wait up to 5 ms for a query plan, then give up
			SET LOCK_TIMEOUT 5;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					UPDATE s
					SET
						s.query_plan =
						(
							SELECT
								CONVERT(xml, query_plan)
							FROM sys.dm_exec_text_query_plan
							(
								@plan_handle, 
								CASE @get_plans
									WHEN 1 THEN
										@statement_start_offset
									ELSE
										0
								END, 
								CASE @get_plans
									WHEN 1 THEN
										@statement_end_offset
									ELSE
										-1
								END
							)
						)
					FROM #sessions AS s
					WHERE 
						s.session_id = @session_id
						AND s.request_id = @request_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END TRY
				BEGIN CATCH;
					IF ERROR_NUMBER() = 6335
					BEGIN;
						UPDATE s
						SET
							s.query_plan =
							(
								SELECT
									N'--' + NCHAR(13) + NCHAR(10) + 
									N'-- Could not render showplan due to XML data type limitations. ' + NCHAR(13) + NCHAR(10) + 
									N'-- To see the graphical plan save the XML below as a .SQLPLAN file and re-open in SSMS.' + NCHAR(13) + NCHAR(10) +
									N'--' + NCHAR(13) + NCHAR(10) +
										REPLACE(qp.query_plan, N'<RelOp', NCHAR(13)+NCHAR(10)+N'<RelOp') + 
										NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2 AS [processing-instruction(query_plan)]
								FROM sys.dm_exec_text_query_plan
								(
									@plan_handle, 
									CASE @get_plans
										WHEN 1 THEN
											@statement_start_offset
										ELSE
											0
									END, 
									CASE @get_plans
										WHEN 1 THEN
											@statement_end_offset
										ELSE
											-1
									END
								) AS qp
								FOR XML
									PATH(''),
									TYPE
							)
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
							AND s.request_id = @request_id
							AND s.recursion = 1
						OPTION (KEEPFIXED PLAN);
					END;
					ELSE
					BEGIN;
						UPDATE s
						SET
							s.query_plan = 
								CASE ERROR_NUMBER() 
									WHEN 1222 THEN '<timeout_exceeded />'
									ELSE '<error message="' + ERROR_MESSAGE() + '" />'
								END
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
							AND s.request_id = @request_id
							AND s.recursion = 1
						OPTION (KEEPFIXED PLAN);
					END;
				END CATCH;

				FETCH NEXT FROM plan_cursor
				INTO
					@session_id,
					@request_id,
					@plan_handle,
					@statement_start_offset,
					@statement_end_offset;
			END;

			--Return this to the default
			SET LOCK_TIMEOUT -1;

			CLOSE plan_cursor;
			DEALLOCATE plan_cursor;
		END;

		IF 
			@get_locks = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[locks|]%' ESCAPE '|'
		BEGIN;
			DECLARE locks_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT DISTINCT
					database_name
				FROM #locks
				WHERE
					EXISTS
					(
						SELECT *
						FROM #sessions AS s
						WHERE
							s.session_id = #locks.session_id
							AND recursion = 1
					)
					AND database_name <> '(null)'
				OPTION (KEEPFIXED PLAN);

			OPEN locks_cursor;

			FETCH NEXT FROM locks_cursor
			INTO 
				@database_name;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					SET @sql_n = CONVERT(NVARCHAR(MAX), '') +
						'UPDATE l ' +
						'SET ' +
							'object_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'o.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'index_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'i.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'schema_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										's.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'principal_name = ' + 
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'dp.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								') ' +
						'FROM #locks AS l ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.allocation_units AS au ON ' +
							'au.allocation_unit_id = l.allocation_unit_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p ON ' +
							'p.hobt_id = ' +
								'COALESCE ' +
								'( ' +
									'l.hobt_id, ' +
									'CASE ' +
										'WHEN au.type IN (1, 3) THEN au.container_id ' +
										'ELSE NULL ' +
									'END ' +
								') ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p1 ON ' +
							'l.hobt_id IS NULL ' +
							'AND au.type = 2 ' +
							'AND p1.partition_id = au.container_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS o ON ' +
							'o.object_id = COALESCE(l.object_id, p.object_id, p1.object_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.indexes AS i ON ' +
							'i.object_id = COALESCE(l.object_id, p.object_id, p1.object_id) ' +
							'AND i.index_id = COALESCE(l.index_id, p.index_id, p1.index_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.schemas AS s ON ' +
							's.schema_id = COALESCE(l.schema_id, o.schema_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.database_principals AS dp ON ' +
							'dp.principal_id = l.principal_id ' +
						'WHERE ' +
							'l.database_name = @database_name ' +
						'OPTION (KEEPFIXED PLAN); ';
					
					EXEC sp_executesql
						@sql_n,
						N'@database_name sysname',
						@database_name;
				END TRY
				BEGIN CATCH;
					UPDATE #locks
					SET
						query_error = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									CONVERT
									(
										NVARCHAR(MAX), 
										ERROR_MESSAGE() COLLATE Latin1_General_Bin2
									),
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N''
							)
					WHERE 
						database_name = @database_name
					OPTION (KEEPFIXED PLAN);
				END CATCH;

				FETCH NEXT FROM locks_cursor
				INTO
					@database_name;
			END;

			CLOSE locks_cursor;
			DEALLOCATE locks_cursor;

			CREATE CLUSTERED INDEX IX_SRD ON #locks (session_id, request_id, database_name);

			UPDATE s
			SET 
				s.locks =
				(
					SELECT 
						REPLACE
						(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								CONVERT
								(
									NVARCHAR(MAX), 
									l1.database_name COLLATE Latin1_General_Bin2
								),
								NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
								NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
								NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
							NCHAR(0),
							N''
						) AS [Database/@name],
						MIN(l1.query_error) AS [Database/@query_error],
						(
							SELECT 
								l2.request_mode AS [Lock/@request_mode],
								l2.request_status AS [Lock/@request_status],
								COUNT(*) AS [Lock/@request_count]
							FROM #locks AS l2
							WHERE 
								l1.session_id = l2.session_id
								AND l1.request_id = l2.request_id
								AND l2.database_name = l1.database_name
								AND l2.resource_type = 'DATABASE'
							GROUP BY
								l2.request_mode,
								l2.request_status
							FOR XML
								PATH(''),
								TYPE
						) AS [Database/Locks],
						(
							SELECT
								COALESCE(l3.object_name, '(null)') AS [Object/@name],
								l3.schema_name AS [Object/@schema_name],
								(
									SELECT
										l4.resource_type AS [Lock/@resource_type],
										l4.page_type AS [Lock/@page_type],
										l4.index_name AS [Lock/@index_name],
										CASE 
											WHEN l4.object_name IS NULL THEN l4.schema_name
											ELSE NULL
										END AS [Lock/@schema_name],
										l4.principal_name AS [Lock/@principal_name],
										l4.resource_description AS [Lock/@resource_description],
										l4.request_mode AS [Lock/@request_mode],
										l4.request_status AS [Lock/@request_status],
										SUM(l4.request_count) AS [Lock/@request_count]
									FROM #locks AS l4
									WHERE 
										l4.session_id = l3.session_id
										AND l4.request_id = l3.request_id
										AND l3.database_name = l4.database_name
										AND COALESCE(l3.object_name, '(null)') = COALESCE(l4.object_name, '(null)')
										AND COALESCE(l3.schema_name, '') = COALESCE(l4.schema_name, '')
										AND l4.resource_type <> 'DATABASE'
									GROUP BY
										l4.resource_type,
										l4.page_type,
										l4.index_name,
										CASE 
											WHEN l4.object_name IS NULL THEN l4.schema_name
											ELSE NULL
										END,
										l4.principal_name,
										l4.resource_description,
										l4.request_mode,
										l4.request_status
									FOR XML
										PATH(''),
										TYPE
								) AS [Object/Locks]
							FROM #locks AS l3
							WHERE 
								l3.session_id = l1.session_id
								AND l3.request_id = l1.request_id
								AND l3.database_name = l1.database_name
								AND l3.resource_type <> 'DATABASE'
							GROUP BY 
								l3.session_id,
								l3.request_id,
								l3.database_name,
								COALESCE(l3.object_name, '(null)'),
								l3.schema_name
							FOR XML
								PATH(''),
								TYPE
						) AS [Database/Objects]
					FROM #locks AS l1
					WHERE
						l1.session_id = s.session_id
						AND l1.request_id = s.request_id
						AND l1.start_time IN (s.start_time, s.last_request_start_time)
						AND s.recursion = 1
					GROUP BY 
						l1.session_id,
						l1.request_id,
						l1.database_name
					FOR XML
						PATH(''),
						TYPE
				)
			FROM #sessions s
			OPTION (KEEPFIXED PLAN);
		END;

		IF 
			@find_block_leaders = 1
			AND @recursion = 1
			AND @output_column_list LIKE '%|[blocked_session_count|]%' ESCAPE '|'
		BEGIN;
			WITH
			blockers AS
			(
				SELECT
					session_id,
					session_id AS top_level_session_id
				FROM #sessions
				WHERE
					recursion = 1

				UNION ALL

				SELECT
					s.session_id,
					b.top_level_session_id
				FROM blockers AS b
				JOIN #sessions AS s ON
					s.blocking_session_id = b.session_id
					AND s.recursion = 1
			)
			UPDATE s
			SET
				s.blocked_session_count = x.blocked_session_count
			FROM #sessions AS s
			JOIN
			(
				SELECT
					b.top_level_session_id AS session_id,
					COUNT(*) - 1 AS blocked_session_count
				FROM blockers AS b
				GROUP BY
					b.top_level_session_id
			) x ON
				s.session_id = x.session_id
			WHERE
				s.recursion = 1;
		END;

		IF
			@get_task_info = 2
			AND @output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
			AND @recursion = 1
		BEGIN;
			CREATE TABLE #blocked_requests
			(
				session_id SMALLINT NOT NULL,
				request_id INT NOT NULL,
				database_name sysname NOT NULL,
				object_id INT,
				hobt_id BIGINT,
				schema_id INT,
				schema_name sysname NULL,
				object_name sysname NULL,
				query_error NVARCHAR(2048),
				PRIMARY KEY (database_name, session_id, request_id)
			);

			CREATE STATISTICS s_database_name ON #blocked_requests (database_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_name ON #blocked_requests (schema_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_name ON #blocked_requests (object_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_query_error ON #blocked_requests (query_error)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
		
			INSERT #blocked_requests
			(
				session_id,
				request_id,
				database_name,
				object_id,
				hobt_id,
				schema_id
			)
			SELECT
				session_id,
				request_id,
				database_name,
				object_id,
				hobt_id,
				CONVERT(INT, SUBSTRING(schema_node, CHARINDEX(' = ', schema_node) + 3, LEN(schema_node))) AS schema_id
			FROM
			(
				SELECT
					session_id,
					request_id,
					agent_nodes.agent_node.value('(database_name/text())[1]', 'sysname') AS database_name,
					agent_nodes.agent_node.value('(object_id/text())[1]', 'int') AS object_id,
					agent_nodes.agent_node.value('(hobt_id/text())[1]', 'bigint') AS hobt_id,
					agent_nodes.agent_node.value('(metadata_resource/text()[.="SCHEMA"]/../../metadata_class_id/text())[1]', 'varchar(100)') AS schema_node
				FROM #sessions AS s
				CROSS APPLY s.additional_info.nodes('//block_info') AS agent_nodes (agent_node)
				WHERE
					s.recursion = 1
			) AS t
			WHERE
				t.database_name IS NOT NULL
				AND
				(
					t.object_id IS NOT NULL
					OR t.hobt_id IS NOT NULL
					OR t.schema_node IS NOT NULL
				);
			
			DECLARE blocks_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR
				SELECT DISTINCT
					database_name
				FROM #blocked_requests;
				
			OPEN blocks_cursor;
			
			FETCH NEXT FROM blocks_cursor
			INTO 
				@database_name;
			
			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					SET @sql_n = 
						CONVERT(NVARCHAR(MAX), '') +
						'UPDATE b ' +
						'SET ' +
							'b.schema_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										's.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'b.object_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'o.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								') ' +
						'FROM #blocked_requests AS b ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p ON ' +
							'p.hobt_id = b.hobt_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS o ON ' +
							'o.object_id = COALESCE(p.object_id, b.object_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.schemas AS s ON ' +
							's.schema_id = COALESCE(o.schema_id, b.schema_id) ' +
						'WHERE ' +
							'b.database_name = @database_name; ';
					
					EXEC sp_executesql
						@sql_n,
						N'@database_name sysname',
						@database_name;
				END TRY
				BEGIN CATCH;
					UPDATE #blocked_requests
					SET
						query_error = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									CONVERT
									(
										NVARCHAR(MAX), 
										ERROR_MESSAGE() COLLATE Latin1_General_Bin2
									),
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N''
							)
					WHERE
						database_name = @database_name;
				END CATCH;

				FETCH NEXT FROM blocks_cursor
				INTO
					@database_name;
			END;
			
			CLOSE blocks_cursor;
			DEALLOCATE blocks_cursor;
			
			UPDATE s
			SET
				additional_info.modify
				('
					insert <schema_name>{sql:column("b.schema_name")}</schema_name>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.schema_name IS NOT NULL;

			UPDATE s
			SET
				additional_info.modify
				('
					insert <object_name>{sql:column("b.object_name")}</object_name>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.object_name IS NOT NULL;

			UPDATE s
			SET
				additional_info.modify
				('
					insert <query_error>{sql:column("b.query_error")}</query_error>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.query_error IS NOT NULL;
		END;

		IF
			@output_column_list LIKE '%|[program_name|]%' ESCAPE '|'
			AND @output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
			AND @recursion = 1
		BEGIN;
			DECLARE @job_id UNIQUEIDENTIFIER;
			DECLARE @step_id INT;

			DECLARE agent_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT
					s.session_id,
					agent_nodes.agent_node.value('(job_id/text())[1]', 'uniqueidentifier') AS job_id,
					agent_nodes.agent_node.value('(step_id/text())[1]', 'int') AS step_id
				FROM #sessions AS s
				CROSS APPLY s.additional_info.nodes('//agent_job_info') AS agent_nodes (agent_node)
				WHERE
					s.recursion = 1
			OPTION (KEEPFIXED PLAN);
			
			OPEN agent_cursor;

			FETCH NEXT FROM agent_cursor
			INTO 
				@session_id,
				@job_id,
				@step_id;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					DECLARE @job_name sysname;
					SET @job_name = NULL;
					DECLARE @step_name sysname;
					SET @step_name = NULL;
					
					SELECT
						@job_name = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									j.name,
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N'?'
							),
						@step_name = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									s.step_name,
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N'?'
							)
					FROM msdb.dbo.sysjobs AS j
					INNER JOIN msdb..sysjobsteps AS s ON
						j.job_id = s.job_id
					WHERE
						j.job_id = @job_id
						AND s.step_id = @step_id;

					IF @job_name IS NOT NULL
					BEGIN;
						UPDATE s
						SET
							additional_info.modify
							('
								insert text{sql:variable("@job_name")}
								into (/additional_info/agent_job_info/job_name)[1]
							')
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
						OPTION (KEEPFIXED PLAN);
						
						UPDATE s
						SET
							additional_info.modify
							('
								insert text{sql:variable("@step_name")}
								into (/additional_info/agent_job_info/step_name)[1]
							')
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
						OPTION (KEEPFIXED PLAN);
					END;
				END TRY
				BEGIN CATCH;
					DECLARE @msdb_error_message NVARCHAR(256);
					SET @msdb_error_message = ERROR_MESSAGE();
				
					UPDATE s
					SET
						additional_info.modify
						('
							insert <msdb_query_error>{sql:variable("@msdb_error_message")}</msdb_query_error>
							as last
							into (/additional_info/agent_job_info)[1]
						')
					FROM #sessions AS s
					WHERE 
						s.session_id = @session_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END CATCH;

				FETCH NEXT FROM agent_cursor
				INTO 
					@session_id,
					@job_id,
					@step_id;
			END;

			CLOSE agent_cursor;
			DEALLOCATE agent_cursor;
		END; 
		
		IF 
			@delta_interval > 0 
			AND @recursion <> 1
		BEGIN;
			SET @recursion = 1;

			DECLARE @delay_time CHAR(12);
			SET @delay_time = CONVERT(VARCHAR, DATEADD(second, @delta_interval, 0), 114);
			WAITFOR DELAY @delay_time;

			GOTO REDO;
		END;
	END;

	SET @sql = 
		--Outer column list
		CONVERT
		(
			VARCHAR(MAX),
			CASE
				WHEN 
					@destination_table <> '' 
					AND @return_schema = 0 
						THEN 'INSERT ' + @destination_table + ' '
				ELSE ''
			END +
			'SELECT ' +
				@output_column_list + ' ' +
			CASE @return_schema
				WHEN 1 THEN 'INTO #session_schema '
				ELSE ''
			END
		--End outer column list
		) + 
		--Inner column list
		CONVERT
		(
			VARCHAR(MAX),
			'FROM ' +
			'( ' +
				'SELECT ' +
					'session_id, ' +
					--[dd hh:mm:ss.mss]
					CASE
						WHEN @format_output IN (1, 2) THEN
							'CASE ' +
								'WHEN elapsed_time < 0 THEN ' +
									'RIGHT ' +
									'( ' +
										'REPLICATE(''0'', max_elapsed_length) + CONVERT(VARCHAR, (-1 * elapsed_time) / 86400), ' +
										'max_elapsed_length ' +
									') + ' +
										'RIGHT ' +
										'( ' +
											'CONVERT(VARCHAR, DATEADD(second, (-1 * elapsed_time), 0), 120), ' +
											'9 ' +
										') + ' +
										'''.000'' ' +
								'ELSE ' +
									'RIGHT ' +
									'( ' +
										'REPLICATE(''0'', max_elapsed_length) + CONVERT(VARCHAR, elapsed_time / 86400000), ' +
										'max_elapsed_length ' +
									') + ' +
										'RIGHT ' +
										'( ' +
											'CONVERT(VARCHAR, DATEADD(second, elapsed_time / 1000, 0), 120), ' +
											'9 ' +
										') + ' +
										'''.'' + ' + 
										'RIGHT(''000'' + CONVERT(VARCHAR, elapsed_time % 1000), 3) ' +
							'END AS [dd hh:mm:ss.mss], '
						ELSE
							''
					END +
					--[dd hh:mm:ss.mss (avg)] / avg_elapsed_time
					CASE 
						WHEN  @format_output IN (1, 2) THEN 
							'RIGHT ' +
							'( ' +
								'''00'' + CONVERT(VARCHAR, avg_elapsed_time / 86400000), ' +
								'2 ' +
							') + ' +
								'RIGHT ' +
								'( ' +
									'CONVERT(VARCHAR, DATEADD(second, avg_elapsed_time / 1000, 0), 120), ' +
									'9 ' +
								') + ' +
								'''.'' + ' +
								'RIGHT(''000'' + CONVERT(VARCHAR, avg_elapsed_time % 1000), 3) AS [dd hh:mm:ss.mss (avg)], '
						ELSE
							'avg_elapsed_time, '
					END +
					--physical_io
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_io))) OVER() - LEN(CONVERT(VARCHAR, physical_io))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io), 1), 19)) AS '
						ELSE ''
					END + 'physical_io, ' +
					--reads
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, reads))) OVER() - LEN(CONVERT(VARCHAR, reads))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads), 1), 19)) AS '
						ELSE ''
					END + 'reads, ' +
					--physical_reads
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_reads))) OVER() - LEN(CONVERT(VARCHAR, physical_reads))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads), 1), 19)) AS '
						ELSE ''
					END + 'physical_reads, ' +
					--writes
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, writes))) OVER() - LEN(CONVERT(VARCHAR, writes))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes), 1), 19)) AS '
						ELSE ''
					END + 'writes, ' +
					--tempdb_allocations
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_allocations))) OVER() - LEN(CONVERT(VARCHAR, tempdb_allocations))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations), 1), 19)) AS '
						ELSE ''
					END + 'tempdb_allocations, ' +
					--tempdb_current
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_current))) OVER() - LEN(CONVERT(VARCHAR, tempdb_current))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current), 1), 19)) AS '
						ELSE ''
					END + 'tempdb_current, ' +
					--CPU
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, CPU))) OVER() - LEN(CONVERT(VARCHAR, CPU))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU), 1), 19)) AS '
						ELSE ''
					END + 'CPU, ' +
					--context_switches
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, context_switches))) OVER() - LEN(CONVERT(VARCHAR, context_switches))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches), 1), 19)) AS '
						ELSE ''
					END + 'context_switches, ' +
					--used_memory
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, used_memory))) OVER() - LEN(CONVERT(VARCHAR, used_memory))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory), 1), 19)) AS '
						ELSE ''
					END + 'used_memory, ' +
					CASE
						WHEN @output_column_list LIKE '%|_delta|]%' ESCAPE '|' THEN
							--physical_io_delta			
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND physical_io_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_io_delta))) OVER() - LEN(CONVERT(VARCHAR, physical_io_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io_delta), 1), 19)) ' 
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io_delta), 1), 19)) '
											ELSE 'physical_io_delta '
										END +
								'ELSE NULL ' +
							'END AS physical_io_delta, ' +
							--reads_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND reads_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, reads_delta))) OVER() - LEN(CONVERT(VARCHAR, reads_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads_delta), 1), 19)) '
											ELSE 'reads_delta '
										END +
								'ELSE NULL ' +
							'END AS reads_delta, ' +
							--physical_reads_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND physical_reads_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_reads_delta))) OVER() - LEN(CONVERT(VARCHAR, physical_reads_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads_delta), 1), 19)) '
											ELSE 'physical_reads_delta '
										END + 
								'ELSE NULL ' +
							'END AS physical_reads_delta, ' +
							--writes_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND writes_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, writes_delta))) OVER() - LEN(CONVERT(VARCHAR, writes_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes_delta), 1), 19)) '
											ELSE 'writes_delta '
										END + 
								'ELSE NULL ' +
							'END AS writes_delta, ' +
							--tempdb_allocations_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND tempdb_allocations_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_allocations_delta))) OVER() - LEN(CONVERT(VARCHAR, tempdb_allocations_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations_delta), 1), 19)) '
											ELSE 'tempdb_allocations_delta '
										END + 
								'ELSE NULL ' +
							'END AS tempdb_allocations_delta, ' +
							--tempdb_current_delta
							--this is the only one that can (legitimately) go negative 
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_current_delta))) OVER() - LEN(CONVERT(VARCHAR, tempdb_current_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current_delta), 1), 19)) '
											ELSE 'tempdb_current_delta '
										END + 
								'ELSE NULL ' +
							'END AS tempdb_current_delta, ' +
							--CPU_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
										'THEN ' +
											'CASE ' +
												'WHEN ' +
													'thread_CPU_delta > CPU_delta ' +
													'AND thread_CPU_delta > 0 ' +
														'THEN ' +
															CASE @format_output
																WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, thread_CPU_delta + CPU_delta))) OVER() - LEN(CONVERT(VARCHAR, thread_CPU_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, thread_CPU_delta), 1), 19)) '
																WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, thread_CPU_delta), 1), 19)) '
																ELSE 'thread_CPU_delta '
															END + 
												'WHEN CPU_delta >= 0 THEN ' +
													CASE @format_output
														WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, thread_CPU_delta + CPU_delta))) OVER() - LEN(CONVERT(VARCHAR, CPU_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU_delta), 1), 19)) '
														WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU_delta), 1), 19)) '
														ELSE 'CPU_delta '
													END + 
												'ELSE NULL ' +
											'END ' +
								'ELSE ' +
									'NULL ' +
							'END AS CPU_delta, ' +
							--context_switches_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND context_switches_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, context_switches_delta))) OVER() - LEN(CONVERT(VARCHAR, context_switches_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches_delta), 1), 19)) '
											ELSE 'context_switches_delta '
										END + 
								'ELSE NULL ' +
							'END AS context_switches_delta, ' +
							--used_memory_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND used_memory_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, used_memory_delta))) OVER() - LEN(CONVERT(VARCHAR, used_memory_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory_delta), 1), 19)) '
											ELSE 'used_memory_delta '
										END + 
								'ELSE NULL ' +
							'END AS used_memory_delta, '
						ELSE ''
					END +
					--tasks
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tasks))) OVER() - LEN(CONVERT(VARCHAR, tasks))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tasks), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tasks), 1), 19)) '
						ELSE ''
					END + 'tasks, ' +
					'status, ' +
					'wait_info, ' +
					'locks, ' +
					'tran_start_time, ' +
					'LEFT(tran_log_writes, LEN(tran_log_writes) - 1) AS tran_log_writes, ' +
					--open_tran_count
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, open_tran_count))) OVER() - LEN(CONVERT(VARCHAR, open_tran_count))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, open_tran_count), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, open_tran_count), 1), 19)) AS '
						ELSE ''
					END + 'open_tran_count, ' +
					--sql_command
					CASE @format_output 
						WHEN 0 THEN 'REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), sql_command), ''<?query --''+CHAR(13)+CHAR(10), ''''), CHAR(13)+CHAR(10)+''--?>'', '''') AS '
						ELSE ''
					END + 'sql_command, ' +
					--sql_text
					CASE @format_output 
						WHEN 0 THEN 'REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), sql_text), ''<?query --''+CHAR(13)+CHAR(10), ''''), CHAR(13)+CHAR(10)+''--?>'', '''') AS '
						ELSE ''
					END + 'sql_text, ' +
					'query_plan, ' +
					'blocking_session_id, ' +
					--blocked_session_count
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, blocked_session_count))) OVER() - LEN(CONVERT(VARCHAR, blocked_session_count))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1), 19)) AS '
						ELSE ''
					END + 'blocked_session_count, ' +
					--percent_complete
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, CONVERT(MONEY, percent_complete), 2))) OVER() - LEN(CONVERT(VARCHAR, CONVERT(MONEY, percent_complete), 2))) + CONVERT(CHAR(22), CONVERT(MONEY, percent_complete), 2)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1)) AS '
						ELSE ''
					END + 'percent_complete, ' +
					'host_name, ' +
					'login_name, ' +
					'database_name, ' +
					'program_name, ' +
					'additional_info, ' +
					'start_time, ' +
					'login_time, ' +
					'CASE ' +
						'WHEN status = N''sleeping'' THEN NULL ' +
						'ELSE request_id ' +
					'END AS request_id, ' +
					'GETDATE() AS collection_time '
		--End inner column list
		) +
		--Derived table and INSERT specification
		CONVERT
		(
			VARCHAR(MAX),
				'FROM ' +
				'( ' +
					'SELECT TOP(2147483647) ' +
						'*, ' +
						'CASE ' +
							'MAX ' +
							'( ' +
								'LEN ' +
								'( ' +
									'CONVERT ' +
									'( ' +
										'VARCHAR, ' +
										'CASE ' +
											'WHEN elapsed_time < 0 THEN ' +
												'(-1 * elapsed_time) / 86400 ' +
											'ELSE ' +
												'elapsed_time / 86400000 ' +
										'END ' +
									') ' +
								') ' +
							') OVER () ' +
								'WHEN 1 THEN 2 ' +
								'ELSE ' +
									'MAX ' +
									'( ' +
										'LEN ' +
										'( ' +
											'CONVERT ' +
											'( ' +
												'VARCHAR, ' +
												'CASE ' +
													'WHEN elapsed_time < 0 THEN ' +
														'(-1 * elapsed_time) / 86400 ' +
													'ELSE ' +
														'elapsed_time / 86400000 ' +
												'END ' +
											') ' +
										') ' +
									') OVER () ' +
						'END AS max_elapsed_length, ' +
						CASE
							WHEN @output_column_list LIKE '%|_delta|]%' ESCAPE '|' THEN
								'MAX(physical_io * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(physical_io * recursion) OVER (PARTITION BY session_id, request_id) AS physical_io_delta, ' +
								'MAX(reads * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(reads * recursion) OVER (PARTITION BY session_id, request_id) AS reads_delta, ' +
								'MAX(physical_reads * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(physical_reads * recursion) OVER (PARTITION BY session_id, request_id) AS physical_reads_delta, ' +
								'MAX(writes * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(writes * recursion) OVER (PARTITION BY session_id, request_id) AS writes_delta, ' +
								'MAX(tempdb_allocations * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(tempdb_allocations * recursion) OVER (PARTITION BY session_id, request_id) AS tempdb_allocations_delta, ' +
								'MAX(tempdb_current * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(tempdb_current * recursion) OVER (PARTITION BY session_id, request_id) AS tempdb_current_delta, ' +
								'MAX(CPU * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(CPU * recursion) OVER (PARTITION BY session_id, request_id) AS CPU_delta, ' +
								'MAX(thread_CPU_snapshot * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(thread_CPU_snapshot * recursion) OVER (PARTITION BY session_id, request_id) AS thread_CPU_delta, ' +
								'MAX(context_switches * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(context_switches * recursion) OVER (PARTITION BY session_id, request_id) AS context_switches_delta, ' +
								'MAX(used_memory * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(used_memory * recursion) OVER (PARTITION BY session_id, request_id) AS used_memory_delta, ' +
								'MIN(last_request_start_time) OVER (PARTITION BY session_id, request_id) AS first_request_start_time, '
							ELSE ''
						END +
						'COUNT(*) OVER (PARTITION BY session_id, request_id) AS num_events ' +
					'FROM #sessions AS s1 ' +
					CASE 
						WHEN @sort_order = '' THEN ''
						ELSE
							'ORDER BY ' +
								@sort_order
					END +
				') AS s ' +
				'WHERE ' +
					's.recursion = 1 ' +
			') x ' +
			'OPTION (KEEPFIXED PLAN); ' +
			'' +
			CASE @return_schema
				WHEN 1 THEN
					'SET @schema = ' +
						'''CREATE TABLE <table_name> ( '' + ' +
							'STUFF ' +
							'( ' +
								'( ' +
									'SELECT ' +
										''','' + ' +
										'QUOTENAME(COLUMN_NAME) + '' '' + ' +
										'DATA_TYPE + ' + 
										'CASE ' +
											'WHEN DATA_TYPE LIKE ''%char'' THEN ''('' + COALESCE(NULLIF(CONVERT(VARCHAR, CHARACTER_MAXIMUM_LENGTH), ''-1''), ''max'') + '') '' ' +
											'ELSE '' '' ' +
										'END + ' +
										'CASE IS_NULLABLE ' +
											'WHEN ''NO'' THEN ''NOT '' ' +
											'ELSE '''' ' +
										'END + ''NULL'' AS [text()] ' +
									'FROM tempdb.INFORMATION_SCHEMA.COLUMNS ' +
									'WHERE ' +
										'TABLE_NAME = (SELECT name FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(''tempdb..#session_schema'')) ' +
										'ORDER BY ' +
											'ORDINAL_POSITION ' +
									'FOR XML ' +
										'PATH('''') ' +
								'), + ' +
								'1, ' +
								'1, ' +
								''''' ' +
							') + ' +
						''')''; ' 
				ELSE ''
			END
		--End derived table and INSERT specification
		);

	SET @sql_n = CONVERT(NVARCHAR(MAX), @sql);

	EXEC sp_executesql
		@sql_n,
		N'@schema VARCHAR(MAX) OUTPUT',
		@schema OUTPUT;
END;
GO

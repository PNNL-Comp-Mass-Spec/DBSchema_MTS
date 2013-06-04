/****** Object:  StoredProcedure [dbo].[usp_TodaysDeadlocks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_TodaysDeadlocks]
AS

/**************************************************************************************************************
**  Purpose:
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  03/19/2013		Michael Rounds			1.0					Comments creation
**	05/15/2013		Matthew Monroe from SSC	1.1					Removed all SUM() potentially causing a conversion failure
***************************************************************************************************************/

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
SELECT DISTINCT CONVERT(NVARCHAR(30),LogDate,120) as LogDate
FROM #ERRORLOG
WHERE ProcessInfo LIKE 'spid%'
and [text] LIKE '   process id=%'

INSERT INTO #DEADLOCKINFO (DeadLockDate, DBName, ProcessInfo, VictimHostname, VictimLogin, VictimSPID, LockingHostname, LockingLogin, LockingSPID)
SELECT 
DISTINCT CONVERT(NVARCHAR(30),b.LogDate,120) AS DeadlockDate,
DB_NAME(SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%currentdb=%',b.[text]),(PATINDEX('%lockTimeout%',b.[text])) - (PATINDEX('%currentdb=%',b.[text]))  )),11,50)) as DBName,
b.processinfo,
SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%hostname=%',a.[text]),(PATINDEX('%hostpid%',a.[text])) - (PATINDEX('%hostname=%',a.[text]))  )),10,50)
	AS VictimHostname,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%loginname=%',a.[text]),(PATINDEX('%isolationlevel%',a.[text])) - (PATINDEX('%loginname=%',a.[text]))  )),11,50) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%loginname=%',a.[text]),(PATINDEX('%isolationlevel%',a.[text])) - (PATINDEX('%loginname=%',a.[text]))  )),11,50)
	ELSE NULL END AS VictimLogin,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%spid=%',a.[text]),(PATINDEX('%sbid%',a.[text])) - (PATINDEX('%spid=%',a.[text]))  )),6,10) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(a.[text],PATINDEX('%spid=%',a.[text]),(PATINDEX('%sbid%',a.[text])) - (PATINDEX('%spid=%',a.[text]))  )),6,10)
	ELSE NULL END AS VictimSPID,
SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%hostname=%',b.[text]),(PATINDEX('%hostpid%',b.[text])) - (PATINDEX('%hostname=%',b.[text]))  )),10,50)
	AS LockingHostname,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%loginname=%',b.[text]),(PATINDEX('%isolationlevel%',b.[text])) - (PATINDEX('%loginname=%',b.[text]))  )),11,50) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%loginname=%',b.[text]),(PATINDEX('%isolationlevel%',b.[text])) - (PATINDEX('%loginname=%',b.[text]))  )),11,50)
	ELSE NULL END AS LockingLogin,
CASE WHEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%spid=%',b.[text]),(PATINDEX('%sbid=%',b.[text])) - (PATINDEX('%spid=%',b.[text]))  )),6,10) NOT LIKE '%id%'
	THEN SUBSTRING(RTRIM(SUBSTRING(b.[text],PATINDEX('%spid=%',b.[text]),(PATINDEX('%sbid=%',b.[text])) - (PATINDEX('%spid=%',b.[text]))  )),6,10)
	ELSE NULL END AS LockingSPID
FROM #TEMPDATES t
JOIN #ERRORLOG a
	ON CONVERT(NVARCHAR(30),t.LogDate,120) = CONVERT(NVARCHAR(30),a.LogDate,120)
JOIN #ERRORLOG b
	ON CONVERT(NVARCHAR(30),t.LogDate,120) = CONVERT(NVARCHAR(30),b.LogDate,120) AND a.[text] LIKE '   process id=%' AND b.[text] LIKE '   process id=%' AND a.ID < b.ID 
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
WHERE DeadlockDate >=  CONVERT(DATETIME, CONVERT (NVARCHAR(10), GETDATE(), 101)) AND
(VictimLogin IS NOT NULL OR LockingLogin IS NOT NULL)
ORDER BY DeadlockDate ASC

DROP TABLE #ERRORLOG
DROP TABLE #DEADLOCKINFO
DROP TABLE #TEMPDATES

END



GO

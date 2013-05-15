/****** Object:  StoredProcedure [dbo].[rpt_Queries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.rpt_Queries (@DateRangeInDays INT)
AS

BEGIN

DECLARE @QueryValue INT

SELECT @QueryValue = CAST(Value AS INT) FROM [dba].dbo.AlertSettings WHERE VariableName = 'QueryValue' AND AlertName = 'LongRunningQueries'

SELECT
DateStamp AS DateStamp,
CAST(DATEDIFF(ss,Start_Time,DateStamp) AS INT) AS [ElapsedTime(ss)],
Session_ID AS Session_ID,
[DBName] AS [DBName],	
Login_Name AS Login_Name,
Formatted_SQL_Text AS SQL_Text
FROM [dba].dbo.QueryHistory (nolock) 
WHERE (DATEDIFF(ss,Start_Time,DateStamp)) >= @QueryValue 
AND (DATEDIFF(dd,DateStamp,GETDATE())) <= @DateRangeInDays
AND [DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LongQueryAlerts = 0)
AND Formatted_SQL_Text NOT LIKE '%BACKUP DATABASE%'
AND Formatted_SQL_Text NOT LIKE '%RESTORE VERIFYONLY%'
AND Formatted_SQL_Text NOT LIKE '%ALTER INDEX%'
AND Formatted_SQL_Text NOT LIKE '%DECLARE @BlobEater%'
AND Formatted_SQL_Text NOT LIKE '%DBCC%'
AND Formatted_SQL_Text NOT LIKE '%WAITFOR(RECEIVE%'
ORDER BY DateStamp DESC

END

GO

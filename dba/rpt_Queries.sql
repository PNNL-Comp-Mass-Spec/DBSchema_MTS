/****** Object:  StoredProcedure [dbo].[rpt_Queries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.rpt_Queries (@DateRangeInDays INT)
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

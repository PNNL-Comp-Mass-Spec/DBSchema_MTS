/****** Object:  StoredProcedure [dbo].[rpt_Blocking] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.rpt_Blocking (@DateRangeInDays INT)
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

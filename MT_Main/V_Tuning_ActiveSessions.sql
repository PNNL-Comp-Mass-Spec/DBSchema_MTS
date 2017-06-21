/****** Object:  View [dbo].[V_Tuning_ActiveSessions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_Tuning_ActiveSessions
AS
SELECT MAX(login_time) AS [Last Login Time], login_name [Login], Count(*) AS Sessions, Sum(cpu_time) AS Total_CPUTime, Sum(reads) AS Total_Reads, Sum(writes) AS Total_Writes, Min([Host_Name]) AS Host_Min, Min([Program_Name]) AS Program_Min
FROM sys.dm_exec_sessions
GROUP BY login_name


GO

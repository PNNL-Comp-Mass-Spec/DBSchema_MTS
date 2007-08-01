/****** Object:  View [dbo].[V_Historic_Log_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Historic_Log_Report]
AS
SELECT TOP 100 PERCENT Entry_ID AS Entry, 
   posted_by AS [Posted By], posting_time AS [Posting Time], type, 
   message, DBName AS [DB Name]
FROM dbo.T_Historic_Log_Entries
ORDER BY Entry DESC


GO

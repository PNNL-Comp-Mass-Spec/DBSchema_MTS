/****** Object:  View [dbo].[V_Log_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW dbo.V_Log_Report
AS
SELECT Entry_ID AS Entry, posted_by AS [Posted By], 
   posting_time AS [Posting Time], type, message
FROM dbo.T_Log_Entries




GO
GRANT VIEW DEFINITION ON [dbo].[V_Log_Report] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Log_Report] TO [MTS_DB_Lite] AS [dbo]
GO

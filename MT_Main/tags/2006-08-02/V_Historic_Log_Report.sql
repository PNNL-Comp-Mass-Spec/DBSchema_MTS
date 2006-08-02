SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Historic_Log_Report]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Historic_Log_Report]
GO

CREATE VIEW dbo.V_Historic_Log_Report
AS
SELECT Entry_ID AS Entry, posted_by AS [Posted By], 
   posting_time AS [Posting Time], type, message, 
   DBName AS [DB Name]
FROM MT_HistoricLog.dbo.T_Historic_Log_Entries

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


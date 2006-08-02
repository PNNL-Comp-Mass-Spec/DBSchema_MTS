SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_TempDB_Log_Truncation_History]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_TempDB_Log_Truncation_History]
GO

CREATE VIEW dbo.V_TempDB_Log_Truncation_History
AS
SELECT TOP 100 PERCENT Entry_ID, posted_by, posting_time, 
    type, message
FROM mt_historiclog.dbo.T_Historic_Log_Entries
WHERE (posted_by = 'ShrinkTempDBLogIfRequired')
UNION
SELECT TOP 100 PERCENT Entry_ID, posted_by, posting_time, 
    type, message
FROM mt_main.dbo.T_Log_Entries
WHERE (posted_by = 'ShrinkTempDBLogIfRequired')
ORDER BY posting_time

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


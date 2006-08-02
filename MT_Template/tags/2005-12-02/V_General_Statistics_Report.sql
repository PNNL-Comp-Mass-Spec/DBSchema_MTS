SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_General_Statistics_Report]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_General_Statistics_Report]
GO


CREATE VIEW dbo.V_General_Statistics_Report
AS
SELECT TOP 100 PERCENT Category, Label, Value, Entry_ID
FROM dbo.T_General_Statistics
ORDER BY Entry_ID


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


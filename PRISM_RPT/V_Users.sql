/****** Object:  View [dbo].[V_Users] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create VIEW [dbo].[V_Users]
AS
SELECT     t1.*
FROM         OPENROWSET('SQLOLEDB', 'gigasax'; 'DMSWebUser'; 'icr4fun', 'SELECT * FROM dms5.dbo.T_Users') t1

GO

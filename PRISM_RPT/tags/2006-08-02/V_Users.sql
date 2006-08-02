SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Users]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Users]
GO

create VIEW [dbo].[V_Users]
AS
SELECT     t1.*
FROM         OPENROWSET('SQLOLEDB', 'gigasax'; 'DMSWebUser'; 'icr4fun', 'SELECT * FROM dms5.dbo.T_Users') t1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


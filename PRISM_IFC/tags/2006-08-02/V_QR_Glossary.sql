SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_QR_Glossary]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_QR_Glossary]
GO

CREATE VIEW dbo.V_QR_Glossary
AS
SELECT TOP 100 PERCENT dbo.T_SP_List.SP_Name, 
    dbo.T_SP_Glossary.Column_Name, 
    ISNULL(dbo.T_SP_Glossary.Description, '') 
    AS Description
FROM dbo.T_SP_List INNER JOIN
    dbo.T_SP_Glossary ON 
    dbo.T_SP_List.SP_ID = dbo.T_SP_Glossary.SP_ID
WHERE (dbo.T_SP_List.Category_ID = 2) AND 
    (dbo.T_SP_Glossary.Direction_ID = 3)
ORDER BY dbo.T_SP_List.SP_Name, 
    dbo.T_SP_Glossary.Ordinal_Position

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


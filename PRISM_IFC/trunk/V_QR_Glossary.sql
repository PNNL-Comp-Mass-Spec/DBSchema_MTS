/****** Object:  View [dbo].[V_QR_Glossary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

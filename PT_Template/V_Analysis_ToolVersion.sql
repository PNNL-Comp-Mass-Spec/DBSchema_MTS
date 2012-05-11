/****** Object:  View [dbo].[V_Analysis_ToolVersion] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Analysis_ToolVersion
AS
SELECT AD.Job,
       AD.Process_State,
       AD.Last_Affected,
       ATV.Tool_Version,
       ATV.DataExtractor_Version,
       ATV.MSGF_Version,
       ATV.Entered AS Tool_Version_Entered
FROM T_Analysis_ToolVersion ATV
     INNER JOIN T_Analysis_Description AD
       ON ATV.Job = AD.Job

GO

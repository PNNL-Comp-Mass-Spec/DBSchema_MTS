/****** Object:  View [dbo].[V_Current_Activity_Dashboard] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW [dbo].[V_Current_Activity_Dashboard]
AS
SELECT *
FROM (
	SELECT TOP 4 'Pogo' AS Server, CA.*, 5*100 + Row_Number() OVER (Order By Began Desc) AS Sort
	FROM pogo.mt_main.dbo.v_current_activity CA
	ORDER BY Began Desc
	UNION
	SELECT '--','','','','','',NULL,NULL,'',0,0,0,0,600 AS Sort
	UNION
	SELECT TOP 4 'Roadrunner' AS Server, CA.*, 7*100 + Row_Number() OVER (Order By Began Desc) AS Sort
	FROM roadrunner.mt_main.dbo.v_current_activity CA
	ORDER BY Began Desc
	UNION
	SELECT '--','','','','','',NULL,NULL,'',0,0,0,0,750 AS Sort
	UNION
	SELECT TOP 4 'Sylvester' AS Server, CA.*, 8*100 + Row_Number() OVER (Order By Began Desc) AS Sort
	FROM Sylvester.mt_main.dbo.v_current_activity CA
	ORDER BY Began Desc
	UNION
	SELECT '--','','','','','',NULL,NULL,'',0,0,0,0,850 AS Sort
	UNION
	SELECT TOP 4 'Proteinseqs' AS Server, CA.*, 10*100 + Row_Number() OVER (Order By Began Desc) AS Sort
	FROM Proteinseqs.mt_main.dbo.v_current_activity CA
	ORDER BY Began Desc
 ) LookupQ




GO

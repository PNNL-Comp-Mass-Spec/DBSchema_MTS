/****** Object:  View [dbo].[v_current_activity_dashboard] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE VIEW dbo.V_Activity_Dashboard
AS
SELECT TOP 100 PERCENT *
FROM (
	SELECT TOP 5 'Albert' AS Server,CA.*, 1*100 + Row_Number() OVER (Order By Began Desc) AS Sort
	FROM albert.mt_main.dbo.v_current_activity CA
	ORDER BY Began Desc
	UNION
	SELECT '--','','','','','',NULL,NULL,'',0,0,0,0,200 AS Sort
	UNION
	SELECT TOP 5 'Pogo' AS Server, CA.*, 3*100 + Row_Number() OVER (Order By Began Desc) AS Sort
	FROM pogo.mt_main.dbo.v_current_activity CA
	ORDER BY Began Desc
	UNION
	SELECT '--','','','','','',NULL,NULL,'',0,0,0,0,400 AS Sort
	UNION
	SELECT TOP 5 'Roadrunner' AS Server, CA.*, 5*100 + Row_Number() OVER (Order By Began Desc) AS Sort
	FROM roadrunner.mt_main.dbo.v_current_activity CA
	ORDER BY Began Desc
 ) LookupQ
ORDER BY Sort

GO

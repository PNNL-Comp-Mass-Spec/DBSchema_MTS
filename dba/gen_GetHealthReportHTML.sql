/****** Object:  StoredProcedure [dbo].[gen_GetHealthReportHTML] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.gen_GetHealthReportHTML (@DateStamp NVARCHAR(20))
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.0					Comments creation
**  08/31/2012		Michael Rounds			1.1					Changed VARCHAR to NVARCHAR
***************************************************************************************************************/

BEGIN

DECLARE @HealthReportID INT

SET @HealthReportID = (SELECT MIN(HealthReportID) FROM [dba].dbo.HealthReport(nolock) WHERE DateStamp >= @DateStamp)

SELECT
hr.GeneratedHTML
FROM [dba].dbo.HealthReport(nolock) hr
WHERE hr.HealthReportID = @HealthReportID

END

GO

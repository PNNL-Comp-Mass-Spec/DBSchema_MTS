/****** Object:  StoredProcedure [dbo].[gen_GetHealthReportToEmail] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.gen_GetHealthReportToEmail (@DateStamp NVARCHAR(20), @EmailAddress NVARCHAR(100))
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

IF EXISTS (SELECT MIN(HealthReportID) FROM [dba].dbo.HealthReport(nolock) WHERE DateStamp >= @DateStamp)
BEGIN

DECLARE @HealthReportID INT,
		@SubjectLine NVARCHAR(255), 
		@FileDateStamp NVARCHAR(20), 
		@HTML NVARCHAR(MAX)
		
SELECT @HealthReportID = MIN(HealthReportID) FROM [dba].dbo.HealthReport(nolock) WHERE DateStamp >= @DateStamp	
SELECT @FileDateStamp = (DATEPART(YEAR,@DateStamp) * 10000 + DATEPART(MONTH,@DateStamp) * 100 + DATEPART(DAY,@DateStamp))
SELECT @SubjectLine = 'Database Health Report - ' + @DateStamp
SELECT @HTML = GeneratedHTML FROM [dba].dbo.HealthReport WHERE HealthReportID = @HealthReportID


EXEC msdb.dbo.sp_send_dbmail
@recipients= @EmailAddress,
@subject = @SubjectLine,
@body = @HTML,
@body_format = 'HTML'

END
END

GO

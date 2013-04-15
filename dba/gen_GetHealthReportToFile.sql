/****** Object:  StoredProcedure [dbo].[gen_GetHealthReportToFile] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.gen_GetHealthReportToFile (@DateStamp NVARCHAR(20), @Path NVARCHAR(100))
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
BEGIN -- <WriteHealthReport>

DECLARE @FileDateStamp NVARCHAR(20), @SQL NVARCHAR(250)
SELECT @FileDateStamp = (DATEPART(year,@DateStamp) * 10000 + DATEPART(month,@DateStamp) * 100 + DATEPART(day,@DateStamp))

SET @SQL = 'bcp "EXEC [dba].dbo.gen_GetHealthReportHTML ' + '''' + @DateStamp + '''' +'" queryout "' + @Path + 'HealthReport' + @FileDateStamp + '.html" /c /Usa /Pqwmrp'

-- Determine if xp_cmdshell is already enabled
DECLARE @xpCmdShellEnabledAtStart int = 0

SELECT @xpCmdShellEnabledAtStart = CONVERT(INT, ISNULL(value_in_use, value))
FROM  sys.configurations
WHERE name = 'xp_cmdshell' ;

If @xpCmdShellEnabledAtStart = 0
BEGIN
	EXEC sp_configure 'show advanced options', 1
	RECONFIGURE
	EXEC sp_configure 'xp_cmdshell', 1
	RECONFIGURE

	EXEC master..xp_cmdshell @SQL

	EXEC sp_configure 'show advanced options', 1
	RECONFIGURE
	EXEC sp_configure 'xp_cmdshell', 0
	RECONFIGURE
END
Else
	EXEC master..xp_cmdshell @SQL

END -- </WriteHealthReport>
END

GO

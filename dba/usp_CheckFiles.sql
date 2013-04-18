/****** Object:  StoredProcedure [dbo].[usp_CheckFiles] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.usp_CheckFiles
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.0					Comments creation
**  06/10/2012		Michael Rounds			1.1					Updated to use new FileStatsHistory table
**	08/31/2012		Michael Rounds			1.2					Changed VARCHAR to NVARCHAR
**	04/15/2013		Matthew Monroe			1.2.1				Now ignoring log files less than 200 MB in size.  Now also looking for '[tempdb]' and '[model]' in addition to 'tempdb' and 'model'.  Fixed bug that was performing a text compare of #TEMP.FileMBSize
**	04/17/2013		Matthew Monroe			1.3					Factored out duplicate code into usp_CheckFilesWork
***************************************************************************************************************/

BEGIN

	SET NOCOUNT ON

	/* GET STATS */

	/*Populate File Stats tables*/
	EXEC [dba].dbo.usp_FileStats @InsertFlag=1

	DECLARE @FileStatsID INT, @QueryValue INT, @QueryValue2 INT, @HTML NVARCHAR(MAX), @EmailList NVARCHAR(255), @CellList NVARCHAR(255), @ServerName NVARCHAR(128), @EmailSubject NVARCHAR(100)

	SELECT @ServerName = CONVERT(NVARCHAR(128), SERVERPROPERTY('servername'))  

	SET @FileStatsID = (SELECT MAX(FileStatsID) FROM [dba].dbo.FileStatsHistory)

	CREATE TABLE #TEMP (
		[FileStatsHistoryID] [int] NOT NULL,
		[FileStatsID] [int] NOT NULL,
		[FileStatsDateStamp] [datetime] NOT NULL,
		[DBName] [nvarchar](128) NULL,
		[FileName] [nvarchar](255) NULL,
		[DriveLetter] [nchar](1) NULL,
		[FileMBSize] BIGINT NULL,
		[FileGrowth] [nvarchar](30) NULL,
		[FileMBUsed] BIGINT NULL,
		[FileMBEmpty] BIGINT NULL,
		[FilePercentEmpty] [numeric](12, 2) NULL	
	)


	/*Populate Main TEMP table*/
	INSERT INTO #TEMP (FileStatsHistoryID, FileStatsID, FileStatsDateStamp, DBName, FileName, DriveLetter, FileMBSize, FileGrowth, FileMBUsed, FileMBEmpty, FilePercentEmpty)
	SELECT  FileStatsHistoryID, FileStatsID, FileStatsDateStamp, [DBName], [FileName], DriveLetter, CAST(FileMBSize as BIGINT), FileGrowth, CAST(FileMBUsed AS BIGINT), CAST(FileMBEmpty AS BIGINT), FilePercentEmpty
	FROM [dba].dbo.FileStatsHistory
	WHERE FileStatsID IN (@FileStatsID,(@FileStatsID -1 ))

	/* LOG FILES */
	exec usp_CheckFilesWork @CheckTempDB=0, @WarnGrowingLogFiles=0

	/* TEMP DB */
	exec usp_CheckFilesWork @CheckTempDB=1, @WarnGrowingLogFiles=1
	
	DROP TABLE #TEMP

END


GO

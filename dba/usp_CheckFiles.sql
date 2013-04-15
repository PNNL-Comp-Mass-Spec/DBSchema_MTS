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

	/*Grab AlertSettings for LogFiles*/
	SELECT @QueryValue = QueryValue,
			@QueryValue2 = QueryValue2,
			@EmailList = EmailList,
			@CellList = CellList
	FROM [dba].dbo.AlertSettings WHERE Name = 'LogFiles'

	CREATE TABLE #TEMP2 (
		[DBName] NVARCHAR(128),
		FileMBSize BIGINT,
		FileMBUsed BIGINT,
		FileMBEmpty BIGINT,
		FilePercentEmpty NUMERIC(12,2)
		)

	-- Find log files that are at least 200 MB in size
	-- and are less than @QueryValue percent empty
	INSERT INTO #TEMP2 ([DBName],FileMBSize,FileMBUsed,FileMBEmpty,FilePercentEmpty)
	SELECT t2.[DBName],t2.FileMBSize,t2.FileMBUsed,t2.FileMBEmpty,t2.FilePercentEmpty
	FROM #TEMP t
	JOIN #TEMP t2
		ON t.[DBName] = t2.[DBName] 
		AND t.[Filename] = t2.[FileName] 
		AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
		AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
	WHERE t2.FilePercentEmpty < @QueryValue
	      AND t2.FileMBSize > 200
	      AND t2.[Filename] like '%ldf'
	      AND t.FileMBSize <> t2.FileMBSize
	      AND t2.[DBName] NOT IN ('model','tempdb','[model]','[tempdb]')
	      AND t2.[DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LogFileAlerts = 0)

	/*Populate TEMPLogFiles table used for Already Grown LOG files*/

	CREATE TABLE #TEMPLogFiles (
		[DBName] NVARCHAR(128),
		[Filename] NVARCHAR(255),
		PreviousFileSize BIGINT,
		PrevPercentEmpty NUMERIC(12,2),
		CurrentFileSize BIGINT,
		CurrPercentEmpty NUMERIC(12,2)	
		)

	INSERT INTO #TEMPLogFiles ([DBName],[Filename],PreviousFileSize,PrevPercentEmpty,CurrentFileSize,CurrPercentEmpty)
	SELECT t.[DBName],t.[Filename],t.FileMBSize AS PreviousFileSize,t.FilePercentEmpty AS PrevPercentEmpty,t2.FileMBSize AS CurrentFileSize,t2.FilePercentEmpty AS CurrPercentEmpty
	FROM #TEMP t
	JOIN #TEMP t2
		ON t.[DBName] = t2.[DBName] 
		AND t.[Filename] = t2.[FileName] 
		AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
		AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
	WHERE t2.[Filename] like '%ldf'
	      AND t.FileMBSize < t2.FileMBSize
	      AND t2.FileMBSize > 200
	      AND t2.[DBName] NOT IN ('model','tempdb','[model]','[tempdb]')
	      AND t2.[DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LogFileAlerts = 0)

	/*Start of Growing Log files*/
	IF EXISTS (SELECT * FROM #TEMP2)
	BEGIN
		SET	@HTML =
			'<html><head><style type="text/css">
			table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
			th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
			th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
			td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
			</style></head><body>
			<table width="725"> <tr><th class="header" width="725">Growing Log Files</th></tr></table>
			<table width="725" >
			<tr>  
			<th width="250">Database</th>
			<th width="250">FileMBSize</th>
			<th width="250">FileMBUsed</th> 
			<th width="250">FileMBEmpty</th>
			<th width="250">FilePercentEmpty</th>
			</tr>'
		SELECT @HTML =  @HTML +   
			'<tr>
			<td bgcolor="#E0E0E0" width="250">' + [DBName] +'</td>
			<td bgcolor="#F0F0F0" width="250">' + CAST(FileMBSize AS NVARCHAR) + '</td>	
			<td bgcolor="#E0E0E0" width="250">' + CAST(FileMBUsed AS NVARCHAR) + '</td>	
			<td bgcolor="#F0F0F0" width="250">' + CAST(FileMBEmpty AS NVARCHAR) + '</td>	
			<td bgcolor="#E0E0E0" width="250">' + CAST(FilePercentEmpty AS NVARCHAR) + '</td>			
			</tr>'
		FROM #TEMP2

		SELECT @HTML =  @HTML + '</table></body></html>'

		SELECT @EmailSubject = 'Log files are about to Auto-Grow on ' + @ServerName + '!'

		EXEC msdb.dbo.sp_send_dbmail
		@recipients= @EmailList,
		@subject = @EmailSubject,
		@body = @HTML,
		@body_format = 'HTML'

		IF @CellList IS NOT NULL
		BEGIN

			IF @QueryValue2 IS NOT NULL
			BEGIN
			TRUNCATE TABLE #TEMP2
				INSERT INTO #TEMP2 ([DBName],FileMBSize,FileMBUsed,FileMBEmpty,FilePercentEmpty)
				SELECT t2.[DBName],t2.FileMBSize,t2.FileMBUsed,t2.FileMBEmpty,t2.FilePercentEmpty
				FROM #TEMP t
				JOIN #TEMP t2
					ON t.[DBName] = t2.[DBName] 
					AND t.[Filename] = t2.[FileName] 
					AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
					AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
				WHERE t2.FilePercentEmpty < @QueryValue2
				      AND t2.FileMBSize > 200
				      AND t2.[Filename] like '%ldf'
				      AND t.FileMBSize <> t2.FileMBSize
				      AND t2.[DBName] NOT IN ('model','tempdb','[model]','[tempdb]')
				      AND t2.[DBName] NOT IN (SELECT [DBName] FROM [dba].dbo.DatabaseSettings WHERE LogFileAlerts = 0)
			END

			/*TEXT MESSAGE*/
			IF EXISTS (SELECT * FROM #TEMP2)
			BEGIN
				SET	@HTML =
					'<html><head></head><body><table><tr><td>Database,</td><td>FileSize,</td><td>Percent</td></tr>'
				SELECT @HTML =  @HTML +   
					'<tr><td>' + COALESCE([DBName], '') +',</td><td>' + COALESCE(CAST(FileMBSize AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(FilePercentEmpty AS NVARCHAR), '') +'</td></tr>'
				FROM #TEMP2
				SELECT @HTML =  @HTML + '</table></body></html>'

				SELECT @EmailSubject = 'LDFGrowing-' + @ServerName

				EXEC msdb.dbo.sp_send_dbmail
				@recipients= @CellList,
				@subject = @EmailSubject,
				@body = @HTML,
				@body_format = 'HTML'

			END
		END
	END
	/*Stop of Growing Log files*/
	/*Start of Already Grown Log files*/
	IF EXISTS (SELECT * FROM #TEMPLogFiles)
	BEGIN
		SET	@HTML =
			'<html><head><style type="text/css">
			table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
			th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
			th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
			td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
			</style></head><body>
			<table width="725"> <tr><th class="header" width="725">Recent Log File Auto-Growth</th></tr></table>
			<table width="725" >
			<tr>  
			<th width="250">Database</th>
			<th width="250">PreviousFileSize</th>
			<th width="250">PrevPercentEmpty</th>
			<th width="250">CurrentFileSize</th>
			<th width="250">CurrPercentEmpty</th>
			</tr>'
		SELECT @HTML =  @HTML +   
			'<tr>
			<td bgcolor="#E0E0E0" width="250">' + [DBName] +'</td>
			<td bgcolor="#F0F0F0" width="250">' + CAST(PreviousFileSize AS NVARCHAR) + '</td>	
			<td bgcolor="#E0E0E0" width="250">' + CAST(PrevPercentEmpty AS NVARCHAR) + '</td>	
			<td bgcolor="#F0F0F0" width="250">' + CAST(CurrentFileSize AS NVARCHAR) + '</td>	
			<td bgcolor="#E0E0E0" width="250">' + CAST(CurrPercentEmpty AS NVARCHAR) + '</td>			
			</tr>'
		FROM #TEMPLogFiles

		SELECT @HTML =  @HTML + '</table></body></html>'

		SELECT @EmailSubject = 'Log files have Auto-Grown on ' + @ServerName + '!'

		EXEC msdb.dbo.sp_send_dbmail
		@recipients= @EmailList,
		@subject = @EmailSubject,
		@body = @HTML,
		@body_format = 'HTML'

		IF @CellList IS NOT NULL
		BEGIN
			/*TEXT MESSAGE*/
			SET	@HTML =
				'<html><head></head><body><table><tr><td>Database,</td><td>PrevFileSize,</td><td>CurrFileSize</td></tr>'
			SELECT @HTML =  @HTML +   
				'<tr><td>' + COALESCE([DBName], '') +',</td><td>' + COALESCE(CAST(PreviousFileSize AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(CurrentFileSize AS NVARCHAR), '') +'</td></tr>'
			FROM #TEMPLogFiles
			SELECT @HTML =  @HTML + '</table></body></html>'

			SELECT @EmailSubject = 'LDFAutoGrowth-' + @ServerName

			EXEC msdb.dbo.sp_send_dbmail
			@recipients= @CellList,
			@subject = @EmailSubject,
			@body = @HTML,
			@body_format = 'HTML'

	END
	END
	/*Stop of Already Grown Log files*/

	/* TEMP DB */

	/*Grab AlertSettings for TEMPDB*/
	SELECT @QueryValue = QueryValue,
			@QueryValue2 = QueryValue2,
			@EmailList = EmailList,
			@CellList = CellList
	FROM [dba].dbo.AlertSettings WHERE Name IN ('TempDB')

	CREATE TABLE #TEMP3 (
		[DBName] NVARCHAR(128),
		FileMBSize BIGINT,
		FileMBUsed BIGINT,
		FileMBEmpty BIGINT,
		FilePercentEmpty NUMERIC(12,2)
		)

	INSERT INTO #TEMP3
	SELECT t2.[DBName],t2.FileMBSize,t2.FileMBUsed,t2.FileMBEmpty,t2.FilePercentEmpty
	FROM #TEMP t
	JOIN #TEMP t2
		ON t.[DBName] = t2.[DBName] 
		AND t.[Filename] = t2.[FileName] 
		AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
		AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
	WHERE t2.FilePercentEmpty < @QueryValue
	      AND t2.FileMBSize > 200
	      AND t2.[Filename] like '%mdf'
	      AND t.FileMBSize <> t2.FileMBSize
	      AND t2.[DBName] IN ('tempdb', '[tempdb]')

	/*Populate TEMPdb table used for Already Grown TEMPDB files*/
	CREATE TABLE #TEMPdb (
		[DBName] NVARCHAR(128),
		[Filename] NVARCHAR(255),
		PreviousFileSize BIGINT,
		PrevPercentEmpty NUMERIC(12,2),
		CurrentFileSize BIGINT,
		CurrPercentEmpty NUMERIC(12,2)	
		)

	INSERT INTO #TEMPdb
	SELECT t2.[DBName],t2.[Filename],t.FileMBSize AS PreviousFileSize,t.FilePercentEmpty AS PrevPercentEmpty,t2.FileMBSize AS CurrentFileSize,t2.FilePercentEmpty AS CurrPercentEmpty
	FROM #TEMP t
	JOIN #TEMP t2
		ON t.[DBName] = t2.[DBName] 
		AND t.[Filename] = t2.[FileName] 
		AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
		AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
	WHERE t2.[Filename] like '%mdf'
	     AND t.FileMBSize < t2.FileMBSize
	     AND t2.FileMBSize > 200
	     AND t2.[DBName] IN ('tempdb', '[tempdb]')

	/*Start of TempDB Growing*/
	IF EXISTS (SELECT * FROM #TEMP3)
	BEGIN
		SET	@HTML =
			'<html><head><style type="text/css">
			table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
			th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
			th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
			td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
			</style></head><body>
			<table width="725"> <tr><th class="header" width="725">TempDB Growth</th></tr></table>
			<table width="725" >
			<tr>  
			<th width="250">Database</th>
			<th width="250">FileMBSize</th>
			<th width="250">FileMBUsed</th> 
			<th width="250">FileMBEmpty</th>
			<th width="250">FilePercentEmpty</th>
			</tr>'
		SELECT @HTML =  @HTML +   
			'<tr>
			<td bgcolor="#E0E0E0" width="250">' + [DBName] +'</td>
			<td bgcolor="#F0F0F0" width="250">' + CAST(FileMBSize AS NVARCHAR) + '</td>	
			<td bgcolor="#E0E0E0" width="250">' + CAST(FileMBUsed AS NVARCHAR) + '</td>	
			<td bgcolor="#F0F0F0" width="250">' + CAST(FileMBEmpty AS NVARCHAR) + '</td>	
			<td bgcolor="#E0E0E0" width="250">' + CAST(FilePercentEmpty AS NVARCHAR) + '</td>			
			</tr>'
		FROM #TEMP3

		SELECT @HTML =  @HTML + '</table></body></html>'

		SELECT @EmailSubject = 'TempDB is growing on ' + @ServerName + '!'

		EXEC msdb.dbo.sp_send_dbmail
		@recipients= @EmailList,
		@subject = @EmailSubject,
		@body = @HTML,
		@body_format = 'HTML'

		IF @CellList IS NOT NULL
		BEGIN

			IF @QueryValue2 IS NOT NULL
			BEGIN
				TRUNCATE TABLE #TEMP3
				INSERT INTO #TEMP3
				SELECT t2.[DBName],t2.FileMBSize,t2.FileMBUsed,t2.FileMBEmpty,t2.FilePercentEmpty
				FROM #TEMP t
				JOIN #TEMP t2
					ON t.[DBName] = t2.[DBName] 
					AND t.[Filename] = t2.[FileName] 
					AND t.FileStatsID = (SELECT MIN(FileStatsID) FROM #TEMP) 
					AND t2.FileStatsID = (SELECT MAX(FileStatsID) FROM #TEMP)
				WHERE t2.FilePercentEmpty < @QueryValue
				      AND t2.FileMBSize > 200
				      AND t2.[Filename] like '%mdf'
				      AND t.FileMBSize <> t2.FileMBSize
				      AND t2.[DBName] IN ('tempdb', '[tempdb]')
			END

			/*TEXT MESSAGE*/
			IF EXISTS (SELECT * FROM #TEMP3)
			BEGIN
				SET	@HTML =
					'<html><head></head><body><table><tr><td>FileSize,</td><td>FileEmpty,</td><td>Percent</td></tr>'
				SELECT @HTML =  @HTML +   
					'<tr><td>' + COALESCE(CAST(FileMBSize AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(FileMBEmpty AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(FilePercentEmpty AS NVARCHAR), '') +'</td></tr>'
				FROM #TEMP3

				SELECT @HTML =  @HTML + '</table></body></html>'

				SELECT @EmailSubject = 'TempDBGrowing-' + @ServerName

				EXEC msdb.dbo.sp_send_dbmail
				@recipients= @CellList,
				@subject = @EmailSubject,
				@body = @HTML,
				@body_format = 'HTML'

			END
		END
	END
	/*Stop of TempDB Growing*/
	/*Start of TempDB Already Grown*/

	/*TempDB */
	IF EXISTS (SELECT * FROM #TEMPdb)
	BEGIN
		SET	@HTML =
			'<html><head><style type="text/css">
			table { border: 0px; border-spacing: 0px; border-collapse: collapse;}
			th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}
			th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}
			td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}
			</style></head><body>
			<table width="725"> <tr><th class="header" width="725">Recent TempDB Auto-Growth</th></tr></table>
			<table width="725" >
			<tr>  
			<th width="250">Database</th>
			<th width="250">PreviousFileSize</th>
			<th width="250">PrevPercentEmpty</th>
			<th width="250">CurrentFileSize</th>
			<th width="250">CurrPercentEmpty</th>
			</tr>'
		SELECT @HTML =  @HTML +   
			'<tr>
			<td bgcolor="#E0E0E0" width="250">' + [DBName] +'</td>
			<td bgcolor="#F0F0F0" width="250">' + CAST(PreviousFileSize AS NVARCHAR) + '</td>	
			<td bgcolor="#E0E0E0" width="250">' + CAST(PrevPercentEmpty AS NVARCHAR) + '</td>	
			<td bgcolor="#F0F0F0" width="250">' + CAST(CurrentFileSize AS NVARCHAR) + '</td>	
			<td bgcolor="#E0E0E0" width="250">' + CAST(CurrPercentEmpty AS NVARCHAR) + '</td>			
			</tr>'
		FROM #TEMPdb

		SELECT @HTML =  @HTML + '</table></body></html>'

		SELECT @EmailSubject = 'TempDB has Auto-Grown on ' + @ServerName + '!'

		EXEC msdb.dbo.sp_send_dbmail
		@recipients= @EmailList,
		@subject = @EmailSubject,
		@body = @HTML,
		@body_format = 'HTML'

		IF @CellList IS NOT NULL
		BEGIN
			/*TEXT MESSAGE*/
			SET	@HTML =
				'<html><head></head><body><table><tr><td>Database,</td><td>PrevFileSize,</td><td>CurrFileSize</td></tr>'
			SELECT @HTML =  @HTML +   
				'<tr><td>' + COALESCE([DBName], '') +',</td><td>' + COALESCE(CAST(PreviousFileSize AS NVARCHAR), '') +',</td><td>' + COALESCE(CAST(CurrentFileSize AS NVARCHAR), '') +'</td></tr>'
			FROM #TEMPdb
			SELECT @HTML =  @HTML + '</table></body></html>'

			SELECT @EmailSubject = 'TempDBAutoGrowth-' + @ServerName

			EXEC msdb.dbo.sp_send_dbmail
			@recipients= @CellList,
			@subject = @EmailSubject,
			@body = @HTML,
			@body_format = 'HTML'

		END
	END
	
	DROP TABLE #TEMPLogFiles
	DROP TABLE #TEMPdb
	DROP TABLE #TEMP
	DROP TABLE #TEMP2
	DROP TABLE #TEMP3

END


GO

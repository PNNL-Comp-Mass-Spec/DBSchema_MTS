/****** Object:  Table [dbo].[DatabaseSettings] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DatabaseSettings](
	[DBName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SchemaTracking] [bit] NULL,
	[LogFileAlerts] [bit] NULL,
	[LongQueryAlerts] [bit] NULL,
	[Reindex] [bit] NULL,
 CONSTRAINT [pk_DatabaseSettings] PRIMARY KEY CLUSTERED 
(
	[DBName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Trigger [dbo].[tr_d_DatabaseSettings] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[tr_d_DatabaseSettings] ON [dbo].[DatabaseSettings]
AFTER DELETE
AS 

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  05/14/2012		Michael Rounds			1.0					New DELETE trigger on DatabaseSettings table to manage Schema Change table and Database trigger
***************************************************************************************************************/

BEGIN
	DECLARE @DBName NVARCHAR(128), @SQL NVARCHAR(MAX)

	IF EXISTS (SELECT * FROM Deleted WHERE [DBName] NOT LIKE 'AdventureWorks%')
	BEGIN
		CREATE TABLE #TEMP ([DBName] NVARCHAR(128), [Status] INT)

		INSERT INTO #TEMP ([DBName], [Status])
		SELECT [DBName], 0
		FROM Deleted WHERE [DBName] NOT LIKE 'AdventureWorks%'

		SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP WHERE [Status] = 0)

		WHILE @DBName IS NOT NULL
		BEGIN
			SELECT @SQL = 
				'USE '+ CHAR(13) + '[' + @DBName + ']'  + CHAR(13)+ CHAR(10) + 
				+ 'IF  EXISTS (SELECT * FROM sys.triggers WHERE [name] = ''tr_DDL_SchemaChangeLog'') DROP TRIGGER tr_DDL_SchemaChangeLog ON DATABASE'
			EXEC(@SQL)
			
			UPDATE #TEMP
			SET [Status] = 1
			WHERE [DBName] = @DBName

			SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP WHERE [Status] = 0)	
		END
		DROP TABLE #TEMP
	END
END

GO
/****** Object:  Trigger [dbo].[tr_iu_DatabaseSettings] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[tr_iu_DatabaseSettings] ON [dbo].[DatabaseSettings]
AFTER INSERT, UPDATE
AS 

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  05/14/2012		Michael Rounds			1.0					New INSERT/UPDATE trigger on DatabaseSettings table to manage Schema Change table and Database trigger
***************************************************************************************************************/

IF UPDATE(SchemaTracking)
BEGIN
	DECLARE @DBName NVARCHAR(128), @SQL NVARCHAR(MAX)

	IF EXISTS (SELECT * FROM Inserted WHERE SchemaTracking = 1 AND [DBName] NOT LIKE 'AdventureWorks%')
	BEGIN
		CREATE TABLE #TEMP ([DBName] NVARCHAR(128), [Status] INT)

		INSERT INTO #TEMP ([DBName], [Status])
		SELECT [DBName], 0
		FROM Inserted WHERE SchemaTracking = 1 AND [DBName] NOT LIKE 'AdventureWorks%'

		SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP WHERE [Status] = 0)

		WHILE @DBName IS NOT NULL
		BEGIN

			SET @SQL = 
			'USE ' + '[' + @DBName + ']' +';

			IF NOT EXISTS (SELECT *	FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''SchemaChangeLog'' AND TABLE_SCHEMA = ''dbo'')
			BEGIN
			CREATE TABLE [dbo].[SchemaChangeLog](
				[SchemaChangeLogID] INT IDENTITY(1,1) NOT NULL
					CONSTRAINT PK_SchemaChangeLog
						PRIMARY KEY CLUSTERED (SchemaChangeLogID),	
				[CreateDate] DATETIME NULL,
				[LoginName] SYSNAME NULL,
				[ComputerName] SYSNAME NULL,
				[DBName] SYSNAME NOT NULL,
				[SQLEvent] SYSNAME NOT NULL,
				[Schema] SYSNAME NULL,
				[ObjectName] SYSNAME NULL,
				[SQLCmd] NVARCHAR(MAX) NULL,
				[XmlEvent] XML NOT NULL
				)
			END;

			IF EXISTS (SELECT *	FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = ''SchemaChangeLog'' AND TABLE_SCHEMA = ''dbo'' 
			AND COLUMN_NAME = ''SQLCmd'' AND IS_NULLABLE = ''NO'')
			BEGIN
			ALTER TABLE dbo.SchemaChangeLog
			ALTER COLUMN [SQLCmd] NVARCHAR(MAX) NULL
			END;

			DECLARE @triggersql1 NVARCHAR(MAX)

			SET @triggersql1 = ''IF NOT EXISTS (SELECT *
							FROM sys.triggers
							WHERE [name] = ''''tr_DDL_SchemaChangeLog'''')
			BEGIN
				EXEC (''''CREATE TRIGGER tr_DDL_SchemaChangeLog ON DATABASE FOR CREATE_TABLE AS SELECT 1'''')
			END;''

			EXEC(@triggersql1)

			DECLARE @triggersql2 NVARCHAR(MAX)

			SET @triggersql2 = ''ALTER TRIGGER [tr_DDL_SchemaChangeLog] ON DATABASE 
			FOR DDL_DATABASE_LEVEL_EVENTS AS 

				SET NOCOUNT ON

				DECLARE @data XML
				DECLARE @schema SYSNAME
				DECLARE @object SYSNAME
				DECLARE @eventType SYSNAME

				SET @data = EVENTDATA()
				SET @eventType = @data.value(''''(/EVENT_INSTANCE/EventType)[1]'''', ''''SYSNAME'''')
				SET @schema = @data.value(''''(/EVENT_INSTANCE/SchemaName)[1]'''', ''''SYSNAME'''')
				SET @object = @data.value(''''(/EVENT_INSTANCE/ObjectName)[1]'''', ''''SYSNAME'''') 

				INSERT [dbo].[SchemaChangeLog] 
					(
					[CreateDate],
					[LoginName], 
					[ComputerName],
					[DBName],
					[SQLEvent], 
					[Schema], 
					[ObjectName], 
					[SQLCmd], 
					[XmlEvent]
					) 
				SELECT
					GETDATE(),
					SUSER_NAME(), 
					HOST_NAME(),   
					@data.value(''''(/EVENT_INSTANCE/DatabaseName)[1]'''', ''''SYSNAME''''),
					@eventType, 
					@schema, 
					@object, 
					@data.value(''''(/EVENT_INSTANCE/TSQLCommand)[1]'''', ''''NVARCHAR(MAX)''''), 
					@data
			;''

			EXEC(@triggersql2)
			'
			EXEC(@SQL)
			
			UPDATE #TEMP
			SET [Status] = 1
			WHERE [DBName] = @DBName

			SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP WHERE [Status] = 0)
		END
		DROP TABLE #TEMP
	END
	IF EXISTS (SELECT * FROM Inserted WHERE SchemaTracking = 0 AND [DBName] NOT LIKE 'AdventureWorks%')
	BEGIN
		CREATE TABLE #TEMP2 ([DBName] NVARCHAR(128), [Status] INT)

		INSERT INTO #TEMP2 ([DBName], [Status])
		SELECT [DBName], 0
		FROM Inserted WHERE SchemaTracking = 0 AND [DBName] NOT LIKE 'AdventureWorks%'

		SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP2 WHERE [Status] = 0)

		WHILE @DBName IS NOT NULL
		BEGIN
			SELECT @SQL = 
				'USE '+ CHAR(13) + '[' + @DBName + ']'  + CHAR(13)+ CHAR(10) + 
				+ 'IF  EXISTS (SELECT * FROM sys.triggers WHERE [name] = ''tr_DDL_SchemaChangeLog'') DROP TRIGGER tr_DDL_SchemaChangeLog ON DATABASE'
			EXEC(@SQL)
		
			UPDATE #TEMP2
			SET [Status] = 1
			WHERE [DBName] = @DBName

			SET @DBName = (SELECT TOP 1 [DBName] FROM #TEMP2 WHERE [Status] = 0)	
		END
		DROP TABLE #TEMP2
	END
END

GO

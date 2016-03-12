/****** Object:  StoredProcedure [dbo].[CacheServerUsersAndPermissions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure CacheServerUsersAndPermissions
/****************************************************
**
**	Desc: 
**		Caches server logins, database logins and roles, and database objects in the T_Auth tables
**
**		If the tables already exist, updates the information using Merge statements
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	03/11/2016 mem - Initial version
**    
*****************************************************/
(
	@databaseList nvarchar(2000) = 'DMS5, DMS_Capture, DMS_Data_Package,DMSHistoricLog,Ontology_Lookup', 	-- List of database names to parse for database logins and roles, plus database permissions
	@infoOnly tinyint = 1,
	@previewSql tinyint = 0,
	@message varchar(255) = '' OUTPUT
)
AS
	Set XACT_ABORT, nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @CurrentLocation varchar(128) = 'Initializing'
	
	Declare @S nvarchar(4000)
	Declare @Params nvarchar(256)
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @databaseList = IsNull(@databaseList, '')
	Set @infoOnly = IsNull(@infoOnly, 1)
	Set @previewSql = IsNull(@previewSql, 0)
	Set @message = ''

	---------------------------------------------------
	-- Create several temporary tables
	---------------------------------------------------
	
	CREATE TABLE #Tmp_DatabaseNames (
		Entry_ID int identity(1,1) not null,
		Database_Name nvarchar(128) not null,
		IsValid tinyint not null,
		Database_ID int null
	)
	
	CREATE TABLE #Tmp_Auth_Server_Logins (
		LoginName nvarchar(128) NOT NULL,
		User_Type_Desc varchar(32) NOT NULL,
		Server_Roles nvarchar(max) NULL,
		Principal_ID int NULL
	)

	CREATE TABLE #Tmp_Auth_Database_LoginsAndRoles(
		Database_ID int NOT NULL,
		Database_Name nvarchar(128) NOT NULL,
		Principal_ID int NOT NULL,
		UserName nvarchar(128) NOT NULL,
		LoginName nvarchar(128) NULL,
		User_Type char(1) NOT NULL,
		User_Type_Desc nvarchar(60) NULL,
		Database_Roles nvarchar(2000) NULL
	)

	CREATE TABLE #Tmp_Auth_Database_Permissions(
		Database_ID int NOT NULL,
		Database_Name nvarchar(128) NOT NULL,
		Principal_ID int NOT NULL,
		Role_Or_User nvarchar(128) NOT NULL,
		User_Type char(1) NOT NULL,
		User_Type_Desc nvarchar(60) NULL,
		Permission nvarchar(128) NOT NULL,
		Object_Names nvarchar(max) NULL	,
		Sort_Order int NOT NULL
	)

	BEGIN TRY 

	
		If @InfoOnly <> 0
		Begin
		
			---------------------------------------------------
			-- Create the tracking tables if missing
			---------------------------------------------------
			--	
			Set @CurrentLocation = 'Creating missing database tables'

			If Not Exists (Select * From sys.Tables where Name = 'T_Auth_Database_LoginsAndRoles')
			Begin
				CREATE TABLE [dbo].[T_Auth_Database_LoginsAndRoles](
					[Database_ID] [int] NOT NULL,
					[Database_Name] [nvarchar](128) NOT NULL,
					[Principal_ID] [int] NOT NULL,
					[UserName] [nvarchar](128) NOT NULL,
					[LoginName] [nvarchar](128) NULL,
					[User_Type] [char](1) NOT NULL,
					[User_Type_Desc] [nvarchar](60) NULL,
					[Database_Roles] [nvarchar](2000) NULL,
					[Entered] [datetime] NOT NULL,
					[Last_Affected] [datetime] NOT NULL,
					[Enabled] [tinyint] NOT NULL,
				 CONSTRAINT [PK_T_Auth_Database_LoginsAndRoles] PRIMARY KEY CLUSTERED (
					[Database_ID] ASC,
					[Principal_ID] ASC )
				)
			
				ALTER TABLE [dbo].[T_Auth_Database_LoginsAndRoles] ADD  CONSTRAINT [DF_T_Auth_Database_LoginsAndRoles_Entered]  DEFAULT (getdate()) FOR [Entered]
				ALTER TABLE [dbo].[T_Auth_Database_LoginsAndRoles] ADD  CONSTRAINT [DF_T_Auth_Database_LoginsAndRoles_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
				ALTER TABLE [dbo].[T_Auth_Database_LoginsAndRoles] ADD  CONSTRAINT [DF_T_Auth_Database_LoginsAndRoles_Enabled]  DEFAULT ((1)) FOR [Enabled]
			
			End
			
			If Not Exists (Select * From sys.Tables where Name = 'T_Auth_Database_Permissions')
			Begin
				
				CREATE TABLE [dbo].[T_Auth_Database_Permissions](
					[Database_ID] [int] NOT NULL,
					[Database_Name] [nvarchar](128) NOT NULL,
					[Principal_ID] [int] NOT NULL,
					[Role_Or_User] [nvarchar](128) NOT NULL,
					[User_Type] [char](1) NOT NULL,
					[User_Type_Desc] [nvarchar](60) NULL,
					[Permission] [nvarchar](128) NOT NULL,
					[Object_Names] [nvarchar](max) NULL,
					[Sort_Order] [int] NOT NULL,
					[Entered] [datetime] NOT NULL,
					[Last_Affected] [datetime] NOT NULL,
					[Enabled] [tinyint] NOT NULL,
				 CONSTRAINT [PK_T_Auth_Database_Permissions] PRIMARY KEY CLUSTERED 
				(
					[Database_ID] ASC,
					[Principal_ID] ASC,
					[Permission] ASC )
				)
			
				ALTER TABLE [dbo].[T_Auth_Database_Permissions] ADD  CONSTRAINT [DF_T_Auth_Database_Permissions_Entered]  DEFAULT (getdate()) FOR [Entered]
				ALTER TABLE [dbo].[T_Auth_Database_Permissions] ADD  CONSTRAINT [DF_T_Auth_Database_Permissions_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
				ALTER TABLE [dbo].[T_Auth_Database_Permissions] ADD  CONSTRAINT [DF_T_Auth_Database_Permissions_Enabled]  DEFAULT ((1)) FOR [Enabled]
			End
			
			If Not Exists (Select * From sys.Tables where Name = 'T_Auth_Server_Logins')
			Begin
				CREATE TABLE [dbo].[T_Auth_Server_Logins](
					[LoginName] [nvarchar](128) NOT NULL,
					[User_Type_Desc] [varchar](32) NOT NULL,
					[Server_Roles] [nvarchar](max) NULL,
					[Principal_ID] [int] NULL,
					[Entered] [datetime] NULL,
					[Last_Affected] [datetime] NULL,
					[Enabled] [tinyint] NOT NULL,
				 CONSTRAINT [PK_T_Auth_Server_Logins] PRIMARY KEY CLUSTERED 
				(
					[LoginName] ASC)
				)
				
				ALTER TABLE [dbo].[T_Auth_Server_Logins] ADD  CONSTRAINT [DF_T_Auth_Server_Logins_Entered]  DEFAULT (getdate()) FOR [Entered]
				ALTER TABLE [dbo].[T_Auth_Server_Logins] ADD  CONSTRAINT [DF_T_Auth_Server_Logins_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
				ALTER TABLE [dbo].[T_Auth_Server_Logins] ADD  CONSTRAINT [DF_T_Auth_Server_Logins_Enabled]  DEFAULT ((1)) FOR [Enabled]
			
			End
			
		End

	
		---------------------------------------------------
		-- Preview or update the server logins
		---------------------------------------------------
		
		Set @CurrentLocation = 'Finding server logins'

		;
		Set @S = ''
		Set @S = @S + ' WITH UserRoleNames (sid, Server_Role) AS ('
		Set @S = @S + '   SELECT sid, CASE WHEN sysadmin > 0      THEN Cast(''sysadmin'' AS varchar(15))      ELSE Cast('''' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION'
		Set @S = @S + '   SELECT sid, CASE WHEN securityadmin > 0 THEN Cast(''securityadmin'' AS varchar(15)) ELSE Cast('''' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION'
		Set @S = @S + '   SELECT sid, CASE WHEN serveradmin > 0   THEN Cast(''serveradmin'' AS varchar(15))   ELSE Cast('''' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION'
		Set @S = @S + '   SELECT sid, CASE WHEN setupadmin > 0    THEN Cast(''setupadmin'' AS varchar(15))    ELSE Cast('''' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION'
		Set @S = @S + '   SELECT sid, CASE WHEN processadmin > 0  THEN Cast(''processadmin'' AS varchar(15))  ELSE Cast('''' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION'
		Set @S = @S + '   SELECT sid, CASE WHEN diskadmin > 0     THEN Cast(''diskadmin'' AS varchar(15))     ELSE Cast('''' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION'
		Set @S = @S + '   SELECT sid, CASE WHEN dbcreator > 0     THEN Cast(''dbcreator'' AS varchar(15))     ELSE Cast('''' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION'
		Set @S = @S + '   SELECT sid, CASE WHEN bulkadmin > 0     THEN Cast(''bulkadmin'' AS varchar(15))     ELSE Cast('''' AS varchar(15)) END AS Server_Role FROM sys.syslogins '
		Set @S = @S + ' ),'
		Set @S = @S + ' UserRoleList (sid, Server_Roles) AS ('
		Set @S = @S + ' SELECT sid,  (STUFF(( SELECT CAST('', '' + Server_Role AS varchar(256))'
		Set @S = @S +				  ' FROM UserRoleNames AS ObjectSource'
		Set @S = @S +				  ' WHERE (UserRoleNames.sid = ObjectSource.sid )'
		Set @S = @S +				  ' ORDER BY Server_Role'
		Set @S = @S +				  ' FOR XML PATH ( '''' ) ), 1, 2, '''')) AS Server_Roles'
		Set @S = @S + ' FROM UserRoleNames'
		Set @S = @S + ' GROUP BY sid)'
		Set @S = @S + ' INSERT INTO #Tmp_Auth_Server_Logins (LoginName, User_Type_Desc, Server_Roles, Principal_ID)'
		Set @S = @S + ' SELECT LoginName, User_Type_Desc,'
		Set @S = @S +        ' CASE WHEN UserRoleList.Server_Roles LIKE '', %'' THEN Substring(UserRoleList.Server_Roles, 3, 100)'
		Set @S = @S +        ' ELSE UserRoleList.Server_Roles'
		Set @S = @S +        ' END AS Server_Roles,'
		Set @S = @S +        ' Principal_ID'
		Set @S = @S + ' FROM (SELECT name AS LoginName,'
		Set @S = @S +          ' default_database_name AS Default_DB,'
		Set @S = @S +          ' principal_id AS [Principal_ID],'
		Set @S = @S +          ' Cast(''SQL_USER'' AS varchar(32)) AS User_Type_Desc,'
		Set @S = @S +          ' sid'
		Set @S = @S +       ' FROM sys.sql_logins'
		Set @S = @S +       ' WHERE is_disabled = 0'
		Set @S = @S +       ' UNION'
		Set @S = @S +       ' SELECT L.loginname,'
		Set @S = @S +              ' L.dbname,'
		Set @S = @S +              ' NULL AS Principal_ID,'
		Set @S = @S +              ' CASE WHEN L.isntname = 0 THEN ''SQL_USER'' '
		Set @S = @S +              ' ELSE CASE WHEN L.isntgroup = 1 THEN ''WINDOWS_GROUP'' '
		Set @S = @S +                        ' WHEN L.isntuser = 1  THEN ''WINDOWS_USER'' '
		Set @S = @S +                        ' ELSE ''Unknown_Type'' '
		Set @S = @S +                   ' END'
		Set @S = @S +              ' END AS User_Type_Desc,'
		Set @S = @S +              ' sid'
		Set @S = @S +       ' FROM sys.syslogins AS L'
		Set @S = @S +       ' WHERE NOT L.sid IN ( SELECT sid FROM sys.sql_logins ) AND'
		Set @S = @S +             ' NOT L.name LIKE ''##MS%'' ) UnionQ'
		Set @S = @S + ' INNER JOIN UserRoleList'
		Set @S = @S +   ' ON UnionQ.sid = UserRoleList.sid'
		Set @S = @S + ' ORDER BY UnionQ.User_Type_Desc, UnionQ.LoginName'

		If @previewSql <> 0
			Print @S
		Else
		Begin -- <a1>
			exec sp_executesql @S
			
			If @infoOnly <> 0
			Begin
				SELECT *
				FROM #Tmp_Auth_Server_Logins
				ORDER BY User_Type_Desc, LoginName
			End
			Else
			Begin -- <b1>

				---------------------------------------------------
				-- Merge #Tmp_Auth_Server_Logins into T_Auth_Server_Logins
				---------------------------------------------------
				--				 
				Set @CurrentLocation = 'Merge #Tmp_Auth_Server_Logins into T_Auth_Server_Logins'

				MERGE dbo.T_Auth_Server_Logins AS t
				USING (SELECT LoginName, 
				              User_Type_Desc, 
				              Server_Roles, 
				              Principal_ID
				       FROM #Tmp_Auth_Server_Logins) as s
				ON ( t.LoginName = s.LoginName)
				WHEN MATCHED AND (
					t.User_Type_Desc <> s.User_Type_Desc OR
					t.Enabled = 0 OR
					ISNULL( NULLIF(t.Server_Roles, s.Server_Roles),
							NULLIF(s.Server_Roles, t.Server_Roles)) IS NOT NULL OR
					ISNULL( NULLIF(t.Principal_ID, s.Principal_ID),
							NULLIF(s.Principal_ID, t.Principal_ID)) IS NOT NULL					
					)
				THEN UPDATE SET 
					User_Type_Desc = s.User_Type_Desc,
					Server_Roles = s.Server_Roles,
					Principal_ID = s.Principal_ID,
					Last_Affected = GetDate(),
					Enabled = 1
				WHEN NOT MATCHED BY TARGET THEN
					INSERT(LoginName, User_Type_Desc, Server_Roles, Principal_ID, Entered, Last_Affected, Enabled)
					VALUES(s.LoginName, s.User_Type_Desc, s.Server_Roles, s.Principal_ID, GetDate(), GetDate(), 1)
				WHEN NOT MATCHED BY SOURCE THEN 
				    UPDATE SET
					Enabled = 0
				;
			
			End -- </b1>
		End -- </a1>

		
		---------------------------------------------------
		-- Populate #Tmp_DatabaseNames with the database names
		---------------------------------------------------
		
		Set @CurrentLocation = 'Parsing database name list'
		
		
		Declare @Delim char(1) = ','
		
		-- The following generates a Tally table with 256 rows
		-- then uses that table to split @databaseList on commas
		-- We could alternatively have used dbo.udfParseDelimitedList() but wanted to keep this procedure self-contained
		--
		;
		WITH
		  Pass0 as (select 1 as C union all select 1),          -- 2 rows
		  Pass1 as (select 1 as C from Pass0 as A, Pass0 as B), -- 4 rows
		  Pass2 as (select 1 as C from Pass1 as A, Pass1 as B), -- 16 rows
		  Pass3 as (select 1 as C from Pass2 as A, Pass2 as B), -- 256 rows
		  Tally as (select row_number() over(order by C) as Number from Pass3)	
		INSERT INTO #Tmp_DatabaseNames( Database_Name,
		                                IsValid )
		SELECT [Value] AS Database_Name,
		       0 AS IsValid
		FROM ( SELECT rowNum,
		              Row_Number() OVER ( Partition BY [Value] ORDER BY rowNum ) AS valueNum,
		              [Value]
		       FROM ( SELECT Row_Number() OVER ( ORDER BY CHARINDEX(@Delim, @databaseList + @Delim) ) AS rowNum,
		                     LTRIM(RTRIM(SUBSTRING(
		                       @databaseList, 
		                       Tally.[Number], 
		                       CHARINDEX(@Delim, @databaseList + @Delim, Tally.[Number]) - [Number]))) AS [Value]
		              FROM Tally
		              WHERE Tally.[Number] <= LEN(@databaseList) AND
		                    SUBSTRING(@Delim + @databaseList, Tally.[Number], LEN(@Delim)) = @Delim ) AS x 
		      ) SplitQ
		WHERE valueNum = 1
		ORDER BY rowNum;


		---------------------------------------------------
		-- Validate the database names
		---------------------------------------------------	
		--
		Set @CurrentLocation = 'Validating database names'
		
		-- Make sure none of the names are surrounded with square brackets
		--
		UPDATE #Tmp_DatabaseNames
		SET Database_Name = Substring(Database_Name, 2, Len(Database_Name)-2)
		WHERE Database_Name Like '[[]%]'
		--
		Select @myRowCount = @@RowCount, @myError = @@Error
		
		
		UPDATE #Tmp_DatabaseNames
		SET IsValid = 1,
		    Database_ID = SystemDBs.Database_ID,
		    Database_Name = SystemDBs.name
		FROM #Tmp_DatabaseNames
		     INNER JOIN sys.databases SystemDBs
		       ON #Tmp_DatabaseNames.Database_Name = SystemDBs.name
		--
		Select @myRowCount = @@RowCount, @myError = @@Error


		If Exists (Select * From #Tmp_DatabaseNames Where IsValid = 0)
		Begin
			Set @message = 'One or more invalid databases: '
			
			SELECT @message = @message + Database_Name + ', '
			FROM #Tmp_DatabaseNames
			WHERE IsValid = 0
			
			Set @message = Substring(@message, 1, Len(@message) - 2)
			Print @message
			
			If @infoOnly <> 0
				SELECT @message as Warning
				
			Delete From #Tmp_DatabaseNames Where IsValid = 0
		End
		
		If Not Exists (Select * From #Tmp_DatabaseNames)
		Begin
			If @message = ''
			Begin
				Set @message = 'Database list was empty'
				Print @message

				If @infoOnly <> 0
					SELECT @message as Warning
				
			End
			
			Goto Done
		End
		
		---------------------------------------------------
		-- Iterate through the database list
		---------------------------------------------------
		--

		Declare @entryID int = 0
		Declare @continue tinyint = 1

		Declare @DatabaseID int
		Declare @DatabaseName nvarchar(128)
		
		While @continue > 0
		Begin -- <a2>

			SELECT TOP 1 
				@DatabaseID = Database_ID,
				@DatabaseName = Database_Name,
				@EntryID = Entry_ID
			FROM #Tmp_DatabaseNames
			WHERE Entry_ID > @EntryID
			ORDER BY Entry_ID
			--
			Select @myRowCount = @@RowCount, @myError = @@Error
			
			
			If @myRowCount = 0
			Begin
				Set @Continue = 0
			End
			Else
			Begin -- <b2>
				
				---------------------------------------------------
				-- Store the database logins and roles in #Tmp_Auth_Database_LoginsAndRoles
				---------------------------------------------------
				--
				Set @CurrentLocation = 'Populating #Tmp_Auth_Database_LoginsAndRoles for database ' + @DatabaseName + ' (ID ' + Cast(@DatabaseID as varchar(12)) + ')'
				
				Set @S = ''
				Set @S = @S + ' WITH RoleMembers (member_principal_id, role_principal_id) AS ('
				Set @S = @S + '   SELECT rm1.member_principal_id, rm1.role_principal_id'
				Set @S = @S +   ' FROM [' + @DatabaseName + '].sys.database_role_members rm1 ( NOLOCK )'
				Set @S = @S +   ' UNION ALL'
				Set @S = @S +   ' SELECT d.member_principal_id, rm.role_principal_id'
				Set @S = @S +   ' FROM [' + @DatabaseName + '].sys.database_role_members rm ( NOLOCK )'
				Set @S = @S +   '   INNER JOIN RoleMembers AS d'
				Set @S = @S +     '   ON rm.member_principal_id = d.role_principal_id'
				Set @S = @S + ' ),'
				Set @S = @S + ' UserRoleQuery AS ('
				Set @S = @S +   ' SELECT DISTINCT mp.name AS database_user,'
				Set @S = @S +     ' rp.name AS database_role,'
				Set @S = @S +     ' drm.member_principal_id'
				Set @S = @S +   ' FROM RoleMembers drm'
				Set @S = @S +     ' INNER JOIN [' + @DatabaseName + '].sys.database_principals rp'
				Set @S = @S +       ' ON (drm.role_principal_id = rp.principal_id)'
				Set @S = @S +     ' INNER JOIN [' + @DatabaseName + '].sys.database_principals mp'
				Set @S = @S +       ' ON (drm.member_principal_id = mp.principal_id)'
				Set @S = @S + ' )'
				Set @S = @S + ' INSERT INTO #Tmp_Auth_Database_LoginsAndRoles ('
				Set @S = @S +   ' Database_ID, Database_Name, Principal_ID, UserName, LoginName, User_Type, User_Type_Desc, Database_Roles)'
				Set @S = @S + ' SELECT ' + Cast(@DatabaseID as varchar(12)) + ', '
				Set @S = @S +       ' ''' + @DatabaseName + ''', '
				Set @S = @S +       ' dbp.Principal_ID,'
				Set @S = @S +       ' dbp.name AS UserName,'
				Set @S = @S +       ' [' + @DatabaseName + '].sys.syslogins.LoginName,'
				Set @S = @S +       ' dbp.[type] AS User_Type,'
				Set @S = @S +       ' dbp.type_desc AS User_Type_Desc,'
				Set @S = @S +       ' RoleListByUser.Database_Roles'
				Set @S = @S + ' FROM [' + @DatabaseName + '].sys.database_principals dbp '
				Set @S = @S +      ' LEFT OUTER JOIN [' + @DatabaseName + '].sys.syslogins'
				Set @S = @S +         ' ON dbp.sid = [' + @DatabaseName + '].sys.syslogins.sid'
				Set @S = @S +      ' LEFT OUTER JOIN ( SELECT UserRoleQuery.database_user,'
				Set @S = @S +                               ' UserRoleQuery.member_principal_id,'
				Set @S = @S +                               ' (STUFF(( SELECT CAST('', '' + database_role AS varchar(256))'
				Set @S = @S +                                        ' FROM UserRoleQuery AS UserRoleQuery2'
				Set @S = @S +                                        ' WHERE UserRoleQuery.database_user = UserRoleQuery2.database_user'
				Set @S = @S +                                       '  ORDER BY database_role'
				Set @S = @S +                                ' FOR XML PATH ( '''' ) ), 1, 2, '''')) AS Database_Roles'
				Set @S = @S +                        ' FROM UserRoleQuery'
				Set @S = @S +                        ' GROUP BY UserRoleQuery.database_user, UserRoleQuery.member_principal_id ) AS RoleListByUser'
				Set @S = @S +        ' ON dbp.principal_id = RoleListByUser.member_principal_id'
				Set @S = @S + ' WHERE NOT dbp.[type] IN (''R'') AND'
				Set @S = @S +       ' NOT dbp.name IN (''INFORMATION_SCHEMA'', ''guest'', ''sys'')'
				Set @S = @S + ' GROUP BY dbp.principal_id, [' + @DatabaseName + '].sys.syslogins.loginname, dbp.name, dbp.[type], dbp.type_desc, RoleListByUser.Database_Roles'
				Set @S = @S + ' ORDER BY dbp.name'
				
				If @previewSql <> 0
					Print @S
				Else
				Begin -- <c>

					Truncate Table #Tmp_Auth_Database_LoginsAndRoles
					exec sp_executesql @S
					
					If @infoOnly <> 0
					Begin
						SELECT *
						FROM #Tmp_Auth_Database_LoginsAndRoles
						ORDER BY UserName
					End
					Else
					Begin -- <d>
					
						---------------------------------------------------
						-- Delete invalid rows from T_Auth_Database_LoginsAndRoles
						---------------------------------------------------
						--
						Set @CurrentLocation = 'Deleting invalid rows in T_Auth_Database_LoginsAndRoles for database ' + @DatabaseName + ' (ID ' + Cast(@DatabaseID as varchar(12)) + ')'
						
						If Exists (
							SELECT * 
							FROM T_Auth_Database_LoginsAndRoles 
							WHERE Database_Name = @DatabaseName AND Database_ID <> @DatabaseID OR
							      Database_Name <> @DatabaseName AND Database_ID = @DatabaseID
							)
						Begin
							
							DELETE FROM T_Auth_Database_LoginsAndRoles
							WHERE Database_Name = @DatabaseName AND Database_ID <> @DatabaseID OR
							      Database_Name <> @DatabaseName AND Database_ID = @DatabaseID
							--
							Select @myRowCount = @@RowCount, @myError = @@Error
							
							Set @message = 'Deleted ' + Cast(@myRowCount as varchar(12)) + ' rows from T_Auth_Database_LoginsAndRoles ' + 
							              ' that were for database ' + @DatabaseName + ' yet did not have database ID ' + Cast(@DatabaseID as varchar(12))
							              
							Exec PostLogEntry 'Warning', @message, 'CacheServerUsersAndPermissions'

						End

						---------------------------------------------------
						-- Merge #Tmp_Auth_Database_LoginsAndRoles into T_Auth_Database_LoginsAndRoles
						---------------------------------------------------
						--
						Set @CurrentLocation = 'Merge #Tmp_Auth_Database_LoginsAndRoles into T_Auth_Database_LoginsAndRoles for database ' + @DatabaseName + ' (ID ' + Cast(@DatabaseID as varchar(12)) + ')'

						MERGE dbo.T_Auth_Database_LoginsAndRoles AS t
						USING (SELECT Database_ID,
									  Database_Name,
									  Principal_ID,
									  UserName,
									  LoginName,
									  User_Type,
									  User_Type_Desc,
									  Database_Roles
								FROM #Tmp_Auth_Database_LoginsAndRoles) as s
						ON ( t.Database_ID = s.Database_ID AND t.Principal_ID = s.Principal_ID)
						WHEN MATCHED AND (
						    t.UserName <> s.UserName OR
						    t.User_Type <> s.User_Type OR
						    t.Enabled = 0 OR
						    ISNULL( NULLIF(t.LoginName, s.LoginName),
						            NULLIF(s.LoginName, t.LoginName)) IS NOT NULL OR
						    ISNULL( NULLIF(t.User_Type_Desc, s.User_Type_Desc),
						            NULLIF(s.User_Type_Desc, t.User_Type_Desc)) IS NOT NULL OR
						    ISNULL( NULLIF(t.Database_Roles, s.Database_Roles),
						            NULLIF(s.Database_Roles, t.Database_Roles)) IS NOT NULL						    
						    )
						THEN UPDATE SET 
						    Database_Name = s.Database_Name,
						    UserName = s.UserName,
						    LoginName = s.LoginName,
						    User_Type = s.User_Type,
						    User_Type_Desc = s.User_Type_Desc,
						    Database_Roles = s.Database_Roles,
						    Last_Affected = GetDate(),
						    Enabled = 1
						WHEN NOT MATCHED BY TARGET THEN
						    INSERT(Database_ID, Database_Name, Principal_ID, UserName, LoginName, 
						           User_Type, User_Type_Desc, Database_Roles, 
						           Entered, Last_Affected, Enabled)
						    VALUES(s.Database_ID, s.Database_Name, s.Principal_ID, s.UserName, s.LoginName, 
						           s.User_Type, s.User_Type_Desc, s.Database_Roles, 
						           GetDate(), GetDate(), 1)
						;
						
						-- Update extra rows to have Enabled = 0
						--
						UPDATE T_Auth_Database_LoginsAndRoles
						SET Enabled = 0
						FROM T_Auth_Database_LoginsAndRoles target
						     LEFT OUTER JOIN #Tmp_Auth_Database_LoginsAndRoles source
						       ON target.Database_ID = source.Database_ID AND
						          target.Principal_ID = source.Principal_ID
						WHERE target.Database_ID = @DatabaseID AND
						      source.Database_ID IS NULL
						--
						Select @myRowCount = @@RowCount, @myError = @@Error

					End -- </d>
				End -- </c>

				---------------------------------------------------
				-- Store the database permissions in #Tmp_Auth_Database_Permissions
				---------------------------------------------------
				--
				Set @CurrentLocation = 'Populating #Tmp_Auth_Database_Permissions for database ' + @DatabaseName + ' (ID ' + Cast(@DatabaseID as varchar(12)) + ')'
				
				Set @S = ''
				Set @S = @S + ' WITH SourceData (Principal_ID, User_Type, User_Type_Desc, Role_Or_User, Permission, ObjectName, Sort_Order)'
				Set @S = @S + ' AS ('
				Set @S = @S +   ' SELECT p.principal_id,'
				Set @S = @S +          ' p.type,'
				Set @S = @S +          ' p.type_desc,'
				Set @S = @S +          ' p.name,'
				Set @S = @S +          ' d.permission_name,'
				Set @S = @S +          ' o.name,'
				Set @S = @S +          ' CASE WHEN d.permission_name = ''EXECUTE'' THEN 1'
				Set @S = @S +               ' WHEN d.permission_name = ''SELECT'' THEN 2'
				Set @S = @S +               ' WHEN d.permission_name = ''INSERT'' THEN 3'
				Set @S = @S +               ' WHEN d.permission_name = ''UPDATE'' THEN 4'
				Set @S = @S +               ' WHEN d.permission_name = ''DELETE'' THEN 5'
				Set @S = @S +               ' ELSE 5'
				Set @S = @S +          ' END AS Sort_Order'
				Set @S = @S +   ' FROM [' + @DatabaseName + '].sys.database_principals AS p'
				Set @S = @S +     ' INNER JOIN [' + @DatabaseName + '].sys.database_permissions AS d'
				Set @S = @S +       ' ON d.grantee_principal_id = p.principal_id'
				Set @S = @S +     ' INNER JOIN [' + @DatabaseName + '].sys.objects AS o'
				Set @S = @S +       ' ON o.object_id = d.major_id'
				Set @S = @S +   ' WHERE NOT (p.name = ''public'' AND (o.name LIKE ''dt[_]%'' OR o.name IN (''dtproperties''))) AND'
				Set @S = @S +   ' NOT d.permission_name IN (''view definition'', ''alter'', ''REFERENCES'') AND'
				Set @S = @S +   ' NOT o.name IN (''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'')'
				Set @S = @S +   ' )'
				Set @S = @S +   ' INSERT INTO #Tmp_Auth_Database_Permissions(Database_ID, Database_Name, Principal_ID, Role_Or_User, User_Type, User_Type_Desc, Permission, Object_Names, Sort_Order)'
				Set @S = @S + ' SELECT ' + Cast(@DatabaseID as varchar(12)) + ', '
				Set @S = @S +       ' ''' + @DatabaseName + ''', '
				Set @S = @S +       ' Principal_ID,'
				Set @S = @S +       ' Role_Or_User,'
				Set @S = @S +       ' User_Type,'
				Set @S = @S +       ' User_Type_Desc,'
				Set @S = @S +       ' Permission,'
				Set @S = @S +       ' (STUFF(( SELECT CAST('', '' + ObjectName AS varchar(256))'
				Set @S = @S +                ' FROM SourceData AS ObjectSource'
				Set @S = @S +                ' WHERE (SourceData.Role_Or_User = ObjectSource.Role_Or_User AND'
				Set @S = @S +                       ' SourceData.Permission = ObjectSource.Permission)'
				Set @S = @S +                ' ORDER BY ObjectName'
				Set @S = @S +        ' FOR XML PATH ( '''' ) ), 1, 2, '''')) AS Object_Names,'
				Set @S = @S +        ' Sort_Order'
				Set @S = @S + ' FROM SourceData'
				Set @S = @S + ' GROUP BY Principal_ID, User_Type, User_Type_Desc, Role_Or_User, Permission, Sort_Order'
				Set @S = @S + ' ORDER BY Role_Or_User, Sort_Order;'
				
				If @previewSql <> 0
					Print @S
				Else
				Begin -- <e>
				
					Truncate Table #Tmp_Auth_Database_Permissions
					exec sp_executesql @S
					
					If @infoOnly <> 0
					Begin
						SELECT *
						FROM #Tmp_Auth_Database_Permissions
						ORDER BY Role_Or_User, Sort_Order
					End
					Else
					Begin -- <f>
					
						---------------------------------------------------
						-- Delete invalid rows from T_Auth_Database_Permissions
						---------------------------------------------------
						--
						Set @CurrentLocation = 'Deleting invalid rows in T_Auth_Database_Permissions for database ' + @DatabaseName + ' (ID ' + Cast(@DatabaseID as varchar(12)) + ')'

						If Exists (
							SELECT * 
							FROM T_Auth_Database_Permissions 
							WHERE Database_Name = @DatabaseName AND Database_ID <> @DatabaseID OR
							      Database_Name <> @DatabaseName AND Database_ID = @DatabaseID
							)
						Begin
							
							DELETE FROM T_Auth_Database_Permissions
							WHERE Database_Name = @DatabaseName AND Database_ID <> @DatabaseID OR
							      Database_Name <> @DatabaseName AND Database_ID = @DatabaseID
							--
							Select @myRowCount = @@RowCount, @myError = @@Error
							
							Set @message = 'Deleted ' + Cast(@myRowCount as varchar(12)) + ' rows from T_Auth_Database_Permissions ' + 
							              ' that were for database ' + @DatabaseName + ' yet did not have database ID ' + Cast(@DatabaseID as varchar(12))
							              
							Exec PostLogEntry 'Warning', @message, 'CacheServerUsersAndPermissions'

						End

						---------------------------------------------------
						-- Merge #Tmp_Auth_Database_Permissions into T_Auth_Database_Permissions
						---------------------------------------------------
						--
						Set @CurrentLocation = 'Merge #Tmp_Auth_Database_Permissions into T_Auth_Database_Permissions for database ' + @DatabaseName + ' (ID ' + Cast(@DatabaseID as varchar(12)) + ')'
						 
						MERGE dbo.T_Auth_Database_Permissions AS t
						USING (SELECT Database_ID,
									  Database_Name,
									  Principal_ID,
									  Role_Or_User,
									  User_Type,
									  User_Type_Desc,
									  Permission,
									  Object_Names,
									  Sort_Order FROM #Tmp_Auth_Database_Permissions) as s
						ON ( t.Database_ID = s.Database_ID AND t.Permission = s.Permission AND t.Principal_ID = s.Principal_ID)
						WHEN MATCHED AND (
						    t.Role_Or_User <> s.Role_Or_User OR
						    t.User_Type <> s.User_Type OR
						    t.Enabled = 0 OR
						    t.Sort_Order <> s.Sort_Order OR
						    ISNULL( NULLIF(t.User_Type_Desc, s.User_Type_Desc),
						            NULLIF(s.User_Type_Desc, t.User_Type_Desc)) IS NOT NULL OR
						    ISNULL( NULLIF(t.Object_Names, s.Object_Names),
						            NULLIF(s.Object_Names, t.Object_Names)) IS NOT NULL
						    )
						THEN UPDATE SET 
						    Database_Name = s.Database_Name,
						    Role_Or_User = s.Role_Or_User,
						    User_Type = s.User_Type,
						    User_Type_Desc = s.User_Type_Desc,
						    Object_Names = s.Object_Names,
						    Sort_Order = s.Sort_Order,
						    Last_Affected = GetDate(),
						    Enabled = 1
						WHEN NOT MATCHED BY TARGET THEN
						    INSERT(Database_ID, Database_Name, Principal_ID, Role_Or_User, 
						           User_Type, User_Type_Desc, Permission, Object_Names, 
						           Sort_Order, Entered, Last_Affected, Enabled)
						    VALUES(s.Database_ID, s.Database_Name, s.Principal_ID, s.Role_Or_User, 
						           s.User_Type, s.User_Type_Desc, s.Permission, s.Object_Names, 
						           s.Sort_Order, GetDate(), GetDate(), 1)
						;

						-- Update extra rows to have Enabled = 0
						--
						UPDATE T_Auth_Database_Permissions
						SET Enabled = 0
						FROM T_Auth_Database_Permissions target
						     LEFT OUTER JOIN #Tmp_Auth_Database_Permissions source
						       ON target.Database_ID = source.Database_ID AND
						          target.Principal_ID = source.Principal_ID
						WHERE target.Database_ID = @DatabaseID AND
						      source.Database_ID IS NULL
						--
						Select @myRowCount = @@RowCount, @myError = @@Error

					End -- </f>
				End -- </e>

			End -- </b2>
		End -- </a2>

		If @infoOnly = 0
		Begin
			Print 'View the cached data with:'
			Print 'SELECT * FROM T_Auth_Server_Logins ORDER BY User_Type_Desc, LoginName'
			Print 'SELECT * FROM T_Auth_Database_LoginsAndRoles ORDER BY Database_Name, UserName'
			Print 'SELECT * FROM T_Auth_Database_Permissions ORDER BY Database_Name, Role_Or_User, Sort_Order'
		End
		
	END TRY
	BEGIN CATCH 
		-- Error caught
		If @@TranCount > 0
			Rollback
		
		Declare @CallingProcName varchar(128) = IsNull(ERROR_PROCEDURE(), 'CacheServerUsersAndPermissions')
				exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 0, 
										@ErrorNum = @myError output, @message = @message output
										
		Set @message = 'Exception: ' + @message
		print @message
		Goto Done
	END CATCH

Done:

	Return @myError

GO

WITH UserRoleNames (sid, Server_Role)
AS (
  SELECT sid, CASE WHEN sysadmin > 0 THEN Cast('sysadmin' AS varchar(15)) ELSE Cast('' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION
  SELECT sid, CASE WHEN securityadmin > 0 THEN Cast('securityadmin' AS varchar(15)) ELSE Cast('' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION
  SELECT sid, CASE WHEN serveradmin > 0 THEN Cast('serveradmin' AS varchar(15)) ELSE Cast('' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION
  SELECT sid, CASE WHEN setupadmin > 0 THEN Cast('setupadmin' AS varchar(15)) ELSE Cast('' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION
  SELECT sid, CASE WHEN processadmin > 0 THEN Cast('processadmin' AS varchar(15)) ELSE Cast('' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION
  SELECT sid, CASE WHEN diskadmin > 0 THEN Cast('diskadmin' AS varchar(15)) ELSE Cast('' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION
  SELECT sid, CASE WHEN dbcreator > 0 THEN Cast('dbcreator' AS varchar(15)) ELSE Cast('' AS varchar(15)) END AS Server_Role FROM sys.syslogins UNION
  SELECT sid, CASE WHEN bulkadmin > 0 THEN Cast('bulkadmin' AS varchar(15)) ELSE Cast('' AS varchar(15)) END AS Server_Role FROM sys.syslogins 
),
UserRoleList (sid, Server_Roles) AS (
SELECT sid,  (STUFF(( SELECT CAST(', ' + Server_Role AS varchar(256))
                FROM UserRoleNames AS ObjectSource
                WHERE (UserRoleNames.sid = ObjectSource.sid )
                ORDER BY Server_Role
                FOR XML PATH ( '' ) ), 1, 2, '')) AS Server_Roles
FROM UserRoleNames
GROUP BY sid)
-- INSERT INTO T_Auth_Server_Logins (LoginName, User_Type_Desc, Server_Roles, Principal_ID)
SELECT LoginName,
       User_Type_Desc,
       CASE
           WHEN UserRoleList.Server_Roles LIKE ', %' THEN Substring(UserRoleList.Server_Roles, 3, 100)
           ELSE UserRoleList.Server_Roles
       END AS Server_Roles,
       Principal_ID
-- INTO T_Auth_Server_Logins
FROM (SELECT name AS LoginName,
             default_database_name AS Default_DB,
             principal_id AS [Principal_ID],
             Cast('SQL_USER' AS varchar(32)) AS User_Type_Desc,
             sid
      FROM sys.sql_logins
      WHERE is_disabled = 0
      UNION
      SELECT L.loginname,
             L.dbname,
             NULL AS Principal_ID,
             CASE
                 WHEN L.isntname = 0 THEN 'SQL_USER'
                 ELSE CASE
                          WHEN L.isntgroup = 1 THEN 'WINDOWS_GROUP'
                          WHEN L.isntuser = 1 THEN 'WINDOWS_USER'
                          ELSE 'Unknown_Type'
                      END
             END AS User_Type_Desc,
             sid
      FROM sys.syslogins AS L
      WHERE NOT L.sid IN ( SELECT sid
                           FROM sys.sql_logins ) AND
            NOT L.name LIKE '##MS%' 
     ) UnionQ
     INNER JOIN UserRoleList
       ON UnionQ.sid = UserRoleList.sid
ORDER BY UnionQ.User_Type_Desc, UnionQ.LoginName

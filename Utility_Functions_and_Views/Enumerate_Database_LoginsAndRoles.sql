WITH RoleMembers (member_principal_id, role_principal_id) 
AS 
(
  SELECT rm1.member_principal_id,
         rm1.role_principal_id
  FROM sys.database_role_members rm1 ( NOLOCK )
  UNION ALL
  SELECT d.member_principal_id,
         rm.role_principal_id
  FROM sys.database_role_members rm ( NOLOCK )
       INNER JOIN RoleMembers AS d
         ON rm.member_principal_id = d.role_principal_id
),
UserRoleQuery AS (
  SELECT DISTINCT mp.name AS database_user,
                  rp.name AS database_role,
                  drm.member_principal_id
  FROM RoleMembers drm
       JOIN sys.database_principals rp
         ON (drm.role_principal_id = rp.principal_id)
       JOIN sys.database_principals mp
         ON (drm.member_principal_id = mp.principal_id)
)
-- INSERT INTO T_Auth_Database_LoginsAndRoles (database_id, Database_Name, Principal_ID, UserName, LoginName, User_Type, User_Type_Desc, Database_Roles)
SELECT Db_Id(), 
       Db_Name(), 
       dbp.Principal_ID,
       dbp.name AS UserName,
       sys.syslogins.LoginName,
       dbp.[type] AS User_Type,
       dbp.type_desc AS User_Type_Desc,
       RoleListByUser.Database_Roles
-- INTO T_Auth_Database_LoginsAndRoles
FROM sys.database_principals dbp LEFT OUTER JOIN
     sys.syslogins
       ON dbp.sid = sys.syslogins.sid
     LEFT OUTER JOIN ( SELECT UserRoleQuery.database_user,
                              UserRoleQuery.member_principal_id,
                              (STUFF(( SELECT CAST(', ' + database_role AS varchar(256))
                                       FROM UserRoleQuery AS UserRoleQuery2
                                       WHERE UserRoleQuery.database_user 
                                             = UserRoleQuery2.database_user
                                       ORDER BY database_role
                                       FOR XML PATH ( '' ) ), 1, 2, '')) AS Database_Roles
                       FROM UserRoleQuery
                       GROUP BY UserRoleQuery.database_user, UserRoleQuery.member_principal_id ) AS RoleListByUser
       ON dbp.principal_id = RoleListByUser.member_principal_id
WHERE NOT dbp.[type] IN ('R') AND
      NOT dbp.name IN ('INFORMATION_SCHEMA', 'guest', 'sys')
GROUP BY dbp.principal_id, sys.syslogins.loginname, dbp.name, dbp.[type], dbp.type_desc, RoleListByUser.Database_Roles
ORDER BY dbp.name

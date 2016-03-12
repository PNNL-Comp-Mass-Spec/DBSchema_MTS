WITH SourceData (Principal_ID, User_Type, User_Type_Desc, Role_Or_User, Permission, ObjectName, PermissionSortOrder)
AS (
  SELECT p.principal_id,
         p.type,
         p.type_desc,
         p.name,
         d.permission_name,
         o.name,
         CASE
             WHEN d.permission_name = 'EXECUTE' THEN 1
             WHEN d.permission_name = 'SELECT' THEN 2
             WHEN d.permission_name = 'INSERT' THEN 3
             WHEN d.permission_name = 'UPDATE' THEN 4
             WHEN d.permission_name = 'DELETE' THEN 5
             ELSE 5
         END AS PermissionSortOrder
  FROM sys.database_principals AS p
     JOIN sys.database_permissions AS d
         ON d.grantee_principal_id = p.principal_id
     JOIN sys.objects AS o
         ON o.object_id = d.major_id
  WHERE NOT (p.name = 'public' AND (o.name LIKE 'dt[_]%' OR o.name IN ('dtproperties'))) AND
        NOT d.permission_name IN ('view definition', 'alter', 'REFERENCES') AND
        NOT o.name IN ('fn_diagramobjects', 'sp_alterdiagram', 'sp_creatediagram', 'sp_dropdiagram', 'sp_helpdiagramdefinition', 'sp_helpdiagrams', 'sp_renamediagram')
)
-- INSERT INTO T_Auth_Database_Permissions(Database_ID, Database_Name, Principal_ID, Role_Or_User, User_Type, User_Type_Desc, Permission, Object_Names)
SELECT Db_Id(), 
       Db_Name(), 
       Principal_ID,
       Role_Or_User,
       User_Type,
       User_Type_Desc,
       Permission,
       (STUFF(( SELECT CAST(', ' + ObjectName AS varchar(256))
                FROM SourceData AS ObjectSource
                WHERE (SourceData.Role_Or_User = ObjectSource.Role_Or_User AND
                       SourceData.Permission = ObjectSource.Permission)
                ORDER BY ObjectName
                FOR XML PATH ( '' ) ), 1, 2, '')) AS Object_Names
-- INTO T_Auth_Database_Permissions
FROM SourceData
GROUP BY Principal_ID, User_Type, User_Type_Desc, Role_Or_User, Permission, PermissionSortOrder
ORDER BY Role_Or_User, PermissionSortOrder;

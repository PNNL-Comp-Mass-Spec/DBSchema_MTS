-- From https://www.simple-talk.com/blogs/2013/12/02/tsql-code-to-explore-keys-in-a-database/

SELECT DISTINCT object_schema_name(Keys.Parent_Object_ID) + '.' + object_name(Keys.Parent_Object_ID) AS TheTable
FROM sys.Key_Constraints keys
     INNER JOIN sys.Index_columns TheColumns
       ON Keys.Parent_Object_ID = theColumns.Object_ID AND
          unique_index_ID = index_ID
     INNER JOIN sys.columns c
       ON TheColumns.object_ID = c.object_ID AND
          TheColumns.column_ID = c.column_ID
WHERE TYPE = 'UQ' AND
      is_nullable = 1

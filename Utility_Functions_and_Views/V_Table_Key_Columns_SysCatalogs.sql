-- From https://www.simple-talk.com/blogs/2013/12/02/tsql-code-to-explore-keys-in-a-database/

Select
 object_schema_name(Keys.Parent_Object_ID)+'.'+object_name(Keys.Parent_Object_ID) as TheTable,--table & Schema
 Keys.name as TheKey, --the name of the key
 replace(lower(max(type_desc)),'_',' ') as [Type],
 case when count(*)=1 then Col_Name(TheColumns.Object_Id, min(TheColumns.Column_Id))
   else --otherwise the list of columns
      Coalesce(stuff((
        SELECT
         ', ' + Col_Name(Ic.Object_Id, Ic.Column_Id)
         + CASE
           WHEN Is_Descending_Key <> 0 THEN ' DESC'
           ELSE '' END
       FROM Sys.Index_Columns AS Ic
       WHERE Ic.Index_Id = TheColumns.Index_Id AND Ic.Object_Id = TheColumns.Object_Id
        and is_included_column=0
       ORDER BY Key_Ordinal
       FOR Xml PATH (''), TYPE).value('.', 'varchar(max)')
     ,1,2,''), '?')
  end AS Columns
from sys.Key_Constraints keys
 inner join sys.Index_columns TheColumns
   on Keys.Parent_Object_ID=theColumns.Object_ID
   and unique_index_ID=index_ID
group by TheColumns.object_ID, TheColumns.Index_Id, Keys.name, keys.schema_ID, Keys.Parent_Object_ID
order by keys.name
 
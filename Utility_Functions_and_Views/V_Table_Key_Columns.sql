-- From https://www.simple-talk.com/blogs/2013/12/02/tsql-code-to-explore-keys-in-a-database/

SELECT c.TABLE_CATALOG+'.'+c.TABLE_SCHEMA+'.'+c.TABLE_NAME,
       Constraint_TYPE , c.CONSTRAINT_NAME,
       Coalesce(stuff((SELECT ', ' + cc.COLUMN_NAME
                       FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE cc
                       WHERE cc.CONSTRAINT_NAME=c.CONSTRAINT_NAME
                         and cc.TABLE_CATALOG=c.TABLE_CATALOG
                         and cc.TABLE_SCHEMA=c.TABLE_SCHEMA
                       ORDER BY ORDINAL_POSITION
                       FOR Xml PATH (''), TYPE).value('.', 'varchar(max)'),1,2,''), '?') AS Columns
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE u
     inner join INFORMATION_SCHEMA.TABLE_CONSTRAINTS c
       on u.CONSTRAINT_NAME=c.CONSTRAINT_NAME
WHERE CONSTRAINT_TYPE in ('PRIMARY KEY','UNIQUE', 'Check')   -- Options are: CHECK, UNIQUE, PRIMARY KEY or FOREIGN KEY
GROUP BY  c.TABLE_CATALOG,c.TABLE_SCHEMA,c.TABLE_NAME, Constraint_TYPE , c.CONSTRAINT_NAME
ORDER BY c.TABLE_CATALOG+'.'+c.TABLE_SCHEMA+'.'+c.TABLE_NAME
-- From https://www.simple-talk.com/blogs/2013/12/02/tsql-code-to-explore-keys-in-a-database/

Select object_schema_name(a.object_ID)+'.'+object_name(a.object_ID) as [Table],
       sum(case when a.name is null then 0 else 1 end) as [indexes],
       sum(case when a.is_unique<>0 then 1 else 0 end) as Unique_indexes,
       sum(case when a.is_unique_constraint<>0 then 1 else 0 end) as [Unique Key],
       sum(case when a.is_primary_key<>0 then 1 else 0 end) as [Primary Key],
       sum(case when a.type =1 then 1 else 0 end) as [Clustered],
       sum(case when a.type =2 then 1 else 0 end) as [Non-clustered],
       sum(case when a.type =3 then 1 else 0 end) as [XML],
       sum(case when a.type =4 then 1 else 0 end) as [Spatial],
       sum(case when a.type =5 then 1 else 0 end) as [Clustered Columnstore],
       sum(case when a.type =6 then 1 else 0 end) as [Nonclustered columnstore]
FROM sys.indexes a
     INNER JOIN sys.tables
       ON a.object_ID = sys.tables.object_id
WHERE object_schema_name(a.object_ID) <> 'sys'
      -- and a.name is not null
GROUP BY a.object_ID
Order By sum(case when a.name is null then 0 else 1 end) desc
WITH cteSource AS 
(
    SELECT 'MSMSJob' AS Category, MAX(Cast(Created as Date)) AS MostRecent, Count(*) as Items
    FROM T_Analysis_Description
)
SELECT DB_Name() AS ThisDB,
       A.Items AS 'MSMS Jobs',
       A.MostRecent AS 'Most recent MSMS Job'
FROM ( SELECT MostRecent, Items
       FROM cteSource
       WHERE Category = 'MSMSJob' ) A;

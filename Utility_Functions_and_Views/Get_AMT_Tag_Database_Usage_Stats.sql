WITH cteSource AS 
(
    SELECT 'MSMSJob' AS Category, MAX(Cast(Created_PMT_Tag_DB as Date)) AS MostRecent, Count(*) as Items
    FROM T_Analysis_Description
    UNION
    SELECT 'HMSJob' AS Category, MAX(Cast(Created as Date)) AS MostRecent, Count(*) as Items
    FROM T_FTICR_Analysis_Description
    UNION
    SELECT 'PMTask' AS Category, MAX(Cast(PM_Start as Date)) AS MostRecent, Count(*) as Items
    FROM T_Peak_Matching_Task
    UNION
    SELECT 'QD' AS Category, MAX(Cast(Last_Affected as Date)) AS MostRecent, Count(*) as Items
    FROM T_Quantitation_Description 
    UNION
    SELECT 'AMTTag' as Category, MAX(Cast(Last_Affected as Date)) as MostRecent, Count(*) as Items
    FROM T_Mass_Tags
)
SELECT DB_Name() AS ThisDB,
       E.Items AS 'AMT Tags',
       A.Items AS 'MSMS Jobs',
       B.Items AS 'HMS Jobs',
       C.Items AS 'PM Tasks',
       D.Items AS 'QD Results',
       E.MostRecent AS 'Most Recent AMT Tag Updated',
       A.MostRecent AS 'Most recent MSMS Job',
       B.MostRecent AS 'Most recent HMS Job',
       C.MostRecent AS 'Most recent PM',
       D.MostRecent AS 'Most recent QD'
FROM ( SELECT MostRecent, Items
       FROM cteSource
       WHERE Category = 'MSMSJob' ) A
     FULL OUTER JOIN ( SELECT MostRecent, Items
                  FROM cteSource
                  WHERE Category = 'HMSJob' ) B ON 1=1
     FULL OUTER JOIN ( SELECT MostRecent, Items
                  FROM cteSource
                  WHERE Category = 'PMTask' ) C ON 1=1
     FULL OUTER JOIN ( SELECT MostRecent, Items
                  FROM cteSource
                  WHERE Category = 'QD' ) D ON 1=1
     FULL OUTER JOIN ( SELECT MostRecent, Items
                  FROM cteSource
                  WHERE Category = 'AMTTag' ) E ON 1=1;

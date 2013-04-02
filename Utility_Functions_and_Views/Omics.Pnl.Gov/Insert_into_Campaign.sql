-- Lookup by campaign name
SELECT 'INSERT INTO campaign (id, campaign_name, created, comment)
VALUES (' + Convert(varchar(12), id) + ',''' + Campaign + ''', ''' + Convert(varchar(32), Created, 120) + ''', ''' + Comment + ''')'
FROM (
SELECT Campaign_ID as id, Campaign_Num as Campaign, CM_created As Created, ISNULL(CM_Comment, '') as Comment
FROM T_Campaign
WHERE Campaign_Num = 'Topdown_method_development'
) LookupQ

-- Lookup by data package
SELECT 'INSERT INTO campaign (id, campaign_name, created, comment)
VALUES (' + Convert(varchar(12), id) + ',''' + Campaign + ''', ''' + Convert(varchar(32), Created, 120) + ''', ''' + Comment + ''')'
FROM (SELECT DISTINCT Campaign_ID as id, Campaign_Num as Campaign, CM_created As Created, ISNULL(CM_Comment, '') as Comment
      FROM V_Experiment_Detail_Report_Ex EDR INNER JOIN
          T_Campaign C ON EDR.Campaign = C.Campaign_Num INNER JOIN
          T_Dataset DS ON EDR.ID = DS.Exp_ID
      WHERE (DS.Dataset_Num IN
              (SELECT dataset
            FROM S_V_Data_Package_Datasets_Export
            WHERE data_package_id = 767))) LookupQ


INSERT INTO campaign (id, campaign_name, created, comment)
VALUES (2653,'Topdown_method_development', '2011-05-11 12:31:27', '')
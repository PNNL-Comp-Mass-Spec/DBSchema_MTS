SELECT 'INSERT INTO campaign (id, campaign_name, created, comment)
VALUES (' + Convert(varchar(12), id) + ',''' + Campaign + ''', ''' + Convert(varchar(32), Created, 120) + ''', ''' + Comment + ''')'
FROM (
SELECT Campaign_ID as id, Campaign_Num as Campaign, CM_created As Created, ISNULL(CM_Comment, '') as Comment
FROM T_Campaign
WHERE Campaign_Num = 'Topdown_method_development'
) LookupQ


INSERT INTO campaign (id, campaign_name, created, comment)
VALUES (2653,'Topdown_method_development', '2011-05-11 12:31:27', '')
-- Validate results

-- Query Omics.pnl.gov using Navicat Sql
SELECT publication_id,
       entity_type,
       count(*) AS items
FROM publication_entity_xref
WHERE publication_id BETWEEN 1075 AND 1078
GROUP BY publication_id, entity_type
ORDER BY publication_id, entity_type


-- Query DMS5 using SSMS
Declare @DataPackageIDStart int = 734
Declare @DataPackageIDEnd int = 734


SELECT data_package_id, 'Dataset' as Entity_Type, COUNT(*) as Items
FROM (SELECT data_package_id, DDR.ID AS id
      FROM T_Dataset_Archive DA INNER JOIN
          V_Dataset_Detail_Report_Ex DDR ON DA.AS_Dataset_ID = DDR.ID INNER JOIN
          T_Experiments E ON DDR.Experiment = E.Experiment_Num INNER JOIN (
          SELECT data_package_id, Dataset 
                              FROM S_V_Data_Package_Datasets_Export
                              WHERE data_package_id Between @DataPackageIDStart and @DataPackageIDEnd
          ) DPkg ON DDR.Dataset = DPkg.Dataset                
) LookupQ
GROUP BY data_package_id
UNION
Select data_package_id, 'Experiment' as Entity_Type, COUNT(*) as Items
FROM (
	SELECT DISTINCT data_package_id, EDR.ID
	FROM V_Experiment_Detail_Report_Ex EDR INNER JOIN
	    T_Campaign C ON EDR.Campaign = C.Campaign_Num INNER JOIN
	    T_Dataset DS ON EDR.ID = DS.Exp_ID INNER JOIN (
          SELECT data_package_id, Dataset 
                              FROM S_V_Data_Package_Datasets_Export
                              WHERE data_package_id Between @DataPackageIDStart and @DataPackageIDEnd
          ) DPkg ON DS.Dataset_Num = DPkg.Dataset
) LookupQ
GROUP BY data_package_id
ORDER BY entity_type, data_package_id

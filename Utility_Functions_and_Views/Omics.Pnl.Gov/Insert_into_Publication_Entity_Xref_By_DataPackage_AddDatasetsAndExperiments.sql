Declare @DataPackageID int = 734
Declare @PublicationID int = 1077

SELECT 'INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)
VALUES (' + Convert(varchar(12), @PublicationID) + ',' + Convert(varchar(12), ID) + ', ''Dataset'');'
FROM (SELECT DDR.ID AS id
      FROM T_Dataset_Archive DA INNER JOIN
          V_Dataset_Detail_Report_Ex DDR ON DA.AS_Dataset_ID = DDR.ID INNER JOIN
          T_Experiments E ON DDR.Experiment = E.Experiment_Num
      WHERE (DDR.Dataset IN ( SELECT Dataset 
                              FROM S_V_Data_Package_Datasets_Export
                              WHERE data_package_id = @DataPackageID) )
) LookupQ
UNION
SELECT 'INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)
VALUES (' + Convert(varchar(12), @PublicationID) + ',' + Convert(varchar(12), id) + ', ''Experiment'');'
FROM (
	SELECT DISTINCT 
	    EDR.ID
	FROM V_Experiment_Detail_Report_Ex EDR INNER JOIN
	    T_Campaign C ON EDR.Campaign = C.Campaign_Num INNER JOIN
	    T_Dataset DS ON EDR.ID = DS.Exp_ID
	WHERE (DS.Dataset_Num IN
	        (SELECT dataset
	      FROM S_V_Data_Package_Datasets_Export
	      WHERE data_package_id = @DataPackageID))
) LookupQ


INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)  VALUES (1077,103356, 'Experiment');
INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)  VALUES (1077,276942, 'Dataset');

Declare @PublicationID int = 1080

/*
 * Note: if you receive a duplicate key error, then the relationship already exists
 *
 * If desired, you could delete extra entries of a given type, for example:
 *   DELETE FROM publication_entity_xref where publication_id = 1084 and entity_type = 'Job';
 *
 */

SELECT 'INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)
VALUES (' + Convert(varchar(12), @PublicationID) + ',' + Convert(varchar(12), ID) + ', ''Dataset'');'
FROM (SELECT DDR.ID AS id
      FROM T_Dataset_Archive DA INNER JOIN
          V_Dataset_Detail_Report_Ex DDR ON DA.AS_Dataset_ID = DDR.ID INNER JOIN
          T_Experiments E ON DDR.Experiment = E.Experiment_Num
      WHERE (DDR.ID IN ( 209001, 208992, 208990, 208986, 208982, 208967, 208961, 208952, 208824, 208748 ))
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
	WHERE (DS.Dataset_ID IN (209001, 208992, 208990, 208986, 208982, 208967, 208961, 208952, 208824, 208748))
) LookupQ


INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)  VALUES (1077,103356, 'Experiment');
INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)  VALUES (1077,276942, 'Dataset');

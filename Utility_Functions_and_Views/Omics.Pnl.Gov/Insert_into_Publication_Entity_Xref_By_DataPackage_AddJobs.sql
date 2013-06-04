Declare @DataPackageID int = 804
Declare @PublicationID int = 1083

SELECT 'INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)
VALUES (' + Convert(varchar(12), @PublicationID) + ',' + Convert(varchar(12), Job) + ', ''Job'');'
FROM (SELECT Job
      FROM S_V_Data_Package_Analysis_Jobs_Export
      WHERE data_package_id = @DataPackageID
) LookupQ

INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)  VALUES (1083,706657, 'Job');
INSERT INTO publication_entity_xref (publication_id, entity_id, entity_type)  VALUES (1083,706658, 'Job');
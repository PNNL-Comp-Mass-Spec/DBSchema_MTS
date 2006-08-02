set identity_insert dbo.T_SP_List on
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (1, 0, N'GetAllMassTagDatabases', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (2, 0, N'GetAllMassTagDatabasesStatisticsReport', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (3, 0, N'GetAllPeptideDatabases', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (4, 0, N'GetAllPeptideDatabasesStatisticsReport', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (5, 0, N'GetAllProteins', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (6, 0, N'GetAllProteinsOutputColumns', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (40, 4, N'GetDBSchemaVersionByDBName', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (37, 4, N'GetDBTypeAndSchemaVersion', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (8, 0, N'GetExperimentsSummary', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (39, 4, N'GetInstrumentNamesForDB', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (11, 0, N'GetMassTags', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (13, 0, N'GetMassTagsOutputColumns', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (14, 0, N'GetPeptideIdentificationMethods', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (17, 0, N'GetProteinJobPeptideCrosstab', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (18, 0, N'GetProteinsIdentified', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (20, 0, N'GetQRollupEntityMap', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (21, 3, N'GetQRollupsSummary', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (41, 5, N'QCMSMSIDCountsByJob', N'Returns list of identifications passing given filters for the given instrument')
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (42, 6, N'QCMSMSMetricByJobArea', N'Returns a metric value representing area for all jobs matching the given job filters')
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (43, 6, N'QCMSMSMetricByJobSN', N'Returns a metric value representing S/N for all jobs matching the given job filters')
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (22, 0, N'QRPeptideCrosstabOutputColumns', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (23, 0, N'QRProteinCrosstabOutputColumns', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (24, 0, N'WebGetMassTags', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (25, 4, N'WebGetPickerList', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (26, 0, N'WebGetProteinsIdentified', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (27, 3, N'WebGetQRollupsSummary', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (28, 3, N'WebGetQuantitationDescription', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (31, 2, N'WebQRPeptideCrosstab', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (32, 2, N'WebQRProteinCrosstab', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (33, 2, N'WebQRProteinsWithPeptidesCrosstab', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (34, 2, N'WebQRRetrievePeptidesMultiQID', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (35, 2, N'WebQRRetrieveProteinsMultiQID', NULL)
INSERT INTO dbo.T_SP_List
  (SP_ID, Category_ID, SP_Name, SP_Description)
  VALUES (36, 2, N'WebQRSummary', NULL)
set identity_insert dbo.T_SP_List off

go

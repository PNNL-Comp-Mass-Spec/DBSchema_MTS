/****** Object:  Table [T_SP_List] ******/
/****** RowCount: 33 ******/
SET IDENTITY_INSERT [T_SP_List] ON
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (1,0,'GetAllMassTagDatabases',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (2,0,'GetAllMassTagDatabasesStatisticsReport',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (3,0,'GetAllPeptideDatabases',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (4,0,'GetAllPeptideDatabasesStatisticsReport',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (5,0,'GetAllProteins',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (6,0,'GetAllProteinsOutputColumns',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (40,4,'GetDBSchemaVersionByDBName',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (37,4,'GetDBTypeAndSchemaVersion',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (8,0,'GetExperimentsSummary',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (39,4,'GetInstrumentNamesForDB',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (11,0,'GetMassTags',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (13,0,'GetMassTagsOutputColumns',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (14,0,'GetPeptideIdentificationMethods',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (17,0,'GetProteinJobPeptideCrosstab',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (18,0,'GetProteinsIdentified',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (20,0,'GetQRollupEntityMap',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (21,3,'GetQRollupsSummary',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (41,5,'QCMSMSIDCountsByJob','Returns list of identifications passing given filters for the given instrument')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (42,6,'QCMSMSMetricByJobArea','Returns a metric value representing area for all jobs matching the given job filters')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (43,6,'QCMSMSMetricByJobSN','Returns a metric value representing S/N for all jobs matching the given job filters')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (22,0,'QRPeptideCrosstabOutputColumns',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (23,0,'QRProteinCrosstabOutputColumns',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (24,0,'WebGetMassTags',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (25,4,'WebGetPickerList',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (26,0,'WebGetProteinsIdentified',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (27,3,'WebGetQRollupsSummary',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (28,3,'WebGetQuantitationDescription',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (31,2,'WebQRPeptideCrosstab',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (32,2,'WebQRProteinCrosstab',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (33,2,'WebQRProteinsWithPeptidesCrosstab',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (34,2,'WebQRRetrievePeptidesMultiQID',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (35,2,'WebQRRetrieveProteinsMultiQID',null)
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (36,2,'WebQRSummary',null)
SET IDENTITY_INSERT [T_SP_List] OFF

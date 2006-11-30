/****** Object:  Table [T_SP_List] ******/
/****** RowCount: 33 ******/
SET IDENTITY_INSERT [T_SP_List] ON
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (1,0,'GetAllMassTagDatabases','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (2,0,'GetAllMassTagDatabasesStatisticsReport','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (3,0,'GetAllPeptideDatabases','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (4,0,'GetAllPeptideDatabasesStatisticsReport','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (5,0,'GetAllProteins','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (6,0,'GetAllProteinsOutputColumns','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (40,4,'GetDBSchemaVersionByDBName','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (37,4,'GetDBTypeAndSchemaVersion','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (8,0,'GetExperimentsSummary','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (39,4,'GetInstrumentNamesForDB','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (11,0,'GetMassTags','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (13,0,'GetMassTagsOutputColumns','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (14,0,'GetPeptideIdentificationMethods','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (17,0,'GetProteinJobPeptideCrosstab','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (18,0,'GetProteinsIdentified','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (20,0,'GetQRollupEntityMap','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (21,3,'GetQRollupsSummary','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (41,5,'QCMSMSIDCountsByJob','Returns list of identifications passing given filters for the given instrument')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (42,6,'QCMSMSMetricByJobArea','Returns a metric value representing area for all jobs matching the given job filters')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (43,6,'QCMSMSMetricByJobSN','Returns a metric value representing S/N for all jobs matching the given job filters')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (22,0,'QRPeptideCrosstabOutputColumns','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (23,0,'QRProteinCrosstabOutputColumns','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (24,0,'WebGetMassTags','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (25,4,'WebGetPickerList','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (26,0,'WebGetProteinsIdentified','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (27,3,'WebGetQRollupsSummary','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (28,3,'WebGetQuantitationDescription','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (31,2,'WebQRPeptideCrosstab','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (32,2,'WebQRProteinCrosstab','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (33,2,'WebQRProteinsWithPeptidesCrosstab','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (34,2,'WebQRRetrievePeptidesMultiQID','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (35,2,'WebQRRetrieveProteinsMultiQID','')
INSERT INTO [T_SP_List] (SP_ID, Category_ID, SP_Name, SP_Description) VALUES (36,2,'WebQRSummary','')
SET IDENTITY_INSERT [T_SP_List] OFF
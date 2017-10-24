/****** Object:  View [dbo].[V_DMS_Analysis_Job_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Analysis_Job_Import]
AS
SELECT Job, Dataset, Experiment, Campaign, DatasetID, Organism, 
    InstrumentName, InstrumentClass, AnalysisTool, Completed, 
    ParameterFileName, SettingsFileName, OrganismDBName, 
    ProteinCollectionList, ProteinOptions, StoragePathClient, 
    StoragePathServer, DatasetFolder, ResultsFolder, 
    SeparationSysType, ResultType, DS_created, EnzymeID
FROM S_V_Analysis_Jobs


GO

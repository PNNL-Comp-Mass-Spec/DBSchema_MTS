/****** Object:  View [dbo].[V_DMS_Analysis_Job_Import_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_DMS_Analysis_Job_Import_Ex]
AS
SELECT Job, Priority, Dataset, Experiment, Campaign, DatasetID, 
    Organism, InstrumentName, InstrumentClass, AnalysisTool, 
    Completed, ParameterFileName, SettingsFileName, 
    OrganismDBName, Convert(varchar(max), ProteinCollectionList) AS ProteinCollectionList, ProteinOptions, 
    StoragePathClient, StoragePathServer, DatasetFolder, 
    ResultsFolder, Owner, Comment, SeparationSysType, 
    ResultType, [Dataset Int Std], DS_created, EnzymeID, 
    Labelling, [PreDigest Int Std], [PostDigest Int Std], Processor
FROM GIGASAX.DMS5.dbo.V_Analysis_Job_Export_Ex AS T1


GO

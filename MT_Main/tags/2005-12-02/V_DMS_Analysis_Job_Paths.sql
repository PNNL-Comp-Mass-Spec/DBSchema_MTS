SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Analysis_Job_Paths]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Analysis_Job_Paths]
GO

CREATE VIEW dbo.V_DMS_Analysis_Job_Paths
AS
SELECT Job, Dataset, DatasetID, InstrumentClass, InstrumentName, 
    VolClient, VolServer, StoragePath, DatasetFolder, 
    ResultsFolder
FROM (SELECT AJ.AJ_jobID AS Job, DS.Dataset_Num AS Dataset, 
          AJ.AJ_datasetID AS DatasetID, 
          InsName.IN_class AS InstrumentClass, 
          InsName.IN_name AS InstrumentName, 
          SP.SP_vol_name_client AS VolClient, 
          SP.SP_vol_name_server AS VolServer, 
          SP.SP_path AS StoragePath, 
          DS.DS_folder_name AS DatasetFolder, 
          AJ.AJ_resultsFolderName AS ResultsFolder
      FROM Gigasax.dms5.dbo.T_Analysis_Job AJ INNER JOIN
          Gigasax.dms5.dbo.T_Dataset DS ON 
          AJ.AJ_datasetID = DS.Dataset_ID INNER JOIN
          Gigasax.dms5.dbo.T_Instrument_Name InsName ON 
          DS.DS_instrument_name_ID = InsName.Instrument_ID INNER
           JOIN
          Gigasax.dms5.dbo.t_storage_path SP ON 
          DS.DS_storage_path_ID = SP.SP_path_ID
      WHERE (AJ.AJ_StateID = 4)) T1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


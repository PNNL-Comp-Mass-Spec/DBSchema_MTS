/****** Object:  View [dbo].[V_DMS_Dataset_Import_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Dataset_Import_Ex]
AS
SELECT Src.Dataset,
       Src.Experiment,
       Src.Organism,
       Src.Instrument,
       Src.[Separation Type],
       Src.[LC Column],
       Src.[Wellplate Number],
       Src.[Well Number],
       Src.[Dataset Int Std],
       Src.Type,
       Src.Operator,
       Src.Comment,
       Src.Rating,
       Src.Request,
       Src.State,
       Src.Created,
       Src.[Folder Name],
       Src.[Dataset Folder Path],
       Src.[Storage Folder],
       Src.Storage,
       Src.ID,
       Src.[Acquisition Start],
       Src.[Acquisition End],
       Src.[Scan Count],
       Src.[PreDigest Int Std],
       Src.[PostDigest Int Std],
       Src.[File Size MB],
       Src.Instrument_Data_Purged
FROM GIGASAX.DMS5.dbo.V_Dataset_Export Src



GO

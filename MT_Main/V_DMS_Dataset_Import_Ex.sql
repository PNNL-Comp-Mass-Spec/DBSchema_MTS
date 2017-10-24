/****** Object:  View [dbo].[V_DMS_Dataset_Import_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Dataset_Import_Ex]
AS
SELECT Dataset,
       Experiment,
       Organism,
       Instrument,
       [Separation Type],
       [LC Column],
       [Wellplate Number],
       [Well Number],
       [Dataset Int Std],
       Type,
       Operator,
       Comment,
       Rating,
       Request,
       State,
       Created,
       [Folder Name],
       [Dataset Folder Path],
       [Storage Folder],
       Storage,
       ID,
       [Acquisition Start],
       [Acquisition End],
       [Scan Count],
       [PreDigest Int Std],
       [PostDigest Int Std],
       [File Size MB],
       Instrument_Data_Purged
FROM S_V_Datasets


GO

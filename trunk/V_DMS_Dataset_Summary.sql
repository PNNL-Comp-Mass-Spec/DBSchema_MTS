/****** Object:  View [dbo].[V_DMS_Dataset_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_DMS_Dataset_Summary]
AS
SELECT Dataset, Experiment, Organism, Instrument, 
    [Separation Type], [LC Column], [Wellplate Number], 
    [Well Number], [Predigest Int Std], [Postdigest Int Std], Type, 
    Operator, Comment, Rating, Request, Created, [Folder Name], 
    State, [Dataset Folder Path], [Archive State], 
    [Archive Folder Path], [Compressed State], [Compressed Date], 
    Jobs, ID, [Acquisition Start], [Acquisition End], [Scan Count], 
    [File Size (MB)], [File Info Updated]
FROM GIGASAX.DMS5.dbo.V_Dataset_Detail_Report_Ex AS t1


GO

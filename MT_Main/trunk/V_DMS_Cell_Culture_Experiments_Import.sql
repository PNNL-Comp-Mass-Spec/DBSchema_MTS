/****** Object:  View [dbo].[V_DMS_Cell_Culture_Experiments_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Cell_Culture_Experiments_Import
AS
SELECT CellCulture, Experiment
FROM GIGASAX.DMS5.dbo.V_Export_Cell_Culture_Experiments t1

GO

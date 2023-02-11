/****** Object:  View [dbo].[V_DMS_Cell_Culture_Experiments_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Cell_Culture_Experiments_Import]
AS
SELECT CellCulture, Experiment
FROM S_V_Cell_Culture_Experiments


GO

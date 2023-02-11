/****** Object:  View [dbo].[V_DMS_Cell_Culture_Jobs_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Cell_Culture_Jobs_Import]
AS
SELECT CellCulture, CellCultureID, JobID
FROM S_V_Cell_Culture_Jobs


GO

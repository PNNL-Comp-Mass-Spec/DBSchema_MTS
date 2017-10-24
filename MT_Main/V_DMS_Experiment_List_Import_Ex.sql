/****** Object:  View [dbo].[V_DMS_Experiment_List_Import_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Experiment_List_Import_Ex]
AS
SELECT [Experiment],
       [Researcher],
       [Organism],
       [Reason for Experiment],
       [Comment],
       [Created],
       [Sample Concentration],
       [Digestion Enzyme],
       [Lab Notebook],
       [Campaign],
       [Plant/Animal Tissue],
       [Cell Cultures],
       [Labelling],
       [Predigest Int Std],
       [Postdigest Int Std],
       [Alkylated],
       [Request],
       [Tissue ID],
       [Experiment Groups],
       [Datasets],
       [Most Recent Dataset],
       [Factors],
       [Experiment Files],
       [Experiment Group Files],
       [ID],
       [Container],
       [Location],
       [Material Status],
       [Last Used],
       [Wellplate Number],
       [Well Number],
       [Barcode]
FROM S_V_Experiment_Detail_Report_Ex


GO

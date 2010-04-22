/****** Object:  View [dbo].[V_Peak_Matching_Requests_List_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Peak_Matching_Requests_List_Report
AS
SELECT     Request, Name, Tool, Mass_Tag_Database AS [Mass Tag Database], Analysis_Jobs AS [Analysis Jobs], Parameter_file AS [Parameter file], 
                      MinimumHighNormalizedScore AS [Min. High Normalized Score], MinimumHighDiscriminantScore AS [Min. High Discriminan tScore], 
                      MinimumPeptideProphetProbability AS [Min.Peptide Prophet Probability], MinimumPMTQualityScore AS [Min. PMTQuality Score], 
                      Limit_To_PMTs_From_Dataset AS [Limit To PMTs From Dataset], Comment, Requester, Created
FROM         dbo.T_Peak_Matching_Requests

GO

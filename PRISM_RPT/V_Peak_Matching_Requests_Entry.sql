/****** Object:  View [dbo].[V_Peak_Matching_Requests_Entry] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW V_Peak_Matching_Requests_Entry AS 
 SELECT 
	Request AS Request,
	Name AS Name,
	Tool AS Tool,
	Mass_Tag_Database AS MassTagDatabase,
	Analysis_Jobs AS AnalysisJobs,
	Parameter_file AS Parameterfile,
	MinimumHighNormalizedScore AS MinimumHighNormalizedScore,
	MinimumHighDiscriminantScore AS MinimumHighDiscriminantScore,
	MinimumPeptideProphetProbability AS MinimumPeptideProphetProbability,
	MinimumPMTQualityScore AS MinimumPMTQualityScore,
	Limit_To_PMTs_From_Dataset AS LimitToPMTsFromDataset,
	Comment AS Comment,
	Requester AS Requester
FROM T_Peak_Matching_Requests

GO

INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Campaign', N'MS/MS analysis job import, FTICR analysis job import', 1, 99, N'Allow MS/MS and FTICR analysis jobs that are associated with this campaign')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Campaign_and_Experiment', N'MS/MS analysis job import, FTICR analysis job import', 0, 99, N'Allow MS/MS and FTICR analysis jobs that are associated with this campaign and experiment; separate the campaign and experiment using a comma; these values are checked separately from the experiment inclusion/exclusion and dataset inclusion/exclusion filters')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Custom_SP_MSMS', N'Custom Processing', 0, 99, N'Enter a stored procedure name to run it during Master Update')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Dataset', N'MS/MS analysis job import, FTICR analysis job import', 1, 99, N'Allow MS/MS and FTICR analysis jobs that are associated with this dataset name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Dataset_DMS_Creation_Date_Minimum', N'MS/MS analysis job import, FTICR analysis job import', 0, 1, N'Earliest allowable dataset creation date in DMS')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Dataset_Exclusion', N'MS/MS analysis job import, FTICR analysis job import', 1, 99, N'Exclude MS/MS and FTICR analysis jobs that are associated with this dataset name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'DB_Schema_Version', N'Info only', 1, 1, N'Version of MTDB schema')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Experiment', N'MS/MS analysis job import, FTICR analysis job import', 1, 99, N'Allow MS/MS and FTICR analysis jobs that are associated with this experiment name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Experiment_Exclusion', N'MS/MS analysis job import, FTICR analysis job import', 1, 99, N'Exclude MS/MS and FTICR analysis jobs that are associated with this experiment name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'GANET_Avg_Use_Max_Obs_Area_In_Job_Enabled', N'Average GANET Computation', 1, 1, N'If 1, then uses the peptide with the maximum observed area in the job; if 0, then uses the first occurrence')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'GANET_Fit_Minimum_Average_GANET', N'Average GANET Computation', 1, 1, N'Minimum GANET Fit to require when computing average GANET values for mass tags')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'GANET_Fit_Minimum_Import', N'MS/MS analysis job import', 1, 1, N'Allow MS/MS jobs that have GANET Fit values of this value or higher')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'GANET_RSquared_Minimum_Average_GANET', N'Average GANET Computation', 1, 1, N'Minimum GANET R-Squared to require when computing average GANET values for mass tags (takes precedence over GANET_Fit_Minimum_Average_GANET)')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'GANET_RSquared_Minimum_Import', N'MS/MS analysis job import', 1, 1, N'Allow MS/MS jobs that have GANET R-Squared values of this value or higher (takes precedence over GANET_Fit_Minimum_Import)')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'GANET_Weighted_Average_Enabled', N'Average GANET Computation', 1, 1, N'If 1, then weights GANET Averages for each Mass Tag using the Discriminant Score values')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'General_Statistics_Update_Interval', N'Update Interval', 1, 1, N'Time interval (in hours) to update the general statistics table')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Job_Info_DMS_Update_Interval', N'Update Interval', 1, 1, N'Time interval (in hours) to validate the analysis job details against those stored in DMS')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'MS_Instrument_Class', N'FTICR analysis job import', 1, 99, N'Allow FTICR analysis jobs that are associated with datasets that were produced on this type of MS instrument')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'MS_Result_Type', N'FTICR analysis job import', 1, 99, N'Allow FTICR analysis jobs that produce this type of result')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Organism', N'Info only', 1, 99, N'Not used for filtering - information only')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Organism_DB_File_Name', N'MS/MS analysis job import', 1, 99, N'Allow MS/MS analysis jobs that were performed with this organism database file (FASTA)')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Parameter_File_Name', N'MS/MS analysis job import', 1, 99, N'Allow MS/MS analysis jobs that were performed with this parameter file')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Peptide_DB_Name', N'MS/MS analysis job import, Peptide hit import', 1, 99, N'Import MS/MS jobs and their associated peptide hits from these peptide databases')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Peptide_Import_Filter_ID', N'Peptide hit import', 0, 99, N'Allow peptide hits that have satisfied this filter')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Peptide_Obs_Count_Filter_ID', N'Info Only', 1, 1, N'Filter ID to use when determining the MS/MS peptide observation count that passes a filter')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'PMT_Quality_Score_Set_ID_and_Value', N'PMT Quality Score Computation', 0, 99, N'Filter Sets from DMS to test PMTs against for populating the PMT_Quality_Score field in T_Mass_Tags; separate the ID and the value with a comma; if no value, then assumes value = 1.  Can include an experiment name filter as a third, comma separated parameter, for example: 121, 2, Tao-HME%')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'PMT_Quality_Score_Uses_Filtered_Peptide_Obs_Count', N'PMT Quality Score Computation', 1, 1, N'If 0, then column Number_of_Peptides is used for PMT QS calculations.  If 1 then column Peptide_Obs_Count_Passing_Filter is used')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Protein_DB_Name', N'Protein Import', 1, 99, N'Import protein definitions from this database')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Separation_Type', N'MS/MS analysis job import, FTICR analysis job import', 1, 99, N'Allow MS/MS and FTICR analysis jobs that are associated with datasets that use this separation method')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Settings_File_Name', N'MS/MS analysis job import', 1, 99, N'Allow MS/MS analysis jobs that were performed with this settings file')

go

INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Campaign', N'MS/MS analysis job import', 0, 99, N'Allow MS/MS analysis jobs that are associated with this campaign')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'DB_Schema_Version', N'Info only', 1, 1, N'Version of MTDB schema')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Experiment', N'MS/MS analysis job import', 0, 99, N'Allow MS/MS analysis jobs that are associated with this experiment name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character.')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Experiment_Exclusion', N'MS/MS analysis job import', 0, 99, N'Exclude MS/MS analysis jobs that are associated with this experiment name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character.')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'General_Statistics_Update_Interval', N'Update Interval', 1, 1, N'Time interval (in hours) to update the general statistics table')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Import_Result_Type', N'MS/MS analysis job import', 1, 99, N'Determines types of analysis results imported into T_Analysis_Description')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Job_Info_DMS_Update_Interval', N'Update Interval', 1, 1, N'Time interval (in hours) to validate the analysis job details against those stored in DMS')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'MTDB_Export_Filter_ID', N'MS/MS results filter', 0, 99, N'Filters to check all peptides against; used when exporting data to MTDBs')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'NET_Update_Batch_Size', N'NET Regression', 1, 1, N'Number of jobs to export at a time for NET regression')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'NET_Update_Max_Peptide_Count', N'NET Regression', 1, 1, N'Maximum number of peptide results to include in the peptideGANET file; limits the number of jobs included to achieve this value')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Organism_DB_File_Name', N'MS/MS analysis job import', 0, 99, N'Allow MS/MS analysis jobs that were performed with this organism database file (FASTA)')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Peptide_Import_Filter_ID', N'MS/MS analysis job import', 1, 1, N'Filter to apply when importing peptides from MS/MS synopsis ifles')

go

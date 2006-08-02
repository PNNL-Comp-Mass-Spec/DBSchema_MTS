INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Campaign', N'MS/MS analysis job import', 0, 99, N'Allow MS/MS analysis jobs that are associated with this campaign')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Campaign_Exclusion', N'MS/MS analysis job import', 0, 99, N'Exclude MS/MS analysis jobs that are associated with this campaign name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character.')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Dataset_DMS_Creation_Date_Minimum', N'MS/MS analysis job import, FTICR analysis job import', 0, 1, N'Earliest allowable dataset creation date in DMS')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'DB_Schema_Version', N'Info only', 1, 1, N'Version of MTDB schema')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Enzyme_ID', N'MS/MS analysis job import', 0, 99, N'Allow MS/MS analysis jobs that are associated with this Enzyme ID')
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
  VALUES (N'Organism_DB_File_Name', N'MS/MS analysis job import', 0, 99, N'Allow MS/MS analysis jobs that were performed with this organism database file (FASTA); matches the OrganismDBName field in V_DMS_Analysis_Job_Import_Ex')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Peptide_Import_Filter_ID', N'MS/MS analysis job import', 1, 1, N'Filter to apply when importing peptides from MS/MS synopsis ifles')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Protein_Collection_and_Protein_Options_Combo', N'MS/MS analysis job import', 0, 99, N'Allow MS/MS analysis jobs that were searched against this precise protein collection list and protein options list; separate the two items using a semicolon; the items can contain wildcards; will compare against the full ProteinCollectionList and ProteinOptionsList fields in V_DMS_Analysis_Job_Import_Ex')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Protein_Collection_Filter', N'MS/MS analysis job import', 0, 99, N'Allow MS/MS analysis jobs that were searched against this protein collection; matches the ProteinCollectionList field in V_DMS_Analysis_Job_Import_Ex (either an exact match or a match to one of the items in the list)')
INSERT INTO dbo.T_Process_Config_Parameters
  VALUES (N'Seq_Direction_Filter', N'MS/MS analysis job import', 0, 99, N'Sequence direction values to allow; only used for jobs with a Protein_Collection_List defined')
go

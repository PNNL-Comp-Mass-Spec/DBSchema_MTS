/****** Object:  Table [T_Process_Config_Parameters] ******/
/****** RowCount: 24 ******/
/****** Columns: Name, Function, Min_Occurrences, Max_Occurrences, Description ******/
INSERT INTO [T_Process_Config_Parameters] VALUES ('Campaign','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that are associated with this campaign')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Campaign_Exclusion','MS/MS analysis job import',0,99,'Exclude MS/MS analysis jobs that are associated with this campaign name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character.')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Dataset_DMS_Creation_Date_Minimum','MS/MS analysis job import, FTICR analysis job import',0,1,'Earliest allowable dataset creation date in DMS')
INSERT INTO [T_Process_Config_Parameters] VALUES ('DB_Schema_Version','Info only',1,1,'Version of MTDB schema')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Enzyme_ID','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that are associated with this Enzyme ID')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Experiment','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that are associated with this experiment name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character.')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Experiment_Exclusion','MS/MS analysis job import',0,99,'Exclude MS/MS analysis jobs that are associated with this experiment name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character.')
INSERT INTO [T_Process_Config_Parameters] VALUES ('General_Statistics_Update_Interval','Update Interval',1,1,'Time interval (in hours) to update the general statistics table')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Import_Result_Type','MS/MS analysis job import',1,99,'Determines types of analysis results imported into T_Analysis_Description')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Job_Info_DMS_Update_Interval','Update Interval',1,1,'Time interval (in hours) to validate the analysis job details against those stored in DMS')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MTDB_Export_Custom_Filter_ID_and_Table','MS/MS results filter',0,99,'Custom filter set ID and filter criteria table')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MTDB_Export_Filter_ID','MS/MS results filter',0,99,'Filters to check all peptides against; used when exporting data to MTDBs')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MTDB_Export_Filter_ID_by_Experiment','MS/MS results filter',0,99,'Filters to check all peptides against; only check jobs with this experiment (can be an exact name match or a name portion, containing a percent sign as a wildcard character)')
INSERT INTO [T_Process_Config_Parameters] VALUES ('NET_Regression_Param_File_Name','NET Regression',0,1,'Name of the parameter file to use when performing NET regression (stored at \\gigasax\DMS_Parameter_Files\NET_Regression\)')
INSERT INTO [T_Process_Config_Parameters] VALUES ('NET_Regression_Param_File_Name_by_Campaign','NET Regression',0,99,'NET Regression parameter file to use for samples with the given Campaign (as defined in T_Analysis_Description); separate the file name and the label name with a comma')
INSERT INTO [T_Process_Config_Parameters] VALUES ('NET_Regression_Param_File_Name_by_Sample_Label','NET Regression',0,99,'NET Regression parameter file to use for samples with the given sample label (Labelling column in T_Analysis_Description); separate the file name and the label name with a comma')
INSERT INTO [T_Process_Config_Parameters] VALUES ('NET_Update_Batch_Size','NET Regression',1,1,'Number of jobs to export at a time for NET regression')
INSERT INTO [T_Process_Config_Parameters] VALUES ('NET_Update_Max_Peptide_Count','NET Regression',1,1,'Maximum number of peptide results to include in the peptideGANET file; limits the number of jobs included to achieve this value')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Organism_DB_File_Name','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that were performed with this organism database file (FASTA); matches the OrganismDBName field in V_DMS_Analysis_Job_Import_Ex')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Import_Filter_ID','MS/MS analysis job import',1,1,'Filter to apply when importing peptides from MS/MS synopsis files')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Import_Filter_ID_by_Campaign','MS/MS analysis job import',0,99,'Filter to apply when importing peptides from MS/MS synopsis files for a given campaign.  Separate the filter ID and the Campaign name with a comma')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Protein_Collection_and_Protein_Options_Combo','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that were searched against this precise protein collection list and protein options list; separate the two items using a semicolon; the items can contain wildcards; will compare against the full ProteinCollectionList and ProteinOptionsList fields in V_DMS_Analysis_Job_Import_Ex')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Protein_Collection_Filter','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that were searched against this protein collection; matches the ProteinCollectionList field in V_DMS_Analysis_Job_Import_Ex (either an exact match or a match to one of the items in the list)')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Seq_Direction_Filter','MS/MS analysis job import',0,99,'Sequence direction values to allow; only used for jobs with a Protein_Collection_List defined')

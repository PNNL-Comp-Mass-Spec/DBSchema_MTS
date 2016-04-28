/****** Object:  Table [T_Process_Config_Parameters] ******/
/****** RowCount: 48 ******/
/****** Columns: Name, Function, Min_Occurrences, Max_Occurrences, Description ******/
INSERT INTO [T_Process_Config_Parameters] VALUES ('Campaign','MS/MS analysis job import, FTICR analysis job import',1,99,'Allow MS/MS and FTICR analysis jobs that are associated with this campaign')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Campaign_and_Experiment','MS/MS analysis job import, FTICR analysis job import',0,99,'Allow MS/MS and FTICR analysis jobs that are associated with this campaign and experiment; separate the campaign and experiment using a comma; these values are checked separately from the experiment inclusion/exclusion and dataset inclusion/exclusion filters')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Custom_SP_MSMS','Custom Processing',0,99,'Enter a stored procedure name to run it during Master Update; Optionally, supply stored procedure parameter values after the SP name, separating each value with a comma, for example: UpdatePMTQS, -10, 10, 0, 1, 2')
INSERT INTO [T_Process_Config_Parameters] VALUES ('DataPkg_Import_MS','MS analysis job import',0,99,'Data Package ID to use for importing MS/MS analysis jobs.  When defined, the following are ignored: Campaign, Campaign_and_Experiment, Dataset_Acq_Length_Range, Dataset_DMS_Creation_Date_Minimum, Dataset, Dataset_Exclusion, Experiment, Experiment_Exclusion, MS_Job_Minimum, MS_Job_Maximum, MS_Instrument_Class, MS_Result_Type, Separation_Type')
INSERT INTO [T_Process_Config_Parameters] VALUES ('DataPkg_Import_MSMS','MS/MS analysis job import',0,99,'Data Package ID to use for importing MS/MS analysis jobs.  When defined, the following are ignored: Campaign, Campaign_and_Experiment, Dataset_Acq_Length_Range, Dataset_DMS_Creation_Date_Minimum, Dataset, Dataset_Exclusion, Enzyme_ID, Experiment, Experiment_Exclusion, GANET_Fit_Minimum_Import, GANET_RSquared_Minimum_Import, MSMS_Instrument_Class, MSMS_Job_Minimum, MSMS_Job_Maximum, MSMS_Result_Type, Organism_DB_File_Name, Parameter_File_Name, Separation_Type')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Dataset','MS/MS analysis job import, FTICR analysis job import',1,99,'Allow MS/MS and FTICR analysis jobs that are associated with this dataset name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Dataset_Acq_Length_Range','MS/MS analysis job import, FTICR analysis job import',0,1,'Allow MS/MS and FTICR analysis jobs whose datasets have acquisition lengths (in minutes) between the two specified values; separate the values with a comma.  For example, "80,120" means acquisition lengths between 80 and 120 minutes')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Dataset_DMS_Creation_Date_Minimum','MS/MS analysis job import, FTICR analysis job import',0,1,'Earliest allowable dataset creation date in DMS')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Dataset_Exclusion','MS/MS analysis job import, FTICR analysis job import',1,99,'Exclude MS/MS and FTICR analysis jobs that are associated with this dataset name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character')
INSERT INTO [T_Process_Config_Parameters] VALUES ('DB_Schema_Version','Info only',1,1,'Version of MTDB schema')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Enzyme_ID','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that are associated with this Enzyme ID')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Experiment','MS/MS analysis job import, FTICR analysis job import',1,99,'Allow MS/MS and FTICR analysis jobs that are associated with this experiment name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Experiment_Exclusion','MS/MS analysis job import, FTICR analysis job import',1,99,'Exclude MS/MS and FTICR analysis jobs that are associated with this experiment name.  Can be an exact name match or a name portion, containing a percent sign as a wildcard character')
INSERT INTO [T_Process_Config_Parameters] VALUES ('GANET_Avg_Use_Max_Obs_Area_In_Job_Enabled','Average GANET Computation',1,1,'If 1, then uses the peptide with the maximum observed area in the job; if 0, then uses the first occurrence')
INSERT INTO [T_Process_Config_Parameters] VALUES ('GANET_Fit_Minimum_Average_GANET','Average GANET Computation',1,1,'Minimum GANET Fit to require when computing average GANET values for mass tags')
INSERT INTO [T_Process_Config_Parameters] VALUES ('GANET_Fit_Minimum_Import','MS/MS analysis job import',1,1,'Allow MS/MS jobs that have GANET Fit values of this value or higher')
INSERT INTO [T_Process_Config_Parameters] VALUES ('GANET_RSquared_Minimum_Average_GANET','Average GANET Computation',1,1,'Minimum GANET R-Squared to require when computing average GANET values for mass tags (takes precedence over GANET_Fit_Minimum_Average_GANET)')
INSERT INTO [T_Process_Config_Parameters] VALUES ('GANET_RSquared_Minimum_Import','MS/MS analysis job import',1,1,'Allow MS/MS jobs that have GANET R-Squared values of this value or higher (takes precedence over GANET_Fit_Minimum_Import)')
INSERT INTO [T_Process_Config_Parameters] VALUES ('GANET_Weighted_Average_Enabled','Average GANET Computation',1,1,'If 1, then weights GANET Averages for each Mass Tag using the Discriminant Score values')
INSERT INTO [T_Process_Config_Parameters] VALUES ('General_Statistics_Update_Interval','Update Interval',1,1,'Time interval (in hours) to update the general statistics table')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Job_Info_DMS_Update_Interval','Update Interval',1,1,'Time interval (in hours) to validate the analysis job details against those stored in DMS')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MS_Instrument_Class','FTICR analysis job import',1,99,'Allow FTICR analysis jobs that are associated with datasets that were produced on this type of MS instrument')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MS_Job_Maximum','FTICR analysis job import',0,1,'Maximum FTICR anlaysis job number to import')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MS_Job_Minimum','FTICR analysis job import',0,1,'Minimum FTICR anlaysis job number to import')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MS_Result_Type','FTICR analysis job import',1,99,'Allow FTICR analysis jobs that produce this type of result')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MSMS_Instrument_Class','Peptide_Hit analysis job import',0,99,'Allow Peptide_Hit analysis jobs that are associated with datasets that were produced on this type of MS/MS instrument')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MSMS_Job_Maximum','MS/MS analysis job import',0,1,'Maximum MS/MS job number to import')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MSMS_Job_Minimum','MS/MS analysis job import',0,1,'Minimum MS/MS job number to import')
INSERT INTO [T_Process_Config_Parameters] VALUES ('MSMS_Result_Type','MS/MS analysis job import',1,99,'Allow MS/MS analysis jobs that produce this type of result')
INSERT INTO [T_Process_Config_Parameters] VALUES ('NET_Regression_Param_File_Name','NET Regression',0,1,'Name of the parameter file to use when performing NET regression (stored at \\gigasax\DMS_Parameter_Files\NET_Regression\)')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Organism','Info only',1,99,'Not used for filtering - information only')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Organism_DB_File_Name','MS/MS analysis job import',1,99,'Allow MS/MS analysis jobs that were performed with this organism database file (FASTA); will match the Organism_DB_Name field or the Protein_Collection_List field in the source database')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Parameter_File_Name','MS/MS analysis job import',1,99,'Allow MS/MS analysis jobs that were performed with this parameter file')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_DB_Name','MS/MS analysis job import, Peptide hit import',1,99,'Import MS/MS jobs and their associated peptide hits from these peptide databases')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Import_Filter_ID','Peptide hit import',0,99,'Allow peptide hits that have satisfied this filter')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Import_MaxJobsPerBatch','MS/MS analysis job import',1,1,'Number of jobs to process in each batch of jobs whose Peptide_hit data is being imported')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Import_MaxPeptidesPerBatch','MS/MS analysis job import',1,1,'Number of peptides to process in each batch of jobs whose Peptide_hit data is being imported')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Import_MSGF_SpecProb_Filter','Peptide hit import',0,1,'MSGF Spectrum Probability filter to apply during peptide import')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Load_Stats_Detail_Thresholds','Statistics Threshold',1,99,'Comma separated list of minimum discriminant score and minimum peptide prophet value to filter on when preparing stats for T_Peptide_Load_Stats')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Load_Stats_Detail_Update_Interval','Update Interval',1,1,'Defines how often detailed load stats are added to T_Peptide_Load_Stats when loading a large number of analysis job')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Peptide_Obs_Count_Filter_ID','Info Only',1,1,'Filter ID to use when determining the MS/MS peptide observation count that passes a filter')
INSERT INTO [T_Process_Config_Parameters] VALUES ('PMT_Quality_Score_Set_ID_and_Value','PMT Quality Score Computation',0,99,'Filter Sets from DMS to test PMTs against for populating the PMT_Quality_Score field in T_Mass_Tags; separate the ID and the value with a comma; if no value, then assumes value = 1.  Can include an experiment name filter as a third, comma separated parameter, for example: 121, 2, Tao-HME%.  Can include an instrument class filter as a fourth, comma separated parameter, for example: 121, 2, , Finnigan_Ion_Trap')
INSERT INTO [T_Process_Config_Parameters] VALUES ('PMT_Quality_Score_Uses_Filtered_Peptide_Obs_Count','PMT Quality Score Computation',1,1,'If 0, then column Number_of_Peptides is used for PMT QS calculations.  If 1 then column Peptide_Obs_Count_Passing_Filter is used')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Protein_Collection_and_Protein_Options_Combo','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that were searched against this precise protein collection list and protein options list; separate the two items using a semicolon; the items can contain wildcards; will compare against the full Protein_Collection_List and Protein_Options_List fields in the source DB.  When using this option, you will likely want to delete all Protein_Collection_Filter and Seq_Direction_Filter entries from the table, otherwise unwanted jobs could get imported')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Protein_Collection_Filter','MS/MS analysis job import',0,99,'Allow MS/MS analysis jobs that were searched against this protein collection; matches the Protein_Collection_List field in the peptide DB (either an exact match or a match to one of the items in the list)')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Protein_DB_Name','Protein Import',1,99,'Import protein definitions from this database; databases that only use protein collections can have "(na)" in this field')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Separation_Type','MS/MS analysis job import, FTICR analysis job import',1,99,'Allow MS/MS and FTICR analysis jobs that are associated with datasets that use this separation method')
INSERT INTO [T_Process_Config_Parameters] VALUES ('Seq_Direction_Filter','MS/MS analysis job import',0,99,'Sequence direction values to allow; only used for jobs with a Protein_Collection_List defined')

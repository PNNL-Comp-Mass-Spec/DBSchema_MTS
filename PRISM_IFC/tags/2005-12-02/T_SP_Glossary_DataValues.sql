INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'IncludeUnused', 1, 2, N'tinyint', 1, N'If True, then Unused databases are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'IncludeDeleted', 1, 3, N'tinyint', 1, N'If True, then deleted databases are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'ServerFilter', 1, 4, N'varchar', 128, N'Server name to filter on.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'VerboseColumnOutput', 1, 5, N'tinyint', 1, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'message', 2, 1, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'Server Name', 3, 1, N'varchar', 128, N'Server the DB resides on')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'DB Name', 3, 2, N'varchar', 128, N'Database name.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'Description', 3, 3, N'varchar', 2048, N'Database description.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'Organism', 3, 4, N'varchar', 64, N'Organism associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'Campaign', 3, 5, N'varchar', 64, N'Campaign name associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'State', 3, 6, N'varchar', 50, N'Database state')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'Created', 3, 7, N'smalldatetime', 4, N'Creation date for the database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (1, N'Last Update', 3, 8, N'smalldatetime', 4, N'Date that the statistics were last updated.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'ConfigurationSettingsOnly', 1, 1, N'varchar', 32, N'If 1, then only configuration settings should be displayed for the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'ConfigurationCrosstabMode', 1, 2, N'varchar', 32, N'If 1, then the results should be displayed in a crosstab format.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'DBNameFilter', 1, 3, N'varchar', 2048, N'Like-clause compatible name to filter the databases on.  For example: MT_Human%')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'IncludeUnused', 1, 4, N'varchar', 32, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'ServerFilter', 1, 6, N'varchar', 128, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'message', 2, 5, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Database Name', 3, 1, N'varchar', 128, N'Database name')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Server Name', 3, 2, N'varchar', 128, N'Server name')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Category', 3, 3, N'varchar', 128, N'Category for the given statistic.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Label', 3, 4, N'varchar', 128, N'Label for the given statistic.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Value', 3, 5, N'varchar', 128, N'Statistic for the given category and label.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Database Campaign', 3, 6, N'varchar', 255, N'Campaign name associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Organism', 3, 7, N'varchar', 128, N'Organism associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Peptide DB', 3, 8, N'varchar', 255, N'Peptide database(s) associated with the given PMT tag database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Protein DB', 3, 9, N'varchar', 255, N'Protein database(s) associated with the given PMT tag database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Organism DB Files', 3, 10, N'varchar', 255, N'Organism database files (FASTA files) associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Parameter Files', 3, 11, N'varchar', 255, N'MS/MS search parameter files associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Setting Files', 3, 12, N'varchar', 255, N'MS/MS search settings files associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Separation Types', 3, 13, N'varchar', 255, N'Allowed LC separation types.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Experiments', 3, 14, N'varchar', 255, N'Experiment clause used to filter datasets for the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'State', 3, 15, N'varchar', 50, N'Database state')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Last Update', 3, 16, N'datetime', 8, N'Date that the statistics were last updated.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (2, N'Database Description', 3, 17, N'varchar', 2048, N'Database description')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'IncludeUnused', 1, 2, N'tinyint', 1, N'If True, then Unused databases are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'IncludeDeleted', 1, 3, N'tinyint', 1, N'If True, then deleted databases are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'ServerFilter', 1, 4, N'varchar', 128, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'VerboseColumnOutput', 1, 5, N'tinyint', 1, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'message', 2, 1, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'Name', 3, 1, N'varchar', 128, N'Database name')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'Description', 3, 2, N'varchar', 2048, N'Database description.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'Organism', 3, 3, N'varchar', 64, N'Organism associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'State', 3, 4, N'varchar', 50, N'Database state')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'Created', 3, 5, N'datetime', 8, N'Creation date for the database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (3, N'Last Update', 3, 6, N'datetime', 8, N'Date that the statistics were last updated.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'ConfigurationSettingsOnly', 1, 1, N'varchar', 32, N'If 1, then only configuration settings should be displayed for the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'ConfigurationCrosstabMode', 1, 2, N'varchar', 32, N'If 1, then the results should be displayed in a crosstab format.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'DBNameFilter', 1, 3, N'varchar', 2048, N'Like-clause compatible name to filter the databases on.  For example: PT_Human%')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'IncludeUnused', 1, 4, N'varchar', 32, N'If True, then Unused databases are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'ServerFilter', 1, 6, N'varchar', 128, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'message', 2, 5, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Database Name', 3, 1, N'varchar', 128, N'Database name')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Server Name', 3, 2, N'varchar', 128, N'Server name')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Category', 3, 3, N'varchar', 128, N'Category for the given statistic.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Label', 3, 4, N'varchar', 128, N'Label for the given statistic.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Value', 3, 5, N'varchar', 128, N'Statistic for the given category and label.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Organism', 3, 6, N'varchar', 128, N'Organism associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Organism DB Files', 3, 7, N'varchar', 255, N'Organism database files (FASTA files) associated with the given database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Peptide Import Filters', 3, 8, N'varchar', 255, N'Filter set IDs used when importing peptide results.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'MTDB Export Filters', 3, 9, N'varchar', 255, N'Filter set IDs used when exporting peptide results.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'State', 3, 10, N'varchar', 50, N'Database state')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Last Update', 3, 11, N'datetime', 8, N'Date that the statistics were last updated.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (4, N'Database Description', 3, 12, N'varchar', 2048, N'Databse description')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'outputColumnNameList', 1, 2, N'varchar', 2048, N'Comma separated list of column names to limit the output to. If blank, then all columns are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'criteriaSql', 1, 3, N'varchar', 6000, N'Sql "Where clause compatible" text for filtering the ResultSet. For example: "Protein_Monoisotopic_Mass < 10000".  This parameter can contain Protein_Name criteria, but the @criteriaSQL text will get AND''d with the @Proteins parameter, if it is defined')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'returnRowCount', 1, 4, N'varchar', 32, N'Set to True to return the row count, false to return the data.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'Proteins', 1, 6, N'varchar', 7000, N'Comma separated list of protein names to filter on or list of protein match criteria containing a wildcard character (%) to filter on.  For example: ''Protein1003, Protein1005, Protein1006'' or ''Protein100%'' or ''Protein1003, Protein1005, Protein100%''')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'message', 2, 5, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'ProteinDBDefined', 2, 7, N'varchar', 32, N'Set to True if a Protein database is defined for this PMT tag database, False if not.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'Protein_Name', 3, 1, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'Protein_Description', 3, 2, N'varchar', 128, N'Description for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'Protein_Location_Start', 3, 3, N'int', 4, N'Starting location in the organism''s DNA at which the given protein sequence starts.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'Protein_Location_Stop', 3, 4, N'int', 4, N'Ending location in the organism''s DNA at which the given protein sequence starts.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'Protein_Monoisotopic_Mass', 3, 5, N'float', 8, N'Uncharged mass of the protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (5, N'Protein_Sequence', 3, 6, N'text', 16, N'Protein sequence')
INSERT INTO dbo.T_SP_Glossary
  VALUES (6, N'message', 2, 1, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (6, N'Column_Name', 3, 1, N'varchar', 255, N'Name of the output column.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (6, N'Data_Type', 3, 2, N'varchar', 255, N'Data type of the output column.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'pepIdentMethod', 1, 2, N'varchar', 32, N'Identification method to use for returning results.  DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'outputColumnNameList', 1, 3, N'varchar', 1024, N'Comma separated list of column names to limit the output to. If blank, then all columns are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'message', 2, 4, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'Experiment', 3, 1, N'varchar', 50, N'Experiment name')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'Sel', 3, 2, N'int', 4, N'Column required by the web page generator to allow the user to select Q Rollups to work with.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'Exp Reason', 3, 3, N'varchar', 500, N'Reason experiment was conducted.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'Exp Comment', 3, 4, N'varchar', 500, N'Comment associated with the experiment')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'Campaign', 3, 5, N'varchar', 50, N'Campaign name for the given experiment.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'Organism', 3, 6, N'varchar', 50, N'Organism associated with the given experiment.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (8, N'Cell Cultures', 3, 7, N'varchar', 1024, N'Cell cultures for the given experiment.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'outputColumnNameList', 1, 2, N'varchar', 2048, N'Comma separated list of column names to limit the output to. If blank, then all columns are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'criteriaSql', 1, 3, N'varchar', 6000, N'Sql "Where clause compatible" text for filtering the ResultSet.  For example: "Protein_Name Like ''DR2%'' And (MSMS_High_Normalized_Score >= 5 Or MSMS_Observation_Count >= 10)".  Although this parameter can contain Protein_Name criteria, it is better to filter for Proteins using the @Proteins parameter.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'returnRowCount', 1, 4, N'varchar', 32, N'Set to True to return the row count, false to return the data.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'pepIdentMethod', 1, 6, N'varchar', 32, N'Identification method to use for returning results.  DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Experiments', 1, 7, N'varchar', 7000, N'Comma separated list of experiments to filter on or list of experiment match criteria containing a wildcard character (%) to filter on.  Names do not need single quotes around them; see @Proteins parameter for examples.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Proteins', 1, 8, N'varchar', 7000, N'Comma separated list of protein names to filter on or list of protein match criteria containing a wildcard character (%) to filter on.  For example: ''Protein1003, Protein1005, Protein1006'' or ''Protein100%'' or ''Protein1003, Protein1005, Protein100%''')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'maximumRowCount', 1, 9, N'int', 4, N'Maximum number of rows to return.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'includeSupersededData', 1, 10, N'varchar', 32, N'If True, then results from superseded peak matching tasks are included.  Only applicable for method UMCPeakMatch(MS-FTICR).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'minimumPMTQualityScore', 1, 11, N'float', 8, N'Minimum Quality Score required of PMTs used in peak matching (Scale 0-2, 2 is best quality).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'message', 2, 5, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Experiment', 3, 1, N'varchar', 64, N'Experiment name that given PMT was identified in.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Protein_Name', 3, 2, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Mass_Tag_ID', 3, 3, N'int', 4, N'Unique integer identification number for the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Mass_Tag_Name', 3, 4, N'varchar', 255, N'Description of the location of the given PMT in the associated protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Peptide_Sequence', 3, 5, N'varchar', 850, N'Sequence of amino acids conteined in matching mass tag, sans preceding and subsequent amino acids')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Peptide_Monoisotopic_Mass', 3, 6, N'float', 8, N'Sum of naturally occuring isotope mass values contained in amino acid sequence')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'MSMS_Observation_Count', 3, 7, N'int', 4, N'Number of filter passing MSMS observations for the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'MSMS_High_Normalized_Score', 3, 8, N'real', 4, N'Highest cross correlational value (XCorr) of the MSMS observations for the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'MSMS_High_Discriminant_Score', 3, 9, N'real', 4, N'Highest discriminant score computed for the MSMS observations for the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Mod_Count', 3, 10, N'int', 4, N'Number of modified amino acids in the peptide sequence')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Mod_Description', 3, 11, N'varchar', 2048, N'Type of modifications on the amino acids of the peptide sequence for the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'PMT_Quality_Score', 3, 12, N'numeric', 5, N'Minimum Quality Score required for PMT match (Scale 0-2, 2 is best quality)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Cleavage_State_Name', 3, 13, N'varchar', 50, N'The enzymatic cleavage state for the given PMT, in the context of the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Residue_Start', 3, 14, N'int', 4, N'Position of the first amino acid in the protein sequence')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Residue_End', 3, 15, N'int', 4, N'Position of the last amino acid in the protein sequence')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Dataset_Count', 3, 16, N'int', 4, N'Number of datasets (for this Q Rollup) in which the given PMT was observed.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (11, N'Job_Count', 3, 17, N'int', 4, N'Number of MS/MS analyses that the given PMT was observed in.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (13, N'pepIdentMethod', 1, 2, N'varchar', 32, N'Identification method to use for returning results.  DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (13, N'message', 2, 1, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (13, N'Column_Name', 3, 1, N'varchar', 255, N'Name of the output column.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (13, N'Data_Type', 3, 2, N'varchar', 255, N'Data type of the output column.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (14, N'message', 2, 1, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (14, N'Name', 3, 1, N'varchar', 32, N'Name for the given peptide identification method.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (14, N'Code', 3, 2, N'varchar', 32, N'Code for the given peptide identification method.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (17, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (17, N'Experiments', 1, 2, N'varchar', 7000, N'Comma separated list of experiments to filter on or list of experiment match criteria containing a wildcard character (%) to filter on.  Names do not need single quotes around them.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (17, N'aggregation', 1, 3, N'varchar', 24, N'Aggregation method.  For example: Sum_XCorr')
INSERT INTO dbo.T_SP_Glossary
  VALUES (17, N'mode', 1, 4, N'varchar', 32, N'Type of cross tab to return: Crosstab_Report, Preview_Data_Analysis_Jobs, Preview_Experiments, Preview_Proteins')
INSERT INTO dbo.T_SP_Glossary
  VALUES (17, N'message', 2, 5, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (17, N'Reference', 3, 1, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (17, N'Monoisotopic_Mass', 3, 2, N'float', 8, N'Uncharged mass of the PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'outputColumnNameList', 1, 2, N'varchar', 2048, N'Comma separated list of column names to limit the output to. If blank, then all columns are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'criteriaSql', 1, 3, N'varchar', 6000, N'Sql "Where clause compatible" text for filtering the ResultSet.  For example: "Mass_Tag_Count >= 5 Or Dataset_Count >= 3".  Although this parameter can contain Protein_Name criteria, it is better to filter for Proteins using the @Proteins parameter')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'returnRowCount', 1, 4, N'varchar', 32, N'Set to True to return the row count, false to return the data.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'pepIdentMethod', 1, 6, N'varchar', 32, N'Identification method to use for returning results.  DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'Experiments', 1, 7, N'varchar', 7000, N'Comma separated list of experiments to filter on or list of experiment match criteria containing a wildcard character (%) to filter on.  Names do not need single quotes around them; see @Proteins parameter for examples.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'Proteins', 1, 8, N'varchar', 7000, N'Comma separated list of protein names to filter on or list of protein match criteria containing a wildcard character (%) to filter on.  For example: ''Protein1003, Protein1005, Protein1006'' or ''Protein100%'' or ''Protein1003, Protein1005, Protein100%''')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'maximumRowCount', 1, 9, N'int', 4, N'Maximum number of rows to return.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'includeSupersededData', 1, 10, N'varchar', 32, N'If True, then results from superseded peak matching tasks are included.  Only applicable for method UMCPeakMatch(MS-FTICR).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'minimumPMTQualityScore', 1, 11, N'float', 8, N'Minimum Quality Score required of PMTs used in peak matching (Scale 0-2, 2 is best quality).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'message', 2, 5, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'Experiment', 3, 1, N'varchar', 64, N'Experiment name that the given protein was identified in.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'Protein_Name', 3, 2, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'Mass_Tag_Count', 3, 3, N'int', 4, N'Number of mass tags seen')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'MSMS_Observation_Count_Avg', 3, 4, N'int', 4, N'Average number of filter passing MSMS observations for the peptides associated with the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'MSMS_High_Normalized_Score_Avg', 3, 5, N'decimal', 5, N'Average highest cross correlational value (XCorr) of the MSMS observations for the peptides associated with the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'MSMS_High_Discriminant_Score_Avg', 3, 6, N'decimal', 5, N'Average highest discriminant score, based on the discriminant scores for the peptides associated with the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'Mod_Count_Avg', 3, 7, N'float', 8, N'Average number of modified amino acids in the peptide sequences for the peptides associated with this protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'Dataset_Count_Avg', 3, 8, N'int', 4, N'Average number of datasets (for this Q Rollup) in which the PMTs for the given protein were observed.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (18, N'Job_Count_Avg', 3, 9, N'int', 4, N'Average number of MS/MS analyses in which the peptides associated with the given protein were observed.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'MTDBName', 1, 1, N'varchar', 128, N'Database from which to obtain the Q Rollup report(s).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'ShowSuperseded', 1, 2, N'tinyint', 1, N'If 1, then will include Q Rollups with Quantitation_State_ = 5')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'outputColumnNameList', 1, 3, N'varchar', 1024, N'Comma separated list of column names to limit the output to. If blank, then all columns are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'QuantitationIDList', 1, 4, N'varchar', 1024, N'Comma separated list of Quantitation_ID report IDs to return; may contain just one value.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'message', 2, 5, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Quantitation_ID', 3, 1, N'int', 4, N'Index from T_Quantitation_Description')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Quantitation_State', 3, 2, N'tinyint', 1, N'State number representing new, proccessing, sucess, or failure - See T_Quantitation_State_Name')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'MD_ID', 3, 3, N'int', 4, N'Unique integer identifier for the peak matching task.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Job', 3, 4, N'int', 4, N'Job Number; Index ID used for tracking')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Dataset', 3, 5, N'varchar', 128, N'Name of dataset created at the time of mass spec run')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Experiment', 3, 6, N'varchar', 64, N'Name of experiment to which the current dataset belongs')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Instrument_Class', 3, 7, N'varchar', 32, N'Class name (LCQ or FTICR)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Parameter_File_Name', 3, 8, N'varchar', 255, N'Name of the parameter file containing the settings used for deisotoping')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Ini_File_Name', 3, 9, N'varchar', 255, N'Name of ini file containing the settings used for peak matching')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Job_Completed', 3, 10, N'smalldatetime', 4, N'Date and time job was completed')
INSERT INTO dbo.T_SP_Glossary
  VALUES (20, N'Dataset_Created_DMS', 3, 11, N'smalldatetime', 4, N'Date and time the dataset was created')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'MTDBName', 1, 1, N'varchar', 128, N'Database from which to obtain the Q Rollup report(s).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'ShowSuperseded', 1, 2, N'tinyint', 1, N'If 1, then will include Q Rollups with Quantitation_State_ = 5')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'outputColumnNameList', 1, 3, N'varchar', 1024, N'Columns to include in the output -- ignored.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'message', 2, 4, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'QID', 3, 1, N'int', 4, N'Q Rollup report ID')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Sel', 3, 2, N'int', 4, N'Column required by the web page generator to allow the user to select Q Rollups to work with.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Sample Name', 3, 3, N'varchar', 255, N'Name of sample')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Comment', 3, 4, N'varchar', 255, N'Comment for the given Q Rollup report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Results Folder Path', 3, 5, N'varchar', 255, N'Location of results folder; server path')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Unique Mass Tag Count', 3, 6, N'int', 4, N'Unique number of PMTs (peptides) identified in the given Q rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Comparison Mass Tag Count', 3, 7, N'int', 4, N'Number of PMTs that the UMCs were compared against in the peak matching task(s) included in the given Q Rollup.  If more than one peak matching task is rolled up, then this is an average for all tasks included, though the number of PMTs used will typically be the same for all tasks included in a single rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Threshold % For Inclusion', 3, 8, N'decimal', 5, N'Decimal value to multiply the abundance value of the most abundant peptide for each protein by when determining the cutoff to use for choosing peptides to average together to compute average protein abundances.  Typically 0.33')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Normalize', 3, 9, N'tinyint', 1, N'If 1, then the peptide abundances are scaled to give values roughly between 0.01 and 100.    Scaling is performed using ScaledAbu = (Abu-Minimum) / (Maximum-Minimum) * 100')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Std Abu Min', 3, 10, N'float', 8, N'Minimum value to use when scaling the peptide abundances.  Scaling is performed using ScaledAbu = (Abu-Minimum) / (Maximum-Minimum) * 100')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Std Abu Max', 3, 11, N'float', 8, N'Maximum value to use when scaling the peptide abundances.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Force Peak Max Abundance', 3, 12, N'tinyint', 1, N'If 1, then peptide abundances are forced to be based on the maximum single-scan abundance within the UMC, rather than the area under the chromatographic peak for the UMC.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Min High MS/MS Score', 3, 13, N'real', 4, N'Minimum Sequest score required of PMTs used in peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Min High Discriminant Score', 3, 14, N'real', 4, N'Minimum Discriminant score required of PMTs used in peak matching (scale 0 to 1).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Min PMT Quality Score', 3, 15, N'real', 4, N'Minimum Quality Score required of PMTs used in peak matching (Scale 0-2, 2 is best quality).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Min SLiC Score', 3, 16, N'real', 4, N'Minimum SLIC score required of PMTs used in peak matching (scale 0 to 1).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Min Del SLiC Score', 3, 17, N'real', 4, N'Minimum Del SLIC score required of PMTs used in peak matching (scale 0 to 1).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Min Peptide Length', 3, 18, N'tinyint', 1, N'Minimum number of amino acids per peptide required of PMTs used in peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Min Peptide Rep Count', 3, 19, N'smallint', 2, N'Minimum number of repeat observations (replicates) required for each PMT (peptide) to be included in the report.  Ignored for Q Rollups that are not replicate-based.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'ORF Coverage Computation Level', 3, 20, N'tinyint', 1, N'Amount of detail to include for protein (ORF) coverage.  If 0, then no protein coverage is computed.  If 1, then observed protein coverage is computed.  If 2, then both potential and observed protein coverage is computed (possibly very time consuming).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Rep Norm Stats', 3, 21, N'varchar', 1024, N'Summary of the normalization steps applied for replicate-based Q Rollups.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Quantitation State ID', 3, 22, N'tinyint', 1, N'Processing state for the Q Rollup; 1=New, 2=Processing, 3=Success, 4=Failure, 5=Superseded.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'State', 3, 23, N'varchar', 50, N'Processing state for the Q Rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (21, N'Last Affected', 3, 24, N'datetime', 8, N'Date that the Q Rollup was last updated.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (22, N'message', 2, 1, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (22, N'Column_Name', 3, 1, N'varchar', 255, N'Name of the output column.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (22, N'Data_Type', 3, 2, N'varchar', 255, N'Data type of the output column.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (22, N'Description', 3, 3, N'varchar', 255, N'Column description.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (23, N'message', 2, 1, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (23, N'Column_Name', 3, 1, N'varchar', 255, N'Name of the output column.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (23, N'Data_Type', 3, 2, N'varchar', 255, N'Data type of the output column.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (23, N'Description', 3, 3, N'varchar', 255, N'Column description.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'outputColumnNameList', 1, 2, N'varchar', 2048, N'Comma separated list of column names to limit the output to. If blank, then all columns are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'criteriaSql', 1, 3, N'varchar', 6000, N'Sql "Where clause compatible" text for filtering the ResultSet.  For example: "Protein_Name Like ''DR2%'' And (MSMS_High_Normalized_Score >= 5 Or MSMS_Observation_Count >= 10)".  Although this parameter can contain Protein_Name criteria, it is better to filter for Proteins using the @Proteins parameter.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'returnRowCount', 1, 4, N'varchar', 32, N'Set to True to return the row count, false to return the data.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'pepIdentMethod', 1, 5, N'varchar', 32, N'Identification method to use for returning results.  DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Experiments', 1, 6, N'varchar', 7000, N'Comma separated list of experiments to filter on or list of experiment match criteria containing a wildcard character (%) to filter on.  Names do not need single quotes around them; see @Proteins parameter for examples.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Proteins', 1, 7, N'varchar', 7000, N'Comma separated list of protein names to filter on or list of protein match criteria containing a wildcard character (%) to filter on.  For example: ''Protein1003, Protein1005, Protein1006'' or ''Protein100%'' or ''Protein1003, Protein1005, Protein100%''')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'maximumRowCount', 1, 8, N'varchar', 32, N'Maximum number of rows to return.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'includeSupersededData', 1, 9, N'varchar', 32, N'If True, then results from superseded peak matching tasks are included.  Only applicable for method UMCPeakMatch(MS-FTICR).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'minimumPMTQualityScore', 1, 10, N'varchar', 32, N'Minimum Quality Score required of PMTs used in peak matching (Scale 0-2, 2 is best quality).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'message', 2, 11, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Experiment', 3, 1, N'varchar', 64, N'Experiment name that given PMT was identified in.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Protein_Name', 3, 2, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Mass_Tag_ID', 3, 3, N'int', 4, N'Unique integer identification number for the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Mass_Tag_Name', 3, 4, N'varchar', 255, N'Description of the location of the given PMT in the associated protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Peptide_Sequence', 3, 5, N'varchar', 750, N'Sequence of Peptide')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Peptide_Monoisotopic_Mass', 3, 6, N'float', 8, N'Monoisotopic Mass of Peptide')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'MSMS_Observation_Count', 3, 7, N'int', 4, N'Number of filter passing MSMS observations for the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'MSMS_High_Normalized_Score', 3, 8, N'real', 4, N'Highest cross correlational value (XCorr) of the MSMS observations for the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'MSMS_High_Discriminant_Score', 3, 9, N'real', 4, N'Highest discriminant score computed for the MSMS observations for the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Mod_Count', 3, 10, N'int', 4, N'Number of modified amino acids in the peptide sequence')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Mod_Description', 3, 11, N'varchar', 2048, N'Type of modifications on the amino acids of the peptide sequence for the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'PMT_Quality_Score', 3, 12, N'numeric', 5, N'Minimum Quality Score required for PMT match (Scale 0-2, 2 is best quality)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Cleavage_State_Name', 3, 13, N'varchar', 50, N'The enzymatic cleavage state for the given PMT, in the context of the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Residue_Start', 3, 14, N'int', 4, N'Position in protein of peptide N-term by amino acid count')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Residue_End', 3, 15, N'int', 4, N'Position in protein of peptide C-term by amino acid count')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Dataset_Count', 3, 16, N'int', 4, N'Number of datasets (for this Q Rollup) in which the given PMT was observed.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (24, N'Job_Count', 3, 17, N'int', 4, N'Number of MS/MS analyses that the given PMT was observed in.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (25, N'MTDBName', 1, 1, N'varchar', 128, N'Name of the mass tag database from which to obtain the desired list of items. Only used if @PickerName is ExperimentList, ProteinList, or QRSummary')
INSERT INTO dbo.T_SP_Glossary
  VALUES (25, N'PickerName', 1, 2, N'varchar', 128, N'Picker type for which items should be returned.  Can be: MTDBNameList, PTDBNameList, ExperimentList, ProteinList, OutputColumnsForGetMassTags, OutputColumnsForGetAllProteins, OutputColumnsForProteinCrosstab, OutputColumnsForPeptideCrosstab, or QRSummary')
INSERT INTO dbo.T_SP_Glossary
  VALUES (25, N'pepIdentMethod', 1, 3, N'varchar', 32, N'Identification method to use for returning results.  DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (25, N'message', 2, 4, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'outputColumnNameList', 1, 2, N'varchar', 2048, N'Comma separated list of column names to limit the output to. If blank, then all columns are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'criteriaSql', 1, 3, N'varchar', 6000, N'Sql "Where clause compatible" text for filtering the ResultSet.  For example: "Mass_Tag_Count >= 5 Or Dataset_Count >= 3".  Although this parameter can contain Protein_Name criteria, it is better to filter for Proteins using the @Proteins parameter')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'returnRowCount', 1, 4, N'varchar', 32, N'Set to True to return the row count, false to return the data.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'pepIdentMethod', 1, 5, N'varchar', 32, N'Identification method to use for returning results.  DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'Experiments', 1, 6, N'varchar', 7000, N'Comma separated list of experiments to filter on or list of experiment match criteria containing a wildcard character (%) to filter on.  Names do not need single quotes around them; see @Proteins parameter for examples.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'Proteins', 1, 7, N'varchar', 7000, N'Comma separated list of protein names to filter on or list of protein match criteria containing a wildcard character (%) to filter on.  For example: ''Protein1003, Protein1005, Protein1006'' or ''Protein100%'' or ''Protein1003, Protein1005, Protein100%''')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'maximumRowCount', 1, 8, N'varchar', 32, N'Maximum number of rows to return.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'includeSupersededData', 1, 9, N'varchar', 32, N'If True, then results from superseded peak matching tasks are included.  Only applicable for method UMCPeakMatch(MS-FTICR).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'minimumPMTQualityScore', 1, 10, N'varchar', 32, N'Minimum Quality Score required of PMTs used in peak matching (Scale 0-2, 2 is best quality).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'message', 2, 11, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'Experiment', 3, 1, N'varchar', 64, N'Experiment name that the given protein was identified in.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'Protein_Name', 3, 2, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'Mass_Tag_Count', 3, 3, N'int', 4, N'Number of mass tags seen')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'MSMS_Observation_Count_Avg', 3, 4, N'int', 4, N'Average number of filter passing MSMS observations for the peptides associated with the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'MSMS_High_Normalized_Score_Avg', 3, 5, N'decimal', 5, N'Average highest cross correlational value (XCorr) of the MSMS observations for the peptides associated with the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'MSMS_High_Discriminant_Score_Avg', 3, 6, N'decimal', 5, N'Average highest discriminant score, based on the discriminant scores for the peptides associated with the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'Mod_Count_Avg', 3, 7, N'float', 8, N'Average number of modified amino acids in the peptide sequences for the peptides associated with this protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'Dataset_Count_Avg', 3, 8, N'int', 4, N'Average number of datasets (for this Q Rollup) in which the PMTs for the given protein were observed.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (26, N'Job_Count_Avg', 3, 9, N'int', 4, N'Average number of MS/MS analyses in which the peptides associated with the given protein were observed.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'MTDBName', 1, 1, N'varchar', 128, N'Database from which to obtain the Q Rollup report(s).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'message', 2, 2, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'QID', 3, 1, N'int', 4, N'Q Rollup report ID')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'sel', 3, 2, N'int', 1, N'Column required by the web page generator to allow the user to select Q Rollups to work with.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Sample Name', 3, 3, N'varchar', 255, N'Job number or sample name; Replicates and Fractions may be combined')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Comment', 3, 4, N'varchar', 255, N'Comment for the given Q Rollup report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Results Folder Path', 3, 5, N'varchar', 255, N'Location of results folder; server path')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Unique Mass Tag Count', 3, 6, N'int', 4, N'Unique number of PMTs (peptides) identified in the given Q rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Comparison Mass Tag Count', 3, 7, N'int', 4, N'Number of PMTs that the UMCs were compared against in the peak matching task(s) included in the given Q Rollup.  If more than one peak matching task is rolled up, then this is an average for all tasks included, though the number of PMTs used will typically be the same for all tasks included in a single rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Threshold % For Inclusion', 3, 8, N'decimal', 5, N'Decimal value to multiply the abundance value of the most abundant peptide for each protein by when determining the cutoff to use for choosing peptides to average together to compute average protein abundances.  Typically 0.33')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Normalize', 3, 9, N'tinyint', 1, N'If 1, then the peptide abundances are scaled to give values roughly between 0.01 and 100.    Scaling is performed using ScaledAbu = (Abu-Minimum) / (Maximum-Minimum) * 100')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Std Abu Min', 3, 10, N'float', 8, N'Minimum value to use when scaling the peptide abundances.  Scaling is performed using ScaledAbu = (Abu-Minimum) / (Maximum-Minimum) * 100')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Std Abu Max', 3, 11, N'float', 8, N'Maximum value to use when scaling the peptide abundances.  Scaling is performed using ScaledAbu = (Abu-Minimum) / (Maximum-Minimum) * 100')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Force Peak Max Abundance', 3, 12, N'tinyint', 1, N'If 1, then peptide abundances are forced to be based on the maximum single-scan abundance within the UMC, rather than the area under the chromatographic peak for the UMC.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Min High MS/MS Score', 3, 13, N'real', 4, N'Minimum Sequest score required of PMTs used in peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Min High Discriminant Score', 3, 14, N'real', 4, N'Minimum Discriminant score required of PMTs used in peak matching (scale 0 to 1).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Min PMT Quality Score', 3, 15, N'real', 4, N'Minimum Quality Score required of PMTs used in peak matching (Scale 0-2, 2 is best quality).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Min SLiC Score', 3, 16, N'real', 4, N'Minimum SLIC score required of PMTs used in peak matching (scale 0 to 1).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Min Del SLiC Score', 3, 17, N'real', 4, N'Minimum Del SLIC score required of PMTs used in peak matching (scale 0 to 1).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Min Peptide Length', 3, 18, N'tinyint', 1, N'Minimum number of amino acids per peptide required of PMTs used in peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Min Peptide Rep Count', 3, 19, N'smallint', 2, N'Minimum number of repeat observations (replicates) required for each PMT (peptide) to be included in the report.  Ignored for Q Rollups that are not replicate-based.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'ORF Coverage Computation Level', 3, 20, N'tinyint', 1, N'Amount of detail to include for protein (ORF) coverage.  If 0, then no protein coverage is computed.  If 1, then observed protein coverage is computed.  If 2, then both potential and observed protein coverage is computed (possibly very time consuming).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Rep Norm Stats', 3, 21, N'varchar', 50, N'Summary of the normalization steps applied for replicate-based Q Rollups.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Quantitation State ID', 3, 22, N'tinyint', 1, N'Processing state for the Q Rollup; 1=New, 2=Processing, 3=Success, 4=Failure, 5=Superseded.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'State', 3, 23, N'varchar', 50, N'Processing state for the Q Rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (27, N'Last Affected', 3, 24, N'datetime', 8, N'Date that the Q Rollup was last updated.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'MTDBName', 1, 1, N'varchar', 128, N'Database from which to obtain the Q Rollup report(s).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'QuantitationID', 1, 2, N'varchar', 20, N'Q Rollup report ID')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'message', 2, 3, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Quantitation_ID', 3, 1, N'int', 4, N'Q Rollup report ID')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'SampleName', 3, 2, N'varchar', 255, N'Description associated with the given Q Rollup report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Quantitation_State', 3, 3, N'tinyint', 1, N'Processing state for the Q Rollup; 1=New, 2=Processing, 3=Success, 4=Failure, 5=Superseded.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Comment', 3, 4, N'varchar', 255, N'Comment for the given Q Rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Fraction_Highest_Abu_To_Use', 3, 5, N'decimal', 5, N'Decimal value to multiply the abundance value of the most abundant peptide for each protein by when determining the cutoff to use for choosing peptides to average together to compute average protein abundances.  Typically 0.22')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Normalize_To_Standard_Abundances', 3, 6, N'tinyint', 1, N'If 1, then the peptide abundances are scaled to give values roughly between 0.01 and 100.    Scaling is performed using ScaledAbu = (Abu-Minimum) / (Maximum-Minimum) * 100')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Standard_Abundance_Min', 3, 7, N'float', 8, N'Minimum value to use when scaling the peptide abundances.  Scaling is performed using ScaledAbu = (Abu-Minimum) / (Maximum-Minimum) * 100')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Standard_Abundance_Max', 3, 8, N'float', 8, N'Maximum value to use when scaling the peptide abundances.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'UMC_Abundance_Mode', 3, 9, N'tinyint', 1, N'If 1, then peptide abundances are forced to be based on the maximum single-scan abundance within the UMC, rather than the area under the chromatographic peak for the UMC.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Expression_Ratio_Mode', 3, 10, N'tinyint', 1, N'If 0 then treat multiple UMCs matching the same mass tag in the same dataset as essentially one large UMC, then computing ER = Sum(Light) / Sum(Heavy).  If 1 then weight multiple ER values for same mass tag by UMC member counts.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Minimum_MT_High_Normalized_Score', 3, 11, N'decimal', 5, N'Minimum Sequest score required of PMTs used in peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Minimum_PMT_Quality_Score', 3, 12, N'decimal', 5, N'Minimum Quality Score required of PMTs used in peak matching (Scale 0-2, 2 is best quality).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Minimum_Peptide_Length', 3, 13, N'tinyint', 1, N'Minimum peptideresidue count for PMTs used in peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Minimum_Match_Score', 3, 14, N'decimal', 5, N'Minimum SLiC score required for PMTs matching UMCs.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'Minimum_Peptide_Replicate_Count', 3, 15, N'smallint', 2, N'Minimum peptideresidue count for PMTs used in peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'ORF Coverage Computation Level', 3, 16, N'tinyint', 1, N'Amount of detail to include for protein (ORF) coverage.  If 0, then no protein coverage is computed.  If 1, then observed protein coverage is computed.  If 2, then both potential and observed protein coverage is computed (possibly very time consuming).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'RepNormalization_PctSmallDataToDiscard', 3, 17, N'tinyint', 1, N'Percentage of low intensity data to be discarded prior to computing the normalization factor.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'RepNormalization_PctLargeDataToDiscard', 3, 18, N'tinyint', 1, N'Percentage of high intensity data to be discarded prior to computing the normalization factor.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'RepNormalization_MinimumDataPointCount', 3, 19, N'smallint', 2, N'Minimum number of matching PMTs between replicates that must be present for intensity normalization to be performed.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'RemoveOutlierAbundancesForReplicates', 3, 24, N'tinyint', 1, N'If 1, then outlier abundance values are removed for each PMT in replicate-based Q Rollups.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'FractionCrossReplicateAvgInRange', 3, 25, N'decimal', 5, N'Decimal value to use when filtering out the outlier abundances in replicate-based Q rollups.  An initial average across replicates is computed for each peptide, then the average is multiplied by FractionCrossReplicateAvgInRange to give DistanceX.  Abundances values that are more than DistanceX away from the average are not included in the final average.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'AddBackExcludedMassTags', 3, 26, N'tinyint', 1, N'Only applies to replicate-based rollups.  If 1, then any PMTs that get filtered out due to widely varying abundances between replicates get added back into the results output.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'MTMatchingUMCsCount', 3, 27, N'int', 4, N'Number of UMCs in the given Q Rollup that had one or more matching PMTs.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'MTMatchingUMCsCountFilteredOut', 3, 28, N'int', 4, N'Number of UMCs in the given Q Rollup that had a matching PMT, but were filtered out because the UMC abundance was marked as an outlier.  Only applies to replicate-based Q Rollups.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'UniqueMassTagCount', 3, 29, N'int', 4, N'Unique number of PMTs (peptides) identified in the given Q rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'UniqueMassTagCountFilteredOut', 3, 30, N'int', 4, N'Number of UMCs in the given Q Rollup that had a matching PMT, but were filtered out because the UMC abundance was marked as an outlier.  Only applies to replicate-based Q Rollups.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'ReplicateNormalizationStates', 3, 31, N'varchar', 1024, N'Summary of the normalization steps applied for replicate-based Q Rollups.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (28, N'LastAffected', 3, 32, N'datetime', 8, N'Date that the Q Rollup was last updated.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'SourceColName', 1, 2, N'varchar', 128, N'Column whose value is to be returned in the crosstab report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'QuantitationIDList', 1, 3, N'varchar', 1024, N'Comma separated list of Quantitation_ID report IDs to return; may contain just one value.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'SeparateReplicateDataIDs', 1, 5, N'tinyint', 1, N'If 1, then will separate out replicate-based Q Rollups into separate columns.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'AggregateColName', 1, 6, N'varchar', 128, N'The column whose value is to be displayed in the crosstab output.  Valid columns include MT_Abundance, ER, Mass_Error_PPM_Avg, UMC_MatchCount_Avg, SingleMT_MassTagMatchingIonCount, SingleMT_FractionScansMatchingSingleMT, ReplicateCountAvg, FractionCountAvg, TopLevelFractionCount')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'AverageAcrossColumns', 1, 7, N'tinyint', 1, N'Set 1 to include a final column in the output that is an average across all columns for the given row.  If enabled, will result in slower execution times and supports fewer total QID values due to Sql Server varchar limitations.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'message', 2, 4, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'Mass_Tag_ID', 3, 1, N'int', 4, N'Unique integer identification number for the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'Peptide', 3, 2, N'varchar', 750, N'Sequence of the PMT (peptide)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (31, N'Mass_Tag_Mods', 3, 3, N'varchar', 2048, N'Amino acid residue modifications associated with the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'SourceColName', 1, 2, N'varchar', 128, N'Column whose value is to be returned in the crosstab report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'QuantitationIDList', 1, 3, N'varchar', 1024, N'Comma separated list of Quantitation_ID report IDs to return; may contain just one value.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'SeparateReplicateDataIDs', 1, 5, N'tinyint', 1, N'If 1, then will separate out replicate-based Q Rollups into separate columns.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'AggregateColName', 1, 6, N'varchar', 128, N'The column whose value is to be displayed in the crosstab output.  Valid columns include Abundance_Average, ER_Average, MassTagCountUniqueObserved, MassTagCountUsedForAbundanceAvg, Full_Enzyme_Count, Full_Enzyme_No_Missed_Cleavage_Count, Partial_Enzyme_Count, ORF_Coverage_Residue_Count, ORF_Coverage_Fraction, Potential_Full_Enzyme_Count, Potential_Partial_Enzyme_Count, Potential_ORF_Coverage_Residue_Count, Potential_ORF_Coverage_Fraction, FractionScansMatchingSingleMassTag')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'AverageAcrossColumns', 1, 7, N'tinyint', 1, N'Set 1 to include a final column in the output that is an average across all columns for the given row.  If enabled, will result in slower execution times and supports fewer total QID values due to Sql Server varchar limitations.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'message', 2, 4, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'Ref_ID', 3, 1, N'int', 4, N'Unique integer identification number for the given protein (aka ORF or Reference).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'Reference', 3, 2, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (32, N'Protein_Description', 3, 3, N'varchar', 512, N'Description for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'SourceColName', 1, 2, N'varchar', 128, N'Column whose value is to be returned in the crosstab report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'QuantitationIDList', 1, 3, N'varchar', 1024, N'Comma separated list of Quantitation_ID report IDs to return; may contain just one value.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'SeparateReplicateDataIDs', 1, 5, N'tinyint', 1, N'If 1, then will separate out replicate-based Q Rollups into separate columns.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'AggregateColName', 1, 6, N'varchar', 128, N'The column whose value is to be displayed in the crosstab output.  Valid columns include MT_Abundance, ER, Mass_Error_PPM_Avg, UMC_MatchCount_Avg, SingleMT_MassTagMatchingIonCount, SingleMT_FractionScansMatchingSingleMT, ReplicateCountAvg, FractionCountAvg, TopLevelFractionCount')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'AverageAcrossColumns', 1, 7, N'tinyint', 1, N'Set 1 to include a final column in the output that is an average across all columns for the given row.  If enabled, will result in slower execution times and supports fewer total QID values due to Sql Server varchar limitations.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'message', 2, 4, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'Ref_ID', 3, 1, N'int', 4, N'Unique integer identification number for the given protein (aka ORF or Reference).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'Reference', 3, 2, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'Protein_Description', 3, 3, N'varchar', 512, N'Description for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'Mass_Tag_ID', 3, 4, N'int', 4, N'Unique integer identification number for the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'Peptide', 3, 5, N'varchar', 750, N'Sequence of the PMT (peptide)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (33, N'Mass_Tag_Mods', 3, 6, N'varchar', 2048, N'Amino acid residue modifications associated with the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'QuantitationIDList', 1, 2, N'varchar', 1024, N'Comma separated list of Quantitation_ID report IDs to return; may contain just one value.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'SeparateReplicateDataIDs', 1, 3, N'tinyint', 1, N'If 1, then will separate out replicate-based Q Rollups into separate columns.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'IncludeRefColumn', 1, 5, N'tinyint', 1, N'If True, then deleted databases are included.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'VerboseColumnOutput', 1, 7, N'tinyint', 1, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'message', 2, 4, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Description', 2, 6, N'varchar', 32, N'Short description of the Q Rollups included in the output.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Sample_Name', 3, 1, N'varchar', 255, N'Description associated with the given Q Rollup report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Ref_ID', 3, 2, N'int', 4, N'Unique integer identification number for the given protein (aka ORF or Reference).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Reference', 3, 3, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Protein_Description', 3, 4, N'varchar', 512, N'Description for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Abundance_Average', 3, 5, N'float', 8, N'Average protein abundance.  Computed by averaging the high abundance peptides for the given protein (typically, all peptides whose abundances are >= 33% times the most abundant peptide for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Abundance_StDev', 3, 6, N'float', 8, N'Protein abundance standard deviation.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'SLiC_Score_Avg', 3, 7, N'float', 8, N'Average Spatially Localized Confidence Score (SLiC Score).  This is the average SLiC score for the peptides that were identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Mass_Tag_Count_Unique_Observed', 3, 8, N'int', 4, N'Unique number of PMTs (peptides) identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Internal_Standard_Count_Unique_Observed', 3, 9, N'int', 4, N'Unique number of internal standard peptides identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Peptide_Count_Used_For_Abundance_Avg', 3, 10, N'int', 4, N'Unique number of peptides whose abundance values were averaged together to compute the protein abundance value.  The column "Used For Abundance Computation" in the peptide results list will have a value of 1 for all peptides included in the averaging.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Full_Enzyme_Count', 3, 11, N'int', 4, N'Number of fully tryptic PMTs identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Potential_Full_Enzyme_Count', 3, 12, N'int', 4, N'Number of fully tryptic PMTs in the PMT tag database for the given protein.  This is not the number identified by LC-FTICR-MS; rather, it is the number putatively identified by LC-MS/MS and thus the total number that could possibly be identified by LC-FTICR-MS.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Full_Enzyme_No_Missed_Cleavage_Count', 3, 13, N'int', 4, N'Number of fully tryptic PMTs with no missed cleavages identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Partial_Enzyme_Count', 3, 14, N'int', 4, N'Number of partially tryptic PMTs identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Potential_Partial_Enzyme_Count', 3, 15, N'int', 4, N'Number of partially tryptic PMTs in the PMT tag database for the given protein.  This is not the number identified by LC-FTICR-MS; rather, it is the number putatively identified by LC-MS/MS and thus the total number that could possibly be identified by LC-FTICR-MS.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'ORF_Coverage_Residue_Count', 3, 16, N'int', 4, N'Number of residues for the given protein (ORF) that were matched, when considering all of the PMTs (peptides) that were matched for this protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Potential_Protein_Coverage_Residue_Count', 3, 17, N'int', 4, N'Potential number of residues for the given protein (ORF) that could be matched, if all PMTs in the PMT tag database for the given protein were identified.  This is not the number of residues identified by LC-FTICR-MS; rather, it is the number putatively identified by LC-MS/MS and thus the total number that could possibly be identified by LC-FTICR-MS.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Protein_Coverage_Percent', 3, 18, N'decimal', 5, N'Residue-based coverage (percent) for the given protein, when considering all of the PMTs (peptides) that were matched for this protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Potential_Protein_Coverage_Percent', 3, 19, N'decimal', 5, N'Potential residue-based coverage (percent) for the given protein, if all PMTs in the PMT tag database for the given protein were identified.  This is not the percent coverage identified by LC-FTICR-MS; rather, it is the coverage based on the peptides putatively identified by LC-MS/MS and thus the highest coverage that could possibly be achived using LC-FTICR-MS.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Protein_Coverage_Percent_High_Abundance', 3, 20, N'decimal', 5, N'Residue-based coverage (percent) for the given protein, when considering all of the high abundance PMTs (peptides) that were matched for this protein.  The high abundance peptides have a value of 1 in the "Used For Abundance Computation" column in the peptide results list.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Protein_Count_Avg', 3, 21, N'decimal', 5, N'Average Protein_Count value for all PMTs (peptides) identified for the given protein.  If all of the peptides'' sequences are only present in this protein''s sequence, then Average Protein_Count is 1.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Mass_Tag_ID', 3, 22, N'int', 4, N'Unique integer identification number for the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Mass_Tag_Mods', 3, 23, N'varchar', 50, N'Amino acid residue modifications associated with the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'MT_Abundance', 3, 24, N'float', 8, N'Abundance of the PMT (peptide).  Computed using the area under the chromatographic peak for the UMC that matched the given PMT.  If the PMT was matched by several UMCs, then this is the sum of the abundances for the matching UMCs.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'MT_Abundance_StDev', 3, 25, N'float', 8, N'Standard deviation of the PMT abundance.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Member_Count_Used_For_Abundance', 3, 26, N'decimal', 5, N'Number of data points (scans) within the UMC that were summed to compute the abundance for the given UMC.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'MT_SLiC_Score_Avg', 3, 27, N'float', 8, N'Spatially Localized Confidence Score (SLiC Score).  This score represents the uniqueness of the given PMT matching the associated UMC.  If the associated UMC only matched one PMT, then MT_SLiC_Score_Avg will be 1.  If itmatched two PMTs, but one was much closer in mass and NET than the second, then the first could have a SLiC score of 0.8 and the second a score of 0.2')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'MT_Del_SLiC_Avg', 3, 28, N'float', 8, N'Difference in SLiC score between this PMT and the highest scoring PMT matching the UMC that identified this PMT.  If this was the highest confidence PMT match for the given UMC, then MT_Del_SLiC_Avg = 0.  This value will be the average of several values if replicate results are rolled up.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Peptide', 3, 29, N'varchar', 850, N'Sequence of the PMT (peptide)')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Monoisotopic_Mass', 3, 30, N'float', 8, N'Uncharged mass of the PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'High_MS/MS_Score_(XCorr)', 3, 31, N'real', 4, N'Highest MS/MS fragmentation spectrum identification score observed for the given PMT (peptide).  This is typically the highest Sequest XCorr value observed.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'High_Discriminant_Score', 3, 32, N'real', 4, N'Highest discriminant score computed for the given PMT (peptide).  Discriminant scores are based on LC-MS/MS observations.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'PMT_Quality_Score', 3, 33, N'decimal', 5, N'Rough indication of the confidence of the PMT identity based on LC-MS/MS data.  This value is typically 0, 1, or 2, with 0 being low confidence, 1 being higher, and 2 being the highest.  The confidence is based on XCorr and DelCn cutoff values that vary from database to database.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Protein_Count', 3, 34, N'tinyint', 1, N'Number of proteins that the given PMT (peptide) is present in (aka protein or ORF degeneracy).  If the peptide sequence is only present in one protein''s sequence, then Protein_Count = 1.  If the peptide sequence is present in two proteins'' sequences, then Protein_Count = 2.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Cleavage_State_Name', 3, 35, N'varchar', 50, N'The enzymatic cleavage state for the given PMT (peptide), in the context of the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'UMC_MatchCount_Avg', 3, 36, N'decimal', 5, N'Number of UMCs that matched the given PMT.  If replicate or fractionated datasets are rolled up in this Q Rollup, then this is the average of the UMC match count for each.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Scan_Minimum', 3, 37, N'int', 4, N'Ending scan number of the UMCs that matched the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Scan_Maximum', 3, 38, N'int', 4, N'Ending scan number of the UMCs that matched the given PMT (peptide).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'NET_Minimum', 3, 39, N'decimal', 5, N'Minimum NET for the UMC matching this PMT.  If only one dataset is included in the rollup, then NET_Minimum will be the same as NET_Maximum.  If more than one dataset is rolled up, then this is the minimum NET of all UMCs that matched the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'NET_Maximum', 3, 40, N'decimal', 5, N'Maximum NET for the UMC matching this PMT.  If only one dataset is included in the rollup, then NET_Maximum will be the same as NET_Minimum.  If more than one dataset is rolled up, then this is the maximum NET of all UMCs that matched the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Charge_Basis_Avg', 3, 41, N'decimal', 5, N'The primary charge state associated with the UMC that matched the given PMT.  If several UMCs led to this identification, then this is the average of the primary charge states for each.  If replicate or fractionated datasets are rolled up in this Q Rollup, then this is the average of the primary charge states for each.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Charge_State_Min', 3, 42, N'tinyint', 1, N'The minimum charge state associated with the UMC(s) that matched the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Charge_State_Max', 3, 43, N'tinyint', 1, N'The maximum charge state associated with the UMC(s) that matched the given PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'MT_Mass_Error_PPM_Avg', 3, 44, N'decimal', 5, N'Mass difference, in ppm, between the UMC''s median mass and the PMT''s theoretical monoisotopic mass.  This value will be the average of several values if replicate results are rolled up.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'NET_Error_Obs_Avg', 3, 45, N'decimal', 5, N'NET difference between the UMC''s median NET and the PMT''s observed NET.  This value will be the average of several values if replicate results are rolled up.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'NET_Error_Pred_Avg', 3, 46, N'decimal', 5, N'NET difference between the UMC''s median NET and the PMT''s predicted NET.  The predicted NET is different than the observed NET for a PMT since the observed NET is the average observed elution time for the peptide while the predicted NET is the elution time predicted by a trained prediction model.  This value will be the average of several values if replicate results are rolled up.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (34, N'Used_For_Abundance_Computation', 3, 47, N'tinyint', 1, N'Will be 1 if the given PMT (peptide) was included in the group of PMTs whose abundance values were averaged together to compute the protein abundance value for the protein associated with this PMT.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'QuantitationIDList', 1, 2, N'varchar', 1024, N'Comma separated list of Quantitation_ID report IDs to return; may contain just one value.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'SeparateReplicateDataIDs', 1, 3, N'tinyint', 1, N'If 1, then will separate out replicate-based Q Rollups into separate columns.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'ReplicateCountAvgMinimum', 1, 5, N'decimal', 5, N'Minimum average replicate count value to require for proteins returned.  If the Q rollup does not contain replicate rollups, then this value is ignored.  The average replicate count is an average of the number of replicates in which each peptide for the given protein was observed.  Setting ReplicateCountAvgMinimum to a value >1 for replicate rollups will have the effect of filtering out lower quality protein identifications.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'VerboseColumnOutput', 1, 7, N'tinyint', 1, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'message', 2, 4, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Description', 2, 6, N'varchar', 32, N'Short description of the Q Rollups included in the output.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Sample_Name', 3, 1, N'varchar', 255, N'Description associated with the given Q Rollup report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Ref_ID', 3, 2, N'int', 4, N'Unique integer identification number for the given protein (aka ORF or Reference).')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Reference', 3, 3, N'varchar', 128, N'Protein identification text')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Protein_Description', 3, 4, N'varchar', 512, N'Description for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Abundance_Average', 3, 5, N'float', 8, N'Average protein abundance.  Computed by averaging the high abundance peptides for the given protein (typically, all peptides whose abundances are >= 33% times the most abundant peptide for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Abundance_StDev', 3, 6, N'float', 8, N'Protein abundance standard deviation.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'SLiC_Score_Avg', 3, 7, N'float', 8, N'Average Spatially Localized Confidence Score (SLiC Score).  This is the average SLiC score for the peptides that were identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Mass_Tag_Count_Unique_Observed', 3, 8, N'int', 4, N'Unique number of PMTs (peptides) identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Internal_Standard_Count_Unique_Observed', 3, 9, N'int', 4, N'Unique number of internal standard peptides identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Peptide_Count_Used_For_Abundance_Avg', 3, 10, N'int', 4, N'Unique number of peptides whose abundance values were averaged together to compute the protein abundance value.  The column "Used For Abundance Computation" in the peptide results list will have a value of 1 for all peptides included in the averaging.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Full_Enzyme_Count', 3, 11, N'int', 4, N'Number of fully tryptic PMTs identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Potential_Full_Enzyme_Count', 3, 12, N'int', 4, N'Number of fully tryptic PMTs in the PMT tag database for the given protein.  This is not the number identified by LC-FTICR-MS; rather, it is the number putatively identified by LC-MS/MS and thus the total number that could possibly be identified by LC-FTICR-MS.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Full_Enzyme_No_Missed_Cleavage_Count', 3, 13, N'int', 4, N'Number of fully tryptic PMTs with no missed cleavages identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Partial_Enzyme_Count', 3, 14, N'int', 4, N'Number of partially tryptic PMTs identified for the given protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Potential_Partial_Enzyme_Count', 3, 15, N'int', 4, N'Number of partially tryptic PMTs in the PMT tag database for the given protein.  This is not the number identified by LC-FTICR-MS; rather, it is the number putatively identified by LC-MS/MS and thus the total number that could possibly be identified by LC-FTICR-MS.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'ORF_Coverage_Residue_Count', 3, 16, N'int', 4, N'Number of residues for the given protein (ORF) that were matched, when considering all of the PMTs (peptides) that were matched for this protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Potential_Protein_Coverage_Residue_Count', 3, 17, N'int', 4, N'Potential number of residues for the given protein (ORF) that could be matched, if all PMTs in the PMT tag database for the given protein were identified.  This is not the number of residues identified by LC-FTICR-MS; rather, it is the number putatively identified by LC-MS/MS and thus the total number that could possibly be identified by LC-FTICR-MS.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Protein_Coverage_Percent', 3, 18, N'decimal', 5, N'Residue-based coverage (percent) for the given protein, when considering all of the PMTs (peptides) that were matched for this protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Potential_Protein_Coverage_Percent', 3, 19, N'decimal', 5, N'Potential residue-based coverage (percent) for the given protein, if all PMTs in the PMT tag database for the given protein were identified.  This is not the percent coverage identified by LC-FTICR-MS; rather, it is the coverage based on the peptides putatively identified by LC-MS/MS and thus the highest coverage that could possibly be achived using LC-FTICR-MS.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Protein_Coverage_Percent_High_Abundance', 3, 20, N'decimal', 5, N'Residue-based coverage (percent) for the given protein, when considering all of the high abundance PMTs (peptides) that were matched for this protein.  The high abundance peptides have a value of 1 in the "Used For Abundance Computation" column in the peptide results list.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Protein_Count_Avg', 3, 21, N'decimal', 5, N'Average Protein_Count value for all PMTs (peptides) identified for the given protein.  If all of the peptides'' sequences are only present in this protein''s sequence, then Average Protein_Count is 1.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (35, N'Mono_Mass_KDa', 3, 22, N'float', 8, N'Uncharged mass of the protein.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'MTDBName', 1, 1, N'varchar', 128, N'Database to obtain results from.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'QuantitationIDList', 1, 2, N'varchar', 1024, N'Comma separated list of Quantitation_ID report IDs to return; may contain just one value.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'VerboseColumnOutput', 1, 4, N'tinyint', 1, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'message', 2, 3, N'varchar', 512, N'Output message; will contain a description of any error that occurred.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Quantitation ID', 3, 1, N'int', 4, N'Q Rollup report ID')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Sample Name', 3, 2, N'varchar', 255, N'Description associated with the given Q Rollup report.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Comment', 3, 3, N'varchar', 255, N'Comment for the given Q Rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Experiments', 3, 4, N'varchar', 1024, N'Experiments contained in the peak matching tasks associated with the given Q Rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Jobs', 3, 5, N'varchar', 1024, N'List of jobs included in rollup')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Results Folder Path', 3, 6, N'varchar', 255, N'Location of folder containg the graphics and chromatograms of the peak matching results.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Fraction Highest Abu To Use', 3, 7, N'decimal', 5, N'Decimal value to multiply the abundance value of the most abundant peptide for each protein by when determining the cutoff to use for choosing peptides to average together to compute average protein abundances.  Typically 0.33')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Feature (UMC) Count', 3, 8, N'int', 4, N'Number of features (UMCs) observed in the dataset used for peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Feature Count With Hits', 3, 9, N'int', 4, N'Number of features (UMCs) in the given Q rollup that had one or more matching PMT tags.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Unique PMT Tag Count Matched', 3, 10, N'int', 4, N'Unique number of PMT tags (peptides) identified in the given Q rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Unique Internal Standard Count Matched', 3, 11, N'int', 4, N'Unique number of internal standard peptides identified in the given Q rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Comparison PMT Tag Count', 3, 12, N'int', 4, N'Number of PMT tags (peptides) that the UMCs were compared against in the peak matching task(s) included in the given Q Rollup.  If more than one peak matching tasks are rolled up, then this is an average for all tasks included, though the number of PMTs used will typically be the same for all tasks included in a single rollup.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'MD UMC TolerancePPM', 3, 13, N'numeric', 5, N'Tolerance used when grouping data points into UMCs in the dataset used for peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'MD NetAdj NET Min', 3, 14, N'numeric', 5, N'Minimum NET value in the dataset used for peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'MD NetAdj NET Max', 3, 15, N'numeric', 5, N'Maximum NET value in the dataset used for peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'MD MMA TolerancePPM', 3, 16, N'numeric', 5, N'Mass tolerance (in ppm) used during peak matching when matching UMCs to PMTs.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'MD NET Tolerance', 3, 17, N'numeric', 5, N'Normalized elution time tolerance used during peak matching when matching UMCs to PMTs.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Refine Mass Cal PPMShift', 3, 18, N'numeric', 5, N'Mass correction factor applied to the UMC masses during peak matching to correct for systematic calibration error in the dataset.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Total_Scans_Avg', 3, 19, N'int', 4, N'Average number of scans in which peptide was seen')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Scan_Start', 3, 20, N'int', 4, N'Initial scan number in the dataset used for peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'Scan_End', 3, 21, N'int', 4, N'Final scan number in the dataset used for peak matching.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (36, N'ReplicateNormalizationStats', 3, 22, N'varchar', 1024, N'Summary of the normalization steps applied for replicate-based Q Rollups.')
INSERT INTO dbo.T_SP_Glossary
  VALUES (37, N'DBName', 1, 1, N'varchar', 128, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (37, N'DBType', 2, 2, N'tinyint', 1, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (37, N'DBSchemaVersion', 2, 3, N'real', 4, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (37, N'DBID', 2, 4, N'int', 4, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (37, N'message', 2, 5, N'varchar', 256, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (39, N'DBName', 1, 1, N'varchar', 128, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (39, N'outputColumnNameList', 1, 2, N'varchar', 2048, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (39, N'criteriaSql', 1, 3, N'varchar', 6000, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (39, N'returnRowCount', 1, 4, N'varchar', 32, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (39, N'pepIdentMethod', 1, 6, N'varchar', 32, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (39, N'message', 2, 5, N'varchar', 512, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (40, N'DBName', 1, 1, N'varchar', 128, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (40, N'DBSchemaVersion', 2, 2, N'real', 4, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (40, N'message', 2, 3, N'varchar', 256, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (41, N'DBName', 1, 1, N'varchar', 128, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (41, N'outputColumnNameList', 1, 2, N'varchar', 2048, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (41, N'criteriaSql', 1, 3, N'varchar', 6000, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (41, N'returnRowCount', 1, 4, N'varchar', 32, NULL)
INSERT INTO dbo.T_SP_Glossary
  VALUES (41, N'message', 2, 5, N'varchar', 512, NULL)

go


USE MT_Main
/*
	-- get names of files in DB backup file

	RESTORE FILELISTONLY
	FROM DISK = @templateFilePath
*/

declare @newDBNameRoot varchar(64)
declare @newDBNameType char(1)
declare @description varchar(256)
declare @campaign varchar(64)
declare @peptideDBName varchar(128)
declare @proteinDBName varchar(128)
declare @OrganismDBFileList varchar(128)
declare @UseProteinSequencesDB tinyint

declare @ParameterFileList varchar(512)
declare @ExperimentFilterList varchar(512)
declare @ExperimentExclusionFilterList varchar(512)
declare @DatasetFilterList varchar(512)
declare @DatasetExclusionFilterList varchar(512)

declare @PeptideImportFilterID varchar(512)
declare @SeparationTypeList varchar(512)
declare @DatasetDateMinimum varchar(32)
declare @PMTQualityScoreSetList varchar(512)

declare @message varchar(512)
declare @newDBName varchar(128)
declare @result int

declare	@dbState int
declare	@dataStoragePath varchar(256)

set @newDBNameRoot = 'A_Thaliana_Rhizo_GS'
set @newDBNameType = 'P'
set @description = 'A_thaliana Rhizo_GS'
set @campaign = 'Rhizomics - Plant and Soil Interface'							    -- Can be comma separated list
set	@peptideDBName  = 'PT_A_Thaliana_A58'
set	@proteinDBName = ''												-- Leave blank if unknown or if using Protein Collections (i.e. using the Protein_Sequences DB on Gigasax)
set @OrganismDBFileList = 'A_thaliana_Rhizo_Community_2015-05-07.fasta'		-- Can be comma separated list
set @UseProteinSequencesDB = 1										-- Set to 1 to use the Protein_Sequences database in DMS to lookup Protein Collection information

set @ParameterFileList = 'MSGFDB_Tryp_NoMods_20ppmParTol.txt'

set @ExperimentFilterList = ''					-- Can be comma separated list
set @ExperimentExclusionFilterList = ''								-- Can be comma separated list

set @DatasetFilterList = ''											-- Can be comma separated list
set @DatasetExclusionFilterList = ''								-- Can be comma separated list

set @PeptideImportFilterID = '117'									-- Loose filter for importing peptides, tyically 117 = partially or fully tryptic
set @SeparationTypeList = 'LC-Waters-Formic_3hr'					-- Typically LC-ISCO-Standard or LC-Agilent

set @DatasetDateMinimum = '12/1/2014'
set @PMTQualityScoreSetList = '213, 1; 214, 2; 215, 3; 216, 4'	-- Separate multiple entries with a semicolon; default to '213, 1; 214, 2; 215, 3'  (previously, '204, 1; 206, 2; 207, 3; 209, 4'; before that, '105, 1; 107, 2')
																-- 204 is "MSGF <= 1E-8, partially/fully tryptic"; 206 is MSGF <= 1E-9, partially/fully tryptic";
																-- 207 is "MSGF <= 1E-10, partially/fully tryptic"; 209 is "MSGF <= 1E-11; peptide prophet >= 0.5"
																-- 213 is "MSGFDB FDR <= 10%"; 214 is "MSGFDB FDR <= 5%, MSAlign < 1E-5"
																-- 215 is "MSGFDB FDR <= 1%, MSAlign < 1E-6"; 216 is "MSGFDB FDR <= 0.5%"
/*	
	DB State values
	0           (na)
	1           Development
	2           Production
	3           Frozen
	5           Pre-Production
*/								

set @message = ''
set @dbState = 5							-- 5 is Pre-Production (for actual use) 
									-- 3 is Frozen to keep normal activities such as updates from occuring (set to 5 in MT_Main > T_MT_Database_List)
exec @result = MakeNewMassTagDB
	@newDBNameRoot,
	@newDBNameType,
	@description,
	@campaign,
	@peptideDBName,
	@proteinDBName,
	@OrganismDBFileList,
	@message output,
	@newDBName output,
	@dbState
					
select @message 

-- Configure the remaining settings for this database
If @result = 0
Exec @result = ConfigureMassTagDB @newDBName, @campaign,
				  @peptideDBName, @proteinDBName, @OrganismDBFileList, @ParameterFileList,
				  @PeptideImportFilterID, @PMTQualityScoreSetList, @SeparationTypeList,
				  @ExperimentFilterList, @ExperimentExclusionFilterList, 
				  @DatasetFilterList, @DatasetExclusionFilterList,
				  @DatasetDateMinimum, @UseProteinSequencesDB

GO

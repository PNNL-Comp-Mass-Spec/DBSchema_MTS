SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ConfigureMassTagDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ConfigureMassTagDB]
GO

CREATE PROCEDURE ConfigureMassTagDB
/****************************************************
**
**	Desc: Sets configuration for mass tag database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 09/22/2004
**			  10/01/2004 mem - Added @ExperimentExclusionFilterList, @PMTQualityScoreSetList, 
**							   @DatasetFilterList, and @DatasetExclusionFilterList
**			  12/17/2004 mem - Increased field sizes for the input parameters
**    
*****************************************************/
	@MTDBName varchar(64) = '',
	@campaign varchar(1024) = '',					-- e.g. Deinococcus  (can be a comma separated list)
	@peptideDBName varchar(1024) = '',				-- e.g. PT_Deinococcus_A55  (can be a comma separated list)
	@proteinDBName varchar(1024) = '',				-- e.g. ORF_Deinococcus_V23 (can be a comma separated list)
	@OrganismDBFileList varchar(1024) = '',			-- e.g. GDR_2000-03-21.fasta  (can be a comma separated list)
	@ParameterFileList varchar(1024) = '',			-- e.g. sequest_N14_NE.params, sequest_N14_NE_Stat_C_Iodoacetimide.params  (can be a comma separated list)

	@PeptideImportFilterIDList varchar(64) = '',	-- e.g. 117
	@PMTQualityScoreSetList varchar(512) = '',		-- e.g. 105, 1				(separate values with a semicolon)
	@SeparationTypeList varchar(512) = '',			-- e.g. LC-ISCO-Standard

	@ExperimentFilterList varchar(512) = '',			-- e.g. DRAD%, DR104		(Can be single value or comma separated list; can contain % wildcards)
	@ExperimentExclusionFilterList varchar(512) = '',	-- (Can be single value or comma separated list; can contain % wildcards)
	@DatasetFilterList varchar(512) = '',				-- (Can be single value or comma separated list; can contain % wildcards)
	@DatasetExclusionFilterList varchar(512) = '',		-- (Can be single value or comma separated list; can contain % wildcards)

	@DatasetDateMinimum	varchar(32) = '',			-- e.g. 1/1/2000

	@message varchar(512) = '' output
AS
	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''

	declare @organism varchar(64)
	set @organism = ''
	
	---------------------------------------------------
	-- Lookup the organism name for @peptideDBName
	-- If no match is found, then @organism will remain blank
	---------------------------------------------------

	SELECT	@organism = PDB_Organism
	FROM	T_Peptide_Database_List
	WHERE	PDB_Name = @peptideDBName
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
		SELECT 'Warning: Peptide database ' + @peptideDBName + ' not found; organism will remain unchanged'

	---------------------------------------------------
	-- Populate T_Process_Config with the given values
	---------------------------------------------------

	Exec AddUpdateConfigEntry @MTDBName, 'Campaign', @campaign
	Exec AddUpdateConfigEntry @MTDBName, 'Peptide_DB_Name', @peptideDBName
	Exec AddUpdateConfigEntry @MTDBName, 'Protein_DB_Name', @proteinDBName

	Exec AddUpdateConfigEntry @MTDBName, 'Organism_DB_File_Name', @OrganismDBFileList, ','
	Exec AddUpdateConfigEntry @MTDBName, 'Organism', @organism
	Exec AddUpdateConfigEntry @MTDBName, 'Parameter_File_Name', @ParameterFileList

	Exec AddUpdateConfigEntry @MTDBName, 'Peptide_Import_Filter_ID', @PeptideImportFilterIDList
	Exec AddUpdateConfigEntry @MTDBName, 'PMT_Quality_Score_Set_ID_and_Value', @PMTQualityScoreSetList, ';'
	Exec AddUpdateConfigEntry @MTDBName, 'Separation_Type', @SeparationTypeList

	Exec AddUpdateConfigEntry @MTDBName, 'Experiment', @ExperimentFilterList
	Exec AddUpdateConfigEntry @MTDBName, 'Experiment_Exclusion', @ExperimentExclusionFilterList
	Exec AddUpdateConfigEntry @MTDBName, 'Dataset', @DatasetFilterList
	Exec AddUpdateConfigEntry @MTDBName, 'Dataset_Exclusion', @DatasetExclusionFilterList
	
	Exec AddUpdateConfigEntry @MTDBName, 'Dataset_DMS_Creation_Date_Minimum', @DatasetDateMinimum


Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[ConfigureMassTagDB]  TO [DMS_SP_User]
GO


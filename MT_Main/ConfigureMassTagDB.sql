/****** Object:  StoredProcedure [dbo].[ConfigureMassTagDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**	Auth:	mem
**	Date:	09/22/2004
**			10/01/2004 mem - Added @ExperimentExclusionFilterList, @PMTQualityScoreSetList, @DatasetFilterList, and @DatasetExclusionFilterList
**			12/17/2004 mem - Increased field sizes for the input parameters
**			07/25/2006 mem - Added parameter @UseProteinSequencesDB
**			07/27/2006 mem - Updated to use @OrganismDBFileList to also populate Protein_Collection_Filter
**			05/15/2007 mem - Expanded several input parameters to varchar(max)
**			10/28/2011 mem - Added parameter @PeptideImportMSGFSpecProbFilter
**			07/21/2015 mem - Switched to using ScrubWhitespace to remove whitespace (including space, tab, and carriage return)
**			06/20/2017 mem - Expand @MTDBName to varchar(128)
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',
	@campaign varchar(1024) = '',					-- e.g. Deinococcus  (can be a comma separated list)
	@peptideDBName varchar(1024) = '',				-- e.g. PT_Deinococcus_A55  (can be a comma separated list)
	@proteinDBName varchar(1024) = '',				-- e.g. ORF_Deinococcus_V23 (can be a comma separated list)
	@OrganismDBFileList varchar(max) = '',			-- Comma separated list of fasta files or comma separated list of protein collection names; e.g. 'PCQ_ETJ_2004-01-21.fasta,PCQ_ETJ_2004-01-21'
	@ParameterFileList varchar(max) = '',			-- e.g. sequest_N14_NE.params, sequest_N14_NE_Stat_C_Iodoacetimide.params  (can be a comma separated list)
	
	@PeptideImportFilterIDList varchar(512) = '',	-- e.g. 117
	@PMTQualityScoreSetList varchar(512) = '',		-- e.g. 105, 1				(separate values with a semicolon)
	@SeparationTypeList varchar(max) = '',			-- e.g. LC-ISCO-Standard

	@ExperimentFilterList varchar(max) = '',			-- e.g. DRAD%, DR104		(Can be single value or comma separated list; can contain % wildcards)
	@ExperimentExclusionFilterList varchar(max) = '',	-- (Can be single value or comma separated list; can contain % wildcards)
	@DatasetFilterList varchar(max) = '',				-- (Can be single value or comma separated list; can contain % wildcards)
	@DatasetExclusionFilterList varchar(max) = '',		-- (Can be single value or comma separated list; can contain % wildcards)

	@DatasetDateMinimum	varchar(32) = '',			-- e.g. 1/1/2000
	@UseProteinSequencesDB tinyint = 1,				-- Set to 1 to use the V_DMS_Protein_Sequences views to obtain the protein sequence information for protein names

	@PeptideImportMSGFSpecProbFilter varchar(24) = '1',
	
	@message varchar(512) = '' output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	Declare @organism varchar(64) = ''
	Declare @S varchar(512)
	
	---------------------------------------------------
	-- Remove any leading or trailing whitespace
	---------------------------------------------------
	--	
	Set @MTDBName = dbo.ScrubWhitespace(IsNull(@MTDBName , ''))
	Set @campaign = dbo.ScrubWhitespace(IsNull(@campaign, ''))
	Set @peptideDBName = dbo.ScrubWhitespace(IsNull(@peptideDBName, ''))
	Set @proteinDBName = dbo.ScrubWhitespace(IsNull(@proteinDBName, ''))
	Set @OrganismDBFileList = dbo.ScrubWhitespace(IsNull(@OrganismDBFileList, ''))
	Set @ParameterFileList = dbo.ScrubWhitespace(IsNull(@ParameterFileList, ''))
	
	Set @PeptideImportFilterIDList = dbo.ScrubWhitespace(IsNull(@PeptideImportFilterIDList , ''))
	Set @PMTQualityScoreSetList = dbo.ScrubWhitespace(IsNull(@PMTQualityScoreSetList, ''))
	Set @SeparationTypeList = dbo.ScrubWhitespace(IsNull(@SeparationTypeList, ''))

	Set @ExperimentFilterList = dbo.ScrubWhitespace(IsNull(@ExperimentFilterList, ''))
	Set @ExperimentExclusionFilterList = dbo.ScrubWhitespace(IsNull(@ExperimentExclusionFilterList, ''))
	Set @DatasetFilterList = dbo.ScrubWhitespace(IsNull(@DatasetFilterList, ''))
	Set @DatasetExclusionFilterList = dbo.ScrubWhitespace(IsNull(@DatasetExclusionFilterList, ''))

	Set @DatasetDateMinimum = dbo.ScrubWhitespace(IsNull(@DatasetDateMinimum, ''))

	Set @PeptideImportMSGFSpecProbFilter = dbo.ScrubWhitespace(IsNull(@PeptideImportMSGFSpecProbFilter, ''))
	
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

	If Len(@OrganismDBFileList) > 0
	Begin
		Exec @myError = ConfigureOrganismDBFileFilters @MTDBName, @OrganismDBFileList, @message = @message output
		
		if @myError <> 0
		Begin
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error calling ConfigureOrganismDBFileFilters with @OrganismDBFileList = ' + @OrganismDBFileList
			goto done
		end
	End

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

	Exec AddUpdateConfigEntry @MTDBName, 'Peptide_Import_MSGF_SpecProb_Filter', @PeptideImportMSGFSpecProbFilter

	-- Update T_Process_Step_Control as needed
	Set @UseProteinSequencesDB = IsNull(@UseProteinSequencesDB, 0)
	If @UseProteinSequencesDB <> 0
		Set @UseProteinSequencesDB = 1
	
	Set @S = ''
	Set @S = @S + ' UPDATE [' + @MTDBName + '].dbo.T_Process_Step_Control'
	Set @S = @S + ' SET Enabled = ' + Convert(varchar(9), @UseProteinSequencesDB)
	Set @S = @S + ' WHERE Processing_Step_Name = ''UseProteinSequencesDB'''
	
	Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[ConfigureMassTagDB] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ConfigureMassTagDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ConfigureMassTagDB] TO [MTS_DB_Lite] AS [dbo]
GO

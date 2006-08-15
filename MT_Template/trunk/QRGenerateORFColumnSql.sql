/****** Object:  StoredProcedure [dbo].[QRGenerateORFColumnSql] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QRGenerateORFColumnSql
/****************************************************	
**  Desc: Generates the sql for the ORF column data
**		  obtained from T_Quantitation_Results
**
**  Return values: 0 if success, otherwise, error code
**
**  Parameters: @OrfColumnSql output parameter
**
**  Auth:	mem
**	Date:	04/09/2004
**			06/06/2004 mem - Added ORF_Coverage_Fraction_High_Abundance column
**			07/10/2004 mem - Added Match_Score_Average column
**			10/05/2004 mem - Updated for new MTDB schema
**			11/09/2004 mem - Renamed the match score columns to SLiC Score, removed some of the legacy, less useful columns, and changed coverage values to be percents rather than fractions
**			05/24/2005 mem - Added column InternalStdCountUniqueObserved and updated protein description linking method
**			05/25/2005 mem - Added underscores at word boundaries in columns QD.SampleName, QR.MassTagCountUniqueObserved, and QR.MassTagCountUsedForAbundanceAvg
**			07/25/2006 mem - Now obtaining the protein Description from T_Proteins instead of from an external ORF database
**
****************************************************/
(
	@ERValuesPresent float = 0,
	@OrfColumnSql varchar(2048) = '' OUTPUT
)
AS

	Declare @sql varchar(2048)
	
	Set @sql = ''
	Set @sql = @sql + 'SELECT QD.SampleName AS Sample_Name,'
	Set @sql = @sql + 'QR.Ref_ID,'
	Set @sql = @sql + 'T_Proteins.Reference,'
	Set @sql = @sql + 'T_Proteins.Description AS Protein_Description,'
	Set @sql = @sql + 'Round(QR.Abundance_Average,4) AS Abundance_Average,'
	Set @sql = @sql + 'Round(QR.Abundance_StDev,4) AS Abundance_StDev,'
	Set @sql = @sql + 'Round(QR.Match_Score_Average,3) AS SLiC_Score_Avg,'
	
	If @ERValuesPresent > 0
	Begin
		Set @sql = @sql + 'QR.ER_Average,'
		Set @sql = @sql + 'QR.ER_StDev,'
	End
	
	Set @sql = @sql + 'QR.MassTagCountUniqueObserved AS Mass_Tag_Count_Unique_Observed,'
	Set @sql = @sql + 'QR.InternalStdCountUniqueObserved AS Internal_Std_Count_Unique_Observed,'
	Set @sql = @sql + 'QR.MassTagCountUsedForAbundanceAvg AS Peptide_Count_Used_For_Abundance_Avg,'
	
	Set @sql = @sql + 'QR.Full_Enzyme_Count,'
	Set @sql = @sql + 'QR.Potential_Full_Enzyme_Count,'
	Set @sql = @sql + 'QR.Full_Enzyme_No_Missed_Cleavage_Count,'
	Set @sql = @sql + 'QR.Partial_Enzyme_Count,'
	Set @sql = @sql + 'QR.Potential_Partial_Enzyme_Count,'
	Set @sql = @sql + 'QR.ORF_Coverage_Residue_Count,'
	Set @sql = @sql + 'QR.Potential_ORF_Coverage_Residue_Count AS Potential_Protein_Coverage_Residue_Count,'
	Set @sql = @sql + 'Round(QR.ORF_Coverage_Fraction*100,1) AS Protein_Coverage_Percent,'
	Set @sql = @sql + 'Round(QR.Potential_ORF_Coverage_Fraction*100,1) AS Potential_Protein_Coverage_Percent,'
	Set @sql = @sql + 'Round(QR.ORF_Coverage_Fraction_High_Abundance*100,1) AS Protein_Coverage_Percent_High_Abundance,'

	Set @sql = @sql + 'Round(QR.ORF_Count_Avg,2) As Protein_Count_Avg,'
	
	Set @OrfColumnSql = @sql
	
	Return 0


GO
GRANT EXECUTE ON [dbo].[QRGenerateORFColumnSql] TO [DMS_SP_User]
GO

/****** Object:  StoredProcedure [dbo].[QRGenerateORFColumnSql] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE QRGenerateORFColumnSql
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
**			05/28/2007 mem - Added column MT_Count_Unique_Observed_Both_MS_and_MSMS
**			06/13/2007 mem - Now truncating T_Proteins.Description at 900 characters, since Visual Studio's SqlDataAdapter tool has problems with text strings over 910 characters in length
**			01/24/2008 mem - Added parameters @IncludeProteinDescription and @IncludeQID
**			10/22/2008 mem - Added parameter @ChangeCommasToSemicolons
**			10/14/2010 mem - Added parameters @MatchScoreModeMin and @MatchScoreModeMax, which control the name given to values in column Match_Score_Average
**			01/25/2012 mem - Now returning Abundance_Average_Unscaled
**
****************************************************/
(
	@ERValuesPresent float = 0,
	@OrfColumnSql varchar(2048) = '' OUTPUT,
	@IncludeProteinDescription tinyint = 1,
	@IncludeQID tinyint = 0,
	@ChangeCommasToSemicolons tinyint = 0,		 -- Replaces commas with semicolons in various text fields, including:  Sample_Name, Reference, Protein_Description
	@MatchScoreModeMin tinyint = 0,
	@MatchScoreModeMax tinyint = 0
)
AS

	Declare @sql varchar(2048)
	
	Set @IncludeProteinDescription = IsNull(@IncludeProteinDescription, 1)
	Set @IncludeQID = IsNull(@IncludeQID, 0)
	Set @ChangeCommasToSemicolons = IsNull(@ChangeCommasToSemicolons, 0)
	
	Set @sql = ' SELECT '
	If @ChangeCommasToSemicolons = 0
		Set @sql = @sql + ' QD.SampleName AS Sample_Name,'
	Else
		Set @sql = @sql + ' Replace(QD.SampleName, '','', '';'') AS Sample_Name,'

	If @IncludeQID <> 0
		Set @sql = @sql + 'QD.Quantitation_ID AS QID,'
		
	Set @sql = @sql + 'QR.Ref_ID,'
	
	If @ChangeCommasToSemicolons = 0
		Set @sql = @sql + 'T_Proteins.Reference,'
	Else
		Set @sql = @sql + ' Replace(T_Proteins.Reference, '','', '';'') AS Reference,'
	
	If @IncludeProteinDescription <> 0
	Begin
		If @ChangeCommasToSemicolons = 0
			Set @sql = @sql + 'Left(T_Proteins.Description, 900) AS Protein_Description,'		-- Truncating Protein Description at 900 characters
		Else
			Set @sql = @sql + 'Replace(Left(T_Proteins.Description, 900), '','', '';'') AS Protein_Description,'		-- Truncating Protein Description at 900 characters
	End
	
	Set @sql = @sql + 'Round(QR.Abundance_Average,4) AS Abundance_Average,'
	Set @sql = @sql + 'Round(QR.Abundance_StDev,4) AS Abundance_StDev,'
	Set @sql = @sql + 'CASE WHEN QD.Normalize_To_Standard_Abundances > 0 THEN Round(QR.Abundance_Average / 100.0 * QD.Standard_Abundance_Max + QD.Standard_Abundance_Min, 0) ELSE Round(QR.Abundance_Average,4) END As Abundance_Average_Unscaled,'
	
	Set @sql = @sql + 'Round(QR.Match_Score_Average,3) '
	
	If @MatchScoreModeMin = 0 And @MatchScoreModeMax = 0
		Set @sql = @sql + 'AS SLiC_Score_Avg,'
	Else
	Begin
		If @MatchScoreModeMin >= 1 And @MatchScoreModeMax >= 1
			Set @sql = @sql + 'AS STAC_Score_Avg,'
		Else
			Set @sql = @sql + 'AS SLiC_or_STAC_Score_Avg,'
	End
	
	If @ERValuesPresent > 0
	Begin
		Set @sql = @sql + 'QR.ER_Average,'
		Set @sql = @sql + 'QR.ER_StDev,'
	End
	
	Set @sql = @sql + 'QR.MassTagCountUniqueObserved AS Mass_Tag_Count_Unique_Observed,'
	Set @sql = @sql + 'QR.InternalStdCountUniqueObserved AS Internal_Std_Count_Unique_Observed,'
	Set @sql = @sql + 'QR.MassTagCountUsedForAbundanceAvg AS Peptide_Count_Used_For_Abundance,'
	Set @sql = @sql + 'QR.MT_Count_Unique_Observed_Both_MS_and_MSMS,'
	
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
GRANT EXECUTE ON [dbo].[QRGenerateORFColumnSql] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRGenerateORFColumnSql] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRGenerateORFColumnSql] TO [MTS_DB_Lite] AS [dbo]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GenerateHistogram]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GenerateHistogram]
GO


CREATE PROCEDURE dbo.GenerateHistogram
/****************************************************
**
**	Desc: 
**		Generates a histogram for the GANET data,
**		Discriminant Score data, or XCorr data
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 01/07/2005
**			  07/25/2005 mem - Added option to histogram peptide length data
**							 - Added option to filter the peptides on minimum discriminant score
**							 - Added option to return stats for distinct or non-distinct peptides
**    
*****************************************************/
	@mode tinyint = 0,							-- Mode 0 means GANET, 
												-- Mode 1 means Discriminant Score, 
												-- Mode 2 means XCorr, 
												-- Mode 3 means peptide length
	@ScoreMinimum real = 0,
	@ScoreMaximum real = 1,
	@BinCount int = 10,
	@DiscriminantScoreMinimum real = 0,
	@UseDistinctPeptides tinyint = 0,			-- When 0 then all peptide observations are used, when 1 then only distinct peptide observations are used
	@PreviewSql tinyint = 0						-- When 1, then returns the Sql that is generated, rather than the data
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @Iteration int
	Declare @ScoreMinStart float
	Declare @BinWidth float
	
	Declare @Sql varchar(8000)
	Declare @FromSql varchar(512)
	Declare @BinSql varchar(8000)
	
	Declare @BinField varchar(128)
	
	Set @mode = IsNull(@mode, 0)
	if @mode < 0 or @mode > 3
		Set @mode = 0
		
	if @mode = 0
	Begin
		Set @BinField = 'NET'
		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('
		If @UseDistinctPeptides = 0
		Begin
			Set @FromSql = @FromSql + '  SELECT P.GANET_Obs AS Value'
			Set @Fromsql = @FromSql + '  FROM T_Peptides P INNER JOIN T_Score_Discriminant SD ON'
			Set @FromSql = @FromSql + '  P.Peptide_ID = SD.Peptide_ID'
			Set @FromSql = @FromSql + '  WHERE NOT P.GANET_Obs Is Null'
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
		End
		Else
		Begin
			Set @FromSql = @FromSql + '  SELECT Avg_GANET AS Value FROM T_Mass_Tags_NET MTN INNER JOIN T_Mass_Tags MT ON'
			Set @FromSql = @FromSql + '  MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' WHERE MT.High_Discriminant_Score >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
		End
		
		Set @FromSql = @FromSql + ') LookupQ '
	End
	
	if @mode = 1
	Begin
		Set @BinField = 'Discriminant_Score'
		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('
		If @UseDistinctPeptides = 0
			Set @FromSql = @FromSql + '  SELECT SD.DiscriminantScoreNorm AS Value'
		Else
			Set @FromSql = @FromSql + '  SELECT Max(SD.DiscriminantScoreNorm) AS Value'
		
		Set @Fromsql = @FromSql + '  FROM T_Peptides P INNER JOIN T_Score_Discriminant SD ON'
		Set @FromSql = @FromSql + '  P.Peptide_ID = SD.Peptide_ID'
		If @DiscriminantScoreMinimum > 0
			Set @FromSql = @FromSql + ' WHERE SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
		If @UseDistinctPeptides <> 0
			Set @FromSql = @FromSql + ' GROUP BY P.Mass_Tag_ID'
		Set @FromSql = @FromSql + ') LookupQ '
	End
	
	if @mode = 2
	Begin
		Set @BinField = 'XCorr'
		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('
		If @UseDistinctPeptides = 0
			Set @FromSql = @FromSql + '  SELECT XCorr AS Value'
		Else
			Set @FromSql = @FromSql + '  SELECT Max(XCorr) AS Value'

		Set @FromSql = @FromSql + '  FROM T_Peptides P INNER JOIN T_Score_Sequest SS ON'
		Set @FromSql = @FromSql + '  P.Peptide_ID = SS.Peptide_ID INNER JOIN T_Score_Discriminant SD ON'
		Set @FromSql = @FromSql + '  P.Peptide_ID = SD.Peptide_ID'
		If @DiscriminantScoreMinimum > 0
			Set @FromSql = @FromSql + ' WHERE SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)		
		If @UseDistinctPeptides <> 0
			Set @FromSql = @FromSql + ' GROUP BY P.Mass_Tag_ID'
		Set @FromSql = @FromSql + ') LookupQ '
	End

	if @mode = 3
	Begin
		Set @BinField = 'PeptideLength'
		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('
		If @UseDistinctPeptides = 0
			Set @FromSql = @FromSql + '  SELECT Len(MT.Peptide) AS Value'
		Else
			Set @FromSql = @FromSql + '  SELECT Max(Len(MT.Peptide)) AS Value'
		
		Set @FromSql = @FromSql + '  FROM T_Peptides P INNER JOIN T_Score_Discriminant SD ON'
		Set @FromSql = @FromSql + '  P.Peptide_ID = SD.Peptide_ID INNER JOIN T_Mass_Tags MT ON'
		Set @FromSql = @FromSql + '  P.Mass_Tag_ID = MT.Mass_Tag_ID'
		If @DiscriminantScoreMinimum > 0
			Set @FromSql = @FromSql + '  WHERE SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
		If @UseDistinctPeptides <> 0
			Set @FromSql = @FromSql + ' GROUP BY P.Mass_Tag_ID'
		Set @FromSql = @FromSql + ') LookupQ '
	End
	
	Set @BinField = @BinField + '_Bin'
	
	Set @Iteration = 0
	Set @ScoreMinStart = @ScoreMinimum
	
	If @BinCount < 1
		Set @BinCount = 1
	
	Set @BinWidth = (@ScoreMaximum - @ScoreMinimum) / @BinCount
	
	If log10(@BinWidth) = Round(log10(@BinWidth),0) And @BinWidth <= 1
	Begin
		-- @BinWidth is 1, 0.1, 0.01, 0.001, etc.
		-- We can use the Round function to bin the data
		Set @BinSql = 'Round(Value, ' + Convert(varchar(9), Convert(int, Abs(log10(@BinWidth)))) + ')'
	End
	Else
	Begin
		-- @BinWidth is not a power of 10
		-- Need to use a Case statement to bin the data
		-- If there are over 100 bins, this could easily result in @BinSql being more than 7250 characters
		-- We abort the loop if this happens
		Set @BinSql = ' CASE WHEN Value IS NULL THEN 0'
		While @ScoreMinStart < @ScoreMaximum And @Iteration <= @BinCount And Len(@BinSql) < 7250
		Begin
			Set @BinSql = @BinSql + ' WHEN Value BETWEEN '
			Set @BinSql = @BinSql + Convert(varchar(9), @ScoreMinStart) + ' AND '
			
			Set @BinSql = @BinSql + Convert(varchar(9), @ScoreMinStart + @BinWidth) + ' THEN ' + Convert(varchar(9), @ScoreMinStart)
			
			Set @Iteration = @Iteration + 1
			Set @ScoreMinStart = @ScoreMinimum + @Iteration * @BinWidth
		End
		
		Set @BinSql = @BinSql + ' ELSE 0 END'
	End	
	
	Set @sql = ''
	Set @Sql = @Sql + ' SELECT Value AS ' + @BinField + ', COUNT(*) AS Match_Count'
	Set @Sql = @Sql + ' FROM (SELECT ' + @BinSql + ' AS Value '
	Set @Sql = @Sql +         @FromSql
	Set @Sql = @Sql +       ' WHERE Value BETWEEN '
	Set @Sql = @Sql +       Convert(varchar(9), @ScoreMinimum) + ' AND ' + Convert(varchar(9), @ScoreMaximum)
	Set @Sql = @Sql +       ') AS StatsQ'
	Set @Sql = @Sql + ' GROUP BY Value'
	Set @Sql = @Sql + ' ORDER BY Value'

	If IsNull(@PreviewSql,0) = 0
		Exec (@Sql)
	Else
	Begin
		Print @Sql
		Select @Sql as TheSql
	End
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GenerateHistogram]  TO [DMS_SP_User]
GO


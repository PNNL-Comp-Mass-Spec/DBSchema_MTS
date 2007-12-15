/****** Object:  StoredProcedure [dbo].[UpdatePMTQSUsingDelMPPM] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdatePMTQSUsingDelMPPM
/****************************************************
** 
**	Desc:	Computes a "corrected" DelM value for all peptides identified by
**			Sequest or XTandem.  "Corrected" means the following:
**				DelM values around -3 are corrected using DelM + 3
**				DelM values around -2 are corrected using DelM + 2
**				DelM values around -1 are corrected using DelM + 1
**				DelM values around 1 are corrected using DelM - 1
**				DelM values around 2 are corrected using DelM - 2
**				DelM values around 3 are corrected using DelM - 3
**
**			This type of correction is appropriate for data collected on the 
**			 LTQ-FT or LTQ-Orbitrap.  After computing the corrected DelM value,
**			 it is converted to PPM.  The PMTs with a corrected DelM value
**			 between -10 and 10 ppm are then found, and their PMT QS values are
**			 increased by @PMTQSAddon
**
**			If @ResetPMTQSForMTsOutOfTolerance = 1, then also changes the 
**			PMT QS value to 0 for peptides that are not within @PPMTolerance
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	02/08/2007
**			02/23/2007 mem - Added parameter @PMTQSFilter
**			04/17/2007 mem - Changed default tolerance to 10 ppm and changed window for correcting DelM values of -3, -2, -1, 1, 2, or 3 to a +/- 0.1 Da window
**			10/22/2007 mem - Added parameter @PPMToleranceNeg and renamed @PPMTolerance to @PPMTolerancePos
**    
*****************************************************/
(
	@PPMToleranceNeg real = -10,
	@PPMTolerancePos real = 10,
	@PMTQSAddon real = 0,
	@ResetPMTQSForMTsOutOfTolerance tinyint = 1,		-- When 1, then sets the PMT QS to 0 for peptides that are not between @PPMToleranceNeg and @PPMTolerancePos
	@PMTQSFilter int = 0,								-- Set to 1, 2, or 3 to only examine PMTs that currently have the given PMT quality score value
	@InfoOnly tinyint = 0,
	@PreviewSql tinyint = 0,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @S varchar(2048)
	
	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	
	Set @PPMToleranceNeg = IsNull(@PPMToleranceNeg, -10)
	Set @PPMTolerancePos = IsNull(@PPMTolerancePos, 10)
	Set @PMTQSAddon = IsNull(@PMTQSAddon, 0)
	Set @ResetPMTQSForMTsOutOfTolerance = IsNull(@ResetPMTQSForMTsOutOfTolerance, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @message = ''

	If @PMTQSAddon = 0 AND @ResetPMTQSForMTsOutOfTolerance = 0
	Begin
		set @message = 'Warning, both @PMTQSAddon and @ResetPMTQSForMTsOutOfTolerance are 0, so no PMT Quality Score values will be updated'
		SELECT @message
		
		execute PostLogEntry 'Error', @message, 'UpdatePMTQSUsingDelMPPM'
		set @message = ''
	End
	
	If @PPMToleranceNeg >= @PPMTolerancePos
	Begin
		set @message = 'Warning, @PPMToleranceNeg is greater than @PPMTolerancePos, meaning no data will be matched'
		SELECT @message
		
		execute PostLogEntry 'Error', @message, 'UpdatePMTQSUsingDelMPPM'
		set @message = ''
	End
	
	--------------------------------------------------------------
	-- Create a temporary table to hold the Mass_Tag_IDs that pass the filter
	--------------------------------------------------------------

	CREATE TABLE #TmpMTsToUpdate (
		Mass_Tag_ID int
	)

	
	Set @S = ''
	Set @S = @S + ' INSERT INTO #TmpMTsToUpdate (Mass_Tag_ID)'
	Set @S = @S + ' SELECT Mass_Tag_ID'
	Set @S = @S + ' FROM T_Peptides INNER JOIN'
	Set @S = @S +    ' ( SELECT Peptide_ID, DelM_PPM'
	Set @S = @S +      ' FROM (SELECT Peptide_ID, CorrectedDelM / (Monoisotopic_Mass / 1e6) AS DelM_PPM'
	Set @S = @S +            ' FROM (SELECT	Pep.Peptide_ID, MT.Monoisotopic_Mass,'
	Set @S = @S +                         ' CASE WHEN SS.DelM BETWEEN -3.1 AND -2.9 THEN DelM + 3 '
	Set @S = @S +          ' WHEN SS.DelM BETWEEN -2.1 AND -1.9 THEN DelM + 2 '
	Set @S = @S +                         ' WHEN SS.DelM BETWEEN -1.1 AND -0.9 THEN DelM + 1' 
	Set @S = @S +                         ' WHEN SS.DelM BETWEEN 0.9 AND 1.1 THEN DelM - 1 '
	Set @S = @S +                         ' WHEN SS.DelM BETWEEN 1.9 AND 2.1 THEN DelM - 2 '
	Set @S = @S +                         ' WHEN SS.DelM BETWEEN 2.9 AND 3.1 THEN DelM - 3 '
	Set @S = @S +              ' ELSE SS.DelM END AS CorrectedDelM'
	Set @S = @S +                 ' FROM T_Peptides Pep INNER JOIN'
	Set @S = @S +                       ' T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID INNER JOIN'
	Set @S = @S +                       ' T_Mass_Tags MT ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID'
	If @PMTQSFilter <> 0
		Set @S = @S +              ' WHERE MT.PMT_Quality_Score = ' + Convert(varchar(12), @PMTQSFilter)
	
	Set @S = @S +                 ' ) LookupQ'
	Set @S = @S +            ' ) OuterQ'
	Set @S = @S +      ' WHERE DelM_PPM BETWEEN ' + Convert(varchar(12), @PPMToleranceNeg) + ' AND ' + Convert(varchar(12), @PPMTolerancePos)
	Set @S = @S +    ' ) LookupQ ON T_Peptides.Peptide_ID = LookupQ.Peptide_ID'
	Set @S = @S +    ' GROUP BY Mass_Tag_ID'
	
	If @PreviewSql <> 0
		Print @S
	Else
		Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	Set @message = 'PMTs within ' + Convert(varchar(12), @PPMToleranceNeg) + ' and ' + Convert(varchar(12), @PPMTolerancePos) + ' ppm of the parent mass: ' + Convert(varchar(12), @myRowCount)
	
	If @PMTQSFilter <> 0
		Set @message = @message + ' ; limiting to PMTs that have PMT QS = ' + Convert(varchar(12), @PMTQSFilter)
		
	If @InfoOnly <> 0 And @PreviewSql = 0
		SELECT @message
	Else
	Begin
		If @PMTQSAddon <> 0
		Begin
			Set @S = ''
			Set @S = @S + ' UPDATE T_Mass_Tags'
			Set @S = @S + ' SET PMT_Quality_Score = PMT_Quality_Score ' +  Convert(varchar(12), @PMTQSAddon)
			Set @S = @S + ' FROM T_Mass_Tags INNER JOIN '
			Set @S = @S +      ' #TmpMTsToUpdate ON T_Mass_Tags.Mass_Tag_ID = #TmpMTsToUpdate.Mass_Tag_ID'
			If @PMTQSFilter <> 0
				Set @S = @S + ' WHERE PMT_Quality_Score = ' + Convert(varchar(12), @PMTQSFilter)
				
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		
			Set @message = @message + '; increased their PMT QS values by ' + convert(varchar(12), @PMTQSAddon)
		End
		
		If @ResetPMTQSForMTsOutOfTolerance <> 0
		Begin
			Set @S = ''
			Set @S = @S + ' UPDATE T_Mass_Tags'
			Set @S = @S + ' SET PMT_Quality_Score = 0'
			Set @S = @S + ' FROM T_Mass_Tags LEFT OUTER JOIN #TmpMTsToUpdate ON '
			Set @S = @S +      ' T_Mass_Tags.Mass_Tag_ID = #TmpMTsToUpdate.Mass_Tag_ID'
			Set @S = @S + ' WHERE #TmpMTsToUpdate.Mass_Tag_ID IS NULL'
			If @PMTQSFilter <> 0
				Set @S = @S + ' AND T_Mass_Tags.PMT_Quality_Score = ' + Convert(varchar(12), @PMTQSFilter)
				
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			Set @message = @message + '; set PMT QS to 0 for PMTs outside the ppm tolerance (' + convert(varchar(12), @myRowCount) + ' PMTs updated)'
		End
		
		If @PreviewSql = 0
			execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingDelMPPM'
		Else
			set @message = 'Sql Statement preview'
	End
	
Done:
	return @myError


GO

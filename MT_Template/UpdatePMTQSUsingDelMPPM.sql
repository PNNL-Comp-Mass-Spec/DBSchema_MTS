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
**			02/10/2009 mem - Added support for XTandem and Inspect data
**						   - Slightly relaxed the window for correcting DelM values to a +/- 0.15 Da window
**			09/24/2012 mem - Updated to use T_Peptides.DelM_PPM instead of querying the T_Score% tables
**						   - Fixed bug when incrementing PMT_Quality_Score via @PMTQSAddon
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

	-- Obtain a filtered set of AMT tags
	-- Note that DelM_PPM in T_Peptides should already have mass-corrected values to assure that the DelM values are between -0.5 and 0.5
	-- However, just to be safe, we convert from DelM_PPM to DelM, then apply a mass adjustor, then convert back
	Set @S = ''
	Set @S = @S + ' INSERT INTO #TmpMTsToUpdate (Mass_Tag_ID)'
	Set @S = @S + ' SELECT Mass_Tag_ID'
	Set @S = @S + ' FROM (SELECT Mass_Tag_ID, CorrectedDelM / (Monoisotopic_Mass / 1e6) AS DelM_PPM, DelM_PPM_Original'
	Set @S = @S +       ' FROM ( SELECT Mass_Tag_ID, Monoisotopic_Mass,'
	Set @S = @S +                     ' CASE'
	Set @S = @S +                        ' WHEN DelM BETWEEN -3.15 AND -2.85 THEN DelM + 3'
	Set @S = @S +                        ' WHEN DelM BETWEEN -2.15 AND -1.85 THEN DelM + 2'
	Set @S = @S +                        ' WHEN DelM BETWEEN -1.15 AND -0.85 THEN DelM + 1'
	Set @S = @S +                        ' WHEN DelM BETWEEN 0.85 AND 1.15 THEN DelM - 1'
	Set @S = @S +                        ' WHEN DelM BETWEEN 1.85 AND 2.15 THEN DelM - 2'
	Set @S = @S +                        ' WHEN DelM BETWEEN 2.85 AND 3.15 THEN DelM - 3'
	Set @S = @S +                        ' ELSE DelM'
	Set @S = @S +                     ' END AS CorrectedDelM, '
	Set @S = @S +                     ' DelM_PPM_Original'
	Set @S = @S +                   ' FROM ('
	Set @S = @S +                        ' SELECT MT.Mass_Tag_ID, MT.Monoisotopic_Mass, '
	Set @S = @S +                               ' Pep.DelM_PPM * (MT.Monoisotopic_Mass / 1e6) AS DelM, '
	Set @S = @S +                               ' Pep.DelM_PPM AS DelM_PPM_Original '	
	Set @S = @S +                        ' FROM T_Peptides Pep'
	Set @S = @S +                              ' INNER JOIN T_Mass_Tags MT'
	Set @S = @S +                                ' ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID '
	If @PMTQSFilter <> 0
		Set @S = @S +                    ' WHERE Abs(MT.PMT_Quality_Score - ' + Convert(varchar(12), @PMTQSFilter) + ') < 0.025'
	Set @S = @S +                     ' ) LookupQ '
	Set @S = @S +            ' ) MassCorrectedQ '
	Set @S = @S +       ' ) OuterQ'
	Set @S = @S + ' WHERE DelM_PPM BETWEEN ' + Convert(varchar(12), @PPMToleranceNeg) + ' AND ' + Convert(varchar(12), @PPMTolerancePos)
	Set @S = @S + ' GROUP BY Mass_Tag_ID'
	
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
			Set @S = @S + ' SET PMT_Quality_Score = PMT_Quality_Score + ' +  Convert(varchar(12), @PMTQSAddon)
			Set @S = @S + ' FROM T_Mass_Tags INNER JOIN '
			Set @S = @S +      ' #TmpMTsToUpdate ON T_Mass_Tags.Mass_Tag_ID = #TmpMTsToUpdate.Mass_Tag_ID'
			If @PMTQSFilter <> 0
				Set @S = @S + ' WHERE Abs(PMT_Quality_Score - ' + Convert(varchar(12), @PMTQSFilter) + ') < 0.025'
				
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
GRANT VIEW DEFINITION ON [dbo].[UpdatePMTQSUsingDelMPPM] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdatePMTQSUsingDelMPPM] TO [MTS_DB_Lite] AS [dbo]
GO

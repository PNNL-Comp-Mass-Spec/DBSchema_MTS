
ALTER Procedure dbo.UpdatePMTQSUsingCustomVladXTFilterAndMotif
/****************************************************
**
**	Desc: 
**		Updates the PMT QS to be the negative of Log_Evalue
**		for peptides that pass the EValue threshold and match the given motif
**
**		If @ResetPMTQSForMTsOutOfTolerance is non-zero, then will reset 
**		the PMT QS to zero for peptides that don't pass the filter
**
**		If @PPMToleranceNeg and @PPMTolerancePos are defined, then will also
**		filter the peptides based on the delta mass between the observed parent mass
**		and the theoretical parent mass
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	02/08/2010
**    
*****************************************************/
(
	@RequiredMotif varchar(12) = '%N#_[ST]%',			-- If defined, then will require that peptides contain this motif (tested with a Like clause against peptide sequence in T_Peptides); for example: '%N#_[ST]%'
	@PPMToleranceNeg real = -10,
	@PPMTolerancePos real = 10,
	@ResetPMTQSForMTsOutOfTolerance tinyint = 1,		-- When 1, then sets the PMT QS to 0 for peptides that don't match the filters
	@InfoOnly tinyint = 0,
	@message varchar(255)='' OUTPUT
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @FilterDescription varchar(64)
	
	---------------------------------------------------
	-- Create a temporary table to track AMT tags that pass the filters
	---------------------------------------------------
	CREATE TABLE #Tmp_FilterPassingAMTs (
		Mass_Tag_ID int not null,
		New_PMT_QS real not null
	)
	
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_FilterPassingAMTs ON #Tmp_FilterPassingAMTs (Mass_Tag_ID)
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	
	Set @RequiredMotif = IsNull(@RequiredMotif, '')
	Set @PPMToleranceNeg = IsNull(@PPMToleranceNeg, 0)
	Set @PPMTolerancePos = IsNull(@PPMTolerancePos, 0)
	Set @ResetPMTQSForMTsOutOfTolerance = IsNull(@ResetPMTQSForMTsOutOfTolerance, 1)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @message= ''

	Set @FilterDescription = 'Peptide Like "' + @RequiredMotif + '"'
		
	---------------------------------------------------
	-- Populate a temporary table with the peptides that pass the required filters
	---------------------------------------------------
	
	INSERT INTO #Tmp_FilterPassingAMTs (Mass_Tag_ID, New_PMT_QS)
	SELECT Pep.Mass_Tag_ID, MAX(-XT.Log_EValue) AS New_PMT_QS
	FROM T_Peptides Pep
	     INNER JOIN T_Score_XTandem XT
	       ON Pep.Peptide_ID = XT.Peptide_ID
	     INNER JOIN T_Mass_Tags MT
	       ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
	WHERE Pep.Peptide LIKE @RequiredMotif AND
	      NOT XT.Log_EValue Is Null
	GROUP BY Pep.Mass_Tag_ID
	--	      
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	
	If @ResetPMTQSForMTsOutOfTolerance <> 0
	Begin
		If @InfoOnly <> 0
		Begin
			SELECT @myRowCount = COUNT(*)
			FROM T_Mass_Tags
			WHERE PMT_Quality_Score <> 0 AND
				NOT Mass_Tag_ID IN ( SELECT Mass_Tag_ID
									FROM #Tmp_FilterPassingAMTs )
		End						
		Else
		Begin
			UPDATE T_Mass_Tags
			SET PMT_Quality_Score = 0
			WHERE PMT_Quality_Score <> 0 AND
				NOT Mass_Tag_ID IN ( SELECT Mass_Tag_ID
									FROM #Tmp_FilterPassingAMTs )
			--	      
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End
		
		Set @message = 'Set PMT QS to 0 for ' + Convert(varchar(12), @myRowCount) + ' AMT tags that did not pass the filters (' + @FilterDescription + ')'
		
		If @InfoOnly <> 0
			Print @message
		Else
			Exec PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingCustomVladXTFilterAndMotif'
	End
	
	If @InfoOnly <> 0
	Begin
		SELECT @myRowCount = COUNT(*)
		FROM T_Mass_Tags
		WHERE Mass_Tag_ID IN ( SELECT Mass_Tag_ID
		                       FROM #Tmp_FilterPassingAMTs )
	End						
	Else
	Begin
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = Source.New_PMT_QS
		FROM T_Mass_Tags Target
		     INNER JOIN #Tmp_FilterPassingAMTs Source
		       ON Target.Mass_Tag_ID = Source.Mass_Tag_ID
		--	      
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	
	Set @message = 'Set PMT QS to MAX(-Log_EValue) for ' + Convert(varchar(12), @myRowCount) + ' AMT tags that pass the filters (' + @FilterDescription + ')'
	
	If @InfoOnly <> 0
		Print @message
	Else
		Exec PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingCustomVladXTFilterAndMotif'
	
	
	If @PPMToleranceNeg <> 0 And @PPMTolerancePos <> 0
	Begin
		-- Now call UpdatePMTQSUsingDelMPPM to filter based on delta mass
		exec UpdatePMTQSUsingDelMPPM 
					@PPMToleranceNeg=@PPMToleranceNeg, 
					@PPMTolerancePos=@PPMTolerancePos, 
					@PMTQSAddon=0, 
					@ResetPMTQSForMTsOutOfTolerance=1,
					@InfoOnly=@InfoOnly
	End
				
	
Done:
	Return @myError


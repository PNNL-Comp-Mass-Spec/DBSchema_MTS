
ALTER Procedure dbo.UpdatePMTQSUsingMotifFilter
/****************************************************
**
**	Desc: 
**		Updates the PMT QS for AMT tags containing the specified motif
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
**	Date:	02/17/2010
**    
*****************************************************/
(
	@RequiredMotif varchar(12),						-- Find peptides that contain this motif (tested with a Like clause against peptide sequence in T_Peptides); for example: '%K#%'
	@PMTQSAddon real = 0,
	@ResetPMTQSForMTsOutOfTolerance tinyint = 1,	-- When 1, then sets the PMT QS to 0 for peptides that don't match the filters
	@PMTQSFilter int = 0,							-- Set to 1, 2, or 3 to only examine PMTs that currently have the given PMT quality score value
	@InfoOnly tinyint = 0,
	@message varchar(255)='' OUTPUT
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	--------------------------------------------------------------
	-- Create a temporary table to hold the Mass_Tag_IDs that pass the filter
	--------------------------------------------------------------

	CREATE TABLE #Tmp_FilterPassingAMTs (
		Mass_Tag_ID int
	)
	
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_FilterPassingAMTs ON #Tmp_FilterPassingAMTs (Mass_Tag_ID)
	
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	Set @RequiredMotif = IsNull(@RequiredMotif, '')
	Set @PMTQSAddon = IsNull(@PMTQSAddon, 0)
	Set @ResetPMTQSForMTsOutOfTolerance = IsNull(@ResetPMTQSForMTsOutOfTolerance, 1)
	Set @PMTQSFilter = IsNull(@PMTQSFilter, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @message= ''

		
	---------------------------------------------------
	-- Populate a temporary table with the peptides that pass the required filters
	---------------------------------------------------
	
	INSERT INTO #Tmp_FilterPassingAMTs( Mass_Tag_ID )
	SELECT Pep.Mass_Tag_ID
	FROM T_Peptides Pep
	     INNER JOIN T_Mass_Tags MT
	       ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
	WHERE Pep.Peptide LIKE @RequiredMotif AND
	      (@PMTQSFilter = 0 OR MT.PMT_Quality_Score = @PMTQSFilter)
	GROUP BY Pep.Mass_Tag_ID
	--	      
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	
	Set @message = 'PMTs that match motif "' + @RequiredMotif + '": ' + Convert(varchar(12), @myRowCount)
	
	If @PMTQSFilter <> 0
		Set @message = @message + ' ; limiting to PMTs that have PMT QS = ' + Convert(varchar(12), @PMTQSFilter)
		
	If @InfoOnly <> 0
		SELECT @message AS Message
	Else
	Begin
		If @PMTQSAddon <> 0
		Begin
			UPDATE T_Mass_Tags
			SET PMT_Quality_Score = MT.PMT_Quality_Score + @PMTQSAddon
			FROM T_Mass_Tags MT
			     INNER JOIN #Tmp_FilterPassingAMTs F
			       ON MT.Mass_Tag_ID = F.Mass_Tag_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		
			Set @message = @message + '; increased their PMT QS values by ' + convert(varchar(12), @PMTQSAddon)
		End
		
		If @ResetPMTQSForMTsOutOfTolerance <> 0
		Begin
			UPDATE T_Mass_Tags
			SET PMT_Quality_Score = 0
			FROM T_Mass_Tags MT
			     LEFT OUTER JOIN #Tmp_FilterPassingAMTs F
			       ON MT.Mass_Tag_ID = F.Mass_Tag_ID
			WHERE MT.PMT_Quality_Score <> 0 AND F.Mass_Tag_ID IS NULL
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			Set @message = @message + '; set PMT QS to 0 for PMTs that do not match the filters (' + convert(varchar(12), @myRowCount) + ' PMTs updated)'
		End

		Set @myRowCount = 0
		
		SELECT @myRowCount = COUNT(*)
		FROM T_Mass_Tags
		WHERE PMT_Quality_Score > 0
		
		Set @message = @message + '; PMT count with non-zero PMT Quality Score: ' + Convert(varchar(12), @myRowCount)
		
		execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingMotifFilter'
		
	End
	
Done:
	Return @myError

GO
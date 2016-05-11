
ALTER PROCEDURE Add11DaShiftedPeptides
/****************************************************
**
**	Desc:	Adds 11 Da shifted peptides using AMT tags with PMT_QS >= @MinimumPMTQS
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	04/17/2015 mem - Initial version
**			04/21/2015 mem - Now storing 1 for Number_Of_Peptides and 0 for Peptide_Obs_Count_Passing_Filter
**    
*****************************************************/
(
	@message varchar(512) = '',
	@MinimumPMTQS int = 2
)
AS
	set nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------
	
	Set @message = ''
	Set @MinimumPMTQS = IsNull(@MinimumPMTQS, @MinimumPMTQS)
	
	If @MinimumPMTQS < 1
		Set @MinimumPMTQS = 1
		
	If Exists (Select * FROM T_Mass_Tags Where Mass_Tag_ID < 0)
	Begin
		
		-----------------------------------------------------
		-- Abort since peptides already exist
		-----------------------------------------------------
	
		Set @message = '11 Da shifted peptides already exist; nothing to do'

		print @message
		print ''
		print 'Could remove the peptides using this:'
		print 'DELETE from T_Mass_Tag_to_Protein_Map WHERE mass_tag_id < 0'
		print 'DELETE from T_Mass_Tags_NET WHERE mass_tag_id < 0'
		print 'DELETE from T_Mass_Tags WHERE mass_tag_id < 0'
	End
	Else
	Begin
		Declare @AddShiftedPeptides varchar(15) = 'MyTran'

		Begin Tran @AddShiftedPeptides

		-----------------------------------------------------
		-- Add to T_Mass_Tags
		-----------------------------------------------------
		--
		INSERT INTO T_Mass_Tags( Mass_Tag_ID,
		                         Peptide,
		                         Monoisotopic_Mass,
		                         Is_Confirmed,
		                         Confidence_Factor,
		                         Multiple_Proteins,
		                         Created,
		                         Last_Affected,
		                         Number_Of_Peptides,
		                         Peptide_Obs_Count_Passing_Filter,
		                         High_Normalized_Score,
		                         High_Discriminant_Score,
		                         High_Peptide_Prophet_Probability,
		                         Number_Of_FTICR,
		                         Mod_Count,
		                         Mod_Description,
		                         PMT_Quality_Score,
		                         Internal_Standard_Only,
		                         Min_Log_EValue,
		                         Cleavage_State_Max,
		                         PeptideEx,
		                         Min_MSGF_SpecProb )
		SELECT -Mass_Tag_ID AS Mass_Tag_ID,
		       Peptide + '+11Da' AS Peptide,
		       Monoisotopic_Mass + 11 AS Monoisotopic_Mass,
		       0 AS Is_Confirmed,
		       Confidence_Factor,
		       0 AS Multiple_Proteins,
		       GETDATE() AS Created,
		       GETDATE() AS Last_Affected,
		       1 As Number_Of_Peptides,
		       0 As Peptide_Obs_Count_Passing_Filter,
		       High_Normalized_Score,
		       High_Discriminant_Score,
		       High_Peptide_Prophet_Probability,
		       Number_Of_FTICR,
		       Mod_Count + 1 AS Mod_Count,
		       CASE
		           WHEN mod_count = 0 THEN '11DaShift:1'
		           ELSE '11DaShift:1,' + Mod_Description
		       END AS Mod_Description,
		       PMT_Quality_Score,
		       Internal_Standard_Only,
		       Min_Log_EValue,
		       Cleavage_State_Max,
		       PeptideEx,
		       Min_MSGF_SpecProb
		FROM T_Mass_Tags
		WHERE (PMT_Quality_Score >= 2)

		-----------------------------------------------------
		-- Add to T_Mass_Tags_NET
		-----------------------------------------------------
		--
		INSERT INTO T_Mass_Tags_NET( Mass_Tag_ID,
		                             Min_GANET,
		                             Max_GANET,
		                             Avg_GANET,
		                             Cnt_GANET,
		                StD_GANET,
		                             StdError_GANET,
		                             PNET,
		                             PNET_Variance )
		SELECT -MTN.Mass_Tag_ID AS Mass_Tag_ID,
		       MTN.Min_GANET,
		       MTN.Max_GANET,
		       MTN.Avg_GANET,
		       MTN.Cnt_GANET,
		       MTN.StD_GANET,
		       MTN.StdError_GANET,
		       MTN.PNET,
		       MTN.PNET_Variance
		FROM T_Mass_Tags MT
		     INNER JOIN T_Mass_Tags_NET AS MTN
		       ON MT.Mass_Tag_ID = - MTN.Mass_Tag_ID
		WHERE (MT.Mass_Tag_ID < 0)

		
		-----------------------------------------------------
		-- Add to T_Mass_Tag_to_Protein_Map
		-----------------------------------------------------
		--		
		INSERT INTO T_Mass_Tag_to_Protein_Map( Mass_Tag_ID,
		                                       Mass_Tag_Name,
		                                       Ref_ID,
		                                       Cleavage_State )
		SELECT -MTPM.Mass_Tag_ID AS Mass_Tag_ID,
		       MTPM.Mass_Tag_Name,
		       MTPM.Ref_ID,
		       MTPM.Cleavage_State
		FROM T_Mass_Tags MT
		     INNER JOIN T_Mass_Tag_to_Protein_Map MTPM
		       ON MT.Mass_Tag_ID = - MTPM.Mass_Tag_ID
		WHERE (MT.Mass_Tag_ID < 0)


		COMMIT

		-----------------------------------------------------
		-- Post a log message
		-----------------------------------------------------
		
		Set @message = 'Added 11 Da shifted peptides using existing AMT tags with PMT QS >= ' + Cast(@MinimumPMTQS AS varchar(12))
		
		exec PostLogEntry	@type = 'Normal',
							@message = @message,
							@postedBy = 'Add11DaShiftedPeptides'

	End

	SELECT @message AS Message

Done:

	Return @myError

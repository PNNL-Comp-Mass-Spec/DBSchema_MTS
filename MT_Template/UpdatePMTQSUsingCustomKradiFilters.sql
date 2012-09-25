
ALTER Procedure UpdatePMTQSUsingCustomKradiFilters
/****************************************************	
**	Updates the PMT Quality Score to 3 for the peptides in table T_User_KRadi_1percentFDR
**
**	Auth:	mem
**	Date:	03/31/2009
**			01/06/2012 mem - Updated to use T_Peptides.Job
**
****************************************************/
(
	@infoOnly tinyint = 0,
	@NewPMTQS real = 3,
	@message varchar(256)='' output
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @NewPMTQS = IsNull(@NewPMTQS, 3)
	Set @message = ''
	
	If @infoOnly <> 0
	Begin
		SELECT MT.PMT_Quality_Score as PMT_QS_Current,
			COUNT(DISTINCT P.Mass_Tag_ID) AS MT_Count
		FROM T_User_KRadi_1percentFDR UsrData
			INNER JOIN T_Peptides P
			ON UsrData.Job = P.Job AND
				UsrData.ScanNum = P.Scan_Number AND
				UsrData.ScanCount = P.Number_Of_Scans AND
				UsrData.ChargeState = P.Charge_State AND
				UsrData.Peptide = P.Peptide
			INNER JOIN T_Mass_Tags MT
			ON P.Mass_Tag_ID = MT.Mass_Tag_ID
		GROUP BY MT.PMT_Quality_Score
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
	End
	Else
	Begin
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = @NewPMTQS
		FROM T_Mass_Tags MT
		     INNER JOIN ( SELECT DISTINCT P.Mass_Tag_ID
		                  FROM T_User_KRadi_1percentFDR UsrData
		                       INNER JOIN T_Peptides P
		                         ON UsrData.Job = P.Job AND
		                            UsrData.ScanNum = P.Scan_Number AND
		                            UsrData.ScanCount = P.Number_Of_Scans AND
		                            UsrData.ChargeState = P.Charge_State AND
		                            UsrData.Peptide = P.Peptide 
		                ) Src
		       ON MT.Mass_Tag_ID = Src.Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount

		Set @message = 'Updated PMT QS to ' + Convert(varchar(12), @NewPMTQS) + ' for ' + Convert(varchar(12), @myRowCount) + ' PMTs that are defined in T_User_KRadi_1percentFDR'
		EXEC PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingOnePercentFDRPeptides'

		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = @NewPMTQS
		FROM T_Mass_Tags
		WHERE (Mass_Tag_ID IN ( SELECT DISTINCT T_Mass_Tag_to_Protein_Map.Mass_Tag_ID
		                        FROM T_Mass_Tag_to_Protein_Map
		                             INNER JOIN T_Proteins
		                               ON T_Mass_Tag_to_Protein_Map.Ref_ID = T_Proteins.Ref_ID
		                        WHERE T_Proteins.Protein_Collection_ID IN (1065, 1280) 
		                      )
		     )
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount

		Set @message = 'Updated PMT QS to ' + Convert(varchar(12), @NewPMTQS) + ' for ' + Convert(varchar(12), @myRowCount) + ' Mini Proteome and Yeast ADH PMTs'
		EXEC PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingOnePercentFDRPeptides'

	End
		
Done:	

	Return @myError

GO
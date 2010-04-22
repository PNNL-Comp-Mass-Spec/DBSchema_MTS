
ALTER PROCEDURE dbo.UpdatePMTQSLopezFerrerAMTList
/****************************************************
** 
**	Desc:	Updates PMT QS to 3 for AMT tags in tables T_User_Lopez_Peptides and T_User_Lopez_Peptides2
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	03/30/2010
**    
*****************************************************/
(
	@InfoOnly tinyint = 0,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @message = ''

	If @InfoOnly <> 0
		SELECT COUNT(*) AS PMT_Count
		FROM T_Mass_Tags
		WHERE (Mass_Tag_ID IN
		        (SELECT DISTINCT T_Peptides.Mass_Tag_ID
		      FROM (SELECT Job, Scan, Charge, Peptide
		            FROM T_User_Lopez_Peptides
		            UNION
		            SELECT Job, Scan, Charge, Peptide
		            FROM T_User_Lopez_Peptides2) 
		           ConfidentPeptides INNER JOIN
		           T_Peptides ON 
		           ConfidentPeptides.Job = T_Peptides.Analysis_ID AND 
		           ConfidentPeptides.Scan = T_Peptides.Scan_Number AND
		            ConfidentPeptides.Peptide = T_Peptides.Peptide))
	Else
	Begin
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = 3
		WHERE (Mass_Tag_ID IN
		        (SELECT DISTINCT T_Peptides.Mass_Tag_ID
		      FROM (SELECT Job, Scan, Charge, Peptide
		            FROM T_User_Lopez_Peptides
		            UNION
		            SELECT Job, Scan, Charge, Peptide
		            FROM T_User_Lopez_Peptides2) 
		           ConfidentPeptides INNER JOIN
		           T_Peptides ON 
		           ConfidentPeptides.Job = T_Peptides.Analysis_ID AND 
		           ConfidentPeptides.Scan = T_Peptides.Scan_Number AND
		            ConfidentPeptides.Peptide = T_Peptides.Peptide))
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @message = 'Set PMT_Quality_Score to 3 for ' + Convert(varchar(12), @myRowCount) + ' AMT tags in T_Mass_Tags using T_User_Lopez_Peptides and T_User_Lopez_Peptides2'
		Print @message

		exec PostLogEntry 'Normal', @message, 'UpdatePMTQSLopezFerrerAMTList'
	End
	
Done:
	return @myError


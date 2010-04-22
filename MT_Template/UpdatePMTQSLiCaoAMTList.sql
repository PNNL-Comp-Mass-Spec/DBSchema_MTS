
ALTER PROCEDURE dbo.UpdatePMTQSLiCaoAMTList
/****************************************************
** 
**	Desc:	Updates PMT QS to 3 for AMT tags in table T_User_PMTQS3_LiCao
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
		FROM T_Mass_Tags INNER JOIN
			T_User_PMTQS3_LiCao ON 
			T_Mass_Tags.Mass_Tag_ID = T_User_PMTQS3_LiCao.Mass_Tag_ID		
	Else
	Begin
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = 3
		FROM T_Mass_Tags
			INNER JOIN T_User_PMTQS3_LiCao
			ON T_Mass_Tags.Mass_Tag_ID = T_User_PMTQS3_LiCao.Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @message = 'Set PMT_Quality_Score to 3 for ' + Convert(varchar(12), @myRowCount) + ' AMT tags in T_Mass_Tags using T_User_PMTQS3_LiCao'
		Print @message

		exec PostLogEntry 'Normal', @message, 'UpdatePMTQSLiCaoAMTList'
	End
	
Done:
	return @myError


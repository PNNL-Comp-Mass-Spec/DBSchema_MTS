SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QuantitationProcessCheckMinimumCriteria]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QuantitationProcessCheckMinimumCriteria]
GO



CREATE Procedure dbo.QuantitationProcessCheckMinimumCriteria 
/****************************************************	
**
**  Desc:	Update field MeetsMinimumCriteria in T_Quantitation_Results 
**			by comparing the values in T_Quantitation_Results with the 
**			Minimum Criteria specified in T_Quantitation_Description
**          If @QuantitationID is Null, then updates all rows
**          If @QuantitationID is specified, then updates only the rows for that ID
**
**  Return values: 0 if success, otherwise, error code
**
**  Parameters: @QuantitationID  (optional)
**
**  Auth: mem
**	Date: 06/03/2003
**
**	Updated 08/26/2003 mem
			09/26/2004 mem - Updated for DB Schema Version 2
**
****************************************************/
(
	@QuantitationID int=Null			-- QuantitationID to process (Optional; if Null, processes all rows)
)
AS
	Set NoCount On
	
	Declare	@myError int,
			@myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @message varchar(255)
	Set @message = ''

	Declare @S varchar(2048)

	-- Update the MeetsMinimumCriteria column in T_Quantitation_Results
	-- The data for a given Protein will meet the minimum criteria if:
	--	1) The fraction of scans matching a single mass tag >= Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum
	--     and if
	--  either 2) or 3):
	--		2) The observed mass tag count is greater than or equal to the Protein_Mass
	--         divided by Minimum_Criteria_ORFMassDaDivisor (rounded down using Floor()),
	--         however, this value cannot be less than Minimum_Criteria_UniqueMTCountMinimum
	--		     or if
	--		3) The matching mass tag ion count is greater than or equal to
	--         Minimum_Criteria_MTIonMatchCountMinimum
	--
	Set @S = ''
	Set @S = @S + ' UPDATE	T_Quantitation_Results'
	Set @S = @S + ' SET		Meets_Minimum_Criteria = CASE WHEN ('
	Set @S = @S + ' 									FractionScansMatchingSingleMassTag >= Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum'
	Set @S = @S + ' 									AND ('
	Set @S = @S + ' 										MassTagCountUniqueObserved >= CASE	WHEN Floor(PRef.Monoisotopic_Mass / Minimum_Criteria_ORFMassDaDivisor) >= Minimum_Criteria_UniqueMTCountMinimum'
	Set @S = @S + ' 																			THEN Floor(PRef.Monoisotopic_Mass / Minimum_Criteria_ORFMassDaDivisor)'
	Set @S = @S + ' 																			ELSE Minimum_Criteria_UniqueMTCountMinimum'
	Set @S = @S + ' 																	  END'
	Set @S = @S + ' 										OR'
	Set @S = @S + ' 										MassTagMatchingIonCount >= Minimum_Criteria_MTIonMatchCountMinimum'
	Set @S = @S + ' 										)'
	Set @S = @S + ' 									)'
	Set @S = @S + ' 								  THEN 1'
	Set @S = @S + ' 								  ELSE 0'
	Set @S = @S + ' 							 END'
	Set @S = @S + ' FROM	T_Quantitation_Results INNER JOIN'
	Set @S = @S + '			T_Proteins AS PRef ON '
	Set @S = @S + '			T_Quantitation_Results.Ref_ID = PRef.Ref_ID INNER JOIN'
	Set @S = @S + '			T_Quantitation_Description ON '
	Set @S = @S + '			T_Quantitation_Results.Quantitation_ID = T_Quantitation_Description.Quantitation_ID'

	-- If @QuantitationID is not null, then add a WHERE clause, limiting the effect of the UPDATE statement
	--
	If IsNull(@QuantitationID, -1) >=0
		Set @S = @S + ' WHERE T_Quantitation_Description.Quantitation_ID = ' + convert(varchar(32), @QuantitationID)
	
	Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error determining the new Meets_Minimum_Criteria value for Quantitation_ID = ' + convert(varchar(32), @QuantitationID)
		set @myError = 101
	end
  
	Print 'Updated ' + convert(varchar(32), @myRowCount) + ' rows'

	-----------------------------------------------------------
	-- Done processing; 
	-----------------------------------------------------------
		
	If @myError <> 0 
		Begin
			If Len(@message) > 0
				Set @message = ': ' + @message
			
			Set @message = 'Quantitation Processing Check Minimum Criteria Work Error ' + convert(varchar(32), @myError) + @message

			Print @message
		End
			
	Return @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QuantitationProcessCheckMinimumCriteria]  TO [DMS_SP_User]
GO


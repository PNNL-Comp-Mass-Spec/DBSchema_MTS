SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QRLookupOptionalColumns]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QRLookupOptionalColumns]
GO


CREATE Procedure dbo.QRLookupOptionalColumns 
/****************************************************	
**  Desc: Checks if the given Quantitation ID report contains
**		  expression ratio data or mass tags with mods
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID value to examine
**
**  Auth: mem
**	Date: 06/06/2004
**		  09/20/2004 mem - Updated for new MTDB schema
**
****************************************************/
(
	@QuantitationID int,
	@ERValuesPresent tinyint=0 Output,	-- If @ERValuesPresent is supplied and is nonzero, then the presence of ER values is not checked for
	@ModsPresent tinyint=0 Output		-- If @ModsPresent is supplied and is nonzero, then the presence of Mods is not checked for
)
AS 

	Set NoCount On

	Declare @MaxER float
	Declare @MyRowCount int
	
	Set @ERValuesPresent = IsNull(@ERValuesPresent, 0)
	Set @ModsPresent = IsNull(@ModsPresent, 0)
	
	-- If no ER values have been found yet, then look for ER values
	If @ERValuesPresent = 0
	Begin
		Set @MaxER = 0
		
		-- Determine if this QuantitationID has any nonzero ER values
		SELECT @MaxER = MAX(ABS(QRD.ER))
		FROM T_Quantitation_ResultDetails AS QRD INNER JOIN
			T_Quantitation_Results AS QR ON QRD.QR_ID = QR.QR_ID
		WHERE (QR.Quantitation_ID = @QuantitationID)
		--
		If @MaxER > 0
			Set @ERValuesPresent = 1
	End

	-- If no mods have been found yet, then look for them
	If @ModsPresent = 0
	Begin
		Set @MyRowCount = 0
		
		-- Determine if this QuantitationID has any mods
		SELECT @MyRowCount = COUNT(T_Mass_Tags.Mass_Tag_ID)
		FROM T_Quantitation_ResultDetails QRD INNER JOIN
			T_Quantitation_Results QR ON 
			QRD.QR_ID = QR.QR_ID INNER JOIN
			T_Mass_Tags ON QRD.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
		WHERE (QR.Quantitation_ID = @QuantitationID) AND 
			    (T_Mass_Tags.Mod_Count > 0)
		--
		If @MyRowCount > 0
			Set @ModsPresent = 1
	End

	Return @@Error


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QRLookupOptionalColumns]  TO [DMS_SP_User]
GO


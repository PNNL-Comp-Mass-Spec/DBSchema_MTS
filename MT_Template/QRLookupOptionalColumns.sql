/****** Object:  StoredProcedure [dbo].[QRLookupOptionalColumns] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**  Auth:	mem
**	Date:	06/06/2004
**			09/20/2004 mem - Updated for new MTDB schema
**			08/12/2008 mem - Added @XTandemDataPresent
**
****************************************************/
(
	@QuantitationID int,
	@ERValuesPresent tinyint=0 Output,		-- If @ERValuesPresent is supplied and is nonzero, then the presence of ER values is not checked for
	@ModsPresent tinyint=0 Output,			-- If @ModsPresent is supplied and is nonzero, then the presence of Mods is not checked for
	@XTandemDataPresent tinyint=0 Output	-- If @XTandemDataPresent is supplied and is nonzero, then the presence of XTandem data is not checked for
)
AS 

	Set NoCount On

	Declare @MaxER float
	
	Set @ERValuesPresent = IsNull(@ERValuesPresent, 0)
	Set @ModsPresent = IsNull(@ModsPresent, 0)
	Set @XTandemDataPresent = IsNull(@XTandemDataPresent, 0)
	
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
		-- Determine if this QuantitationID has any mods
		IF Exists (	SELECT *
					FROM T_Quantitation_ResultDetails QRD INNER JOIN
						 T_Quantitation_Results QR ON QRD.QR_ID = QR.QR_ID INNER JOIN
						 T_Mass_Tags MT ON QRD.Mass_Tag_ID = MT.Mass_Tag_ID
					WHERE (QR.Quantitation_ID = @QuantitationID) AND 
						  (MT.Mod_Count > 0)
				   )
			Set @ModsPresent = 1
	End

	-- If XTandem data hasn't been found yet, then look for it
	If @XTandemDataPresent = 0
	Begin
		-- Determine if this QuantitationID has any MTs with non-null Min_Log_EValue values
		IF Exists (	SELECT *
					FROM T_Quantitation_ResultDetails QRD INNER JOIN
						 T_Quantitation_Results QR ON QRD.QR_ID = QR.QR_ID INNER JOIN
						 T_Mass_Tags MT ON QRD.Mass_Tag_ID = MT.Mass_Tag_ID
					WHERE (QR.Quantitation_ID = @QuantitationID) AND 
						  (NOT MT.Min_Log_EValue Is Null)
				   )
			Set @XTandemDataPresent = 1
	End
	
	Return @@Error


GO
GRANT EXECUTE ON [dbo].[QRLookupOptionalColumns] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRLookupOptionalColumns] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRLookupOptionalColumns] TO [MTS_DB_Lite] AS [dbo]
GO

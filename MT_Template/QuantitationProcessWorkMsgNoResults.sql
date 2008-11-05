/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkMsgNoResults] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuantitationProcessWorkMsgNoResults
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006
**
****************************************************/
(
	@QuantitationID int,
	@InternalStdInclusionMode tinyint,
	@Message varchar(512)='' output
)
AS
	Set NoCount On
	
	set @Message = ''
	set @Message = @Message + 'Could not find any results in '

	If @InternalStdInclusionMode = 0
		set @Message = @Message + 'T_FTICR_UMC_Results and T_FTICR_UMC_ResultDetails'
	Else
	Begin
		If @InternalStdInclusionMode = 1
			set @Message = @Message + 'T_FTICR_UMC_Results, T_FTICR_UMC_ResultDetails, and T_FTICR_UMC_InternalStdDetails'
		Else
			set @Message = @Message + 'T_FTICR_UMC_Results and T_FTICR_UMC_InternalStdDetails'
	End
	
	set @Message = @Message + ' corresponding to the MDID(s) for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' listed in T_Quantitation_MDIDs'

	Return 0

GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkMsgNoResults] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkMsgNoResults] TO [MTS_DB_Lite]
GO

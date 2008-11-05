/****** Object:  StoredProcedure [dbo].[QRLookupReplicateAndFractionCounts] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.QRLookupReplicateAndFractionCounts
/****************************************************	
**  Desc: Returns the number of replicates, fractions,
**        and top level fractions for the given QuantitationID
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID value to process
**
**  Auth: mem
**	Date: 08/26/2003
**
****************************************************/
(
	@QuantitationID int,
	@ReplicateCount int OUTPUT,
	@FractionCount int OUTPUT,
	@TopLevelFractionCount int OUTPUT
)
AS
	Set NoCount On

	Declare @myError int,
			@MaxValue int

	Set @ReplicateCount = 0
	Set @FractionCount = 0
	Set @TopLevelFractionCount = 0

	Set @MaxValue = 0
	SELECT @ReplicateCount = COUNT(DISTINCT [Replicate]), @MaxValue = MAX ([Replicate])
	FROM T_Quantitation_MDIDs
	WHERE Quantitation_ID = @QuantitationID
	--
	SELECT @myError = @@Error
	--
	If @MaxValue > 1 AND @ReplicateCount <=1
		Set @ReplicateCount = @MaxValue
		
	Set @MaxValue = 0
	SELECT @FractionCount = COUNT(DISTINCT Fraction), @MaxValue = MAX (Fraction)
	FROM T_Quantitation_MDIDs
	WHERE Quantitation_ID = @QuantitationID
	--
	SELECT @myError = @@Error
	--
	If @MaxValue > 1 AND @FractionCount <=1
		Set @FractionCount = @MaxValue

	Set @MaxValue = 0
	SELECT @TopLevelFractionCount = COUNT(DISTINCT TopLevelFraction), @MaxValue = MAX (TopLevelFraction)
	FROM T_Quantitation_MDIDs
	WHERE Quantitation_ID = @QuantitationID
	--
	SELECT @myError = @@Error
	--
	If @MaxValue > 1 AND @TopLevelFractionCount <=1
		Set @TopLevelFractionCount = @MaxValue

	
	Return @myError



GO
GRANT VIEW DEFINITION ON [dbo].[QRLookupReplicateAndFractionCounts] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[QRLookupReplicateAndFractionCounts] TO [MTS_DB_Lite]
GO

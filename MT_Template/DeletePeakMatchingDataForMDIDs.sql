/****** Object:  StoredProcedure [dbo].[DeletePeakMatchingDataForMDIDs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.DeletePeakMatchingDataForMDIDs
/****************************************************
**
**	Desc: 
**		Removes all references to the MDID's ranging
**		from @MDIDStart to @MDIDEnd, including removing 
**		the MDID entry from T_Match_Making_Description 
**		and T_Peak_Matching_Task
**
**		Use with caution!
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	mem
**	Date:	08/23/2003
**			09/19/2003
**			01/02/2004 mem - added deletion of data in T_FTICR_UMC_NetLockerDetails
**			09/20/2004 mem - Removed reference to T_FTICR_Peak_Results
**			09/30/2004 mem - Added reference to T_FTICR_UMC_Members
**			05/07/2005 mem - Switched to using Between statements
**			12/20/2005 mem - Renamed T_FTICR_UMC_NETLockerDetails to T_FTICR_UMC_InternalStdDetails
**			01/19/2006 mem - Added parameter @ResetIdentityFieldSeed
**
*****************************************************/
(
	@MDIDStart int = -1,
	@MDIDEnd int = -1,
	@ResetIdentityFieldSeed tinyint = 0		-- Set to 1 to call SP ResetIdentityFieldSeed if no errors occur
)
AS

	Set NoCount On

	Declare @myError int,
			@myRowCount int,
			@MatchFound int
	
	---------------------------------------------------
	-- Define the MDID range to delete
	---------------------------------------------------

	If @MDIDStart < 0 OR @MDIDEnd < 0
	Begin
		Select 'MD_ID values cannot be negative.  Aborting.'
		Set @myError = 50000
		Goto Done
	End

	set @myError = 0
		
	SELECT 'Deleted all references to MD_ID ' + convert(varchar(9), MD_ID)
	FROM T_Match_Making_Description
	WHERE MD_ID BETWEEN @MDIDStart AND @MDIDEnd
	--
	SELECT @myError = @myError + @@Error, @myRowCount = @@RowCount

	-- Populate a temporary table with the list of QIDs containing an MD_ID value in the given range
	SELECT DISTINCT Quantitation_ID
	INTO #QIDsToDelete
	FROM T_Quantitation_MDIDs
	WHERE MD_ID BETWEEN @MDIDStart AND @MDIDEnd
	
	-- Note: this deletion will cascade into T_Quantitation_ResultDetails
	DELETE T_Quantitation_Results
	FROM T_Quantitation_Results QR INNER JOIN
		T_Quantitation_Description QD ON 
		QR.Quantitation_ID = QD.Quantitation_ID
	WHERE QD.Quantitation_ID IN (SELECT Quantitation_ID FROM #QIDsToDelete)
	--
	SELECT @myError = @myError + @@Error


	DELETE FROM T_Quantitation_MDIDs
	WHERE Quantitation_ID IN (SELECT Quantitation_ID FROM #QIDsToDelete)
	--
	SELECT @myError = @myError + @@Error


	DELETE FROM T_Quantitation_Description
	WHERE Quantitation_ID IN (SELECT Quantitation_ID FROM #QIDsToDelete)
	--
	SELECT @myError = @myError + @@Error

	
	
	DELETE T_FTICR_UMC_ResultDetails
	FROM T_FTICR_UMC_ResultDetails INNER JOIN T_FTICR_UMC_Results
			ON T_FTICR_UMC_ResultDetails.UMC_Results_ID = T_FTICR_UMC_Results.UMC_Results_ID
	WHERE T_FTICR_UMC_Results.MD_ID BETWEEN @MDIDStart AND @MDIDEnd 
	--
	SELECT @myError = @myError + @@Error


	DELETE T_FTICR_UMC_InternalStdDetails
	FROM T_FTICR_UMC_InternalStdDetails INNER JOIN T_FTICR_UMC_Results
			ON T_FTICR_UMC_InternalStdDetails.UMC_Results_ID = T_FTICR_UMC_Results.UMC_Results_ID
	WHERE T_FTICR_UMC_Results.MD_ID BETWEEN @MDIDStart AND @MDIDEnd
	--
	SELECT @myError = @myError + @@Error

	DELETE T_FTICR_UMC_Members
	FROM T_FTICR_UMC_Members INNER JOIN T_FTICR_UMC_Results
			ON T_FTICR_UMC_Members.UMC_Results_ID = T_FTICR_UMC_Results.UMC_Results_ID
	WHERE T_FTICR_UMC_Results.MD_ID BETWEEN @MDIDStart AND @MDIDEnd
	--
	SELECT @myError = @myError + @@Error

	DELETE FROM T_FTICR_UMC_Results
	WHERE MD_ID BETWEEN @MDIDStart AND @MDIDEnd
	--
	SELECT @myError = @myError + @@Error


	UPDATE T_Peak_Matching_Task
	Set MD_ID = Null
	WHERE MD_ID BETWEEN @MDIDStart AND @MDIDEnd
	--
	SELECT @myError = @myError + @@Error


	DELETE FROM T_Match_Making_Description
	WHERE MD_ID BETWEEN @MDIDStart AND @MDIDEnd
	--
	SELECT @myError = @myError + @@Error

	If @myError = 0 and @ResetIdentityFieldSeed <> 0
		Exec ResetIdentityFieldSeed

Done:
	DROP TABLE #QIDsToDelete

	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[DeletePeakMatchingDataForMDIDs] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[DeletePeakMatchingDataForMDIDs] TO [MTS_DB_Lite]
GO

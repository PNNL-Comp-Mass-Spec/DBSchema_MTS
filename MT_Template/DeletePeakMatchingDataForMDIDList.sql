/****** Object:  StoredProcedure [dbo].[DeletePeakMatchingDataForMDIDList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.DeletePeakMatchingDataForMDIDList
/****************************************************
**
**	Desc: 
**		Removes all references to the MDID's specified by
**		 @MDIDList, including removing the MDID entry from 
**		 T_Match_Making_Description and T_Peak_Matching_Task
**
**		Note that the values in @MDIDList all need to be integers
**		 but they do not need to be sorted
**
**		Use with caution!
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	mem
**	Date:	06/18/2006 mem - Matt's 31st Birthday
**			12/01/2006 mem - Now using udfParseDelimitedIntegerList to parse @MDIDList
**			09/29/2008 mem - Increased size of @MDIDList to varchar(max)
**
*****************************************************/
(
	@MDIDList varchar(max),
	@ResetIdentityFieldSeed tinyint = 0,		-- Set to 1 to call SP ResetIdentityFieldSeed if no errors occur
	@InfoOnly tinyint = 0,
	@Message varchar(512) = '' output
)
AS

	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0
	
	Declare @UniqueID int
	Declare @MDIDStart int
	Declare @MDIDEnd int
	
	Declare @MDIDCurrent int
	Declare @Continue int

	Declare @MDIDValuesProcessed int
	Set @MDIDValuesProcessed = 0

	---------------------------------------------------
	-- Validate the input values
	---------------------------------------------------
	
	Set @MDIDList = LTRIM(RTRIM(IsNull(@MDIDList, '')))
	Set @ResetIdentityFieldSeed = IsNull(@ResetIdentityFieldSeed, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @Message = ''
	
	If Len(@MDIDList) = 0
	Begin
		Set @Message = '@MDIDList is blank; nothing to do.'
		Goto Done
	End
				
	---------------------------------------------------
	-- Split @MDIDList and populate a temporary table
	---------------------------------------------------
	
	CREATE TABLE #TmpMDIDList (
		MDID int NOT NULL
	)

	CREATE TABLE #TmpMDIDDeletionRanges (
		RangeID int IDENTITY(1,1),
		MDIDStart int,
		MDIDEnd int
	)
	
	INSERT INTO #TmpMDIDList (MDID)
	SELECT Value
	FROM dbo.udfParseDelimitedIntegerList(@MDIDList, ',')
	--
	SELECT @myError = @@Error, @myRowCount = @@RowCount
	--
	If @myError <> 0
	Begin
		Set @Message = 'Error populating #TmpMDIDList (ID ' + Convert(varchar(12), @myError) + ')'
		Goto Done
	End
	--
	If @myRowcount = 0
	Begin
		Set @Message = 'No values were parsed out of @MDIDList: ' + @MDIDList
		Goto Done
	End

	---------------------------------------------------
	-- Step through #TmpMDIDList to find any contiguous values
	---------------------------------------------------

	Set @MDIDValuesProcessed = 0
	Set @MDIDStart = 0
	Set @MDIDEnd = 0
	
	Set @MDIDCurrent = -9999999
	Set @Continue = 1
	While @Continue = 1
	Begin -- <a>
		SELECT TOP 1 @MDIDCurrent = MDID
		FROM #TmpMDIDList
		WHERE MDID > @MDIDCurrent
		ORDER BY MDID
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount

		If @myError <> 0 OR @myRowCount <> 1
			Set @Continue = 0
		Else
		Begin -- <b>
			If @MDIDValuesProcessed = 0
			Begin
				Set @MDIDStart = @MDIDCurrent
				Set @MDIDEnd = @MDIDCurrent
			End
			Else
			Begin -- <c>
				If @MDIDCurrent = @MDIDEnd + 1
					Set @MDIDEnd = @MDIDCurrent
				Else
				Begin
					INSERT INTO #TmpMDIDDeletionRanges (MDIDStart, MDIDEnd)
					SELECT @MDIDStart, @MDIDEnd

					If @InfoOnly = 0
						Exec DeletePeakMatchingDataForMDIDs @MDIDStart, @MDIDEnd, 0 
						
					Set @MDIDStart = @MDIDCurrent
					Set @MDIDEnd = @MDIDCurrent
				End
				
			End -- </c>

			Set @MDIDValuesProcessed = @MDIDValuesProcessed + 1
		End -- </b>
	End -- </a>
	
	If @MDIDValuesProcessed > 0
	Begin
		INSERT INTO #TmpMDIDDeletionRanges (MDIDStart, MDIDEnd)
		SELECT @MDIDStart, @MDIDEnd

		If @InfoOnly = 0
		Begin
			Exec DeletePeakMatchingDataForMDIDs @MDIDStart, @MDIDEnd, 0
			Set @message = 'Deleted ' + Convert(varchar(12), @MDIDValuesProcessed) + ' MDIDs'
		End
	End
	
	If @InfoOnly = 0
	Begin
		If @myError = 0 and @ResetIdentityFieldSeed <> 0
			Exec ResetIdentityFieldSeed
	End

	SELECT RangeID, MDIDStart, MDIDEnd, MDIDEnd - MDIDStart + 1 As MDIDs_In_Range
	FROM #TmpMDIDDeletionRanges
	ORDER BY RangeID

Done:
	DROP TABLE #TmpMDIDList
	DROP TABLE #TmpMDIDDeletionRanges

	If @myError <> 0 Or Len(@Message) > 0
		SELECT @message AS Message
	
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[DeletePeakMatchingDataForMDIDList] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[DeletePeakMatchingDataForMDIDList] TO [MTS_DB_Lite]
GO

/****** Object:  StoredProcedure [dbo].[QRCollapseToUniqueList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.QRCollapseToUniqueList 
/****************************************************	
**  Desc:	Examines a comma separated list of values and
**			collapses the list to a unique list of values
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID value to examine
**
**  Auth:	mem
**	Date:	09/22/2005
**			03/29/2012 mem - Updated to use udfParseDelimitedListOrdered
**
****************************************************/
(
	@WorkingList varchar(7500),				-- Comma separated list of values (text and/or numbers)
	@UniqueList varchar(7500) OUTPUT		-- Populated with values in @WorkingList but with duplicates values removed
)
AS 

	Set NoCount On

	Declare @CommaLoc int
	Declare @ListItem varchar(7500)
	
	Set @WorkingList = IsNull(@WorkingList, '')
	
	SELECT @UniqueList = COALESCE(@UniqueList + ',' + Value, Value)
	FROM ( SELECT Value,
		            MIN(EntryID) AS EntryID
		    FROM dbo.udfParseDelimitedListOrdered ( @WorkingList, ',' )
		    GROUP BY Value
		    HAVING LEN(Value) > 0 
		    ) LookupQ
	ORDER BY EntryID
	
	Set @UniqueList = IsNull(@UniqueList, '')
	
	Return @@Error


GO
GRANT EXECUTE ON [dbo].[QRCollapseToUniqueList] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRCollapseToUniqueList] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRCollapseToUniqueList] TO [MTS_DB_Lite] AS [dbo]
GO

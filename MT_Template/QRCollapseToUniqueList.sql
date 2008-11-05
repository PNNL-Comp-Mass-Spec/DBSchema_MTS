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
**  Auth: mem
**	Date: 09/22/2005
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
	
	If Len(IsNull(@WorkingList, '')) <= 0
	Begin
		Set @UniqueList = ''
	End
	Else
	Begin
		-- Make sure @WorkingList ends in a comma
		If SubString(@WorkingList, Len(@WorkingList),1) <> ','
			Set @WorkingList = @WorkingList + ','
			
		-- Need a leading comma on @UniqueList for the If CharIndex text below
		Set @UniqueList = ','
		Set @CommaLoc = CharIndex(',', @WorkingList)
		While @CommaLoc > 1
		Begin
			Set @ListItem = LTrim(Left(@WorkingList, @CommaLoc-1))
			Set @WorkingList = SubString(@WorkingList, @CommaLoc+1, Len(@WorkingList))
		
			If CharIndex(',' + @ListItem + ',', @UniqueList) < 1
			Begin
				Set @UniqueList = @UniqueList + @ListItem + ','
			End
			
			Set @CommaLoc = CharIndex(',', @WorkingList)
		End	

		-- Remove the leading comma and trailing comma from @UniqueList
		Set @UniqueList = SubString(@UniqueList,2, Len(@UniqueList)-2)
	End
	
	Return @@Error


GO
GRANT EXECUTE ON [dbo].[QRCollapseToUniqueList] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[QRCollapseToUniqueList] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[QRCollapseToUniqueList] TO [MTS_DB_Lite]
GO

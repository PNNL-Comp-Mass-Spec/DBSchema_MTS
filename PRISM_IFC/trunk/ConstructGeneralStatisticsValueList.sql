/****** Object:  StoredProcedure [dbo].[ConstructGeneralStatisticsValueList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.ConstructGeneralStatisticsValueList
/****************************************************
**
**	Desc: 
**		Constructs a list of matching entries in #Temp_General_Statistics,
**		filtering on MTL_Name and Value
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 10/22/2004
**    
*****************************************************/
	@Database_Name varchar(128),
	@LabelName varchar(255),				-- Single label name to match
	@ValueList varchar(2048) output,		-- Comma separated list of matching values
	@UseCategoryField tinyint = 0			-- If 0, then matches Label field; if 1 then matches Category field
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	Set @ValueList = ''

	If @UseCategoryField = 1
		SELECT @ValueList = @ValueList + Label + ', '
		FROM #Temp_General_Statistics
		WHERE [Database Name] = @Database_Name AND Category = @LabelName
		ORDER BY Value
	
	Else
		SELECT @ValueList = @ValueList + Value + ', '
		FROM #Temp_General_Statistics
		WHERE [Database Name] = @Database_Name AND Label = @LabelName
		ORDER BY Value
	
	-- Remove the trailing comma
	IF Len(@ValueList) > 0
		Set @ValueList = SubString(@ValueList, 1, Len(@ValueList) - 1)


Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[ConstructGeneralStatisticsValueList] TO [DMS_SP_User]
GO

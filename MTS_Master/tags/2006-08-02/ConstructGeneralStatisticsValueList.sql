SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ConstructGeneralStatisticsValueList]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ConstructGeneralStatisticsValueList]
GO

CREATE PROCEDURE dbo.ConstructGeneralStatisticsValueList
/****************************************************
**
**	Desc: 
**		Constructs a list of matching entries in T_General_Statistics_Cached
**		filtering on Server_Name, Database_Name, and Value
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 10/22/2004
**			  12/06/2004 mem - Ported to MTS_Master
**    
*****************************************************/
	@Server_Name varchar(128),
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
		FROM T_General_Statistics_Cached
		WHERE Server_Name = @Server_Name AND DBName = @Database_Name AND Category = @LabelName
		ORDER BY Value
	
	Else
		SELECT @ValueList = @ValueList + Value + ', '
		FROM T_General_Statistics_Cached
		WHERE Server_Name = @Server_Name AND DBName = @Database_Name AND Label = @LabelName
		ORDER BY Value
	
	-- Remove the trailing comma
	IF Len(@ValueList) > 0
		Set @ValueList = SubString(@ValueList, 1, Len(@ValueList) - 1)


Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[ConstructGeneralStatisticsValueList]  TO [DMS_SP_User]
GO

GRANT  EXECUTE  ON [dbo].[ConstructGeneralStatisticsValueList]  TO [MTUser]
GO


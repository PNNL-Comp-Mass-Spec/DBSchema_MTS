SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetQCTrendSPs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetQCTrendSPs]
GO

CREATE PROCEDURE dbo.GetQCTrendSPs 
/****************************************************
**
**	Desc: 
**	Returns the names and descriptions of the QC Trend SPs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @message				-- Status/error message output
**
**		Auth: mem
**		Date: 07/15/2005
**			  08/28/2005 mem - Added column Category_ID to the output
**
*****************************************************/
	@message varchar(512) = '' output
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	SELECT SPC.Category_Name, SPL.SP_Name, 
		   SPL.SP_Description, SPL.SP_ID, SPL.Category_ID
	FROM T_SP_List SPL INNER JOIN T_SP_Categories SPC ON 
		 SPL.Category_ID = SPC.Category_ID
	WHERE SPL.Category_ID IN (5, 6)
	ORDER BY SPC.Category_Name, SPL.SP_Name
	
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetQCTrendSPs]  TO [DMS_SP_User]
GO


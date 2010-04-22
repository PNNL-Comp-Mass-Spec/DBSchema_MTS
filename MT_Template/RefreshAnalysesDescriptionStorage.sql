/****** Object:  StoredProcedure [dbo].[RefreshAnalysesDescriptionStorage] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.RefreshAnalysesDescriptionStorage
/****************************************************
**
**	Desc: 
**		find analysis jobs in this database
**		that have different storage attributes than
**		the corresponding job in DMS (via MT_Main)
**		and correct them
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**
**	Auth:	grk
**	Date:	04/1/2003
**			07/08/2005 mem - Updated to call RefreshAnalysisDescriptionInfo
**			12/09/2008 mem - Increased size of @message to varchar(4000)
**    
*****************************************************/
 	@message varchar(4000) = '' output
As
	set nocount on

	declare @myError int
	
	-- The behavior of this SP has been superseded by RefreshAnalysisDescriptionInfo
	Exec @myError = RefreshAnalysisDescriptionInfo @UpdateInterval = 0, @message=@message output

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[RefreshAnalysesDescriptionStorage] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshAnalysesDescriptionStorage] TO [MTS_DB_Lite] AS [dbo]
GO

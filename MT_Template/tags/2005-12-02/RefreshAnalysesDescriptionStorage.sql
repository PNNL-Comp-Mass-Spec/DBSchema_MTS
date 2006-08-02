SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RefreshAnalysesDescriptionStorage]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RefreshAnalysesDescriptionStorage]
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
**		Auth: grk
**		Date: 04/1/2003
**			  07/08/2005 mem - Updated to call RefreshAnalysisDescriptionInfo
**    
*****************************************************/
 	@message varchar(255) = '' output
As
	set nocount on

	declare @myError int
	
	-- The behavior of this SP has been superseded by RefreshAnalysisDescriptionInfo
	Exec @myError = RefreshAnalysisDescriptionInfo @UpdateInterval = 0

	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


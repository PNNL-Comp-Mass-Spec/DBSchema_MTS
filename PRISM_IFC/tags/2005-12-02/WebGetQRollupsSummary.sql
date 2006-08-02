SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[WebGetQRollupsSummary]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[WebGetQRollupsSummary]
GO

CREATE PROCEDURE dbo.WebGetQRollupsSummary
/****************************************************
**	Desc: Returns summary list of Q Rollups for given mass tag database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**      @MTDBName       -- name of mass tag database to use
**		@message        -- explanation of any error that occurred
**
**		Auth: jee
**		Date: 4/16/2004
**    
*****************************************************/
	@MTDBName varchar(128) = '',
	@message varchar(512) = '' output
As
	declare @result int
	exec @result = GetQRollupsSummary @MTDBName, 1, '', @message
	RETURN @result

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[WebGetQRollupsSummary]  TO [DMS_SP_User]
GO


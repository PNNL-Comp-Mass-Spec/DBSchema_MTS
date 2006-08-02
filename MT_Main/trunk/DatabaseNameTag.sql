SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DatabaseNameTag]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[DatabaseNameTag]
GO

CREATE FUNCTION dbo.DatabaseNameTag
	(
	@DatabaseName varchar(128)
	)
RETURNS varchar(24)
AS
	BEGIN

		declare @tag varchar(24)
		set @tag = 'Unknown'

		-- Find the first underscore from the right of @DatabaseName
		declare @MatchLoc int
		declare @StartLoc int
		set @MatchLoc = charindex('_', Reverse(@DatabaseName))

		if @MatchLoc > 0
		Begin
			Set @StartLoc = Len(@DatabaseName) - @MatchLoc + 2
			set @tag = SubString(@DatabaseName, @StartLoc, @MatchLoc)
		End
		
	RETURN @tag
	END

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[DatabaseNameTag]  TO [DMS_SP_User]
GO


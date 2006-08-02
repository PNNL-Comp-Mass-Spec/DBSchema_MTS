SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DropOldNETExportViews]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[DropOldNETExportViews]
GO


CREATE PROCEDURE dbo.DropOldNETExportViews
/****************************************************
** 
**		Desc:  
**        Drops any views containing @matchString that were created more than @MaxAgeHours ago
**
**		Auth:	mem
**		Date:	05/30/2005
**    
*****************************************************/
	@matchString varchar(256)= 'V_NET_Export_Peptides_Task_%',
	@DropViews tinyint = 1,										-- Set to 1 to drop views, 0 to drop tables
	@MaxAgeHours int = 48,
	@ObjectDropCount int = 0,
	@message varchar(256) = '' output
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @continue tinyint
	
	declare @Sql varchar(1024)
	declare @ObjectName varchar(128)
	declare @ObjectID int
	declare @CreationDate datetime
	
	declare @ObjectAge int
	declare @ObjectType char
	declare @ObjectTypeName varchar(12)
	
	set @ObjectDropCount = 0
	set @message = ''

	if @DropViews = 1
	Begin
		Set @ObjectType = 'V'
		Set @ObjectTypeName = 'View'
	End
	Else
	Begin
		Set @ObjectType = 'U'
		Set @ObjectTypeName = 'Table'
	End
		
	-----------------------------------------------------------
	-- Replace any underscore in @matchString with [_] since _ means any single character when used in a Like clause
	-----------------------------------------------------------
	--
	Set @matchString = Replace(@matchString, '_', '[_]')
	
	-----------------------------------------------------------
	-- Possibly surround @matchString with wildcard symbols
	-----------------------------------------------------------
	--
	If CharIndex('%', @matchString) <= 0
		Set @matchString = '%' + @matchString + '%'

	-----------------------------------------------------------
	-- Look for matching objects in sysobjects
	-----------------------------------------------------------
	--
	set @continue = 1
	set @ObjectID = -1
	--
	While @continue > 0
	Begin
	
		SELECT TOP 1 @ObjectName = [name], @ObjectID = id, @CreationDate = crdate
		FROM sysobjects
		WHERE xtype = @ObjectType AND [name] Like @matchString AND id > @ObjectID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Problem finding next matching object in sysobjects'
			goto Done
		end

		if @myRowCount = 0
			Set @continue = 0
		Else
		Begin
			Set @ObjectAge = DateDiff(hour, @CreationDate, GetDate())
			If IsNull(@ObjectAge, 0) >= @MaxAgeHours
			Begin
				set @Sql = ' DROP ' + @ObjectTypeName + ' ' + @ObjectName
				--
				Exec (@Sql)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				--
				if @myError <> 0
				begin
					set @message = 'Problem dropping object ' + @ObjectName
					goto Done
				end
				
				Set @message = 'Dropped old work objects (' + convert(varchar(9), @ObjectAge) + ' hours old): ' + @ObjectName
				Exec PostLogEntry 'Error', @message, 'DropOldNETExportViews'
				
				set @ObjectDropCount = @ObjectDropCount + 1
			End
		End
		
	End

	if @ObjectDropCount = 0
		set @message = 'No old objects were found matching ''' + @matchstring + ''''
	else
		set @message = 'Dropped ' + convert(varchar(9), @ObjectDropCount) + ' old objects matching ''' + @matchstring + ''''

	Select @message as Message
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


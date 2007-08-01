/****** Object:  StoredProcedure [dbo].[DropOldWorkTables] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.DropOldWorkTables
/****************************************************
** 
**		Desc:  
**        Drops any tables containing @matchString that were created more than @MaxAgeHours ago
**
**		Auth:	mem
**		Date:	02/10/2005
**    
*****************************************************/
	@matchString varchar(256)= 'SeqWork_',
	@MaxAgeHours int = 120,
	@TableDropCount int = 0,
	@message varchar(256) = '' output
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	declare @continue tinyint
	
	declare @Sql varchar(1024)
	declare @TableName varchar(128)
	declare @TableID int
	declare @CreationDate datetime
	
	declare @TableAge int
	
	set @TableDropCount = 0
	set @message = ''
	
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
	-- Look for matching tables in sysobjects
	-----------------------------------------------------------
	--
	set @continue = 1
	set @TableID = -1
	--
	While @continue > 0
	Begin
	
		SELECT TOP 1 @TableName = [name], @TableID = id, @CreationDate = crdate
		FROM sysobjects
		WHERE [name] Like @matchString AND id > @TableID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Problem finding next matching table in sysobjects'
			goto Done
		end

		if @myRowCount = 0
			Set @continue = 0
		Else
		Begin
			Set @TableAge = DateDiff(hour, @CreationDate, GetDate())
			If IsNull(@TableAge, 0) >= @MaxAgeHours
			Begin
				set @Sql = ' DROP TABLE ' + @TableName
				--
				Exec (@Sql)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				--
				if @myError <> 0
				begin
					set @message = 'Problem dropping table ' + @TableName
					goto Done
				end
				
				Set @message = 'Dropped old work table (' + convert(varchar(9), @TableAge) + ' hours old): ' + @TableName
				Exec PostLogEntry 'Error', @message, 'DropOldWorkTables'
				
				set @TableDropCount = @TableDropCount + 1
			End
		End
		
	End

	if @TableDropCount = 0
		set @message = 'No old tables were found matching ''' + @matchstring + ''''
	else
		set @message = 'Dropped ' + convert(varchar(9), @TableDropCount) + ' old tables matching ''' + @matchstring + ''''

	Select @message as Message
	
Done:
	return @myError

GO

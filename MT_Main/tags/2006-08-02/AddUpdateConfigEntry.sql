SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AddUpdateConfigEntry]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AddUpdateConfigEntry]
GO

CREATE PROCEDURE AddUpdateConfigEntry
/****************************************************
**
**	Desc: Sets a configuration value in a database
**		  @entryValue can contain a single value, or a 
**		  delimiter separated list of values
**
**		  If 1 row exists with field Name = @entryName, then
**		  updates the existing row with the first value in the
**		  list, then appends the remaining values in the list
**
**		  If more than 1 row exists with field Name = @entryName, 
**		  then deletes all but one of the matching rows, updates
**		  the remaining row with the first value in @entryValue,
**		  then appends the remaining values to the list
**
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/22/2004
**			11/23/2005 mem - Added brackets around @dbName as needed to allow for DBs with dashes in the name
**			12/15/2005 mem - Now preventing zero-length values from being added to #TmpValues
**    
*****************************************************/
(
	@dbName varchar(64),
	@entryName varchar(256),
	@entryValueList varchar(2048),
	@valueDelimiter char(1) = ',',
	@configTableName varchar(64) = 'T_Process_Config',
	@configNameColumn varchar(32) = 'Name',
	@configValueColumn varchar(32) = 'Value'
)
AS

	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @DelimiterLoc int
	declare @valueListCount int
	
	declare @ListRemaining varchar(2048)
	declare @matchCount int
	declare @rowMatchID int
	
	declare @remoteTableName varchar(256)
	declare @CurrValue varchar(512)
	
	declare @S nvarchar(4000)
	
	Set @matchCount = 0
	Set @valueListCount = 0
	Set @rowMatchID = 0
	
	---------------------------------------------------	
	-- If @entryValueList is empty, then don't change anything
	---------------------------------------------------	
	If Len(IsNull(@entryValueList, '')) = 0
		Goto Done

	---------------------------------------------------	
	-- Initialize @remoteTableName
	---------------------------------------------------	
	Set @remoteTableName = '[' + @dbName + ']..' + @configTableName

	---------------------------------------------------	
	-- Create a temporary table to hold the values
	---------------------------------------------------	
	CREATE TABLE #TmpValues (
		NewValue varchar(512)
	)

	-- Create a unique index to guarantee no duplicate values
	CREATE UNIQUE CLUSTERED INDEX #IX_TmpValues ON #TmpValues (NewValue ASC)

	---------------------------------------------------	
	-- Parse @entryValueList, splitting on @valueDelimiter
	---------------------------------------------------	

	Set @ListRemaining = @entryValueList
	
	While Len(@ListRemaining) > 0
	Begin
		---------------------------------------------------	
		-- Extract next inclusion item and build criteria
		---------------------------------------------------	
		Set @DelimiterLoc = CharIndex(@valueDelimiter, @ListRemaining)		
		If @DelimiterLoc > 0
		 Begin
			Set @CurrValue = RTrim(LTrim(SubString(@ListRemaining, 1, @DelimiterLoc-1)))
			Set @ListRemaining = RTrim(LTrim(SubString(@ListRemaining, @DelimiterLoc+1, Len(@ListRemaining)-@DelimiterLoc)))
		 End
		Else			--last inclusion item
		 Begin
			Set @CurrValue = RTrim(LTrim(@ListRemaining))
			Set @ListRemaining = ''
		 End

		If Len(@CurrValue) > 0
			INSERT INTO #TmpValues (NewValue)
			VALUES (@CurrValue)
	End

	SELECT @valueListCount = COUNT(*)
	FROM #TmpValues	


	---------------------------------------------------	
	-- Start a transaction
	---------------------------------------------------	

	declare @transName varchar(32)
	set @transName = 'AddUpdateConfigEntry'
	begin transaction @transName
	
	
	---------------------------------------------------	
	-- Check for existing entries in @configTableName
	---------------------------------------------------	
	
	Set @S = ''
	Set @S = @S + ' SELECT @matchCount = COUNT(*)'
	Set @S = @S + ' FROM ' + @remoteTableName
	Set @S = @S + ' WHERE (' + @configNameColumn + ' = ''' + @entryName + ''')'
	--
	exec sp_executesql @S, N'@matchCount int output', @matchCount output
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	Begin
		Rollback transaction @transName
		Goto Done
	End
	
	If @matchCount > 1
	Begin
		---------------------------------------------------	
		-- More than one matching row, delete all but the first one
		---------------------------------------------------	
		
		Set @S = ''
		Set @S = @S + ' SELECT @rowMatchID = MIN(Process_Config_ID)'
		Set @S = @S + ' FROM ' + @remoteTableName
		Set @S = @S + ' WHERE (' + @configNameColumn + ' = ''' + @entryName + ''')'
		--
		exec sp_executesql @S, N'@rowMatchID int output', @rowMatchID output
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount		
		--
		if @myError <> 0
		Begin
			Rollback transaction @transName
			Goto Done
		End

		
		Set @S = ''
		Set @S = @S + ' DELETE FROM ' + @remoteTableName
		Set @S = @S + ' WHERE (' + @configNameColumn + ' = ''' + @entryName + ''') AND'
		Set @S = @S + ' Process_Config_ID > ' + Convert(varchar(11), @rowMatchID)
		--
		exec sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount		
		--
		if @myError <> 0
		Begin
			Rollback transaction @transName
			Goto Done
		End


		---------------------------------------------------	
		-- Verify that just one matching row remains
		---------------------------------------------------	

		Set @S = ''
		Set @S = @S + ' SELECT @matchCount = COUNT(*)'
		Set @S = @S + ' FROM ' + @remoteTableName
		Set @S = @S + ' WHERE (' + @configNameColumn + ' = ''' + @entryName + ''')'
		--
		exec sp_executesql @S, N'@matchCount int output', @matchCount output
	End
	
	if @matchCount = 0
	Begin
		Set @S = ''
		Set @S = @S + ' INSERT INTO ' + @remoteTableName + ' (' + @configNameColumn + ', ' + @configValueColumn + ')'
		Set @S = @S + ' SELECT ''' + @entryName + ''', NewValue'
		Set @S = @S + ' FROM #TmpValues'
	End
	Else
	Begin
		If @valueListCount > 1
		Begin
			-- Grab the first value from #TmpValues and append it to the table
			
			SELECT TOP 1 @CurrValue = NewValue
			FROM #TmpValues
			
			DELETE FROM
			#TmpValues WHERE NewValue = @CurrValue

			Set @S = ''
			Set @S = @S + ' UPDATE ' + @remoteTableName
			Set @S = @S + ' SET ' + @configValueColumn + ' = ''' +   @CurrValue + ''''
			Set @S = @S + ' WHERE (' + @configNameColumn + ' = ''' + @entryName + ''')'
			--
			exec sp_executesql @S
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0
			Begin
				Rollback transaction @transName
				Goto Done
			End


			-- Now append the remaining values to the table
			Set @S = ''
			Set @S = @S + ' INSERT INTO ' + @remoteTableName + ' (' + @configNameColumn + ', ' + @configValueColumn + ')'
			Set @S = @S + ' SELECT ''' + @entryName + ''', NewValue'
			Set @S = @S + ' FROM #TmpValues'
			
		End
		Else
		Begin
			Set @S = ''
			Set @S = @S + ' UPDATE ' + @remoteTableName
			Set @S = @S + ' SET ' + @configValueColumn + ' = ''' +  @entryValueList + ''''
			Set @S = @S + ' WHERE (' + @configNameColumn + ' = ''' + @entryName + ''')'
		End
	End

	exec sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	Begin
		Rollback transaction @transName
		Goto Done
	End
	Else
		Commit transaction @transName
		
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


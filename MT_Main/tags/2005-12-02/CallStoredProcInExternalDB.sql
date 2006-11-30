SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CallStoredProcInExternalDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CallStoredProcInExternalDB]
GO

CREATE PROCEDURE dbo.CallStoredProcInExternalDB
/****************************************************
**
**	Desc: 
**      Calls the Stored Procedure specified by
**      @StoredProcNameToCall in the database
**      specified by 
**
**		Auth: grk
**		Date: 7/16/2004
**			  11/23/2005 mem - Added brackets around @ExternalDBName as needed to allow for DBs with dashes in the name
**
*****************************************************/
	@ExternalDBName varchar(64),	
	@StoredProcNameToCall varchar(128),
	@CheckForExistenceOnly tinyint = 0, -- If 1, then only checks if SP exists; does not Execute it
	@StoredProcFound int Output,
	@message varchar(512)='' Output
AS
	set nocount on

	declare @myError int,
			@myRowCount int,
			@MTDBCount int,
			@done int

	set @myError = 0
	set @myRowCount = 0
	set @done = 0

	-- Note: @S needs to be unicode (nvarchar) for compatibility with sp_executesql
	declare @S nvarchar(1024),
			@SPToExec varchar(255)
				
	set @SPToExec = ''
	set @message = ''
	
	---------------------------------------------------
	-- Check if stored procedures exists in external DB
	-- and execute it if it does
	---------------------------------------------------


	-- query system tables in external DB for existance 
	-- of stored procedure object with correct name
	--
	set @StoredProcFound = 0
	--
	Set @S = ''				
	Set @S = @S + ' SELECT @StoredProcFound = COUNT(*)'
	Set @S = @S + ' FROM [' + @ExternalDBName + ']..sysobjects'
	Set @S = @S + ' WHERE id = OBJECT_ID(N''[' + @ExternalDBName + ']..[' + @StoredProcNameToCall + ']'')  '
	--
	EXEC sp_executesql @S, N'@StoredProcFound int OUTPUT', @StoredProcFound OUTPUT

	If (@StoredProcFound = 0)
		Select @StoredProcNameToCall + ' not found in ' + @ExternalDBName
	Else
		Begin
			if @CheckForExistenceOnly = 1
				Set @message = @StoredProcNameToCall + ' was found in ' + @ExternalDBName
			else
				begin
					-- Call RequestPeakMatchingTask in @ExternalDBName
					Set @SPToExec = '[' + @ExternalDBName + ']..' + @StoredProcNameToCall
						
					Select @SPToExec
	
					Exec @myError = @SPToExec
				end
		End		
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

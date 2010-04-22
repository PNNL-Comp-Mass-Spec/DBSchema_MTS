/****** Object:  StoredProcedure [dbo].[AddNewInternalStandardUsingExisting] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE AddNewInternalStandardUsingExisting
/****************************************************
**
**	Desc: Adds a new row to T_Internal_Standards, named @NewInternalStdName
**		  Populates T_Internal_Std_Composition using the entries for internal standard @ExistingInternalStdToCopy
**
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/17/2008
**			05/20/2009 mem - Added default values; run this procedure with @infoOnly = 0 to commit the changes
**    
*****************************************************/
(
	@NewInternalStdName varchar(50) = 'MP_09_02',
	@NewInternalStdDescription varchar(255) = 'MP_09_02',
	@ExistingInternalStdToCopy varchar(50) = 'MP_09_01',
	@message varchar(512) = '' output,
	@infoOnly tinyint = 1
)
AS

	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @MixIDBase int
	declare @MixIDNew int
	
	---------------------------------------------------	
	-- Validate the inputs
	---------------------------------------------------	
	Set @NewInternalStdName = IsNull(@NewInternalStdName, '')
	Set @NewInternalStdDescription = IsNull(@NewInternalStdDescription, '')
	Set @ExistingInternalStdToCopy = IsNull(@ExistingInternalStdToCopy, '')
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	Set @message = ''
	
	If Len(@NewInternalStdName) = ''
	Begin
		Set @message = '@NewInternalStdName is blank; unable to continue'
		Set @myError = 50000
		Goto Done
	End
	
	If Len(@ExistingInternalStdToCopy) = ''
	Begin
		Set @message = '@ExistingInternalStdToCopy is blank; unable to continue'
		Set @myError = 50001
		Goto Done
	End
	
	If Len(@NewInternalStdDescription) = 0
		Set @NewInternalStdDescription = @NewInternalStdName

	---------------------------------------------------	
	-- Look for @ExistingInternalStdToCopy in T_Internal_Standards
	---------------------------------------------------	

	Set @MixIDBase = -1	
	SELECT @MixIDBase = Internal_Std_Mix_ID
	FROM T_Internal_Standards
	WHERE (Name = @ExistingInternalStdToCopy)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @message = 'Could not find "' + @ExistingInternalStdToCopy + '" in Internal_Std_Mix_ID; unable to continue'
		Set @myError = 50002
		Goto Done
	End
	
	If Exists (SELECT * from T_Internal_Standards WHERE Name = @NewInternalStdName)
	Begin
		Set @message = '"' + @NewInternalStdName + '" is already present in Internal_Std_Mix_ID; unable to continue'
		Set @myError = 50003
		Goto Done
	End
	
	If @infoOnly <> 0
	Begin
		-- Preview what Mix_ID will be assigned
		Set @MixIDNew = 1
		SELECT @MixIDNew = Max(Internal_Std_Mix_ID)+1
		FROM T_Internal_Standards
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-- Preview the new description and Type
		SELECT @NewInternalStdName AS Name, @NewInternalStdName AS Description, Type
		FROM T_Internal_Standards
		WHERE Name = @ExistingInternalStdToCopy
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		SELECT @MixIDNew AS Internal_Std_Mix_ID, Seq_ID, Concentration
		FROM T_Internal_Std_Composition
		WHERE Internal_Std_Mix_ID = @MixIDBase
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		Goto Done
	End
	
	---------------------------------------------------	
	-- Add @NewInternalStdName to T_Internal_Standards
	---------------------------------------------------
	--
	INSERT INTO T_Internal_Standards (Name, Description, Type)
	SELECT @NewInternalStdName, @NewInternalStdName, Type
	FROM T_Internal_Standards
	WHERE Name = @ExistingInternalStdToCopy
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myError <> 0 Or @myRowCount = 0
	Begin
		Set @message = 'Error adding "' + @NewInternalStdName + '"to Internal_Std_Mix_ID based on "' + @ExistingInternalStdToCopy + '"; @myError = ' + Convert(varchar(18), @myError)
		Set @myError = 50004
		Goto Done
	End

	Set @message = 'Added "' + @NewInternalStdName + '" to T_Internal_Standards'
	
	SELECT @MixIDNew = Internal_Std_Mix_ID
	FROM T_Internal_Standards
	WHERE (Name = @NewInternalStdName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @message = 'Could not find "' + @NewInternalStdName + '" in Internal_Std_Mix_ID; unable to continue'
		Set @myError = 50002
		Goto Done
	End
	
	Set @message = @message + '; ID = ' + Convert(varchar(12), @MixIDNew)
	
	---------------------------------------------------	
	-- Populate T_Internal_Std_Composition
	---------------------------------------------------	
	--
	INSERT INTO T_Internal_Std_Composition (Internal_Std_Mix_ID, Seq_ID, Concentration)
	SELECT @MixIDNew, Seq_ID, Concentration
	FROM T_Internal_Std_Composition
	WHERE (Internal_Std_Mix_ID = @MixIDBase)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	Set @message = @message + '; Added ' + Convert(varchar(12), @myRowCount) + ' components to T_Internal_Std_Composition'

Done:
	
	If @myError <> 0
		Select @message AS ErrorMessage

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[AddNewInternalStandardUsingExisting] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddNewInternalStandardUsingExisting] TO [MTS_DB_Lite] AS [dbo]
GO

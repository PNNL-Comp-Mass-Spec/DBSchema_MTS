/****** Object:  StoredProcedure [dbo].[EnableDisableJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.EnableDisableJobs
/****************************************************
** 
**		Desc: 
**		Looks for Sql Server Agent jobs with category @CategoryName
**		and enables or disables them
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: mem
**		Date: 1/18/2005
**    
*****************************************************/
	@EnableJobs tinyint,										-- 0 to disable, 1 to enable
	@CategoryName varchar(255) = 'MTS Auto Update Continuous',
	@Preview tinyint = 0,										-- 1 to preview jobs that would be affected, 0 to actually make changes
	@message varchar(255) = '' OUTPUT
AS
	SET NOCOUNT ON

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set @message = ''
	
	--------------------------------------------
	-- Validate @EnableJobs
	--------------------------------------------
	Set @EnableJobs = IsNull(@EnableJobs, 1)
	If @EnableJobs <> 0 And @EnableJobs <> 1
		Set @EnableJobs = 1

	Declare @CategoryID int

	--------------------------------------------
	-- Look up the Category ID for @CategoryName
	--------------------------------------------
	Set @CategoryID = 0
	SELECT @CategoryID = Category_ID 
	FROM msdb.dbo.syscategories
	WHERE [Name] = @CategoryName
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @CategoryID = 0
	Begin
		Set @message = 'Category "' + @CategoryName + '" was not found in msdb.dbo.syscategories'
		Set @myError = 50000
	End
	Else
	Begin
		If @Preview = 1
		Begin
			SELECT S.[name], S.enabled, S.[description], C.[Name]
			FROM msdb.dbo.sysjobs AS S INNER JOIN msdb.dbo.syscategories AS C
				ON S.Category_ID = C.Category_ID
			WHERE S.Category_ID = @CategoryID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			Set @message = 'Found '
		End
		Else
		Begin
			--------------------------------------------
			-- Enable or disable the matching jobs
			--------------------------------------------
			UPDATE msdb.dbo.sysjobs
			SET Enabled = @EnableJobs
			WHERE Category_ID = @CategoryID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @EnableJobs = 0
				Set @message = 'Disabled '
			Else
				Set @message = 'Enabled '
		End

		Set @message = @message + Convert(Varchar(9), @myRowCount) + ' Jobs with category ' + @CategoryName
	End

	If @Preview <> 1
		SELECT @message AS Message
	
	RETURN @myError

GO
GRANT EXECUTE ON [dbo].[EnableDisableJobs] TO [DMS_SP_User]
GO

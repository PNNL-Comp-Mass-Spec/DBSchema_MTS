/****** Object:  StoredProcedure [dbo].[UpdateUserPermissionsViewDefinitions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateUserPermissionsViewDefinitions
/****************************************************
**
**	Desc: Grants view definition permission to all stored procedures for the specified users
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/04/2008
**    
*****************************************************/
(
	@UserList varchar(255) = 'MTS_DB_Dev, MTS_DB_Lite',
	@PreviewSql tinyint = 0,
	@message varchar(512)='' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set NoCount On
	
	Declare @Continue int
	Declare @Continue2 int
	
	Declare @S varchar(1024)
	Declare @UniqueID int
	Declare @LoginName varchar(255)
	
	Declare @SPName varchar(255)
	Declare @SPCount int
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		------------------------------------------------
		-- Validate the inputs
		------------------------------------------------
		
		Set @UserList = IsNull(@UserList, '')
		Set @PreviewSql = IsNull(@PreviewSql, 0)
		Set @message = ''
		
		------------------------------------------------
		-- Create a temporary table to hold the items in @UserList
		------------------------------------------------
		CREATE TABLE #TmpUsers (
			UniqueID int Identity(1,1),
			LoginName varchar(255)
		)
		
		Set @CurrentLocation = 'Parse @UserList'
		
		INSERT INTO #TmpUsers (LoginName)
		SELECT Value
		FROM dbo.udfParseDelimitedList(@UserList, ',')
		ORDER BY Value
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
		Begin
			Set @Message = '@UserList was empty; nothing to do'
			Goto Done
		End
		
		------------------------------------------------
		-- Process each user in #TmpUsers
		------------------------------------------------
		Set @CurrentLocation = 'Process each user in #TmpUsers'
		
		Set @UniqueID = 0
		
		Set @Continue = 1
		While @Continue = 1
		Begin -- <a>
		
			SELECT TOP 1 @UniqueID = UniqueID,
						 @LoginName = LoginName		   
			FROM #TmpUsers
			WHERE UniqueID > @UniqueID
			ORDER BY UniqueID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount = 0
				Set @Continue = 0
			Else
			Begin -- <b>
				------------------------------------------------
				-- Grant ShowPlan to user @LoginName
				------------------------------------------------
		
				Set @S = 'grant showplan to [' + @LoginName + ']'
				Set @CurrentLocation = @S

				If @PreviewSql <> 0
					Print @S
				Else
					Exec (@S)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @myError <> 0
				Begin
					Set @message = 'Error executing "' + @S + '"'
					Goto Done
				End
					
				------------------------------------------------
				-- Process each stored procedure in sys.procedures
				------------------------------------------------
				Set @CurrentLocation = 'Process each stored procedure in sys.procedures'
		
				Set @SPName = ''
				Set @SPCount = 0
				
				Set @Continue2 = 1
				While @Continue2 = 1
				Begin -- <c>
					SELECT TOP 1 @SPName = Name
					FROM sys.procedures
					WHERE Name > @SPName
					ORDER BY Name
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount

					If @myRowCount = 0
						Set @Continue2 = 0
					Else
					Begin -- <d>
						Set @S = 'grant view definition on [' + @SPName + '] to [' + @LoginName + ']'
						Set @CurrentLocation = @S

						If @PreviewSql <> 0
							Print @S
						Else
							Exec (@S)
											
						Set @SPCount = @SPCount + 1
						
					End -- </d>				
				End -- </c>
			
				If @message <> ''
					Set @message = @message + '; '
					
				Set @message = @message + 'Updated ' + Convert(varchar(12), @SPCount) + ' procedures for [' + @LoginName + ']'
				
			End -- </b>
		End -- </a>

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateUserPermissionsViewDefinitions')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

Done:

	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateUserPermissionsViewDefinitions] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateUserPermissionsViewDefinitions] TO [MTS_DB_Lite] AS [dbo]
GO

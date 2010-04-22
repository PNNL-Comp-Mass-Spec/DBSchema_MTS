/****** Object:  StoredProcedure [dbo].[UpdateUserPermissionsViewDefinitions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateUserPermissionsViewDefinitions
/****************************************************
**
**	Desc: Grants view definition permission to all stored procedures and views for the specified users
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/04/2008
**			12/28/2009 mem - Updated to also update views (and to include parameters @UpdateSPs and @UpdateViews)
**    
*****************************************************/
(
	@UserList varchar(255) = 'MTS_DB_Dev, MTS_DB_Lite',
	@UpdateSPs tinyint = 1,
	@UpdateViews tinyint = 1,
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
	
	Declare @ObjectName varchar(255)
	Declare @ObjectUpdateCount int
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		------------------------------------------------
		-- Validate the inputs
		------------------------------------------------
		
		Set @UserList = IsNull(@UserList, '')
		Set @UpdateSPs = IsNull(@UpdateSPs, 1)
		Set @UpdateViews = IsNull(@UpdateViews, 1)		
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
				
				If @UpdateSPs <> 0
				Begin -- <c1>
					------------------------------------------------
					-- Process each stored procedure in sys.procedures
					------------------------------------------------
					Set @CurrentLocation = 'Process each stored procedure in sys.procedures'
			
					Set @ObjectName = ''
					Set @ObjectUpdateCount = 0
					
					Set @Continue2 = 1
					While @Continue2 = 1
					Begin -- <d1>
						SELECT TOP 1 @ObjectName = Name
						FROM sys.procedures
						WHERE Name > @ObjectName AND Type = 'P'
						ORDER BY Name
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount

						If @myRowCount = 0
							Set @Continue2 = 0
						Else
						Begin -- <e1>
							Set @S = 'grant view definition on [' + @ObjectName + '] to [' + @LoginName + ']'
							Set @CurrentLocation = @S

							If @PreviewSql <> 0
								Print @S
							Else
								Exec (@S)
												
							Set @ObjectUpdateCount = @ObjectUpdateCount + 1
							
						End -- </e1>				
					End -- </d1>
				
					If @message <> ''
						Set @message = @message + '; '
						
					Set @message = @message + 'Updated ' + Convert(varchar(12), @ObjectUpdateCount) + ' procedures for [' + @LoginName + ']'
				End -- </c1>
				
				If @UpdateSPs <> 0
				Begin -- <c2>
					------------------------------------------------
					-- Process each view in sys.views
					------------------------------------------------
					Set @CurrentLocation = 'Process each view in sys.views'
			
					Set @ObjectName = ''
					Set @ObjectUpdateCount = 0
					
					Set @Continue2 = 1
					While @Continue2 = 1
					Begin -- <d2>
						SELECT TOP 1 @ObjectName = Name
						FROM sys.views
						WHERE Name > @ObjectName
						ORDER BY Name
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount

						If @myRowCount = 0
							Set @Continue2 = 0
						Else
						Begin -- <e2>
							Set @S = 'grant view definition on [' + @ObjectName + '] to [' + @LoginName + ']'
							Set @CurrentLocation = @S

							If @PreviewSql <> 0
								Print @S
							Else
								Exec (@S)
												
							Set @ObjectUpdateCount = @ObjectUpdateCount + 1
							
						End -- </e2>				
					End -- </d2>
				
					If @message <> ''
						Set @message = @message + '; '
						
					Set @message = @message + 'Updated ' + Convert(varchar(12), @ObjectUpdateCount) + ' views for [' + @LoginName + ']'
				End -- </c2>

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

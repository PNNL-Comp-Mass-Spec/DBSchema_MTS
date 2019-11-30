/****** Object:  StoredProcedure [dbo].[UpdateCachedAnalysisTasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.UpdateCachedAnalysisTasks 
/****************************************************
**
**	Desc:	Updates T_Analysis_Task_Candidate_DBs with stats on the 
**			analysis tasks available for VIPER and MultiAlign 
**
**	Auth:	mem
**	Date:	12/21/2007
**
*****************************************************/
(
	@ServerNameFilter varchar(128) = '',	-- If defined, then only examines databases on this server
	@DBNameFilter varchar(128)= '',			-- If defined, then only examines this database (must also provide @ServerNameFilter)
	@ToolIDFilter int = 0,					-- If defined, then only updates this tool
	@ForceUpdate tinyint = 0,
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @ToolID int
	Declare @Continue tinyint
	Declare @UpdateCache tinyint
	
	Declare @NewState int
	
	Declare @ToolActive int
	Declare @CacheUpdateState int
	Declare @CacheUpdateStart DateTime
	Declare @CacheUpdateFinish DateTime
	Declare @MinutesSinceLastUpdate int
	
	Declare @StatusMessage varchar(4000)
	Set @StatusMessage = ''
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		Set @CurrentLocation = 'Validate input parameters'
		
		Set @ServerNameFilter = LTrim(RTrim(IsNull(@ServerNameFilter, '')))
		Set @DBNameFilter = LTrim(RTrim(IsNull(@DBNameFilter, '')))
		Set @ToolIDFilter = IsNull(@ToolIDFilter, 0)
		Set @ForceUpdate = IsNull(@ForceUpdate, 0)
		
		Set @message = ''
		
		If Len(@DBNameFilter) > 0 AND @ServerNameFilter = ''
		Begin
			Set @message = 'You must supply the server name (@ServerNameFilter) when specifying the database name using @DBNameFilter'
			Set @myError = 50000
			Goto Done
		End

		---------------------------------------------------
		-- Look for analysis tools that need to have their cached tasks updated
		---------------------------------------------------
		
		Set @CurrentLocation = 'Loop through analysis tools'
		
		Set @ToolID = 0
		Set @Continue = 1
		
		While @Continue = 1
		Begin -- <a>
			If @ToolIDFilter = 0
			Begin
				-- Lookup the next Tool_ID in T_Analysis_Tool
				
				SELECT TOP 1 @ToolID = Tool_ID,
							 @CacheUpdateState = Cache_Update_State, 
							 @CacheUpdateStart = Cache_Update_Start
				FROM T_Analysis_Tool
				WHERE Tool_ID > @ToolID AND Tool_Active <> 0
				ORDER BY Tool_ID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @myRowCount = 0
					Set @Continue = 0
			End
			Else
			Begin
				SELECT TOP 1 @ToolID = Tool_ID,
							 @ToolActive = Tool_Active, 
							 @CacheUpdateState = Cache_Update_State, 
							 @CacheUpdateStart = Cache_Update_Start
				FROM T_Analysis_Tool
				WHERE Tool_ID = @ToolIDFilter
				ORDER BY Tool_ID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @myRowCount = 0
				Begin
					Set @message = 'Tool ID ' + Convert(varchar(12), @ToolIDFilter) + ' not found in T_Analysis_Tool; unable to continue'
					Set @myError = 50001
					Goto Done
				End
				
				If @ToolActive = 0
				Begin
					Set @message = 'Tool ID ' + Convert(varchar(12), @ToolIDFilter) + ' is not active; unable to continue'
					Set @myError = 50002
					Goto Done
				End
			End
			
			If @Continue = 1
			Begin -- <b>
				Set @CurrentLocation = 'Examine @CacheUpdateState and @CacheUpdateStart'
				
				-- Check for impossible values in @CacheUpdateStart
				--  If the date is more than 0.5 days from now, then bump it back to 1 day before the present
				If @CacheUpdateStart > GetDate() + 0.5
				Begin
					Set @Message = 'Encountered an impossible cache update start time for Tool ID ' + Convert(varchar(12), @ToolID) + '; the time will be ignored'
					Exec PostLogEntry 'Error', @Message, 'UpdateCachedAnalysisTasks', 6
					Set @Message = ''

					Set @CacheUpdateStart = GetDate() - 1
				End
				
				Set @UpdateCache = 1
				
				If @CacheUpdateState = 2
				Begin -- <c1>
					-- Cache Update is in progress
					If DateDiff(minute, @CacheUpdateStart, GetDate()) > 10
					Begin
						-- Update is indicated to be in progress, but it started more than 10 minutes ago; reset to state 1
						UPDATE T_Analysis_Tool
						SET Cache_Update_State = 1
						WHERE Tool_ID = @ToolID AND 
							  Cache_Update_State = 2
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount

						If @myRowCount > 0
						Begin
							Set @Message = 'Update of cached analysis tasks for Tool ID ' + Convert(varchar(12), @ToolID) + ' appears stuck (update started at ' + Convert(varchar(64), @CacheUpdateStart) + '); resetting update state to 1'
							Exec PostLogEntry 'Error', @Message, 'UpdateCachedAnalysisTasks'
							Set @Message = ''
						End
					End
					Else
						Set @UpdateCache = 0
				End -- </c1>
				
				If @CacheUpdateState = 3
				Begin
					Set @MinutesSinceLastUpdate = DateDiff(minute, @CacheUpdateStart, GetDate())
					
					If IsNull(@MinutesSinceLastUpdate, 100) < 5 And @ForceUpdate = 0
					Begin
						-- Cache updated less than 5 minutes ago; do not repeat unless @ForceUpdate <> 1
						If Len(@StatusMessage) > 0
							Set @StatusMessage = @StatusMessage + '; '
						Set @StatusMessage = @StatusMessage + 'Skipped update for Tool ID ' + Convert(varchar(12), @ToolID) + ' since last updated ' + Convert(varchar(12), @MinutesSinceLastUpdate) + ' minute(s) ago'
						
						Set @UpdateCache = 0
					End
				End
				
				If @UpdateCache = 1
				Begin -- <c2>
					-- Cache update required
					Set @CurrentLocation = 'Update cached tasks for Tool ID ' + Convert(varchar(12), @ToolID)
					
					UPDATE T_Analysis_Tool
					SET Cache_Update_State = 2,
						Cache_Update_Start = GetDate(),
						Cache_Update_Finish = Null
					WHERE Tool_ID = @ToolID AND 
						  Cache_Update_State <> 2
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					If @myRowCount = 0
					Begin
						-- Another process must have already changed the Cache Update State to 2; do not continue
						Set @UpdateCache = 0
					End
					Else
					Begin -- <d>
						-- We can finally now update the cached tasks for this Tool
						Exec @myError = UpdateCachedAnalysisTasksOneTool @ToolID, @ServerNameFilter, @DBNameFilter

						If Len(@StatusMessage) > 0
							Set @StatusMessage = @StatusMessage + '; '
												
						If @myError = 0
						Begin
							Set @StatusMessage = @StatusMessage + 'Update succeeded'
							Set @NewState = 3
						End
						Else
						Begin
							Set @StatusMessage = @StatusMessage + 'Update failed'
							Set @NewState = 4
						End
						
						Set @StatusMessage = @StatusMessage + ' for Tool ID ' + Convert(varchar(12), @ToolID)
						
							
						UPDATE T_Analysis_Tool
						SET Cache_Update_State = @NewState,
							Cache_Update_Finish = GetDate()
						WHERE Tool_ID = @ToolID AND 
							  Cache_Update_State = 2
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
					
					End -- </d>
						
				End -- </c2>
				

				-- Set @Continue to 0 if a ToolID Filter was defined
				If @ToolIDFilter <> 0
					Set @Continue = 0

			End -- </b>
		End  -- </a>

		Set @message = @StatusMessage
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateCachedAnalysisTasks')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[UpdateCachedAnalysisTasks] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateCachedAnalysisTasks] TO [MTS_DB_Lite] AS [dbo]
GO

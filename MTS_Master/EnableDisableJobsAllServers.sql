/****** Object:  StoredProcedure [dbo].[EnableDisableJobsAllServers] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.EnableDisableJobsAllServers
/****************************************************
** 
**	Desc: Call EnableDisableJobs on each server listed in T_MTS_Servers
**
**	Return values: 0: success, otherwise, error code
** 
** 
**	Auth:	mem
**	Date:	01/18/2005
**			11/14/2006 mem - Removed Prismdev from @AdditionalServers
**			05/10/2007 mem - Added parameter @UpdateTProcessStepControl
**						   - Added ProteinSeqs to @AdditionalServers
**			11/15/2007 mem - Updated @CategoryName to allow comma separated lists
**						   - Added @EnableTProcessStepControlEvenIfZero
**			03/13/2008 mem - Added parameter @ExecutionStateNewOverride
**			11/12/2009 mem - Now setting Execution_State in T_Process_Control to 0 or 1 instead of to 3 or 1
**    
*****************************************************/
(
	@EnableJobs tinyint,										-- 0 to disable, 1 to enable
	@CategoryName varchar(1024) = 'MTS Auto Update Continuous, DMS Continuous, Database Maintenance',		-- Can be comma-separated list
	@Preview tinyint = 0,										-- 1 to preview jobs that would be affected, 0 to actually make changes
	@AdditionalServers varchar(512) = '',			-- Additional servers to poll besides those in T_MTS_Servers
	@SPName varchar(128) = 'MT_Main.dbo.EnableDisableJobs',
	@UpdateTProcessStepControl tinyint = 1,						-- If 1, then will change Execution_State in MT_Main.T_Process_Control from 1 to 0 or from 0 to 1, depending on @EnableJobs
	@EnableTProcessStepControlEvenIfZero tinyint = 1,			-- Set to 1 to force MT_Main.T_Process_Control to set the values to 1, even if they are 0; only used when @EnableJobs = 1 and @UpdateTProcessStepControl = 1
	@ExecutionStateNewOverride int = -1,						-- If 0 or higher, then this value is used for the new Execution_State for table T_Process_Step_Control; if negative, then the default value is used (1 if enabling, 3 if disabling)
	@message varchar(255) = '' OUTPUT
)
AS
	SET NOCOUNT ON

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set @message = ''
	
	Declare @S nvarchar(2048)
	Declare @ServerID int
	Declare @ServerName varchar(128)
	Declare @Continue tinyint
	
	Declare @CommaLoc int

	Declare @ExecutionStateMatch smallint
	Declare @ExecutionStateMatchB smallint
	Declare @ExecutionStateNew smallint

	-------------------------------------------------
	-- Validate the Inputs
	-------------------------------------------------
	--
	Set @EnableJobs = IsNull(@EnableJobs, 0)
	Set @CategoryName = IsNull(@CategoryName, 'Category Undefined')
	Set @Preview = IsNull(@Preview, 0)
	Set @AdditionalServers = IsNull(@AdditionalServers, '')
	Set @SPName = LTrim(RTrim(IsNull(@SPName, '')))
	Set @UpdateTProcessStepControl = IsNull(@UpdateTProcessStepControl, 1)
	Set @EnableTProcessStepControlEvenIfZero = IsNull(@EnableTProcessStepControlEvenIfZero, 0)
	Set @ExecutionStateNewOverride = IsNull(@ExecutionStateNewOverride, -1)
	
	If Len(@SPName) = 0
	Begin
		Set @message = 'Error, @SPName is blank'
		Set @myError = 50000
		Goto Done
	End
	
	-- Assure that @preview is 0 or 1
	If @preview <> 0
		Set @preview = 1
		
	-- Assure that @EnableJobs is 0 or 1
	If @EnableJobs <> 0
		Set @EnableJobs = 1
	
	If @EnableJobs = 0
	Begin
		Set @ExecutionStateMatch = 1
		Set @ExecutionStateMatchB = 3
		If @ExecutionStateNewOverride < 0
			Set @ExecutionStateNew = 0
		Else
			Set @ExecutionStateNew = @ExecutionStateNewOverride
	End
	Else
	Begin
		Set @ExecutionStateMatch = 0
		Set @ExecutionStateMatchB = 3
		If @ExecutionStateNewOverride < 0
			Set @ExecutionStateNew = 1
		Else
			Set @ExecutionStateNew = @ExecutionStateNewOverride
	End
	
	-------------------------------------------------
	-- Process each server in T_MTS_Servers, plus
	-- optionally @AdditionalServers
	-------------------------------------------------
	
	Set @ServerID = -1
	
	Set @Continue = 1
	While @Continue > 0
	Begin
		Set @ServerName = ''
		
		SELECT TOP 1 @ServerID = Server_ID, @ServerName = Server_Name
		FROM T_MTS_Servers
		WHERE Server_ID > @ServerID AND Active = 1
		ORDER BY Server_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
		Begin
			-------------------------------------------------
			--See if any servers are listed in @AdditionalServers
			-------------------------------------------------
			Set @CommaLoc = CharIndex(',', @AdditionalServers)
			Set @ServerName = ''
			
			If @CommaLoc > 0
			 Begin
				Set @ServerName = LTrim(RTrim(SubString(@AdditionalServers, 1, @CommaLoc-1)))
				Set @AdditionalServers = LTrim(RTrim(SubString(@AdditionalServers, @CommaLoc+1, Len(@AdditionalServers) - @CommaLoc)))
			 End
			Else
			 Begin
				Set @ServerName = LTrim(RTrim(@AdditionalServers))
				Set @AdditionalServers = ''
			 End
				
			If Len(@ServerName) > 0
				Set @myRowCount = 1
		End
		
		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin

			If @UpdateTProcessStepControl <> 0
			Begin
				------------------------------------------------
				-- Process MT_Main.dbo.T_Process_Step_Control on the given server
				-------------------------------------------------
				
				If @Preview = 1
				Begin
					Set @S = ''
					Set @S = @S + ' SELECT  Processing_Step_Name, '
					Set @S = @S +      ' Convert(varchar(12), Execution_State) + '' --> '' +' 
					If (@ExecutionStateNewOverride >= 0) OR 
					   (@ExecutionStateNew = 0) OR 
					   (@ExecutionStateNew = 1 And @EnableTProcessStepControlEvenIfZero = 1)
						Set @S = @S +      ' CASE WHEN Execution_State <> ' + Convert(varchar(12), @ExecutionStateNew)
					Else
						Set @S = @S +      ' CASE WHEN Execution_State = ' + Convert(varchar(12), @ExecutionStateMatch) + ' OR Execution_State = ' + Convert(varchar(12), @ExecutionStateMatchB)

					Set @S = @S +      ' THEN  Convert(varchar(12), ' + Convert(varchar(12), @ExecutionStateNew) + ')'
					Set @S = @S +      ' ELSE ''No Change'''

					Set @S = @S +      ' End AS Execution_State,'
					Set @S = @S +      ' Last_Query_Date, Last_Query_Description'
					Set @S = @S + ' FROM ' + @ServerName + '.MT_Main.dbo.T_Process_Step_Control'
					Set @S = @S + ' ORDER BY Processing_Step_Name'
					
					Exec sp_executeSql @S
				End
				Else
				Begin
					Set @S = ''
					Set @S = @S + ' UPDATE ' + @ServerName + '.MT_Main.dbo.T_Process_Step_Control'
					Set @S = @S + ' Set Execution_State = ' + Convert(varchar(12), @ExecutionStateNew)

					If (@ExecutionStateNewOverride >= 0) OR 
					   (@ExecutionStateNew = 0) OR 
					   (@ExecutionStateNew = 1 And @EnableTProcessStepControlEvenIfZero = 1)
						Set @S = @S + ' WHERE Execution_State <> ' + Convert(varchar(12), @ExecutionStateNew)
					Else
						Set @S = @S + ' WHERE Execution_State = ' + Convert(varchar(12), @ExecutionStateMatch) + ' OR Execution_State = ' + Convert(varchar(12), @ExecutionStateMatchB)
										
					Exec sp_executeSql @S
				End
			End
			
			-------------------------------------------------
			-- Call @SPName on the given server
			-------------------------------------------------
			
			Set @S = ''
			Set @S = @S + 'Exec ' + @ServerName + '.' + @SPName + ' '
			Set @S = @S + '@EnableJobs = ' + Convert(varchar(9), @EnableJobs) + ', '
			Set @S = @S + '@CategoryName = ''' + @CategoryName + ''', '
			Set @S = @S + '@Preview = ' + Convert(varchar(9), @Preview)
			
			Exec sp_executeSql @S
	
			If Len(@message) = 0
				Set @message = 'Called SP on '
			Else
				Set @message = @message + ', '
			Set @message = @message + @ServerName	
			
		End
	End

Done:
	Select @Message as Message
GO
GRANT VIEW DEFINITION ON [dbo].[EnableDisableJobsAllServers] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EnableDisableJobsAllServers] TO [MTS_DB_Lite] AS [dbo]
GO

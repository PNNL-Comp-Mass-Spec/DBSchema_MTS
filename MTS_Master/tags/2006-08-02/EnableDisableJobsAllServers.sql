SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[EnableDisableJobsAllServers]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[EnableDisableJobsAllServers]
GO

CREATE PROCEDURE dbo.EnableDisableJobsAllServers
/****************************************************
** 
**		Desc: 
**		Call EnableDisableJobs on each server listed in T_MTS_Servers
**		Additionally, calls SP on PrismDev
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
	@AdditionalServers varchar(512) = 'PrismDev',				-- Additional servers to poll besides those in T_MTS_Servers
	@SPName varchar(128) = 'MT_Main.dbo.EnableDisableJobs',
	@message varchar(255) = '' OUTPUT
AS
	SET NOCOUNT ON

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set @message = ''

	Set @AdditionalServers = IsNull(@AdditionalServers, '')
	
	Declare @S nvarchar(2048)
	Declare @ServerID int
	Declare @ServerName varchar(128)
	Declare @Continue tinyint
	
	Declare @CommaLoc int
	
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
			--See if any servers are listed in @AdditionalServers
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
		
	Select @Message as Message
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


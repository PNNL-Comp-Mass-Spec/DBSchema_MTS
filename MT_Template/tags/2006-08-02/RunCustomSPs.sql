SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RunCustomSPs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RunCustomSPs]
GO


CREATE Procedure dbo.RunCustomSPs
/****************************************************
** 
**		Desc: 
**		Runs custom stored procedures defined in T_Process_Config
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters: see below
**		
**		Outputs: @message - description of error, or '' if no error
** 
**		Auth: mem
**		Date: 3/14/2005
**    
*****************************************************/
	@logLevel tinyint = 1,
	@message varchar(255) = '' output,
	@CustomSPConfigName varchar(50) = 'Custom_SP_MSMS'
AS
	SET NOCOUNT ON

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	
	declare @continue int
	declare @ProcessConfigID int
	declare @SPName varchar(64)
	declare @Sql nvarchar(256)
	
	set @continue = 1
	set @ProcessConfigID = -1
	
	
	While @continue = 1
	Begin
		Set @SPName = ''
		
		SELECT TOP 1 @SPName = Value, @ProcessConfigID = Process_Config_ID
		FROM T_Process_Config
		WHERE [Name] = @CustomSPConfigName AND
			  Process_Config_ID > @ProcessConfigID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			set @message = 'Error retrieving next entry from T_Process_Config with Name = ' + @CustomSPConfigName
			set @myError = 50000
			goto Done
		End

		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin
			-- Validate that @SPName exists
			Set @myRowCount = 0
			SELECT @myRowCount = COUNT(*)
			FROM sysObjects
			WHERE [Name] = IsNull(@SPName, '')
			
			If @myRowCount = 0
			Begin
				set @message = 'Custom stored procedure not found: ' + @SPName
				set @myError = 50001
				goto Done
			End
			Else
			Begin
				Set @myError = 0
				Set @Sql = @SPName
				exec @myError = sp_executesql @Sql
				
				If @myError <> 0
				Begin
					set @message = 'Error calling stored procedure: ' + @SPName
					set @myError = 50002
					goto Done
				End
			End
		End	
	End
	
--------------------------------------------------
-- Exit
---------------------------------------------------
Done:

	RETURN @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


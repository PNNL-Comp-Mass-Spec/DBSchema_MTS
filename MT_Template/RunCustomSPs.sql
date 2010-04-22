/****** Object:  StoredProcedure [dbo].[RunCustomSPs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.RunCustomSPs
/****************************************************
** 
**	Desc: Runs custom stored procedures defined in T_Process_Config
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters: see below
**		
**	Outputs: @message - description of error, or '' if no error
** 
**	Auth:	mem
**	Date:	03/14/2005 mem
**			10/22/2007 mem - Added parameter @InfoOnly and added support for parameters being defined in T_Process_Config after the custom SP name
**    
*****************************************************/
	@logLevel tinyint = 1,
	@message varchar(255) = '' output,
	@CustomSPConfigName varchar(50) = 'Custom_SP_MSMS',
	@InfoOnly tinyint = 0
AS
	SET NOCOUNT ON

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	
	declare @continue int
	declare @ProcessConfigID int
	declare @SPName varchar(256)
	declare @Sql nvarchar(1024)
	
	declare @CommaLoc int
	Declare @Params varchar(256)
	Set @Params = ''
	
	set @continue = 1
	set @ProcessConfigID = -1

	While @continue = 1
	Begin -- <a>
		Set @SPName = ''
		
		SELECT TOP 1 @SPName = Value, @ProcessConfigID = Process_Config_ID
		FROM T_Process_Config
		WHERE [Name] = @CustomSPConfigName AND
			  Process_Config_ID > @ProcessConfigID
		ORDER BY Process_Config_ID
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
		Begin -- <b>
			-- If @SPName contains a comma, then split out the values after the comma
			
			Set @CommaLoc = CharIndex(',', @SPName)
			
			If @CommaLoc > 0
			Begin
				Set @Params = SubString(@SPName, @CommaLoc+1, Len(@SPName))
				Set @SPName = SubString(@SPName, 1, @CommaLoc-1)			
			End
			
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
			Begin -- <c>
				Set @myError = 0
				Set @Sql = @SPName
				
				If Len(@Params) > 0
					Set @Sql = @Sql + ' ' + @Params
				
				If @InfoOnly <> 0
					print 'Exec ' + @Sql
				Else
					exec @myError = sp_executesql @Sql
				
				If @myError <> 0
				Begin
					set @message = 'Error calling stored procedure: ' + @SPName
					set @myError = 50002
					goto Done
				End
			End -- </c>
		End	 -- </b>
	End -- </a>
	
--------------------------------------------------
-- Exit
---------------------------------------------------
Done:

	RETURN @myError


GO
GRANT VIEW DEFINITION ON [dbo].[RunCustomSPs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RunCustomSPs] TO [MTS_DB_Lite] AS [dbo]
GO

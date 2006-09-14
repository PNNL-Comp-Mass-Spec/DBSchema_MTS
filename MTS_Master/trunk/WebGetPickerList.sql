/****** Object:  StoredProcedure [dbo].[WebGetPickerList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.WebGetPickerList
/****************************************************
**
**	Desc:	Returns list of MT or PT databases, or list
**			of MTS servers
**
**	Auth:	grk
**	Date:	12/9/2004
**			09/01/2006 mem - Added mode 'MTSServerList' for @PickerName
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',					-- Ignored by this SP
	@PickerName varchar(128) = 'MTDBNameList',		-- Can be 'MTDBNameList', 'PTDBNameList', or 'MTSServerList'
	@pepIdentMethod varchar(32) = '',				-- Ignored by this SP
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- Examine @PickerName and call the appropriate SP to return the desired list
	---------------------------------------------------

	if @PickerName = 'MTDBNameList'
	begin
		exec @myError = GetAllMassTagDatabases 
					0,			-- Set to 1 to include unused databases
					0,			-- Set to 1 to include deleted databases
					'',			-- Server filter
					@message output,
					@VerboseColumnOutput=0
		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'PTDBNameList'
	begin
		exec @myError = GetAllPeptideDatabases 
					0,			-- Set to 1 to include unused databases
					0,			-- Set to 1 to include deleted databases
					'',			-- Server filter
					@message output,
					@VerboseColumnOutput=0
		--
		goto Done
	end

	if @PickerName = 'MTSServerList'
	begin
		SELECT *
		FROM V_Active_MTS_Servers
		ORDER BY Server_Name
	end
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[WebGetPickerList] TO [DMS_SP_User]
GO
GRANT EXECUTE ON [dbo].[WebGetPickerList] TO [MTUser]
GO
GRANT EXECUTE ON [dbo].[WebGetPickerList] TO [public]
GO

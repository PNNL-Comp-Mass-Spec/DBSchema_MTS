/****** Object:  StoredProcedure [dbo].[WebGetPickerList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.WebGetPickerList
/****************************************************
**
**	Desc: 
**  
**    
**		Auth:	grk
**		Date:	12/9/2004
**    
*****************************************************/
	@MTDBName varchar(128) = '',
	@PickerName varchar(128) = 'MTDBNameList',
	@pepIdentMethod varchar(32) = '',
	@message varchar(512) = '' output
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'MTDBNameList'
	begin
--		exec @result = GetAllMassTagDatabases
--					@message  output,
--					0,			-- Set to 1 to include unused databases
--					0			-- Set to 1 to include deleted databases
		exec @myError = GetAllMassTagDatabases 
					0, 
					0, 
					'', 
					@message output

		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'PTDBNameList'
	begin
--		exec @result = MTS_Master.dbo.GetAllPeptideDatabases
--					@message  output,
--					0,			-- Set to 1 to include unused databases
--					0			-- Set to 1 to include deleted databases
		exec @myError = GetAllPeptideDatabases 
					0, 
					0, 
					'', 
					@message output
		--
		goto Done
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

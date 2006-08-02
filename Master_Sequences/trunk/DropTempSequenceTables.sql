SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DropTempSequenceTables]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[DropTempSequenceTables]
GO

CREATE PROCEDURE dbo.DropTempSequenceTables
/****************************************************
** 
**	Desc:	Drops the tables given by @TempTable1 and @TempTable2
**			These tables would have originally been created using CreateTempSequenceTables
**
**	Auth:	mem
**	Date:	02/10/2005
**			01/15/2006 mem - Renamed input parameters to generic names
**			05/13/2006 mem - Added ability to only delete one table since deletion will be skipped if @TempTable1 or @TempTable2 are blank
**    
*****************************************************/
(
	@TempTable1 varchar(256)='',
	@TempTable2 varchar(256)='',
	@message varchar(256) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @Sql varchar(1024)

	-----------------------------------------------------------
	-- Check for null table names
	-----------------------------------------------------------
	Set @TempTable1 = IsNull(@TempTable1, '')
	Set @TempTable2 = IsNull(@TempTable2, '')
	
	-----------------------------------------------------------
	-- Drop table 1
	-----------------------------------------------------------
	--
	If Len(@TempTable1) > 0
	Begin
		-- Possibly add square brackets
		If CharIndex('[', @TempTable1) <= 0
			Set @TempTable1 = '[' + @TempTable1 + ']'

		set @Sql = ' DROP TABLE ' + @TempTable1
		--
		Exec (@Sql)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Problem dropping temporary table ' + @TempTable1
			goto Done
		end
	End

	-----------------------------------------------------------
	-- Drop table 2
	-----------------------------------------------------------
	--
	If Len(@TempTable2) > 0
	Begin
		-- Possibly add square brackets
		If CharIndex('[', @TempTable2) <= 0
			Set @TempTable2 = '[' + @TempTable2 + ']'

		set @Sql = ' DROP TABLE ' + @TempTable2
		--
		Exec (@Sql)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Problem dropping temporary table ' + @TempTable2
			goto Done
		end
	End

Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[DropTempSequenceTables]  TO [DMS_SP_User]
GO


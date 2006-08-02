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
**		Desc:  
**        Drops the tables given by @PeptideSequencesTableName and @UniqueSequencesTableName
**		  These tables would have originally been created using CreateTempSequenceTables
**
**		Auth:	mem
**		Date:	02/10/2005
**    
*****************************************************/
	@PeptideSequencesTableName varchar(256)='' output,
	@UniqueSequencesTableName varchar(256)='' output,
	@message varchar(256) = '' output
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	declare @GUID varchar(64)
	declare @Sql varchar(1024)

	-----------------------------------------------------------
	-- Possibly add square brackets
	-----------------------------------------------------------
	--
	If CharIndex('[', @PeptideSequencesTableName) <= 0
		Set @PeptideSequencesTableName = '[' + @PeptideSequencesTableName + ']'

	If CharIndex('[', @UniqueSequencesTableName) <= 0
		Set @UniqueSequencesTableName = '[' + @UniqueSequencesTableName + ']'


	-----------------------------------------------------------
	-- Drop the tables
	-----------------------------------------------------------
	--
	set @Sql = ' DROP TABLE ' + @PeptideSequencesTableName
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem dropping temporary table ' + @PeptideSequencesTableName
		goto Done
	end

	set @Sql = ' DROP TABLE ' + @UniqueSequencesTableName
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem dropping temporary table ' + @PeptideSequencesTableName
		goto Done
	end



Done:
	return @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[DropTempSequenceTables]  TO [DMS_SP_User]
GO


/****** Object:  StoredProcedure [dbo].[MakeProvisionalPeptideDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.MakeProvisionalPeptideDB
/****************************************************
**
**	Desc: Creates a provisional entry for a 
**  new peptide database and returns the name and ID
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth:	grk
**		Date:	11/12/2004 
**				12/17/2004 mem - Added validation of @newDBNameRoot
**    
*****************************************************/
	@serverName varchar(64),				-- e.g. albert
	@newDBNameRoot varchar(64),				-- e.g. Deinococcus
	@newDBNameType char(1) = 'Q',			-- e.g. A or X or Q
	@newDBName varchar(128) = '' output,
	@newDBID int output,
	@message varchar(512) = '' output
AS
	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	set @newDBName = ''
	
	
	declare @result int
	declare @hit int

	---------------------------------------------------
	-- Resolve server name to ID
	---------------------------------------------------

	declare @serverID int
	set @serverID = 0
	--
	SELECT @serverID = Server_ID
	FROM T_MTS_Servers
	WHERE (Server_Name = @serverName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to resolve server name to ID'
		goto done
	end
	if  @serverID = 0
	begin
		set @myError = 11
		set @message = 'Could not find server name'
		goto done
	end

	---------------------------------------------------
	-- Validate @newDBNameRoot
	---------------------------------------------------
	Set @newDBNameRoot = LTrim(RTrim(IsNull(@newDBNameRoot, '')))
	If Len(@newDBNameRoot) = 0
	begin
		set @myError = 12
		set @message = 'Empty @newDBNameRoot parameter is not allowed'
		goto done
	end

	---------------------------------------------------
	-- Begin a transaction
	---------------------------------------------------

	declare @Trans varchar(50)
	set @Trans = 'NextDBIdTrans'
	
	Begin Tran @Trans
	
	---------------------------------------------------
	-- Get sequence number for name for new database
	---------------------------------------------------
	declare @seqNum int
	set @seqNum = 0
	--
	SELECT     TOP 1 @newDBID = Peptide_DB_ID + 1, @seqNum = Peptide_DB_ID - 998
	FROM         T_MTS_Peptide_DBs WITH (HOLDLOCK)
	ORDER BY Peptide_DB_ID DESC
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not get new seqence number'
		Rollback Tran @Trans
		goto done
	end

	---------------------------------------------------
	-- Construct name for new database
	---------------------------------------------------
	
	set @newDBName = 'PT_' + @newDBNameRoot + '_' + @newDBNameType + cast(@seqNum as varchar(12))

	---------------------------------------------------
	-- Create provisional entry in Peptide database list
	---------------------------------------------------
		
	INSERT INTO T_MTS_Peptide_DBs (
		Peptide_DB_ID, 
		Peptide_DB_Name, 
		Server_ID, 
		State_ID
	)
	VALUES (
		@newDBID,
		@newDBName,
		@serverID, 
		101
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not add new record to Peptide DB list'
		Rollback Tran @Trans
		goto done
	end

	---------------------------------------------------
	-- Commit the transaction
	---------------------------------------------------

	Commit Tran @Trans
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[MakeProvisionalPeptideDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[MakeProvisionalPeptideDB] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[MakeProvisionalPeptideDB] TO [MTUser] AS [dbo]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetInstrumentNamesForDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetInstrumentNamesForDB]
GO

CREATE PROCEDURE dbo.GetInstrumentNamesForDB
/****************************************************
**
**	Desc: 
**	Returns list of instruments corresponding to the analysis jobs
**  in the given datasbase (Peptide or MTDB).  For MTDBs, returns the
**  instruments for both match methods.  To limit to one method type, set
**  @pepIdentMethod to DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- Peptide or PMT Tag database name
**	  @message				-- Status/error message output
**	  @pepIdentMethod		-- Can be DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR) ; Alternatively, set to '' to return instruments for both match methods
**
**		Auth: mem
**		Date: 07/15/2005
**			  11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**
*****************************************************/
	@DBName varchar(128) = '',
	@message varchar(512) = '' output,
	@pepIdentMethod varchar(32) = ''
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	
	---------------------------------------------------
	-- Validate that DB exists on this server, determine its type,
	-- and look up its schema version
	---------------------------------------------------

	Declare @DBType tinyint				-- 1 if PMT Tag DB, 2 if Peptide DB
	Declare @DBSchemaVersion real
	
	Set @DBType = 0
	Set @DBSchemaVersion = 1
	
	Exec @myError = GetDBTypeAndSchemaVersion @DBName, @DBType OUTPUT, @DBSchemaVersion OUTPUT, @message = @message OUTPUT

	-- Make sure the type is 1 or 2
	If @DBType = 0 Or @myError <> 0
	Begin
		If @myError = 0
			Set @myError = 20000

		If Len(@message) = 0
			Set @message = 'Database not found on this server: ' + @DBName
		Goto Done
	End
	Else
	If @DBType <> 1 AND @DBType <> 2
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a Peptide DB or a PMT Tag DB and is therefore not appropriate for this procedure'
		Goto Done
	End
	Else
	If @DBSchemaVersion <= 1
	Begin
		Set @myError = 20002
		Set @message = 'Database ' + @DBName + ' has a DB Schema Version less than 2 and is therefore not supported by this procedure'
		Goto Done
	End
	
	---------------------------------------------------
	-- resolve match method name to internal code
	-- Note that if @pepIdentMethod does not match any entries
	-- in T_Match_Methods, then @internalMatchCode will remain blank and thus
	-- all instruments will be returned
	---------------------------------------------------
	declare @internalMatchCode varchar(32)
	set @internalMatchCode = ''
	--
	If Len(@pepIdentMethod) > 0
	Begin
		SELECT @internalMatchCode = Internal_Code
		FROM T_Match_Methods
		WHERE ([Name] = @pepIdentMethod)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Could not resolve match methods'
			goto Done
		end
	End

	---------------------------------------------------
	-- build the sql query to get the data
	---------------------------------------------------
	declare @S varchar(2048)

	-- Construct the base Select clause, using Distinct to return a unique list of instrument names
	Set @S = 'SELECT DISTINCT'
	
	If @DBType = 2
	Begin
		-- Peptide DB
		Set @S = @S + ' Instrument'
		Set @S = @S + ' FROM [' + @DBName + ']..T_Analysis_Description'
		Set @S = @S + ' WHERE NOT Instrument IS NULL'
	End
	Else
	Begin
		-- PMT Tag DB
		if @internalMatchCode = 'PMT'
			Set @S = @S + ' Instrument FROM [' + @DBName + ']..T_Analysis_Description'
		else
		Begin
			if @internalMatchCode = 'UMC'
				Set @S = @S + ' Instrument FROM [' + @DBName + ']..T_FTICR_Analysis_Description'
			else
			Begin
				-- Return all instruments present
				Set @S = @S + ' Instrument FROM ('
				Set @S = @S +   ' SELECT DISTINCT Instrument FROM [' + @DBName + ']..T_Analysis_Description UNION'
				Set @S = @S +   ' SELECT DISTINCT Instrument FROM [' + @DBName + ']..T_FTICR_Analysis_Description'
				Set @S = @S + ') LookupQ'
			End
		End
		
			
		-- Note that the Instrument column must be present in the output
		Set @S = @S + ' WHERE NOT Instrument IS NULL'
	End

	-- Define the sort order
	Set @S = @S + ' ORDER BY Instrument'

	
	-- Obtain the data
	Exec (@S)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	If Len(@pepIdentMethod) > 0
		Set @UsageMessage = @UsageMessage + '; ' + @pepIdentMethod
	
	Exec PostUsageLogEntry 'GetInstrumentNamesForDB', @DBName, @UsageMessage
	
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetInstrumentNamesForDB]  TO [DMS_SP_User]
GO


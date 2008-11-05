/****** Object:  StoredProcedure [dbo].[LookupPeptideDBLocations] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE LookupPeptideDBLocations
/****************************************************	
**
**  Desc: Populates temporary table #T_Peptide_Database_List with the
**		  names and locations of the peptide DBs defined in T_Process_Config
**
**		  The calling procedure must create table  #T_Peptide_Database_List
**		  before calling this procedure
**
**			CREATE TABLE #T_Peptide_Database_List (
**					PeptideDBName varchar(128) NULL,
**					PeptideDBID int NULL,
**					PeptideDBServer varchar(128) NULL,
**					PeptideDBPath varchar(256) NULL
**			)
**
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	08/12/2005
**			09/06/2006 mem - Added parameter @MinimumPeptideProphetProbability
**			05/29/2007 mem - Fixed SP name provided to PostLogEntry
**
****************************************************/
(
	@message varchar(255) = '' output
)
AS
	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @message = ''

	declare @PeptideDBCountInvalid int
	declare @InvalidDBList varchar(1024)

	---------------------------------------------------
	-- Get peptide database name(s) from T_Process_Config
	---------------------------------------------------
	--
	INSERT INTO #T_Peptide_Database_List (PeptideDBName)
	SELECT Value
	FROM T_Process_Config
	WHERE [Name] = 'Peptide_DB_Name' AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount < 1
	begin
		set @message = 'No peptide databases are defined in T_Process_Config'
		set @myError = 40000
		goto Done
	end
		
	---------------------------------------------------
	-- Determine the ID and server for each Peptide DB in #T_Peptide_Database_List
	---------------------------------------------------
	--
	exec @myError = MT_Main.dbo.PopulatePeptideDBLocationTable @PreferDBName = 1, @message = @message output

	If @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling MT_Main.dbo.PopulatePeptideDBLocationTable'
		
		Set @message = @message + '; Error Code ' + Convert(varchar(12), @myError)
		Goto Done
	End
	
	Set @PeptideDBCountInvalid = 0
	SELECT @PeptideDBCountInvalid = COUNT(*)
	FROM #T_Peptide_Database_List
	WHERE PeptideDBID Is Null

	If @PeptideDBCountInvalid > 0
	Begin -- <a>
		-- One or more DBs in #T_Peptide_Database_List are unknown
		-- Construct a comma-separated list, post a log entry, 
		--  and delete the invalid databases from #T_Peptide_Database_List
		
		Set @InvalidDBList = ''
		SELECT @InvalidDBList = @InvalidDBList + PeptideDBName + ','
		FROM #T_Peptide_Database_List
		WHERE PeptideDBID Is Null
		ORDER BY PeptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount > 0
		Begin
			-- Remove the trailing comma
			Set @InvalidDBList = Left(@InvalidDBList, Len(@InvalidDBList)-1)
			
			Set @message = 'Invalid peptide DB'
			If @myRowCount > 1
				Set @message = @message + 's'
			Set @message = @message + ' defined in T_Process_Config: ' + @InvalidDBList
			execute PostLogEntry 'Error', @message, 'LookupPeptideDBLocations'
			set @message = ''
			
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBID Is Null
		End
	End
							
Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[LookupPeptideDBLocations] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[LookupPeptideDBLocations] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[LookupPeptideDBLocations] TO [MTS_DB_Lite]
GO

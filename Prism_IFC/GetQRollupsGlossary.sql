/****** Object:  StoredProcedure [dbo].[GetQRollupsGlossary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE dbo.GetQRollupsGlossary
/****************************************************
**
**	Desc: 
**	Returns data from V_QR_Glossary, but with user-friendly column names
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@message        -- explanation of any error that occurred
**
**		Auth: mem
**		Date: 02/11/2005
**    
*****************************************************/
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
	-- Create a temporary table to hold the glossary data
	---------------------------------------------------
	CREATE TABLE #T_GlossaryData (
		SP_Name varchar(128) NOT NULL ,
		Column_Name varchar(128) NOT NULL ,
		Description varchar(1024) NOT NULL ,
		Ordinal_Position int NOT NULL ,
		SPSortOrder int NULL
	)

	INSERT INTO #T_GlossaryData (SP_Name, Column_Name, Description, Ordinal_Position, SPSortOrder)
	SELECT T_SP_List.SP_Name, T_SP_Glossary.Column_Name, ISNULL(T_SP_Glossary.Description, ''), Ordinal_Position, 100
	FROM T_SP_List INNER JOIN
		T_SP_Glossary ON T_SP_List.SP_ID = T_SP_Glossary.SP_ID
	WHERE T_SP_List.Category_ID = 2 AND T_SP_Glossary.Direction_ID = 3
	ORDER BY T_SP_List.SP_Name, T_SP_Glossary.Ordinal_Position
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not get QR glossary data'
		goto Done
	end

	---------------------------------------------------
	-- Update the column data
	---------------------------------------------------
	
	-- Replace underscores with spaces
	UPDATE #T_GlossaryData
	SET Column_Name = Replace(Column_Name, '_', ' ')

	-- Rename the values in the SP_Name column to user-friendly names
	UPDATE #T_GlossaryData SET	SP_Name = 'Summary',	
			SPSortOrder = 1 WHERE SP_Name = 'WebQRSummary'
	UPDATE #T_GlossaryData SET	SP_Name = 'Protein Report',
			SPSortOrder = 2 WHERE SP_Name = 'WebQRRetrieveProteinsMultiQID'
	UPDATE #T_GlossaryData SET	SP_Name = 'Peptide Report',
			SPSortOrder = 3 WHERE SP_Name = 'WebQRRetrievePeptidesMultiQID'
	UPDATE #T_GlossaryData SET	SP_Name = 'Protein Crosstab', 
			SPSortOrder = 4 WHERE SP_Name = 'WebQRProteinCrosstab'
	UPDATE #T_GlossaryData SET	SP_Name = 'Peptide Crosstab', 
			SPSortOrder = 5 WHERE SP_Name = 'WebQRPeptideCrosstab'
	UPDATE #T_GlossaryData SET	SP_Name = 'Proteins with Peptides Crosstab', 
			SPSortOrder = 6 WHERE SP_Name = 'WebQRProteinsWithPeptidesCrosstab'

	---------------------------------------------------
	-- Return the glossary data
	---------------------------------------------------
	
	SELECT SP_Name AS [Worksheet], Column_Name AS [Column Name], Description
	FROM #T_GlossaryData
	ORDER BY SPSortOrder, Ordinal_Position
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'GetQRollupsGlossary', '', @UsageMessage
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetQRollupsGlossary] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetQRollupsGlossary] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetQRollupsGlossary] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[GetPeptideDBRecentCampaignActivity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetPeptideDBRecentCampaignActivity
/****************************************************
** 
**		Desc: 
**		gets list of most recent job imported by campaign
**		for each peptide db in master list
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: grk
**		Date: 09/18/2003
**			  11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
**    
*****************************************************/
AS
	SET NOCOUNT ON

	declare @myError int,
			@myRowCount int,
			@SPExecCount int,
			@SPRowCount int,
			@DBCount int,
			@done int,
			@message varchar(256)

	set @myError = 0
	set @myRowCount = 0
	set @SPRowCount = 0
	set @SPExecCount = 0
	set @done = 0


	-- Note: @S needs to be unicode (nvarchar) for compatibility with sp_executesql
	declare @S nvarchar(1024),
			@CurrentDB varchar(255),	
			@SPToExec varchar(255)
				
	set @CurrentDB = ''
	set @message = ''
	
	
	---------------------------------------------------
	-- temporary table to hold results
	---------------------------------------------------
	CREATE TABLE #XResults (
		PTDB_Name varchar(128),
		Campaign varchar(128),
		[Most Recent] datetime
	) 

	
 	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #XDBNames (
		PTDB_Name varchar(128),
		Processed tinyint
	) 

	---------------------------------------------------
	-- populate temporary table with list of mass tag
	-- databases that are not deleted
	---------------------------------------------------
	INSERT INTO #XDBNames
	SELECT     PDB_Name, 0 AS Expr1
	FROM         T_Peptide_Database_List
	WHERE     (PDB_State <> 100)
	ORDER BY PDB_Name	
	--
	SELECT @myError = @@error, @DBCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not load temporary table'
		goto done
	end

	---------------------------------------------------
	-- step through the mass tag database list and call
	---------------------------------------------------
		
	WHILE @done = 0 and @myError = 0  
	BEGIN
	
		-- Get next available entry from XMTDBNames
		--
		SELECT	TOP 1 @CurrentDB = PTDB_Name
		FROM	#XDBNames 
		WHERE	Processed = 0
		ORDER BY PTDB_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--		
		if @myRowCount = 0
			Goto Done
		
		-- update Process_State entry for given MTDB to 1
		--
		UPDATE	#XDBNames
		SET		Processed = 1
		WHERE	(PTDB_Name = @CurrentDB)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not update the mass tag database list temp table'
			set @myError = 51
			goto Done
		end

		-- update results table
		--
		set @S = N'INSERT INTO #XResults (PTDB_Name, Campaign, [Most Recent] ) '
		set @S = @S + 'SELECT ''' + @CurrentDB + ''', Campaign, MAX(Created) AS [Most Recent Job] '
		set @S = @S + 'FROM '
		set @S = @S + '[' + @CurrentDB + '].dbo.T_Analysis_Description '
		set @S = @S + 'WHERE (Analysis_Tool NOT LIKE ''%TIC%'') '
		set @S = @S + 'GROUP BY Campaign '

		exec sp_executesql @S		
	END

Done:
	select PTDB_Name as [Peptide DB], Campaign, [Most Recent] from #XResults ORDER BY PTDB_Name

 
	RETURN 


GO
GRANT EXECUTE ON [dbo].[GetPeptideDBRecentCampaignActivity] TO [DMS_SP_User]
GO

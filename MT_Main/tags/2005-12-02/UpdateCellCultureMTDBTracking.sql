SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateCellCultureMTDBTracking]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateCellCultureMTDBTracking]
GO

CREATE PROCEDURE UpdateCellCultureMTDBTracking
/****************************************************
** 
**		Desc: 
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 10/28/2002
**			  11/23/2005 mem - Added brackets around @mtdb as needed to allow for DBs with dashes in the name
**    
*****************************************************/
AS
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	declare @message varchar(255)

	declare @cmd nvarchar(255)
	declare @result int
	declare @sql nvarchar(2048)

	set @message = 'Cell Culture Tracking Update Begun'
	execute PostLogEntry 'Normal', @message, 'UpdateCellCultureMTDBTracking'
	set @message = ''

	-----------------------------------------------------------
	-- Build Dynamic SQL base strings
	-----------------------------------------------------------
	
	-- build dynamic SQL string for updating dataset counts
	-- 
	declare @s1 varchar(2048)
	set @s1 = ''
	--
	set @s1 = @s1 + 'Update Q Set Q.Datasets = U.Datasets '
	set @s1 = @s1 + 'FROM T_Cell_Culture_MTDB_Tracking as Q JOIN '
	set @s1 = @s1 + '( '
	--
	set @s1 = @s1 + 'SELECT T.CellCulture, ''XXX'' AS MTDatabase, COUNT(S.DatasetID) AS Datasets '
	set @s1 = @s1 + 'FROM V_DMS_Cell_Culture_Datasets_Import T INNER JOIN '
	set @s1 = @s1 + '( '
	set @s1 = @s1 + 'SELECT DISTINCT Dataset_ID AS DatasetID '
	set @s1 = @s1 + 'FROM XXX.dbo.T_Analysis_Description '
	set @s1 = @s1 + 'UNION '
	set @s1 = @s1 + 'SELECT DISTINCT Dataset_ID AS DatasetID '
	set @s1 = @s1 + 'FROM XXX.dbo.T_FTICR_Analysis_Description '
	set @s1 = @s1 + ') S ON S.DatasetID = T.DatasetID '
	set @s1 = @s1 + 'GROUP BY T.CellCulture '
	set @s1 = @s1 + ') U on Q.CellCulture = U.CellCulture and Q.MTDatabase = U.MTDatabase'

	-- build dynamic SQL string for updating experiment counts
	-- 
	declare @s2 varchar(2048)
	set @s2 = ''
	--
	set @s2 = @s2 + 'Update Q Set Q.Experiments = U.Experiments '
	set @s2 = @s2 + 'FROM T_Cell_Culture_MTDB_Tracking as Q JOIN '
	set @s2 = @s2 + '( '
	set @s2 = @s2 + 'SELECT T.CellCulture, ''XXX'' AS MTDatabase, COUNT(S.Experiment) AS Experiments '
	set @s2 = @s2 + 'FROM V_DMS_Cell_Culture_Experiments_Import T INNER JOIN '
	set @s2 = @s2 + '( '
	set @s2 = @s2 + '  SELECT DISTINCT Experiment '
	set @s2 = @s2 + '  FROM XXX.dbo.T_Analysis_Description '
	set @s2 = @s2 + '  UNION '
	set @s2 = @s2 + '  SELECT DISTINCT Experiment '
	set @s2 = @s2 + '  FROM XXX.dbo.T_FTICR_Analysis_Description '
	set @s2 = @s2 + ') S ON S.Experiment = T.Experiment '
	set @s2 = @s2 + 'GROUP BY T.CellCulture '
	set @s2 = @s2 + ') U on Q.CellCulture = U.CellCulture and Q.MTDatabase = U.MTDatabase'

	-- build dynamic SQL string for updating job counts
	-- 
	declare @s3 varchar(2048)
	set @s3 = ''
	--
	set @s3 = @s3 + 'Update Q Set Q.Jobs = U.Jobs '
	set @s3 = @s3 + 'FROM T_Cell_Culture_MTDB_Tracking as Q JOIN '
	set @s3 = @s3 + '( '
	set @s3 = @s3 + 'SELECT T.CellCulture, ''XXX'' AS MTDatabase, COUNT(S.Job) AS Jobs '
	set @s3 = @s3 + 'FROM V_DMS_Cell_Culture_Jobs_Import T INNER JOIN '
	set @s3 = @s3 + '( '
	set @s3 = @s3 + '  SELECT DISTINCT Job '
	set @s3 = @s3 + '  FROM XXX.dbo.T_Analysis_Description '
	set @s3 = @s3 + '  UNION '
	set @s3 = @s3 + '  SELECT DISTINCT Job '
	set @s3 = @s3 + '  FROM XXX.dbo.T_FTICR_Analysis_Description '
	set @s3 = @s3 + ') S ON S.Job = T.JobID '
	set @s3 = @s3 + 'GROUP BY T.CellCulture '
	set @s3 = @s3 + ') U on Q.CellCulture = U.CellCulture and Q.MTDatabase = U.MTDatabase'

	-----------------------------------------------------------
	-- Establish base information in tracking table
	-----------------------------------------------------------

	-- clean out existing entries in tracking table
	--
	DELETE FROM T_Cell_Culture_MTDB_Tracking
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not clear tracking table'
		set @myError = 37
		goto Done
	end

	-- add baseline information about cell cultures and associated MT databases
	--
	INSERT INTO T_Cell_Culture_MTDB_Tracking
		(CellCulture, MTDatabaseID, CCID, MTDatabase)
	SELECT 
		V_DMS_Campaign_Cell_Culture_Import.CellCulture AS [Cell Culture], 
		T_MT_Database_List.MTL_ID AS [MTDB ID], 
		V_DMS_Campaign_Cell_Culture_Import.CC_ID,
		T_MT_Database_List.MTL_Name
	FROM T_MT_Database_List INNER JOIN
	V_DMS_Campaign_Cell_Culture_Import ON V_DMS_Campaign_Cell_Culture_Import.Campaign = T_MT_Database_List.MTL_Campaign
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not add baseline information to tracking table'
		set @myError = 39
		goto Done
	end

	-----------------------------------------------------------
	-- Update information in tracking table for each MTDatabase
	-----------------------------------------------------------

	-- create temporary table for holding list of 
	-- mass tag databases
	--
	create table #MTDBL (
		MTDatabase varchar(128) NULL,
		MTDatabaseID int NULL
	)

	-- populate temporary table with current list of mass tag databases
	--
	INSERT INTO #MTDBL
		(MTDatabase, MTDatabaseID)
	SELECT     MTL_Name, MTL_ID
	FROM         T_MT_Database_List
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not populate temporary table'
		set @myError = 38
		goto Done
	end
	
	-- cycle through each mass tag database
	--
	declare @mtdb varchar(128)
	declare @id int
	set @id = 0
	declare @cnt int
	set @cnt = @myRowCount
	--
	while @cnt > 0
	begin
		SELECT top 1 @id = MTDatabaseID, @mtdb = MTDatabase 
		FROM #MTDBL
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--

		if @id = 0 break

		-- replace placeholder with mass tag database name in dynamic SQL strings
		-- and execute them

		set @sql = replace(@s1, 'XXX', '[' + @mtdb + ']')
		exec @result = sp_executesql @sql

		set @sql = replace(@s2, 'XXX', '[' + @mtdb + ']')
		exec @result = sp_executesql @sql

		set @sql = replace(@s3, 'XXX', '[' + @mtdb + ']')
		exec @result = sp_executesql @sql
		
		--
		delete from #MTDBL where MTDatabaseID = @id
		--
		set @cnt = @cnt - 1 -- to preclude infinite loop
	end
	
	-----------------------------------------------------------
	-- log successful completion of update process
	-----------------------------------------------------------
	
	if @myError = 0 
	begin
		set @message = 'Cell Culture Tracking Update Completed'
		execute PostLogEntry 'Normal', @message, 'UpdateCellCultureMTDBTracking'
	end

Done:
	-----------------------------------------------------------
	-- 
	-----------------------------------------------------------
	--
	if @myError <> 0 
	begin
		set @message = 'Cell Culture Tracking Update Error: ' + @message
		execute PostLogEntry 'Error', @message, 'UpdateCellCultureMTDBTracking'
	end

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[UpdateCellCultureMTDBTracking]  TO [DMS_SP_User]
GO


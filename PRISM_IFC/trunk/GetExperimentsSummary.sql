SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetExperimentsSummary]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetExperimentsSummary]
GO

CREATE PROCEDURE dbo.GetExperimentsSummary
/****************************************************
**
**	Desc: 
**	Returns summary list of PRISM experiments for given
**	mass tag database and given peptide identification method
**  
**  Returns result set with columns defined in view V_DMS_CCE_Experiment_Summary:
**		Experiment
**		[Exp Reason]
**		[Exp Comment]
**		Campaign
**		Organism
**		[Cell Cultures]       
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**      @MTDBName       -- name of mass tag database to use
**		@pepIdentMethod -- method used to identify peptides: DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)
**      @outputColumnNameList -- list of output columns to include in result set (ignored at present)
**		@message        -- explanation of any error that occurred
**
**		Auth: grk
**		Date: 04/7/2004
**            04/12/2004 grk - added validation logic for @MTDBName
**			  10/22/2004 mem - Added PostUsageLogEntry
**			  11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@MTDBName varchar(128) = '',
	@pepIdentMethod varchar(32) = 'DBSearch(MS/MS-LCQ)',
	@outputColumnNameList varchar(1024) = '', -- ignored at present
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
	-- validate mass tag DB name
	---------------------------------------------------
	Declare @DBNameLookup varchar(256)
	SELECT  @DBNameLookup = MTL_ID
	FROM MT_Main.dbo.T_MT_Database_List
	WHERE (MTL_Name = @MTDBName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Could not resolve mass tag DB name'
		goto Done
	end

	---------------------------------------------------
	-- resolve match method name to internal code
	---------------------------------------------------
	declare @internalMatchCode varchar(32)
	set @internalMatchCode = ''
	--
	SELECT @internalMatchCode = Internal_Code
	FROM T_Match_Methods
	WHERE (Name = @pepIdentMethod)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @internalMatchCode = ''
	begin
		set @message = 'Could not resolve match methods'
		goto Done
	end

	---------------------------------------------------
	-- build basic query to get list of experiments from MTDB
	---------------------------------------------------
	declare @sql nvarchar(1024)
	--
	set @sql = ''
	set @sql = @sql + 'INSERT INTO #EXP '
	set @sql = @sql + 'SELECT DISTINCT Experiment '
	set @sql = @sql + 'FROM DATABASE..TABLE '
	set @sql = @sql + 'WHERE (NOT (Analysis_Tool LIKE ''%TIC%''))'

/*	
	SELECT DISTINCT T.Experiment
	FROM
	(
	SELECT Experiment
	FROM MT_Deinococcus_P104..T_Analysis_Description
	WHERE (NOT (Analysis_Tool LIKE '%TIC%'))
	UNION
	SELECT Experiment
	FROM MT_Deinococcus_P104..T_FTICR_Analysis_Description
	WHERE (NOT (Analysis_Tool LIKE '%TIC%'))
	) T
	
	SELECT DISTINCT T.Experiment
	FROM
	(
	SELECT Experiment
	FROM MT_Deinococcus_P104..T_Analysis_Description
	WHERE (NOT (Analysis_Tool LIKE '%TIC%'))
	UNION
	SELECT Experiment
	FROM MT_Deinococcus_P104..T_FTICR_Analysis_Description
	WHERE (NOT (Analysis_Tool LIKE '%TIC%'))
	) T
*/

	---------------------------------------------------
	-- tailor basic query to specific MTDB and match method
	---------------------------------------------------

	declare @s nvarchar(1024)
	set @s = ''
	--
	if @internalMatchCode = 'PMT'
	begin
		set @s = replace(@sql, 'DATABASE..TABLE', '[' + @MTDBName + ']..T_Analysis_Description')
	end

	if @internalMatchCode = 'UMC'
	begin
		set @s = replace(@sql, 'DATABASE..TABLE', '[' + @MTDBName + ']..T_FTICR_Analysis_Description')
	end

	if @s = ''
	begin
		set @message = 'Could not build dynamic SQL'
		goto Done
	end

	---------------------------------------------------
	-- temporary table to hold list of experiments
	---------------------------------------------------
	CREATE TABLE #EXP (
		Experiment varchar (128)
	)   
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @internalMatchCode = ''
	begin
		set @message = 'Could not create temporary table'
		goto Done
	end

	---------------------------------------------------
	-- get list of experiments into temporary table
	---------------------------------------------------
	
	exec @result = sp_executesql @s
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount

	---------------------------------------------------
	-- get context information from DMS
	-- for experiments in temporary table
	---------------------------------------------------

	SELECT V_DMS_CCE_Experiment_Summary.Experiment, 0 as Sel, [Exp Reason], [Exp Comment], Campaign, Organism, [Cell Cultures]
	FROM V_DMS_CCE_Experiment_Summary INNER JOIN
	#EXP on #EXP.Experiment = V_DMS_CCE_Experiment_Summary.Experiment
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows; ' + @pepIdentMethod
	Exec PostUsageLogEntry 'GetExperimentsSummary', @MTDBName, @UsageMessage
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetExperimentsSummary]  TO [DMS_SP_User]
GO


/****** Object:  StoredProcedure [dbo].[GetExperimentsSummary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**	Auth:	grk
**	Date:	04/7/2004
**          04/12/2004 grk - added validation logic for @MTDBName
**			10/22/2004 mem - Added PostUsageLogEntry
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			02/20/2006 mem - Now validating that @MTDBName has a state less than 100 in MT_Main
**						   - Now returning column [Dataset Count] as column 8
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',
	@pepIdentMethod varchar(32) = 'DBSearch(MS/MS-LCQ)',
	@outputColumnNameList varchar(1024) = '', -- ignored at present
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- validate mass tag DB name
	---------------------------------------------------
	--
	Declare @DBNameLookup varchar(256)
	SELECT  @DBNameLookup = MTL_ID
	FROM MT_Main.dbo.T_MT_Database_List
	WHERE (MTL_Name = @MTDBName) AND MTL_State < 100
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
	--
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
	-- Create temporary table to hold list of experiments
	---------------------------------------------------
	--
	CREATE TABLE #Tmp_Experiments (
		Experiment varchar (128),
		[Dataset Count] int
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
	-- Build query to get list of experiments from
	-- specific MTDB and match method
	---------------------------------------------------
	--
	declare @s nvarchar(1024)
	set @s = ''
	--
	if @internalMatchCode = 'PMT'
	begin
		set @s = ''
		set @s = @s + ' INSERT INTO #Tmp_Experiments (Experiment, [Dataset Count])'
		set @s = @s + ' SELECT TAD.Experiment, COUNT(DISTINCT Dataset_ID) AS [Dataset Count] '
		set @s = @s + ' FROM [' + @MTDBName + ']..T_Analysis_Description TAD'
		set @s = @s + ' WHERE (NOT (TAD.Analysis_Tool LIKE ''%TIC%''))'
		set @s = @s + ' GROUP BY TAD.Experiment'
	end

	if @internalMatchCode = 'UMC'
	begin
		set @s = ''
		set @s = @s + ' INSERT INTO #Tmp_Experiments (Experiment, [Dataset Count])'
		set @s = @s + ' SELECT TAD.Experiment, COUNT(DISTINCT Dataset_ID) AS [Dataset Count]'
		set @s = @s + ' FROM [' + @MTDBName + ']..T_FTICR_Analysis_Description TAD INNER JOIN'
		set @s = @s +      ' [' + @MTDBName + ']..T_Match_Making_Description MMD ON TAD.Job = MMD.MD_Reference_Job'
		set @s = @s + ' WHERE (NOT (TAD.Analysis_Tool LIKE ''%TIC%''))'
		set @s = @s + ' GROUP BY TAD.Experiment'
	end

	if @s = ''
	begin
		set @message = 'Could not build dynamic SQL'
		goto Done
	end

	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Experiments]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table dbo.#Tmp_Experiments


	---------------------------------------------------
	-- Populate temporary table with list of experiments and Dataset counts
	---------------------------------------------------
	--
	exec @result = sp_executesql @s
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount


	---------------------------------------------------
	-- get context information from DMS
	-- for experiments in temporary table
	---------------------------------------------------
	--
	SELECT V_DMS_CCE_Experiment_Summary.Experiment, 0 as Sel, [Exp Reason], [Exp Comment], Campaign, Organism, [Cell Cultures], [Dataset Count]
	FROM V_DMS_CCE_Experiment_Summary INNER JOIN
	     #Tmp_Experiments on #Tmp_Experiments.Experiment = V_DMS_CCE_Experiment_Summary.Experiment
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
GRANT EXECUTE ON [dbo].[GetExperimentsSummary] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetExperimentsSummary] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetExperimentsSummary] TO [MTS_DB_Lite] AS [dbo]
GO

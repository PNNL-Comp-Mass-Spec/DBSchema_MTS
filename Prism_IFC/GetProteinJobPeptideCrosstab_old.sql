/****** Object:  StoredProcedure [dbo].[GetProteinJobPeptideCrosstab_old] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetProteinJobPeptideCrosstab_old
/****************************************************
**	Desc:  
**  Generates a crosstab report of proteins against jobs
**  for experiments in list.  Uses only peptide analysis 
**  results (not mass tags)
**
**  Developer note: Eliminate GetPeptideJobCrosstab if this sproc is retained
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @MTDBName				-- Mass tag database name
**	  @experiments			-- Filter: Comma separated list of experiments or list of experiment match criteria containing a wildcard character(%)
**							--   Names do not need single quotes around them; see @Proteins parameter for examples
**	  @message				-- Status/error message output
**
**		Auth: grk
**		Date: 11/21/2004
**			  12/01/2004 grk - Added Dataset column to output and now accommodating for a blank @experiments input parameter
**			  11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@MTDBName varchar(128) = 'MT_Shewanella_P146',
	@experiments varchar(7000) = 'Core_003_CTL040603_A1, Core_003_CTL040603_A2, Core_003_CTL040603_B1, Core_003_CTL040603_B2, Core_003_CTL040603_C1, Core_003_CTL040603_C2',
	@aggregation varchar(24) = 'Sum_XCorr', -- 'Count_Peptide_Hits'
	@mode varchar(32) = 'Crosstab_Report', -- 'Preview_Data_Analysis_Jobs', 'Preview_Experiments', 'Preview_Proteins'
	@message varchar(512) output
AS
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	declare @sql nvarchar(4000)
	
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
	if @myError <> 0
	begin
		set @message = 'Error trying to resolve mass tag DB name'
		goto Done
	end
	--
	if @myRowCount <> 1
	begin
		set @myError = 19
		set @message = 'Mass tag DB name was not recognized'
		goto Done
	end
	
	---------------------------------------------------
	-- Determine version of MTDB schema 
	---------------------------------------------------

	declare @dbVer int
	set @dbVer = 0
	Exec @dbVer = GetDBSchemaVersionByDBName @MTDBName

	---------------------------------------------------
	-- Parse @experiments and @Proteins to create a proper
	-- SQL where clause containing a mix of 
	-- Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @experimentWhereClause varchar(8000)
	Set @experimentWhereClause = ''
	if @experiments = ''
		set @experiments = '%'
	Exec ConvertListToWhereClause @experiments, 'A.Experiment', @entryListWhereClause = @experimentWhereClause OUTPUT
	
	---------------------------------------------------
	-- Create temporary table to hold rollups from proteins
	-- and jobs and populate it
	---------------------------------------------------

	CREATE TABLE #XPD ( 
		Ref_ID int,
		Experiment varchar(128),
		Dataset varchar(128),
		Job int,
		NP int,
		SX float,
	)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not create temporary table for ORFs'
		goto Done
	end

	set @sql = ''
	set @sql = @sql + 'INSERT INTO #XPD '+ CHAR(10)
	set @sql = @sql + 'SELECT Ref_ID, Experiment, Dataset, Job, Count(MT) as NP, Sum(XCorr) as SX '+ CHAR(10)
	set @sql = @sql + 'FROM '+ CHAR(10)
	set @sql = @sql + '( '+ CHAR(10)
	if @dbVer > 1
		begin
			set @sql = @sql + 'SELECT DISTINCT O.Ref_ID, A.Experiment, A.Dataset, P.Analysis_ID AS Job, P.Mass_Tag_ID as MT, S.XCorr '+ CHAR(10)
			set @sql = @sql + 'FROM '+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Peptides P INNER JOIN'+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Mass_Tag_to_Protein_Map M ON P.Mass_Tag_ID = M.Mass_Tag_ID INNER JOIN' + CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Proteins O ON M.Ref_ID = O.Ref_ID INNER JOIN'+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Analysis_Description A ON P.Analysis_ID = A.Job INNER JOIN'+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Score_Sequest S ON P.Peptide_ID = S.Peptide_ID'+ CHAR(10)
			set @sql = @sql + 'WHERE ' + @experimentWhereClause
		end
	else
		begin
			set @sql = @sql + 'SELECT DISTINCT O.Ref_ID, A.Experiment, A.Dataset, P.Analysis_ID AS Job, P.Mass_Tag_ID as MT, P.XCorr '+ CHAR(10)
			set @sql = @sql + 'FROM '+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_ORF_Reference O INNER JOIN'+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Mass_Tag_to_ORF_Map M ON O.Ref_ID = M.Ref_ID INNER JOIN'+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Peptides P ON M.MT_ID = P.Mass_Tag_ID INNER JOIN'+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Analysis_Description A ON P.Analysis_ID = A.Job'+ CHAR(10)
			set @sql = @sql + 'WHERE ' + @experimentWhereClause
		end
	set @sql = @sql + ') Z '+ CHAR(10)
	set @sql = @sql + 'GROUP  BY Ref_ID, Experiment, Dataset, Job '+ CHAR(10)
	set @sql = @sql + 'HAVING  (COUNT(MT) > 1) '+ CHAR(10)
	--
	EXEC @myError = sp_executesql @sql
	--
	if @myError <> 0
	begin
		set @message = 'Could not populate temporary table for ORFs'
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @mode = 'Preview_Data_Analysis_Jobs'
	begin
		select distinct Job, Dataset, Experiment from #XPD
		goto Done
	end

	if @mode = 'Preview_Experiments'
	begin
		select Experiment, count(Job) as [Data Analysis Jobs] 
		from 
		(
			Select distinct Job, Experiment from #XPD
		) M
		group by Experiment
		goto Done
	end

	---------------------------------------------------
	-- create temporary table for protein information
	-- for selected results and populate it
	---------------------------------------------------

	CREATE TABLE #ORF ( 
		S char(1) Null,
		Reference varchar (128) NULL,
		Ref_ID int NULL,
		ORF_ID int NULL,
		Monoisotopic_Mass float NULL,
		Description varchar(512) NULL
	)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not create temporary table for ORFs'
		goto Done
	end

	set @sql = ''
	set @sql = @sql + 'INSERT INTO #ORF '+ CHAR(10)
	if @dbVer > 1
		begin
			set @sql = @sql + 'SELECT '''' as S, Reference, Ref_ID, Protein_ID, Monoisotopic_Mass, ''X'' as Description '+ CHAR(10)
			set @sql = @sql + 'FROM '+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_Proteins'+ CHAR(10)
		end
	else
		begin
			set @sql = @sql + 'SELECT '''' as S, Reference, Ref_ID, ORF_ID, Monoisotopic_Mass, ''X'' as Description '+ CHAR(10)
			set @sql = @sql + 'FROM '+ CHAR(10)
			set @sql = @sql + '[' + @MTDBName + '].dbo.T_ORF_Reference '+ CHAR(10)
		end
	set @sql = @sql + 'WHERE Ref_ID IN (SELECT DISTINCT Ref_ID FROM #XPD)'+ CHAR(10)
	--
	EXEC @myError = sp_executesql @sql
	--
	if @myError <> 0
	begin
		set @message = 'Could not populate temporary ORF table'
		goto Done
	end


	---------------------------------------------------
	-- update ORF description from ORF database (if existent)
	---------------------------------------------------

	declare @peptideDBName varchar(128), @proteinDBName varchar(128)
	Exec MT_Main.dbo.GetMTAssignedDBs @MTDBName, @peptideDBName output, @proteinDBName output

	if @proteinDBName <> ''
	begin
		set @sql = ''
		set @sql = @sql + 'update X '
		set @sql = @sql + 'set X.Description = T.Description '
		set @sql = @sql + 'from #ORF X INNER JOIN '
		set @sql = @sql + '( '
		set @sql = @sql + 'SELECT Reference, Description_From_FASTA AS Description '
		set @sql = @sql + 'FROM ' + @proteinDBName + '.dbo.T_ORF '
		set @sql = @sql + ') T on T.Reference = X.Reference '
		--
		EXEC @myError = sp_executesql @sql
		--
		if @myError <> 0
		begin
			set @message = 'Could not update temporary table for ORFs descriptions'
			goto Done
		end
	end 

	---------------------------------------------------
	-- Add protein standards entries as markers
	---------------------------------------------------
/**/
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '200kDa', 200000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '150kDa', 150000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '100kDa', 100000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '90kDa', 90000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '80kDa', 80000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '70kDa', 70000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '60kDa', 60000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '50kDa', 50000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '40kDa', 40000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '30kDa', 30000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '20kDa', 20000)
	INSERT INTO #ORF (S, Reference, Monoisotopic_Mass) VALUES ('S', '10kDa', 10000)

	---------------------------------------------------
	-- 
	---------------------------------------------------
	if @mode = 'Preview_Proteins'
	begin
		select Reference, Monoisotopic_Mass, Description from #ORF
		goto Done
	end

	---------------------------------------------------
	-- Build crosstab column SQL for each job
	---------------------------------------------------
	declare @colName varchar(50)
	set @colname = 'SX'

	declare @funcName varchar(32)
	set @funcName = 'SUM'

	If @aggregation = 'Count_Peptide_Hits' -- '''Sum_XCorr'
	begin
		set @colname = '1'
		set @funcName = 'SUM'
	end
	
	declare @crossTabCols varchar(5000)
	set @crossTabCols = ''

	SELECT @crossTabCols = @crossTabCols 
	+ CASE WHEN @crossTabCols = '' THEN '' ELSE ', ' + CHAR(10) END
	+ @funcName + '(CASE Job WHEN ' 
	+  cast(Job as varchar(12)) + ' THEN ' + @colname + ' END) AS '
	+ Experiment + '_' + cast(Job as varchar(12)) 
	FROM 
	(
	SELECT DISTINCT Job, Experiment
	FROM #XPD 
	) J
	ORDER BY Experiment
	--
	if @crossTabCols = ''
	begin
		set @message = 'No crosstab columns were generated'
		goto Done
	end
	---------------------------------------------------
	-- build full crosstab query against temporary table
	-- and run it
	---------------------------------------------------

	set @sql = 'SELECT S, Reference, Monoisotopic_Mass,' + CHAR(10)
	set @sql = @sql + @crossTabCols + CHAR(10)
	set @sql = @sql + 'FROM ' + CHAR(10)
	set @sql = @sql + '#XPD RIGHT OUTER JOIN ' + CHAR(10)
	set @sql = @sql + '#ORF ON #XPD.Ref_ID = #ORF.Ref_ID ' + CHAR(10)
	set @sql = @sql + 'GROUP BY S, Reference, Monoisotopic_Mass ' + CHAR(10)
	set @sql = @sql + 'ORDER BY Monoisotopic_Mass DESC ' + CHAR(10)

	-- check if dynamic sql statement has been truncated
	--
	if len(@sql) = 4000
	begin
		set @myError = 20
		set @message = 'Too many crosstab columns'
		goto Done
	end

	-- execute dynamic sql
	--
	EXEC @myError = sp_executesql @sql
	--
	if @myError <> 0
	begin
		set @message = 'Error executing crosstab query'
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------
Done:
/*
	if @myError <> 0
	begin
		CREATE TABLE #ERR ( 
			Num int,
			Error varchar(512)
		)
		INSERT INTO #ERR (Num, Error) VALUES (@myError, @message)
		select * from #ERR
	end
*/
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[GetProteinJobPeptideCrosstab_old] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetProteinJobPeptideCrosstab_old] TO [MTS_DB_Lite] AS [dbo]
GO

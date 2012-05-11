/****** Object:  StoredProcedure [dbo].[QCMSMSSeqStatDetails] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE QCMSMSSeqStatDetails
/****************************************************
** 
**		Desc: 
**			Returns the SIC stats for the given jobs and peptides
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	11/14/2005
**				11/16/2005 mem - Now returning additional columns: Peak_Apex_Scan, Peak_Scan_Start, Peak_Scan_End, and Peak_Width_Base_Points
**			    11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**				09/22/2010 mem - Added parameters @ResultTypeFilter and @PreviewSql
**				01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@DBName varchar(128) = '',
	@returnRowCount varchar(32) = 'False',
	@message varchar(512) = '' output,
	
	@InstrumentFilter varchar(128) = '',			-- Single instrument name or instrument name match strings; use SP GetInstrumentNamesForDB to see the instruments for the jobs in a given DB
	@CampaignFilter varchar(1024) = '',
	@ExperimentFilter varchar(1024) = '',
	@DatasetFilter varchar(1024) = '',
	@OrganismDBFilter varchar(1024) = '',

	@DatasetDateMinimum varchar(32) = '',			-- Ignored if blank; compared against Dataset_Acq_Time_Start
	@DatasetDateMaximum varchar(32) = '',			-- Ignored if blank; compared against Dataset_Acq_Time_End
	@JobMinimum int = 0,							-- Ignored if 0
	@JobMaximum int = 0,							-- Ignored if 0
	
	@maximumRowCount int = 0,						-- 0 means to return all rows
	
	@SeqIDList varchar(7000),						-- Required: Comma separated list of Seq_ID values to match
	
	@ResultTypeFilter varchar(32) = 'XT_Peptide_Hit',	-- Peptide_Hit is Sequest, XT_Peptide_Hit is X!Tandem, IN_Peptide_Hit is Inspect
	@PreviewSql tinyint = 0

)
As
	Set NoCount On
	
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

	-- Make sure the type is 1 or 2 and that no errors occurred
	If @DBType = 0 Or @myError <> 0
	Begin
		If @myError = 0
			Set @myError = 20000

		If Len(@message) = 0
			Set @message = 'Database not found on this server: ' + @DBName
		Goto Done
	End
	Else
	If @DBType <> 2
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a Peptide DB and is therefore not appropriate for this procedure'
		Goto Done
	End
	Else
	If @DBSchemaVersion < 2
	Begin
		Set @myError = 20002
		Set @message = 'Database ' + @DBName + ' has a DB Schema Version less than 2 and is therefore not supported by this procedure'
		Goto Done
	End
		
	---------------------------------------------------
	-- Cleanup the input parameters
	---------------------------------------------------

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @returnRowCount OUTPUT, 1

	Set @ResultTypeFilter = IsNull(@ResultTypeFilter, '')
	Set @previewSql = IsNull(@previewSql, 0)

	-- Force @maximumRowCount to be negative if @returnRowCount is true
	If @returnRowCount = 'true'
		Set @maximumRowCount = -1

	---------------------------------------------------
	-- Create the jobs temporary table
	---------------------------------------------------
	
--	If exists (select * from dbo.sysobjects where id = object_id(N'[#TmpQCJobList]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
--		drop table [#TmpQCJobList]

	CREATE TABLE #TmpQCJobList (
		Job int NOT NULL 
	)

	CREATE UNIQUE CLUSTERED INDEX [#IX_TmpQCJobList] ON #TmpQCJobList(Job)
	
	---------------------------------------------------
	-- Populate the temporary table with the jobs matching the filters
	---------------------------------------------------
	
	Exec @myError = QCMSMSJobsTablePopulate	@DBName, @message output, 
											@InstrumentFilter, @CampaignFilter, @ExperimentFilter, @DatasetFilter, 
											@OrganismDBFilter, @DatasetDateMinimum, @DatasetDateMaximum, 
											@JobMinimum, @JobMaximum, @maximumRowCount,
											@ResultTypeFilter, @PreviewSql
	If @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling QCMSMSJobTablePopulate'
		Goto Done
	End


	--------------------------------------------------------------
	-- Create a temporary table to hold the SIC stats
	--------------------------------------------------------------
	If Exists (select * from dbo.sysobjects where id = object_id(N'[#TmpSICStats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		DROP TABLE [#TmpSICStats]

	CREATE TABLE [#TmpSICStats] (
		[Unique_ID] [int] IDENTITY NOT NULL ,
		[Peptide_Hit_Job] [int] NOT NULL ,
		[SIC_Job] [int] NOT NULL ,
		[Seq_ID] [int] NOT NULL ,
		[Frag_Scan_Number] [int] NOT NULL ,
		[NET_Obs] [real] NULL ,
		[Scan_Time_Peak_Apex] [real] NULL ,
		[Peak_Area] [float] NULL ,
		[Max_Value] [tinyint] NULL
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not create temporary table #StaleJobs'
		goto Done
	End

	CREATE UNIQUE CLUSTERED INDEX #IX_TmpSICStats_UniqueID ON #TmpSICStats
	(
		[Unique_ID]
	)

	--------------------------------------------------------------
	-- Create a temporary table to hold the SIC summary information
	--------------------------------------------------------------
	If Exists (select * from dbo.sysobjects where id = object_id(N'[#TmpSICStatsSummary]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		DROP TABLE [#TmpSICStatsSummary]

	CREATE TABLE [#TmpSICStatsSummary] (
		[Peptide_Hit_Job] [int] NOT NULL ,
		[SIC_Job] [int] NOT NULL ,
		[Seq_ID] [int] NOT NULL ,
		[NET_Obs_Min] [real] NULL ,
		[NET_Obs_Max] [real] NULL ,
		[NET_Obs_Avg] [real] NULL ,
		[Scan_Time_Peak_Apex_Min] [real] NULL ,
		[Scan_Time_Peak_Apex_Max] [real] NULL ,
		[Scan_Time_Peak_Apex_Avg] [real] NULL ,
		[Obs_Count] [int] NOT NULL ,
		[Frag_Scan_Number] [int] NOT NULL ,
		[Scan_Time_Peak_Apex_Obs] [real] NULL ,
		[Peak_Apex_Scan] [int] NULL ,

		[Peak_Scan_Start] [int] NULL ,
		[Peak_Scan_End] [int] NULL ,
		[Peak_Width_Base_Points] [int] NULL ,
		[Peak_Intensity] [float] NULL ,
		[Peak_SN_Ratio] [real] NULL ,
		[FWHM_In_Scans] [int] NULL ,
		[Peak_Area] [float] NULL ,
		[Peak_Baseline_Noise_Level] [real] NULL ,
		[Peak_Baseline_Noise_StDev] [real] NULL ,
		[Peak_Baseline_Points_Used] [smallint] NULL ,
		[StatMoments_Area] [real] NULL ,
		[CenterOfMass_Scan] [int] NULL ,
		[Peak_StDev] [real] NULL ,
		[Peak_Skew] [real] NULL ,
		[Peak_KSStat] [real] NULL ,
		[StatMoments_DataCount_Used] [smallint] NULL 
	)

	CREATE UNIQUE CLUSTERED INDEX #IX_TmpSICStatsSummary_Job_Seq_ID ON #TmpSICStatsSummary
	(
		[Peptide_Hit_Job], [Seq_ID]
	)


	CREATE INDEX #IX_TmpSICStatsSummary_SICJob_Frag_Scan_Number ON #TmpSICStatsSummary
	(
		[SIC_Job], [Frag_Scan_Number]
	)
	

	--------------------------------------------------------------
	-- Create a temporary table to hold the dataset stats for each job
	--------------------------------------------------------------
	If Exists (select * from dbo.sysobjects where id = object_id(N'[#TmpDataset_Info]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		DROP TABLE [#TmpDataset_Info]

	CREATE TABLE [#TmpDataset_Info] (
		[Peptide_Hit_Job] [int] NOT NULL ,
		[Instrument] [varchar](128)NULL ,
		[Acq_Time_Start] [datetime] NULL ,
		[LC Column] [varchar](128) NULL 
	)

	CREATE UNIQUE CLUSTERED INDEX #IX_TmpDataset_Info_Job ON #TmpDataset_Info
	(
		[Peptide_Hit_Job]
	)

	--------------------------------------------------------------
	-- Populate #TmpSICStats with the SIC stats
	-- If @UseCachedStates <> 0 then will use the SIC stats cached in T_Peptides
	--------------------------------------------------------------
	--
	/*
	declare @UseCachedStates tinyint
	set @UseCachedStates = 1
	if @UseCachedStates = 0
		INSERT INTO #TmpSICStats (
			Peptide_Hit_Job, SIC_Job, 
			Seq_ID, Frag_Scan_Number, NET_Obs, 
			Scan_Time_Peak_Apex, Peak_Area, Max_Value)
		SELECT JobTable.Job AS Peptide_Hit_Job, DSSIC.Job AS SIC_Job, 
			Pep.Seq_ID, DSSIC.Frag_Scan_Number, Pep.GANET_Obs, 
			DSS.Scan_Time, DSSIC.Peak_Area, 0 AS Max_Value
		FROM T_Analysis_Description JobTable INNER JOIN
			T_Datasets DatasetTable ON 
			JobTable.Dataset_ID = DatasetTable.Dataset_ID INNER JOIN
			T_Peptides Pep ON 
			JobTable.Job = Pep.Job INNER JOIN
			T_Dataset_Stats_SIC DSSIC ON 
			DatasetTable.SIC_Job = DSSIC.Job AND 
			Pep.Scan_Number = DSSIC.Frag_Scan_Number INNER JOIN
			T_Dataset_Stats_Scans DSS ON 
			DSSIC.Job = DSS.Job AND DSSIC.Optimal_Peak_Apex_Scan_Number = DSS.Scan_Number
		WHERE	JobTable.Job IN (137453, 137451, 137431, 137429, 137427, 137425, 137328, 137326, 137324, 137322) AND
				Pep.Seq_ID IN (1008,1039,18126) 
	Else
	*/
	
	declare @Sql varchar(4000)
	declare @sqlWhere varchar(7100)

	Set @Sql = ''
	
	Set @Sql = @Sql + ' INSERT INTO #TmpSICStats ('
	Set @Sql = @Sql +        ' Peptide_Hit_Job, SIC_Job,'
	Set @Sql = @Sql +        ' Seq_ID, Frag_Scan_Number, NET_Obs,'
	Set @Sql = @Sql +        ' Scan_Time_Peak_Apex, Peak_Area, Max_Value)'
	Set @Sql = @Sql + ' SELECT JobTable.Job AS Peptide_Hit_Job, DatasetTable.SIC_Job AS SIC_Job,'
	Set @Sql = @Sql +        ' Pep.Seq_ID, Pep.Scan_Number, Pep.GANET_Obs,'
	Set @Sql = @Sql +        ' Pep.Scan_Time_Peak_Apex, Pep.Peak_Area, 0 AS Max_Value'

	Set @Sql = @Sql + ' FROM DATABASE..T_Analysis_Description JobTable'
	Set @Sql = @Sql +      ' INNER JOIN #TmpQCJobList ON JobTable.Job = #TmpQCJobList.Job'
	Set @Sql = @Sql +      ' INNER JOIN DATABASE..T_Datasets DatasetTable ON JobTable.Dataset_ID = DatasetTable.Dataset_ID'
	Set @Sql = @Sql +      ' INNER JOIN DATABASE..T_Peptides Pep ON JobTable.Job = Pep.Job'

	-- Define the where clause using @SeqIDList
	Set @sqlWhere = 'WHERE Pep.Seq_ID In (' + @SeqIDList + ')'

	---------------------------------------------------
	-- Customize the columns for the given database
	---------------------------------------------------
	set @Sql = replace(@Sql, 'DATABASE..', '[' + @DBName + ']..')

	---------------------------------------------------
	-- Run the query to populate #TmpSICStats
	---------------------------------------------------
	If @previewSql <> 0
		Print @Sql + ' ' + @sqlWhere
	Else
		Exec (@Sql + ' ' + @sqlWhere)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	    

	--------------------------------------------------------------
	-- Determine the first occurence of the maximum area value 
	-- for each sequence in each job; update Max_Value for the appropriate rows
	--------------------------------------------------------------
	UPDATE #TmpSICStats
	SET Max_Value = 1
	FROM (	SELECT #TmpSICStats.SIC_Job, 
				   #TmpSICStats.Seq_ID, 
				   MIN(#TmpSICStats.Unique_ID) AS Unique_ID_Min
			FROM (	SELECT SIC_Job, Seq_ID, MAX(Peak_Area) AS Peak_Area_Max
					FROM #TmpSICStats
					GROUP BY SIC_Job, Seq_ID
				 ) LookupQ INNER JOIN #TmpSICStats ON 
				LookupQ.SIC_Job = #TmpSICStats.SIC_Job AND 
				LookupQ.Seq_ID = #TmpSICStats.Seq_ID AND 
				LookupQ.Peak_Area_Max = #TmpSICStats.Peak_Area
			GROUP BY #TmpSICStats.SIC_Job, 
					 #TmpSICStats.Seq_ID
		 ) OuterQ INNER JOIN #TmpSICStats ON 
		 OuterQ.Unique_ID_Min = #TmpSICStats.Unique_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	--------------------------------------------------------------
	-- Populate the SIC Stats Summary table
	--------------------------------------------------------------

	INSERT INTO #TmpSICStatsSummary (
		Peptide_Hit_Job, SIC_Job, Seq_ID, 
		NET_Obs_Min, NET_Obs_Max, NET_Obs_Avg, 
		Scan_Time_Peak_Apex_Min, Scan_Time_Peak_Apex_Max, Scan_Time_Peak_Apex_Avg, 
		Obs_Count, Frag_Scan_Number, Scan_Time_Peak_Apex_Obs)
	SELECT SS.Peptide_Hit_Job, SS.SIC_Job, SS.Seq_ID, 
		   MIN(NET_Obs), MAX(NET_Obs), CONVERT(real, AVG(NET_Obs)),
		   MIN(SS.Scan_Time_Peak_Apex), MAX(SS.Scan_Time_Peak_Apex), CONVERT(real, AVG(SS.Scan_Time_Peak_Apex)),
		   COUNT(Unique_ID), LookupQ.Frag_Scan_Number, LookupQ.Scan_Time_Peak_Apex
	FROM #TmpSICStats AS SS INNER JOIN
		 (	SELECT	Peptide_Hit_Job, Seq_ID, 
					MIN(Frag_Scan_Number) AS Frag_Scan_Number,
					MIN(#TmpSICStats.Scan_Time_Peak_Apex) AS Scan_Time_Peak_Apex
			FROM #TmpSICStats 
			WHERE Max_Value = 1
			GROUP BY Peptide_Hit_Job, Seq_ID
		 ) LookupQ ON SS.Peptide_Hit_Job = LookupQ.Peptide_Hit_Job AND 
		 SS.Seq_ID = LookupQ.Seq_ID
	GROUP BY SS.Peptide_Hit_Job, SS.SIC_Job, SS.Seq_ID, LookupQ.Frag_Scan_Number, LookupQ.Scan_Time_Peak_Apex  
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	

	--------------------------------------------------------------
	-- Link #TmpSICStatsSummary to T_Dataset_Stats_SIC and extract the SIC data for each job
	--------------------------------------------------------------	

	Set @Sql = ''
	Set @Sql = @Sql + ' UPDATE #TmpSICStatsSummary SET'
	Set @Sql = @Sql +    ' Peak_Scan_Start = DSS.Peak_Scan_Start,'
	Set @Sql = @Sql +    ' Peak_Scan_End = DSS.Peak_Scan_End,'
	Set @Sql = @Sql +    ' Peak_Apex_Scan = DSS.Optimal_Peak_Apex_Scan_Number,'
	Set @Sql = @Sql +    ' Peak_Intensity = DSS.Peak_Intensity,'
	Set @Sql = @Sql +    ' Peak_SN_Ratio = DSS.Peak_SN_Ratio,'
	Set @Sql = @Sql +    ' FWHM_In_Scans = DSS.FWHM_In_Scans,'
	Set @Sql = @Sql +    ' Peak_Area = DSS.Peak_Area,'
	Set @Sql = @Sql +    ' Peak_Baseline_Noise_Level = DSS.Peak_Baseline_Noise_Level,'
	Set @Sql = @Sql +    ' Peak_Baseline_Noise_StDev = DSS.Peak_Baseline_Noise_StDev,'
	Set @Sql = @Sql +    ' Peak_Baseline_Points_Used = DSS.Peak_Baseline_Points_Used,'
	Set @Sql = @Sql +    ' StatMoments_Area = DSS.StatMoments_Area,'
	Set @Sql = @Sql +    ' CenterOfMass_Scan = DSS.CenterOfMass_Scan,'
	Set @Sql = @Sql +    ' Peak_StDev = DSS.Peak_StDev,'
	Set @Sql = @Sql +    ' Peak_Skew = DSS.Peak_Skew,'
	Set @Sql = @Sql +    ' Peak_KSStat = DSS.Peak_KSStat,'
	Set @Sql = @Sql +    ' StatMoments_DataCount_Used = DSS.StatMoments_DataCount_Used'
    Set @Sql = @Sql + ' FROM #TmpSICStatsSummary AS SS'
	Set @Sql = @Sql +    ' INNER JOIN DATABASE..T_Dataset_Stats_SIC DSS With (NoLock) ON'
	Set @Sql = @Sql +    ' SS.Frag_Scan_Number = DSS.Frag_Scan_Number AND SS.SIC_Job = DSS.Job'

	set @Sql = replace(@Sql, 'DATABASE..', '[' + @DBName + ']..')
	
	If @previewSql <> 0
		Print @Sql
	Else
		Exec (@Sql)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	

	--------------------------------------------------------------
	-- Link #TmpSICStatsSummary to T_Dataset_Stats_Scans to compute Peak_Width_Base_Points for each job
	--------------------------------------------------------------	


	Set @Sql = ''
	Set @Sql = @Sql + ' UPDATE #TmpSICStatsSummary SET'
	Set @Sql = @Sql +    ' Peak_Width_Base_Points = LookupQ.Peak_Width_Base_Points'
	Set @Sql = @Sql + ' FROM #TmpSICStatsSummary INNER JOIN ('
	Set @Sql = @Sql +    ' SELECT DS_SIC.Job, DS_SIC.Frag_Scan_Number,'
	Set @Sql = @Sql +           ' COUNT(DSS.Scan_Number) AS Peak_Width_Base_Points'
	Set @Sql = @Sql +    ' FROM DATABASE..T_Dataset_Stats_SIC DS_SIC INNER JOIN'
	Set @Sql = @Sql +         ' DATABASE..T_Dataset_Stats_Scans DSS ON DS_SIC.Job = DSS.Job AND'
	Set @Sql = @Sql +         ' (DSS.Scan_Number BETWEEN DS_SIC.Peak_Scan_Start AND DS_SIC.Peak_Scan_End) AND'
	Set @Sql = @Sql +         ' DSS.Scan_Type = 1'
	Set @Sql = @Sql +    ' WHERE DS_SIC.Job IN (SELECT DISTINCT SIC_Job FROM #TmpSICStatsSummary)'
	Set @Sql = @Sql +    ' GROUP BY DS_SIC.Job, DS_SIC.Frag_Scan_Number'
	Set @Sql = @Sql +    ' ) LookupQ ON #TmpSICStatsSummary.SIC_Job = LookupQ.Job AND'
	Set @Sql = @Sql +                '  #TmpSICStatsSummary.Frag_Scan_Number = LookupQ.Frag_Scan_Number'

	set @Sql = replace(@Sql, 'DATABASE..', '[' + @DBName + ']..')
	If @previewSql <> 0
		Print @Sql
	Else
		Exec (@Sql)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	

	--------------------------------------------------------------
	-- Cache the dataset-related information
	--------------------------------------------------------------
	--
	Set @Sql = ''
	
	Set @Sql = @Sql + ' INSERT INTO #TmpDataset_Info ('
	Set @Sql = @Sql +   ' Peptide_Hit_Job, Instrument, Acq_Time_Start, [LC Column])'
	Set @Sql = @Sql + ' SELECT Peptide_Hit_Job, TAD.Instrument, DS.Acq_Time_Start, DDR.[LC Column]'
	Set @Sql = @Sql + ' FROM (  SELECT DISTINCT Peptide_Hit_Job'
	Set @Sql = @Sql +         ' FROM #TmpSICStatsSummary) JobQ'
	Set @Sql = @Sql +      ' INNER JOIN DATABASE..T_Analysis_Description TAD ON JobQ.Peptide_Hit_Job = TAD.Job'
	Set @Sql = @Sql +      ' INNER JOIN DATABASE..T_Datasets DS ON TAD.Dataset_ID = DS.Dataset_ID'
	Set @Sql = @Sql +      ' INNER JOIN MT_Main.dbo.V_DMS_Dataset_Detail_Report DDR ON DS.Dataset_ID = DDR.ID'

	set @Sql = replace(@Sql, 'DATABASE..', '[' + @DBName + ']..')
	If @previewSql <> 0
		Print @Sql
	Else
		Exec (@Sql)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	--------------------------------------------------------------
	-- Link #TmpSICStatsSummary with #TmpDataset_Info and return the results
	--------------------------------------------------------------
	--
	SELECT DatasetInfoQ.Instrument, 
		'''' + DatasetInfoQ.[LC Column] + '''' as [LC Column],
		DatasetInfoQ.Acq_Time_Start AS [Acquisition Date], 
		SS.Peptide_Hit_Job AS MSMS_Job, 
		SS.Seq_ID, 
		SS.NET_Obs_Min, 
		SS.NET_Obs_Max, 
		SS.NET_Obs_Avg, 
		SS.Scan_Time_Peak_Apex_Min, 
		SS.Scan_Time_Peak_Apex_Max, 
		SS.Scan_Time_Peak_Apex_Avg, 
		SS.Obs_Count, 

		SS.Scan_Time_Peak_Apex_Obs, SS.Peak_Apex_Scan,
		SS.Peak_Scan_Start, SS.Peak_Scan_End,
		SS.Peak_Width_Base_Points,

		SS.Peak_Intensity, SS.Peak_SN_Ratio, 
		SS.FWHM_In_Scans, SS.Peak_Area, 
		SS.Peak_Baseline_Noise_Level, 
		SS.Peak_Baseline_Noise_StDev, 
		SS.Peak_Baseline_Points_Used, SS.StatMoments_Area, 
		SS.CenterOfMass_Scan, SS.Peak_StDev, SS.Peak_Skew, 
		SS.Peak_KSStat, SS.StatMoments_DataCount_Used
	FROM #TmpSICStatsSummary SS INNER JOIN
		#TmpDataset_Info AS DatasetInfoQ ON SS.Peptide_Hit_Job = DatasetInfoQ.Peptide_Hit_Job
	ORDER BY DatasetInfoQ.Instrument, SS.Seq_ID, DatasetInfoQ.Acq_Time_Start
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'QCMSMSSeqStatDetails', @DBName, @UsageMessage	

	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[QCMSMSSeqStatDetails] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QCMSMSSeqStatDetails] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QCMSMSSeqStatDetails] TO [MTS_DB_Lite] AS [dbo]
GO

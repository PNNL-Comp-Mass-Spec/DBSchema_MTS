/****** Object:  StoredProcedure [dbo].[QueryAllMassTagDatabasesForPeakMatchingStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure QueryAllMassTagDatabasesForPeakMatchingStats
/****************************************************
** 
**	Desc: Queries each database to obtain stats on the 
**		  peak matching tasks in each DB, storing the results 
**		  in a table in this DB
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	08/22/2006
**			08/28/2006 mem - Added columns Mass_Error_Avg, Mass_Error_StDev, NET_Error_Avg, NET_Error_StDev
**    
*****************************************************/
(
	@MinimumDiscriminantScore real = 0,
	@MinimumPMTQualityScore real = 2,
	@MinimumSLiCScore real = 0.35,
	@DBsToProcess int = 0,						-- If this number is > 0, then only processes the first @DBsToProcess databases, ordered by MTL_ID
	@IncludeUnused tinyint = 1,
	@DBFilterList varchar(1024) = '',
	@DBsToSkip varchar(1024) = 'MT_Mixed_P191, MT_Shewanella_X202, MT_S_Typhimurium_X245',
	@infoOnly tinyint = 0,						-- If 0, then only displays the results; if 1, then populates T_Peak_Matching_Stats_by_DB with the results
	@PreviewSql tinyint = 0,
	@message varchar(255) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int

	declare @CurrentDBName varchar(128)
	declare @CurrentDBID int
	set @CurrentDBID = 0

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)

	-----------------------------------------------------------
	-- Create the output table
	-----------------------------------------------------------

	If @infoOnly = 0 And Not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[T_Peak_Matching_Stats_by_DB]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	Begin
	--	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[T_Peak_Matching_Stats_by_DB]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	--		drop table [dbo].[T_Peak_Matching_Stats_by_DB]

		CREATE TABLE [dbo].[T_Peak_Matching_Stats_by_DB] (
			[MTDB] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
			[Job] [int] NOT NULL ,
			[Dataset] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
			[MDID] [int] NOT NULL ,
			[MD_Type_Name] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
			[Ini_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
			[MD_Peaks_Count] [int] NULL ,
			[MD_Tool_Version] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
			[MD_Comparison_Mass_Tag_Count] [int] NOT NULL ,
			[Minimum_High_Normalized_Score] [real] NOT NULL ,
			[Minimum_High_Discriminant_Score] [real] NOT NULL ,
			[Minimum_PMT_Quality_Score] [real] NOT NULL ,
			[MD_NetAdj_NET_Min] [numeric](9, 5) NULL ,
			[MD_NetAdj_NET_Max] [numeric](9, 5) NULL ,
			[MD_MMA_TolerancePPM] [numeric](9, 4) NULL ,
			[MD_NET_Tolerance] [numeric](9, 5) NULL ,
			[Unique_PMTs_Matched] [int] NULL ,
			[Last_Affected] [datetime] NOT NULL  CONSTRAINT [DF_T_Peak_Matching_Stats_by_DB_Last_Affected] DEFAULT (getdate())
		) ON [PRIMARY]

		ALTER TABLE [dbo].[T_Peak_Matching_Stats_by_DB] WITH NOCHECK ADD 
			CONSTRAINT [PK_T_Peak_Matching_Stats_by_DB] PRIMARY KEY  CLUSTERED (MTDB, Job, MDID)
	End
	
	CREATE TABLE #DBsToProcess (
		MTL_Name varchar(128),
		MTL_ID int
	)


	-----------------------------------------------------------
	-- process each entry in T_MT_Database_List
	-----------------------------------------------------------
	declare @done int
	declare @processCount int
	declare @Sql varchar(4096)

	Declare @FilterDBWhereClause varchar(2048)
	Declare @SkipDBWhereClause varchar(2048)

	Exec Prism_IFC.dbo.ConvertListToWhereClause @DBFilterList, 'MTL_Name', @entryListWhereClause = @FilterDBWhereClause OUTPUT
	Exec Prism_IFC.dbo.ConvertListToWhereClause @DBsToSkip, 'MTL_Name', @entryListWhereClause = @SkipDBWhereClause OUTPUT
	
	set @sql = ''
	Set @Sql = @Sql + ' INSERT INTO #DBsToProcess (MTL_Name, MTL_ID)'

	Set @Sql = @Sql + ' SELECT MTL_Name, MTL_ID'
	Set @Sql = @Sql + ' FROM T_MT_Database_List'
	
	If @IncludeUnused = 0
		Set @Sql = @Sql + ' WHERE MTL_State < 10'
	Else
		Set @Sql = @Sql + ' WHERE MTL_State <= 10'

	If Len(@FilterDBWhereClause) > 0
		Set @Sql = @Sql + ' AND ' + @FilterDBWhereClause
		
	If Len(@SkipDBWhereClause) > 0
		Set @Sql = @Sql + ' AND NOT ' + @SkipDBWhereClause

	Exec (@Sql)

	set @done = 0
	set @processCount = 0

	While @done = 0 and @myError = 0  
	Begin --<a>

		-----------------------------------------------------------
		-- get next available entry from mass tag database list table
		-----------------------------------------------------------
		--
		SELECT TOP 1 @CurrentDBName = MTL_Name, @CurrentDBID = MTL_ID
		FROM  #DBsToProcess
		WHERE MTL_ID > @CurrentDBID
		ORDER BY MTL_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from MT DB table'
			set @myError = 39
			goto Done
		end
		
		-- We are done if we didn't find any more records
		--
		if @myRowCount = 0 OR (@DBsToProcess > 0 AND @ProcessCount >= @DBsToProcess)
			set @done = 1
		else
		Begin

			-- Lookup the DB Schema Version
			--
			exec GetDBSchemaVersionByDBName @CurrentDBName, @DBSchemaVersion output

			Set @processCount = @processCount + 1

			If @DBSchemaVersion >= 2
			Begin
				-- Grab data and place in T_Peak_Matching_Stats_by_DB
				--

				If @infoOnly = 0
				Begin
					DELETE FROM T_Peak_Matching_Stats_by_DB
					WHERE MTDB = @CurrentDBName
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				End

				Set @Sql = ''
				If @infoOnly = 0
				Begin
					Set @Sql = @Sql + ' INSERT INTO T_Peak_Matching_Stats_by_DB (MTDB, Job, Dataset,'
					Set @Sql = @Sql +          ' MDID, MD_Type_Name, Ini_File_Name, MD_Peaks_Count, MD_Tool_Version,'
					Set @Sql = @Sql +          ' MD_Comparison_Mass_Tag_Count, Minimum_High_Normalized_Score,'
					Set @Sql = @Sql +          ' Minimum_High_Discriminant_Score, Minimum_PMT_Quality_Score,'
					Set @Sql = @Sql +          ' MD_NetAdj_NET_Min, MD_NetAdj_NET_Max,'
					Set @Sql = @Sql +          ' MD_MMA_TolerancePPM, MD_NET_Tolerance, Unique_PMTs_Matched,'
					Set @Sql = @Sql +          ' Mass_Error_Avg, Mass_Error_StDev, NET_Error_Avg, NET_Error_StDev)'
				End
				Set @Sql = @Sql + ' SELECT ''' + @CurrentDBName + ''', FAD.Job, FAD.Dataset,'
				Set @Sql = @Sql +    ' MMD.MD_ID, MTN.MD_Type_Name, MMD.Ini_File_Name,'
				Set @Sql = @Sql +    ' MMD.MD_Peaks_Count, MMD.MD_Tool_Version,'
				Set @Sql = @Sql +    ' MMD.MD_Comparison_Mass_Tag_Count,'
				Set @Sql = @Sql +    ' MMD.Minimum_High_Normalized_Score,'
				Set @Sql = @Sql +    ' MMD.Minimum_High_Discriminant_Score,'
				Set @Sql = @Sql +    ' MMD.Minimum_PMT_Quality_Score,'
				Set @Sql = @Sql +    ' MMD.MD_NetAdj_NET_Min, MMD.MD_NetAdj_NET_Max,'
				Set @Sql = @Sql +    ' MMD.MD_MMA_TolerancePPM, MMD.MD_NET_Tolerance,'
				Set @Sql = @Sql +    ' COUNT(DISTINCT FURD.Mass_Tag_ID) AS Unique_PMTs_Matched,'
				Set @Sql = @Sql +    ' AVG(ABS((MT.Monoisotopic_Mass + FURD.Mass_Tag_Mod_Mass - FUR.Class_Mass)*1000000/(MT.Monoisotopic_Mass + FURD.Mass_Tag_Mod_Mass))) AS Mass_Error_Avg, '
				Set @Sql = @Sql +    ' STDEV(ABS((MT.Monoisotopic_Mass + FURD.Mass_Tag_Mod_Mass - FUR.Class_Mass)*1000000/(MT.Monoisotopic_Mass + FURD.Mass_Tag_Mod_Mass))) AS Mass_Error_StDev, '
				Set @Sql = @Sql +    ' AVG(ABS(FUR.ElutionTime - FURD.Expected_NET)) AS NET_Error_Avg, '
				Set @Sql = @Sql +    ' STDEV(ABS(FUR.ElutionTime - FURD.Expected_NET)) AS NET_Error_StDev'
				Set @Sql = @Sql + ' FROM DATABASE..T_Match_Making_Description MMD INNER JOIN'
				Set @Sql = @Sql +      ' DATABASE..T_FTICR_UMC_Results FUR ON MMD.MD_ID = FUR.MD_ID INNER JOIN'
				Set @Sql = @Sql +      ' DATABASE..T_FTICR_UMC_ResultDetails FURD ON FUR.UMC_Results_ID = FURD.UMC_Results_ID INNER JOIN'
				Set @Sql = @Sql +      ' DATABASE..T_Mass_Tags MT ON FURD.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN'
				Set @Sql = @Sql +      ' DATABASE..T_FTICR_Analysis_Description FAD ON MMD.MD_Reference_Job = FAD.Job INNER JOIN'
				Set @Sql = @Sql +      ' DATABASE..T_MMD_Type_Name MTN ON MMD.MD_Type = MTN.MD_Type'
				Set @Sql = @Sql + ' WHERE FURD.Match_Score >= ' + Convert(varchar(12), @MinimumSLiCScore) + ' AND '
				Set @Sql = @Sql +       ' MT.PMT_Quality_Score >= ' + Convert(varchar(12), @MinimumPMTQualityScore) + ' AND '
				Set @Sql = @Sql +       ' MT.High_Discriminant_Score >= ' + Convert(varchar(12), @MinimumDiscriminantScore)
				Set @Sql = @Sql + ' GROUP BY FAD.Job, FAD.Dataset, MMD.MD_ID,'
				Set @Sql = @Sql +       ' MTN.MD_Type_Name, MMD.Ini_File_Name,'
				Set @Sql = @Sql +       ' MMD.MD_Peaks_Count, MMD.MD_Tool_Version,'
				Set @Sql = @Sql +       ' MMD.MD_Comparison_Mass_Tag_Count,'
				Set @Sql = @Sql +       ' MMD.Minimum_High_Normalized_Score,'
				Set @Sql = @Sql +       ' MMD.Minimum_High_Discriminant_Score,'
				Set @Sql = @Sql +       ' MMD.Minimum_PMT_Quality_Score,'
				Set @Sql = @Sql +       ' MMD.MD_NetAdj_NET_Min, MMD.MD_NetAdj_NET_Max,'
				Set @Sql = @Sql +       ' MMD.MD_MMA_TolerancePPM, MMD.MD_NET_Tolerance'
				Set @Sql = @Sql + ' ORDER BY COUNT(DISTINCT FURD.Mass_Tag_ID) DESC'

				Set @Sql = Replace (@Sql, 'DATABASE..', '[' + @CurrentDBName + ']..')
				
				If @PreviewSql <> 0
					print @Sql
				Else
				Begin
					Exec (@sql)
					
					-- Compute the match score
					-- The score is: 
					--  Unique_PMTs_Matched / Max(Unique_PMTs_Matched) / 2 + 
					--  ((5 - PMS.Mass_Error_Avg) / 5) / 4 + 
					--  ((0.05 - PMS.NET_Error_Avg) / 0.05) / 4
					-- Where Max(Unique_PMTs_Matched) is computed separately for each database
					-- Notice that in this score the number of PMTs matched makes up 50% of the score,
					--  the mass error makes up 25% of the score, and the NET error makes up 25% of the score
					--
					UPDATE T_Peak_Matching_Stats_by_DB
					SET PM_Match_Score = ScoreQ.Match_Count_Score / 2 + CASE WHEN ScoreQ.Mass_Error_Score
						> 0 THEN ScoreQ.Mass_Error_Score / 4 ELSE 0 END + CASE WHEN
						ScoreQ.NET_Error_Score > 0 THEN ScoreQ.NET_Error_Score / 4
						ELSE 0 END
					FROM (	SELECT PMS.MTDB, PMS.Job, PMS.MDID, 
								PMS.Unique_PMTs_Matched / CONVERT(real, LookupQ.Max_Match_Count) AS Match_Count_Score, 
								(5 - PMS.Mass_Error_Avg) / 5 AS Mass_Error_Score, 
								(0.05 - PMS.NET_Error_Avg) / 0.05 AS NET_Error_Score
							FROM T_Peak_Matching_Stats_by_DB PMS INNER JOIN
									(SELECT MTDB, MAX(Unique_PMTs_Matched) AS Max_Match_Count
									FROM T_Peak_Matching_Stats_by_DB
									GROUP BY MTDB
									) LookupQ ON PMS.MTDB = LookupQ.MTDB COLLATE SQL_Latin1_General_CP1_CI_AS
							WHERE PMS.MTDB = @CurrentDBName AND NOT PMS.Mass_Error_Avg IS NULL
						) ScoreQ INNER JOIN
						T_Peak_Matching_Stats_by_DB PMSUpdate ON 
							ScoreQ.MTDB COLLATE SQL_Latin1_General_CP1_CI_AS = PMSUpdate.MTDB AND 
							ScoreQ.Job = PMSUpdate.Job AND 
							ScoreQ.MDID = PMSUpdate.MDID
    
				End
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End
		End

	End --<a>

Done:

	if @myError <> 0
		SELECT @message As Message
	else
		SELECT 'Done: Processed ' + Convert(varchar(9), @processCount) + ' databases' As Message

	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[QueryAllMassTagDatabasesForPeakMatchingStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QueryAllMassTagDatabasesForPeakMatchingStats] TO [MTS_DB_Lite] AS [dbo]
GO

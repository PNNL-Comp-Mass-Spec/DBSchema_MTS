/****** Object:  StoredProcedure [dbo].[ExportUMCCrosstab] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure dbo.ExportUMCCrosstab
/****************************************************	
**  Desc:	Creates a crosstab of the LC-MS Features (aka UMCs) identified
**			in the specified MDID list
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	01/28/2009
**			01/29/2009 mem - Updated T_Tmp_ClusteredUMC_Mapping to include EntryID
**
****************************************************/
(
	@MDIDs varchar(8000) = '',
	@BaseMDID int = -1,			-- If -1, then chooses the MDID with the most UMCs as the base
	@MassTolerancePPM real = 8,
	@NETTolerance real = 0.05,
	@LogProgress tinyint = 1,
	@LogIntervalSeconds int = 30,
	@infoOnly tinyint = 0,
	@UseExistingClusteredUMCsTable tinyint = 0,
	@message varchar(512)='' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @MDIDContinue int
	Declare @MDIDEntryIDSorted int
	Declare @MDID int

	Declare @Continue int
	Declare @EntryID int
	Declare @ClusterID int
	Declare @UMCIndex int
	Declare @Mass float
	Declare @NET real
	Declare @Abundance float

	Declare @LastLogTime datetime
	
	Declare @TaskProcessed int
	Declare @TaskTotal int

	Declare @UMCsProcessed int
	Declare @CurrentUMCCount int
	Declare @TotalUMCs int

	Declare @PercentComplete Decimal(9,2)
	
	Declare @PivotFieldsA varchar(max)
	Declare @PivotFieldsB varchar(max)
	
	Declare @S varchar(max)
	
	Set @TaskProcessed = 0
	Set @TaskTotal = 1
	
	Set @CurrentUMCCount = 0
	Set @UMCsProcessed = 0
	Set @TotalUMCs = 1

	Set @PercentComplete = 0
	
	-------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------	
	Set @MDIDs = IsNull(@MDIDs, '')
	Set @BaseMDID = IsNull(@BaseMDID, -1)
	Set @MassTolerancePPM = IsNull(@MassTolerancePPM, 3)
	Set @NETTolerance = IsNull(@NETTolerance, 0.015) 
	Set @LogProgress = IsNull(@LogProgress, 0)
	
	Set @LogIntervalSeconds = IsNull(@LogIntervalSeconds, 15)
	If @LogIntervalSeconds < 15
		Set @LogIntervalSeconds = 15
	
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @UseExistingClusteredUMCsTable = IsNull(@UseExistingClusteredUMCsTable, 0)
	Set @message = ''
	
	If @MDIDs = ''
	Begin
		Set @message = '@MDIDs is empty; nothing to do'
		Goto Done
	End
	
	Set @LastLogTime = GetDate()

	-------------------------------------------------
	-- Create the working tables
	-------------------------------------------------	
	--
	if exists (select * from dbo.sysobjects where id = object_id(N'[T_Tmp_MDIDList]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [T_Tmp_MDIDList]

	CREATE TABLE T_Tmp_MDIDList (
		MD_ID int NOT NULL,
		UMC_Count int NULL,
		Refine_Mass_Cal_PPMShift real NULL,
		MDIDEntryIDSorted int NULL
	)

	CREATE UNIQUE INDEX IX_Tmp_MDIDList_MDID ON T_Tmp_MDIDList (MD_ID ASC)
	CREATE INDEX IX_Tmp_MDIDList_MDIDEntryIDSorted ON T_Tmp_MDIDList (MDIDEntryIDSorted ASC)

	if exists (select * from dbo.sysobjects where id = object_id(N'[T_TmpCurrentUMCs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [T_TmpCurrentUMCs]

	CREATE TABLE T_TmpCurrentUMCs (
		UMCIndex int,
		Mass float, 
		NET real, 
		Abundance float,
		EntryIDSorted int
	)

	CREATE CLUSTERED INDEX IX_TmpCurrentUMCs_EntryIDSorted ON T_TmpCurrentUMCs (EntryIDSorted ASC)


	If @UseExistingClusteredUMCsTable = 0
	Begin -- <DoNotUseExistingClusteredUMCsTable>
	
		if exists (select * from dbo.sysobjects where id = object_id(N'[T_Tmp_ClusteredUMCs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [T_Tmp_ClusteredUMCs]
		
		CREATE TABLE T_Tmp_ClusteredUMCs (
			ClusterID int identity (1,1), 
			Mass float, 
			NET real,
			MDID_Count_Distinct int NULL,
			Member_Count int NULL,
			Mass_Avg float NULL,
			NET_Avg real NULL,
			Mass_StDev float NULL,
			NET_StDev float NULL,
			Abundance_Avg float NULL,
			Abundance_Sum float NULL
		)

		CREATE INDEX IX_Tmp_ClusteredUMCs_ClusterID ON T_Tmp_ClusteredUMCs (ClusterID ASC)
		CREATE INDEX IX_Tmp_ClusteredUMCs_Mass ON T_Tmp_ClusteredUMCs (Mass ASC)


		if exists (select * from dbo.sysobjects where id = object_id(N'[T_Tmp_ClusteredUMC_Mapping]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [T_Tmp_ClusteredUMC_Mapping]

		CREATE TABLE T_Tmp_ClusteredUMC_Mapping (
			ClusterID int,
			MDID int,
			UMCIndex int,
			Abundance float,
			EntryID int identity(1,1)
		)


		if exists (select * from dbo.sysobjects where id = object_id(N'[T_Tmp_ClusteredUMC_Matches]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [T_Tmp_ClusteredUMC_Matches]

		CREATE TABLE T_Tmp_ClusteredUMC_Matches (
			ClusterID int NOT NULL, 
			Mass_Tag_ID int NOT NULL, 
			SLiC_Score_Max real
		)

		CREATE CLUSTERED INDEX IX_Tmp_ClusteredUMC_Matches_ClusterID ON T_Tmp_ClusteredUMC_Matches (ClusterID ASC)
		CREATE INDEX IX_Tmp_ClusteredUMC_Matches_Mass_Tag_ID ON T_Tmp_ClusteredUMC_Matches (Mass_Tag_ID ASC)
	
	End -- </DoNotUseExistingClusteredUMCsTable>
	
	-------------------------------------------------	
	-- Populate T_Tmp_MDIDList
	-------------------------------------------------
	
	INSERT INTO T_Tmp_MDIDList (MD_ID)
	SELECT Value
	FROM dbo.udfParseDelimitedIntegerList(@MDIDs, ',')
	--
	Select @myError = @@Error, @myRowCount = @@RowCount
	
	If @myError <> 0
	Begin
		Set @message = 'Error parsing the MDID list'
		Goto Done
	End
	
	-- Delete invalid entries from T_Tmp_MDIDList
	DELETE T_Tmp_MDIDList
	FROM T_Tmp_MDIDList L LEFT OUTER JOIN T_Match_Making_Description MMD ON L.MD_ID = MMD.MD_ID
	WHERE MMD.MD_ID IS NULL
	--
	Select @myError = @@Error, @myRowCount = @@RowCount
	
	If @myRowCount > 0
	Begin
		Set @message = 'Deleted invalid entries from the MDID List; entry count removed: ' + Convert(varchar(12), @myRowCount)
		Print @message
		Set @message = ''
	End

	If @UseExistingClusteredUMCsTable = 0
	Begin -- <DoNotUseExistingClusteredUMCsTable>
	
		-------------------------------------------------	
		-- Populate UMC_Count and Refine_Mass_Cal_PPMShift in T_Tmp_MDIDList
		-------------------------------------------------
		
		UPDATE T_Tmp_MDIDList
		SET UMC_Count = MMD.MD_UMC_Count,
			Refine_Mass_Cal_PPMShift = MMD.Refine_Mass_Cal_PPMShift
		FROM T_Match_Making_Description MMD INNER JOIN
			T_Tmp_MDIDList ML ON 
			MMD.MD_ID = ML.MD_ID
		--
		Select @myError = @@Error, @myRowCount = @@RowCount
	  
		Set @TaskTotal = @myRowCount

		-- Count the number of UMCs that will be processed
		--	
		SELECT @TotalUMCs = COUNT(*)
		FROM T_FTICR_UMC_Results FUR
			INNER JOIN T_Tmp_MDIDList ML
			ON FUR.MD_ID = ML.MD_ID
		
		
		-------------------------------------------------	
		-- Possibly update @BaseMDID
		-------------------------------------------------

		If @BaseMDID >= 0 AND NOT EXISTS (SELECT * FROM T_Tmp_MDIDList WHERE MD_ID = @BaseMDID)
		Begin
			Set @message = '@BaseMDID value (' + Convert(varchar(12), @BaseMDID) + ') not found in the MDID List; will use the MDID with the most features'
			Print @message
			Set @message = ''
			Set @BaseMDID = -1
		End
		
		If @BaseMDID < 0
		Begin
			SELECT TOP 1 @BaseMDID = MD_ID
			FROM T_Tmp_MDIDList
			ORDER BY Abs(Refine_Mass_Cal_PPMShift) DESC
			--
			Select @myError = @@Error, @myRowCount = @@RowCount
		End

		-------------------------------------------------
		-- Process each of the entries in T_Tmp_MDIDList, processing them
		--  by increasing value of Abs(Refine_Mass_Cal_PPMShift)
		-- However, we want to start with @BaseMDID
		-------------------------------------------------

		-- Populate EntryIDSorted in T_Tmp_MDIDList
		--
		UPDATE T_Tmp_MDIDList
		SET MDIDEntryIDSorted = CASE
								WHEN M.MD_ID = @BaseMDID THEN 1
								ELSE SortQ.EntryID + 1
							END
		FROM T_Tmp_MDIDList M
			INNER JOIN ( SELECT MD_ID,
								Row_Number() OVER ( ORDER BY Abs(Refine_Mass_Cal_PPMShift) ) AS EntryID
						FROM T_Tmp_MDIDList ) SortQ
			ON M.MD_ID = SortQ.MD_ID
		--
		Select @myError = @@Error, @myRowCount = @@RowCount

		If @infoOnly <> 0
		Begin
			SELECT *
			FROM T_Tmp_MDIDList
			ORDER BY MDIDEntryIDSorted
			
			SELECT @TaskTotal AS Total_MDIDs, @TotalUMCs AS TotalUMCs
			
			Goto Done
		End
		
		
		-------------------------------------------------
		-- Now step through the entries in T_Tmp_MDIDList
		-------------------------------------------------
		
		Set @MDIDEntryIDSorted = 0
		Set @MDIDContinue = 1
		
		While @MDIDContinue = 1
		Begin -- <a>
			
			-- Get the next MDID
			--
			SELECT TOP 1 
					@MDIDEntryIDSorted = MDIDEntryIDSorted,
					@MDID = MD_ID
			FROM T_Tmp_MDIDList
			WHERE MDIDEntryIDSorted > @MDIDEntryIDSorted
			ORDER BY MDIDEntryIDSorted
			--
			Select @myError = @@Error, @myRowCount = @@RowCount
			
			If @myRowCount = 0
				Set @MDIDContinue = 0
			Else
			Begin -- <b>
				
				-- Cache the UMCs for @MDID
				
				TRUNCATE TABLE T_TmpCurrentUMCs
				
				INSERT INTO T_TmpCurrentUMCs (UMCIndex, Mass, NET, Abundance, EntryIDSorted)			
				SELECT	UMC_Ind, 
						Class_Mass,
						ElutionTime,
						Class_Abundance,
						Row_Number() OVER (ORDER BY Class_Abundance DESC)
				FROM T_FTICR_UMC_Results
				WHERE (MD_ID = @MDID)
				--
				Select @myError = @@Error, @myRowCount = @@RowCount
				--
				Set @CurrentUMCCount = @myRowCount

				-- Now process each of the entries in T_TmpCurrentUMCs
				--			
				Set @EntryID = 0
				Set @Continue = 1
				While @Continue = 1
				Begin -- <c>
					SELECT TOP 1 
							@EntryID = EntryIDSorted,
							@UMCIndex = UMCIndex,
							@Mass = Mass, 
							@NET = NET,
							@Abundance = Abundance
					FROM T_TmpCurrentUMCs
					WHERE EntryIDSorted > @EntryID
					ORDER BY EntryIDSorted
					--
					Select @myError = @@Error, @myRowCount = @@RowCount
					
					If @myRowCount = 0
						Set @Continue = 0
					Else
					Begin -- <d>
						-- Compare @Mass and @NET to the entries in T_Tmp_ClusteredUMCs
						Set @ClusterID = 0
						SELECT @ClusterID = ClusterID
						FROM T_Tmp_ClusteredUMCs C
						WHERE ABS(C.Mass - @Mass) <= @Mass / 1e6 * @MassTolerancePPM AND
							ABS(C.NET - @NET) <= @NETTolerance

						If @ClusterID > 0
						Begin -- <e1>
							-- Existing cluster was matched
							-- Add a new entry to T_Tmp_ClusteredUMC_Mapping
							--
							INSERT INTO T_Tmp_ClusteredUMC_Mapping (UMCIndex, MDID, ClusterID, Abundance)
							VALUES (@UMCIndex, @MDID, @ClusterID, @Abundance)
						End -- </e1>
						Else
						Begin -- <e2>
							-- No matching clusters; add a new entry to T_Tmp_ClusteredUMCs and T_Tmp_ClusteredUMC_Mapping
							--
							INSERT INTO T_Tmp_ClusteredUMCs (Mass, NET)
							VALUES (@Mass, @NET)
							--
							Set @ClusterID = SCOPE_IDENTITY()
										
							INSERT INTO T_Tmp_ClusteredUMC_Mapping (UMCIndex, MDID, ClusterID, Abundance)
							VALUES (@UMCIndex, @MDID, @ClusterID, @Abundance)
							
						End -- </e2>
					End  -- </d>
					
					Set @UMCsProcessed = @UMCsProcessed + 1
					
					If DateDiff(second, @LastLogTime, GetDate()) >= @LogIntervalSeconds
					Begin
						Set @LastLogTime = GetDate()
						Set @PercentComplete = @UMCsProcessed / Convert(real, @TotalUMCs) * 100
						Set @message = '...Processing: ' + Convert(varchar(12), @PercentComplete) + '% complete; ' + Convert(varchar(12), @TaskProcessed) + ' of ' + Convert(varchar(12), @TaskTotal) + ' completed'
						
						If @LogProgress = 0
							Print @message
						Else
							Exec PostLogEntry 'Progress', @message, 'ExportUMCCrosstab'
					End
						
				End -- </c>
			End -- </b>

			Set @TaskProcessed = @TaskProcessed + 1

		End -- </a>

		-------------------------------------------------
		-- Update the Mass and NET statistics in T_Tmp_ClusteredUMCs
		-------------------------------------------------
		--
		UPDATE T_Tmp_ClusteredUMCs
		SET MDID_Count_Distinct = StatsQ.MDID_Count_Distinct,
			Member_Count = StatsQ.Member_Count,
			Mass_Avg = StatsQ.Mass_Avg,
			NET_Avg = StatsQ.NET_Avg,
			Mass_StDev = StatsQ.Mass_StDev,
			NET_StDev = StatsQ.NET_StDev,
			Abundance_Avg = StatsQ.Abundance_Avg,
			Abundance_Sum = StatsQ.Abundance_Sum
		FROM T_Tmp_ClusteredUMCs Target
			INNER JOIN ( SELECT C.ClusterID,
								COUNT(DISTINCT FUR.MD_ID) AS MDID_Count_Distinct,
								COUNT(*) AS Member_Count,
								AVG(FUR.Class_Mass) AS Mass_Avg,
								AVG(FUR.ElutionTime) AS NET_Avg,
								STDEV(FUR.Class_Mass) AS Mass_StDev,
								STDEV(FUR.ElutionTime) AS NET_StDev,
								AVG(M.Abundance) AS Abundance_Avg, 
								SUM(M.Abundance) AS Abundance_Sum
						FROM T_Tmp_ClusteredUMCs C
							INNER JOIN T_Tmp_ClusteredUMC_Mapping M
								ON C.ClusterID = M.ClusterID
							INNER JOIN T_FTICR_UMC_Results FUR
								ON M.MDID = FUR.MD_ID AND
									M.UMCIndex = FUR.UMC_Ind
						GROUP BY C.ClusterID 
					) StatsQ
			ON Target.ClusterID = StatsQ.ClusterID
		--
		Select @myError = @@Error, @myRowCount = @@RowCount
		
		-------------------------------------------------
		-- Populate T_Tmp_ClusteredUMC_Matches with the matches to the clusters
		-------------------------------------------------
		
		TRUNCATE TABLE T_Tmp_ClusteredUMC_Matches
		
		INSERT INTO T_Tmp_ClusteredUMC_Matches( ClusterID,
												Mass_Tag_ID,
												SLiC_Score_Max )
		SELECT C.ClusterID,
			FURD.Mass_Tag_ID,
			MAX(FURD.Match_Score) AS SLiC_Score_Max
		FROM T_FTICR_UMC_ResultDetails FURD
			INNER JOIN T_FTICR_UMC_Results FUR
			ON FURD.UMC_Results_ID = FUR.UMC_Results_ID
			INNER JOIN T_Tmp_ClusteredUMCs C
						INNER JOIN T_Tmp_ClusteredUMC_Mapping M
						ON C.ClusterID = M.ClusterID
			ON FUR.MD_ID = M.MDID AND
				FUR.UMC_Ind = M.UMCIndex
		GROUP BY C.ClusterID, FURD.Mass_Tag_ID
		--
		Select @myError = @@Error, @myRowCount = @@RowCount

								
	End -- </DoNotUseExistingClusteredUMCsTable>


	-------------------------------------------------
	-- Create the Pivot query to return the results
	-------------------------------------------------

	Set @PivotFieldsA = Null
	Set @PivotFieldsB = Null
	
	SELECT 
		@PivotFieldsA = Coalesce(@PivotFieldsA + ',', '') + 'IsNull([' + MDID + '], 0) AS [' + Dataset + ';' + MDID + ']',
		@PivotFieldsB = Coalesce(@PivotFieldsB + ',', '') + '[' + MDID + ']'
	FROM ( SELECT Convert(varchar(12), MMD.MD_ID) AS MDID,
	              Dataset
	       FROM T_Match_Making_Description MMD
	            INNER JOIN T_FTICR_Analysis_Description FAD
	              ON MMD.MD_Reference_Job = FAD.Job
	            INNER JOIN T_Tmp_MDIDList ML
	              ON MMD.MD_ID = ML.MD_ID ) ConvertQ
	ORDER BY Dataset

	
	Set @S = ''
	Set @S = @S + ' SELECT PivotData.ClusterID,'
	Set @S = @S +        ' PivotData.Mass, PivotData.NET,'
	Set @S = @S +        ' PivotData.MDID_Count_Distinct,'
	Set @S = @S +        ' PivotData.Mass_Avg, PivotData.NET_Avg,'
	Set @S = @S +        ' PivotData.Mass_StDev, PivotData.NET_StDev,'
	Set @S = @S +        ' PivotData.Abundance_Avg, PivotData.Abundance_Sum,'
	Set @S = @S +        ' ' + @PivotFieldsA + ','
	Set @S = @S +        ' IsNull(Matches.Mass_Tag_ID, 0) AS Mass_Tag_ID,'
	Set @S = @S +        ' IsNull(Matches.SLiC_Score_Max, 0) AS SLiC_Score_Max'
	Set @S = @S + ' FROM ( '
	Set @S = @S +        ' SELECT C.ClusterID, C.Mass, C.NET,'
	Set @S = @S +               ' C.MDID_Count_Distinct, C.Mass_Avg, C.NET_Avg,'
	Set @S = @S +               ' C.Mass_StDev, C.NET_StDev,'
	Set @S = @S +               ' C.Abundance_Avg, C.Abundance_Sum,'
	Set @S = @S +               ' M.MDID, M.Abundance AS MemberAbundance'
	Set @S = @S +        ' FROM T_Tmp_ClusteredUMCs C'
	Set @S = @S +               ' INNER JOIN T_Tmp_ClusteredUMC_Mapping M'
	Set @S = @S +                 ' ON C.ClusterID = M.ClusterID '
	Set @S = @S +      ' ) SourceTable'
	Set @S = @S +        ' PIVOT ( SUM(MemberAbundance)'
	Set @S = @S +                ' FOR MDID'
	Set @S = @S +                ' IN ( ' + @PivotFieldsB + ' ) '
	Set @S = @S +      ' ) AS PivotData'
	Set @S = @S +      ' LEFT OUTER JOIN T_Tmp_ClusteredUMC_Matches Matches'
	Set @S = @S +        ' ON PivotData.ClusterID = Matches.ClusterID'

	Print @S

	If @infoOnly = 0
		Exec (@S)

	DROP TABLE T_Tmp_MDIDList
	DROP TABLE T_TmpCurrentUMCs


Done:	
	Return @myError


GO

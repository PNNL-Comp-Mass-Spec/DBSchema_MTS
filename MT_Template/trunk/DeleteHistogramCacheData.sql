/****** Object:  StoredProcedure [dbo].[DeleteHistogramCacheData] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.DeleteHistogramCacheData
/****************************************************
**
**	Desc:	Deletes duplicate and outdated histogram cache data
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	mem
**	Date:	03/14/2006
**
*****************************************************/
(
	@MinimumDateThreshold datetime = '1/1/2006',
	@CacheIDFilterList varchar(2048) = '',				-- Comma separated list of Histogram_Cache_ID values to filter on
	@KeepOneEntryForEachUniqueCombo tinyint = 1,		-- if this is 1, then data prior to @MinimumDateThreshold will be kept if it is the only entry for the given combination of values in T_Histogram_Cache_Date; if this is 0, then all data prior to @MinimumDateThreshold will be deleted
	@PreviewUpdate tinyint = 0,
	@message varchar(255)='' output
)
AS

	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @Sql varchar(2048)
	
	Declare @UniqueComboIDMax int
	Declare @UniqueComboID int
	Declare @UniqueRowID int
	
	Declare @ResultCount int
	Declare @CompareCount int
	Declare @CandidateDeletionCount int
	
	Declare @DuplicateComparisonContinue int
	
	Declare @HistogramCacheID int

	Declare @CacheIDSource int
	Declare @SourceDataCount int
	
	Declare @EntriesDeleted int
	Set @EntriesDeleted = 0
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------
	--
	Set @MinimumDateThreshold = IsNull(@MinimumDateThreshold, GetDate() - 180)
	Set @CacheIDFilterList = LTrim(RTrim(IsNull(@CacheIDFilterList, '')))
	Set @KeepOneEntryForEachUniqueCombo = IsNull(@KeepOneEntryForEachUniqueCombo, 1)
	Set @PreviewUpdate = IsNull(@PreviewUpdate, 0)
	
	Set @message = ''

	-----------------------------------------------------
	-- Create two temporary tables
	-----------------------------------------------------
	--
	/*
	if exists (select * from dbo.sysobjects where id = object_id(N'#TmpHistogram_Cache_Unique') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table #TmpHistogram_Cache_Unique

	if exists (select * from dbo.sysobjects where id = object_id(N'#TmpCurrent_Cache_ID_List') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table #TmpCurrent_Cache_ID_List
	*/

	CREATE TABLE #TmpCache_ID_List_To_Process (
		Histogram_Cache_ID int NOT NULL,
	)

	CREATE UNIQUE CLUSTERED INDEX #IX_TmpCache_ID_List_To_Process_Cache_ID ON #TmpCache_ID_List_To_Process (Histogram_Cache_ID)

	
	CREATE TABLE #TmpHistogram_Cache_Unique (
		Unique_Combo_ID int IDENTITY (1, 1) NOT NULL ,
		Histogram_Mode smallint NOT NULL ,
		Score_Minimum float NOT NULL ,
		Score_Maximum float NOT NULL ,
		Bin_Count int NOT NULL ,
		Discriminant_Score_Minimum real NOT NULL ,
		PMT_Quality_Score_Minimum real NOT NULL ,
		Use_Distinct_Peptides tinyint NOT NULL ,
		Result_Type_Filter varchar(32) NOT NULL
	)

	CREATE UNIQUE CLUSTERED INDEX #IX_TmpHistogram_Cache_Unique_Combo_ID ON #TmpHistogram_Cache_Unique (Unique_Combo_ID)
	
	CREATE TABLE #TmpCurrent_Cache_ID_List (
		Unique_Row_ID int IDENTITY (1, 1) NOT NULL ,
		Histogram_Cache_ID int NOT NULL,
		Query_Date datetime NOT NULL,
		Auto_Update tinyint NOT NULL,
		Delete_Entry tinyint NOT NULL default 0,
		Deletion_Reason varchar(128) NULL
	)

	If @PreviewUpdate <> 0
		CREATE TABLE #TmpHistogramDataToDelete (
			Histogram_Cache_ID int NOT NULL, 
			Deletion_Reason varchar(128) NULL,
			Histogram_Mode smallint NOT NULL ,
			Score_Minimum float NOT NULL ,
			Score_Maximum float NOT NULL ,
			Bin_Count int NOT NULL ,
			Discriminant_Score_Minimum real NOT NULL ,
			PMT_Quality_Score_Minimum real NOT NULL ,
			Use_Distinct_Peptides tinyint NOT NULL ,
			Result_Type_Filter varchar(32) NOT NULL ,
			Query_Date datetime NOT NULL ,
			Data_Row_Count int NULL
		)	


	-----------------------------------------------------
	-- Populate #TmpCache_ID_List_To_Process with the 
	--  Histogram_Cache_ID values that are not deleted
	-- Optionally filter on @CacheIDFilterList
	-----------------------------------------------------
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' INSERT INTO #TmpCache_ID_List_To_Process (Histogram_Cache_ID)'
	Set @Sql = @Sql + ' SELECT Histogram_Cache_ID'
	Set @Sql = @Sql + ' FROM T_Histogram_Cache'
	Set @Sql = @Sql + ' WHERE Histogram_Cache_State <> 100'

	If @CacheIDFilterList <> ''
		Set @Sql = @Sql + ' AND Histogram_Cache_ID IN (' + @CacheIDFilterList + ')'
	
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	-----------------------------------------------------
	-- Populate #TmpHistogram_Cache_Unique with the unique combination
	--   of values in T_Histogram_Cache, linking on #TmpCache_ID_List_To_Process
	-----------------------------------------------------
	--
	INSERT INTO #TmpHistogram_Cache_Unique (
					Histogram_Mode, Score_Minimum, Score_Maximum, Bin_Count,
					Discriminant_Score_Minimum, PMT_Quality_Score_Minimum,
					Use_Distinct_Peptides, Result_Type_Filter)
	SELECT DISTINCT H.Histogram_Mode, H.Score_Minimum, H.Score_Maximum, H.Bin_Count,
					H.Discriminant_Score_Minimum, H.PMT_Quality_Score_Minimum,
					H.Use_Distinct_Peptides, H.Result_Type_Filter
	FROM T_Histogram_Cache H INNER JOIN
		 #TmpCache_ID_List_To_Process LTP ON H.Histogram_Cache_ID = LTP.Histogram_Cache_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	If @myRowCount = 0
	Begin
		Set @message = 'T_Histogram_Cache is empty; nothing to do'
		Goto Done
	End

	-----------------------------------------------------
	-- Loop through the values in #TmpHistogram_Cache_Unique
	-----------------------------------------------------
	--
	Set @UniqueComboID = 0
	Set @UniqueComboIDMax = 0
	
	SELECT	@UniqueComboID = MIN(Unique_Combo_ID),
			@UniqueComboIDMax = MAX(Unique_Combo_ID)
	FROM #TmpHistogram_Cache_Unique
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	-- Note: The reaon for iterating to one greater than @UniqueComboIDMax is that we
	--       look for entries without any data in T_Histogram_Cache_Data on the final iteration
	While @UniqueComboID <= @UniqueComboIDMax + 1 And @myError = 0
	Begin -- <a>
		TRUNCATE TABLE #TmpCurrent_Cache_ID_List
		Set @CandidateDeletionCount = 0
		
		If @UniqueComboID <= @UniqueComboIDMax
		Begin
			-- Populate #TmpCurrent_Cache_ID_List, sorting on state 1, then state 2, then the remaining states
			-- For identical states, sort on Query_Date descending
			--
			INSERT INTO #TmpCurrent_Cache_ID_List (Histogram_Cache_ID, Query_Date, Auto_Update)
			SELECT Histogram_Cache_ID, Query_Date, Auto_Update
			FROM (
				SELECT	H.Histogram_Cache_ID, H.Query_Date, H.Auto_Update,
						CASE H.Histogram_Cache_State
						WHEN 1 THEN 255
						WHEN 2 THEN 254
						ELSE H.Histogram_Cache_State
						END AS StateSortKey
				FROM #TmpHistogram_Cache_Unique HCU INNER JOIN
					 T_Histogram_Cache H ON 
						HCU.Histogram_Mode = H.Histogram_Mode AND 
						HCU.Score_Minimum = H.Score_Minimum AND 
						HCU.Score_Maximum = H.Score_Maximum AND 
						HCU.Bin_Count = H.Bin_Count AND 
						HCU.Discriminant_Score_Minimum = H.Discriminant_Score_Minimum AND
						HCU.PMT_Quality_Score_Minimum = H.PMT_Quality_Score_Minimum AND
						HCU.Use_Distinct_Peptides = H.Use_Distinct_Peptides AND 
						HCU.Result_Type_Filter = H.Result_Type_Filter INNER JOIN
					 #TmpCache_ID_List_To_Process LTP ON H.Histogram_Cache_ID = LTP.Histogram_Cache_ID
				WHERE HCU.Unique_Combo_ID = @UniqueComboID AND
					H.Histogram_Cache_State <> 100
				) DataQ
			ORDER BY StateSortKey Desc, Query_Date Desc
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			Set @CandidateDeletionCount = @myRowCount
		End
		Else
		Begin
			-- No more Unique_Combo_ID values to check
			-- Look for entries where no data is present in T_Histogram_Cache_Data but Result_Count is positive
			TRUNCATE TABLE #TmpCurrent_Cache_ID_List
			
			INSERT INTO #TmpCurrent_Cache_ID_List (	Histogram_Cache_ID, Query_Date, Auto_Update, 
													Delete_Entry, Deletion_Reason)
			SELECT	H.Histogram_Cache_ID, H.Query_Date, H.Auto_Update, 
					1 AS Delete_Entry, 'No data in T_Histogram_Cache_Data'
			FROM T_Histogram_Cache H INNER JOIN
				 #TmpCache_ID_List_To_Process LTP ON H.Histogram_Cache_ID = LTP.Histogram_Cache_ID LEFT OUTER JOIN
				 T_Histogram_Cache_Data HCD ON H.Histogram_Cache_ID = HCD.Histogram_Cache_ID
			WHERE H.Result_Count > 0 AND
				  H.Histogram_Cache_State <> 100 AND 
				  HCD.Histogram_Cache_ID IS NULL
			GROUP BY H.Histogram_Cache_ID, H.Query_Date, H.Auto_Update
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error	
			--				
			Set @CandidateDeletionCount = @myRowCount

			If Len(@CacheIDFilterList) = 0
			Begin
				-- In addition, look for entries that do have data in T_Histogram_Cache_Data but have Histogram_Cache_State = 100
				INSERT INTO #TmpCurrent_Cache_ID_List (	Histogram_Cache_ID, Query_Date, Auto_Update, 
														Delete_Entry, Deletion_Reason)
				SELECT	H.Histogram_Cache_ID, H.Query_Date, H.Auto_Update, 
						1 AS Delete_Entry, 'Marked as deleted in T_Histogram_Cache, but has data in T_Histogram_Cache_Data'
				FROM T_Histogram_Cache H INNER JOIN
					 T_Histogram_Cache_Data HCD ON H.Histogram_Cache_ID = HCD.Histogram_Cache_ID
				WHERE H.Histogram_Cache_State = 100
				GROUP BY H.Histogram_Cache_ID, H.Query_Date, H.Auto_Update
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	
				--				
				Set @CandidateDeletionCount = @CandidateDeletionCount + @myRowCount
			End
			
		End

		If @CandidateDeletionCount > 0 AND @UniqueComboID <= @UniqueComboIDMax
		Begin -- <b>
		
			-- Count the number of entries in #TmpCurrent_Cache_ID_List older than @MinimumDateThreshold
			SELECT @CompareCount = COUNT(*)
			FROM #TmpCurrent_Cache_ID_List
			WHERE Query_Date < @MinimumDateThreshold
			
			-- Delete old entries
			If @CandidateDeletionCount > @CompareCount Or @KeepOneEntryForEachUniqueCombo = 0
			Begin
				-- Either one or more entries are >= @MinimumDateThreshold or 
				--  @KeepOneEntryForEachUniqueCombo = 0
				-- Mark all queries older than @MinimumDateThreshold for deletion
				UPDATE #TmpCurrent_Cache_ID_List
				SET Delete_Entry = 1, Deletion_Reason = 'Older than "' + Convert(varchar(64), @MinimumDateThreshold) + '"'
				WHERE Query_Date < @MinimumDateThreshold
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	
			End
			Else
			Begin
				-- All of the entries are older than @MinimumDateThreshold
				-- Find the most recent entry in #TmpCurrent_Cache_ID_List
				SELECT @HistogramCacheID = MAX(Histogram_Cache_ID)
				FROM #TmpCurrent_Cache_ID_List CL INNER JOIN (
						SELECT MAX(Query_Date) AS Query_Date_Max
						FROM #TmpCurrent_Cache_ID_List
					  ) DateQ ON CL.Query_Date = DateQ.Query_Date_Max
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	

				-- Make sure Auto_Update = MAX(Auto_Update) for @HistogramCacheID
				UPDATE #TmpCurrent_Cache_ID_List
				SET Auto_Update = LookupQ.Auto_Update_Max
				FROM #TmpCurrent_Cache_ID_List CROSS JOIN 
					( SELECT MAX(Auto_Update) AS Auto_Update_Max
					  FROM #TmpCurrent_Cache_ID_List) LookupQ
				WHERE #TmpCurrent_Cache_ID_List.Histogram_Cache_ID = @HistogramCacheID
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	
				
				-- Delete the entries older than @MinimumDateThreshold, skipping @HistogramCacheID
				UPDATE #TmpCurrent_Cache_ID_List
				SET Delete_Entry = 1, Deletion_Reason = 'Older than "' + Convert(varchar(64), @MinimumDateThreshold) + '"; keeping most recent entry, ID = ' + Convert(varchar(19), @HistogramCacheID)
				WHERE Query_Date < @MinimumDateThreshold AND
					  Histogram_Cache_ID <> @HistogramCacheID
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	
			End
			
			-- Count the number of entries remaining in #TmpCurrent_Cache_ID_List with Delete_Entry = 0
			SELECT @ResultCount = COUNT(*)
			FROM #TmpCurrent_Cache_ID_List
			WHERE Delete_Entry = 0
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error	
			
			
			If @ResultCount > 1
			Begin -- <c>

				-- Look for entries with duplicate data
				--
				Set @UniqueRowID = -1
				Set @DuplicateComparisonContinue = 1
				While @DuplicateComparisonContinue = 1 And @myError = 0
				Begin -- <d>
					-- Lookup the next non-deleted entry in #TmpCurrent_Cache_ID_List, ordering by Unique_Row_ID
					-- Note that Unique_Row_ID sorts data on state 1, then state 2, then the remaining states
					-- For identical states, the data is sorted on Query_Date descending
					SELECT TOP 1 @UniqueRowID = Unique_Row_ID, 
								 @CacheIDSource = Histogram_Cache_ID
					FROM #TmpCurrent_Cache_ID_List
					WHERE Delete_Entry = 0 AND Unique_Row_ID > @UniqueRowID
					ORDER BY Unique_Row_ID
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error	
					
					If @myRowCount = 0
						Set @DuplicateComparisonContinue = 0
					Else
					Begin
						-- Count the number of data rows for @CacheIDSource
						Set @SourceDataCount = 0
						SELECT @SourceDataCount = COUNT(*)
						FROM T_Histogram_Cache_Data
						WHERE Histogram_Cache_ID = @CacheIDSource
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error	
						
						-- Mark duplicate entries for deletion
						-- Note that we need only examine entries with Histogram_Cache_ID > @CacheIDSource
						UPDATE #TmpCurrent_Cache_ID_List
						SET Delete_Entry = 1, Deletion_Reason = 'Duplicate data with ID = ' + Convert(varchar(19), @CacheIDSource)
						FROM #TmpCurrent_Cache_ID_List INNER JOIN
							 (	SELECT Histogram_Cache_ID
								FROM (	SELECT CompareQ.Histogram_Cache_ID, 
											   COUNT(*) AS Data_Row_Count, 
											   SUM(CASE WHEN SourceQ.Histogram_Cache_ID IS NULL THEN 0 ELSE 1 END) AS Matching_Row_Count
										FROM (  SELECT HCD.Histogram_Cache_ID, HCD.Bin, HCD.Frequency
												FROM T_Histogram_Cache_Data HCD INNER JOIN
													 #TmpCurrent_Cache_ID_List CIL ON HCD.Histogram_Cache_ID = CIL.Histogram_Cache_ID
												WHERE CIL.Unique_Row_ID > @UniqueRowID AND CIL.Delete_Entry = 0
											) CompareQ LEFT OUTER JOIN
											(	SELECT HCD.Histogram_Cache_ID, HCD.Bin, HCD.Frequency
												FROM T_Histogram_Cache_Data HCD INNER JOIN
													 #TmpCurrent_Cache_ID_List CIL ON HCD.Histogram_Cache_ID = CIL.Histogram_Cache_ID
												WHERE CIL.Unique_Row_ID = @UniqueRowID
											) SourceQ ON CompareQ.Bin = SourceQ.Bin AND CompareQ.Frequency = SourceQ.Frequency
										GROUP BY CompareQ.Histogram_Cache_ID
									) MatchingRowQ
								WHERE Data_Row_Count = @SourceDataCount AND Matching_Row_Count = @SourceDataCount
							 ) DeleteQ ON #TmpCurrent_Cache_ID_List.Histogram_Cache_ID = DeleteQ.Histogram_Cache_ID
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error	
							 
					End
				End -- </d>
			End -- </c>
		End -- </b>

		-- Update @CandidateDeletionCount to the number of entries with Delete_Entry = 1 in #TmpCurrent_Cache_ID_List
		SELECT @CandidateDeletionCount = COUNT(*)
		FROM #TmpCurrent_Cache_ID_List
		WHERE Delete_Entry = 1
		
		If @CandidateDeletionCount > 0
		Begin
			-- Delete the data for the marked entries
			If @PreviewUpdate <> 0
			Begin
				INSERT INTO #TmpHistogramDataToDelete (	Histogram_Cache_ID, Deletion_Reason, 
														Histogram_Mode, Score_Minimum, Score_Maximum, Bin_Count, 
														Discriminant_Score_Minimum, PMT_Quality_Score_Minimum, Use_Distinct_Peptides, 
														Result_Type_Filter, Query_Date, Data_Row_Count)
				SELECT	CL.Histogram_Cache_ID, CL.Deletion_Reason, 
						H.Histogram_Mode, H.Score_Minimum, H.Score_Maximum, H.Bin_Count, 
						H.Discriminant_Score_Minimum, H.PMT_Quality_Score_Minimum, H.Use_Distinct_Peptides, 
						H.Result_Type_Filter, H.Query_Date, 
						SUM(CASE WHEN HCD.Histogram_Cache_ID IS NULL THEN 0 ELSE 1 END) As Data_Row_Count
				FROM #TmpCurrent_Cache_ID_List CL INNER JOIN
					 T_Histogram_Cache H ON CL.Histogram_Cache_ID = H.Histogram_Cache_ID LEFT OUTER JOIN
					 T_Histogram_Cache_Data HCD ON H.Histogram_Cache_ID = HCD.Histogram_Cache_ID
				WHERE CL.Delete_Entry = 1
				GROUP BY CL.Histogram_Cache_ID, CL.Deletion_Reason, H.Histogram_Mode, H.Score_Minimum, H.Score_Maximum, H.Bin_Count, 
						H.Discriminant_Score_Minimum, H.PMT_Quality_Score_Minimum, H.Use_Distinct_Peptides, 
						H.Result_Type_Filter, H.Query_Date
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	
				--
				Set @EntriesDeleted = @EntriesDeleted + @myRowCount
			End
			Else
			Begin
				-- Delete the data from T_Histogram_Cache_Data
				DELETE T_Histogram_Cache_Data
				FROM T_Histogram_Cache_Data HCD INNER JOIN
					 #TmpCurrent_Cache_ID_List CL ON HCD.Histogram_Cache_ID = CL.Histogram_Cache_ID
				WHERE CL.Delete_Entry = 1
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	

				-- Change the state of the marked entries to 100 = Deleted
				UPDATE T_Histogram_Cache
				SET Histogram_Cache_State = 100
				FROM T_Histogram_Cache H INNER JOIN
					 #TmpCurrent_Cache_ID_List CL ON H.Histogram_Cache_ID = CL.Histogram_Cache_ID
				WHERE CL.Delete_Entry = 1
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	
				--
				Set @EntriesDeleted = @EntriesDeleted + @myRowCount
				
				-- Make sure Auto_Update is correct for the non-deleted entries
				UPDATE T_Histogram_Cache
				SET Auto_Update = 1
				FROM T_Histogram_Cache H INNER JOIN
					 #TmpCurrent_Cache_ID_List CL ON H.Histogram_Cache_ID = CL.Histogram_Cache_ID
				WHERE CL.Delete_Entry = 0 AND 
					  CL.Auto_Update = 1 AND 
					  H.Auto_Update = 0
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error	
			End
		End
		
		-- Increment @UniqueComboID
		Set @UniqueComboID = @UniqueComboID + 1
	End -- </a>
 
	-- Define the output message and possibly preview the data to be deleted
	Set @message = 'Deleted the data for ' + Convert(varchar(11), @EntriesDeleted) + ' histogram '
	If @EntriesDeleted = 1
		Set @message = @message + 'entry'
	Else
		Set @message = @message + 'entries'
	Set @message = @message + ' in T_Histogram_Cache_Data'
	
	If @PreviewUpdate <> 0
	Begin
		Set @message = 'Preview: ' + @message
		
		SELECT *
		FROM #TmpHistogramDataToDelete
		ORDER BY Histogram_Mode, Data_Row_Count, Histogram_Cache_ID
		
	End
	Else
	Begin
		If @EntriesDeleted > 0
			EXEC PostLogEntry 'Normal', @message, 'DeleteHistogramCacheData'
	End
	
Done:
	Return @myError


GO

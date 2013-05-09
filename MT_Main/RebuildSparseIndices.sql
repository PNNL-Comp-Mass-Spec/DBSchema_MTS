/****** Object:  StoredProcedure [dbo].[RebuildSparseIndices] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RebuildSparseIndices
/****************************************************
**
**	Desc: 
**		Reindexes indices with FillFactor less than @FillFactorThreshold
**		Changes the Fill Factor to either 100 or @NewFillFactorLargeTables
**
**		Note that a FillFactor of 0 and 100 are equivalent (both mean fill the index 100%)
**
**		A FillFactor of 10 means a very sparse index, and thus lots of wasted space
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	04/24/2013 mem - Initial version
**    
*****************************************************/
(
	@FillFactorThreshold int = 90,
	@SmallTableRowThreshold int = 1000,		-- Tables with fewer than this many rows will get a fill factor of 100 applied
	@NewFillFactorLargeTables int = 90,		-- Fill_factor to use on tables with over @SmallTableRowThreshold rows
	@infoOnly tinyint = 1,
	@message varchar(1024) = '' output
)
As
	set nocount on
	
	Declare @myError int
	Declare @myRowcount int
	set @myRowcount = 0
	set @myError = 0
	
	Declare @objectid int 
	Declare @indexid int 
	Declare @partitioncount bigint 
	Declare @schemaname nvarchar(130) 
	Declare @objectname nvarchar(130) 
	Declare @indexname nvarchar(130) 
	Declare @partitionnum bigint 
	Declare @fillFactor int
	Declare @partitions bigint 
	Declare @command nvarchar(4000) 
	Declare @HasBlobColumn int 
	
	Declare @IndexRowCount bigint
	Declare @FillFactorToApply int
	
	Declare @StartTime datetime
	Declare @continue int
	Declare @UniqueID int

	Declare @IndexCountProcessed int
	Set @IndexCountProcessed = 0

	Declare @UpdateEnabled tinyint

	-- Validate the inputs
	
	Set @FillFactorThreshold = IsNull(@FillFactorThreshold, 90)
	Set @SmallTableRowThreshold = IsNull(@SmallTableRowThreshold, 1000)
	Set @NewFillFactorLargeTables = IsNull(@NewFillFactorLargeTables, 90)
	Set @infoOnly = IsNull(@infoOnly, 1)
	
	If @SmallTableRowThreshold < 100
		Set @SmallTableRowThreshold = 100
		
	
	CREATE TABLE dbo.#TmpIndicesToProcess(
		[UniqueID] int Identity(1,1) NOT NULL,
		[objectid] [int] NULL,
		[indexid] [int] NULL,
		[partitionnum] [int] NULL,
		[fill_factor] [int] NULL
	) ON [PRIMARY]

	-- Conditionally select tables and indexes from the sys.dm_db_index_physical_stats function 
	-- and convert object and index IDs to names. 
	INSERT INTO #TmpIndicesToProcess (objectid, indexid, partitionnum, fill_factor)
	SELECT p.object_id,
	       p.index_id,
	       p.partition_number,
	       i.fill_factor
	FROM sys.dm_db_index_physical_stats ( DB_ID(), NULL, NULL, NULL, 'LIMITED' ) p INNER JOIN 
	     sys.indexes i ON i.object_id = p.object_id
	WHERE p.index_id > 0 -- cannot defrag a heap 
	      AND i.fill_factor NOT IN (0,100)
	      AND i.fill_factor < @FillFactorThreshold
 	ORDER BY i.fill_factor
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @Message = 'All database indices have fill factors at/above ' + convert(varchar(12), @FillFactorThreshold)
		If @infoOnly <> 0
			Print '  ' + @message
		Goto Done
	End

	-- Loop through #TmpIndicesToProcess and process the indices
	Set @StartTime = GetDate()
	Set @continue = 1
	Set @UniqueID = -1

	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @UniqueID = UniqueiD,
		             @objectid = objectid,
		             @indexid = indexid,
		             @partitionnum = partitionnum,
		             @fillFactor = fill_factor
		FROM #TmpIndicesToProcess
		WHERE UniqueID > @UniqueID
		ORDER BY UniqueID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>
	
	        Set @HasBlobColumn = 0 -- reinitialize 
			SELECT @objectname = QUOTENAME(o.name),
			       @schemaname = QUOTENAME(s.name)
			FROM sys.objects AS o
			     JOIN sys.schemas AS s
			       ON s.schema_id = o.schema_id
			WHERE o.object_id = @objectid
	
			SELECT @indexname = QUOTENAME(name)
			FROM sys.indexes
			WHERE object_id = @objectid AND
			      index_id = @indexid
	
			-- Lookup the index row count
			Set @IndexRowCount = -1
			SELECT @IndexRowCount = Index_Row_Count
			FROM dbo.V_Table_Index_Sizes
			WHERE QUOTENAME(Index_Name) = @indexname		
			
			If @@RowCount= 0
				Set @IndexRowCount = @SmallTableRowThreshold+1
	
			If @IndexRowCount < @SmallTableRowThreshold
				Set @FillFactorToApply = 100
			Else
				Set @FillFactorToApply = @NewFillFactorLargeTables
				
			SELECT @partitioncount = count(*)
			FROM sys.partitions
			WHERE object_id = @objectid AND
			      index_id = @indexid
	
	        -- Check for BLOB columns 
	        If @indexid = 1 -- only check here for clustered indexes ANY blob column on the table counts 
			Begin
	            SELECT @HasBlobColumn = CASE
	                                        WHEN max(so.object_ID) IS NULL THEN 0
	                                        ELSE 1
	                                    END
	            FROM sys.objects SO
	                 INNER JOIN sys.columns SC
	                   ON SO.Object_id = SC.object_id
	                 INNER JOIN sys.types ST
	                   ON SC.system_type_id = ST.system_type_id 
	               AND
	            ST.name IN ('text', 'ntext', 'image', 'varchar(max)', 'nvarchar(max)', 'varbinary(max)', 'xml')
	            WHERE SO.Object_ID = @objectID
			End
	        Else -- nonclustered. Only need to check if indexed column is a BLOB 
			Begin
	            SELECT @HasBlobColumn = CASE
	                                        WHEN max(so.object_ID) IS NULL THEN 0
	                                        ELSE 1
	                                    END
	            FROM sys.objects SO
	                 INNER JOIN sys.index_columns SIC
	                   ON SO.Object_ID = SIC.object_id
	                 INNER JOIN sys.Indexes SI
	                   ON SO.Object_ID = SI.Object_ID AND
	                      SIC.index_id = SI.index_id
	                 INNER JOIN sys.columns SC
	                   ON SO.Object_id = SC.object_id AND
	                      SIC.Column_id = SC.column_id
	                 INNER JOIN sys.types ST
	                   ON SC.system_type_id = ST.system_type_id 
	                      AND ST.name IN ('text', 'ntext', 'image', 'varchar(max)', 'nvarchar(max)', 'varbinary(max)', 'xml')
	            WHERE SO.Object_ID = @objectID
			End
	
	        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD'
	 
	        if @HasBlobColumn = 1 
	            Set @command = @command + N' WITH( SORT_IN_TEMPDB = ON, FILLFACTOR = ' + convert(nvarchar(12), @FillFactorToApply) + ') ' 
	        else 
	            Set @command = @command + N' WITH( ONLINE = OFF, SORT_IN_TEMPDB = ON, FILLFACTOR = ' + convert(nvarchar(12), @FillFactorToApply) + ') ' 
	
			IF @partitioncount > 1 
				SET @command = @command + N' PARTITION=' + CAST(@partitionnum AS nvarchar(10)) 
			
			Set @message = 'Fill_Factor: ' + Convert(varchar(12), @fillFactor) + '; '
			Set @message = @message + 'Executing: ' + @command + ' Has Blob = ' + convert(nvarchar(2),@HasBlobColumn) 
			
			if @InfoOnly <> 0
			Begin
				Print '  ' + @message
			End
			Else
			Begin
				EXEC (@command) 

				Set @message = 'Reindexed ' + @indexname + ' due to Fill_Factor = ' + Convert(varchar(12), @fillFactor)
				Exec PostLogEntry 'Normal', @message, 'RebuildSparseIndices'

				-- Validate that updating is enabled, abort if not enabled
				If Exists (select * from sys.objects where name = 'VerifyUpdateEnabled')
				Begin
					exec VerifyUpdateEnabled @CallingFunctionDescription = 'RebuildSparseIndices', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
					If @UpdateEnabled = 0
						Goto Done
				End
			End
	
			Set @IndexCountProcessed = @IndexCountProcessed + 1


		End -- </b>
	End -- </a>

	If @IndexCountProcessed > 0 and @InfoOnly = 0
	Begin
		-----------------------------------------------------------
		-- Log the reindex
		-----------------------------------------------------------
		
		Set @message = 'Reindexed ' + Convert(varchar(12), @IndexCountProcessed) + ' indices in ' + convert(varchar(12), Convert(decimal(9,1), DateDiff(second, @StartTime, GetDate()) / 60.0)) + ' minutes'
		Exec PostLogEntry 'Normal', @message, 'RebuildSparseIndices'
	End
	
Done:

	-- Drop the temporary table. 
	DROP TABLE #TmpIndicesToProcess 

	Return @myError


GO

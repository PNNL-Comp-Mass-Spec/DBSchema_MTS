/****** Object:  StoredProcedure [dbo].[RebuildFragmentedIndices] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE RebuildFragmentedIndices
/****************************************************
**
**	Desc: 
**		Reindexes fragmented indices in the database
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/12/2007
**			10/15/2012 mem - Added spaces prior to printing debug messages
**			10/18/2012 mem - Added parameter @VerifyUpdateEnabled
**			07/16/2014 mem - Now showing table with detailed index info when @infoOnly = 1
**						   - Changed default value for @MaxFragmentation from 15 to 25
**						   - Changed default value for @TrivialPageCount from 12 to 22
**    
*****************************************************/
(
	@MaxFragmentation int = 25,
	@TrivialPageCount int = 22,
	@VerifyUpdateEnabled tinyint = 1,		-- When non-zero, then calls VerifyUpdateEnabled to assure that database updating is enabled
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
	Declare @partitions bigint 
	Declare @frag float 
	Declare @command nvarchar(4000) 
	Declare @HasBlobColumn int 

	Declare @StartTime datetime
	Declare @continue int
	Declare @UniqueID int

	Declare @IndexCountProcessed int
	Set @IndexCountProcessed = 0

	Declare @UpdateEnabled tinyint

	---------------------------------------
	-- Validate the inputs
	---------------------------------------
	--
	Set @MaxFragmentation = IsNull(@MaxFragmentation, 25)
	Set @TrivialPageCount = IsNull(@TrivialPageCount, 22)
	Set @VerifyUpdateEnabled = IsNull(@VerifyUpdateEnabled, 1)
	Set @infoOnly = IsNull(@infoOnly, 1)
	Set @message = ''
	
	---------------------------------------
	-- Create a table to track the indices to process
	---------------------------------------
	--
	CREATE TABLE dbo.#TmpIndicesToProcess(
		UniqueID int Identity(1,1) NOT NULL,
		objectid int NULL,
		indexid int NULL,
		partitionnum int NULL,
		frag float NULL,
		page_count int NULL
	) ON [PRIMARY]
	
	---------------------------------------
	-- Conditionally select tables and indexes from the sys.dm_db_index_physical_stats function 
	-- and convert object and index IDs to names. 
	---------------------------------------
	--
	INSERT INTO #TmpIndicesToProcess (objectid, indexid, partitionnum, frag, page_count)
	SELECT object_id,
	       index_id,
	       partition_number,
	       avg_fragmentation_in_percent, 
	       page_count
	FROM sys.dm_db_index_physical_stats ( DB_ID(), NULL, NULL, NULL, 'LIMITED' )
	WHERE avg_fragmentation_in_percent > @MaxFragmentation
	  AND index_id > 0 -- cannot defrag a heap 
	  AND page_count > @TrivialPageCount -- ignore trivial sized indexes 
 	ORDER BY avg_fragmentation_in_percent Desc
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @Message = 'All database indices have fragmentation levels below ' + convert(varchar(12), @MaxFragmentation) + '%'
		If @infoOnly <> 0
			Print '  ' + @message
		Goto Done
	End


	If @InfoOnly > 0
	Begin
		------------------------------------------
		-- Show information on the indices
		------------------------------------------
		--
		SELECT NameQ.ObjectName,
			IndexQ.IndexName,
			IndexSizes.Table_Row_Count,
			IndexSizes.Index_Row_Count,
			IndexSizes.Space_Reserved_MB,
			IndexSizes.fill_factor,
			Cast(convert(decimal(9,1), SourceQ.frag) AS varchar(12)) + '%' As Avg_fragmentation,
			SourceQ.page_count,
			SourceQ.objectid AS Object_ID,
			sourceQ.indexid as Index_ID,
			SourceQ.partitionnum As Partition_number
		FROM #TmpIndicesToProcess As SourceQ
			INNER JOIN ( SELECT o.name AS ObjectName,
								QUOTENAME(s.name) AS SchemaName,
								o.object_id
						FROM sys.objects AS o
							JOIN sys.schemas AS s
								ON s.schema_id = o.schema_id ) NameQ
			ON SourceQ.objectid = NameQ.object_id
			INNER JOIN ( SELECT name AS IndexName,
								index_id,
								object_id
						FROM sys.indexes ) AS IndexQ
			ON SourceQ.indexid = IndexQ.index_id AND
				SourceQ.objectid = IndexQ.object_id
			INNER JOIN V_Table_Index_Sizes IndexSizes
			ON NameQ.ObjectName = IndexSizes.Table_Name AND
				IndexQ.IndexName = IndexSizes.Index_Name
		
		Select 'See the messages pane (text output) for the Alter Index commands that would be used' AS Message
		
	End
	
	--------------------------------------------------------------
	-- Loop through #TmpIndicesToProcess and process the indices
	--------------------------------------------------------------
	--
	Set @StartTime = GetDate()
	Set @continue = 1
	Set @UniqueID = -1

	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @UniqueID = UniqueiD,
		             @objectid = objectid,
		             @indexid = indexid,
		             @partitionnum = partitionnum,
		             @frag = frag
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
	            Set @command = @command + N' WITH( SORT_IN_TEMPDB = ON) ' 
	        else 
	            Set @command = @command + N' WITH( ONLINE = OFF, SORT_IN_TEMPDB = ON) ' 
	
			IF @partitioncount > 1 
				SET @command = @command + N' PARTITION=' + CAST(@partitionnum AS nvarchar(10)) 
			
			Set @message = 'Fragmentation = ' + Convert(varchar(12), convert(decimal(9,1), @frag)) + '%; '
			Set @message = @message + 'Executing: ' + @command + ' Has Blob = ' + convert(nvarchar(2),@HasBlobColumn) 
			
			if @InfoOnly <> 0
				Print '  ' + @message
			Else
			Begin
				EXEC (@command) 

				Set @message = 'Reindexed ' + @indexname + ' due to Fragmentation = ' + Convert(varchar(12), Convert(decimal(9,1), @frag)) + '%; '
				Exec PostLogEntry 'Normal', @message, 'RebuildFragmentedIndices'

				Set @IndexCountProcessed = @IndexCountProcessed + 1

				If @VerifyUpdateEnabled <> 0
				Begin
					-- Validate that updating is enabled, abort if not enabled
					If Exists (select * from sys.objects where name = 'VerifyUpdateEnabled')
					Begin
						exec VerifyUpdateEnabled @CallingFunctionDescription = 'RebuildFragmentedIndices', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
						If @UpdateEnabled = 0
							Goto Done
					End
				End
			End
	
		End -- </b>
	End -- </a>

	If @IndexCountProcessed > 0
	Begin
		-----------------------------------------------------------
		-- Log the reindex
		-----------------------------------------------------------
		
		Set @message = 'Reindexed ' + Convert(varchar(12), @IndexCountProcessed) + ' indices in ' + convert(varchar(12), Convert(decimal(9,1), DateDiff(second, @StartTime, GetDate()) / 60.0)) + ' minutes'
		Exec PostLogEntry 'Normal', @message, 'RebuildFragmentedIndices'
	End
	
Done:

	-- Drop the temporary table. 
	DROP TABLE #TmpIndicesToProcess 

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[RebuildFragmentedIndices] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RebuildFragmentedIndices] TO [MTS_DB_Lite] AS [dbo]
GO

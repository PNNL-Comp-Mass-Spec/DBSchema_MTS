/****** Object:  StoredProcedure [dbo].[ReindexDatabase] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ReindexDatabase
/****************************************************
**
**	Desc: 
**		Reindexes the key tables in the database
**		Once complete, updates ReindexDatabaseNow to 0 in T_Process_Step_Control
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	10/11/2007
**			10/30/2007 mem - Now calling VerifyUpdateEnabled
**			10/09/2008 mem - Added T_Score_Inspect
**			01/13/2011 mem - Now calling PostLogEntry after re-indexing each table
**			10/20/2011 mem - Added T_Peptide_Filter_Flags
**    
*****************************************************/
(
	@message varchar(512) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowcount int
	set @myRowcount = 0
	set @myError = 0
	
	Declare @TableCount int
	Set @TableCount = 0

	declare @UpdateEnabled tinyint
	
	Set @message = ''

	Exec PostLogEntry 'Debug', 'Reindexing tables', 'ReindexDatabase'
	
	-----------------------------------------------------------
	-- Reindex the data tables
	-----------------------------------------------------------
	DBCC DBREINDEX (T_Analysis_Description, '', 90)
	Set @TableCount = @TableCount + 1
	
	DBCC DBREINDEX (T_Datasets, '', 90)
	Set @TableCount = @TableCount + 1

	Exec PostLogEntry 'Debug', ' ... T_Analysis_Description and T_Datasets', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Peptides, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Peptides', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Sequence, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Sequence', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Score_Sequest, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Score_Sequest', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Score_XTandem, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Score_XTandem', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	DBCC DBREINDEX (T_Score_Inspect, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Score_Inspect', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Score_Discriminant, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Score_Discriminant', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Proteins, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Proteins', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Peptide_to_Protein_Map, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Peptide_to_Protein_Map', 'ReindexDatabase'
	
	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Peptide_Filter_Flags, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Peptide_Filter_Flags', 'ReindexDatabase'
	
	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Dataset_Stats_Scans, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Dataset_Stats_Scans', 'ReindexDatabase'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'ReindexDatabase', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	DBCC DBREINDEX (T_Dataset_Stats_SIC, '', 90)
	Set @TableCount = @TableCount + 1
	Exec PostLogEntry 'Debug', ' ... T_Dataset_Stats_SIC', 'ReindexDatabase'
	
	-----------------------------------------------------------
	-- Log the reindex
	-----------------------------------------------------------
	
	Set @message = 'Reindexed ' + Convert(varchar(12), @TableCount) + ' tables'
	Exec PostLogEntry 'Normal', @message, 'ReindexDatabase'
	
	-----------------------------------------------------------
	-- Update T_Process_Step_Control
	-----------------------------------------------------------
	
	-- Set 'ReindexDatabaseNow' to 0
	--
	UPDATE T_Process_Step_Control
	SET Enabled = 0
	WHERE (Processing_Step_Name = 'ReindexDatabaseNow')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = 'Entry "ReindexDatabaseNow" not found in T_Process_Step_Control; adding it'
		Exec PostLogEntry 'Error', @message, 'ReindexDatabase'
		
		INSERT INTO T_Process_Step_Control (Processing_Step_Name, Enabled)
		VALUES ('ReindexDatabaseNow', 0)
	End
	
	-- Set 'InitialDBReindexComplete' to 1
	--
	UPDATE T_Process_Step_Control
	SET Enabled = 1
	WHERE (Processing_Step_Name = 'InitialDBReindexComplete')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = 'Entry "InitialDBReindexComplete" not found in T_Process_Step_Control; adding it'
		Exec PostLogEntry 'Error', @message, 'ReindexDatabase'
		
		INSERT INTO T_Process_Step_Control (Processing_Step_Name, Enabled)
		VALUES ('InitialDBReindexComplete', 1)
	End


Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ReindexDatabase] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ReindexDatabase] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[ExtractMTModPositions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ExtractMTModPositions
/****************************************************
**
**	Desc: 
**		Examines the Mod_Description field of peptides in
**		T_Mass_Tags and parses out each ModName and ModDescription,
**		placing that information in T_Mass_Tag_Mod_Info
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	03/11/2008
**			03/12/2008 mem - Added parameter @AdditionalMTWhereClause
**    
*****************************************************/
(
	@MTIDMin int = 0,								-- Ignored if 0
	@MTIDMax int = 0,								-- Ignored if 0
	@SkipExistingEntries tinyint = 1,				-- When <> 0, then skips peptides already present in T_Mass_Tag_Mod_Info
	@AdditionalMTWhereClause varchar(255) = '',		-- Example: Mod_Description NOT LIKE '% -- DupSeq'
	@infoOnly tinyint = 0,
	@previewSql tinyint = 0,
	@message varchar(512)='' OUTPUT
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @S varchar(2048)
	
	Declare @CurrentMTID int
	Declare @ModCount int
	Declare @ModDescription varchar(2048)
	
	Declare @continue int
	Declare @MTsProcessed int
	Declare @TotalMTs int
	
	Declare @StatusMessage varchar(255)
	Declare @LastStatusUpdate datetime
	Set @LastStatusUpdate = GetDate()
	
	Declare @LastUpdateEnabledCheck datetime
	Set @LastUpdateEnabledCheck = GetDate()
	
	Declare @UpdateEnabled tinyint
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @MTIDMin = IsNull(@MTIDMin, 0)
	Set @MTIDMax = IsNull(@MTIDMax, 0)
	Set @SkipExistingEntries = IsNull(@SkipExistingEntries, 1)
	Set @AdditionalMTWhereClause = IsNull(@AdditionalMTWhereClause, '')
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @previewSql = IsNull(@previewSql, 0)
	Set @message= ''
	
	---------------------------------------------------
	-- Create a temporary table to hold the MT_IDs to parse
	---------------------------------------------------

	CREATE TABLE #Tmp_MTsToProcess (
		Mass_Tag_ID int NOT NULL
	)
	
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_MTsToProcess_Mass_Tag_ID ON #Tmp_MTsToProcess(Mass_Tag_ID)
	
	---------------------------------------------------
	-- Create a temporary table to hold the results
	---------------------------------------------------

	CREATE TABLE #Tmp_MTMods (
		Mass_Tag_ID int NOT NULL,
		Mod_Name varchar(32) NOT NULL,
		Mod_Position smallint NOT NULL
	)
	
	CREATE CLUSTERED INDEX #IX_Tmp_MTMods_Mass_Tag_ID ON #Tmp_MTMods(Mass_Tag_ID, Mod_Position)
	
	---------------------------------------------------
	-- Populate #Tmp_MTsToProcess
	---------------------------------------------------

	set @S = ''
	set @S = @S + ' INSERT INTO #Tmp_MTsToProcess (Mass_Tag_ID)'
	set @S = @S + ' SELECT MT.Mass_Tag_ID'
	set @S = @S + ' FROM T_Mass_Tags MT'
	If @SkipExistingEntries <> 0
		set @S = @S +  ' LEFT OUTER JOIN T_Mass_Tag_Mod_Info MTMI ON MT.Mass_Tag_ID = MTMI.Mass_Tag_ID'
	
	set @S = @S + ' WHERE (MT.Mod_Count > 0)'
	
	If @MTIDMin <> 0
		Set @S = @S + ' AND MT.Mass_Tag_ID >= ' + Convert(varchar(19), @MTIDMin)
		
	If @MTIDMax <> 0
		Set @S = @S + ' AND MT.Mass_Tag_ID <= ' + Convert(varchar(19), @MTIDMax)
	
	If @SkipExistingEntries <> 0
		Set @S = @S + ' AND MTMI.Mass_Tag_ID Is Null'
	
	If @AdditionalMTWhereClause <> ''
		Set @S = @S + ' AND ' + @AdditionalMTWhereClause
	
	If @previewSql <> 0
		Print @S
	Else
		Exec (@S)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @previewSql <> 0
		Goto Done
	
	---------------------------------------------------
	-- Count the number of petpides in #Tmp_MTsToProcess
	---------------------------------------------------
	
	Set @TotalMTs = 0
	SELECT @TotalMTs = COUNT(*)
	FROM #Tmp_MTsToProcess
	
	If @TotalMTs > 0
		Set @message = 'Found ' + Convert(varchar(12), @TotalMTs) + ' MTs to process'
	Else
	Begin
		Set @message = 'No modified MTs were found'
		
		If @MTIDMin <> 0 And @MTIDMax <> 0
			Set @message = @message + ' (Mass_Tag_ID Between ' + Convert(varchar(19), @MTIDMin) + ' and ' + Convert(varchar(19), @MTIDMax)+ ')'
		Else
		Begin
			If @MTIDMin <> 0
				Set @message = @message + ' (Mass_Tag_ID >= ' + Convert(varchar(19), @MTIDMin) + ')'
			
			If @MTIDMax <> 0
				Set @message = @message + ' (Mass_Tag_ID <= ' + Convert(varchar(19), @MTIDMax) + ')'
		End
		
		If @SkipExistingEntries <> 0
			Set @message = @message + '; skipping entries already present in T_Mass_Tag_Mod_Info'
		
		Goto Done
	End
	
	---------------------------------------------------
	-- Initialize @CurrentMTID
	---------------------------------------------------
	
	SELECT @CurrentMTID = MIN(Mass_Tag_ID) - 1
	FROM #Tmp_MTsToProcess
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	---------------------------------------------------
	-- Process each of the peptides in #Tmp_MTsToProcess
	---------------------------------------------------
	
	Set @continue = 1
	Set @MTsProcessed = 0

	While @continue = 1
	Begin
		SELECT TOP 1 @CurrentMTID = MTP.Mass_Tag_ID,
					 @ModCount = MT.Mod_Count,
					 @ModDescription = MT.Mod_Description
		FROM #Tmp_MTsToProcess MTP INNER JOIN
			 T_Mass_Tags MT ON MTP.Mass_Tag_ID = MT.Mass_Tag_ID
		WHERE MTP.Mass_Tag_ID > @CurrentMTID
		ORDER BY MTP.Mass_Tag_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		

		If @myRowCount <= 0
			Set @continue = 0
		Else
		Begin
			INSERT INTO #Tmp_MTMods (Mass_Tag_ID, Mod_Name, Mod_Position)
			SELECT	@CurrentMTID as MTID,
					Convert(varchar(32), KeyWord) as Mod_Name, 
					Convert(smallint, Value) as Mod_Position
			FROM dbo.udfParseKeyValueList(@ModDescription, ',', ':')
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			Set @MTsProcessed = @MTsProcessed + 1
			
			If @MTsProcessed % 1000 = 0
			Begin
				If DateDiff(second, @LastUpdateEnabledCheck, GetDate()) >= 15
				Begin
					-- Validate that updating is enabled, abort if not enabled
					exec VerifyUpdateEnabled @CallingFunctionDescription = 'ExtractMTModPositions', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @StatusMessage output
					If @UpdateEnabled = 0
						Goto Done
						
					Set @LastUpdateEnabledCheck = GetDate()
				End
				
				If DateDiff(second, @LastStatusUpdate, GetDate()) >= 60
				Begin
					Set @StatusMessage = '...Processing: ' + Convert(varchar(19), @MTsProcessed) + ' / ' + Convert(varchar(19), @TotalMTs)
					Exec PostLogEntry 'Progress', @StatusMessage, 'ExtractMTModPositions'
					
					Set @LastStatusUpdate = GetDate()
				End
			End
		End	
	End
	
	If @infoOnly <> 0
	Begin
		SELECT *
		FROM #Tmp_MTMods
		ORDER BY Mass_Tag_ID, Mod_Position
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

	End
	Else
	Begin
		-- Delete existing entries in T_Mass_Tag_Mod_Info
		DELETE T_Mass_Tag_Mod_Info
		FROM T_Mass_Tag_Mod_Info MTMI INNER JOIN
			 #Tmp_MTMods MTM ON MTMI.Mass_Tag_ID = MTM.Mass_Tag_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-- Append new entries to T_Mass_Tag_Mod_Info
		INSERT INTO T_Mass_Tag_Mod_Info (Mass_Tag_ID, Mod_Name, Mod_Position)
		SELECT Mass_Tag_ID, Mod_Name, Mod_Position
		FROM #Tmp_MTMods
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		Set @message = @message + '; Added ' + Convert(varchar(19), @myRowCount) + ' rows to T_Mass_Tag_Mod_Info for ' + Convert(varchar(12), @MTsProcessed) + ' MTs'
		
		Exec PostLogEntry 'Normal', @message, 'ExtractMTModPositions'
	End
	
Done:
	If @infoOnly <> 0
		Print @message
		
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ExtractMTModPositions] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[ExtractMTModPositions] TO [MTS_DB_Lite]
GO

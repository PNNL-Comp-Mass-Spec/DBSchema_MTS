/****** Object:  StoredProcedure [dbo].[UpdateMassTagToProteinModMap] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateMassTagToProteinModMap
/****************************************************
**
**	Desc: 
**		Parses the entries in T_Mass_Tag_Mod_Info to populate
**      T_Protein_Residue_Mods and T_Mass_Tag_to_Protein_Mod_Map
**
**		Use SP ExtractMTModPositions to populate T_Mass_Tag_Mod_Info before calling this procedure
**		In addition, table T_Mass_Tag_to_Protein_Map must have column Residue_Start populated
**		 before you can call this procedure
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	03/27/2008
**			03/29/2008 mem - Now skipping reversed or scrambled proteins
**						   - Optimized modified MT selection logic to exclude existing entries during the selection query rather than using a separate delete query (if @SkipExistingEntries = 1)
**			04/25/2008 mem - Updated to properly handle MTs with multiple occurences of the same modification on a given residue (e.g. N-terminus of peptide has NHS_SS modification twice)
**						   - Added Try/Catch error handling
**    
*****************************************************/
(
	@MTIDMin int = 0,							-- Set @MTIDMin and @MTIDMax to process all MTs
	@MTIDMax int = 0,
	@SkipExistingEntries tinyint = 1,			-- When <> 0, then skips peptides already present in T_Mass_Tag_to_Protein_Mod_Map and T_Protein_Residue_Mods
	@SkipReversedAndScrambledProteins tinyint = 1,
	@infoOnly tinyint= 0,
	@previewSql tinyint = 0,
	@maxIterations int = 0,
	@message varchar(255)='' OUTPUT
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @BatchSize int
	set @BatchSize = 5000
	
	declare @S nvarchar(3000)
	declare @ParamDef nvarchar(512)

	Declare @RangeFilter varchar(512)
	Set @RangeFilter = ''
		
	Declare @MTIDRange varchar(128)
	Set @MTIDRange = ''
	
	Declare @ModEntryID int
	Declare @continue int
	Declare @IterationCount int

	Declare @RefIDStart int
	Declare @RefIDEnd int
	
	Declare @MassTagID int
	Declare @RefID int

	Declare @ModMTCountAvailable int
	Declare @ModMTCountNotReady int
	Set @ModMTCountAvailable = 0
	Set @ModMTCountNotReady = 0
	
	Declare @ProteinCountNotReady int
	Set @ProteinCountNotReady = 0

	Declare @ProteinCountToProcess int
	Declare @ProteinCountDone int
	Set @ProteinCountToProcess = 0
	Set @ProteinCountDone = 0

	Declare @MTsProcessed int
	Declare @MappingCountAdded int
	Set @MTsProcessed = 0
	Set @MappingCountAdded = 0
	
	Declare @UpdateEnabledCheckTime datetime
	Declare @UpdateEnabled tinyint
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @MTIDMin = IsNull(@MTIDMin, 0)
	Set @MTIDMax = IsNull(@MTIDMax, 0)
	Set @SkipExistingEntries = IsNull(@SkipExistingEntries, 1)
	Set @SkipReversedAndScrambledProteins = IsNull(@SkipReversedAndScrambledProteins, 1)
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @previewSql = IsNull(@previewSql, 0)

	Set @message = ''

	declare @CurrentLocationBase varchar(256)
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
	
		-- Validate that updating is enabled, abort if not enabled
		Set @UpdateEnabledCheckTime = GetDate()
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateMassTagsFromMultipleAnalyses', @AllowPausing = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
		Begin
			Set @message = ''
			Goto Done
		End
			
		---------------------------------------------------
		-- Create a temporary table to hold the MTs to process
		-- Also include the Ref_ID's each Mass_Tag_ID maps to
		---------------------------------------------------

		Set @CurrentLocation = 'Create temporary tables'
		
		-- if exists (select * from dbo.sysobjects where id = object_id(N'[#Tmp_Mod_MTs_to_Process]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		-- drop table [#Tmp_Mod_MTs_to_Process]

		CREATE TABLE #Tmp_Mod_MTs_to_Process (
			Mass_Tag_ID int NOT NULL,
			Ref_ID int NOT NULL,
			Residue_Start int NULL,					-- Allow nulls here, though we will ultimately delete any entries with null Residue_Start values
			Processed tinyint NOT NULL Default 0
		)

		CREATE CLUSTERED INDEX IX_Tmp_Mod_MTs_to_Process ON #Tmp_Mod_MTs_to_Process(Ref_ID, Mass_Tag_ID) ON [PRIMARY]

		-- if exists (select * from dbo.sysobjects where id = object_id(N'[#Tmp_ResidueInfoCurrentProteins]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		-- drop table [#Tmp_ResidueInfoCurrentProteins]

		CREATE TABLE #Tmp_ResidueInfoCurrentProteins (
			Ref_ID int NOT NULL, 
			Residue_Num int NOT NULL, 
			Mod_Name varchar(32) NOT NULL,
			Residue_Mod_ID int NULL
		)

		CREATE CLUSTERED INDEX IX_Tmp_ResidueInfoCurrentProteins ON #Tmp_ResidueInfoCurrentProteins(Ref_ID) ON [PRIMARY]
			
		---------------------------------------------------
		-- Populate the temporary table with the MTs to process
		---------------------------------------------------

		Set @CurrentLocation = 'Populate #Tmp_Mod_MTs_to_Process'

		Set @S = ''
		Set @S = @S + ' INSERT INTO #Tmp_Mod_MTs_to_Process (Mass_Tag_ID, Ref_ID, Residue_Start)'
		Set @S = @S + ' SELECT MTMI.Mass_Tag_ID, MTPM.Ref_ID, MTPM.Residue_Start'

		If @SkipExistingEntries <> 0
		Begin	
			Set @S = @S + ' FROM T_Mass_Tag_to_Protein_Mod_Map PMM'
			Set @S = @S + '  INNER JOIN T_Protein_Residue_Mods PRM'
			Set @S = @S +    ' ON PMM.Residue_Mod_ID = PRM.Residue_Mod_ID'
			Set @S = @S +  ' RIGHT OUTER JOIN T_Mass_Tag_Mod_Info MTMI'
			Set @S = @S +                   ' INNER JOIN T_Mass_Tag_to_Protein_Map MTPM'
			Set @S = @S +                     ' ON MTMI.Mass_Tag_ID = MTPM.Mass_Tag_ID'
			If @SkipReversedAndScrambledProteins <> 0
				Set @S = @S +               ' INNER JOIN T_Proteins Prot ON MTPM.Ref_ID = Prot.Ref_ID'
			
			Set @S = @S +    ' ON PRM.Ref_ID = MTPM.Ref_ID AND'
			Set @S = @S +       ' PMM.Mass_Tag_ID = MTMI.Mass_Tag_ID'

			Set @S = @S + ' WHERE PRM.Residue_Mod_ID IS NULL '
		End
		Else
		Begin
			Set @S = @S + ' FROM T_Mass_Tag_Mod_Info MTMI INNER JOIN '
			Set @S = @S +      ' T_Mass_Tag_to_Protein_Map MTPM ON MTMI.Mass_Tag_ID = MTPM.Mass_Tag_ID'
			If @SkipReversedAndScrambledProteins <> 0
				Set @S = @S + ' INNER JOIN T_Proteins Prot ON MTPM.Ref_ID = Prot.Ref_ID'

			Set @S = @S + ' WHERE 1=1 '
		End
			
		Set @RangeFilter = ''
		If @MTIDMin <> 0
		Begin
			Set @RangeFilter = @RangeFilter + ' AND MTMI.Mass_Tag_ID >= ' + Convert(varchar(19), @MTIDMin)
		End
		
		If @MTIDMax <> 0
		Begin
			Set @RangeFilter = @RangeFilter + ' AND MTMI.Mass_Tag_ID <= ' + Convert(varchar(19), @MTIDMax)
		End
		
		If Len(@RangeFilter) > 0
			Set @S = @S + ' ' + @RangeFilter

		If @SkipReversedAndScrambledProteins <> 0
		Begin
				Set @S = @S + ' AND (NOT ( Prot.Reference LIKE ''reversed[_]%'' OR'
				Set @S = @S +           ' Prot.Reference LIKE ''scrambled[_]%'' OR'
				Set @S = @S +           ' Prot.Reference LIKE ''%[:]reversed'''
				Set @S = @S +         ' ))'
		End
		
		Set @S = @S + ' GROUP BY MTMI.Mass_Tag_ID, MTPM.Ref_ID, MTPM.Residue_Start'
		Set @S = @S + ' ORDER BY MTMI.Mass_Tag_ID, MTPM.Ref_ID'
		
		If @previewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @ModMTCountAvailable = @myRowCount
			
		
		---------------------------------------------------
		-- Count, then delete any MTs that have Null Residue_Start values
		---------------------------------------------------
		
		Set @CurrentLocation = 'Count, then delete any MTs that have Null Residue_Start values'
		
		SELECT	@ModMTCountNotReady   = COUNT(DISTINCT MMP.Mass_Tag_ID),
				@ProteinCountNotReady = COUNT(DISTINCT MMP.Ref_ID)
		FROM  #Tmp_Mod_MTs_to_Process MMP
		WHERE MMP.Residue_Start IS NULL
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If IsNull(@ModMTCountNotReady, 0) > 0
		Begin
			Set @Message = 'Modified MTs are present in T_Mass_Tag_to_Protein_Map with null Residue_Start values; unable to populate T_Mass_Tag_to_Protein_Mod_Map for ' + Convert(varchar(12), @ModMTCountNotReady) + ' MT'
		
			If @ModMTCountNotReady = 1
				Set @Message = @Message + ' (that maps to '
			Else
				Set @Message = @Message + 's (that map to '
				
			Set @Message = @Message + Convert(varchar(12), @ProteinCountNotReady) + ' protein'
			
			If @ProteinCountNotReady = 1
				Set @Message = @Message + ')'
			Else
				Set @Message = @Message + 's)'
			
			If @infoOnly <> 0
				SELECT @message as ErrorMessage
			Else
			Begin
				If @previewSql <> 0
					Print @Message
				Else
					Exec PostLogEntry 'Error', @Message, 'UpdateMassTagToProteinModMap'
			End
						
			Set @Message = ''
			
			DELETE #Tmp_Mod_MTs_to_Process
			WHERE Residue_Start IS NULL
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
		End

		If @previewSql <> 0
			Goto Done

		---------------------------------------------------
		-- Count the number of entries that remain
		---------------------------------------------------

		SELECT @ModMTCountAvailable = COUNT(*)
		FROM #Tmp_Mod_MTs_to_Process

		If @ModMTCountAvailable = 0
			Set @Message = 'No modified MTs are available for processing; either they are already defined in T_Mass_Tag_to_Protein_Mod_Map or they were skipped'
		Else
			Set @message = 'Found ' + Convert(varchar(12), @ModMTCountAvailable) + ' modified MTs to process'

		If Len(@MTIDRange) > 0
			Set @Message = @Message + ' (filtering on  ' + @RangeFilter + ')'

		if @infoOnly <> 0
			SELECT @Message as Message

		If @infoOnly <> 0 Or @ModMTCountAvailable = 0
			Goto done


		---------------------------------------------------
		-- Process the data in #Tmp_Mod_MTs_to_Process
		-- For efficiency purposes, processing a range of proteins at a time
		---------------------------------------------------

		Set @CurrentLocation = 'Process the data in #Tmp_Mod_MTs_to_Process'
		
		Set @RefIDStart = 0
		
		SELECT @RefIDStart = MIN(Ref_ID), 
			@ProteinCountToProcess = COUNT(Distinct Ref_ID)
		FROM #Tmp_Mod_MTs_to_Process
		
		Set @IterationCount = 0
		Set @Continue = 1
		While @Continue = 1
		Begin -- <a>

			-- Determine the ending Ref_ID to process
			-- Process ~@BatchSize MT to Protein mappings at a time
			SELECT @RefIDEnd = MIN(Ref_ID)
			FROM (	SELECT Ref_ID, 
						Row_Number() OVER (ORDER BY Ref_ID) AS EntryRowNumber
					FROM #Tmp_Mod_MTs_to_Process
					WHERE Ref_ID >= @RefIDStart
				) RefQ
			WHERE EntryRowNumber >= @BatchSize

			If @RefIDEnd Is Null
			Begin
				SELECT @RefIDEnd = MAX(Ref_ID)
				FROM #Tmp_Mod_MTs_to_Process
			End

			If IsNull(@RefIDEnd, 0) < @RefIDStart
				-- All proteins have been processed
				Set @Continue = 0
			Else
			Begin -- <b>

				-- For the Ref_ID values between @RefIDStart and @RefIDEnd, make sure the 
				-- Mods defined in T_Mass_Tag_Mod_Info are defined in T_Protein_Residue_Mods
				-- Add any that are missing

				Set @CurrentLocationBase = 'Process Ref_ID values between ' + Convert(varchar(12), @RefIDStart) + ' and ' + Convert(varchar(12), @RefIDEnd)
				Set @CurrentLocation = @CurrentLocationBase + '; Populate #Tmp_ResidueInfoCurrentProteins'

				TRUNCATE TABLE #Tmp_ResidueInfoCurrentProteins
				
				INSERT INTO #Tmp_ResidueInfoCurrentProteins (Ref_ID, Residue_Num, Mod_Name)
				SELECT DISTINCT MMP.Ref_ID,
								MMP.Residue_Start + MTMI.Mod_Position - 1 AS Residue_Num,
								MTMI.Mod_Name
				FROM #Tmp_Mod_MTs_to_Process MMP
					INNER JOIN T_Mass_Tag_Mod_Info MTMI
					ON MMP.Mass_Tag_ID = MTMI.Mass_Tag_ID
				WHERE (MMP.Ref_ID BETWEEN @RefIDStart AND @RefIDEnd)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount


				-- Add new rows to T_Protein_Residue_Mods
				Set @CurrentLocation = @CurrentLocationBase + '; Add new rows to T_Protein_Residue_Mods'

				INSERT INTO T_Protein_Residue_Mods
					(Ref_ID, Residue_Num, Mod_Name)
				SELECT RICP.Ref_ID, RICP.Residue_Num, RICP.Mod_Name
				FROM #Tmp_ResidueInfoCurrentProteins RICP
					LEFT OUTER JOIN T_Protein_Residue_Mods PRM
					ON RICP.Ref_ID = PRM.Ref_ID AND
						RICP.Residue_Num = PRM.Residue_Num AND
						RICP.Mod_Name = PRM.Mod_Name
				WHERE (PRM.Residue_Mod_ID IS NULL)
				ORDER BY RICP.Ref_ID, RICP.Residue_Num, RICP.Mod_Name
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount


				-- Before populating T_Mass_Tag_to_Protein_Mod_Map, make sure no entries
				--  are present in T_Mass_Tag_to_Protein_Mod_Map mapping to the Mass_Tag_ID
				--  and Ref_ID values in #Tmp_Mod_MTs_to_Process
			
				Set @CurrentLocation = @CurrentLocationBase + '; Delete extra rows from T_Mass_Tag_to_Protein_Mod_Map'

				DELETE T_Mass_Tag_to_Protein_Mod_Map
				FROM T_Mass_Tag_to_Protein_Mod_Map PMM
					INNER JOIN T_Protein_Residue_Mods PRM
					ON PMM.Residue_Mod_ID = PRM.Residue_Mod_ID
					INNER JOIN #Tmp_Mod_MTs_to_Process MMP
					ON PMM.Mass_Tag_ID = MMP.Mass_Tag_ID AND
						PRM.Ref_ID = MMP.Ref_ID
				WHERE (MMP.Ref_ID BETWEEN @RefIDStart AND @RefIDEnd)
    			--
				SELECT @myError = @@error, @myRowCount = @@rowcount

	    			
				-- Populate T_Mass_Tag_to_Protein_Mod_Map with the residue
				--  mapping of the entries in #Tmp_Mod_MTs_to_Process
				--  to the proteins that contain these entries
			
				Set @CurrentLocation = @CurrentLocationBase + '; Add new rows to T_Mass_Tag_to_Protein_Mod_Map'

				INSERT INTO T_Mass_Tag_to_Protein_Mod_Map( Mass_Tag_ID, Residue_Mod_ID )
				SELECT LookupQ.Mass_Tag_ID,
				       PRM.Residue_Mod_ID
				FROM ( SELECT MMP.Mass_Tag_ID,
							MMP.Ref_ID,
							MMP.Residue_Start + MTMI.Mod_Position - 1 AS Residue_Num,
							MTMI.Mod_Name
					FROM #Tmp_Mod_MTs_to_Process MMP
							INNER JOIN T_Mass_Tag_Mod_Info MTMI
							ON MMP.Mass_Tag_ID = MTMI.Mass_Tag_ID
					WHERE (MMP.Ref_ID BETWEEN @RefIDStart AND @RefIDEnd) ) LookupQ
					INNER JOIN T_Protein_Residue_Mods PRM
					ON LookupQ.Ref_ID = PRM.Ref_ID AND
						LookupQ.Residue_Num = PRM.Residue_Num AND
						LookupQ.Mod_Name = PRM.Mod_Name
				GROUP BY LookupQ.Mass_Tag_ID, PRM.Residue_Mod_ID

    			--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				SET @MappingCountAdded = @MappingCountAdded + @myRowCount
				
				
				-- Bump up @ProteinCountDone based on the number of proteins in #Tmp_ResidueInfoCurrentProteins
				--
				SELECT @myRowCount = COUNT(Distinct Ref_ID)
				FROM #Tmp_ResidueInfoCurrentProteins
				
				Set @ProteinCountDone = @ProteinCountDone + IsNull(@myRowCount, 0)
											
				-- Update the Processed flag in #Tmp_Mod_MTs_to_Process
				--
				UPDATE #Tmp_Mod_MTs_to_Process
				SET Processed = 1
				WHERE Ref_ID BETWEEN @RefIDStart AND @RefIDEnd
				
			End -- </b>

			-- Validate that updating is enabled, abort if not enabled
			If DateDiff(second, @UpdateEnabledCheckTime, GetDate()) >= 60
			Begin
				Set @Message = '...Processing: ' + Convert(varchar(12), @ProteinCountDone) + ' / ' + Convert(varchar(12), @ProteinCountToProcess) + ' proteins'
				Exec PostLogEntry 'Progress', @Message, 'UpdateMassTagToProteinModMap'
				Set @Message = ''
				
				Set @UpdateEnabledCheckTime = GetDate()
				exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateMassTagToProteinModMap', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
				If @UpdateEnabled = 0
				Begin
					Set @message = ''
					Goto Done
				End
			End

			-- Update @RefIDStart so that we start at the protein just after @RefIDEnd
			Set @RefIDStart = @RefIDEnd + 1

			-- Check for too many iterations		
			Set @IterationCount = @IterationCount + 1
			If @maxIterations > 0 And @IterationCount >= @maxIterations
				Set @Continue = 0
				
		End -- </a>
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateMassTagToProteinModMap')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

Done:
	
	If @ProteinCountDone > 0
	Begin
		SELECT @MTsProcessed = COUNT(Distinct Mass_Tag_ID)
		FROM #Tmp_Mod_MTs_to_Process
		WHERE Processed <> 0
		
		Set @message = 'Populated T_Mass_Tag_to_Protein_Mod_Map for ' + Convert(varchar(12), IsNull(@MTsProcessed, 0)) + ' MTs and ' + Convert(varchar(12), @ProteinCountDone) + ' proteins, adding ' + Convert(varchar(12), @MappingCountAdded) + ' mapping entries'
		
		Exec PostLogEntry 'Normal', @message, 'UpdateMassTagToProteinModMap'
	End
	
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagToProteinModMap] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagToProteinModMap] TO [MTS_DB_Lite] AS [dbo]
GO

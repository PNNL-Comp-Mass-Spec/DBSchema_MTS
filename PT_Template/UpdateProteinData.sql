/****** Object:  StoredProcedure [dbo].[UpdateProteinData] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateProteinData
/****************************************************
**
**	Desc:	Updates local copy of the Protein table
**
**	Return values: 0 if no error, non-zero if an error
**
**	Auth:	mem
**	Date:	10/30/2009 mem - Initial Version (modelled after RefreshLocalProteinTable in MT DBs)
**			11/01/2009 mem - Now logging the number of jobs in @JobListFilter
**			07/23/2010 mem - Added 'xxx.%' as a potential prefix for reversed proteins
**			12/13/2010 mem - Now looking up protein collection info using MT_Main.dbo.T_DMS_Protein_Collection_Info
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			01/17/2012 mem - Added 'rev[_]%' as a potential prefix for reversed proteins (MS-GFDB)
**			12/12/2012 mem - Added 'xxx[_]%' as a potential prefix for reversed proteins (MSGF+)
**    
*****************************************************/
(
	@JobListFilter varchar(max) = '',					-- Optional list of Job numbers to filter on; affects which protein collections will be examined
	@SkipUpdateExistingProteins tinyint = 1,			-- Only valid if @JobListFilter is defined.  If 1, then will skip processing of a protein collection if all non-reversed/decoy proteins for the collection already have non-null protein sequence values; when this is 1, then @importAllProteins is set to 0
	@importAllProteins int = 1,
	@ProteinCountAdded int = 0 output,					-- The number of new proteins added
	@ProteinCountUpdated int = 0 output,				-- The number of proteins updated
	@infoOnly int = 0,
	@message varchar(512) = '' output
)
As
	Set nocount on 

	declare @myError int
	declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	declare @S nvarchar(2048)
	declare @DBIDString nvarchar(30)
	
	Declare @ProteinCollectionList varchar(max)
	Declare @UnknownProteinCollections varchar(2048)
	Declare @ProteinCollectionName varchar(128)
	Declare @ProteinCollectionDescription varchar(256)
		
	declare @CurrentID int
	declare @continue int

	declare @AllowImportAllProteins tinyint
	declare @MatchCount int
	Declare @ProcessProteinCollection tinyint
	
	declare @result int
	Set @result = 0

	declare @JobFilterCount int
	Set @JobFilterCount = 0
	
	Declare @ProteinSequenceUpdateRequired tinyint

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		---------------------------------------------------
		-- Validate the input parameters
		---------------------------------------------------
		--
		Set @JobListFilter = LTrim(RTrim(IsNull(@JobListFilter, '')))
		Set @SkipUpdateExistingProteins = IsNull(@SkipUpdateExistingProteins, 0)
		Set @importAllProteins = IsNull(@importAllProteins, 1)
		Set @infoOnly = IsNull(@infoOnly, 0)
		
		If @JobListFilter = ''
			Set @SkipUpdateExistingProteins = 0
			
		If @SkipUpdateExistingProteins <> 0
			Set @importAllProteins = 0
		
		Set @ProteinCountAdded = 0
		Set @ProteinCountUpdated = 0
		Set @message = ''

		---------------------------------------------------
		-- Create several temporary tables
		---------------------------------------------------
		--
		
		CREATE TABLE #T_Tmp_ProteinDataJobFilter (
			Job int NOT NULL
		)

		CREATE CLUSTERED INDEX #IX_Tmp_ProteinDataJobFilter ON #T_Tmp_ProteinDataJobFilter (Job)
		
		
		--If exists (select * from dbo.sysobjects where id = object_id(N'[#T_Tmp_Protein_Collection_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		--drop table [#T_Tmp_Protein_Collection_List]
		
		CREATE TABLE #T_Tmp_Protein_Collection_List (
			Protein_Collection_Name varchar(128) NOT NULL,
			Protein_Collection_ID int NULL,
			Import_All_Proteins tinyint NOT NULL default 0
		)

		CREATE CLUSTERED INDEX #IX_Tmp_Protein_Collection_List_Collection_Name ON #T_Tmp_Protein_Collection_List (Protein_Collection_Name)
		CREATE INDEX #IX_Tmp_Protein_Collection_List_Collection_ID ON #T_Tmp_Protein_Collection_List (Protein_Collection_ID)

		--If exists (select * from dbo.sysobjects where id = object_id(N'[#T_Tmp_Protein_Collection_Candidates]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		--drop table [#T_Tmp_Protein_Collection_Candidates]

		CREATE TABLE #T_Tmp_Protein_Collection_Candidates (
			Protein_Collection_List varchar(max),
			UniqueRowID int identity(1,1)
		)
		
		CREATE CLUSTERED INDEX #IX_Tmp_Protein_Collection_Candidates ON #T_Tmp_Protein_Collection_Candidates (UniqueRowID)
		

		CREATE TABLE #Tmp_ProteinCollectionData (
			Protein_Name varchar(128) NOT NULL,
			Description varchar(900) NULL,
			Protein_Sequence text NOT NULL,
			Residue_Count int NOT NULL,
			Monoisotopic_Mass float NULL,
			Reference_ID int NOT NULL,
			Protein_ID int NOT NULL
		) -- ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

		CREATE CLUSTERED INDEX #IX_#mp_ProteinCollectionData ON #Tmp_ProteinCollectionData (Protein_Name)


		If @JobListFilter <> ''
		Begin
			Set @CurrentLocation = 'Populate #T_Tmp_Protein_Collection_Candidates using @JobListFilter'

			INSERT INTO #T_Tmp_ProteinDataJobFilter ( Job )
			SELECT DISTINCT Value AS Job
			FROM dbo.udfParseDelimitedIntegerList ( @JobListFilter, ',' )
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			Set @JobFilterCount = @myRowCount
			
			---------------------------------------------------
			-- Populate #T_Tmp_Protein_Collection_Candidates with 
			--  Protein Collection names from T_Analysis_Description
			--
			-- Filter the list using @JobListFilter
			---------------------------------------------------
			--
			INSERT INTO #T_Tmp_Protein_Collection_Candidates (Protein_Collection_List)
			SELECT DISTINCT TAD.Protein_Collection_List
			FROM T_Analysis_Description TAD
				INNER JOIN #T_Tmp_ProteinDataJobFilter JobQ
				ON TAD.Job = JobQ.Job
			WHERE IsNull(TAD.Protein_Collection_List, '') NOT IN ('', 'na')
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
				
			If @myRowCount = 0
			Begin
				Set @message = 'Warning: None of the jobs in @JobListFilter is present in T_Analysis_Description with a defined Protein Collection List; @JobListFilter = ' + @JobListFilter
				execute PostLogEntry 'Warning', @message, 'UpdateProteinData'
				Set @message = ''
			End
				
		End
		Else
		Begin
			Set @CurrentLocation = 'Populate #T_Tmp_Protein_Collection_Candidates using all jobs in T_Analysis_Description'
			
			---------------------------------------------------
			-- Populate #T_Tmp_Protein_Collection_Candidates with 
			--  Protein Collection names from T_Analysis_Description
			---------------------------------------------------
			--
			INSERT INTO #T_Tmp_Protein_Collection_Candidates (Protein_Collection_List)
			SELECT DISTINCT Protein_Collection_List
			FROM T_Analysis_Description
			WHERE IsNull(Protein_Collection_List, '') NOT IN ('', 'na')
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End

	    
		---------------------------------------------------
		-- Parse each entry in #T_Tmp_Protein_Collection_Candidates
		--  to populate #T_Tmp_Protein_Collection_List
		---------------------------------------------------
		
		Set @CurrentLocation = 'Parse entries in #T_Tmp_Protein_Collection_Candidates'
		
		Set @CurrentID = 0
		Set @Continue = 1
		While @Continue = 1
		Begin -- <b1>
    		SELECT TOP 1 @ProteinCollectionList = Protein_Collection_List,
    					@CurrentID = UniqueRowID
    		FROM #T_Tmp_Protein_Collection_Candidates
    		WHERE UniqueRowID > @CurrentID
    		ORDER BY UniqueRowID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount = 0
				Set @continue = 0
			Else
			Begin -- <c1>
				-- Split apart @ProteinCollectionList on commas, and insert any new
				-- protein collections into #T_Tmp_Protein_Collection_list
				--
				INSERT INTO #T_Tmp_Protein_Collection_List (Protein_Collection_Name, Import_All_Proteins)
				SELECT DISTINCT Value, 1 AS Import_All_Proteins
				FROM dbo.udfParseDelimitedList(@ProteinCollectionList, ',') SourceQ
						LEFT OUTER JOIN #T_Tmp_Protein_Collection_List Target ON 
						SourceQ.Value = Target.Protein_Collection_Name
				WHERE Target.Protein_Collection_Name Is Null AND NOT IsNull(Value, '') = ''
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End -- </c1>
		End -- </b1>

		Set @CurrentLocation = 'Update Protein_Collection_ID values in #T_Tmp_Protein_Collection_Candidates'
		
		---------------------------------------------------
		-- Update Protein_Collection_ID in #T_Tmp_Protein_Collection_List
		--  using MT_Main.dbo.T_DMS_Protein_Collection_Info
		---------------------------------------------------
		--
		UPDATE #T_Tmp_Protein_Collection_List
		SET Protein_Collection_ID =	PCI.Protein_Collection_ID
		FROM #T_Tmp_Protein_Collection_List PC
			INNER JOIN MT_Main.dbo.T_DMS_Protein_Collection_Info PCI
			ON PC.Protein_Collection_Name = PCI.[Name]
		WHERE PC.Protein_Collection_ID IS NULL
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		If @JobListFilter = ''
		Begin
			Set @CurrentLocation = 'Add any Protein Collection IDs defined in T_Proteins that are not yet in #T_Tmp_Protein_Collection_List'
			
			---------------------------------------------------
			-- Now add any Protein Collection IDs defined in T_Proteins
			-- We set Import_All_Proteins to 0 for these since we don't want to
			--  import missing proteins from protein collections not defined in
			--  T_Analysis_Description
			---------------------------------------------------
			--
			INSERT INTO #T_Tmp_Protein_Collection_List (Protein_Collection_Name, Protein_Collection_ID, Import_All_Proteins)
			SELECT SourceQ.[Name],
			       SourceQ.Protein_Collection_ID,
			       0 AS Import_All_Proteins
			FROM ( SELECT DISTINCT PCI.[Name],
			                       T_Proteins.Protein_Collection_ID
			       FROM T_Proteins
			            INNER JOIN MT_Main.dbo.T_DMS_Protein_Collection_Info PCI
			              ON T_Proteins.Protein_Collection_ID = PCI.Protein_Collection_ID
			       WHERE NOT (T_Proteins.Protein_Collection_ID IS NULL) 
			     ) SourceQ
			     LEFT OUTER JOIN #T_Tmp_Protein_Collection_List Target
			       ON SourceQ.Protein_Collection_ID = Target.Protein_Collection_ID
			WHERE Target.Protein_Collection_ID IS NULL
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End

		
		---------------------------------------------------
		-- Count the number of entries now present in #T_Tmp_Protein_Collection_List
		---------------------------------------------------
		--
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM #T_Tmp_Protein_Collection_List
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @MatchCount < 1
		Begin
			Set @message = 'Warning: No protein collection lists are defined in T_Analysis_Description or in T_Process_Config'
			goto Done
		End
		Else
		Begin -- <b2>

			Set @CurrentLocation = 'Remove unknown protein collections from #T_Tmp_Protein_Collection_List'

			---------------------------------------------------
			-- Construct a list of any protein collections with null Proten Collection ID values
			-- If any are found, post an entry to the log, then delete them from #T_Tmp_Protein_Collection_List
			---------------------------------------------------
			--
			Set @UnknownProteinCollections = ''
			SELECT @UnknownProteinCollections = @UnknownProteinCollections + Protein_Collection_Name + ','
			FROM #T_Tmp_Protein_Collection_List
			WHERE Protein_Collection_ID IS NULL
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount > 0
			Begin
				-- Unknown protein collections found; post an entry to the log (limiting to one post every 24 hours)
				
				-- Remove the trailing comma
				Set @UnknownProteinCollections = Left(@UnknownProteinCollections, Len(@UnknownProteinCollections)-1)
				Set @message = 'Protein collections were found that are not defined in the Protein_Sequences DB: ' + @UnknownProteinCollections
				execute PostLogEntry 'Error', @message, 'UpdateProteinData', 24
				Set @message = ''

				DELETE FROM #T_Tmp_Protein_Collection_List
				WHERE Protein_Collection_ID IS NULL

			End

			Set @CurrentLocation = 'Process each protein collection defined in #T_Tmp_Protein_Collection_List'

			---------------------------------------------------
			-- Process each protein collection defined in #T_Tmp_Protein_Collection_List
			---------------------------------------------------
			--
			SELECT @CurrentID = Min(Protein_Collection_ID)-1
    		FROM #T_Tmp_Protein_Collection_List

    		Set @Continue = 1
    		While @Continue = 1
    		Begin -- <c2>
 				SELECT TOP 1 @ProteinCollectionName = Protein_Collection_Name,
 				             @CurrentID = Protein_Collection_ID,
 				             @AllowImportAllProteins = Import_All_Proteins
 				FROM #T_Tmp_Protein_Collection_List
 				WHERE Protein_Collection_ID > @CurrentID
 				ORDER BY Protein_Collection_ID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @myRowCount = 0
					Set @continue = 0
				Else
				Begin -- <d>
					Set @ProteinCollectionDescription = 'Protein Collection ' + @ProteinCollectionName + ' (ID ' + Convert(varchar(12), @CurrentID) + ')'

					Set @CurrentLocation = 'Process ' + @ProteinCollectionDescription
					
					Set @ProcessProteinCollection = 1
					
					If @SkipUpdateExistingProteins <> 0
					Begin
						-- Possibly skip updates for this protein collection
						-- See if there are any Null values for the Proteins originating from the jobs in #T_Tmp_ProteinDataJobFilter
						--
						Set @MatchCount = 0
						
						SELECT @MatchCount = COUNT(*)
						FROM #T_Tmp_ProteinDataJobFilter F
						     INNER JOIN T_Peptides Pep
						       ON Pep.Job = F.Job
						     INNER JOIN T_Peptide_to_Protein_Map PPM
						       ON PPM.Peptide_ID = Pep.Peptide_ID
						     INNER JOIN T_Proteins Prot
						       ON Prot.Ref_ID = PPM.Ref_ID
						WHERE Protein_Collection_ID IS NULL AND
						      NOT (	Prot.Reference LIKE 'reversed[_]%' OR	-- MTS reversed proteins
									Prot.Reference LIKE 'scrambled[_]%' OR	-- MTS scrambled proteins
									Prot.Reference LIKE '%[:]reversed' OR	-- X!Tandem decoy proteins
									Prot.Reference LIKE 'xxx.%' OR			-- Inspect reversed/scrambled proteins
									Prot.Reference LIKE 'rev[_]%' OR		-- MSGFDB reversed proteins
									Prot.Reference LIKE 'xxx[_]%'			-- MSGF+ reversed proteins
						           )
						
						If @MatchCount = 0
						Begin
							Set @ProcessProteinCollection = 0

							Set @message =  'Skipping ' + @ProteinCollectionDescription + ' since all proteins are up-to-date in T_Proteins for '
							If @JobFilterCount = 1
								Set @message = @message + ' job ' + @JobListFilter
							Else
								Set @message = @message + Convert(varchar(12), @JobFilterCount) + ' jobs'
							
							If @InfoOnly = 0
								exec PostLogEntry 'Normal', @message, 'UpdateProteinData'
							Else
								Print @message
						End
							
					End
					
					If @ProcessProteinCollection <> 0
					Begin -- <e>
					
						if @infoOnly <> 0
							Print 'Adding entries for ' + @ProteinCollectionDescription

						---------------------------------------------------
						-- Cache the data for this protein collection (to avoid repeatedly extracting the same info from the Protein Sequences DB)
						---------------------------------------------------
						
						TRUNCATE TABLE #Tmp_ProteinCollectionData
						
						INSERT INTO #Tmp_ProteinCollectionData (Protein_Name, Description, Protein_Sequence,
																Residue_Count, Monoisotopic_Mass, Reference_ID, Protein_ID)
						SELECT Protein_Name, Description, Protein_Sequence,
						       Residue_Count, Monoisotopic_Mass, Reference_ID, Protein_ID
						FROM MT_Main.dbo.V_DMS_Protein_Collection_Members_Import
						WHERE Protein_Collection_ID = @CurrentID
						--
						SELECT @myError = @result, @myRowcount = @@rowcount
							
						---------------------------------------------------
						-- Add new entries to T_Proteins
						---------------------------------------------------
						If @importAllProteins <> 0 And @AllowImportAllProteins <> 0
						Begin -- <f1>
							If @infoOnly <> 0
								-- Preview missing proteins from Protein_Collection_ID @CurrentID
								SELECT SourceQ.*
								FROM #Tmp_ProteinCollectionData SourceQ LEFT OUTER JOIN
									T_Proteins ON SourceQ.Protein_Name = T_Proteins.Reference
								WHERE T_Proteins.Reference IS NULL
							Else
								-- Insert missing proteins from Protein_Collection_ID @CurrentID
								INSERT INTO T_Proteins (Reference, Description, Protein_Sequence, 
														Protein_Residue_Count, Monoisotopic_Mass, 
														External_Reference_ID, External_Protein_ID, Protein_Collection_ID)
								SELECT	SourceQ.Protein_Name, Left(SourceQ.Description, 7500) AS Description, SourceQ.Protein_Sequence, 
										SourceQ.Residue_Count, SourceQ.Monoisotopic_Mass, 
										SourceQ.Reference_ID, SourceQ.Protein_ID, @CurrentID AS Protein_Collection_ID
								FROM #Tmp_ProteinCollectionData SourceQ
								     LEFT OUTER JOIN T_Proteins
								       ON SourceQ.Protein_Name = T_Proteins.Reference
								WHERE T_Proteins.Reference IS NULL
							--
							SELECT @myError = @result, @myRowcount = @@rowcount
							--
							If @myError  <> 0
							Begin
								Set @message = 'Could not add new Protein entries for ' + @ProteinCollectionDescription
								goto Done
							End
							
							Set @ProteinCountAdded = @ProteinCountAdded + @myRowCount
						End -- </f1>


						If @infoOnly <> 0 
						Begin
							-- Count the number of proteins that need to be updated
							Set @myRowCount = 0
							
							SELECT @myRowCount = COUNT(*)
							FROM T_Proteins
							WHERE ISNULL(T_Proteins.Protein_Collection_ID, @CurrentID) = @CurrentID AND 
								Protein_Collection_ID IS NULL
								
							Set @message = 'Need to update ' + Convert(varchar(12), @myRowCount) + ' proteins for ' + @ProteinCollectionDescription
							Print @message
							
						End
						Else
						Begin -- <f2>

							---------------------------------------------------
							-- Update existing entries
							---------------------------------------------------
							--
							UPDATE T_Proteins
							SET Description = Left(SourceQ.Description, 7500),
								Protein_Sequence = SourceQ.Protein_Sequence,
								Protein_Residue_Count = SourceQ.Residue_Count,
								Monoisotopic_Mass = SourceQ.Monoisotopic_Mass,
								External_Reference_ID = SourceQ.Reference_ID,
								External_Protein_ID = SourceQ.Protein_ID,
								Protein_Collection_ID = @CurrentID,
								Last_Affected = GetDate()
							FROM #Tmp_ProteinCollectionData AS SourceQ
								INNER JOIN T_Proteins Prot
								  ON SourceQ.Protein_Name = Prot.Reference
							WHERE ISNULL(Prot.Protein_Collection_ID, @CurrentID) = @CurrentID 
								AND
								(	IsNull(Prot.Description, '') <> Left(SourceQ.Description, 7500) OR
									IsNull(Prot.Protein_Residue_Count, 0) <> SourceQ.Residue_Count OR
									IsNull(Prot.Monoisotopic_Mass, 0) <> SourceQ.Monoisotopic_Mass OR
									Prot.External_Reference_ID IS NULL OR
									Prot.External_Protein_ID IS NULL OR
									Prot.Protein_Collection_ID IS NULL OR
									Prot.Protein_Sequence IS NULL
								)
							--
							SELECT @myError = @result, @myRowcount = @@rowcount
							--
							If @myError  <> 0
							Begin
								Set @message = 'Could not update Protein entries for ' + @ProteinCollectionDescription
								goto Done
							End
							
							Set @ProteinCountUpdated = @ProteinCountUpdated + @myRowCount

						End -- </f2>
						
					End -- </e>
					
				End -- </d>
    		End	-- </c2>
		End -- </b2>

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateProteinData')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto DoneSkipLog
	End Catch

Done:

	If @myError <> 0
	Begin
		Set @message = @message + ' (Error ' + Convert(varchar(12), @myError) + ')'
		
		If @infoOnly = 0
			execute PostLogEntry 'Error', @message, 'UpdateProteinData'
		Else
			Select @message As TheMessage
	End
	Else
	Begin

		Set @message = 'Refresh local Protein reference table: ' + convert(varchar(12), @ProteinCountAdded) + ' proteins added; ' + convert(varchar(12), @ProteinCountUpdated) + ' proteins updated'

		If @JobFilterCount > 0
		Begin
			Set @message = @message + '; processed ' + Convert(varchar(12), @JobFilterCount) + ' job'
			If @JobFilterCount <> 1
				Set @message = @message + 's'
		End		
		
		If @infoOnly = 0 And (@ProteinCountAdded > 0 Or @ProteinCountUpdated > 0)
			exec PostLogEntry 'Normal', @message, 'UpdateProteinData'
	End

DoneSkipLog:

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateProteinData] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateProteinData] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[RefreshLocalProteinTable] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.RefreshLocalProteinTable
/****************************************************
**
**	Desc:	Updates local copy of the Protein table from 
**			associated Protein database.
**
**	Return values: 0: End of line not yet encountered
**
**	Auth:	grk
**	Date:	12/18/2001
**
**			11/20/2003 grk - Added @noImport and function
**			04/08/2004 mem - Renamed @noImport to be @importAllProteins and updated logic accordingly
**						   - Added check to validate that the ORF database exists
**			09/22/2004 mem - Replaced ORF references with Protein references
**			12/15/2004 mem - Updated to lookup the Protein DB ID in MT_Main and to record in the Protein_DB_ID column
**						   - Updated to allow multiple Protein_DB_Name database entries in T_Process_Config
**			12/01/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**						   - Increased size of @ProteinDBName from 64 to 128 characters
**			07/27/2006 mem - Updated to utilize the new column names in T_Proteins
**						   - Updated to work with Protein Collection Lists (the V_DMS_Protein_Collection views in MT_Main)
**			08/16/2006 mem - Added option @SwitchFromLegacyDBToProteinCollection
**			09/29/2006 mem - Now verifying that each protein database actually exists on this server.  If it doesn't, then posts an error message if the name is not 'na', '(na)', 'none', or blank
**			10/07/2007 mem - Increased size of @ProteinCollectionList to varchar(max)
**    
*****************************************************/
(
	@message varchar(512) = '' output,
	@infoOnly int = 0,
	@importAllProteins int = 1,
	@ForceLegacyDBProcessing tinyint = 0,						-- Set to 1 to force processing of legacy protein DBs defined in T_Process_Config even If 'UseProteinSequencesDB' is enabled in T_Process_Step_Control
	@SwitchFromLegacyDBToProteinCollection tinyint = 0			-- Set to 1 to update the entries in T_Proteins to use a protein collection (defined in T_Process_Config or T_Analysis_Description) if possible
)
As
	Set nocount on 

	declare @myError int
	declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0
	
	Set @message = ''
	Set @importAllProteins = IsNull(@importAllProteins, 1)
	Set @ForceLegacyDBProcessing = IsNull(@ForceLegacyDBProcessing, 0)
	Set @SwitchFromLegacyDBToProteinCollection = IsNull(@SwitchFromLegacyDBToProteinCollection, 0)

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
	
	declare @result int
	declare @numAdded int

	Set @result = 0
	Set @numAdded = 0

	Declare @UseProteinSequencesDB tinyint
	Declare @ProteinSequenceUpdateRequired tinyint
	
	Declare @ProteinSequenceDBSwitchPerformed tinyint
	Set @ProteinSequenceDBSwitchPerformed = 0
	
	Declare @ProteinDBIDListCount int
	Declare @ProteinDBIDList varchar(256)


	If @SwitchFromLegacyDBToProteinCollection <> 0
	Begin
		Set @UseProteinSequencesDB = 1
	End
	Else
	Begin
		---------------------------------------------------
		-- See If use of the Protein_Sequences database is enabled
		---------------------------------------------------

		Set @UseProteinSequencesDB = 0
		SELECT @UseProteinSequencesDB = enabled
		FROM T_Process_Step_Control
		WHERE (Processing_Step_Name = 'UseProteinSequencesDB')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End


	If @UseProteinSequencesDB <> 0
	Begin -- <a>

		---------------------------------------------------
		-- Create several temporary tables
		---------------------------------------------------
		--
		If exists (select * from dbo.sysobjects where id = object_id(N'[#T_Tmp_Protein_Collection_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#T_Tmp_Protein_Collection_List]
		
		CREATE TABLE #T_Tmp_Protein_Collection_List (
			Protein_Collection_Name varchar(128) NOT NULL,
			Protein_Collection_ID int NULL,
			Import_All_Proteins tinyint NOT NULL default 0
		)


		If exists (select * from dbo.sysobjects where id = object_id(N'[#T_Tmp_Protein_Collection_Candidates]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#T_Tmp_Protein_Collection_Candidates]

		CREATE TABLE #T_Tmp_Protein_Collection_Candidates (
			Protein_Collection_List varchar(max),
			UniqueRowID int identity(1,1)
		)
		

		If exists (select * from dbo.sysobjects where id = object_id(N'[#T_Tmp_Protein_Sequence_Updates]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#T_Tmp_Protein_Sequence_Updates]
		
		CREATE TABLE #T_Tmp_Protein_Sequence_Updates (
			Protein_ID int NOT NULL,
			Protein_Sequence text NULL,
			Residue_Count int NULL
		)


		---------------------------------------------------
		-- Populate #T_Tmp_Protein_Collection_Candidates with 
		--  Protein Collection names from T_Analysis_Description
		---------------------------------------------------
		--
		INSERT INTO #T_Tmp_Protein_Collection_Candidates (Protein_Collection_List)
		SELECT DISTINCT Protein_Collection_List
		FROM T_Analysis_Description
		WHERE IsNull(Protein_Collection_List, 'na') <> 'na' AND 
			  LEN(ISNULL(Protein_Collection_List, '')) > 0
    	
    	---------------------------------------------------
    	-- Parse each entry in #T_Tmp_Protein_Collection_Candidates
    	--  to populate #T_Tmp_Protein_Collection_List
    	---------------------------------------------------
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
				WHERE Target.Protein_Collection_Name Is Null
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End -- </c1>
    	End -- </b1>

		---------------------------------------------------
		-- Now add any protein collection lists defined in T_Process_Config 
		--  using setting Protein_Collection_Filter
		-- Note that we do not consider entries for Protein_Collection_and_Protein_Options_Combo 
		--  since it can contain wildcards
		-- If any jobs get imported into this DB using Protein_Collection_and_Protein_Options_Combo,
		--  then their protein collection lists will be parsed from T_Analysis_Description
		---------------------------------------------------
		--
		INSERT INTO #T_Tmp_Protein_Collection_List (Protein_Collection_Name, Import_All_Proteins)
		SELECT DISTINCT Value, 1 AS Import_All_Proteins
		FROM (SELECT Value
				FROM T_Process_Config
				WHERE [Name] = 'Protein_Collection_Filter' AND 
					Len(IsNull(Value, '')) > 0
			  ) SourceQ LEFT OUTER JOIN #T_Tmp_Protein_Collection_List Target ON
				SourceQ.Value = Target.Protein_Collection_Name
		WHERE Target.Protein_Collection_Name Is Null
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		---------------------------------------------------
		-- Update Protein_Collection_ID in #T_Tmp_Protein_Collection_List
		--  using MT_Main.dbo.V_DMS_Protein_Collection_List_Import
		---------------------------------------------------
		--
		UPDATE #T_Tmp_Protein_Collection_List
		Set Protein_Collection_ID = PCLI.Protein_Collection_ID
		FROM #T_Tmp_Protein_Collection_List PC INNER JOIN
			 MT_Main.dbo.V_DMS_Protein_Collection_List_Import PCLI ON
			 PC.Protein_Collection_Name = PCLI.[Name]
		WHERE PC.Protein_Collection_ID IS NULL
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		---------------------------------------------------
		-- Now add any Protein Collection IDs defined in T_Proteins
		-- We set Import_All_Proteins to 0 for these since we don't want to
		--  import missing proteins from protein collections not defined in
		--  T_Process_Config or T_Analysis_Description
		---------------------------------------------------
		--
		INSERT INTO #T_Tmp_Protein_Collection_List (Protein_Collection_Name, Protein_Collection_ID, Import_All_Proteins)
		SELECT SourceQ.[Name], SourceQ.Protein_Collection_ID, 0 AS Import_All_Proteins
		FROM (	SELECT DISTINCT PCLI.[Name], T_Proteins.Protein_Collection_ID
				FROM T_Proteins INNER JOIN 
					 MT_Main.dbo.V_DMS_Protein_Collection_List_Import PCLI ON 
					 T_Proteins.Protein_Collection_ID = PCLI.Protein_Collection_ID
				WHERE NOT (T_Proteins.Protein_Collection_ID IS NULL)
			 ) SourceQ LEFT OUTER JOIN #T_Tmp_Protein_Collection_List Target ON
			   SourceQ.Protein_Collection_ID = Target.Protein_Collection_ID
		WHERE Target.Protein_Collection_ID Is Null
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		
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
			If @ForceLegacyDBProcessing = 0
			Begin
				Set @message = 'No protein collection lists are defined in T_Analysis_Description or in T_Process_Config'
				Set @myError = 40000
				goto Done
			End
		End
		Else
		Begin -- <b2>

			---------------------------------------------------
			-- Construct a list of any protein collections with null ID values
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
				execute PostLogEntry 'Error', @message, 'RefreshLocalProteinTable', 24
				Set @message = ''

				DELETE FROM #T_Tmp_Protein_Collection_List
				WHERE Protein_Collection_ID IS NULL

			End

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
					
					---------------------------------------------------
					-- Add new entries to T_Proteins
					---------------------------------------------------
					If @importAllProteins <> 0 And @AllowImportAllProteins <> 0
					Begin -- <e1>
						If @infoOnly <> 0
							-- Preview missing proteins from Protein_Collection_ID @CurrentID
							SELECT SourceQ.*
							FROM (	SELECT  Protein_Name, Description, Protein_Sequence, Residue_Count, 
											Monoisotopic_Mass, 
											Reference_ID, Protein_ID
									FROM MT_Main.dbo.V_DMS_Protein_Collection_Members_Import 
									WHERE Protein_Collection_ID = @CurrentID
								) SourceQ LEFT OUTER JOIN
								T_Proteins ON SourceQ.Protein_Name = T_Proteins.Reference
							WHERE T_Proteins.Reference IS NULL
						Else
							-- Insert missing proteins from Protein_Collection_ID @CurrentID
							INSERT INTO T_Proteins (Reference, Description, Protein_Sequence, 
													Protein_Residue_Count, Monoisotopic_Mass, 
													Protein_DB_ID, External_Reference_ID, External_Protein_ID, Protein_Collection_ID)
							SELECT	SourceQ.Protein_Name, Left(SourceQ.Description, 7500) AS Description, SourceQ.Protein_Sequence, 
									SourceQ.Residue_Count, SourceQ.Monoisotopic_Mass, 
									0 AS Protein_DB_ID, SourceQ.Reference_ID, SourceQ.Protein_ID, @CurrentID AS Protein_Collection_ID
							FROM (	SELECT  Protein_Name, Description, Protein_Sequence, Residue_Count, 
											Monoisotopic_Mass, Reference_ID, Protein_ID
									FROM MT_Main.dbo.V_DMS_Protein_Collection_Members_Import 
									WHERE Protein_Collection_ID = @CurrentID
								) SourceQ LEFT OUTER JOIN
								T_Proteins ON SourceQ.Protein_Name = T_Proteins.Reference
							WHERE T_Proteins.Reference IS NULL

						--
						SELECT @myError = @result, @myRowcount = @@rowcount
						--
						If @myError  <> 0
						Begin
							Set @message = 'Could not add new Protein entries for ' + @ProteinCollectionDescription
							goto Done
						End
						
						Set @numAdded = @numAdded + @myRowCount
					End -- </e1>


					If @infoOnly = 0 
					Begin -- <e2>

						If @SwitchFromLegacyDBToProteinCollection <> 0
						Begin -- <f1>
							---------------------------------------------------
							-- Look for proteins that are currently associated with a Protein_DB_ID but could
							-- be switched to this protein collection
							---------------------------------------------------

							Set @ProteinDBIDListCount = 0
							Set @ProteinDBIDList = ''
							SELECT @ProteinDBIDList = @ProteinDBIDList + Convert(varchar(9), Protein_DB_ID) + ','
							FROM (
								SELECT DISTINCT Protein_DB_ID
								FROM T_Proteins TargetQ INNER JOIN
										(	SELECT Protein_Name, Protein_ID, Reference_ID
											FROM MT_Main.dbo.V_DMS_Protein_Collection_Members_Import
											WHERE Protein_Collection_ID = @CurrentID
										) SourceQ ON TargetQ.Reference = SourceQ.Protein_Name COLLATE SQL_Latin1_General_CP1_CI_AS
								WHERE ISNULL(TargetQ.Protein_DB_ID, 1) <> 0 
							) LookupQ
							--
							SELECT @myError = @result, @myRowcount = @@rowcount
							Set @ProteinDBIDListCount = @myRowcount

							If @ProteinDBIDListCount > 0	
							Begin -- <g>
								-- Remove the trailing comma from @ProteinDBIDList
								If Len(@ProteinDBIDList) > 0
									Set @ProteinDBIDList = Left(@ProteinDBIDList, Len(@ProteinDBIDList)-1)

								UPDATE T_Proteins
								SET Protein_DB_ID = 0, 
									Protein_Collection_ID = @CurrentID, 
									External_Reference_ID = SourceQ.Reference_ID, 
									External_Protein_ID = SourceQ.Protein_ID,
									Last_Affected = GetDate()
								FROM T_Proteins TargetQ INNER JOIN
										(	SELECT Protein_Name, Protein_ID, Reference_ID
											FROM MT_Main.dbo.V_DMS_Protein_Collection_Members_Import
											WHERE Protein_Collection_ID = @CurrentID
										) SourceQ ON TargetQ.Reference = SourceQ.Protein_Name COLLATE SQL_Latin1_General_CP1_CI_AS
								WHERE ISNULL(TargetQ.Protein_DB_ID, 1) <> 0 
								--
								SELECT @myError = @result, @myRowcount = @@rowcount
								--
								If @myError <> 0
								Begin
									Set @message = 'Error switching from using Protein_DB_ID ' + @ProteinDBIDList + ' to using ' + @ProteinCollectionDescription
									goto Done
								End
								--
								If @myRowcount > 0
								Begin -- <h>
									Set @ProteinSequenceDBSwitchPerformed = 1
										
									Set @message = 'Switched from using Protein_DB_ID'
									If @ProteinDBIDListCount > 1
										Set @message = @message + 's'
									Set @message = @message + ' ' + @ProteinDBIDList + ' to ' + @ProteinCollectionDescription + ' for ' + Convert(varchar(12), @myRowcount) + ' proteins'

									execute PostLogEntry 'Normal', @message, 'RefreshLocalProteinTable'
									Set @message = ''
								End -- </h>
							End -- </g>
						End -- </f1>

						---------------------------------------------------
						-- Update existing entries
						-- First, check for Protein Sequences that need to be updated
						-- Since a direct UPDATE query raises Sql Server error 8624 (see below)
						--  we'll populate a temporary table with the protein sequences for the proteins
						--  that currently have null protein sequences, then update them below
						-- However, we won't update them right away since we want to link on Protein_ID
						--  and that might currently be Null in T_Proteins
						---------------------------------------------------
						--
						TRUNCATE TABLE #T_Tmp_Protein_Sequence_Updates
						--
						INSERT INTO #T_Tmp_Protein_Sequence_Updates (Protein_ID, Protein_Sequence, Residue_Count)
						SELECT Protein_ID, Protein_Sequence, Residue_Count
						FROM MT_Main.dbo.V_DMS_Protein_Collection_Members_Import
						WHERE Protein_Collection_ID = @CurrentID AND 
							  Protein_Name IN (	SELECT Reference
												FROM T_Proteins
												WHERE ISNULL(T_Proteins.Protein_DB_ID, 0) = 0 AND 
													  ISNULL(T_Proteins.Protein_Collection_ID, @CurrentID) = @CurrentID AND 
													  Protein_Sequence IS NULL)
						--
						SELECT @myError = @result, @myRowcount = @@rowcount
						--
						If @myRowCount > 0
							Set @ProteinSequenceUpdateRequired = 1
						Else
							Set @ProteinSequenceUpdateRequired = 0
						--
						If @myError <> 0
						Begin
							Set @message = 'Error obtaining protein sequences to update for ' + @ProteinCollectionDescription
							goto Done
						End

						---------------------------------------------------
						-- Now update the other fields as needed
						-- Note: We cannot update Protein_Sequence here because
						--  it is a Text field and Sql Server raises this error
						--  message if we try to update it (probably related to the
						--  Protein_Sequences DB being located on another server):
						--    Server: Msg 8624, Level 16, State 123, Line 37
						--    Internal SQL Server error.
						---------------------------------------------------
						--
						UPDATE T_Proteins
						SET Description = Left(SourceQ.Description, 7500),
							Protein_Residue_Count = SourceQ.Residue_Count,
							Monoisotopic_Mass = SourceQ.Monoisotopic_Mass, 
							Protein_DB_ID = 0, 
							External_Reference_ID = SourceQ.Reference_ID, 
							External_Protein_ID = SourceQ.Protein_ID, 
							Protein_Collection_ID = @CurrentID,
							Last_Affected = GetDate()
						FROM (	SELECT  Protein_Name, Description, Residue_Count, 
										Monoisotopic_Mass, 
										Reference_ID, Protein_ID
								FROM MT_Main.dbo.V_DMS_Protein_Collection_Members_Import 
								WHERE Protein_Collection_ID = @CurrentID
							) SourceQ INNER JOIN
							T_Proteins ON SourceQ.Protein_Name = T_Proteins.Reference
						WHERE ISNULL(T_Proteins.Protein_DB_ID, 0) = 0 AND 
							  ISNULL(T_Proteins.Protein_Collection_ID, @CurrentID) = @CurrentID AND
							  (IsNull(T_Proteins.Description,'') <> Left(SourceQ.Description, 7500) OR 
							   IsNull(T_Proteins.Protein_Residue_Count,0) <> SourceQ.Residue_Count OR
							   IsNull(T_Proteins.Monoisotopic_Mass,0) <> SourceQ.Monoisotopic_Mass OR
							   T_Proteins.Protein_DB_ID IS NULL OR
							   T_Proteins.External_Reference_ID IS NULL OR
							   T_Proteins.External_Protein_ID IS NULL OR
							   T_Proteins.Protein_Collection_ID IS NULL OR
							   T_Proteins.External_Protein_ID IN (SELECT DISTINCT Protein_ID FROM #T_Tmp_Protein_Sequence_Updates)
							  )
						--
						SELECT @myError = @result, @myRowcount = @@rowcount
						--
						If @myError  <> 0
						Begin
							Set @message = 'Could not update Protein entries for ' + @ProteinCollectionDescription
							goto Done
						End


						If @ProteinSequenceUpdateRequired > 0
						Begin -- <f2>
							UPDATE T_Proteins
							SET Protein_Sequence = SourceQ.Protein_Sequence, 
								Protein_Residue_Count = SourceQ.Residue_Count,
								Last_Affected = GetDate()
							FROM T_Proteins INNER JOIN 
								 #T_Tmp_Protein_Sequence_Updates SourceQ ON 
								 T_Proteins.External_Protein_ID = SourceQ.Protein_ID AND 
								 T_Proteins.Protein_Collection_ID = @CurrentID
							--
							SELECT @myError = @result, @myRowcount = @@rowcount
							--
							If @myError  <> 0
							Begin
								Set @message = 'Error updating protein sequences for ' + @ProteinCollectionDescription
								goto Done
							End
						End -- </f2>

					End -- </e2>
				End -- </d>
    		End	-- </c2>
		End -- </b2>
	End -- </a>


	If @UseProteinSequencesDB = 0 OR @ForceLegacyDBProcessing <> 0
	Begin -- <a>
		
		---------------------------------------------------
		-- Create the temporary table to hold the
		--  Legacy Protein DB names and IDs
		---------------------------------------------------
		--

		If exists (select * from dbo.sysobjects where id = object_id(N'[#T_Tmp_Protein_Database_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#T_Tmp_Protein_Database_List]
		
		CREATE TABLE #T_Tmp_Protein_Database_List (
			ProteinDBName varchar(128) NOT NULL,
			ProteinDBID int NULL
		)

		---------------------------------------------------
		-- Get Legacy Protein Database name(s)
		---------------------------------------------------
		--
		INSERT INTO #T_Tmp_Protein_Database_List (ProteinDBName)
		SELECT Value
		FROM T_Process_Config
		WHERE [Name] = 'Protein_DB_Name' AND Len(Value) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myRowCount < 1
		Begin
			Set @message = 'No protein databases are defined in T_Process_Config'
			Set @myError = 40001
			goto Done
		End


		declare @ProteinDBName varchar(128)
		declare @ProteinDBID int
		declare @UndefinedProteinDBID tinyint
		declare @ProteinDBExists tinyint
		Set @UndefinedProteinDBID = 0
		Set @ProteinDBExists = 0
		
		-- Loop through the Legacy Protein database(s) and add or update the protein entries
		--

		Set @continue = 1
		While @continue = 1
		Begin -- <b>
			SELECT TOP 1 @ProteinDBName = ProteinDBName
			FROM #T_Tmp_Protein_Database_List
			ORDER BY ProteinDBName
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount = 0
				Set @continue = 0
			Else
			Begin -- <c>

				-- Lookup the ODB_ID value for @ProteinDBName in MT_Main
				--
				Set @ProteinDBID = 0
				
				SELECT @ProteinDBID = ODB_ID
				FROM MT_Main.dbo.T_ORF_Database_List
				WHERE ODB_Name = @ProteinDBName
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				If @myRowCount = 0
					Set @UndefinedProteinDBID = 1
				Else
					Set @UndefinedProteinDBID = 0
				
				Set @DBIDString = Convert(nvarchar(25), @ProteinDBID)

				
				-- Make sure the DB exists on this server
				--
				Set @myRowCount = 0
				SELECT @myRowCount = COUNT(*) 
				FROM master.dbo.sysdatabases
				WHERE [NAME] = @ProteinDBName
				
				If @myRowCount = 0
					Set @ProteinDBExists = 0
				Else
					Set @ProteinDBExists = 1
				
				If @ProteinDBExists = 1
				Begin -- <d>
					---------------------------------------------------
					-- Construct the Sql to populate T_Proteins
					---------------------------------------------------
					
					Set @S = ''

					---------------------------------------------------
					-- add new entries
					---------------------------------------------------
					If @importAllProteins <> 0
					Begin -- <e1>
						--
						If @infoOnly = 0
						Begin
							Set @S = @S + 'INSERT INTO T_Proteins '
							Set @S = @S + ' (Reference, Description, Protein_Sequence, Protein_Residue_Count, Monoisotopic_Mass, Protein_DB_ID, External_Reference_ID, External_Protein_ID) '
						End
						--
						Set @S = @S + ' SELECT '
						Set @S = @S + '  P.Reference, P.Description_from_Fasta, P.Protein_Sequence, P.Amino_Acid_Count, P.Monoisotopic_Mass, ' + @DBIDString + ' AS Protein_DB_ID, P.ORF_ID, P.ORF_ID'
						Set @S = @S + ' FROM '
						Set @S = @S +   '[' + @ProteinDBName + '].dbo.T_ORF AS P LEFT OUTER JOIN '
						Set @S = @S + '  T_Proteins ON P.Reference = T_Proteins.Reference '
						Set @S = @S + ' WHERE T_Proteins.Reference IS NULL AND Protein_DB_ID IS NULL'
						--
						exec @result = sp_executesql @S
						--
						select @myError = @result, @myRowcount = @@rowcount
						--
						If @myError  <> 0
						Begin
							Set @message = 'Could not add new Protein entries'
							goto Done
						End
						
						Set @numAdded = @numAdded + @myRowCount
					End -- </e1>


					If @infoOnly = 0 
					Begin -- <e2>

						---------------------------------------------------
						-- update existing entries
						---------------------------------------------------
						Set @S = ''

						Set @S = @S + ' UPDATE T_Proteins '
						Set @S = @S + ' Set '
						Set @S = @S + '  Description = P.Description_From_Fasta, Protein_Sequence = P.Protein_Sequence, '
						Set @S = @S + '  Protein_Residue_Count = P.Amino_Acid_Count, Monoisotopic_Mass = P.Monoisotopic_Mass, '
						Set @S = @S + '  Protein_DB_ID = ' + @DBIDString + ', External_Reference_ID = P.ORF_ID, '
						Set @S = @S + '  External_Protein_ID = P.ORF_ID, Last_Affected = GetDate()'
						Set @S = @S + ' FROM '
						Set @S = @S + '  T_Proteins INNER JOIN '
						Set @S = @S +    '[' + @ProteinDBName + '].dbo.T_ORF AS P ON '
						Set @S = @S + ' T_Proteins.Reference = P.Reference AND'
						Set @S = @S + '  IsNull(Protein_DB_ID, ' + @DBIDString + ') = ' + @DBIDString
						Set @S = @S + ' WHERE T_Proteins.Protein_Residue_Count <> P.Amino_Acid_Count OR'
						Set @S = @S +       ' T_Proteins.Monoisotopic_Mass <> P.Monoisotopic_Mass OR'
						Set @S = @S +       ' T_Proteins.External_Reference_ID <> P.ORF_ID'
						--
						exec @result = sp_executesql @S
						--
						select @myError = @result, @myRowcount = @@rowcount
						--
						If @myError  <> 0
						Begin
							Set @message = 'Could not update Protein entries'
							goto Done
						End

						
						If @myRowCount > 0 and @infoOnly = 0 And @UndefinedProteinDBID = 1
						Begin
							-- New proteins were added, but the Protein DB was unknown
							-- Post an entry to the log, but do not return an error
							Set @message = 'Protein database ' + @ProteinDBName + ' was not found in MT_Main..T_ORF_Database_List; newly imported Proteins have been assigned a Protein_DB_ID value of 0'
							execute PostLogEntry 'Error', @message, 'RefreshLocalProteinTable'
							Set @message = ''
						End
					End -- </e2>
				End -- </d>
				Else
				Begin
					-- Database does not exist
					-- Post an error message if @ProteinDBName is not blank, 'none', 'na', or '(na)'
					If Not (@ProteinDBName = '' Or @ProteinDBName = 'none' Or @ProteinDBName = 'na' Or @ProteinDBName = '(na)')
					Begin
						Set @message = 'Protein database ' + @ProteinDBName + ' was not found on this server'
						execute PostLogEntry 'Error', @message, 'RefreshLocalProteinTable'
						Set @message = ''
					End
				End
				
				DELETE FROM #T_Tmp_Protein_Database_List
				WHERE ProteinDBName = @ProteinDBName
				
			End -- </c>
		End -- </b>
	End -- </a>

Done:
	If @myError <> 0
	Begin
		Set @message = @message + ' (Error ' + Convert(varchar(12), @myError) + ')'
		
		If @infoOnly = 0
			execute PostLogEntry 'Error', @message, 'RefreshLocalProteinTable'
		Else
			Select @message As TheMessage
	End
	Else
	Begin
		If @ProteinSequenceDBSwitchPerformed <> 0
		Begin
			UPDATE T_Process_Step_Control
			SET enabled = 1
			WHERE (Processing_Step_Name = 'UseProteinSequencesDB')
		End
		
		Set @message = 'Refresh local Protein reference table: ' +  convert(varchar(12), @numAdded)
	End
	
	return @myError


GO

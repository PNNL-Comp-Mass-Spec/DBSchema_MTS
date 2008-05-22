/****** Object:  StoredProcedure [dbo].[FixDuplicatePeptideToProteinEntries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE dbo.FixDuplicatePeptideToProteinEntries
/****************************************************
**
**	Desc:	Looks for proteins in T_Proteins that are identical for the first 34 characters
**			If any are found, then creates a mapping table to map duplicate Ref_ID to master Ref_ID
**			Next, uses this mapping table to either delete extra entries in T_Peptide_to_Protein_Map
**			 or to update entries to point to the correct Ref_ID 
**
**	Auth:	mem
**	Date:	02/27/2007
**			04/23/2008 mem - Added @PreviewPeptideRowsToDeleteOrUpdate
**
*****************************************************/
(
	@DeleteExtraProteins tinyint = 1,
	@infoOnly tinyint = 0,
	@PreviewDuplicateProteins tinyint = 0,						-- Only used if @infoOnly <> 0
	@PreviewPeptideRowsToDeleteOrUpdate tinyint = 0,			-- Only used if @infoOnly <> 0
	@PeptideToProteinMapEntriesUpdated int = 0 output,
	@PeptideToProteinMapEntriesDeleted int = 0 output,
	@ProteinEntriesDeleted int = 0 output,
	@message varchar(512)='' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @ProteinCountToUpdate int
	declare @Message2 varchar(512)

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		---------------------------------------------------
		-- Validate the inputs
		---------------------------------------------------
		Set @CurrentLocation = 'Validate the inputs'

		set @DeleteExtraProteins = IsNull(@DeleteExtraProteins, 0)
		set @infoOnly = IsNull(@infoOnly, 0)
		set @PreviewDuplicateProteins = IsNull(@PreviewDuplicateProteins, 0)
		set @PreviewPeptideRowsToDeleteOrUpdate = IsNull(@PreviewPeptideRowsToDeleteOrUpdate, 0)
		set @message = ''
		set @PeptideToProteinMapEntriesUpdated = 0
		set @PeptideToProteinMapEntriesDeleted = 0
		set @ProteinEntriesDeleted = 0

		
		---------------------------------------------------
		-- Create some temporary tables
		---------------------------------------------------
		--
		CREATE TABLE #Tmp_Ref_ID_Updates (
			Ref_ID int NOT NULL,
			Ref_ID_Master int NOT NULL
		)

		CREATE CLUSTERED INDEX #IX_Tmp_Ref_ID_Updates_Ref_ID ON #Tmp_Ref_ID_Updates (Ref_ID)


		CREATE TABLE #Tmp_EntriesToDelete (
			Peptide_ID int NOT NULL,
			Ref_ID int NOT NULL
		)
		
		CREATE CLUSTERED INDEX #IX_Tmp_EntriesToDelete_Peptide_ID ON #Tmp_EntriesToDelete (Peptide_ID)
		
		
		---------------------------------------------------
		-- Populate #Tmp_Ref_ID_Updates
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Populate #Tmp_Ref_ID_Updates'

		INSERT INTO #Tmp_Ref_ID_Updates (Ref_ID, Ref_ID_Master)
		SELECT T_Proteins.Ref_ID, MappingQ.Ref_ID_Master
		FROM T_Proteins INNER JOIN
				(	SELECT SUBSTRING(Reference, 1, 34) AS ReferenceStart
					FROM T_Proteins
					GROUP BY SUBSTRING(Reference, 1, 34)
					HAVING (COUNT(*) > 1)
				) ProteinQ ON SUBSTRING(T_Proteins.Reference, 1, 34) = ProteinQ.ReferenceStart INNER JOIN
				(	SELECT OuterQ.ReferenceStart, MIN(T_Proteins.Ref_ID) AS Ref_ID_Master
					FROM T_Proteins INNER JOIN
					(	SELECT ProteinQ.ReferenceStart, MAX(Len(T_Proteins.Reference)) AS RefNameLength
						FROM T_Proteins INNER JOIN
							(	SELECT SUBSTRING(Reference, 1, 34) AS ReferenceStart
								FROM T_Proteins
								GROUP BY SUBSTRING(Reference, 1, 34)
								HAVING (COUNT(*) > 1)
							) ProteinQ ON SUBSTRING(T_Proteins.Reference, 1, 34) = ProteinQ.ReferenceStart
						GROUP BY ProteinQ.ReferenceStart
					) OuterQ ON SUBSTRING(T_Proteins.Reference, 1, 34) = OuterQ.ReferenceStart AND 
								LEN(T_Proteins.Reference) = OuterQ.RefNameLength
					GROUP BY OuterQ.ReferenceStart
				) MappingQ ON ProteinQ.ReferenceStart = MappingQ.ReferenceStart AND 
							T_Proteins.Ref_ID <> MappingQ.Ref_ID_Master
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		Set @ProteinCountToUpdate = @myRowCount
		
		If @myError <> 0
		Begin
			set @message = 'Error populating #Tmp_Ref_ID_Updates'
			Goto Done
		End
		
		If @ProteinCountToUpdate = 0
		Begin
			set @message = 'No duplicate proteins were found in T_Proteins in ' + DB_Name()
			If @infoOnly <> 0
				SELECT @message AS Preview_Message
		End
		Else
		Begin -- <a>
			If @infoOnly <> 0
			Begin
				---------------------------------------------------
				-- Preview the data that would be updated
				---------------------------------------------------

				Set @message = 'Found ' + Convert(varchar(12), @ProteinCountToUpdate) + ' proteins to update in ' + DB_Name() 

				Set @CurrentLocation = 'Count the number of entries in T_Peptide_to_Protein_Map that would be deleted'
				-- 
				SELECT @PeptideToProteinMapEntriesDeleted = COUNT(*)
				FROM T_Peptide_to_Protein_Map PPM INNER JOIN
						(	SELECT PPM.Peptide_ID, PPM.Ref_ID
							FROM T_Peptide_to_Protein_Map PPM INNER JOIN
								#Tmp_Ref_ID_Updates U ON PPM.Ref_ID = U.Ref_ID INNER JOIN
								T_Peptide_to_Protein_Map PPM_Master ON U.Ref_ID_Master = PPM_Master.Ref_ID AND 
									PPM.Peptide_ID = PPM_Master.Peptide_ID
						) DeleteQ ON PPM.Peptide_ID = DeleteQ.Peptide_ID AND PPM.Ref_ID = DeleteQ.Ref_ID
						

				If @PreviewPeptideRowsToDeleteOrUpdate <> 0
				Begin
					SELECT Row_Number() OVER (ORDER BY PPM.Peptide_ID, PPM.Ref_ID) AS Entry_to_Delete,
					       PPM.*
					FROM T_Peptide_to_Protein_Map PPM INNER JOIN
							(	SELECT PPM.Peptide_ID, PPM.Ref_ID
								FROM T_Peptide_to_Protein_Map PPM INNER JOIN
									#Tmp_Ref_ID_Updates U ON PPM.Ref_ID = U.Ref_ID INNER JOIN
									T_Peptide_to_Protein_Map PPM_Master ON U.Ref_ID_Master = PPM_Master.Ref_ID AND 
										PPM.Peptide_ID = PPM_Master.Peptide_ID
							) DeleteQ ON PPM.Peptide_ID = DeleteQ.Peptide_ID AND PPM.Ref_ID = DeleteQ.Ref_ID
					ORDER BY PPM.Peptide_ID, PPM.Ref_ID
					
					INSERT INTO #Tmp_EntriesToDelete (Peptide_ID, Ref_ID)
					SELECT PPM.Peptide_ID, PPM.Ref_ID
					FROM T_Peptide_to_Protein_Map PPM INNER JOIN
							(	SELECT PPM.Peptide_ID, PPM.Ref_ID
								FROM T_Peptide_to_Protein_Map PPM INNER JOIN
									#Tmp_Ref_ID_Updates U ON PPM.Ref_ID = U.Ref_ID INNER JOIN
									T_Peptide_to_Protein_Map PPM_Master ON U.Ref_ID_Master = PPM_Master.Ref_ID AND 
										PPM.Peptide_ID = PPM_Master.Peptide_ID
							) DeleteQ ON PPM.Peptide_ID = DeleteQ.Peptide_ID AND PPM.Ref_ID = DeleteQ.Ref_ID
					
										
				End
						
				Set @CurrentLocation = 'Count the number of entries in T_Peptide_to_Protein_Map that would be updated'
				-- 
				SELECT @PeptideToProteinMapEntriesUpdated = COUNT(*)
				FROM T_Peptide_to_Protein_Map PPM INNER JOIN 
					#Tmp_Ref_ID_Updates U ON PPM.Ref_ID = U.Ref_ID

				If @PeptideToProteinMapEntriesUpdated > 0 And @PeptideToProteinMapEntriesDeleted > 0
				Begin
					-- Note: We need to correct @PeptideToProteinMapEntriesUpdated using @PeptideToProteinMapEntriesDeleted
					--       since peptides that match the first query will also match the second query
					Set @PeptideToProteinMapEntriesUpdated = @PeptideToProteinMapEntriesUpdated - @PeptideToProteinMapEntriesDeleted
				End
				
				If @PreviewPeptideRowsToDeleteOrUpdate <> 0
				Begin
					SELECT Row_Number() OVER (ORDER BY PPM.Peptide_ID, PPM.Ref_ID) AS Entry_to_Update,
					       PPM.Peptide_ID AS Peptide_ID_to_Update,
					       PPM.Ref_ID AS Ref_ID_Old,
					       U.Ref_ID_Master AS Ref_ID_New
					FROM T_Peptide_to_Protein_Map PPM
					     INNER JOIN #Tmp_Ref_ID_Updates U
					       ON PPM.Ref_ID = U.Ref_ID
					     LEFT OUTER JOIN #Tmp_EntriesToDelete ED
					       ON PPM.Peptide_ID = ED.Peptide_ID AND
					          PPM.Ref_ID = ED.Ref_ID
					WHERE ED.Peptide_ID IS NULL
				End
				
				Set @CurrentLocation = 'Update the status message'
				-- 
				If @PeptideToProteinMapEntriesUpdated > 0 OR @PeptideToProteinMapEntriesDeleted > 0
					Set @Message = @Message + '; found ' + convert(varchar(12), @PeptideToProteinMapEntriesDeleted) + ' rows to delete and ' + convert(varchar(12), @PeptideToProteinMapEntriesUpdated) + ' rows to update in T_Peptide_to_Protein_Map'
				Else
					Set @Message = @message + '; Did not find any entries in T_Peptide_to_Protein_Map to update'
					
				SELECT @message As Preview_Message
				
				If @PreviewDuplicateProteins <> 0
				Begin
					Set @CurrentLocation = 'Display the protein information, showing the truncated name and the full name'
					-- 
					SELECT Prot.Ref_ID, Prot.Reference, #Tmp_Ref_ID_Updates.Ref_ID_Master, Prot_Master.Reference AS Reference_Master
					FROM T_Proteins Prot INNER JOIN
						#Tmp_Ref_ID_Updates ON Prot.Ref_ID = #Tmp_Ref_ID_Updates.Ref_ID INNER JOIN
						T_Proteins Prot_Master ON #Tmp_Ref_ID_Updates.Ref_ID_Master = Prot_Master.Ref_ID
					ORDER BY Prot_Master.Reference, Prot.Reference
				End				
			End
			Else
			Begin -- <b>
				---------------------------------------------------
				-- Perform the updates
				-- Use a transaction to assure both the Delete and 
				--  the Update queries are successful
				---------------------------------------------------
				
				Begin Tran ApplyUpdates

				Set @CurrentLocation = 'Delete entries from T_Peptide_to_Protein_Map that also have a map to the full Ref_ID'
				--
				DELETE T_Peptide_to_Protein_Map
				FROM T_Peptide_to_Protein_Map PPM INNER JOIN
						(	SELECT PPM.Peptide_ID, PPM.Ref_ID
							FROM T_Peptide_to_Protein_Map PPM INNER JOIN
								#Tmp_Ref_ID_Updates U ON PPM.Ref_ID = U.Ref_ID INNER JOIN
								T_Peptide_to_Protein_Map PPM_Master ON U.Ref_ID_Master = PPM_Master.Ref_ID AND 
									PPM.Peptide_ID = PPM_Master.Peptide_ID
						) DeleteQ ON PPM.Peptide_ID = DeleteQ.Peptide_ID AND PPM.Ref_ID = DeleteQ.Ref_ID
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				Set @PeptideToProteinMapEntriesDeleted = @myRowCount

				Set @CurrentLocation = 'Update entries in T_Peptide_to_Protein_Map to use Ref_ID_Master instead of Ref_ID'
				-- 
				UPDATE T_Peptide_to_Protein_Map
				SET Ref_ID = U.Ref_ID_Master
				FROM T_Peptide_to_Protein_Map PPM INNER JOIN 
					#Tmp_Ref_ID_Updates U ON PPM.Ref_ID = U.Ref_ID
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				Set @PeptideToProteinMapEntriesUpdated = @myRowCount

				Set @CurrentLocation = 'Commit the transaction'
				--
				Commit Tran ApplyUpdates
				
				if @myError <> 0
				Begin
					-- Error occurred
					Set @CurrentLocation = 'Error occurred, rollback the transaction'

					Rollback Tran ApplyUpdates
					set @message = 'Error deleting and/or updating entries in T_Peptide_to_Protein_Map; Error ID: ' + Convert(varchar(12), @myError)
					exec PostLogEntry 'Error', @message, 'FixDuplicatePeptideToProteinEntries' 
				End
				Else
				Begin -- <c>
					---------------------------------------------------
					-- Successfully updated the data; post a log entry
					---------------------------------------------------

					Set @CurrentLocation = 'Update the status message'
					-- 
					If @PeptideToProteinMapEntriesDeleted > 0 Or @PeptideToProteinMapEntriesUpdated > 0
					Begin 
						Set @Message = 'Updated entries in T_Peptide_to_Protein_Map that pointed to near-duplicate proteins (matching the first 34 characters)'
						Set @Message = @Message + '; deleted ' + convert(varchar(12), @PeptideToProteinMapEntriesDeleted) + ' rows and updated ' + convert(varchar(12), @PeptideToProteinMapEntriesUpdated) + ' rows'
						
						print @message
						exec PostLogEntry 'Normal', @message, 'FixDuplicatePeptideToProteinEntries' 
					End
					Else
					Begin
						Set @Message = 'Did not find any data in T_Peptide_to_Protein_Map that needed to be updated'
						print @message
					End
					
					if @DeleteExtraProteins <> 0
					Begin
						---------------------------------------------------
						-- Also delete the extra proteins
						---------------------------------------------------
						
						Set @CurrentLocation = 'Delete the extra proteins'
						-- 
						DELETE T_Proteins
						FROM T_Proteins INNER JOIN
							#Tmp_Ref_ID_Updates U ON T_Proteins.Ref_ID = U.Ref_ID
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
						
						Set @ProteinEntriesDeleted = @myRowCount
						
						If @myRowCount > 0
						Begin -- <e>
							Set @Message2 = 'Deleted ' + Convert(varchar(12), @ProteinEntriesDeleted) + ' near-duplicate proteins in T_Proteins (matched the first 34 characters of another protein)'
							
							print @Message2
							exec PostLogEntry 'Normal', @Message2, 'FixDuplicatePeptideToProteinEntries' 
							
							Set @Message = @Message + '; ' + @Message2
						End -- </e>
					End -- </d>				
				End -- </c>
			End -- </b>
		End -- </a>

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'FixDuplicatePeptideToProteinEntries')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	DROP TABLE #Tmp_Ref_ID_Updates
	DROP TABLE #Tmp_EntriesToDelete
	
	return @myError


GO

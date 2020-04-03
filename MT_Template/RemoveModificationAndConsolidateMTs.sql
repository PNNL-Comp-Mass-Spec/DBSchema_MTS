/****** Object:  StoredProcedure [dbo].[RemoveModificationAndConsolidateMTs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RemoveModificationAndConsolidateMTs
/****************************************************
**
**	Desc: Examines the modified PMTs to look for those
**		  that contain the given modification.
**		  Removes the modification from Mod_Description and
**		  updates Mod_Count.  When doing this, assigns a new
**		  mass_tag_id value (negative number).
**
**		  After this, looks for entries with identical sequences
**		  and identical mod_descriptions, and deletes
**		  the redundant ones, favoring positive Mass_tag_id values.
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	10/20/2004
**			09/19/2006 mem - Added support for table T_Mass_Tag_Peptide_Prophet_Stats
**          04/09/2020 mem - Expand Mass_Correction_Tag to varchar(32)
**
*****************************************************/
(
	@ModSymbolToFind varchar(8) = 'Deamide',
	@MaxPeptidesToProcess int = 0,
	@message varchar(255) = '' output,
	@PeptidesProcessedCount int = 0 output
)
AS
	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @message = ''
	Set @PeptidesProcessedCount = 0

	Declare @ModSymbolForLikeClause varchar(10)

	Set @ModSymbolToFind = LTrim(RTrim(@ModSymbolToFind))
	Set @ModSymbolForLikeClause = '%' + @ModSymbolToFind + '%'


	Declare @MassTagID int
	Declare @peptide varchar(850)
	Declare @modCount int
	Declare @modCountNew int
	Declare @modDescription varchar(2048)
	Declare @modDescriptionNew varchar(2048)

	Declare @UniqueModID int

	Set @UniqueModID = -1

	Declare @result int
	Declare @continue int
	Declare @PMTsUpdatedCount int
	Declare @PMTsDeletedCount int
	Declare @MTIDCountUpdated int

	Set @PMTsUpdatedCount = 0
	Set @PMTsDeletedCount = 0
	Set @MTIDCountUpdated = 0

	---------------------------------------------------
	-- create temporary table to hold the mass tags being processed
	---------------------------------------------------

--	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#TempMassTagsWork]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
--	drop table dbo.#TempMassTagsWork

	CREATE TABLE #TempMassTagsWork (
		[Mass_Tag_ID] int NOT NULL,
		[Mass_Tag_ID_New] INT NULL,
		[Peptide] varchar(850) NULL,
		[Mod_Count] int NOT NULL,
		[Mod_Description] varchar(2048) NOT NULL,
		[Mod_Count_New] int NULL,
		[Mod_Description_New] varchar(2048) NULL,
		[Delete_MT] tinyint NOT NULL
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to create #TempMassTagsWork temporary table'
		goto Done
	end

	CREATE INDEX #IX_MassTagsWork_Peptide ON #TempMassTagsWork (Peptide)


	---------------------------------------------------
	-- create temporary table to hold mod set members
	---------------------------------------------------

	CREATE TABLE #TModDescriptors (
		[Mass_Tag_ID] [int] NULL,
		[Mass_Correction_Tag] [varchar] (32) NULL,
		[Position] [int] NULL,
		[UniqueModID] [int] IDENTITY
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to create #TModDescriptors temporary table'
		goto Done
	end

	CREATE UNIQUE INDEX #IX_ModDescriptors_UniqueModID ON #TModDescriptors (UniqueModID)


	If Len(@ModSymbolToFind) = 0
	Begin
		-- No Mod Symbol was provided; we're simply consolidating PMTs
		INSERT INTO #TempMassTagsWork (Mass_Tag_ID, Mass_Tag_ID_New, Peptide, Mod_Count, Mod_Description, Mod_Count_New, Mod_Description_New, Delete_MT)
		SELECT Mass_Tag_ID, Mass_Tag_ID, Peptide, Mod_Count, Mod_Description, Mod_Count, Mod_Description, 0 AS Delete_MT
		FROM T_Mass_Tags
		WHERE (Mod_Count = 0)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	Else
	Begin
		-- Populate a temporary table with the necessary values from T_Mass_Tags
		-- Selecting those PMTs that contain @ModSymbolToFind in Mod_Description

		INSERT INTO #TempMassTagsWork (Mass_Tag_ID, Peptide, Mod_Count, Mod_Description, Delete_MT)
		SELECT Mass_Tag_ID, Peptide, Mod_Count, Mod_Description, 0 AS Delete_MT
		FROM T_Mass_Tags
		WHERE (Mod_Count > 0) AND (Mod_Description LIKE @ModSymbolForLikeClause)
		ORDER BY Peptide
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error trying to populate #TempMassTagsWork'
			goto Done
		end


		-----------------------------------------------
		-- Process each entry in #TempMassTagsWork
		-----------------------------------------------
		Set @continue = 1
		Set @MassTagID = -100000000
		While @continue > 0
		Begin -- <A>
			-- Grab next PMT
			SELECT TOP 1
					@MassTagID = Mass_Tag_ID,
					@peptide = Peptide,
					@modCount = Mod_Count,
					@modDescription = Mod_Description
			FROM #TempMassTagsWork
			WHERE Mass_Tag_ID > @MassTagID
			ORDER BY Mass_Tag_ID ASC
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			If @myError <> 0
			Begin
				Set @message = 'Error in reading peptide info from table #TempMassTagsWork'
				Goto done
			End
			Set @continue = @myRowCount

			If @continue > 0
			Begin -- <B>

				-- Note: Rather than using Truncate Table after every sequence to clear #TModDescriptors, it is
				--       more efficient to continually add new modifications to the table as peptides are processed
				--       and only Truncate the table every 1000 sequences (arbitrary value)
				-- Continual use of Truncate Table actually slows down this procedure due to drastically increased disk activity

				If @UniqueModID > 1000
				Begin
					TRUNCATE TABLE #TModDescriptors
					Set @UniqueModID = -1
				End

				-- unroll mod description into temporary table (#TModDescriptors)
				--
				Set @result = 0
				exec @result = UnrollModDescription
									@MassTagID,
									@modDescription,
									@message = @message output
				if @result <> 0
				begin
					Set @message = 'Error unrolling mod description ' + @modDescription + ' for Mass_Tag_ID ' + Convert(varchar(11), @MassTagID)

					if @result = 90000
						Set @message = @message + '; mod not in the expected form'

					goto Done
				end

				-- Delete all occurrences of @ModSymbolToFind in #TModDescriptors
				DELETE FROM #TModDescriptors
				WHERE	Mass_Tag_ID = @MassTagID AND
						LTrim(RTrim(Mass_Correction_Tag)) = @ModSymbolToFind
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @myRowCount = 0
				Begin
					-- No rows were deleted; this is unexpected
					Set @message = 'Unable to find any rows containing ' + @ModSymbolToFind + ' after unrolling the mods from ' + @modDescription + ' for Mass_Tag_ID ' + Convert(varchar(11), @MassTagID) + '; this is unexpected'

					goto Done

				End
				Else
				Begin

					-- Re-construct the mod description
					Set @modDescriptionNew = ''
					SELECT @modDescriptionNew = @modDescriptionNew + Ltrim(RTrim(Mass_Correction_Tag)) + ':' + LTrim(RTrim(Convert(varchar(11), [Position]))) + ','
					FROM #TModDescriptors
					WHERE Mass_Tag_ID = @MassTagID
					ORDER BY [Position], UniqueModID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount

					Set @modCountNew = @myRowCount

					-- Remove the trailing comma
					If Len(@modDescriptionNew) > 0
						Set @modDescriptionNew = SubString(@modDescriptionNew, 1, Len(@modDescriptionNew)-1)

					-- Update the PMT in #TempMassTagsWork
					UPDATE #TempMassTagsWork
					SET  Mass_Tag_ID_New = -Abs(@MassTagID), Mod_Count_New = @modCountNew, Mod_Description_New = @modDescriptionNew
					WHERE Mass_Tag_ID = @MassTagID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount

					Set @PMTsUpdatedCount = @PMTsUpdatedCount + 1

				End


				Set @PeptidesProcessedCount = @PeptidesProcessedCount + 1
				If @MaxPeptidesToProcess > 0
				Begin
					If @PeptidesProcessedCount >= @MaxPeptidesToProcess
						Set @continue = 0
				End

			End	 -- </B>
		End -- </A>


		Set @message = ''

		-----------------------------------------------
		-- Add the PMTs to #TempMassTagsWork that that match Mod_Count_New and Mod_Description_New, but are not yet present
		-- None of these peptides will contain @ModSymbolToFind
		-----------------------------------------------
		--
		INSERT INTO #TempMassTagsWork (Mass_Tag_ID, Mass_Tag_ID_New, Peptide, Mod_Count, Mod_Description, Mod_Count_New, Mod_Description_New, Delete_MT)
		SELECT LookupQ.Mass_Tag_ID, LookupQ.Mass_Tag_ID, LookupQ.Peptide, LookupQ.Mod_Count, LookupQ.Mod_Description, LookupQ.Mod_Count, LookupQ.Mod_Description, 0 AS Delete_MT
		FROM (	SELECT DISTINCT MT.Mass_Tag_ID, MT.Peptide, MT.Mod_Count, MT.Mod_Description
				FROM T_Mass_Tags AS MT INNER JOIN #TempMassTagsWork AS MTW ON
						MT.Peptide = MTW.Peptide AND
						MT.Mod_Count = MTW.Mod_Count_New AND
						MT.Mod_Description = MTW.Mod_Description_New AND
						MT.Mass_Tag_ID <> MTW.Mass_Tag_ID
			) As LookupQ LEFT OUTER JOIN #TempMassTagsWork ON LookupQ.Mass_Tag_ID = #TempMassTagsWork.Mass_Tag_ID
		WHERE #TempMassTagsWork.Mass_Tag_ID Is Null
		ORDER BY LookupQ.Peptide
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

	-- Set Delete_MT = 1 for peptides in #TempMassTagsWork that have Mass_Tag_ID_New values defined
	UPDATE #TempMassTagsWork
	SET Delete_MT = 1
	WHERE NOT #TempMassTagsWork.Mass_Tag_ID_New Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	-- Set Delete_MT = 0 for one representative Mass_Tag_ID
	--  for each unique combo of Peptide, Mod_Count_New, and Mod_Description_New
	-- Favor the largest Mass_Tag_ID value (to thus not favor negative Mass_Tag_ID values)
	UPDATE #TempMassTagsWork
	SET Delete_MT = 0
	FROM #TempMassTagsWork INNER JOIN (
			SELECT MAX(Mass_Tag_ID_New) AS Max_MTID_New
			FROM #TempMassTagsWork
			WHERE (NOT (Mod_Count_New IS NULL))
			GROUP BY Peptide, Mod_Count_New, Mod_Description_New
			) As LookupQ ON #TempMassTagsWork.Mass_Tag_ID_New = LookupQ.Max_MTID_New
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Make sure no PMTs have PMT_Quality_Score = -100
	--
	UPDATE T_Mass_Tags
	SET PMT_Quality_Score = 0
	WHERE PMT_Quality_Score = -100
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Mark the mass tags in T_Mass_Tags that should be deleted
	-- Do this by setting PMT_Quality_Score to -100
	--
	UPDATE T_Mass_Tags
	SET PMT_Quality_Score = -100
	FROM #TempMassTagsWork INNER JOIN T_Mass_Tags ON
		#TempMassTagsWork.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
	WHERE #TempMassTagsWork.Delete_MT = 1 AND NOT #TempMassTagsWork.Mass_Tag_ID_New Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	---------------------------
	--Change the following FK's to cascade updates:
	---------------------------
	ALTER TABLE dbo.T_FTICR_UMC_ResultDetails
		DROP CONSTRAINT FK_T_FTICR_UMC_ResultDetails_T_Mass_Tags
	ALTER TABLE dbo.T_FTICR_UMC_ResultDetails WITH NOCHECK ADD CONSTRAINT
		FK_T_FTICR_UMC_ResultDetails_T_Mass_Tags FOREIGN KEY
		(Mass_Tag_ID) REFERENCES dbo.T_Mass_Tags (Mass_Tag_ID) ON UPDATE CASCADE

	ALTER TABLE dbo.T_Mass_Tag_to_Protein_Map
		DROP CONSTRAINT FK_T_Mass_Tag_to_Protein_Map_T_Mass_Tags
	ALTER TABLE dbo.T_Mass_Tag_to_Protein_Map WITH NOCHECK ADD CONSTRAINT
		FK_T_Mass_Tag_to_Protein_Map_T_Mass_Tags FOREIGN KEY
		(Mass_Tag_ID) REFERENCES dbo.T_Mass_Tags (Mass_Tag_ID) ON UPDATE CASCADE

	ALTER TABLE dbo.T_Quantitation_ResultDetails
		DROP CONSTRAINT FK_T_Quantitation_ResultDetails_T_Mass_Tags
	ALTER TABLE dbo.T_Quantitation_ResultDetails WITH NOCHECK ADD CONSTRAINT
		FK_T_Quantitation_ResultDetails_T_Mass_Tags FOREIGN KEY
		(Mass_Tag_ID) REFERENCES dbo.T_Mass_Tags (Mass_Tag_ID) ON UPDATE CASCADE

	ALTER TABLE dbo.T_Peptides
		DROP CONSTRAINT FK_T_Peptides_T_Mass_Tags
	ALTER TABLE dbo.T_Peptides WITH NOCHECK ADD CONSTRAINT

		FK_T_Peptides_T_Mass_Tags FOREIGN KEY
		(Mass_Tag_ID) REFERENCES dbo.T_Mass_Tags (Mass_Tag_ID) ON UPDATE CASCADE

	ALTER TABLE dbo.T_Mass_Tags_NET
		DROP CONSTRAINT FK_T_Mass_Tags_NET_T_Mass_Tags
	ALTER TABLE dbo.T_Mass_Tags_NET WITH NOCHECK ADD CONSTRAINT
		FK_T_Mass_Tags_NET_T_Mass_Tags FOREIGN KEY
		(Mass_Tag_ID) REFERENCES dbo.T_Mass_Tags (Mass_Tag_ID) ON UPDATE CASCADE


	ALTER TABLE dbo.T_Mass_Tag_Peptide_Prophet_Stats
		DROP CONSTRAINT FK_T_Mass_Tag_Peptide_Prophet_Stats_T_Mass_Tags
	ALTER TABLE dbo.T_Mass_Tag_Peptide_Prophet_Stats WITH NOCHECK ADD CONSTRAINT
		FK_T_Mass_Tag_Peptide_Prophet_Stats_T_Mass_Tags FOREIGN KEY
		(Mass_Tag_ID) REFERENCES dbo.T_Mass_Tags (Mass_Tag_ID) ON UPDATE CASCADE


	---------------------------
	-- We can now delete the PMTs in T_Mass_Tags that are listed in #TempMassTagsWork with Delete_MT=1
	-- Need to delete the PMTs in several dependent tables before deleting them from T_Mass_Tags
	---------------------------

	-- Decrement MassTag_Hit_Count for the affected mass tags in the UMC_Results table
	UPDATE T_FTICR_UMC_Results
	SET T_FTICR_UMC_Results.MassTag_Hit_Count = T_FTICR_UMC_Results.MassTag_Hit_Count - 1
	FROM T_FTICR_UMC_Results INNER JOIN
		T_FTICR_UMC_ResultDetails AS FURD ON
		T_FTICR_UMC_Results.UMC_Results_ID = FURD.UMC_Results_ID
		INNER JOIN
		T_Mass_Tags ON FURD.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
	WHERE (T_Mass_Tags.PMT_Quality_Score = -100)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Delete the affected mass tags from the UMC_ResultDetails table
	DELETE T_FTICR_UMC_ResultDetails
	FROM T_FTICR_UMC_ResultDetails AS FURD INNER JOIN
		T_Mass_Tags ON FURD.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
	WHERE (T_Mass_Tags.PMT_Quality_Score = -100)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Decrement MassTagCountUniqueObserved for the affected mass tags in T_Quantitation_Results
	UPDATE T_Quantitation_Results
	SET MassTagCountUniqueObserved = MassTagCountUniqueObserved - 1
	FROM T_Mass_Tags INNER JOIN
		T_Quantitation_ResultDetails AS QRD ON
		T_Mass_Tags.Mass_Tag_ID = QRD.Mass_Tag_ID
		INNER JOIN
		T_Quantitation_Results AS QR ON QRD.QR_ID = QR.QR_ID
	WHERE (T_Mass_Tags.PMT_Quality_Score = -100)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Delete the affected mass tags from T_Quantitation_ResultDetails
	DELETE T_Quantitation_ResultDetails
	FROM T_Mass_Tags INNER JOIN
		T_Quantitation_ResultDetails AS QRD ON
		T_Mass_Tags.Mass_Tag_ID = QRD.Mass_Tag_ID
	WHERE (T_Mass_Tags.PMT_Quality_Score = -100)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Delete Proteins in T_Quantitation_Results that have no matching mass tags
	DELETE T_Quantitation_Results
	FROM T_Quantitation_Results
	WHERE (MassTagCountUniqueObserved = 0)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Delete the Mass Tag to Protein mapping
	DELETE T_Mass_Tag_to_Protein_Map
	FROM T_Mass_Tags INNER JOIN
		T_Mass_Tag_to_Protein_Map AS MTPM ON
		T_Mass_Tags.Mass_Tag_ID = MTPM.Mass_Tag_ID
	WHERE (T_Mass_Tags.PMT_Quality_Score = -100)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Delete the NET value
	DELETE T_Mass_Tags_NET
	FROM T_Mass_Tags_NET AS MTN INNER JOIN
		T_Mass_Tags ON T_Mass_Tags.Mass_Tag_ID = MTN.Mass_Tag_ID
	WHERE (T_Mass_Tags.PMT_Quality_Score = -100)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	---------------------------
	-- Update the Mass_Tag_ID values for the PMTs in #TempMassTagsWork that have
	--   negative Mass_Tag_ID_New values and Delete_MT = 0
	-- This needs to be done before we update T_Peptides following this query
	---------------------------
	--
	UPDATE T_Mass_Tags
	SET Mass_Tag_ID = Mass_Tag_ID_New, Mod_Count = Mod_Count_New, Mod_Description = Mod_Description_New
	FROM T_Mass_Tags INNER JOIN #TempMassTagsWork ON
		 T_Mass_Tags.Mass_Tag_ID = #TempMassTagsWork.Mass_Tag_ID
	WHERE #TempMassTagsWork.Delete_MT = 0 AND
		  #TempMassTagsWork.Mass_Tag_ID_New < 0 AND
		  #TempMassTagsWork.Mass_Tag_ID <> #TempMassTagsWork.Mass_Tag_ID_New
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @MTIDCountUpdated = @myRowCount

	---------------------------
	-- Now update the Mass_Tag_ID values in T_Peptides as needed
	---------------------------
	--
	UPDATE T_Peptides
	SET Mass_Tag_ID = LookupQ.Mass_Tag_ID
	FROM T_Peptides INNER JOIN
			(	SELECT MTW.Mass_Tag_ID AS Mass_Tag_ID_Old, MT.Mass_Tag_ID
				FROM #TempMassTagsWork MTW INNER JOIN T_Mass_Tags MT ON
					 MTW.Mod_Description_New = MT.Mod_Description AND
					 MTW.Mod_Count_New = MT.Mod_Count AND
					 MTW.Peptide = MT.Peptide
				WHERE MTW.Delete_MT = 1 AND
					  NOT (MTW.Mass_Tag_ID_New IS NULL)
			) AS LookupQ ON
		 T_Peptides.Mass_Tag_ID = LookupQ.Mass_Tag_ID_Old
   	--
	SELECT @myError = @@error, @myRowCount = @@rowcount



	-- We can now, finally, delete the invalid mass tags from T_Mass_Tags
	-- This takes a while; to speed things up, we first remove the foreign keys to this table
	ALTER TABLE dbo.T_FTICR_UMC_ResultDetails DROP CONSTRAINT FK_T_FTICR_UMC_ResultDetails_T_Mass_Tags
	ALTER TABLE dbo.T_Mass_Tag_to_Protein_Map DROP CONSTRAINT FK_T_Mass_Tag_to_Protein_Map_T_Mass_Tags
	ALTER TABLE dbo.T_Mass_Tags_NET DROP CONSTRAINT FK_T_Mass_Tags_NET_T_Mass_Tags
	ALTER TABLE dbo.T_Mass_Tag_Peptide_Prophet_Stats DROP CONSTRAINT FK_T_Mass_Tag_Peptide_Prophet_Stats_T_Mass_Tags
	ALTER TABLE dbo.T_Peptides DROP CONSTRAINT FK_T_Peptides_T_Mass_Tags
	ALTER TABLE dbo.T_Quantitation_ResultDetails DROP CONSTRAINT FK_T_Quantitation_ResultDetails_T_Mass_Tags

	DELETE FROM T_Mass_Tags
	WHERE (PMT_Quality_Score = -100)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @PMTsDeletedCount = @myRowCount


	-- Restore the foreign keys to T_Mass_Tags
	ALTER TABLE dbo.T_FTICR_UMC_ResultDetails
		ADD CONSTRAINT FK_T_FTICR_UMC_ResultDetails_T_Mass_Tags foreign key(Mass_Tag_ID) references dbo.T_Mass_Tags(Mass_Tag_ID)
	ALTER TABLE dbo.T_Mass_Tag_to_Protein_Map
		ADD CONSTRAINT FK_T_Mass_Tag_to_Protein_Map_T_Mass_Tags foreign key(Mass_Tag_ID) references dbo.T_Mass_Tags(Mass_Tag_ID)
	ALTER TABLE dbo.T_Mass_Tags_NET
		ADD CONSTRAINT FK_T_Mass_Tags_NET_T_Mass_Tags foreign key(Mass_Tag_ID) references dbo.T_Mass_Tags(Mass_Tag_ID)
	ALTER TABLE dbo.T_Mass_Tag_Peptide_Prophet_Stats
		ADD CONSTRAINT FK_T_Mass_Tag_Peptide_Prophet_Stats_T_Mass_Tags foreign key(Mass_Tag_ID) references dbo.T_Mass_Tags(Mass_Tag_ID)
	ALTER TABLE dbo.T_Peptides
		ADD CONSTRAINT FK_T_Peptides_T_Mass_Tags foreign key(Mass_Tag_ID) references dbo.T_Mass_Tags(Mass_Tag_ID)
	ALTER TABLE dbo.T_Quantitation_ResultDetails
		ADD CONSTRAINT FK_T_Quantitation_ResultDetails_T_Mass_Tags foreign key(Mass_Tag_ID) references dbo.T_Mass_Tags(Mass_Tag_ID)


	--At this point, it's a good idea to check that the constraints are still valid
	DBCC CHECKCONSTRAINTS (T_Mass_Tags)



done:

	If Len(IsNull(@message, '')) = 0
	Begin
		If @PeptidesProcessedCount > 0 and @PMTsUpdatedCount <> @PeptidesProcessedCount
			Set @message = 'Warning, only updated ' + Convert(varchar(11), @PMTsUpdatedCount) + ' PMTs, though we processed ' + convert(varchar(9), @PeptidesProcessedCount) + ' PMTs'
		Else
			Set @message = 'Updated ' + Convert(varchar(11), @PMTsUpdatedCount) + ' PMTs'

		Set @message = @message + '; Changed the Mass_tag_ID value for ' + convert(varchar(9), @MTIDCountUpdated) + ' PMTs; Deleted ' + convert(varchar(9), @PMTsDeletedCount) + ' PMTs'
	End

	Select @message As Message

	RETURN @myError


GO
GRANT VIEW DEFINITION ON [dbo].[RemoveModificationAndConsolidateMTs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RemoveModificationAndConsolidateMTs] TO [MTS_DB_Lite] AS [dbo]
GO

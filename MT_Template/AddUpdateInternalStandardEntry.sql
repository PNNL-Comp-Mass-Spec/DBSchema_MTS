/****** Object:  StoredProcedure [dbo].[AddUpdateInternalStandardEntry] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddUpdateInternalStandardEntry
/****************************************************
**
**	Desc:
**		Looks for @SeqID in T_Mass_Tags
**
**		If not present, then adds as a new entry, obtaining the
**		 mass and peptide sequence from MT_Main..T_Internal_Std_Components
**		 and setting Internal_Standard_Only to 1.  Also adds a mapping to
**		 T_Proteins and T_Mass_Tag_to_Protein_Map using the
**		 information in MT_Main..T_Internal_Std_Proteins and 
**		 MT_Main..T_Internal_Std_to_Protein_Map.
**
**		If already present, then will update the mass and
**		 Peptide Sequence if Internal_Standard_Only = 1.  
**		 In addition, will update the mapping to T_Proteins, adding
**		 any missing entries.
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	12/15/2005
**			07/25/2006 mem - Updated field names in T_Proteins
**      
*****************************************************/
(
	@SeqID int,								-- Seq_ID of the Internal Standard to add or update
	@PostLogEntry tinyint = 1,				-- If non-zero, then post an entry to T_Log_Entries if any changes are made
	@message varchar(256) = '' OUTPUT
)
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	
	Declare @LogMessage varchar(255)
	Set @LogMessage = ''
	
	Declare @PeptideSequence varchar(850)
	Declare @MonoisotopicMass float
	Declare @InternalStandardOnly tinyint
	Declare @UpdateTable tinyint
	
	Declare @SeqIdStr varchar(19)
	Set @SeqIdStr = Convert(varchar(19), @SeqID)
	
	Declare @myTrans varchar(32)
	Set @myTrans = 'AddUpdateInternalStandardEntry'
	
	Begin Transaction @myTrans
	
	---------------------------------------------------
	-- Validate that @SeqID is present in MT_Main..T_Internal_Std_Components
	---------------------------------------------------
	--	
	SELECT	@PeptideSequence = Peptide, 
			@MonoisotopicMass = Monoisotopic_Mass
	FROM MT_Main..T_Internal_Std_Components
	WHERE Seq_ID = @SeqID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount < 1
	Begin
		Set @message = 'Seq_ID ' + @SeqIdStr + ' is not present in MT_Main..T_Internal_Std_Components; unable to continue'
		Set @myError = 51000
		Rollback Transaction @myTrans
		Goto Done
	End

	---------------------------------------------------
	-- See if @SeqID is present in T_Mass_Tags
	-- Do this by looking up the value for Internal_Standard_Only
	---------------------------------------------------

	SELECT @InternalStandardOnly = IsNull(Internal_Standard_Only, 0)
	FROM T_Mass_Tags
	WHERE Mass_Tag_ID = @SeqID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	 Begin
		---------------------------------------------------
		-- Entry not present; add it to T_Mass_Tags
		---------------------------------------------------
		--
		Set @InternalStandardOnly = 1
		--
		INSERT INTO T_Mass_Tags (	Mass_Tag_ID, Peptide, Monoisotopic_Mass, 
									Multiple_Proteins, Created, Last_Affected, 
									Number_Of_Peptides, High_Normalized_Score, 
									High_Discriminant_Score, Mod_Count, 
									Mod_Description, PMT_Quality_Score, Internal_Standard_Only)
		VALUES (@SeqID, @PeptideSequence, @MonoisotopicMass, 
				0,	-- Multiple_Proteins
				GetDate(),	-- Created
				GetDate(),	-- Last_Affected
				0,	-- Number_of_Peptides
				0,  -- High_Normalized_Score
				0,  -- High_Discriminant
				0,	-- Mod_Count
				'', -- Mod_Description
				0,	-- PMT_Quality_Score
				@InternalStandardOnly
				)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
		Begin
			Set @message = 'Error adding Seq_ID ' + @SeqIdStr + ' to T_Mass_Tags'
			Rollback Transaction @myTrans
			Goto Done
		End

		Set @LogMessage = 'Added internal standard Seq_ID ' + Convert(varchar(19), @SeqID) + ' to T_Mass_Tags'
	 End
	Else
	 Begin
		If @InternalStandardOnly = 1
		Begin
			---------------------------------------------------
			-- Entry is present and is flagged as only being an internal standard
			-- Update the mass and the peptide sequence
			---------------------------------------------------
			--
			UPDATE T_Mass_Tags
			SET Peptide = @PeptideSequence,
				Monoisotopic_Mass = @MonoisotopicMass
			WHERE Mass_Tag_ID = @SeqID AND (
				  Peptide <> @PeptideSequence OR
				  Monoisotopic_Mass <> @MonoisotopicMass)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myError <> 0
			Begin
				Set @message = 'Error updating peptide sequence and mass for Seq_ID ' + @SeqIdStr + ' in T_Mass_Tags'
				Rollback Transaction @myTrans
				Goto Done
			End

			If @myRowCount > 0
				Set @LogMessage = 'Updated peptide sequence and/or mass for internal standard Seq_ID ' + Convert(varchar(19), @SeqID) + ' in T_Mass_Tags'
		End
	 End
	
	---------------------------------------------------
	-- Make sure the protein(s) for @SeqID is/are present in T_Proteins
	---------------------------------------------------
	--
	INSERT INTO T_Proteins (Reference, External_Reference_ID, Protein_Sequence, 
							Monoisotopic_Mass, Protein_DB_ID)
	SELECT	ISP.Protein_Name, ISP.Protein_ID, ISP.Protein_Sequence, 
			ISP.Monoisotopic_Mass, ISP.Protein_DB_ID
	FROM MT_Main.dbo.T_Internal_Std_to_Protein_Map ISPM INNER JOIN
		 MT_Main.dbo.T_Internal_Std_Proteins ISP ON 
		 ISPM.Internal_Std_Protein_ID = ISP.Internal_Std_Protein_ID LEFT OUTER JOIN
		 T_Proteins Prot ON ISP.Protein_Name = Prot.Reference
	WHERE ISPM.Seq_ID = @SeqID AND 
		  Prot.Reference IS NULL
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
		
	If @myError <> 0
	Begin
		Set @message = 'Error updating T_Proteins for Seq_ID ' + @SeqIDStr
		Rollback Transaction @myTrans
		Goto Done
	End

	---------------------------------------------------
	-- Make sure the peptide to protein mapping for @SeqID is present in T_Mass_Tag_to_Protein_Map
	---------------------------------------------------
	--
	INSERT INTO T_Mass_Tag_to_Protein_Map (	Mass_Tag_ID, Mass_Tag_Name, Ref_ID, Cleavage_State, 
											Fragment_Number, Fragment_Span, Residue_Start, 
											Residue_End, Repeat_Count, Terminus_State)
	SELECT	ISPM.Seq_ID, ISPM.Mass_Tag_Name, Prot.Ref_ID, ISPM.Cleavage_State, 
			ISPM.Fragment_Number, ISPM.Fragment_Span, ISPM.Residue_Start, 
			ISPM.Residue_End, ISPM.Repeat_Count, ISPM.Terminus_State
	FROM MT_Main.dbo.T_Internal_Std_to_Protein_Map ISPM INNER JOIN
		 MT_Main.dbo.T_Internal_Std_Proteins ISProt ON ISPM.Internal_Std_Protein_ID = ISProt.Internal_Std_Protein_ID INNER JOIN
		 T_Proteins Prot ON ISProt.Protein_Name = Prot.Reference LEFT OUTER JOIN
		 T_Mass_Tag_to_Protein_Map MTPM ON Prot.Ref_ID = MTPM.Ref_ID AND ISPM.Seq_ID = MTPM.Mass_Tag_ID
	WHERE ISPM.Seq_ID = @SeqID AND MTPM.Mass_Tag_ID IS NULL
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
		
	If @myError <> 0
	Begin
		Set @message = 'Error updating T_Mass_Tag_to_Protein_Map for Seq_ID ' + @SeqIDStr
		Rollback Transaction @myTrans
		Goto Done
	End

	---------------------------------------------------
	-- Update the Mass_Tag_Name, Cleavage_State, etc. in T_Mass_Tag_to_Protein_Map if @InternalStandardOnly = 1
	-- or if Cleavage_State is Null
	---------------------------------------------------
	--
	Set @UpdateTable = 1
	If @InternalStandardOnly = 0
	Begin
		SELECT @UpdateTable = COUNT(*)
		FROM MT_Main.dbo.T_Internal_Std_to_Protein_Map ISPM INNER JOIN
			 MT_Main.dbo.T_Internal_Std_Proteins ISProt ON ISPM.Internal_Std_Protein_ID = ISProt.Internal_Std_Protein_ID INNER JOIN
			 T_Proteins Prot ON ISProt.Protein_Name = Prot.Reference INNER JOIN
			 T_Mass_Tag_to_Protein_Map MTPM ON Prot.Ref_ID = MTPM.Ref_ID AND ISPM.Seq_ID = MTPM.Mass_Tag_ID
		WHERE ISPM.Seq_ID = @SeqID AND 
			  MTPM.Cleavage_State IS NULL
	End
			
	If @UpdateTable = 1
	Begin
		UPDATE T_Mass_Tag_to_Protein_Map
		SET Mass_Tag_Name = ISPM.Mass_Tag_Name,
			Cleavage_State = ISPM.Cleavage_State, 
			Fragment_Number = ISPM.Fragment_Number, 
			Fragment_Span = ISPM.Fragment_Span, 
			Residue_Start = ISPM.Residue_Start, 
			Residue_End = ISPM.Residue_End, 
			Repeat_Count = ISPM.Repeat_Count, 
			Terminus_State = ISPM.Terminus_State
		FROM MT_Main.dbo.T_Internal_Std_to_Protein_Map ISPM INNER JOIN
			 MT_Main.dbo.T_Internal_Std_Proteins ISProt ON ISPM.Internal_Std_Protein_ID = ISProt.Internal_Std_Protein_ID INNER JOIN
			 T_Proteins Prot ON ISProt.Protein_Name = Prot.Reference INNER JOIN
			 T_Mass_Tag_to_Protein_Map MTPM ON Prot.Ref_ID = MTPM.Ref_ID AND ISPM.Seq_ID = MTPM.Mass_Tag_ID
		WHERE ISPM.Seq_ID = @SeqID AND NOT ISPM.Mass_Tag_Name IS NULL AND (
				IsNull(MTPM.Mass_Tag_Name,'') <> ISPM.Mass_Tag_Name OR
				IsNull(MTPM.Cleavage_State,0) <> ISPM.Cleavage_State OR
				IsNull(MTPM.Fragment_Number,0) <> ISPM.Fragment_Number OR
				IsNull(MTPM.Fragment_Span,0) <> ISPM.Fragment_Span OR
				IsNull(MTPM.Residue_Start,0) <> ISPM.Residue_Start OR
				IsNull(MTPM.Residue_End,0) <> ISPM.Residue_End OR
				IsNull(MTPM.Repeat_Count,0) <> ISPM.Repeat_Count OR
				IsNull(MTPM.Terminus_State,0) <> ISPM.Terminus_State		
			)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
			
		If @myError <> 0
		Begin
			Set @message = 'Error updating T_Mass_Tag_to_Protein_Map.Mass_Tag_Name for Seq_ID ' + @SeqIDStr
			Rollback Transaction @myTrans
			Goto Done
		End

		If @myRowCount > 0 And Len(@LogMessage) = 0
			Set @LogMessage = 'Updated stats in Mass_Tag_to_Protein_Map for internal standard Seq_ID ' + Convert(varchar(19), @SeqID)

	End
		
	-- Finalize the changes
	Commit Transaction @myTrans

	If @PostLogEntry <> 0 And Len(@LogMessage) > 0 
		Execute PostLogEntry 'Normal', @LogMessage, 'AddUpdateInternalStandardEntry'

Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[AddUpdateInternalStandardEntry] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[AddUpdateInternalStandardEntry] TO [MTS_DB_Lite]
GO

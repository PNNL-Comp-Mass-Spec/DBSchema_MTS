SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AddUpdateGANETLockerEntry]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AddUpdateGANETLockerEntry]
GO


CREATE Procedure dbo.AddUpdateGANETLockerEntry
/****************************************************
**
**	Desc: Adds a new entry to the T_GANET_Lockers table,
**		  optionally also assuring the protein is present in T_Proteins
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**		Auth:	mem
**		Date:	05/20/2005
**				06/15/2005 mem - Added parameter @PNET
**      
*****************************************************/
	@SeqID int,								-- Required
	@Description varchar(128) = NULL,
	@PeptideSequence varchar(850) = NULL,
	@MonoisotopicMass float ,				-- Required
	@ChargeMinimum int = 1 ,				-- Required
	@ChargeMaximum int = 3,					-- Required
	@ChargeHighestAbu int = 2,				-- Required
	@MinGANET real = NULL,
	@MaxGANET real = NULL,
	@AvgGANET real,							-- Required
	@CntGANET int = NULL,
	@StDGANET real = NULL,
	@PNET real = NULL,
	@ProteinName varchar(128) = NULL,
	@ProteinID int = NULL,
	@ProteinSequence text = NULL,
	@ProteinMass float = NULL,
	@ProteinDBID int = NULL,
	@GANETLockerState tinyint = Null,		-- Set to Null to leave existing entries unchanged, 1 = Valid Locker; 2 = Unused Locker
	@message varchar(256) = '' OUTPUT
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	
	declare @RefID int
	declare @MatchCount int
	
	declare @myTrans varchar(32)
	set @myTrans = 'AddGANETLockerEntry'
	
	Begin Transaction @myTrans
	
	If Len(IsNull(@ProteinName, '')) > 0
	Begin
		-- Make sure the protein is present in T_Proteins
		Set @RefID = 0
		
		SELECT @RefID = Ref_ID
		FROM T_Proteins 
		WHERE Reference = @ProteinName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myError <> 0
		Begin
			Set @message = 'Error looking up ' + @ProteinName + ' in T_Proteins'
			Rollback Transaction @myTrans
			Goto Done
		End
		
		If @myRowCount = 0
		Begin
			INSERT INTO T_Proteins (Reference, Protein_ID, Protein_Sequence, Monoisotopic_Mass, Protein_DB_ID)
			VALUES (@ProteinName, @ProteinID, @ProteinSequence, @ProteinMass, @ProteinDBID)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount, @RefID = SCOPE_IDENTITY()

			If @myRowCount = 0 Or @myError <> 0
			Begin
				Set @message = 'Error adding ' + @ProteinName + ' to T_Proteins'
				Rollback Transaction @myTrans
				Goto Done
			End

		End
	End
	Else
		Set @RefID = Null


	-- Make sure the peptide is present in T_Mass_Tags
	Set @matchCount = 0
	SELECT @matchCount = Count(Mass_Tag_ID)
	FROM T_Mass_Tags
	WHERE Mass_Tag_ID = @SeqID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myError <> 0
	Begin
		Set @message = 'Error looking up ' + Convert(varchar(12), @SeqID) + ' in T_Mass_Tags'
		Rollback Transaction @myTrans
		Goto Done
	End
	
	If @matchCount = 0
	Begin
		INSERT INTO T_Mass_Tags (	Mass_Tag_ID, Peptide, Monoisotopic_Mass, 
									Multiple_Proteins, Created, Last_Affected, 
									Number_Of_Peptides, High_Normalized_Score, 
									High_Discriminant_Score, Mod_Count, 
									Mod_Description, PMT_Quality_Score, Internal_Standard_Only)
		VALUES (@SeqID, @PeptideSequence, @MonoisotopicMass, 
				0,	-- Multiple_Proteins
				 GetDate(), GetDate(),
				0,	-- Number_of_Peptides
				0,  -- High_Discriminant
				0,  -- High_Normalized
				0,	-- Mod_Count
				'', -- Mod_Description
				0,	-- PMT_Quality_Score
				1	-- Internal_Standard_Only
				)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0 Or @myError <> 0
		Begin
			Set @message = 'Error adding ' + Convert(varchar(12), @SeqID) + ' to T_Mass_Tags'
			Rollback Transaction @myTrans
			Goto Done
		End
	End

	
	-- Make sure the peptide to protein mapping is present in T_Mass_Tag_to_Protein_Map
	If Not @RefID Is Null
	Begin
		SELECT @matchCount = Count(Mass_Tag_ID)
		FROM T_Mass_Tag_to_Protein_Map	
		WHERE Mass_Tag_ID = @SeqID AND Ref_ID = @RefID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myError <> 0
		Begin
			Set @message = 'Error looking up ' + Convert(varchar(12), @SeqID) + ' in T_Mass_Tag_to_Protein_Map'
			Rollback Transaction @myTrans
			Goto Done
		End		

		If @matchCount = 0
		Begin
			INSERT INTO T_Mass_Tag_to_Protein_Map (	Mass_Tag_ID, Ref_ID)
			VALUES (@SeqID, @RefID)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount = 0 Or @myError <> 0
			Begin
				Set @message = 'Error adding ' + Convert(varchar(12), @SeqID) + ' to T_Mass_Tag_to_Protein_Map'
				Rollback Transaction @myTrans
				Goto Done
			End
		End
	End
	
	-- See if the entry is already present in T_GANET_Lockers
	Set @matchCount = 0
	SELECT @MatchCount = Count(Seq_ID)
	FROM T_GANET_Lockers
	WHERE Seq_ID = @SeqID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @MatchCount = 1
	Begin
		-- Update the entry in T_GANET_Lockers
		UPDATE T_GANET_Lockers
			SET	Description = @Description, 
				Charge_Minimum = @ChargeMinimum, 
				Charge_Maximum = @ChargeMaximum, 
				Charge_Highest_Abu = @ChargeHighestAbu, 
				Min_GANET = @MinGANET, 
				Max_GANET = @MaxGANET, 
				Avg_GANET = @AvgGANET, 
				Cnt_GANET = @CntGANET, 
				StD_GANET = @StDGANET, 
				PNET = @PNET,
				GANET_Locker_State = IsNull(IsNull(@GANETLockerState, GANET_Locker_State), 1)
		WHERE Seq_ID = @SeqID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
	End
	Else
	Begin
		-- Add the entry to T_GANET_Lockers
		INSERT INTO T_GANET_Lockers (
			Seq_ID, Description,
			Charge_Minimum, Charge_Maximum, Charge_Highest_Abu, 
			Min_GANET, Max_GANET, Avg_GANET, Cnt_GANET, 
			StD_GANET, PNET, GANET_Locker_State)
		VALUES (@SeqID, @Description, 
				@ChargeMinimum, @ChargeMaximum, @ChargeHighestAbu, 
				@MinGANET, @MaxGANET, @AvgGANET, @CntGANET, 
				@StDGANET, @PNET, IsNull(@GANETLockerState,1))
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
				
	End

	If @myError <> 0
	Begin
		Set @message = 'Error updating T_GANET_Lockers'
		Rollback Transaction @myTrans
	End
	Else	
		Commit Transaction @myTrans

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


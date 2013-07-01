/****** Object:  StoredProcedure [dbo].[RemoveDecoyProteins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.RemoveDecoyProteins
/****************************************************
**
**	Desc: Deletes decoy (reverse sequence) entries from T_Proteins
**
**		  When deleting, makes sure that the affected Mass_Tag_IDs
**		  will have at least one protein remaining after all of the
**		  reversed proteins are deleted
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	03/18/2010
**			03/19/2010 mem - Now posting to the log if proteins are deleted
**			01/17/2012 mem - Added 'xxx.%' and 'rev[_]%' as potential prefixes for reversed proteins
**			06/20/2013 mem - Added 'xxx[_]%' as an additional prefix for reversed proteins
**    
*****************************************************/
(
	@InfoOnly tinyint = 0,			-- Set to 1 to preview the proteins that would be deleted
	@message varchar(255) = '' output
)
AS
	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @TranDeleteProteins varchar(32)

	Set @message = ''
	Set @InfoOnly = IsNull(@InfoOnly, 0)

	
	---------------------------------------------------
	-- Create a temporary table to hold the proteins to delete
	---------------------------------------------------

	CREATE TABLE #Tmp_ProteinList (
		[Ref_ID] int NOT NULL
	)

	CREATE INDEX #IX_Tmp_ProteinList_RefID ON #Tmp_ProteinList (Ref_ID);
	
	---------------------------------------------------
	-- Find the AMTs that have decoy proteins, yet also have at least one non-decoy protein
	-- Populate #Tmp_ProteinList using the decoy proteins mapped to these AMTs
	-- Exclude any proteins that have peptides that only map to that protein
	---------------------------------------------------
	WITH ProtStats ( Mass_Tag_ID, ProteinCount, DecoyProteinCount )
	AS
	( SELECT MTPMA.Mass_Tag_ID,
	         COUNT(*) AS ProteinCount,
	         SUM(CASE
	                 WHEN Prot.Reference LIKE 'reversed[_]%' OR		-- MTS reversed proteins
	                      Prot.Reference LIKE 'scrambled[_]%' OR	-- MTS scrambled proteins
	                      Prot.Reference LIKE '%[:]reversed' OR		-- X!Tandem decoy proteins
	                      Prot.Reference LIKE 'xxx.%' OR			-- Inspect reversed/scrambled proteins
	                      Prot.Reference LIKE 'rev[_]%' OR			-- MSGFDB reversed proteins
	                      Prot.Reference LIKE 'xxx[_]%' THEN 1		-- MSGF+ reversed proteins
	                 ELSE 0
	             END) AS DecoyProteinCount
	  FROM T_Proteins Prot
	       INNER JOIN T_Mass_Tag_to_Protein_Map MTPMA
	         ON Prot.Ref_ID = MTPMA.Ref_ID
	  GROUP BY MTPMA.Mass_Tag_ID )
	INSERT INTO #Tmp_ProteinList( Ref_ID )
	SELECT DISTINCT MTPM.Ref_ID
	FROM T_Mass_Tag_to_Protein_Map MTPM
	     INNER JOIN T_Proteins Prot
	       ON MTPM.Ref_ID = Prot.Ref_ID
	     INNER JOIN ( SELECT Mass_Tag_ID
	                  FROM ProtStats
	                  WHERE (DecoyProteinCount > 0) AND
	                        (ProteinCount > DecoyProteinCount) ) MTIDList
	       ON MTPM.Mass_Tag_ID = MTIDList.Mass_Tag_ID
	WHERE Prot.Reference LIKE 'reversed[_]%' OR
	      Prot.Reference LIKE 'scrambled[_]%' OR
	      Prot.Reference LIKE '%[:]reversed' OR
	      Prot.Reference LIKE 'xxx.%' OR
	      Prot.Reference LIKE 'rev[_]%' OR
	      Prot.Reference LIKE 'xxx[_]%' AND
	      NOT Prot.Ref_ID IN ( SELECT Ref_ID
	                           FROM T_Mass_Tag_to_Protein_Map
	                           WHERE Mass_Tag_ID IN ( SELECT Mass_Tag_ID
	                                                  FROM ProtStats
	                                                  WHERE (DecoyProteinCount > 0) AND
	                                                        (ProteinCount = DecoyProteinCount) ) )
	;
	--
	SELECT @myError = @@Error, @myRowCount = @@RowCount
	
	If @InfoOnly <> 0
	Begin
		---------------------------------------------------
		-- Preview the proteins that would be deleted
		---------------------------------------------------
		
		SELECT MTPM.Ref_ID,
		   Prot.Reference,
		       COUNT(*) AS MT_Count
		FROM T_Mass_Tag_to_Protein_Map MTPM
		     INNER JOIN T_Proteins Prot
		       ON MTPM.Ref_ID = Prot.Ref_ID
		     INNER JOIN #Tmp_ProteinList
		       ON Prot.Ref_ID = #Tmp_ProteinList.Ref_ID
		GROUP BY MTPM.Ref_ID, Prot.Reference
		ORDER BY Prot.Reference
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount

	End
	Else
	Begin
		---------------------------------------------------
		-- Delete the proteins from the various table
		---------------------------------------------------
		
		
		Set @TranDeleteProteins = 'DeleteProteins'
		
		Begin Tran @TranDeleteProteins

		-- Delete entries in T_Mass_Tag_to_Protein_Map
		--
		DELETE T_Mass_Tag_to_Protein_Map
		FROM T_Mass_Tag_to_Protein_Map Target
		     INNER JOIN #Tmp_ProteinList Prot
		       ON Target.Ref_ID = Prot.Ref_ID
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount
			
		If @myError <> 0
		Begin
			Rollback Tran @TranDeleteProteins
			Set @message = 'Error deleting data from T_Mass_Tag_to_Protein_Map'			
			Goto Done
		End
		
		-- Delete entries in T_Protein_Coverage
		--
		DELETE T_Protein_Coverage
		FROM T_Protein_Coverage Target
		     INNER JOIN #Tmp_ProteinList Prot
		       ON Target.Ref_ID = Prot.Ref_ID
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount
			
		If @myError <> 0
		Begin
			Rollback Tran @TranDeleteProteins
			Set @message = 'Error deleting data from T_Protein_Coverage'			
			Goto Done
		End
		
		
		-- Delete entries in T_Protein_Residue_Mods
		--
		DELETE T_Protein_Residue_Mods
		FROM T_Protein_Residue_Mods Target
		     INNER JOIN #Tmp_ProteinList Prot
		   ON Target.Ref_ID = Prot.Ref_ID
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount
			
		If @myError <> 0
		Begin
			Rollback Tran @TranDeleteProteins
			Set @message = 'Error deleting data from T_Protein_Residue_Mods'			
			Goto Done
		End
		
		
		-- Delete entries in T_Quantitation_Results
		--
		DELETE T_Quantitation_Results
		FROM T_Quantitation_Results Target
		     INNER JOIN #Tmp_ProteinList Prot
		       ON Target.Ref_ID = Prot.Ref_ID
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount
			
		If @myError <> 0
		Begin
			Rollback Tran @TranDeleteProteins
			Set @message = 'Error deleting data from T_Quantitation_Results'			
			Goto Done
		End
		
		
		-- Delete entries in T_Proteins
		--
		DELETE T_Proteins
		FROM T_Proteins Target
		     INNER JOIN #Tmp_ProteinList Prot
		       ON Target.Ref_ID = Prot.Ref_ID
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount
			
		If @myError <> 0
		Begin
			Rollback Tran @TranDeleteProteins
			Set @message = 'Error deleting data from T_Proteins'			
			Goto Done
		End
	
		Commit Tran @TranDeleteProteins
		
		Set @message = 'Deleted ' + Convert(varchar(12), @myRowCount) + ' decoy (reverse) proteins from T_Proteins and its dependent tables'
		
		If @myRowCount > 0
			exec PostLogEntry 'Normal', @message, 'RemoveDecoyProteins'

	End
	
Done:
	If @InfoOnly <> 0 And IsNull(@message, '') <> ''
		Select @message As Message
	
	RETURN @myError


GO

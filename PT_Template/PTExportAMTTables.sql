/****** Object:  StoredProcedure [dbo].[PTExportAMTTables] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure PTExportAMTTables
/****************************************************	
**  Desc:	
**		Exports the details for the AMT tags defined in #TmpPeptideStats_Results
**		Also optionally exports the protein information and MT to Protein mapping info
**
**		The calling procedure must create table #TmpPeptideStats_Results
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	10/30/2009 mem - Initial Version (modelled after PMExportAMTTables in MT DBs)
**			11/11/2009 mem - Switched to using #TmpPeptideStats_Results to determine the peptides and proteins to export
**						   - Added parameter @ReturnPeptideToProteinMapTable

****************************************************/
(
	@ReturnMTTable tinyint = 1,						-- When 1, then returns a table of Mass Tag IDs and various information
	@ReturnProteinTable tinyint = 1,				-- When 1, then also returns a table of Proteins that the Mass Tag IDs map to
	@ReturnProteinMapTable tinyint = 1,				-- When 1, then also returns the mapping information of Mass_Tag_ID to Protein
	@ReturnPeptideToProteinMapTable tinyint = 1,	-- When 1, then also returns a table mapping each individual peptide observation to a protein (necessary to see peptides that map to reversed proteins and don't have Seq_ID values)
	@message varchar(512)='' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	declare @ProteinCollectionList varchar(255)
	declare @EntryID int
	declare @Continue int

	Declare @ProteinCollectionID int
	
	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	

		Set @ReturnMTTable = IsNull(@ReturnMTTable, 1)
		Set @ReturnProteinTable = IsNull(@ReturnProteinTable, 1)
		Set @ReturnProteinMapTable = IsNull(@ReturnProteinMapTable, 1)
		Set @ReturnPeptideToProteinMapTable = IsNull(@ReturnPeptideToProteinMapTable, 1)

		Set @message = ''
	
		-------------------------------------------------	
		-- Return the data
		-------------------------------------------------	

		If @ReturnMTTable <> 0
		Begin
			SELECT Seq.Seq_ID AS Mass_Tag_ID,
			       Seq.Clean_Sequence AS Peptide,
			       Seq.Monoisotopic_Mass,
			       Seq.Mod_Count,
			       Seq.Mod_Description,
			       Seq.Cleavage_State_Max
			       --, Seq.PeptideEx
			FROM T_Sequence Seq
			     INNER JOIN #TmpPeptideStats_Results F
			       ON Seq.Seq_ID = F.Mass_Tag_ID
			GROUP BY Seq.Seq_ID, Seq.Clean_Sequence, Seq.Monoisotopic_Mass, 
			         Seq.Mod_Count, Seq.Mod_Description, Seq.Cleavage_State_Max
			ORDER BY Seq.Seq_ID

			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		End


		If @ReturnProteinTable <> 0
		Begin

			SELECT  Prot.Reference AS Protein,
				    Prot.Ref_ID,
				    Prot.Description,
				    Prot.Protein_Residue_Count,
				    Prot.Monoisotopic_Mass,
				    Prot.External_Reference_ID,
				    Prot.External_Protein_ID,
				    Prot.Protein_Collection_ID,
				    CASE
				        WHEN Prot.Reference LIKE 'reversed[_]%' OR
				            Prot.Reference LIKE 'scrambled[_]%' OR
				            Prot.Reference LIKE '%[:]reversed' THEN 1
				        ELSE 0
				    END AS Decoy_Protein
			FROM T_Proteins Prot
				    INNER JOIN ( SELECT Prot.Ref_ID
				                FROM #TmpPeptideStats_Results PSR
				                    INNER JOIN T_Peptide_to_Protein_Map PPM
				                        ON PPM.Peptide_ID = PSR.Peptide_ID
				                    INNER JOIN T_Proteins Prot
				                        ON PPM.Ref_ID = Prot.Ref_ID
				                GROUP BY Prot.Ref_ID 
				            ) ProteinIDQ
				    ON Prot.Ref_ID = ProteinIDQ.Ref_ID
			ORDER BY Prot.Reference
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
			
		End

		If @ReturnProteinMapTable <> 0
		Begin
			SELECT DISTINCT PSR.Mass_Tag_ID AS Mass_Tag_ID,
				            Prot.Reference AS Protein,
				            PPM.Ref_ID,
				            PSR.Peptide AS Peptide_Sequence,
				            PPM.Cleavage_State,
				            PPM.Terminus_State,
				            CASE
				                WHEN Prot.Reference LIKE 'reversed[_]%' OR
				                     Prot.Reference LIKE 'scrambled[_]%' OR
				                     Prot.Reference LIKE '%[:]reversed' THEN 1
				                ELSE 0
				            END AS Decoy_Protein
			FROM #TmpPeptideStats_Results PSR
				    INNER JOIN T_Peptide_to_Protein_Map PPM
				    ON PSR.Peptide_ID = PPM.Peptide_ID
				    INNER JOIN T_Proteins Prot
				    ON PPM.Ref_ID = Prot.Ref_ID
			ORDER BY PSR.Mass_Tag_ID, Prot.Reference
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

		End

		If @ReturnPeptideToProteinMapTable <> 0
		Begin
		
			SELECT PSR.Peptide_ID,
			       Prot.Reference AS Protein,
			       PPM.Ref_ID,
			       PPM.Cleavage_State,
			       PPM.Terminus_State,
			       CASE
			           WHEN Prot.Reference LIKE 'reversed[_]%' OR
			                Prot.Reference LIKE 'scrambled[_]%' OR
			                Prot.Reference LIKE '%[:]reversed' THEN 1
			           ELSE 0
			       END AS Decoy_Protein
			FROM #TmpPeptideStats_Results PSR
			     INNER JOIN T_Peptide_to_Protein_Map PPM
			       ON PSR.Peptide_ID = PPM.Peptide_ID
			     INNER JOIN T_Proteins Prot
			       ON PPM.Ref_ID = Prot.Ref_ID
			ORDER BY PSR.Peptide_ID, Prot.Reference
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

		End
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PTExportAMTTables')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto DoneSkipLog
	End Catch
				
Done:
	-----------------------------------------------------------
	-- Done processing
	-----------------------------------------------------------
		
	If @myError <> 0 
	Begin
		Execute PostLogEntry 'Error', @message, 'PTExportAMTTables'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO

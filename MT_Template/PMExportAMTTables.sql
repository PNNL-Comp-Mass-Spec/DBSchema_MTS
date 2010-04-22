/****** Object:  StoredProcedure [dbo].[PMExportAMTTables] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure PMExportAMTTables
/****************************************************	
**  Desc:	
**		Exports the details for the AMT tags defined in #Tmp_MTs_ToExport
**		Also optionally exports the protein information and MT to Protein mapping info
**
**		The calling procedure must create #Tmp_MTs_ToExport
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	10/30/2009 mem - Initial Version
**
****************************************************/
(
	@ReturnMTTable tinyint = 1,						-- When 1, then returns a table of Mass Tag IDs and various infor
	@ReturnProteinTable tinyint = 1,				-- When 1, then also returns a table of Proteins that the Mass Tag IDs map to
	@ReturnProteinMapTable tinyint = 1,				-- When 1, then also returns the mapping information of Mass_Tag_ID to Protein
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

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	

		Set @ReturnMTTable = IsNull(@ReturnMTTable, 1)
		Set @ReturnProteinTable = IsNull(@ReturnProteinTable, 1)
		Set @ReturnProteinMapTable = IsNull(@ReturnProteinMapTable, 1)

		Set @message = ''

		-------------------------------------------------	
		-- Return the data
		-------------------------------------------------	

		If @ReturnMTTable <> 0
		Begin
			SELECT MT.Mass_Tag_ID,
				    MT.Peptide,
				    MT.Monoisotopic_Mass,
				    ISNULL(MT.Multiple_Proteins, 0) + 1 AS Protein_Count,
				    MT.Number_Of_Peptides AS Peptide_Obs_Count,
				    MT.Peptide_Obs_Count_Passing_Filter,
				    MT.High_Normalized_Score,
				    MT.High_Discriminant_Score,
				    MT.High_Peptide_Prophet_Probability,
				    MT.Min_Log_EValue,
				    MT.Mod_Count,
				    MT.Mod_Description,
				    ISNULL(MT.PMT_Quality_Score, 0) AS PMT_Quality_Score,
				    MT.Internal_Standard_Only,
				    MT.Cleavage_State_Max,
				    MT.PeptideEx,
				    MTN.Avg_GANET AS NET_Avg,
				    MTN.Min_GANET AS NET_Min,
				    MTN.Max_GANET AS NET_Max,
				    MTN.Cnt_GANET AS NET_Count,
				    MTN.StD_GANET AS NET_StDev,
				    MTN.StdError_GANET AS NET_StdError,
				    MTN.PNET
			FROM T_Mass_Tags MT
				    INNER JOIN T_Mass_Tags_NET MTN
				    ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID
				    INNER JOIN #Tmp_MTs_ToExport F
				    ON MT.Mass_Tag_ID = F.Mass_Tag_ID
			ORDER BY MT.Mass_Tag_ID
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		End
		
		If @ReturnProteinTable <> 0
		Begin
			SELECT 	Prot.Reference AS Protein,
					Prot.Ref_ID,
					Prot.Description,
					Prot.Protein_Residue_Count,
					Prot.Monoisotopic_Mass,
					Prot.Protein_DB_ID,
					Prot.External_Reference_ID,
					Prot.External_Protein_ID,
					Prot.Protein_Collection_ID,
					CASE
						WHEN Prot.Reference LIKE 'reversed[_]%' OR
							Prot.Reference LIKE 'scrambled[_]%' OR
							Prot.Reference LIKE '%[:]reversed' THEN 1
						ELSE 0
					END AS Decoy_Protein,
					Prot.Protein_Sequence
			FROM T_Proteins Prot
					INNER JOIN ( SELECT Prot.Ref_ID
								FROM T_Mass_Tags MT
									INNER JOIN T_Mass_Tag_to_Protein_Map MTPM
										ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
									INNER JOIN T_Proteins Prot
										ON MTPM.Ref_ID = Prot.Ref_ID
									INNER JOIN #Tmp_MTs_ToExport F
										ON MT.Mass_Tag_ID = F.Mass_Tag_ID
								GROUP BY Prot.Ref_ID ) ProteinIDQ
					ON Prot.Ref_ID = ProteinIDQ.Ref_ID
			ORDER BY Prot.Reference
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

		End

		If @ReturnProteinMapTable <> 0
		Begin
			SELECT MT.Mass_Tag_ID,
					Prot.Reference AS Protein,
					MTPM.Ref_ID,
					FullSeq.Peptide_Sequence,
					MTPM.Cleavage_State,
					MTPM.Fragment_Number,
					MTPM.Fragment_Span,
					MTPM.Residue_Start,
					MTPM.Residue_End,
					MTPM.Repeat_Count,
					MTPM.Terminus_State,
					MTPM.Missed_Cleavage_Count,
					CASE
						WHEN Prot.Reference LIKE 'reversed[_]%' OR
							Prot.Reference LIKE 'scrambled[_]%' OR
							Prot.Reference LIKE '%[:]reversed' THEN 1
						ELSE 0
					END AS Decoy_Protein
			FROM T_Mass_Tags MT
					INNER JOIN V_Mass_Tag_to_Protein_Map_Full_Sequence FullSeq
					ON MT.Mass_Tag_ID = FullSeq.Mass_Tag_ID
					INNER JOIN T_Mass_Tag_to_Protein_Map MTPM
					ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
					INNER JOIN T_Proteins Prot
					ON MTPM.Ref_ID = Prot.Ref_ID
					INNER JOIN #Tmp_MTs_ToExport F
					ON MT.Mass_Tag_ID = F.Mass_Tag_ID
			WHERE MTPM.Ref_ID = FullSeq.Ref_ID
			ORDER BY MT.Mass_Tag_ID, Prot.Reference
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

		End
		
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMExportAMTTables')
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
		Execute PostLogEntry 'Error', @message, 'PMExportAMTTables'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO

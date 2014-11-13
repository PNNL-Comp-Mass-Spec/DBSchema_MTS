/****** Object:  StoredProcedure [dbo].[PMExportAMTTables] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.PMExportAMTTables
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
**			01/26/2011 mem - Now returning Min_MSGF_SpecProb from T_Mass_Tags
**			02/22/2011 mem - Added parameter @ReturnIMSConformersTable
**			10/07/2011 mem - Added column Peptide_Count_Observed to the proteins table
**			01/17/2012 mem - Added 'xxx.%' and 'rev[_]%' as potential prefixes for reversed proteins
**			06/20/2013 mem - Added 'xxx[_]%' as an additional prefix for reversed proteins
**			11/11/2014 mem - Added switches @ReturnMTModsTable and @ReturnMTChargesTable
**
****************************************************/
(
	@ReturnMTTable tinyint = 1,						-- When 1, then returns a table of Mass Tag IDs and various information
	@ReturnProteinTable tinyint = 1,				-- When 1, then also returns a table of Proteins that the Mass Tag IDs map to
	@ReturnProteinMapTable tinyint = 1,				-- When 1, then also returns the mapping information of Mass_Tag_ID to Protein
	@ReturnIMSConformersTable tinyint = 1,			-- When 1, then also returns T_Mass_Tag_Conformers_Observed	
	@ReturnMTModsTable tinyint = 1,					-- When 1, then also returns T_Mass_Tag_Mod_Info (with mod masses pulled from MT_Main)	
	@ReturnMTChargesTable tinyint = 1,				-- When 1, then also returns a table summarizing the charge state observation stats
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
		Set @ReturnIMSConformersTable = IsNull(@ReturnIMSConformersTable, 1)
		Set @ReturnMTModsTable = IsNull(@ReturnMTModsTable, 1)
		Set @ReturnMTChargesTable = IsNull(@ReturnMTChargesTable, 1)
		
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
			       MT.Min_MSGF_SpecProb,
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
			SELECT Prot.Reference AS Protein,
			       Prot.Ref_ID,
			       Prot.Description,
			       Prot.Protein_Residue_Count,
			       Prot.Monoisotopic_Mass,
			       Prot.Protein_DB_ID,
			       Prot.External_Reference_ID,
			       Prot.External_Protein_ID,
			       Prot.Protein_Collection_ID,
			       CASE
			           WHEN Prot.Reference LIKE 'reversed[_]%' OR	-- MTS reversed proteins
			                Prot.Reference LIKE 'scrambled[_]%' OR	-- MTS scrambled proteins
			                Prot.Reference LIKE '%[:]reversed' OR	-- X!Tandem decoy proteins
	                      Prot.Reference LIKE 'xxx.%' OR			-- Inspect reversed/scrambled proteins
	                        Prot.Reference LIKE 'rev[_]%' OR		-- MSGFDB reversed proteins
	                        Prot.Reference LIKE 'xxx[_]%'			-- MSGF+ reversed proteins
			                THEN 1
			           ELSE 0
			       END AS Decoy_Protein,
			       Prot.Protein_Sequence,
			       ProteinIDQ.Peptide_Count_Observed
			FROM T_Proteins Prot
			     INNER JOIN ( SELECT Prot.Ref_ID,
			                         COUNT(*) AS Peptide_Count_Observed
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
		           CASE WHEN Prot.Reference LIKE 'reversed[_]%' OR  -- MTS reversed proteins  
		                     Prot.Reference LIKE 'scrambled[_]%' OR -- MTS scrambled proteins 
		                     Prot.Reference LIKE '%[:]reversed' OR  -- X!Tandem decoy proteins
		                     Prot.Reference LIKE 'xxx.%' OR         -- Inspect reversed/scrambled proteins
		                     Prot.Reference LIKE 'rev[_]%' OR       -- MSGFDB reversed proteins
		                     Prot.Reference LIKE 'xxx[_]%'          -- MSGF+ reversed proteins
			       THEN 1
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
		
		If @ReturnIMSConformersTable <> 0
		Begin
			SELECT Conf.Conformer_ID,
			       Conf.Mass_Tag_ID,
			       Conf.Charge,
			       Conf.Conformer,
			       Conf.Drift_Time_Avg,
			       Conf.Drift_Time_StDev,
			       Conf.Obs_Count
			FROM T_Mass_Tag_Conformers_Observed Conf
			     INNER JOIN #Tmp_MTs_ToExport F
			       ON Conf.Mass_Tag_ID = F.Mass_Tag_ID
			ORDER BY Conf.Conformer_ID
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		End
		
		If @ReturnMTModsTable <> 0
		Begin
			SELECT MTMI.Mass_Tag_ID,
			       MTMI.Mod_Name,
			       MTMI.Mod_Position,
			       MCF.Monoisotopic_Mass_Correction
			FROM T_Mass_Tags MT
			     INNER JOIN #Tmp_MTs_ToExport F
			       ON MT.Mass_Tag_ID = F.Mass_Tag_ID
			     INNER JOIN T_Mass_Tag_Mod_Info MTMI
			       ON MT.Mass_Tag_ID = MTMI.Mass_Tag_ID
			     INNER JOIN MT_Main.dbo.V_DMS_Mass_Correction_Factors MCF
			       ON MTMI.Mod_Name = MCF.Mass_Correction_Tag
			ORDER BY MTMI.Mass_Tag_ID, MTMI.Mod_Position, MTMI.Mod_Name
		End
		
		If @ReturnMTChargesTable <> 0
		Begin
			SELECT MT.Mass_Tag_ID,
			       Pep.Charge_State,
			       COUNT(*) AS Observations
			FROM T_Mass_Tags MT
			     INNER JOIN #Tmp_MTs_ToExport F
			       ON MT.Mass_Tag_ID = F.Mass_Tag_ID
			     INNER JOIN T_Peptides Pep
			       ON MT.Mass_Tag_ID = Pep.Mass_Tag_ID
			GROUP BY MT.Mass_Tag_ID, Pep.Charge_State
			ORDER BY MT.Mass_Tag_ID, Pep.Charge_State
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

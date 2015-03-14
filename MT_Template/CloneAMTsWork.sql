/****** Object:  StoredProcedure [dbo].[CloneAMTsWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE CloneAMTsWork
/****************************************************
** 
**	Desc:	Performs the work of cloning AMT tags in temporary table #T_Tmp_MTs_to_Clone
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	11/07/2013 mem - Initial version (refactored from CloneO18AMTs)
**			01/02/2015 mem - Added column Rank_Hit
**    
*****************************************************/
(
	@ModDescription varchar(12),
	@OrganismDBFileID int,
	@ProteinCollectionFileID int,	
	@DeleteTempTables tinyint,
	@InfoOnly tinyint = 0,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @MasterSequencesServerName varchar(64) = 'ProteinSeqs2'

	declare @Sql varchar(1024)

	declare @CandidateTablesContainJobColumn tinyint
	
	declare @CandidateSequencesTableName varchar(256)
	declare @CandidateModDetailsTableName varchar(256)

	declare @MatchCount int

	declare @processCount int = 0
	declare @sequencesAdded int = 0
	declare @UndefinedSeqIDCount int = 0

	declare @msg2 varchar(256)

	declare @logLevel int
	set @logLevel = 1		-- Default to normal logging

	declare @SourceDatabase varchar(256)
	Set @SourceDatabase = @@ServerName + '.' + DB_Name()

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
	
		-----------------------------------------------------------
		-- Create two tables on the master sequences server to cache the data to process
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Define @CandidateSequencesTableName and @CandidateModDetailsTableName'
		--
		Set @message = 'Call Master_Sequences.dbo.CreateTempSequenceTables'
		Set @CurrentLocation = @message

		Set @CandidateTablesContainJobColumn = 0
		
		-- Warning: Update @MasterSequencesServerName above if changing from ProteinSeqs2 to another computer
		exec ProteinSeqs2.Master_Sequences.dbo.CreateTempCandidateSequenceTables @CandidateSequencesTableName output, @CandidateModDetailsTableName output
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Problem calling CreateTempCandidateSequenceTables to create the temporary sequence tables'
			goto Done
		end
		else
			set @DeleteTempTables = 1

		-----------------------------------------------------------
		-- Populate @CandidateSequencesTableName with the candidate sequences
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Populate ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName + ' with candidate sequences'
		
		Set @Sql = ''
		Set @Sql = @Sql + ' INSERT INTO ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName
		set @Sql = @Sql +       ' (Seq_ID_Local, Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass)'
		Set @Sql = @Sql + ' SELECT Seq_ID_Local, Peptide, Mod_Count_New, Mod_Description_New, Monoisotopic_Mass_New'
		Set @Sql = @Sql + ' FROM #T_Tmp_MTs_to_Clone'
		--
		Exec (@Sql)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		--
		if @myError <> 0
		begin
			set @message = 'Problem populating ' + @MasterSequencesServerName + ' with the candidate sequences to process'
			goto Done
		end
		
		-----------------------------------------------------------
		-- Populate @CandidateModDetailsTableName with the data to parse
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Populate ' + @MasterSequencesServerName + '.' + @CandidateModDetailsTableName + ' with candidate mod details'
		Set @Sql = ''
		Set @Sql = @Sql + ' INSERT INTO ' + @MasterSequencesServerName + '.' + @CandidateModDetailsTableName
		set @Sql = @Sql +       ' (Seq_ID_Local, Mass_Correction_Tag, Position)'
		Set @Sql = @Sql + ' SELECT MT.Seq_ID_Local, MTMi.Mod_Name, MTMI.Mod_Position'
		Set @Sql = @Sql + ' FROM #T_Tmp_Mass_Tag_Mod_Info MTMI INNER JOIN'
		Set @Sql = @Sql +      ' #T_Tmp_MTs_to_Clone MT ON MTMI.Mass_Tag_ID = MT.Mass_Tag_ID'
		--
		Exec (@Sql)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Problem populating ' + @MasterSequencesServerName + ' with the candidate sequence mod details'
			goto Done
		end	

		-----------------------------------------------------------
		-- Call ProcessCandidateSequences to process the data in the temporary sequence tables
		-----------------------------------------------------------
		--
		set @message = 'Call Master_Sequences.dbo.ProcessCandidateSequences'
		Set @CurrentLocation = @message
		If @logLevel >= 1
			execute PostLogEntry 'Progress', @message, 'CloneAMTsWork'
		--
		exec @myError = ProteinSeqs2.Master_Sequences.dbo.ProcessCandidateSequences @OrganismDBFileID, @ProteinCollectionFileID,
																@CandidateSequencesTableName, @CandidateModDetailsTableName, 
																@CandidateTablesContainJobColumn = @CandidateTablesContainJobColumn,
																@Job = 0, 
																@SourceDatabase = @SourceDatabase,
																@count = @processCount output, 
																@message = @message output
		--
		if @myError <> 0
		begin
			If Len(@message) = 0
				set @message = 'Error with ' + @CurrentLocation + ': ' + convert(varchar(12), @myError)
			else
				set @message = 'Error with ' + @CurrentLocation + ': ' + @message
				
			goto Done
		end
		

		-----------------------------------------------------------
		-- Update the Seq_ID values in #T_Tmp_MTs_to_Clone using the
		-- tables on the remote server
		-----------------------------------------------------------
		Set @CurrentLocation = 'UPDATE #T_Tmp_MTs_to_Clone using Seq_ID values in ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName
		
		Set @Sql = ''
		Set @Sql = @Sql + ' UPDATE #T_Tmp_MTs_to_Clone'
		Set @Sql = @Sql + ' SET Mass_Tag_ID_New = MSeqData.Seq_ID'
		Set @Sql = @Sql + ' FROM #T_Tmp_MTs_to_Clone MTC INNER JOIN'
		Set @Sql = @Sql +  ' ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName + ' MSeqData '
		set @Sql = @Sql +    ' ON MTC.Seq_ID_Local = MSeqData.Seq_ID_Local'
		--
		If @infoOnly <> 0
			print @sql
			
		Exec (@Sql)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Error updating #T_Tmp_MTs_to_Clone with the Seq_ID values'
			goto Done
		end
		
		-----------------------------------------------------------
		-- Validate that all of the sequences have Mass_Tag_ID_New values
		-----------------------------------------------------------
		Set @CurrentLocation = 'Validate that all of the sequences have Mass_Tag_ID_New values'
		Set @UndefinedSeqIDCount = 0
		
		SELECT @UndefinedSeqIDCount = Count(*)
		FROM #T_Tmp_MTs_to_Clone
		WHERE Mass_Tag_ID_New IS NULL
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @UndefinedSeqIDCount > 0
		Begin
			set @message = 'Found ' + Convert(varchar(12), @UndefinedSeqIDCount) + ' sequences with undefined Mass_Tag_ID_New values; this is unexpected'
			set @myError = 51113
			Goto Done
		End
		
		-----------------------------------------------------------
		-- Flag entries in #T_Tmp_MTs_to_Clone that need to be added to T_Mass_Tags
		-----------------------------------------------------------
		--		
		UPDATE #T_Tmp_MTs_to_Clone
		SET Add_Sequence = 1
		FROM #T_Tmp_MTs_to_Clone MTC
			LEFT OUTER JOIN T_Mass_Tags MT
			ON MTC.Mass_Tag_ID_New = MT.Mass_Tag_ID
		WHERE MT.Mass_Tag_ID IS NULL
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error


		If @infoOnly <> 0
		Begin
			SELECT *
			FROM #T_Tmp_MTs_to_Clone
			ORDER BY Mass_Tag_ID_New
			
			SELECT MTC.Mass_Tag_ID_New,
				MTMI.*
			FROM #T_Tmp_Mass_Tag_Mod_Info MTMI
				INNER JOIN #T_Tmp_MTs_to_Clone MTC
				ON MTMI.Mass_Tag_ID = MTC.Mass_Tag_ID
			ORDER BY MTC.Mass_Tag_ID_New

		End
		Else
		Begin
		
			If NOT EXISTS (SELECT * FROM #T_Tmp_MTs_to_Clone WHERE Add_Sequence = 1)
			Begin
				Set @message = 'No new AMTs need to be cloned'
				Print @message
				Goto Done
			End
			
			
			Declare @TranAddMTs varchar(24) = 'AddMTs'
			
			Begin Transaction @TranAddMTs
			
			-----------------------------------------------------------
			-- Add the new AMTs to T_Mass_Tags
			-----------------------------------------------------------
			--
			set @message = 'Add new sequences to T_Mass_Tags'
			Set @CurrentLocation = @message
			--
			INSERT INTO T_Mass_Tags
				(Mass_Tag_ID, Peptide, Monoisotopic_Mass, Multiple_Proteins, Created, Last_Affected, Number_Of_Peptides, 
				Peptide_Obs_Count_Passing_Filter, High_Normalized_Score, High_Discriminant_Score, High_Peptide_Prophet_Probability, 
				Mod_Count, Mod_Description, PMT_Quality_Score, Cleavage_State_Max, PeptideEx, Min_MSGF_SpecProb)
			SELECT Mass_Tag_ID_New, Peptide, Monoisotopic_Mass_New, Multiple_Proteins, GetDate() AS Created, GetDate() AS Last_Affected, Number_Of_Peptides, 
				Peptide_Obs_Count_Passing_Filter, High_Normalized_Score, High_Discriminant_Score, High_Peptide_Prophet_Probability, 
				Mod_Count_New, Mod_Description_New, PMT_Quality_Score, Cleavage_State_Max, PeptideEx_New, Min_MSGF_SpecProb
			FROM #T_Tmp_MTs_to_Clone
			WHERE Add_Sequence = 1
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount
			--			
			Set @sequencesAdded = @myRowCount				
			
			-----------------------------------------------------------
			-- Add the new entries to T_Mass_Tag_to_Protein_Map
			-----------------------------------------------------------
			
			INSERT INTO T_Mass_Tag_to_Protein_Map
				(Mass_Tag_ID, Mass_Tag_Name, Ref_ID, Cleavage_State, Fragment_Number, Fragment_Span, Residue_Start, 
				Residue_End, Repeat_Count, Terminus_State, Missed_Cleavage_Count)
			SELECT MT.Mass_Tag_ID_New, MTPM.Mass_Tag_Name, MTPM.Ref_ID, MTPM.Cleavage_State, MTPM.Fragment_Number, 
				MTPM.Fragment_Span, MTPM.Residue_Start, MTPM.Residue_End, MTPM.Repeat_Count, MTPM.Terminus_State, 
				MTPM.Missed_Cleavage_Count
			FROM T_Mass_Tag_to_Protein_Map MTPM INNER JOIN
				#T_Tmp_MTs_to_Clone MT ON MTPM.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount
				
			
			-----------------------------------------------------------
			-- Add the new entries to T_Mass_Tag_Mod_Info
			-----------------------------------------------------------
			
			INSERT INTO T_Mass_Tag_Mod_Info
				(Mass_Tag_ID, Mod_Name, Mod_Position, Entered)
			SELECT MT.Mass_Tag_ID_New, MTMI.Mod_Name, MTMI.Mod_Position, GetDate() AS Entered
			FROM #T_Tmp_Mass_Tag_Mod_Info MTMI INNER JOIN
				#T_Tmp_MTs_to_Clone MT ON MTMI.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount
			
			
			-----------------------------------------------------------
			-- Add the new entries to T_Mass_Tags_NET
			-----------------------------------------------------------
			
			INSERT INTO T_Mass_Tags_NET
				(Mass_Tag_ID, Min_GANET, Max_GANET, Avg_GANET, Cnt_GANET, StD_GANET, StdError_GANET, PNET, PNET_Variance)
			SELECT MT.Mass_Tag_ID_New, MTN.Min_GANET, MTN.Max_GANET, MTN.Avg_GANET, MTN.Cnt_GANET, MTN.StD_GANET, 
				MTN.StdError_GANET, MTN.PNET, MTN.PNET_Variance
			FROM T_Mass_Tags_NET MTN INNER JOIN
				#T_Tmp_MTs_to_Clone MT ON MTN.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE (MT.Add_Sequence = 1)
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount


			---------------------------------------------------------
			-- Add the new entries to T_Mass_Tag_Peptide_Prophet_Stats
			-----------------------------------------------------------
			
			INSERT INTO T_Mass_Tag_Peptide_Prophet_Stats
				(Mass_Tag_ID, ObsCount_CS1, ObsCount_CS2, ObsCount_CS3, PepProphet_FScore_Max_CS1, 
				PepProphet_FScore_Max_CS2, PepProphet_FScore_Max_CS3, PepProphet_Probability_Max_CS1, 
				PepProphet_Probability_Max_CS2, PepProphet_Probability_Max_CS3, PepProphet_FScore_Avg_CS1, 
				PepProphet_FScore_Avg_CS2, PepProphet_FScore_Avg_CS3, Cleavage_State_Max)
			SELECT MT.Mass_Tag_ID_New,
				MTPP.ObsCount_CS1,
				MTPP.ObsCount_CS2,
				MTPP.ObsCount_CS3,
				MTPP.PepProphet_FScore_Max_CS1,
				MTPP.PepProphet_FScore_Max_CS2,
				MTPP.PepProphet_FScore_Max_CS3,
				MTPP.PepProphet_Probability_Max_CS1,
				MTPP.PepProphet_Probability_Max_CS2,
				MTPP.PepProphet_Probability_Max_CS3,
				MTPP.PepProphet_FScore_Avg_CS1,
				MTPP.PepProphet_FScore_Avg_CS2,
				MTPP.PepProphet_FScore_Avg_CS3,
				MTPP.Cleavage_State_Max
			FROM T_Mass_Tag_Peptide_Prophet_Stats MTPP INNER JOIN
				#T_Tmp_MTs_to_Clone MT ON MTPP.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE (MT.Add_Sequence = 1)


			Set @message = 'Cloned ' + @ModDescription + ' AMTs and added ' + Convert(varchar(12), @sequencesAdded) + ' new peptides to T_Mass_Tags and related tables'
			exec PostLogEntry 'Normal', @message, 'CloneAMTsWork'

			
			-----------------------------------------------------------
			-- Clone the info in T_Peptides and related tables
			-----------------------------------------------------------
			
			Declare @PeptideIDAddon int
			declare @PeptidesCloned int = 0

			SELECT @PeptideIDAddon = MAX(Peptide_ID)
			FROM T_Peptides
			
			
			-- T_Peptides
			--
			INSERT INTO T_Peptides( Peptide_ID, Job, Scan_Number, Number_Of_Scans, Charge_State, MH, Multiple_Proteins, Peptide, Mass_Tag_ID, 
				GANET_Obs, State_ID, Scan_Time_Peak_Apex, Peak_Area, Peak_SN_Ratio, Max_Obs_Area_In_Job, 
				PMT_Quality_Score_Local, DelM_PPM, Rank_Hit)
			SELECT Pep.Peptide_ID + @PeptideIDAddon,
				Pep.Job,
				Pep.Scan_Number,
				Pep.Number_Of_Scans,
				Pep.Charge_State,
				Pep.MH,
				Pep.Multiple_Proteins,
				Pep.Peptide,
				MT.Mass_Tag_ID_New,
				Pep.GANET_Obs,
				Pep.State_ID,
				Pep.Scan_Time_Peak_Apex,
				Pep.Peak_Area,
				Pep.Peak_SN_Ratio,
				Pep.Max_Obs_Area_In_Job,
				Pep.PMT_Quality_Score_Local,
				Pep.DelM_PPM,
				Ppe.Rank_Hit
			FROM T_Peptides Pep
				INNER JOIN #T_Tmp_MTs_to_Clone MT
				ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount
			--			
			Set @PeptidesCloned = @myRowCount
			
			-- T_Score_Discriminant
			--
			INSERT INTO T_Score_Discriminant ( Peptide_ID, MScore, DiscriminantScore, DiscriminantScoreNorm, PassFilt, Peptide_Prophet_FScore, Peptide_Prophet_Probability, MSGF_SpecProb )				
			SELECT Src.Peptide_ID + @PeptideIDAddon,
				Src.MScore,
				Src.DiscriminantScore,
				Src.DiscriminantScoreNorm,
				Src.PassFilt,
				Src.Peptide_Prophet_FScore,
				Src.Peptide_Prophet_Probability,
				Src.MSGF_SpecProb
			FROM T_Score_Discriminant Src
				INNER JOIN T_Peptides Pep
				ON Src.Peptide_ID = Pep.Peptide_ID
				INNER JOIN #T_Tmp_MTs_to_Clone MT
				ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1

			-- T_Score_Inspect
			--
			INSERT INTO T_Score_Inspect ( Peptide_ID, MQScore, TotalPRMScore, MedianPRMScore, FractionY, FractionB, Intensity, PValue, FScore, DeltaScore, 
				DeltaScoreOther, DeltaNormMQScore, DeltaNormTotalPRMScore, RankTotalPRMScore, RankFScore, DelM, 
				Normalized_Score )				
			SELECT Src.Peptide_ID + @PeptideIDAddon,
				Src.MQScore,
				Src.TotalPRMScore,
				Src.MedianPRMScore,
				Src.FractionY,
				Src.FractionB,
				Src.Intensity,
				Src.PValue,
				Src.FScore,
				Src.DeltaScore,
				Src.DeltaScoreOther,
				Src.DeltaNormMQScore,
				Src.DeltaNormTotalPRMScore,
				Src.RankTotalPRMScore,
				Src.RankFScore,
				Src.DelM,
				Src.Normalized_Score
			FROM T_Score_Inspect Src
				INNER JOIN T_Peptides Pep
				ON Src.Peptide_ID = Pep.Peptide_ID
				INNER JOIN #T_Tmp_MTs_to_Clone MT
				ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1

			-- T_Score_MSGFDB
			--
			INSERT INTO T_Score_MSGFDB ( Peptide_ID, FragMethod, PrecursorMZ, DelM, DeNovoScore, MSGFScore, SpecProb, RankSpecProb, PValue, Normalized_Score, FDR, PepFDR )				
			SELECT Src.Peptide_ID + @PeptideIDAddon,
				Src.FragMethod,
				Src.PrecursorMZ,
				Src.DelM,
				Src.DeNovoScore,
				Src.MSGFScore,
				Src.SpecProb,
				Src.RankSpecProb,
				Src.PValue,
				Src.Normalized_Score,
				Src.FDR,
				Src.PepFDR
			FROM T_Score_MSGFDB Src
				INNER JOIN T_Peptides Pep
				ON Src.Peptide_ID = Pep.Peptide_ID
				INNER JOIN #T_Tmp_MTs_to_Clone MT
				ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1
			
			-- T_Score_Sequest
			--
			INSERT INTO T_Score_Sequest ( Peptide_ID, XCorr, DeltaCn, DeltaCn2, Sp, RankSp, RankXc, DelM, XcRatio )				
			SELECT Src.Peptide_ID + @PeptideIDAddon,
				Src.XCorr,
				Src.DeltaCn,
				Src.DeltaCn2,
				Src.Sp,
				Src.RankSp,
				Src.RankXc,
				Src.DelM,
				Src.XcRatio
			FROM T_Score_Sequest Src
				INNER JOIN T_Peptides Pep
				ON Src.Peptide_ID = Pep.Peptide_ID
				INNER JOIN #T_Tmp_MTs_to_Clone MT
				ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1
			

			-- T_Score_XTandem
			--
			INSERT INTO T_Score_XTandem ( Peptide_ID, Hyperscore, Log_EValue, DeltaCn2, Y_Score, Y_Ions, B_Score, B_Ions, DelM, Intensity, Normalized_Score )				
			SELECT Src.Peptide_ID + @PeptideIDAddon,
				Src.Hyperscore,
				Src.Log_EValue,
				Src.DeltaCn2,
				Src.Y_Score,
				Src.Y_Ions,
				Src.B_Score,
				Src.B_Ions,
				Src.DelM,
				Src.Intensity,
				Src.Normalized_Score
			FROM T_Score_XTandem Src
				INNER JOIN T_Peptides Pep
				ON Src.Peptide_ID = Pep.Peptide_ID
				INNER JOIN #T_Tmp_MTs_to_Clone MT
				ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1


			Set @msg2 = 'Cloned peptides for newly cloned ' + @ModDescription + ' AMTs and added ' + Convert(varchar(12), @PeptidesCloned) + ' new rows to T_Peptides and related tables; PeptideAddon = ' + Convert(varchar(12), @PeptideIDAddon)
			exec PostLogEntry 'Normal', @msg2, 'CloneAMTsWork'

			Commit Transaction @TranAddMTs
			
			-----------------------------------------------------------
			-- Populate tables T_Mass_Tag_to_Protein_Mod_Map and T_Protein_Residue_Mods for the cloned AMTs
			-----------------------------------------------------------
			--
			exec UpdateMassTagToProteinModMap @SkipExistingEntries=1, @infoOnly=0
			
		End


	End Try
	Begin Catch
		If @@TranCount > 0
			Rollback

		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'CloneAMTsWork')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch	

Done:

	-----------------------------------------------------------
	-- Delete the temporary sequence tables, since no longer needed
	-----------------------------------------------------------
	--
	If @DeleteTempTables = 1
	Begin
		Begin Try
			Set @CurrentLocation = 'Delete temporary tables ' + @CandidateSequencesTableName + ' and ' + @CandidateModDetailsTableName
			exec ProteinSeqs2.Master_Sequences.dbo.DropTempSequenceTables @CandidateSequencesTableName, @CandidateModDetailsTableName
		End Try
		Begin Catch
			-- Error caught
			Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'CloneAMTsWork')
			exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
									@ErrorNum = @myError output, @message = @message output
		End Catch
	End
		
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CloneAMTsWork] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CloneAMTsWork] TO [MTS_DB_Lite] AS [dbo]
GO

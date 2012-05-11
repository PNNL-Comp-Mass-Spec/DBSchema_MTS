/****** Object:  StoredProcedure [dbo].[CloneO18AMTs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.CloneO18AMTs
/****************************************************
** 
**	Desc:	Clones each AMT tag in T_Mass_Tags that has an O18 mod on the C-terminus (e.g. Two_O18:30)
**
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	02/09/2012 mem - Initial version
**    
*****************************************************/
(
	@InfoOnly tinyint = 0,
	@PMTQualityScoreMinimum real = 1,
	@O18DynamicModSymbol varchar(1) = '#',				-- If a dynamic O18 mod search was used, then use this parameter to define the mod symbol that needs to be removed from cloned AMTs
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @O18ModName varchar(12) = 'Two_O18'
	declare @O18ModMass float = 0
	
	declare @MasterSequencesServerName varchar(64)
	set @MasterSequencesServerName = 'ProteinSeqs2'

	Declare @PDBID int = 0
	Declare @Job int = 0
	Declare @PeptideDBPath varchar(128) = ''
	Declare @NSql nvarchar(2048)
	Declare @Params nvarchar(2048)

	declare @OrganismDBFileID int
	declare @ProteinCollectionFileID int

	declare @DeleteTempTables tinyint
	declare @processCount int
	declare @sequencesAdded int
	
	declare @UndefinedSeqIDCount int
	
	set @DeleteTempTables = 0
	set @processCount = 0
	set @sequencesAdded = 0
	set @UndefinedSeqIDCount = 0

	declare @CandidateTablesContainJobColumn tinyint
	
	declare @CandidateSequencesTableName varchar(256)
	declare @CandidateModDetailsTableName varchar(256)

	declare @MatchCount int
	
	declare @Sql varchar(1024)
	declare @msg2 varchar(256)

	declare @SourceDatabase varchar(256)
	Set @SourceDatabase = @@ServerName + '.' + DB_Name()
	
	declare @logLevel int
	set @logLevel = 1		-- Default to normal logging

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		-------------------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------------------
		
		Set @InfoOnly = IsNull(@InfoOnly, 0)
		Set @PMTQualityScoreMinimum = IsNull(@PMTQualityScoreMinimum, 1)
		Set @O18DynamicModSymbol = IsNull(@O18DynamicModSymbol, '')
		Set @message = ''

		--------------------------------------------------------------
		-- Lookup the monoisotopic mass for the Two_O18 mod
		--------------------------------------------------------------
		
		SELECT @O18ModMass = Monoisotopic_Mass_Correction
		FROM MT_Main.dbo.T_DMS_Mass_Correction_Factors_Cached
		WHERE (Mass_Correction_Tag = @O18ModName)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error


		If @myRowCount = 0 Or @O18ModMass = 0
		Begin
			Set @myError = 51000
			Set @message = 'Mod "' + @O18ModName + '" not found in MT_Main.dbo.T_DMS_Mass_Correction_Factors_Cached'
			Goto Done
		End
		
		--------------------------------------------------------------
		-- Lookup the Organism DB file info for the first job in T_Analysis_Description
		--------------------------------------------------------------
		
		-- Lookup the Peptide DB ID
		--
		SELECT TOP 1 @PDBID = PDB_ID, @Job = Job
		FROM T_Analysis_Description TAD
		WHERE NOT PDB_ID IS NULL
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myRowCount < 1
		begin
			Set @message = 'No analyses with valid peptide DB IDs were found'
			Set @myError = 50014
			goto Done
		end

		
		-- Determine the name and server for this peptide DB		
		--
		SELECT @PeptideDBPath = CASE WHEN @@SERVERNAME = [Server_Name] THEN ''
		                             ELSE [Server_Name] + '.'
		                             END + '[' + Peptide_DB_Name + ']'
		FROM MT_Main.dbo.V_MTS_PT_DBs
		WHERE (Peptide_DB_ID = @PDBID) AND
		      (State_ID < 15)

		If IsNull(@PeptideDBPath, '') = ''
		Begin
			Set @message = 'Unable to determine the full path to the Peptide DB'
			Set @myError = 50014
			goto Done
		End
		
		
		-- Call GetOrganismDBFileInfo in the peptide DB to determine the Protein Collection File ID
		--
		Set @NSql = 'Exec ' + @PeptideDBPath + '.dbo.GetOrganismDBFileInfo @job, @OrganismDBFileID = @OrganismDBFileID OUTPUT, @ProteinCollectionFileID = @ProteinCollectionFileID OUTPUT'
		Set @Params = '@job int, @OrganismDBFileID int output, @ProteinCollectionFileID int output'
		
		Exec @myError = sp_executesql @NSql, @Params, @Job, @OrganismDBFileID = @OrganismDBFileID OUTPUT, @ProteinCollectionFileID = @ProteinCollectionFileID OUTPUT
	
		If @myError <> 0
		Begin
			Set @message = 'Error calling "' + @PeptideDBPath + '.GetOrganismDBFileInfo"'
			goto Done
		End
		
		
		--------------------------------------------------------------
		-- Create the temporary tables
		--------------------------------------------------------------
		--
		Set @CurrentLocation = 'Create the temporary tables'
		
		CREATE TABLE #T_Tmp_O18_MTs_to_Clone (
			Seq_ID_Local int identity(1,1),
			Mass_Tag_ID int NOT NULL,
			Peptide varchar(850) NOT NULL,			-- Clean_Sequence
			Monoisotopic_Mass float NULL,
			Multiple_Proteins smallint NULL,
			Created datetime NOT NULL,
			Last_Affected datetime NOT NULL,
			Number_Of_Peptides int NULL,
			Peptide_Obs_Count_Passing_Filter int NULL,
			High_Normalized_Score real NULL,
			High_Discriminant_Score real NULL,
			High_Peptide_Prophet_Probability real NULL,
			Mod_Count int NOT NULL,
			Mod_Description varchar(2048) NOT NULL,
			PMT_Quality_Score numeric(9, 5) NULL,
			Cleavage_State_Max tinyint NOT NULL,
			PeptideEx varchar(512) NULL,
			Min_MSGF_SpecProb real NULL,
			Mod_Count_New int NOT NULL, 
			Mod_Description_New varchar(2048) NOT NULL,
			PeptideEx_New varchar(512) NULL,
			Monoisotopic_Mass_New float NOT NULL,
			Mass_Tag_ID_New int NULL,
			Add_Sequence tinyint NULL,
		)
		
		CREATE UNIQUE INDEX #IX_T_Tmp_O18_MTs_to_Clone ON #T_Tmp_O18_MTs_to_Clone (Mass_Tag_ID ASC)
				
		
		CREATE TABLE #T_Tmp_Mass_Tag_Mod_Info (
			Entry_ID int IDENTITY(1,1) NOT NULL,
			Mass_Tag_ID int NOT NULL,
			Mod_Name varchar(32) NOT NULL,
			Mod_Position smallint NOT NULL,
		)

		CREATE UNIQUE INDEX #IX_T_Tmp_Mass_Tag_Mod_Info ON #T_Tmp_Mass_Tag_Mod_Info (Entry_ID ASC)
		

		--------------------------------------------------------------
		-- Populate #T_Tmp_O18_MTs_to_Clone
		--------------------------------------------------------------
		--
		Set @CurrentLocation = 'Populate #T_Tmp_O18_MTs_to_Clone'

		INSERT INTO #T_Tmp_O18_MTs_to_Clone
			(Mass_Tag_ID, Peptide, Monoisotopic_Mass, Multiple_Proteins, Created, Last_Affected, Number_Of_Peptides, 
			Peptide_Obs_Count_Passing_Filter, High_Normalized_Score, High_Discriminant_Score, High_Peptide_Prophet_Probability, 
			Mod_Count, Mod_Description, PMT_Quality_Score, Cleavage_State_Max, PeptideEx, Min_MSGF_SpecProb, 
			Mod_Count_New, Mod_Description_New, PeptideEx_New, Monoisotopic_Mass_New, Add_Sequence)
		SELECT Mass_Tag_ID,
		       Peptide,
		       Monoisotopic_Mass,
		       Multiple_Proteins,
		       GETDATE() AS Created,
		       GETDATE() AS Last_Affected,
		       Number_Of_Peptides,
		       Peptide_Obs_Count_Passing_Filter,
		       High_Normalized_Score,
		       High_Discriminant_Score,
		       High_Peptide_Prophet_Probability,
		       Mod_Count,
		       Mod_Description,
		       PMT_Quality_Score,
		       Cleavage_State_Max,
		       PeptideEx,
		       Min_MSGF_SpecProb,
		       -1 AS Mod_Count_New,
		       '' AS Mod_Description_New,
		       CASE WHEN @O18DynamicModSymbol = '' 
		            THEN PeptideEx
		            ELSE Replace(PeptideEx, @O18DynamicModSymbol, '')
		       END,
		       Monoisotopic_Mass - @O18ModMass AS Monoisotopic_Mass_New,
		       0 AS Add_Sequence
		FROM T_Mass_Tags
		WHERE (PMT_Quality_Score >= @PMTQualityScoreMinimum) AND
		      (Mod_Description LIKE '%Two_O18%')			-- Like @O18ModName
		ORDER BY Mass_Tag_ID

		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
		Begin
			Set @message = 'No AMT tags in T_Mass_Tags have PMT QS >= ' + Convert(varchar(12), @PMTQualityScoreMinimum) + ' and Mod_Description Like Two_O18'
			Print @message
			Goto Done
		End
		
		--------------------------------------------------------------
		-- Populate #T_Tmp_Mass_Tag_Mod_Info
		-- Exclude the Two_O18 entries
		--------------------------------------------------------------
		--
		Set @CurrentLocation = 'Populate #T_Tmp_Mass_Tag_Mod_Info'

		INSERT INTO #T_Tmp_Mass_Tag_Mod_Info 
			(Mass_Tag_ID, Mod_Name, Mod_Position)
		SELECT MTMI.Mass_Tag_ID,
		       MTMI.Mod_Name,
		       MTMI.Mod_Position
		FROM T_Mass_Tag_Mod_Info MTMI
		     INNER JOIN #T_Tmp_O18_MTs_to_Clone MT
		       ON MTMI.Mass_Tag_ID = MT.Mass_Tag_ID
		WHERE Mod_Name <> @O18ModName

		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		
		-----------------------------------------------------------
		-- Populate the Mod_Description_New column
		-----------------------------------------------------------

		-- First process peptides with multiple mods, for example: IodoAcet:11,Two_O18:15
		--
		UPDATE #T_Tmp_O18_MTs_to_Clone
		SET Mod_Description_New = SUBSTRING(Mod_Description, 1, CHARINDEX('Two_O18', Mod_Description) - 2), 
			Mod_Count_New = Mod_Count - 1
		WHERE Not Mod_Description like 'Two_O18%'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		-- Next process peptides with only a O18 mod, for example: Two_O18:21
		--
		UPDATE #T_Tmp_O18_MTs_to_Clone
		SET Mod_Description_New = '', Mod_Count_New = 0
		WHERE Mod_Description like 'Two_O18%'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		-- Make sure all of the peptides were updated
		IF EXISTS (Select * from #T_Tmp_O18_MTs_to_Clone Where Mod_Count_New < 0)
		Begin
			Set @myError = 50010
			set @message = 'Entries in #T_Tmp_O18_MTs_to_Clone have Mod_Count_New < 0; this is unexpected'
			goto Done			
		End


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
		Set @Sql = @Sql + ' FROM #T_Tmp_O18_MTs_to_Clone'
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
		Set @Sql = @Sql +      ' #T_Tmp_O18_MTs_to_Clone MT ON MTMI.Mass_Tag_ID = MT.Mass_Tag_ID'
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
			execute PostLogEntry 'Progress', @message, 'CloneO18AMTs'
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
		-- Update the Seq_ID values in #T_Tmp_O18_MTs_to_Clone using the
		-- tables on the remote server
		-----------------------------------------------------------
		Set @CurrentLocation = 'UPDATE #T_Tmp_O18_MTs_to_Clone using Seq_ID values in ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName
		
		Set @Sql = ''
		Set @Sql = @Sql + ' UPDATE #T_Tmp_O18_MTs_to_Clone'
		Set @Sql = @Sql + ' SET Mass_Tag_ID_New = MSeqData.Seq_ID'
		Set @Sql = @Sql + ' FROM #T_Tmp_O18_MTs_to_Clone MTC INNER JOIN'
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
			set @message = 'Error updating #T_Tmp_O18_MTs_to_Clone with the Seq_ID values'
			goto Done
		end
		
		-----------------------------------------------------------
		-- Validate that all of the sequences have Mass_Tag_ID_New values
		-----------------------------------------------------------
		Set @CurrentLocation = 'Validate that all of the sequences have Mass_Tag_ID_New values'
		Set @UndefinedSeqIDCount = 0
		
		SELECT @UndefinedSeqIDCount = Count(*)
		FROM #T_Tmp_O18_MTs_to_Clone
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
		-- Flag entries in #T_Tmp_O18_MTs_to_Clone that need to be added to T_Mass_Tags
		-----------------------------------------------------------
		--		
		UPDATE #T_Tmp_O18_MTs_to_Clone
		SET Add_Sequence = 1
		FROM #T_Tmp_O18_MTs_to_Clone MTC
		     LEFT OUTER JOIN T_Mass_Tags MT
		       ON MTC.Mass_Tag_ID_New = MT.Mass_Tag_ID
		WHERE MT.Mass_Tag_ID IS NULL
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error


		If @infoOnly <> 0
		Begin
			SELECT *
			FROM #T_Tmp_O18_MTs_to_Clone
			ORDER BY Mass_Tag_ID_New
			
			SELECT MTC.Mass_Tag_ID_New,
			       MTMI.*
			FROM #T_Tmp_Mass_Tag_Mod_Info MTMI
			     INNER JOIN #T_Tmp_O18_MTs_to_Clone MTC
			       ON MTMI.Mass_Tag_ID = MTC.Mass_Tag_ID
			ORDER BY MTC.Mass_Tag_ID_New

		End
		Else
		Begin
		
			If NOT EXISTS (SELECT * FROM #T_Tmp_O18_MTs_to_Clone WHERE Add_Sequence = 1)
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
			FROM #T_Tmp_O18_MTs_to_Clone
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
				#T_Tmp_O18_MTs_to_Clone MT ON MTPM.Mass_Tag_ID = MT.Mass_Tag_ID
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
				 #T_Tmp_O18_MTs_to_Clone MT ON MTMI.Mass_Tag_ID = MT.Mass_Tag_ID
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
				#T_Tmp_O18_MTs_to_Clone MT ON MTN.Mass_Tag_ID = MT.Mass_Tag_ID
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
				#T_Tmp_O18_MTs_to_Clone MT ON MTPP.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE (MT.Add_Sequence = 1)


			Set @message = 'Cloned O18 AMTs and added ' + Convert(varchar(12), @sequencesAdded) + ' new peptides to T_Mass_Tags and related tables'
			exec PostLogEntry 'Normal', @message, 'CloneO18AMTs'

			
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
				PMT_Quality_Score_Local, DelM_PPM)				
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
			       Pep.DelM_PPM
			FROM T_Peptides Pep
			     INNER JOIN #T_Tmp_O18_MTs_to_Clone MT
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
			     INNER JOIN #T_Tmp_O18_MTs_to_Clone MT
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
			     INNER JOIN #T_Tmp_O18_MTs_to_Clone MT
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
			     INNER JOIN #T_Tmp_O18_MTs_to_Clone MT
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
			     INNER JOIN #T_Tmp_O18_MTs_to_Clone MT
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
			     INNER JOIN #T_Tmp_O18_MTs_to_Clone MT
			       ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE MT.Add_Sequence = 1


			Set @msg2 = 'Cloned peptides for newly cloned O18 AMTs and added ' + Convert(varchar(12), @PeptidesCloned) + ' new rows to T_Peptides and related tables; PeptideAddon = ' + Convert(varchar(12), @PeptideIDAddon)
			exec PostLogEntry 'Normal', @msg2, 'CloneO18AMTs'

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
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'CloneO18AMTs')
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
			Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'CloneO18AMTs')
			exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
									@ErrorNum = @myError output, @message = @message output
		End Catch
	End
	
	
	If @infoOnly = 0 And @myError <> 0
		exec PostLogEntry 'Error', @message, 'CloneO18AMTs'
	
	
	return @myError


GO

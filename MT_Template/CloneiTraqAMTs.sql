ALTER PROCEDURE dbo.CloneiTraqAMTs
/****************************************************
** 
**	Desc:	Clones each AMT tag in T_Mass_Tags that has ITraq mods (e.g. itrac:1 or itrac:5)
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	11/7/2013 mem - Initial version (modelled after CloneO18AMTs)
**    
*****************************************************/
(
	@InfoOnly tinyint = 0,
	@PMTQualityScoreMinimum real = 1,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @ITraqModName varchar(12) = 'itrac'
	declare @ITraqModMass float = 0

	Declare @PDBID int = 0
	Declare @Job int = 0
	Declare @PeptideDBPath varchar(128) = ''
	Declare @NSql nvarchar(2048)
	Declare @Params nvarchar(2048)

	declare @OrganismDBFileID int
	declare @ProteinCollectionFileID int

	declare @DeleteTempTables tinyint
	set @DeleteTempTables = 0
	
	declare @Sql varchar(1024)

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		-------------------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------------------
		
		Set @InfoOnly = IsNull(@InfoOnly, 0)
		Set @PMTQualityScoreMinimum = IsNull(@PMTQualityScoreMinimum, 1)
		Set @message = ''

		--------------------------------------------------------------
		-- Lookup the monoisotopic mass for the ITraq mod
		--------------------------------------------------------------
		
		SELECT @ITraqModMass = Monoisotopic_Mass_Correction
		FROM MT_Main.dbo.T_DMS_Mass_Correction_Factors_Cached
		WHERE (Mass_Correction_Tag = @ITraqModName)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error


		If @myRowCount = 0 Or @ITraqModMass = 0
		Begin
			Set @myError = 51000
			Set @message = 'Mod "' + @ITraqModName + '" not found in MT_Main.dbo.T_DMS_Mass_Correction_Factors_Cached'
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
		
		CREATE TABLE #T_Tmp_MTs_to_Clone (
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
		
		CREATE UNIQUE INDEX #IX_T_Tmp_MTs_to_Clone ON #T_Tmp_MTs_to_Clone (Mass_Tag_ID ASC)
				
		
		CREATE TABLE #T_Tmp_Mass_Tag_Mod_Info (
			Entry_ID int IDENTITY(1,1) NOT NULL,
			Mass_Tag_ID int NOT NULL,
			Mod_Name varchar(32) NOT NULL,
			Mod_Position smallint NOT NULL,
		)

		CREATE UNIQUE INDEX #IX_T_Tmp_Mass_Tag_Mod_Info ON #T_Tmp_Mass_Tag_Mod_Info (Entry_ID ASC)
		

		--------------------------------------------------------------
		-- Populate #T_Tmp_MTs_to_Clone
		--------------------------------------------------------------
		--
		Set @CurrentLocation = 'Populate #T_Tmp_MTs_to_Clone'

		INSERT INTO #T_Tmp_MTs_to_Clone
			(Mass_Tag_ID, Peptide, Monoisotopic_Mass, Multiple_Proteins, Created, Last_Affected, Number_Of_Peptides, 
			Peptide_Obs_Count_Passing_Filter, High_Normalized_Score, High_Discriminant_Score, High_Peptide_Prophet_Probability, 
			Mod_Count, Mod_Description, PMT_Quality_Score, Cleavage_State_Max, PeptideEx, Min_MSGF_SpecProb, 
			Mod_Count_New, Mod_Description_New, PeptideEx_New, Monoisotopic_Mass_New, Add_Sequence)
		SELECT MT.Mass_Tag_ID,
		       MT.Peptide,
		       MT.Monoisotopic_Mass,
		       MT.Multiple_Proteins,
		       GETDATE() AS Created,
		       GETDATE() AS Last_Affected,
		       MT.Number_Of_Peptides,
		       MT.Peptide_Obs_Count_Passing_Filter,
		       MT.High_Normalized_Score,
		       MT.High_Discriminant_Score,
		       MT.High_Peptide_Prophet_Probability,
		       MT.Mod_Count,
		       MT.Mod_Description,
		       MT.PMT_Quality_Score,
		       MT.Cleavage_State_Max,
		       MT.PeptideEx,
		       MT.Min_MSGF_SpecProb,
		       -1 AS Mod_Count_New,
		       '' AS Mod_Description_New,
		       MT.PeptideEx,
		       MT.Monoisotopic_Mass - @ITraqModMass * CountQ.ITraqModCount AS Monoisotopic_Mass_New,
		       0 AS Add_Sequence
		FROM T_Mass_Tags MT
		     INNER JOIN ( SELECT Mass_Tag_ID,
		                         COUNT(*) AS ITraqModCount
		                  FROM T_Mass_Tag_Mod_Info
		                  WHERE Mod_Name = 'itrac'
		                  GROUP BY Mass_Tag_ID 
		                ) CountQ
		       ON MT.Mass_Tag_ID = CountQ.Mass_Tag_ID
		WHERE (PMT_Quality_Score >= @PMTQualityScoreMinimum) AND
		    (Mod_Description LIKE '%itrac%')			-- Like @ITraqModName
		ORDER BY Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
		Begin
			Set @message = 'No AMT tags in T_Mass_Tags have PMT QS >= ' + Convert(varchar(12), @PMTQualityScoreMinimum) + ' and Mod_Description Like %itrac%'
			Print @message
			Goto Done
		End
		
		--------------------------------------------------------------
		-- Populate #T_Tmp_Mass_Tag_Mod_Info
		-- Exclude the itrac entries
		--------------------------------------------------------------
		--
		Set @CurrentLocation = 'Populate #T_Tmp_Mass_Tag_Mod_Info'

		INSERT INTO #T_Tmp_Mass_Tag_Mod_Info 
			(Mass_Tag_ID, Mod_Name, Mod_Position)
		SELECT MTMI.Mass_Tag_ID,
		       MTMI.Mod_Name,
		       MTMI.Mod_Position
		FROM T_Mass_Tag_Mod_Info MTMI
		     INNER JOIN #T_Tmp_MTs_to_Clone MT
		       ON MTMI.Mass_Tag_ID = MT.Mass_Tag_ID
		WHERE Mod_Name <> @ITraqModName

		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		
		-----------------------------------------------------------
		-- Populate the Mod_Description_New column
		-----------------------------------------------------------

		-- First process peptides with multiple mods, for example: IodoAcet:11,itrac:15
		--
		UPDATE #T_Tmp_MTs_to_Clone
		SET Mod_Description_New = SUBSTRING(Mod_Description, 1, CHARINDEX('itrac', Mod_Description) - 2), 
			Mod_Count_New = Mod_Count - 1
		WHERE Not Mod_Description like 'itrac%'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		-- Next process peptides with only an iTraq mod, for example: itrac:21
		--
		UPDATE #T_Tmp_MTs_to_Clone
		SET Mod_Description_New = '', Mod_Count_New = 0
		WHERE Mod_Description like 'itrac%'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		-- Make sure all of the peptides were updated
		IF EXISTS (Select * from #T_Tmp_MTs_to_Clone Where Mod_Count_New < 0)
		Begin
			Set @myError = 50010
			set @message = 'Entries in #T_Tmp_MTs_to_Clone have Mod_Count_New < 0; this is unexpected'
			goto Done			
		End

		exec @myError = CloneAMTsWork 'iTraq', @OrganismDBFileID, @ProteinCollectionFileID, @DeleteTempTables, @InfoOnly, @message output

	End Try
	Begin Catch
		If @@TranCount > 0
			Rollback

		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'CloneiTraqAMTs')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch			
		
Done:	
	
	If @infoOnly = 0 And @myError <> 0
		exec PostLogEntry 'Error', @message, 'CloneiTraqAMTs'
	
	
	return @myError


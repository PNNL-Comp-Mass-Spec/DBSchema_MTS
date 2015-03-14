/****** Object:  StoredProcedure [dbo].[AddMatchMakingConformers] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE AddMatchMakingConformers
/****************************************************
**
**	Desc:	Examines the UMCs and matching AMT tags for the given MD_ID
**			to update the Conformer_ID column in T_FTICR_UMC_ResultDetails
**			by comparing the observed drift times to data in T_Mass_Tag_Conformers_Observed
**
**			For matches that match an existing conformer, will update T_Mass_Tag_Conformers_Observed
**			For new observations, will add a new row to T_Mass_Tag_Conformers_Observed
**
**			When updating column Obs_Count in T_Mass_Tag_Conformers_Observed will only count each conformer once per MDID
**
**			This procedure must be called after all of the matches for a given MDID task
**			have been written to T_FTICR_UMC_Results and T_FTICR_UMC_ResultDetails
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/08/2010 mem - Initial version
**			02/21/2011 mem - Added parameter @FilterByExperimentMSMS
**			03/23/2011 mem - Now updating Last_Affected in T_Mass_Tag_Conformers_Observed
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			06/26/2012 mem - Now choosing the newest job in T_Analysis_Description if an experiment has multiple datasets and/or jobs
**			04/01/2014 mem - Added @MergeChargeStates
**    
*****************************************************/
(
	@MDID int,
	@MaxFDRThreshold real = 0.95,				-- Set to a value less than 1 to filter by FDR
	@MinimumUniquenessProbability real = 0.5,	-- Set to a value greater than 0 to filter by Uniqueness Probability (UP)
	@DriftTimeTolerance real = 2,				-- Matching conformers must have drift times within this tolerance
	@MergeChargeStates tinyint = 1,				-- When 1, then ignores charge state when finding conformers
	@FilterByExperimentMSMS tinyint = 1,		-- When 1, then requires that each identified AMT tag also be observed by MS/MS for this experiment
	@message varchar(255) = '' output,
	@MaxIterations int = 0,
	@InfoOnly tinyint = 0,
	@DebugStoreCandidateConformers tinyint = 0		-- When 1, then will store the candidate conformers in table T_Tmp_CandidateConformers; this table is deleted/re-created each time this stored procedure is run
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @JobFilter int
	Declare @Experiment varchar(128)
		
	Declare @EntryID int
	Declare @Continue tinyint

	Declare @Charge smallint
	Declare @MassTagID int
	Declare @DriftTime real

	Declare @ConformerIDMatch int
	Declare @ConformerNum smallint
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------

	Set @MDID = IsNull(@MDID, -1)
	Set @MaxFDRThreshold = IsNull(@MaxFDRThreshold, 1)
	Set @MinimumUniquenessProbability = IsNull(@MinimumUniquenessProbability, 0)
	Set @DriftTimeTolerance = IsNull(@DriftTimeTolerance, 0.75)
	Set @FilterByExperimentMSMS = IsNull(@FilterByExperimentMSMS, 1)
	Set @message = ''
	
	Set @MaxIterations = IsNull(@MaxIterations, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @DebugStoreCandidateConformers = IsNull(@DebugStoreCandidateConformers, 0)
	
	-----------------------------------------------------
	-- Make sure @MDID is valid
	-----------------------------------------------------
	
	If Not Exists (SELECT * FROM T_Match_Making_Description WHERE MD_ID = @MDID)
	Begin
		Set @message = 'Invalid MD_ID value: ' + Convert(varchar(12), @MDID)
		Set @myError = 50000
		Goto Done
	End
	
	-----------------------------------------------------
	-- Find the corresponding MS/MS job number
	-----------------------------------------------------
	
	If @FilterByExperimentMSMS <> 0
	Begin
		Set @JobFilter = 0
		Set @Experiment = ''
		
		-- Note: If multiple analysis jobs existing in T_Analysis_Description for this experiment, then we're choosing the newest job
		-- The Order By clause to select this job was added in June 2012
		-- Prior to this, Sql Server would chose just one of the jobs, typically the largest job number, but there is no guarantee of that
		SELECT @Experiment = FAD.Experiment,
		       @JobFilter = IsNull(TAD.Job, 0)
		FROM T_Match_Making_Description MMD
		     INNER JOIN T_FTICR_Analysis_Description FAD
		       ON MMD.MD_Reference_Job = FAD.Job
		     LEFT OUTER JOIN T_Analysis_Description TAD
		       ON FAD.Experiment = TAD.Experiment
		WHERE MMD.MD_ID = @MDID
		ORDER BY TAD.Job desc
		
		If @JobFilter = 0
		Begin
			Set @message = 'MS/MS job not found for Experiment ' + IsNull(@Experiment, '???') + '; unable to filter by experiment'
			Set @myError = 50001
			
			If @InfoOnly <> 0
				SELECT @message as Message
			Else
				Exec PostLogEntry 'Error', @message, 'AddMatchMakingConformers'
			
			Goto Done
		End
	End
	
	-----------------------------------------------------
	-- Create a temporary table to hold the data
	-----------------------------------------------------

	CREATE TABLE #Tmp_CandidateConformers (
		Entry_ID int IDENTITY(1,1) NOT NULL,
		UMC_ResultDetails_ID int NOT NULL,
		Class_Abundance float NOT NULL,
		Charge smallint NOT NULL,
		Mass_Tag_ID int NOT NULL,
		Drift_Time real NOT NULL,
		Valid_Match tinyint NOT NULL,				-- Only used if @FilterByExperimentMSMS <> 0
		Conformer_ID int NULL,
		Conformer_Max_Abundance tinyint NULL
	)
	--
	CREATE CLUSTERED INDEX #IX_Tmp_CandidateConformers ON #Tmp_CandidateConformers ([Entry_ID])

	-----------------------------------------------------
	-- Populate a temporary table with the data to process
	-----------------------------------------------------

	INSERT INTO #Tmp_CandidateConformers( UMC_ResultDetails_ID,
	                                      Class_Abundance,
	                                      Charge,
	                                      Mass_Tag_ID,
	                                      Drift_Time,
	                                      Valid_Match )
	SELECT FURD.UMC_ResultDetails_ID,
	       FUR.Class_Abundance,
	       FUR.Charge_State_MaxAbu,
	       FURD.Mass_Tag_ID,
	       FUR.Drift_Time,
	       0 AS Valid_Match				-- Only used if @FilterByExperimentMSMS <> 0
	FROM T_FTICR_UMC_Results FUR
	     INNER JOIN T_FTICR_UMC_ResultDetails FURD
	       ON FUR.UMC_Results_ID = FURD.UMC_Results_ID
	WHERE (FUR.MD_ID = @MDID) AND
	      (FURD.Uniqueness_Probability >= @MinimumUniquenessProbability) AND
	      (FURD.FDR_Threshold <= @MaxFDRThreshold) AND
	     NOT FUR.Drift_Time IS NULL
	ORDER BY FUR.Class_Abundance DESC, FUR.Drift_Time
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error populating temporary table for MD_ID ' + Convert(varchar(12), @MDID) 
		Set @myError = 53000
		Goto Done
	End

	-----------------------------------------------------
	-- Possibly filter the data based on whether the peptides were also observed by MS/MS for this experiment (sample)
	-----------------------------------------------------
	--
	If @FilterByExperimentMSMS <> 0	
	Begin
		SELECT @myRowCount = COUNT(*)
		FROM #Tmp_CandidateConformers
		
		Set @message = 'MD_ID ' + Convert(varchar(12), @MDID) + ' for experiment ' + @Experiment + ' has ' + Convert(varchar(12), @myRowCount) + ' identified LC-MS features'
		
		UPDATE #Tmp_CandidateConformers
		SET Valid_Match = 1
		FROM #Tmp_CandidateConformers Target INNER JOIN
             T_Peptides Pep ON Target.Mass_Tag_ID = Pep.Mass_Tag_ID
        WHERE Pep.Job = @JobFilter
        --
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @message = @message + '; of these, ' + Convert(varchar(12), @myRowCount) + ' features match AMT tags that were also observed by MS/MS for this experiment'	
		
		SELECT @myRowCount = COUNT(Distinct Mass_Tag_ID)
		FROM #Tmp_CandidateConformers
		WHERE Valid_Match = 1
		
		Set @message = @message + '; unique AMT tag count = ' + Convert(varchar(12), @myRowCount)
		
	End

	If @DebugStoreCandidateConformers <> 0
	Begin
		IF Exists (SELECT * from sys.tables where Name = 'T_Tmp_CandidateConformers')
			Drop table T_Tmp_CandidateConformers
			
		SELECT @MDID as MD_ID, *
		INTO T_Tmp_CandidateConformers
		FROM #Tmp_CandidateConformers
		ORDER BY Entry_ID
	End
	
	If @InfoOnly > 0
	Begin
		SELECT @message as Message 
		
		SELECT *
		FROM #Tmp_CandidateConformers
		ORDER BY Entry_ID
		
		-- Could delete new, unused conformers from T_Mass_Tag_Conformers_Observed like this
		-- DELETE FROM T_Mass_Tag_Conformers_Observed
		-- WHERE Obs_Count = 0
		Goto Done
	End
	Else
	Begin
		If @FilterByExperimentMSMS <> 0
		Begin
			DELETE FROM #Tmp_CandidateConformers
			WHERE Valid_Match = 0
			
			Exec PostLogEntry 'Normal', @message, 'AddMatchMakingConformers'
		End
	End

	-----------------------------------------------------
	-- Step through the data by decreasing abundance
	-----------------------------------------------------
	--	

	Set @EntryID = 0
	Set @Continue = 1
	
	While @Continue = 1 and (@MaxIterations = 0 Or @EntryID < @MaxIterations)
	Begin -- <a>
		SELECT TOP 1 @EntryID = Entry_ID,
					 @Charge = Charge,
	                 @MassTagID = Mass_Tag_ID,
	                 @DriftTime = Drift_Time 
		FROM #Tmp_CandidateConformers
		WHERE Entry_ID > @EntryID
		ORDER BY Entry_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <b>
		
			-----------------------------------------------------
			-- Look for an existing entry in T_Mass_Tag_Conformers_Observed			
			-----------------------------------------------------
			--
			SELECT @ConformerIDMatch = Conformer_ID
			FROM T_Mass_Tag_Conformers_Observed
			WHERE Mass_Tag_ID = @MassTagID AND
			      (Charge = @Charge Or @MergeChargeStates > 0) AND
			      ABS(Drift_Time_Avg - @DriftTime) <= @DriftTimeTolerance
			--
			If @@rowcount = 0
			Begin -- <c>
			
				-----------------------------------------------------
				-- Match Not Found; need to determine next available Conformer_ID value
				-----------------------------------------------------
				
				Begin Transaction TranAddConformer
				
				Set @ConformerNum = 1
				
				SELECT @ConformerNum = IsNull(MAX(Conformer), 0) + 1
				FROM T_Mass_Tag_Conformers_Observed
				WHERE (Mass_Tag_ID = @MassTagID) AND 
				      (Charge = @Charge Or @MergeChargeStates > 0)
				
				
				INSERT INTO T_Mass_Tag_Conformers_Observed( Mass_Tag_ID,
				                                            Charge,
				                                            Conformer,
				                                            Drift_Time_Avg,
				                                            Obs_Count,
				                                            Last_Affected )
				VALUES(@MassTagID, @Charge, @ConformerNum, @DriftTime, 0, GetDate())
				--			    
			    SELECT @myError = @@error, @myRowCount = @@rowcount, @ConformerIDMatch = SCOPE_IDENTITY()
			    
			    If @myError <> 0
				Begin
					ROLLBACK TRANSACTION TranAddConformer
					Set @message = 'Error adding new conformer for MD_ID ' + Convert(varchar(12), @MDID) + '; MassTagID = ' + Convert(varchar(12), @MassTagID) + ', Charge = ' + Convert(varchar(12), @Charge) + ', DriftTime = ' + Convert(varchar(12), @DriftTime)
					Exec PostLogEntry 'Error', @message, 'AddMatchMakingConformers'
					Goto Done
				End
				Else
					COMMIT TRANSACTION TranAddConformer
					
			End -- </c>

			UPDATE #Tmp_CandidateConformers
			SET Conformer_ID = @ConformerIDMatch,
			    Conformer_Max_Abundance = 0
			WHERE Entry_ID = @EntryID
			
		End	-- </b>
	End -- </a>
	
	-----------------------------------------------------
	-- Flag the entries in #Tmp_CandidateConformers that have the highest abundance for each conformer
	-----------------------------------------------------
	--
	UPDATE #Tmp_CandidateConformers
	SET Conformer_Max_Abundance = 1
	FROM #Tmp_CandidateConformers
	     INNER JOIN ( SELECT Entry_ID,
	                         Row_Number() OVER ( Partition BY Conformer_ID 
	                                             ORDER BY Class_Abundance DESC, Drift_Time ) AS AbundanceRank
	                  FROM #Tmp_CandidateConformers
	                  WHERE Not Conformer_ID Is Null
	                ) LookupQ
	       ON #Tmp_CandidateConformers.Entry_ID = LookupQ.Entry_ID AND
	          LookupQ.AbundanceRank = 1
	--
	SELECT @myError = @@Error, @myRowCount = @@RowCount


	-----------------------------------------------------
	-- Commit the changes to T_FTICR_UMC_ResultDetails
	-----------------------------------------------------
	
	UPDATE T_FTICR_UMC_ResultDetails
	SET Conformer_ID = Src.Conformer_ID, 
		Conformer_Max_Abundance = Src.Conformer_Max_Abundance
	FROM T_FTICR_UMC_ResultDetails FURD INNER JOIN
		#Tmp_CandidateConformers Src ON 
		FURD.UMC_ResultDetails_ID = Src.UMC_ResultDetails_ID
	--
	SELECT @myError = @@Error, @myRowCount = @@RowCount

	If @myError <> 0
	Begin
		Set @message = 'Error storing results in T_FTICR_UMC_ResultDetails for MD_ID ' + Convert(varchar(12), @MDID)
		Exec PostLogEntry 'Error', @message, 'AddMatchMakingConformers'
		Goto Done
	End
		
	-----------------------------------------------------
	-- Update the stats in T_Mass_Tag_Conformers_Observed
	-- Note that Obs_Count only counts each AMT tags once per MD_ID;
	--   we do this using FURD.Conformer_Max_Abundance = 1
	-----------------------------------------------------
	
	UPDATE T_Mass_Tag_Conformers_Observed
	SET Obs_Count = Obs_Count_New,
		Drift_Time_Avg = Drift_Time_Avg_New,
		Drift_Time_StDev = Drift_Time_StDev_New,
		Last_Affected = GetDate()
	FROM T_Mass_Tag_Conformers_Observed Target
		    INNER JOIN ( SELECT FURD.Conformer_ID,
		                        COUNT(*) AS Obs_Count_New,
		                        AVG(T_FTICR_UMC_Results.Drift_Time) AS Drift_Time_Avg_New,
		                        StDev(T_FTICR_UMC_Results.Drift_Time) AS Drift_Time_StDev_New
		                FROM T_FTICR_UMC_ResultDetails FURD
		                    INNER JOIN T_FTICR_UMC_Results
		                        ON FURD.UMC_Results_ID = T_FTICR_UMC_Results.UMC_Results_ID
		                WHERE (NOT (FURD.Conformer_ID IS NULL)) AND
		                      (FURD.Conformer_Max_Abundance = 1)
		                GROUP BY FURD.Conformer_ID 
		               ) Source
		    ON Source.Conformer_ID = Target.Conformer_ID

	--
	SELECT @myError = @@Error, @myRowCount = @@RowCount
	
	If @myError <> 0
	Begin
		Set @message = 'Error updating stats in T_Mass_Tag_Conformers_Observed for MD_ID ' + Convert(varchar(12), @MDID)
		Exec PostLogEntry 'Error', @message, 'AddMatchMakingConformers'
	End

		
Done:

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[AddMatchMakingConformers] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddMatchMakingConformers] TO [MTS_DB_Lite] AS [dbo]
GO

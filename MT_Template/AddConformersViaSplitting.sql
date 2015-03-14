/****** Object:  StoredProcedure [dbo].[AddConformersViaSplitting] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE AddConformersViaSplitting
/****************************************************
**
**	Desc:	Examines the observed drift times for each conformer in T_Mass_Tag_Conformers_Observed
**
**			If observed drift times are more than @DriftTimeToleranceFinal msec from the must abundant observation, then
**			splits the conformer into two or more new conformers
**
**			This procedure must be called after AddMatchMakingConformersForList finishes processing all of the MDIDs being used to create conformers
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/09/2010 mem - Initial version
**			06/21/2013 mem - Moved determination of the next available conformer number for a given mass_tag_id to within the while loop processing each row in #Tmp_NewConformers
**			04/01/2014 mem - Added @MergeChargeStates
**    
*****************************************************/
(
	@DriftTimeTolerance real = 0.35,			-- Matching conformers must have drift times within this tolerance
	@MergeChargeStates tinyint = 1,				-- When 1, then ignores charge state when finding conformers
	@ConformerIDFilterList varchar(max) = '',	
	@InfoOnly tinyint = 0
)
AS
	set nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @ConformerID int
	Declare @Charge smallint
	Declare @MassTagID  int
	Declare @DriftTime real
	Declare @ConformerNumNew smallint
	Declare @ConformerIDNew int
	
	Declare @InfoOnlyConformerID int = -1
	
	Declare @Continue tinyint
	Declare @ContinueAddingNewConformers tinyint

	Declare @ConformerCountOld int
	Declare @ConformerCountNew int

	Declare @message varchar(256)
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------

	Set @DriftTimeTolerance = IsNull(@DriftTimeTolerance, 0.35)
	Set @ConformerIDFilterList = IsNull(@ConformerIDFilterList, '')
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	
	
	-----------------------------------------------------
	-- Create a temporary table to track the conformer IDs to process
	-----------------------------------------------------
	CREATE TABLE #Tmp_ConformerIDList (
		Conformer_ID int NOT NULL
	)
	
	CREATE CLUSTERED INDEX #IX_Tmp_ConformerIDList ON #Tmp_ConformerIDList (Conformer_ID)
		
	-----------------------------------------------------
	-- Create a temporary table to track the peak matching result entries 
	-- for which new conformers need to be created / assigned
	-----------------------------------------------------
	--
	CREATE TABLE #Tmp_PMResultsToProcess (
		Conformer_ID int NOT NULL,
		UMC_ResultDetails_ID int NOT NULL,
		Mass_Tag_ID int NOT NULL,
		Drift_Time real NOT NULL,
		Charge_State smallint NOT NULL,
		Class_Abundance float NOT NULL,
		Conformer_ID_New int NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_PMResultsToProcess ON #Tmp_PMResultsToProcess (Conformer_ID, UMC_ResultDetails_ID)
		
	-----------------------------------------------------
	-- Create a temporary table to track details for each 
	-- new conformer that needs to be added
	-----------------------------------------------------
	--
	CREATE TABLE #Tmp_NewConformers (
		Conformer_ID int NOT NULL,
		Drift_Time real NOT NULL,
		Charge_State smallint NOT NULL,
		Mass_Tag_ID int NOT NULL,
		Conformer_ID_New int NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_NewConformers ON #Tmp_NewConformers (Conformer_ID)	
		
		
		
	-----------------------------------------------------
	--  Populate #Tmp_ConformerIDList with the conformer IDs to process
	-----------------------------------------------------
	
	If @ConformerIDFilterList <> ''
	Begin
		INSERT INTO #Tmp_ConformerIDList (Conformer_ID)
		SELECT Value
		FROM dbo.udfParseDelimitedIntegerList(@ConformerIDFilterList, ',')
	End
	Else
	Begin
		INSERT INTO #Tmp_ConformerIDList (Conformer_ID)
		SELECT Conformer_ID
		FROM T_Mass_Tag_Conformers_Observed
		
		SELECT @ConformerCountOld = COUNT(*) 
		FROM T_Mass_Tag_Conformers_Observed

	End
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-----------------------------------------------------
	-- Populate #Tmp_PMResultsToProcess with the observations for each conformer 
	-- that are more than @DriftTimeTolerance msec away from the drift time of the most abundant observation for that conformer
	-----------------------------------------------------
	--
	INSERT INTO #Tmp_PMResultsToProcess( Conformer_ID,
	                                     UMC_ResultDetails_ID,
	                                     Mass_Tag_ID,
	                                     Drift_Time,
	                                     Charge_State,
	                                     Class_Abundance )
	SELECT ObsQ.Conformer_ID,
	       ObsQ.UMC_ResultDetails_ID,
	       ObsQ.Mass_Tag_ID,
	       ObsQ.Drift_Time,
	       ObsQ.Charge_State,
	       ObsQ.Class_Abundance
	FROM ( SELECT Conformer_ID,
	              UMC_ResultDetails_ID,
	              Drift_Time,
	              AbundanceRank
	       FROM ( SELECT FURD.UMC_ResultDetails_ID,
	                     FURD.Conformer_ID,
	                     FUR.Drift_Time,
	                     FUR.Class_Abundance,
	                     FUR.Charge_State_MaxAbu,
	                     ROW_NUMBER() OVER ( PARTITION BY FURD.Conformer_ID ORDER BY FUR.Class_Abundance DESC ) AS AbundanceRank
	              FROM T_FTICR_UMC_ResultDetails FURD
	                   INNER JOIN T_FTICR_UMC_Results FUR
	                     ON FURD.UMC_Results_ID = FUR.UMC_Results_ID
	                   INNER JOIN #Tmp_ConformerIDList CIDs
	                     ON CIDs.Conformer_ID = FURD.Conformer_ID
	             ) LookupQ
	       WHERE AbundanceRank = 1 
	     ) BestObsQ
	     
	    INNER JOIN
            ( SELECT Conformer_ID,
	                UMC_ResultDetails_ID,
	                Mass_Tag_ID,
	                Drift_Time,
	                Class_Abundance,
	                Charge_State
	        FROM ( SELECT FURD.UMC_ResultDetails_ID,
	                    FURD.Conformer_ID,
	                    FURD.Mass_Tag_ID,
	                    FUR.Drift_Time,
	                    FUR.Class_Abundance,
	                    FUR.Charge_State_MaxAbu AS Charge_State,
	                    ROW_NUMBER() OVER ( PARTITION BY FURD.Conformer_ID ORDER BY FUR.Class_Abundance DESC ) AS AbundanceRank
	              FROM T_FTICR_UMC_ResultDetails FURD
	                   INNER JOIN T_FTICR_UMC_Results FUR
	                     ON FURD.UMC_Results_ID = FUR.UMC_Results_ID
	                   INNER JOIN #Tmp_ConformerIDList CIDs
	                     ON CIDs.Conformer_ID = FURD.Conformer_ID
	            ) LookupQ
	        WHERE AbundanceRank > 1 
	    ) ObsQ
	       ON BestObsQ.Conformer_ID = ObsQ.Conformer_ID
	WHERE ABS(BestObsQ.Drift_Time - ObsQ.Drift_Time) > @DriftTimeTolerance
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-----------------------------------------------------
	-- Process the data in #Tmp_PMResultsToProcess to create new conformers
	-----------------------------------------------------
	--
	Set @ContinueAddingNewConformers = 1
	While @ContinueAddingNewConformers = 1
	Begin -- <a1>

		TRUNCATE TABLE #Tmp_NewConformers

		-----------------------------------------------------
		-- Populate #Tmp_NewConformers with the drift time and charge of the 
		-- most abundant observation for each of the rows that 
		-- still have a null value for Conformer_ID_New in #Tmp_PMResultsToProcess
		--
		-- This will define the new conformers that need to be added to T_Mass_Tag_Conformers_Observed
		--
		-- When computing Max_Conformer, we group by Mass_Tag_ID and optionally by charge, then add 1
		-----------------------------------------------------
		--
		INSERT INTO #Tmp_NewConformers ( Conformer_ID,
		                                 Mass_Tag_ID,
		                                 Drift_Time,
		                                 Charge_State )
		SELECT ObsQ.Conformer_ID,
		       ObsQ.Mass_Tag_ID,
		       ObsQ.Drift_Time,
		       ObsQ.Charge_State
		FROM ( SELECT Conformer_ID,
		              UMC_ResultDetails_ID,
		              Mass_Tag_ID,
		              Drift_Time,
		              Charge_State,
		              Class_Abundance,
		              ROW_NUMBER() OVER ( PARTITION BY Conformer_ID ORDER BY Class_Abundance DESC ) AS AbundanceRank
		       FROM #Tmp_PMResultsToProcess
		       WHERE Conformer_ID_New IS NULL 
		       ) ObsQ
		WHERE ObsQ.AbundanceRank = 1
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		-----------------------------------------------------
		-- Process each row in #Tmp_NewConformers
		-----------------------------------------------------
		--
		Set @ConformerID = -1
		Set @Continue = 1
			
		While @Continue = 1
		Begin -- <b>
				SELECT TOP 1 @ConformerID = Conformer_ID,
				             @Charge = Charge_State,
				             @MassTagID = Mass_Tag_ID,
				             @DriftTime = Drift_Time
				FROM #Tmp_NewConformers
				WHERE Conformer_ID > @ConformerID
				ORDER BY Conformer_ID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @myRowCount = 0
					Set @Continue = 0
				Else
				Begin -- <c>
						
						If @InfoOnly = 0
						Begin
							Set @ConformerNumNew = 1
							
							SELECT @ConformerNumNew = MAX(Conformer) + 1
							FROM T_Mass_Tag_Conformers_Observed
							WHERE Mass_Tag_ID = @MassTagID AND 
							      (Charge = @Charge OR @MergeChargeStates > 0)
							
							
							INSERT INTO T_Mass_Tag_Conformers_Observed( Mass_Tag_ID,
																		Charge,
																		Conformer,
																		Drift_Time_Avg,
																		Obs_Count,
																		Last_Affected )
							VALUES(@MassTagID, @Charge, @ConformerNumNew, @DriftTime, 0, GetDate())
							--			    
							SELECT @myError = @@error, @myRowCount = @@rowcount, @ConformerIDNew = SCOPE_IDENTITY()
						    
							If @myError <> 0
							Begin
								Set @message = 'Error splitting conformer ' + Convert(varchar(12), @ConformerID) + ' to create a new conformer'
								Exec PostLogEntry 'Error', @message, 'AddConformersViaSplitting'
								Goto Done
							End
														
						End
						Else
						Begin
							Set @ConformerIDNew = @InfoOnlyConformerID
							Set @InfoOnlyConformerID = @InfoOnlyConformerID - 1
						End
						
						UPDATE #Tmp_NewConformers
						SET Conformer_ID_New = @ConformerIDNew
						WHERE Conformer_ID = @ConformerID
						
						INSERT INTO #Tmp_ConformerIDList (Conformer_ID)
						VALUES (@ConformerIDNew)
						
						If @InfoOnly = 0
						Begin
							UPDATE T_Mass_Tag_Conformers_Observed
							SET Last_Affected = GetDate()
							WHERE Conformer_ID = @ConformerID
						End
						
				End -- </c>

				
		End -- </b>


		-----------------------------------------------------
		-- Update #Tmp_PMResultsToProcess with the New Conformer IDs
		-----------------------------------------------------
		--
		UPDATE #Tmp_PMResultsToProcess
		SET Conformer_ID_New = NC.Conformer_ID_New
		FROM #Tmp_PMResultsToProcess PM
		     INNER JOIN #Tmp_NewConformers NC
		       ON PM.Conformer_ID = NC.Conformer_ID
		WHERE ABS(PM.Drift_Time - NC.Drift_Time) <= @DriftTimeTolerance AND
		  PM.Conformer_ID_New IS NULL
		--			    
		SELECT @myError = @@error, @myRowCount = @@rowcount, @ConformerIDNew = SCOPE_IDENTITY()

		-- Check whether we need to keep processing rows in #Tmp_PMResultsToProcess
		--
		If Not Exists (	SELECT * FROM #Tmp_PMResultsToProcess where Conformer_ID_New is null)
			Set @ContinueAddingNewConformers = 0

		If @InfoOnly <> 0
			SELECT *
			FROM #Tmp_NewConformers
			
	End -- </a1>


	If @InfoOnly = 0
	Begin -- <a2>
		-----------------------------------------------------
		-- Update T_FTICR_UMC_ResultDetails with the new conformer IDs
		-----------------------------------------------------
		--
		UPDATE T_FTICR_UMC_ResultDetails
		SET Conformer_ID = PM.Conformer_ID_New
		FROM T_FTICR_UMC_ResultDetails FURD
		     INNER JOIN #Tmp_PMResultsToProcess PM
		  ON FURD.UMC_ResultDetails_ID = PM.UMC_ResultDetails_ID
		--			    
		SELECT @myError = @@error, @myRowCount = @@rowcount
				
		-----------------------------------------------------
		-- Update Conformer_Max_Abundance in T_FTICR_UMC_ResultDetails
		-----------------------------------------------------
		--
		UPDATE T_FTICR_UMC_ResultDetails
		SET Conformer_Max_Abundance = CASE WHEN RankQ.AbundanceRank = 1 THEN 1 ELSE 0 END
		FROM T_FTICR_UMC_ResultDetails Target
		     INNER JOIN ( SELECT FURD.UMC_ResultDetails_ID,
		                         Row_Number() OVER ( PARTITION BY FUR.MD_ID, FURD.Conformer_ID 
		                                             ORDER BY Class_Abundance DESC, Drift_Time ) AS AbundanceRank
		                  FROM T_FTICR_UMC_ResultDetails FURD
		                       INNER JOIN T_FTICR_UMC_Results FUR
		                         ON FURD.UMC_Results_ID = FUR.UMC_Results_ID
		                       INNER JOIN #Tmp_ConformerIDList CIL
		                         ON FURD.Conformer_ID = CIL.Conformer_ID
		               ) RankQ
		       ON Target.UMC_ResultDetails_ID = RankQ.UMC_ResultDetails_ID
		--			    
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-----------------------------------------------------
		-- Update the stats in T_Mass_Tag_Conformers_Observed
		-- Note that Obs_Count only counts each AMT tag once per MD_ID;
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
			Set @message = 'Error updating stats in T_Mass_Tag_Conformers_Observed'
			Exec PostLogEntry 'Error', @message, 'AddConformersViaSplitting'
			Goto Done
		End

		If @ConformerIDFilterList = ''
		Begin
			-----------------------------------------------------
			-- Post a log entry since we just updated all of the conformers
			-----------------------------------------------------
			SELECT @ConformerCountNew = COUNT(*) 
			FROM T_Mass_Tag_Conformers_Observed
			
			Set @message = 'Split conformers based on observed drift times, using tolerance of +/-' + Convert(varchar(12), @DriftTimeTolerance) + ' msec'
			Set @message = @message + '; Conformer Count before split = ' + Convert(varchar(12), @ConformerCountOld)
			Set @message = @message + '; Conformer Count after split = ' + Convert(varchar(12), @ConformerCountNew)
			
			Exec PostLogEntry 'Normal', @message, 'AddConformersViaSplitting'
		End
	End -- </a2>
	Else
	Begin -- <a3>
		-----------------------------------------------------
		-- Preview the changes
		-----------------------------------------------------
		
		Select @myRowCount = COUNT(*)
		FROM #Tmp_ConformerIDList		

		-- Only show the detailed changes if processing fewer than 25 conformer IDs
		If @myRowCount < 25
		Begin

			SELECT MTCO.Conformer_ID,
					MTCO.Mass_Tag_ID,
					MTCO.Charge,
					MTCO.Conformer,
					MTCO.Drift_Time_Avg,
					MTCO.Drift_Time_StDev,
					MTCO.Obs_Count,
					UpdateQ.Conformer_ID_New,
					Convert(decimal(9,3), UpdateQ.Drift_Time_Avg) AS Drift_Time_Avg_New
				FROM ( SELECT LookupQ.Conformer_ID,
							IsNull(PM.Conformer_ID_New, LookupQ.Conformer_ID) AS Conformer_ID_New,
							Avg(LookupQ.Drift_Time) AS Drift_Time_Avg
					FROM ( SELECT FURD.UMC_ResultDetails_ID,
									FURD.Conformer_ID,
									FUR.Drift_Time
							FROM T_FTICR_UMC_ResultDetails FURD
								INNER JOIN T_FTICR_UMC_Results FUR
									ON FURD.UMC_Results_ID = FUR.UMC_Results_ID
								INNER JOIN #Tmp_ConformerIDList CIDs
									ON CIDs.Conformer_ID = FURD.Conformer_ID 
							) LookupQ
							LEFT OUTER JOIN #Tmp_PMResultsToProcess PM
							ON LookupQ.UMC_ResultDetails_ID = PM.UMC_ResultDetails_ID
					GROUP BY LookupQ.Conformer_ID, IsNull(PM.Conformer_ID_New, LookupQ.Conformer_ID) 
					) UpdateQ
				INNER JOIN T_Mass_Tag_Conformers_Observed MTCO
					ON UpdateQ.Conformer_ID = MTCO.Conformer_ID
				ORDER BY MTCO.Conformer_ID, UpdateQ.Drift_Time_Avg


				SELECT LookupQ.MD_ID,
					LookupQ.Charge_State_MaxAbu AS Charge_State,
					LookupQ.Conformer_ID,
					LookupQ.UMC_ResultDetails_ID,
					LookupQ.Drift_Time,
					LookupQ.Class_Abundance,
					LookupQ.AbundanceRank,
					LookupQ.Conformer_Max_Abundance,
					IsNull(PM.Conformer_ID_New, LookupQ.Conformer_ID) AS Conformer_ID_New
				FROM ( SELECT FUR.MD_ID,
							FURD.UMC_ResultDetails_ID,
							FURD.Conformer_ID,
							FUR.Drift_Time,
							FUR.Class_Abundance,
							FUR.Charge_State_MaxAbu,
							ROW_NUMBER() OVER ( PARTITION BY FURD.Conformer_ID ORDER BY FUR.Class_Abundance DESC ) AS AbundanceRank,
							FURD.Conformer_Max_Abundance
					FROM T_FTICR_UMC_ResultDetails FURD
							INNER JOIN T_FTICR_UMC_Results FUR
							ON FURD.UMC_Results_ID = FUR.UMC_Results_ID
							INNER JOIN #Tmp_ConformerIDList CIDs
							ON CIDs.Conformer_ID = FURD.Conformer_ID 
					) LookupQ
					LEFT OUTER JOIN #Tmp_PMResultsToProcess PM
					ON LookupQ.UMC_ResultDetails_ID = PM.UMC_ResultDetails_ID
				ORDER BY LookupQ.Conformer_ID, Drift_Time

		End
		Else
		Begin
			SELECT *
			FROM #Tmp_PMResultsToProcess
			ORDER BY Conformer_ID
		End
		
	End -- </a3>

		
Done:

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[AddConformersViaSplitting] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddConformersViaSplitting] TO [MTS_DB_Lite] AS [dbo]
GO

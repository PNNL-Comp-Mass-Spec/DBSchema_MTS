/****** Object:  StoredProcedure [dbo].[CheckFilterUsingCustomCriteria] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE CheckFilterUsingCustomCriteria
/****************************************************
** 
**	Desc:	Updates T_Peptide_Filter_Flags to only contain 
**			peptides that pass the given filters
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	09/17/2011
**			09/19/2011 mem - Removed T_Analysis_Description from #TmpPeptideIds Update Query since experiment and parameter file are validated prior to the update query
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@CustomFilterTableName varchar(128) = 'T_Custom_Peptide_Filter_Criteria',
	@FilterID int = 10,									-- Filter_ID to store in T_Analysis_Filter_Flags and T_Peptide_Filter_Flags
	@JobListFilter varchar(max),
	@InfoOnly tinyint = 0,
	@ShowSummaryStats tinyint = 1,						-- Auto-set to 1 if @InfoOnly=1
	@PostLogEntries tinyint = 1,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @Job int
	Declare @Experiment varchar(128)
	Declare @ParameterFile varchar(255)
	Declare @JobAvailable tinyint
	
	declare @ExperimentFilter varchar(128)
	declare @ParamFileFilter varchar(255)
	declare @ChargeState smallint
	declare @DeltaMassPPM real
	declare @XCorr real
	declare @DeltaCN2 real
	declare @ModSymbolFilter varchar(12)
	declare @MSGFSpecProb real
	declare @CleavageState smallint
	declare @EntryID int
	Declare @TestFilter tinyint
	
	Declare @ProtonMass float
	Set @ProtonMass = 1.007276
	
	Declare @Continue tinyint
	
	Declare @JobsProcessed int = 0
	Declare @RowCountDeleted int = 0
	Declare @RowCountAdded int = 0
	
	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	
	Set @CustomFilterTableName = IsNull(@CustomFilterTableName, '')
	Set @FilterID = IsNull(@FilterID, 10)
	Set @JobListFilter = IsNull(@JobListFilter, '')
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @message = ''

	If @FilterID >= 100
	Begin
		set @message = 'Error: @FilterID must be less than 100'
		If @InfoOnly = 0
		Begin
			If @PostLogEntries <> 0
				execute PostLogEntry 'Error', @message, 'CheckFilterUsingCustomCriteria'
		End
		Else
			SELECT @message as ErrorMessage
			
		Set @myError = 50000
		Goto Done
	End
	
	--------------------------------------------------------------
	-- Create a temporary table to hold the peptides that pass the filters for each job
	--------------------------------------------------------------

	CREATE TABLE #TmpJobsToProcess (
		Job int,
		Experiment varchar(128),
		Parameter_File_Name varchar(255)
	)
	
	CREATE CLUSTERED INDEX #IX_TmpJobsToProcess ON #TmpJobsToProcess (Job ASC)

	
	CREATE TABLE #TmpPeptideIds (
		Peptide_ID int NOT NULL,
		PassFilter tinyint NOT NULL
	)
	
	CREATE CLUSTERED INDEX #IX_TmpPeptideIds ON #TmpPeptideIds (Peptide_ID ASC)
	
	
	CREATE TABLE #TmpFilterScores (
		Entry_ID int, 
		ExperimentFilter varchar(128),			-- Like Clause text to match against Experiment name; use '%' to match all experiments
		ParamFileFilter varchar(255),			-- Empty means any parameter file; otherwise, a Like clause to compare to the Parameter_File_Name column in T_Analysis_Description
		ChargeState smallint,
		DeltaMassPPM real,
		XCorr real,
		DeltaCN2 real,
		ModSymbolFilter varchar(12),			-- Empty field means the criteria apply to any peptide; 'NoMods' means they only apply to peptides without a mod symbol; '*' means they only apply to peptides with a * in the residues
		MSGF_SpecProb real,
		CleavageState smallint,					-- Exact cleavage state to match; set to -1 to match all cleavage states
		TestCount int
	)
	
	--------------------------------------------------------------
	-- Populate #TmpFilterScores
	--------------------------------------------------------------

	Declare @S varchar(1024)
	
	If Not Exists (Select * from sys.Tables WHERE Name = @CustomFilterTableName)
	Begin
		Set @message = 'Custom filter table not found: ' + @CustomFilterTableName
		If @InfoOnly = 0
		Begin
			If @PostLogEntries <> 0
				execute PostLogEntry 'Error', @message, 'CheckFilterUsingCustomCriteria'
		End
		Else
			SELECT @message as ErrorMessage
			
		Set @myError = 50001
		Goto Done
	End
	
	Set @S = ''
	Set @S = @S + ' INSERT INTO #TmpFilterScores( Entry_ID, ExperimentFilter, ParamFileFilter,'
	Set @S = @S +			' ChargeState, DeltaMassPPM, XCorr,DeltaCN2,'
	Set @S = @S +			' ModSymbolFilter,MSGF_SpecProb,CleavageState, TestCount)'
	Set @S = @S + ' SELECT Entry_ID, ExperimentFilter, ParamFileFilter,'
	Set @S = @S +			' ChargeState, DeltaMassPPM, XCorr, DeltaCN2,'
	Set @S = @S +			' ModSymbolFilter, MSGF_SpecProb, CleavageState, 0 AS TestCount'
	Set @S = @S + ' FROM ' + @CustomFilterTableName
    Set @S = @S + ' ORDER BY Entry_ID'
    Exec (@S)
    
	--------------------------------------------------------------
    -- Populate #TmpJobsToProcess
    --------------------------------------------------------------
    
    If Len(@JobListFilter) > 0
    Begin
		INSERT INTO #TmpJobsToProcess (Job, Parameter_File_Name, Experiment)
		SELECT Job, Parameter_File_Name, Experiment
		FROM T_Analysis_Description TAD
		     INNER JOIN ( SELECT Value
		                  FROM dbo.udfParseDelimitedIntegerList ( @JobListFilter, ',' ) 
		                ) ValueQ
		       ON TAD.Job = ValueQ.Value
		ORDER BY TAD.Job
	End
    Else
    Begin
    	INSERT INTO #TmpJobsToProcess (Job, Parameter_File_Name, Experiment)
		SELECT Job, Parameter_File_Name, Experiment
		FROM T_Analysis_Description
		WHERE ResultType LIKE '%Peptide_Hit%'
		ORDER BY Job
	End
	
	--------------------------------------------------------------
	-- Process each job in #TmpJobsToProcess
	--------------------------------------------------------------
	
	Set @Job = 0
	SELECT @Job = Min(Job) - 1
	FROM #TmpJobsToProcess

	Set @JobAvailable = 1
	While @JobAvailable = 1
	Begin -- <a>
		SELECT TOP 1 @Job = Job,
					 @ParameterFile = Parameter_File_Name,
					 @Experiment = Experiment
		FROM #TmpJobsToProcess
		WHERE Job > @Job
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @JobAvailable = 0
		Else
		Begin -- <b>
		
			TRUNCATE TABLE #TmpPeptideIds
			
			--------------------------------------------------------------
			-- Populate #TmpPeptideIds
			--------------------------------------------------------------
			INSERT INTO #TmpPeptideIds (Peptide_ID, PassFilter)
			SELECT Peptide_ID, 0 As PassFilter
			FROM T_Peptides
			WHERE Job = @Job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		
			If @myRowCount = 0
			Begin
				Set @message = 'Warning: job ' + Convert(varchar(12), @Job) + ' does not have any entries in T_Peptides'
				
				If @InfoOnly = 0
				Begin
					If @PostLogEntries <> 0
							execute PostLogEntry 'Warning', @message, 'CheckFilterUsingCustomCriteria'
				End
				Else
					Print @message
				
				Set @message = ''
					
			End
			Else
			Begin -- <c1>
				--------------------------------------------------------------
				-- Loop through the entries in #TmpFilterScores
				--------------------------------------------------------------
				
				Set @EntryID = 0
				
				Set @Continue = 1
				While @Continue = 1
				Begin -- <d>
					SELECT TOP 1	@ExperimentFilter = ExperimentFilter,
									@ParamFileFilter = ParamFileFilter,
									@ChargeState = ChargeState,
									@DeltaMassPPM = DeltaMassPPM,
									@XCorr = XCorr,
									@DeltaCN2 = DeltaCN2,
									@ModSymbolFilter = ModSymbolFilter,
									@MSGFSpecProb = MSGF_SpecProb,
									@CleavageState = CleavageState,
									@EntryID = Entry_ID 
					FROM #TmpFilterScores
					WHERE Entry_ID > @EntryID
					ORDER BY Entry_ID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					If @myRowCount = 0
						Set @Continue = 0
					Else
					Begin -- <e>
					
						If IsNull(@ParamFileFilter, '') = ''
							Set @TestFilter = 1
						Else
						Begin
							If @ParameterFile LIKE @ParamFileFilter
								Set @TestFilter = 1
							Else
							Begin
								Set @TestFilter = 0
								If @InfoOnly <> 0
									Print 'Skip job ' + Convert(varchar(12), @Job) + ' against filter entry ' + Convert(varchar(12), @EntryID) + '; "' + @ParameterFile + '" Not Like "' + @ParamFileFilter + '"'
							End
						End
						
						If @TestFilter = 1
						Begin
							If IsNull(@ExperimentFilter, '') <> '' AND IsNull(@ExperimentFilter, '') <> '%'
								If NOT @Experiment LIKE @ExperimentFilter
								Begin
									Set @TestFilter = 0
									If @InfoOnly <> 0
										Print 'Skip job ' + Convert(varchar(12), @Job) + ' against filter entry ' + Convert(varchar(12), @EntryID) + '; "' + @Experiment + '" Not Like "' + @ExperimentFilter + '"'
								End
						End
													
						If @TestFilter = 1
						Begin -- <f>
						
							If @InfoOnly <> 0
								Print 'Test job ' + Convert(varchar(12), @Job) + ' against filter entry ' + Convert(varchar(12), @EntryID)
								
							UPDATE #TmpPeptideIds
							SET PassFilter = 1
							FROM #TmpPeptideIds 
								INNER JOIN (
									SELECT Peptide_ID
									FROM ( SELECT Pep.Peptide_ID, 
									              SS.DelM / (TS.Monoisotopic_Mass / 1e6) AS DelM_PPM
										FROM T_Peptides Pep
											INNER JOIN T_Sequence TS
												ON Pep.Seq_ID = TS.Seq_ID
											INNER JOIN T_Score_Sequest SS
												ON Pep.Peptide_ID = SS.Peptide_ID
											INNER JOIN T_Score_Discriminant SD
												ON Pep.Peptide_ID = SD.Peptide_ID
										WHERE   Pep.Charge_State = @ChargeState AND
												SS.XCorr >= @XCorr AND
												SS.DeltaCN2 >= @DeltaCN2 AND
												SD.MSGF_SpecProb < @MSGFSpecProb AND
												(@CleavageState < 0 Or TS.Cleavage_State_Max = @CleavageState) AND
												(
													(@ModSymbolFilter = '') OR 
													(@ModSymbolFilter = 'NoMods' And Not Pep.Peptide Like '%[*#@!$%^&]%') OR 
													(Len(@ModSymbolFilter) > 0 AND @ModSymbolFilter <> 'NoMods' And Pep.Peptide Like '%' + @ModSymbolFilter + '%') 
												)
										) LookupQ
									WHERE (ABS(DelM_PPM) <= @DeltaMassPPM) 
								) FilterQ ON #TmpPeptideIds.Peptide_ID = FilterQ.Peptide_ID
							WHERE #TmpPeptideIds.PassFilter = 0
          					--
							SELECT @myError = @@error, @myRowCount = @@rowcount
							
							UPDATE #TmpFilterScores
							SET TestCount = TestCount + 1
							WHERE Entry_ID = @EntryID
							
						End -- </f>

					End -- </e>

				End -- </d>
			
				Set @JobsProcessed = @JobsProcessed + 1
				
			End -- </c1>

			If @InfoOnly = 0
			Begin -- <c2>
				
				-- Delete extra entries from T_Peptide_Filter_Flags
				--
				DELETE T_Peptide_Filter_Flags
				FROM T_Peptide_Filter_Flags PFF
				     INNER JOIN #TmpPeptideIds Src
				       ON Src.Peptide_ID = PFF.Peptide_ID AND
				          PFF.Filter_ID = @FilterID
				WHERE Src.PassFilter = 0
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				Set @RowCountDeleted = @myRowCount


				-- Add missing rows to T_Peptide_Filter_Flags
				--
				INSERT INTO T_Peptide_Filter_Flags( Filter_ID,
				                                    Peptide_ID )
				SELECT @FilterID,
				       Src.Peptide_ID
				FROM #TmpPeptideIds Src
				     LEFT OUTER JOIN T_Peptide_Filter_Flags PFF
				       ON Src.Peptide_ID = PFF.Peptide_ID AND
				          PFF.Filter_ID = @FilterID
				WHERE Src.PassFilter = 1 AND
				      PFF.Filter_ID IS NULL
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				Set @RowCountAdded = @myRowCount

				-- Make sure T_Analysis_Filter_Flags is up-to-date
				IF NOT EXISTS (SELECT * FROM T_Analysis_Filter_Flags WHERE Job = @Job AND Filter_ID = @FilterID)
				Begin
					INSERT INTO T_Analysis_Filter_Flags (Filter_ID, Job) 
					VALUES (@FilterID, @Job)
				End
				

				Set @message = 'Updated values in T_Peptide_Filter_Flags for Job ' + Convert(varchar(12), @Job) + ' and filter ' + Convert(varchar(12), @FilterID)
				Set @message = @message + '; RowCountAdded = ' +   Convert(varchar(12), @RowCountAdded)
				Set @message = @message + '; RowCountDeleted = ' + Convert(varchar(12), @RowCountDeleted)		

				If @PostLogEntries <> 0
					execute PostLogEntry 'Normal', @message, 'CheckFilterUsingCustomCriteria'
				
			End -- </c2>
			Else
			Begin			
				SELECT @Job AS Job, PassFilter, COUNT(*) PeptideCount
				FROM #TmpPeptideIds
				GROUP BY PassFilter
			End
			
		End -- </b>
		
	End -- </a>


	
	If @InfoOnly <> 0 OR @ShowSummaryStats <> 0
	Begin
		-- Display the contents of #TmpFilterScores
		--
		SELECT *
		FROM #TmpFilterScores
		ORDER BY Entry_ID
	End
	
	If @InfoOnly =0
	Begin
		If @ShowSummaryStats <> 0
			Select @message As Message
	End
		
	
Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[CheckFilterUsingCustomCriteria] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckFilterUsingCustomCriteria] TO [MTS_DB_Lite] AS [dbo]
GO

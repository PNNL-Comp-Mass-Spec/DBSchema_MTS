/****** Object:  StoredProcedure [dbo].[DeletePeptidesForJobAndResetToNew] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE DeletePeptidesForJobAndResetToNew
/****************************************************
**
**	Desc: 
**		Deletes all peptides for the given job
**		If @ResetStateToNew = 1, then resets
**		  the job's state to 10 = new.
**		If @DeleteUnusedSequences = 1, then deletes
**		  sequences from T_Sequences that do not have
**		  corresponding entries in T_Peptides
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	08/07/2004
**			11/03/2004 mem - Added dropping of foreign keys to speed up the Delete Queries
**			12/20/2004 mem - Now clearing the GANET_RSquared column in T_Analysis_Description
**			01/03/2005 mem - Now also clearing SIC tables and SIC_Job from T_Datasets
**			08/15/2005 mem - Updated FK_T_Peptides_T_Sequence to not use 'ON UPDATE CASCADE'; added FK_T_Peptide_to_Protein_Map_T_Peptide_Terminus_State_Name
**			12/11/2005 mem - Now also clearing T_Score_XTandem; changed @DropAndAddConstraints to default to 0
**			01/15/2006 mem - Now also clearing T_Seq_Candidates, T_Seq_Candidate_ModDetails, and T_Seq_Candidate_to_Peptide_Map
**			02/14/2006 mem - Now pre-determining which jobs have entries in T_Peptides; if they don't have an entry in T_Peptides, then there is no need to try to delete entries from the tables with foreign keys to T_Peptides
**			07/03/2006 mem - Now clearing RowCount_Loaded in T_Analysis_Description
**			07/18/2006 mem - Updated the ALTER TABLE ADD CONSTRAINT queries to use WITH NOCHECK
**			08/26/2006 mem - Now also clearing T_NET_Update_Task_Job_Map and T_Peptide_Prophet_Task_Job_Map
**			09/05/2006 mem - Updated to use dbo.udfParseDelimitedList and to check for invalid job numbers
**						   - Now posting a log entry for the processed jobs
**			09/26/2006 mem - Updated to only post a log entry if data is actually deleted
**			11/27/2006 mem - Now dropping the foreign key to T_Peptide_State_Name
**			09/24/2008 mem - Updated to check for the existence of certain tables before attempting to access them
**			10/10/2008 mem - Added support for Inspect tables
**			03/17/2010 mem - Now clearing the NET Regression fields in T_Analysis_Description
**			03/11/2011 mem - Updated @JobListToDelete to varchar(max)
**			08/19/2011 mem - Tweaked log message
**			08/23/2011 mem - Now also clearing T_Score_MSGFDB
**			11/29/2011 mem - Now also clearing T_Peptide_ScanGroupInfo
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/04/2012 mem - Now also clearing T_Score_MSAlign and T_Seq_Candidate_ModSummary
**    
*****************************************************/
(
	@JobListToDelete varchar(max),			-- Comma separated list of jobs to delete
	@ResetStateToNew tinyint = 0,
	@DeleteUnusedSequences tinyint = 0,
	@DropAndAddConstraints tinyint = 0
)
AS
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @commaLoc int
	Declare @HasPeptidesThreshold tinyint
	
	Declare @Message varchar(512)
	Declare @JobListProcessed varchar(512)
	Set @JobListProcessed = ''
	
	Declare @NumJobsDeleted int = 0
	
	Declare @DataDeleted tinyint
	Set @DataDeleted = 0
	
	-- Create a temporary table to hold the jobs to delete
	CREATE TABLE #JobListToDelete (
		Job int NOT NULL ,
		HasPeptides tinyint NOT NULL DEFAULT (0) 			-- Will be 1 if the job has any peptides in T_Peptides and related tables; effectively ignored if @DropAndAddConstraints=1
	)

	CREATE CLUSTERED INDEX #IX_Tmp_JobListToDelete_Job ON #JobListToDelete (Job)

	-- Populate #JobListToDelete with the jobs in @JobListToDelete
	INSERT INTO #JobListToDelete (Job)
	SELECT value
	FROM dbo.udfParseDelimitedList(@JobListToDelete, ',')
	ORDER BY value
	
	-- Look for jobs not present in T_Analysis_Description
	Set @JobListProcessed = ''
	SELECT @JobListProcessed = @JobListProcessed + Convert(varchar(12), JL.Job) + ','
	FROM #JobListToDelete JL LEFT OUTER JOIN
		 T_Analysis_Description TAD ON JL.Job = TAD.Job
	WHERE TAD.Job Is Null
	ORDER BY JL.Job
	
	If Len(IsNull(@JobListProcessed, '')) > 0
	Begin
		Set @Message = 'Warning, invalid jobs specified: ' + left(@JobListProcessed, Len(@JobListProcessed)-1)		
		SELECT @Message AS Message
		Print @Message

		Set @Message = ''
		
		-- Delete the invalid jobs
		DELETE #JobListToDelete
		FROM #JobListToDelete JL LEFT OUTER JOIN
			T_Analysis_Description TAD ON JL.Job = TAD.Job
		WHERE TAD.Job Is Null
	End

	-- Update @JobListProcessed with the list of valid jobs
	Set @JobListProcessed = ''
	SELECT @JobListProcessed = @JobListProcessed + Convert(varchar(12), Job) + ', '
	FROM #JobListToDelete
	ORDER BY Job	

	If Len(IsNull(@JobListProcessed, '')) = 0
	Begin
		Set @Message = 'Error: no valid jobs were found'

		SELECT @Message AS Message
		Print @Message

		Goto Done
	End
	
	-- Remove the trailing comma from @JobListProcessed
	Set @JobListProcessed = left(@JobListProcessed, Len(@JobListProcessed)-1)

	If @DropAndAddConstraints = 0
		Set @HasPeptidesThreshold = 1
	Else
	Begin
		ALTER TABLE dbo.T_Peptides
			DROP CONSTRAINT FK_T_Peptides_T_Sequence
		ALTER TABLE dbo.T_Peptides
			DROP CONSTRAINT FK_T_Peptides_T_Analysis_Description
		ALTER TABLE dbo.T_Peptides
			DROP CONSTRAINT FK_T_Peptides_T_Peptide_State_Name
			
		If Exists (select * from sys.tables where name = 'T_Peptide_Filter_Flags')
			ALTER TABLE dbo.T_Peptide_Filter_Flags
				DROP CONSTRAINT FK_T_Peptide_Filter_Flags_T_Peptides
			
		ALTER TABLE dbo.T_Score_Discriminant
			DROP CONSTRAINT FK_T_Score_Discriminant_T_Peptides
		ALTER TABLE dbo.T_Score_Sequest
			DROP CONSTRAINT FK_T_Score_Sequest_T_Peptides
		ALTER TABLE dbo.T_Score_XTandem
			DROP CONSTRAINT FK_T_Score_XTandem_T_Peptides
		ALTER TABLE dbo.T_Score_Inspect
			DROP CONSTRAINT FK_T_Score_Inspect_T_Peptides
		ALTER TABLE dbo.T_Score_MSGFDB
			DROP CONSTRAINT FK_T_Score_MSGFDB_T_Peptides		
		ALTER TABLE dbo.T_Score_MSAlign
			DROP CONSTRAINT FK_T_Score_MSAlign_T_Peptides
			
		ALTER TABLE dbo.T_Peptide_ScanGroupInfo
			DROP CONSTRAINT FK_T_Peptide_ScanGroupInfo_T_Analysis_Description
			
		ALTER TABLE dbo.T_Seq_Candidate_to_Peptide_Map
			DROP CONSTRAINT FK_T_Seq_Candidate_to_Peptide_Map_T_Peptides
			
		ALTER TABLE dbo.T_Peptide_to_Protein_Map
			DROP CONSTRAINT FK_T_Peptide_to_Protein_Map_T_Peptides
		ALTER TABLE dbo.T_Peptide_to_Protein_Map
			DROP CONSTRAINT FK_T_Peptide_to_Protein_Map_T_Peptide_Cleavage_State_Name
		ALTER TABLE dbo.T_Peptide_to_Protein_Map
			DROP CONSTRAINT FK_T_Peptide_to_Protein_Map_T_Peptide_Terminus_State_Name
		ALTER TABLE dbo.T_Peptide_to_Protein_Map
			DROP CONSTRAINT FK_T_Peptide_to_Protein_Map_T_Proteins
			
		ALTER TABLE dbo.T_Dataset_Stats_Scans
			DROP CONSTRAINT FK_T_Dataset_Stats_Scans_T_Analysis_Description
		ALTER TABLE dbo.T_Dataset_Stats_Scans
			DROP CONSTRAINT FK_T_Dataset_Stats_Scans_T_Dataset_Scan_Type_Name
		ALTER TABLE dbo.T_Dataset_Stats_SIC
			DROP CONSTRAINT FK_T_Dataset_Stats_SIC_T_Analysis_Description

		Set @HasPeptidesThreshold = 0
	End
		
	-- Mark jobs in #JobListToDelete that have at least one entry in T_Peptides
	-- For jobs that do not have any entries in T_Peptides, we do not need to try to delete entries from the tables with foreign keys to T_Peptides
	UPDATE #JobListToDelete
	SET HasPeptides = 1
	FROM #JobListToDelete JobList INNER JOIN
		  (	SELECT DISTINCT JobList.Job
			FROM #JobListToDelete JobList INNER JOIN
				 T_Peptides P ON JobList.Job = P.Job
		  ) LookupQ ON JobList.Job = LookupQ.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	DELETE T_Score_Sequest
	FROM T_Peptides P INNER JOIN 
		 T_Score_Sequest SS ON P.Peptide_ID = SS.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1
	
	DELETE T_Score_XTandem
	FROM T_Peptides P INNER JOIN 
		 T_Score_XTandem XT ON P.Peptide_ID = XT.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	DELETE T_Score_Inspect
	FROM T_Peptides P INNER JOIN 
		 T_Score_Inspect Ins ON P.Peptide_ID = Ins.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	DELETE T_Score_MSGFDB
	FROM T_Peptides P INNER JOIN 
		 T_Score_MSGFDB M ON P.Peptide_ID = M.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	DELETE T_Peptide_ScanGroupInfo
	FROM T_Peptide_ScanGroupInfo SGI INNER JOIN 
	     #JobListToDelete JobList ON SGI.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	DELETE T_Score_MSAlign
	FROM T_Peptides P INNER JOIN 
		 T_Score_MSAlign M ON P.Peptide_ID = M.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1
	
	DELETE T_Score_Discriminant
	FROM T_Peptides P INNER JOIN
		 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	DELETE T_Peptide_to_Protein_Map
	FROM T_Peptides P INNER JOIN 
		 T_Peptide_to_Protein_Map PPM ON P.Peptide_ID = PPM.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	If Exists (select * from sys.tables where name = 'T_Peptide_Filter_Flags')
	Begin
		DELETE T_Peptide_Filter_Flags
		FROM T_Peptides P INNER JOIN
			T_Peptide_Filter_Flags PFF ON P.Peptide_ID = PFF.Peptide_ID INNER JOIN
			#JobListToDelete JobList ON P.Job = JobList.Job
		WHERE JobList.HasPeptides >= @HasPeptidesThreshold
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto DefineConstraints
		If @myRowCount <> 0 Set @DataDeleted = 1
	End
	
	DELETE T_Seq_Candidate_to_Peptide_Map
	FROM T_Seq_Candidate_to_Peptide_Map SCPM INNER JOIN
		 #JobListToDelete JobList ON SCPM.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1
	
	DELETE T_Seq_Candidate_ModDetails
	FROM T_Seq_Candidate_ModDetails SCMD INNER JOIN
		 #JobListToDelete JobList ON SCMD.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
    --
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1
    
	DELETE T_Seq_Candidates
	FROM T_Seq_Candidates SC INNER JOIN 
		 #JobListToDelete JobList ON SC.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
    --
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	DELETE T_Seq_Candidate_ModSummary
	FROM T_Seq_Candidate_ModSummary SC INNER JOIN 
		 #JobListToDelete JobList ON SC.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
    --
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1
			
	DELETE T_Peptides
	FROM T_Peptides P INNER JOIN 
		 #JobListToDelete JobList ON P.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	If @DeleteUnusedSequences <> 0
	Begin
		DELETE T_Sequence
		FROM T_Sequence S LEFT OUTER JOIN
			T_Peptides P ON S.Seq_ID = P.Seq_ID
		WHERE P.Seq_ID IS NULL
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto DefineConstraints
		If @myRowCount <> 0 Set @DataDeleted = 1
	End


	If Exists (select * from sys.tables where name = 'T_Analysis_Filter_Flags')
	Begin
		DELETE T_Analysis_Filter_Flags
		FROM T_Analysis_Description TAD INNER JOIN
			T_Analysis_Filter_Flags AFF ON TAD.Job = AFF.Job INNER JOIN
			#JobListToDelete JobList ON TAD.Job = JobList.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto DefineConstraints
		If @myRowCount <> 0 Set @DataDeleted = 1
	End
	
	If Exists (select * from sys.tables where name = 'T_NET_Update_Task_Job_Map')
	Begin
		DELETE T_NET_Update_Task_Job_Map
		FROM T_NET_Update_Task_Job_Map TJM INNER JOIN
			#JobListToDelete JobList ON TJM.Job = JobList.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto DefineConstraints
		If @myRowCount <> 0 Set @DataDeleted = 1
	End

	If Exists (select * from sys.tables where name = 'T_Peptide_Prophet_Task_Job_Map')
	Begin
		DELETE T_Peptide_Prophet_Task_Job_Map
		FROM T_Peptide_Prophet_Task_Job_Map TJM INNER JOIN
			#JobListToDelete JobList ON TJM.Job = JobList.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto DefineConstraints
		If @myRowCount <> 0 Set @DataDeleted = 1
	End
	
	DELETE T_Dataset_Stats_Scans
	FROM T_Analysis_Description TAD INNER JOIN
		 T_Dataset_Stats_Scans DSS ON TAD.Job = DSS.Job INNER JOIN
		 #JobListToDelete JobList ON TAD.Job = JobList.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	DELETE T_Dataset_Stats_SIC
	FROM T_Analysis_Description TAD INNER JOIN
		 T_Dataset_Stats_SIC DSSIC ON TAD.Job = DSSIC.Job INNER JOIN
		 #JobListToDelete JobList ON TAD.Job = JobList.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1

	UPDATE T_Datasets
	SET SIC_Job = Null
	WHERE SIC_Job IN (SELECT Job FROM #JobListToDelete)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	If @myRowCount <> 0 Set @DataDeleted = 1
	
	
	SELECT @NumJobsDeleted = COUNT(*)
	FROM #JobListToDelete
	

	-- Prepare the log message
	If @NumJobsDeleted = 1
		Set @message = 'Deleted data for job ' + @JobListProcessed
	Else
		Set @message = 'Deleted data for jobs ' + @JobListProcessed

	If Len(@message) > 475
	Begin
		-- Find the next comma after position 475
		Set @commaLoc = CharIndex(',', @Message, 475)
		Set @message = Left(@message, @commaLoc) + '...'
	End
	
	If @ResetStateToNew <> 0
	Begin
		UPDATE T_Analysis_Description
		SET Process_State = 10, Last_Affected = GetDate(),
			-- GANET_Fit = NULL, GANET_Slope = NULL, GANET_Intercept = NULL, GANET_RSquared = NULL,
			RowCount_Loaded = NULL,
			ScanTime_NET_Slope = NULL, ScanTime_NET_Intercept = NULL, 
            ScanTime_NET_RSquared = NULL, ScanTime_NET_Fit = NULL,
            Regression_Order = NULL, Regression_Filtered_Data_Count = NULL,
            Regression_Equation = NULL, Regression_Equation_XML = NULL
		FROM T_Analysis_Description TAD INNER JOIN 
			 #JobListToDelete JobList ON TAD.Job = JobList.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto DefineConstraints
		
		Set @message = @message + '; Job states have been reset to 10'
	End

	If @DataDeleted <> 0
	Begin
		exec PostLogEntry 'Normal', @message, 'DeletePeptidesForJobAndResetToNew'
		SELECT @message
	End
	
DefineConstraints:
	If @DropAndAddConstraints = 1
	Begin
		ALTER TABLE dbo.T_Peptide_Filter_Flags WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptide_Filter_Flags_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Peptide_to_Protein_Map WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptide_to_Protein_Map_T_Proteins FOREIGN KEY(Ref_ID) REFERENCES dbo.T_Proteins(Ref_ID)
		ALTER TABLE dbo.T_Peptide_to_Protein_Map WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptide_to_Protein_Map_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Peptide_to_Protein_Map WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptide_to_Protein_Map_T_Peptide_Cleavage_State_Name FOREIGN KEY(Cleavage_State) REFERENCES dbo.T_Peptide_Cleavage_State_Name(Cleavage_State)
		ALTER TABLE dbo.T_Peptide_to_Protein_Map WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptide_to_Protein_Map_T_Peptide_Terminus_State_Name FOREIGN KEY(Terminus_State) REFERENCES dbo.T_Peptide_Terminus_State_Name(Terminus_State)
					
		ALTER TABLE dbo.T_Peptides WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptides_T_Analysis_Description FOREIGN KEY(Job) REFERENCES dbo.T_Analysis_Description(Job)
		ALTER TABLE dbo.T_Peptides WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptides_T_Sequence FOREIGN KEY(Seq_ID) REFERENCES dbo.T_Sequence(Seq_ID)
		ALTER TABLE dbo.T_Peptides WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptides_T_Peptide_State_Name FOREIGN KEY(State_ID) REFERENCES dbo.T_Peptide_State_Name(State_ID)
			
		ALTER TABLE dbo.T_Score_Discriminant WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_Discriminant_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Score_Sequest WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_Sequest_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Score_XTandem WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_XTandem_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Score_Inspect WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_Inspect_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Score_MSGFDB WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_MSGFDB_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Score_MSAlign WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_MSAlign_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
			
		ALTER TABLE dbo.T_Peptide_ScanGroupInfo WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptide_ScanGroupInfo_T_Analysis_Description FOREIGN KEY(Job) REFERENCES dbo.T_Analysis_Description(Job)

		ALTER TABLE dbo.T_Seq_Candidate_to_Peptide_Map WITH NOCHECK
			ADD CONSTRAINT FK_T_Seq_Candidate_to_Peptide_Map_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides (Peptide_ID)

		ALTER TABLE dbo.T_Dataset_Stats_Scans WITH NOCHECK
			ADD CONSTRAINT FK_T_Dataset_Stats_Scans_T_Analysis_Description FOREIGN KEY(Job) REFERENCES dbo.T_Analysis_Description(Job)
		ALTER TABLE dbo.T_Dataset_Stats_Scans WITH NOCHECK
			ADD CONSTRAINT FK_T_Dataset_Stats_Scans_T_Dataset_Scan_Type_Name FOREIGN KEY(Scan_Type) REFERENCES dbo.T_Dataset_Scan_Type_Name(Scan_Type)
		ALTER TABLE dbo.T_Dataset_Stats_SIC WITH NOCHECK
			ADD CONSTRAINT FK_T_Dataset_Stats_SIC_T_Analysis_Description FOREIGN KEY(Job) REFERENCES dbo.T_Analysis_Description(Job)
	End

Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[DeletePeptidesForJobAndResetToNew] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[DeletePeptidesForJobAndResetToNew] TO [MTS_DB_Lite] AS [dbo]
GO

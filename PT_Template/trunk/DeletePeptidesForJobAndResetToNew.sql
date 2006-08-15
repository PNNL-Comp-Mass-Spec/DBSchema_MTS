/****** Object:  StoredProcedure [dbo].[DeletePeptidesForJobAndResetToNew] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.DeletePeptidesForJobAndResetToNew
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
**    
*****************************************************/
(
	@JobListToDelete varchar(4096),			-- Comma separated list of jobs to delete
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
	Declare @jobStr varchar(255)
	Declare @HasPeptidesThreshold tinyint
	
	-- Populate a temporary table with the list of jobs in @JobListToDelete
	CREATE TABLE #JobListToDelete (
		Job int NOT NULL ,
		HasPeptides tinyint NOT NULL DEFAULT (0) 			-- Will be 1 if the job has any peptides in T_Peptides and related tables; effectively ignored if @DropAndAddConstraints=1
	)

	CREATE CLUSTERED INDEX #IX_Tmp_JobListToDelete_Job ON #JobListToDelete (Job)

	-- Append a comma to @JobListToDelete
	Set @JobListToDelete = LTrim(RTrim(@JobListToDelete)) + ','
	
	Set @commaLoc = 1
	While @commaLoc > 0
	Begin
		Set @commaLoc = CharIndex(',', @JobListToDelete)
		
		If @commaLoc > 0
		Begin
			Set @jobStr = SubString(@JobListToDelete, 1, @commaLoc-1)
			Set @JobListToDelete = LTrim(RTrim(SubString(@JobListToDelete, @commaLoc+1, Len(@JobListToDelete) - @commaLoc)))
		
			INSERT INTO #JobListToDelete (Job)
			SELECT Convert(int, @jobStr)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--

		End
	End

	If @DropAndAddConstraints = 0
		Set @HasPeptidesThreshold = 1
	Else
	Begin
		ALTER TABLE dbo.T_Peptides
			DROP CONSTRAINT FK_T_Peptides_T_Sequence
		ALTER TABLE dbo.T_Peptides
			DROP CONSTRAINT FK_T_Peptides_T_Analysis_Description
		ALTER TABLE dbo.T_Peptide_Filter_Flags
			DROP CONSTRAINT FK_T_Peptide_Filter_Flags_T_Peptides
		ALTER TABLE dbo.T_Score_Discriminant
			DROP CONSTRAINT FK_T_Score_Discriminant_T_Peptides
		ALTER TABLE dbo.T_Score_Sequest
			DROP CONSTRAINT FK_T_Score_Sequest_T_Peptides
		ALTER TABLE dbo.T_Score_XTandem
			DROP CONSTRAINT FK_T_Score_XTandem_T_Peptides
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
				 T_Peptides P ON JobList.Job = P.Analysis_ID
		  ) LookupQ ON JobList.Job = LookupQ.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	DELETE T_Score_Sequest
	FROM T_Peptides P INNER JOIN 
		 T_Score_Sequest SS ON P.Peptide_ID = SS.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Analysis_ID = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints

	DELETE T_Score_XTandem
	FROM T_Peptides P INNER JOIN 
		 T_Score_XTandem XT ON P.Peptide_ID = XT.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Analysis_ID = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints

	DELETE T_Score_Discriminant
	FROM T_Peptides P INNER JOIN
		 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Analysis_ID = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints


	DELETE T_Peptide_to_Protein_Map
	FROM T_Peptides P INNER JOIN 
		 T_Peptide_to_Protein_Map PPM ON P.Peptide_ID = PPM.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Analysis_ID = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints


	DELETE T_Peptide_Filter_Flags
	FROM T_Peptides P INNER JOIN
		 T_Peptide_Filter_Flags PFF ON P.Peptide_ID = PFF.Peptide_ID INNER JOIN
		 #JobListToDelete JobList ON P.Analysis_ID = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	

	DELETE T_Seq_Candidate_to_Peptide_Map
	FROM T_Seq_Candidate_to_Peptide_Map SCPM INNER JOIN
		 #JobListToDelete JobList ON SCPM.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	
	
	DELETE T_Seq_Candidate_ModDetails
	FROM T_Seq_Candidate_ModDetails SCMD INNER JOIN
		 #JobListToDelete JobList ON SCMD.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
    --
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
		 
    
	DELETE T_Seq_Candidates
	FROM T_Seq_Candidates SC INNER JOIN 
		 #JobListToDelete JobList ON SC.Job = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
    --
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints

	
	DELETE T_Peptides
	FROM T_Peptides P INNER JOIN 
		 #JobListToDelete JobList ON P.Analysis_ID = JobList.Job
	WHERE JobList.HasPeptides >= @HasPeptidesThreshold
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints


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
	End


	DELETE T_Analysis_Filter_Flags
	FROM T_Analysis_Description TAD INNER JOIN
		 T_Analysis_Filter_Flags AFF ON TAD.Job = AFF.Job INNER JOIN
		 #JobListToDelete JobList ON TAD.Job = JobList.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints


	DELETE T_Dataset_Stats_Scans
	FROM T_Analysis_Description TAD INNER JOIN
		 T_Dataset_Stats_Scans DSS ON TAD.Job = DSS.Job INNER JOIN
		 #JobListToDelete JobList ON TAD.Job = JobList.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints


	DELETE T_Dataset_Stats_SIC
	FROM T_Analysis_Description TAD INNER JOIN
		 T_Dataset_Stats_SIC DSSIC ON TAD.Job = DSSIC.Job INNER JOIN
		 #JobListToDelete JobList ON TAD.Job = JobList.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints


	UPDATE T_Datasets
	SET SIC_Job = Null
	WHERE SIC_Job IN (SELECT Job FROM #JobListToDelete)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto DefineConstraints
	

	If @ResetStateToNew <> 0
	Begin
		UPDATE T_Analysis_Description
		SET Process_State = 10, Last_Affected = GetDate(),
			GANET_Fit = NULL, GANET_Slope = NULL, GANET_Intercept = NULL, GANET_RSquared = NULL,
			RowCount_Loaded = NULL
		FROM T_Analysis_Description TAD INNER JOIN 
			 #JobListToDelete JobList ON TAD.Job = JobList.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto DefineConstraints
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
			ADD CONSTRAINT FK_T_Peptides_T_Analysis_Description FOREIGN KEY(Analysis_ID) REFERENCES dbo.T_Analysis_Description(Job)
		ALTER TABLE dbo.T_Peptides WITH NOCHECK
			ADD CONSTRAINT FK_T_Peptides_T_Sequence FOREIGN KEY(Seq_ID) REFERENCES dbo.T_Sequence(Seq_ID)
		ALTER TABLE dbo.T_Score_Discriminant WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_Discriminant_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Score_Sequest WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_Sequest_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
		ALTER TABLE dbo.T_Score_XTandem WITH NOCHECK
			ADD CONSTRAINT FK_T_Score_XTandem_T_Peptides FOREIGN KEY(Peptide_ID) REFERENCES dbo.T_Peptides(Peptide_ID)
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

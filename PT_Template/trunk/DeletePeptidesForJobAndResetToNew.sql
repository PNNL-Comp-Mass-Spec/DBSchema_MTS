SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DeletePeptidesForJobAndResetToNew]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[DeletePeptidesForJobAndResetToNew]
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
**		Auth: mem
**		Date: 08/07/2004
**			  11/03/2004 mem - Added dropping of foreign keys to speed up the Delete Queries
**			  12/20/2004 mem - Now clearing the GANET_RSquared column in T_Analysis_Description
**			  01/03/2005 mem - Now also clearing SIC tables and SIC_Job from T_Datasets
**			  08/15/2005 mem - Updated FK_T_Peptides_T_Sequence to not use 'ON UPDATE CASCADE'; added FK_T_Peptide_to_Protein_Map_T_Peptide_Terminus_State_Name
**    
*****************************************************/
	@JobListToDelete varchar(4096),			-- Comma separated list of jobs to delete
	@ResetStateToNew tinyint = 0,
	@DeleteUnusedSequences tinyint = 0,
	@DropAndAddConstraints tinyint = 1
AS
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	Declare @commaLoc int
	Declare @jobStr varchar(255)
	
	-- Populate a temporary table with the list of jobs in @JobListToDelete
	
	CREATE TABLE #JobListToDelete (
		[Job] int NOT NULL
	) ON [PRIMARY]

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

	If @DropAndAddConstraints = 1
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

	End
	
	DELETE T_Score_Sequest
	FROM T_Peptides INNER JOIN T_Score_Sequest 
		 ON T_Peptides.Peptide_ID = T_Score_Sequest.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Analysis_ID = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done


	DELETE T_Score_Discriminant
	FROM T_Peptides INNER JOIN T_Score_Discriminant 
		 ON T_Peptides.Peptide_ID = T_Score_Discriminant.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Analysis_ID = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done


	DELETE T_Peptide_to_Protein_Map
	FROM T_Peptides INNER JOIN T_Peptide_to_Protein_Map 
		 ON T_Peptides.Peptide_ID = T_Peptide_to_Protein_Map.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Analysis_ID = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done


	DELETE T_Peptide_Filter_Flags
	FROM T_Peptides INNER JOIN T_Peptide_Filter_Flags
		 ON T_Peptides.Peptide_ID = T_Peptide_Filter_Flags.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Analysis_ID = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done
	

	DELETE T_Peptides
	FROM T_Peptides INNER JOIN #JobListToDelete ON T_Peptides.Analysis_ID = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done


	If @DeleteUnusedSequences <> 0
	Begin
		DELETE T_Sequence
		FROM T_Sequence LEFT OUTER JOIN
			T_Peptides ON T_Sequence.Seq_ID = T_Peptides.Seq_ID
		WHERE T_Peptides.Seq_ID IS NULL
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto Done
	End


	DELETE T_Analysis_Filter_Flags
	FROM T_Analysis_Description INNER JOIN
		T_Analysis_Filter_Flags ON 
		T_Analysis_Description.Job = T_Analysis_Filter_Flags.Job
		INNER JOIN #JobListToDelete ON T_Analysis_Description.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done


	DELETE T_Dataset_Stats_Scans
	FROM T_Analysis_Description INNER JOIN
		T_Dataset_Stats_Scans ON 
		T_Analysis_Description.Job = T_Dataset_Stats_Scans.Job
		INNER JOIN #JobListToDelete ON T_Analysis_Description.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done


	DELETE T_Dataset_Stats_SIC
	FROM T_Analysis_Description INNER JOIN
		T_Dataset_Stats_SIC ON 
		T_Analysis_Description.Job = T_Dataset_Stats_SIC.Job
		INNER JOIN #JobListToDelete ON T_Analysis_Description.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done


	UPDATE T_Datasets
	SET SIC_Job = Null
	WHERE SIC_Job IN (SELECT Job FROM #JobListToDelete)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done
	

	If @ResetStateToNew <> 0
	Begin
		UPDATE T_Analysis_Description
		SET Process_State = 10, Last_Affected = GetDate(),
			GANET_Fit = NULL, GANET_Slope = NULL, GANET_Intercept = NULL, GANET_RSquared = NULL
		FROM T_Analysis_Description INNER JOIN #JobListToDelete ON T_Analysis_Description.Job = #JobListToDelete.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto Done
	End

	if @DropAndAddConstraints = 1
	Begin
		alter table dbo.T_Peptide_Filter_Flags
			add constraint FK_T_Peptide_Filter_Flags_T_Peptides foreign key(Peptide_ID) references dbo.T_Peptides(Peptide_ID)
		alter table dbo.T_Peptide_to_Protein_Map
			add constraint FK_T_Peptide_to_Protein_Map_T_Proteins foreign key(Ref_ID) references dbo.T_Proteins(Ref_ID)
		alter table dbo.T_Peptide_to_Protein_Map
			add constraint FK_T_Peptide_to_Protein_Map_T_Peptides foreign key(Peptide_ID) references dbo.T_Peptides(Peptide_ID)
		alter table dbo.T_Peptide_to_Protein_Map
			add constraint FK_T_Peptide_to_Protein_Map_T_Peptide_Cleavage_State_Name foreign key(Cleavage_State) references dbo.T_Peptide_Cleavage_State_Name(Cleavage_State)
		alter table dbo.T_Peptide_to_Protein_Map
			add constraint FK_T_Peptide_to_Protein_Map_T_Peptide_Terminus_State_Name foreign key(Terminus_State) references dbo.T_Peptide_Terminus_State_Name(Terminus_State)
	
		alter table dbo.T_Peptides
			add constraint FK_T_Peptides_T_Analysis_Description foreign key(Analysis_ID) references dbo.T_Analysis_Description(Job)
		alter table dbo.T_Peptides
			add constraint FK_T_Peptides_T_Sequence foreign key(Seq_ID) references dbo.T_Sequence(Seq_ID)
		alter table dbo.T_Score_Discriminant
			add constraint FK_T_Score_Discriminant_T_Peptides foreign key(Peptide_ID) references dbo.T_Peptides(Peptide_ID)
		alter table dbo.T_Score_Sequest
			add constraint FK_T_Score_Sequest_T_Peptides foreign key(Peptide_ID) references dbo.T_Peptides(Peptide_ID)

		ALTER TABLE dbo.T_Dataset_Stats_Scans
			ADD CONSTRAINT FK_T_Dataset_Stats_Scans_T_Analysis_Description foreign key(Job) references dbo.T_Analysis_Description(Job)
		ALTER TABLE dbo.T_Dataset_Stats_Scans
			ADD CONSTRAINT FK_T_Dataset_Stats_Scans_T_Dataset_Scan_Type_Name foreign key(Scan_Type) references dbo.T_Dataset_Scan_Type_Name(Scan_Type)
		ALTER TABLE dbo.T_Dataset_Stats_SIC
			ADD CONSTRAINT FK_T_Dataset_Stats_SIC_T_Analysis_Description foreign key(Job) references dbo.T_Analysis_Description(Job)

	End

Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


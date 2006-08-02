SET QUOTED_IDENTIFIER OFF 
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
**		  the job's state to 1 = new.
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 09/21/2004
**			  12/14/2004 mem - Now accepts a list of jobs to delete and reset
**    
*****************************************************/
	@JobListToDelete varchar(4096),
	@ResetStateToNew tinyint = 0
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

	DELETE T_Peptides 
	FROM T_Peptides
		 INNER JOIN #JobListToDelete ON T_Peptides.Analysis_ID = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done

	-- Update T_Mass_Tags.Number_of_Peptides and .High_Normalized_Score, if necessary
	If @myRowCount > 0
		Exec ComputeMassTagsAnalysisCounts


	If @ResetStateToNew <> 0
	Begin
		UPDATE T_Analysis_Description
		SET State = 1
		FROM T_Analysis_Description
			 INNER JOIN #JobListToDelete ON T_Analysis_Description.Job = #JobListToDelete.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto Done
	End


Done:
	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


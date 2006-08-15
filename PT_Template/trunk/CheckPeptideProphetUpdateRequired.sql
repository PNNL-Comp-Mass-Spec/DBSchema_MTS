/****** Object:  StoredProcedure [dbo].[CheckPeptideProphetUpdateRequired] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.CheckPeptideProphetUpdateRequired
/****************************************************
**
**	Desc: Looks for jobs for which peptide prophet processing can be skipped
**		  Advances their state to @NextProcessState
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/05/2006
**    
*****************************************************/
(
	@ProcessStateMatch int = 90,						-- Ignored if @JobFilter = 1
	@NextProcessState int = 60,
	@message varchar(255) = '' OUTPUT,
	@JobFilter int = 0,									-- Set to a non-zero number to only check the given job
	@JobAdvancedToNextState tinyint = 0 OUTPUT			-- Set to 1 if one or more jobs are advanced to state @NextProcessState
)
As

	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	-----------------------------------------------
	-- Validate @JobFilter
	-----------------------------------------------
	Set @JobFilter = IsNull(@JobFilter, 0)
	
	-----------------------------------------------
	-- Clear the output parameters
	-----------------------------------------------
	Set @message = ''
	Set @JobAdvancedToNextState = 0
	
	-----------------------------------------------
	-- Populate a temporary table with the list of known Result Types appropriate for peptide prophet calculation
	-----------------------------------------------
	CREATE TABLE #T_ResultTypeList (
		ResultType varchar(64)
	)
	
	INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')

	If @JobFilter <> 0
	Begin
		-- If Job @JobFilter is not a Peptide_Hit job, then advance the state to @NextProcessState
		UPDATE T_Analysis_Description
		SET Process_State = @NextProcessState, Last_Affected = GetDate()
		WHERE Job = @JobFilter AND
			  NOT ResultType IN (SELECT ResultType FROM #T_ResultTypeList)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		IF @myRowCount <> 0
			Set @JobAdvancedToNextState = 1

		-- See if Job @JobFilter already has peptide prophet results 
		--  present in T_Score_Discriminant; advance the state to @NextProcessState
		--  if no Null values are present
		UPDATE T_Analysis_Description
		SET Process_State = @NextProcessState, Last_Affected = GetDate()
		WHERE Job = @JobFilter AND
			ResultType IN (SELECT ResultType FROM #T_ResultTypeList) AND
			NOT Job IN (
				SELECT DISTINCT TAD.Job
				FROM T_Analysis_Description TAD INNER JOIN
					T_Peptides P ON TAD.Job = P.Analysis_ID INNER JOIN
					T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID
				WHERE TAD.Job = @JobFilter AND
					  SD.Peptide_Prophet_Probability IS NULL
				)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount <> 0
			Set @JobAdvancedToNextState = 1
	End
	Else
	Begin
		-- Look for jobs with state @ProcessStateMatch that are not Peptide_Hit jobs; 
		--  advance their state to @NextProcessState
		UPDATE T_Analysis_Description
		SET Process_State = @NextProcessState, Last_Affected = GetDate()
		WHERE Process_State = @ProcessStateMatch AND
			  NOT ResultType IN (SELECT ResultType FROM #T_ResultTypeList)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		IF @myRowCount <> 0
			Set @JobAdvancedToNextState = 1

		-- Look for jobs with state @ProcessStateMatch that already 
		--  have peptide prophet results present in T_Score_Discriminant;
		--  advance their state to @NextProcessState
		UPDATE T_Analysis_Description
		SET Process_State = @NextProcessState, Last_Affected = GetDate()
		WHERE Process_State = @ProcessStateMatch AND
			ResultType IN (SELECT ResultType FROM #T_ResultTypeList) AND
			NOT Job IN (
				SELECT DISTINCT TAD.Job
				FROM T_Analysis_Description TAD INNER JOIN
					T_Peptides P ON TAD.Job = P.Analysis_ID INNER JOIN
					T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID
				WHERE TAD.Process_State = @ProcessStateMatch AND
					SD.Peptide_Prophet_Probability IS NULL
				)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount <> 0
			Set @JobAdvancedToNextState = 1
	End
	
Done:
	return @myError


GO

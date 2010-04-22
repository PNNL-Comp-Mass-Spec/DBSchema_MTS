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
**			02/06/2007 mem - Now ignoring charge states >= 6 when looking for rows with null Peptide_Prophet_Probability values
**			04/17/2007 mem - Now also ignoring charge states >= 6 when @JobFilter is non-zero; posting a log message if any peptides with charge >= 6 have Null values (Ticket #423)
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

	declare @RowCountTotal int
	declare @RowCountNull int
	declare @RowCountNullCharge5OrLess int

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
		Else
		Begin
			-----------------------------------------------
			-- Job @JobFilter must have a ResultType in #T_ResultTypeList
			-- See if any rows have null Peptide Prophet values for this job
			-- Keep track of whether the charge is <= 5 only advance
			-- if the only missing values are peptides with charge >= 6
			-----------------------------------------------
			--
			Set @RowCountTotal = 0
			Set @RowCountNull = 0
			Set @RowCountNullCharge5OrLess = 0
			SELECT	@RowCountTotal = COUNT(*),
					@RowCountNull = SUM(CASE WHEN SD.Peptide_Prophet_FScore IS NULL OR 
												  SD.Peptide_Prophet_Probability IS NULL 
										THEN 1 ELSE 0 END),
					@RowCountNullCharge5OrLess = SUM(CASE WHEN P.Charge_State <= 5 AND (
																SD.Peptide_Prophet_FScore IS NULL OR 
																SD.Peptide_Prophet_Probability IS NULL)
										THEN 1 ELSE 0 END)
			FROM T_Peptides P INNER JOIN
				 T_Score_Discriminant SD ON 
				 P.Peptide_ID = SD.Peptide_ID
			WHERE P.Analysis_ID = @JobFilter
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @RowCountTotal > 0 And @RowCountNull = 0
			Begin
				-- No Null rows; advance the state
				Set @JobAdvancedToNextState = 1	
			End
			Else
			Begin
				If @RowCountNull > 0 And @RowCountNullCharge5OrLess = 0
				Begin
					set @message = 'Job ' + Convert(varchar(12), @JobFilter) + ' has ' + Convert(varchar(12), @RowCountNull) + ' out of ' + Convert(varchar(12), @RowCountTotal) + ' rows in T_Score_Discriminant with null peptide prophet FScore or Probability values; however, all have charge state 6+ or higher'
					execute PostLogEntry 'Warning', @message, 'CheckPeptideProphetUpdateRequired'
					Set @JobAdvancedToNextState = 1	
				End
			End
			
			If @JobAdvancedToNextState = 1
			Begin
				UPDATE T_Analysis_Description
				SET Process_State = @NextProcessState, Last_Affected = GetDate()
				WHERE Job = @JobFilter
			End
		End
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
					  SD.Peptide_Prophet_Probability IS NULL AND
					  P.Charge_State <= 5
				)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount <> 0
			Set @JobAdvancedToNextState = 1
	End
	
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CheckPeptideProphetUpdateRequired] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckPeptideProphetUpdateRequired] TO [MTS_DB_Lite] AS [dbo]
GO

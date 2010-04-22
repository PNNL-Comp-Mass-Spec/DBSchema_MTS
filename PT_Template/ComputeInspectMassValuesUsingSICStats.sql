/****** Object:  StoredProcedure [dbo].[ComputeInspectMassValuesUsingSICStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure ComputeInspectMassValuesUsingSICStats
/****************************************************
**
**	Desc: 
**		Populates DelM in T_Score_Inspect (and optionally MH in T_Peptides)
**		This procedure is only appropriate for Inspect analysis jobs; other job types will be skipped
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	10/29/2008 mem - Initial Version
**			01/08/2009 mem - Now storing theoretical peptide MH in T_Peptides.MH
**						   - Computing DelM as Theoretical_MH - Observed_MH, which is consistent with XTandem and Sequest data in MTS
**						   - Added parameter @ForceMHRecalculation (with a default of 0)
**    
*****************************************************/
(
	@Job int,
	@message varchar(512)='' output,
	@ForceMHRecalculation tinyint = 0				-- When 0, then only calculates T_Peptides.MH if Null
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @ResultType varchar(32)
	Declare @SICJobExists tinyint
	
	Declare @SICProcessState int
	Declare @RowCountUpdated int
	Declare @RowCountUpdated2 int
	Set @RowCountUpdated = 0
	Set @RowCountUpdated2 = 0
	
	Declare @RowCountDefined int
	
	Declare @JobStr varchar(18)
	
	Declare @ErrorMessage varchar(512)
	
	----------------------------------------------
	-- Validate the inputs
	----------------------------------------------
		
	Set @Job = IsNull(@Job, 0)
	Set @message = ''
	Set @ForceMHRecalculation = IsNull(@ForceMHRecalculation, 0)
	
	Set @JobStr = Convert(varchar(18), @Job)

	----------------------------------------------
	-- Look for @job in T_Analysis_Description
	----------------------------------------------

	SELECT TOP 1 @Job = Job,
		         @ResultType = ResultType
	FROM T_Analysis_Description
	WHERE Job = @Job
	ORDER BY Job
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		Set @message = 'Error while looking for job ' + @JobStr + ' in T_Analysis_Description'
		goto done
	end


	If @myRowCount = 0
		Set @message = 'Warning: Job ' + @JobStr + ' not found in T_Analysis_Description'

	If @ResultType <> 'IN_Peptide_Hit'
	Begin
		Set @message = 'Warning: Job ' + @JobStr + ' has job type "' + @ResultType + '"; it will be ignored since it is not type "IN_Peptide_Hit"'
		Set @myRowCount = 0		
	End
	
	If @message <> ''
		exec PostLogEntry 'Warning', @message, 'ComputeInspectMassValuesUsingSICStats'
	
	
	If @myRowCount >= 1
	Begin -- <a>
		----------------------------------------------
		-- Make sure the Job has a SIC_Job associated with it
		----------------------------------------------
		--
		Set @SICJobExists = 0
		Set @SICProcessState = 0
		
		SELECT @SICProcessState = TAD_SIC.Process_State
		FROM T_Analysis_Description TAD
		     INNER JOIN T_Datasets DS
		       ON TAD.Dataset_ID = DS.Dataset_ID
		     INNER JOIN T_Analysis_Description TAD_SIC
		       ON DS.SIC_Job = TAD_SIC.Job
		WHERE TAD.Job = @Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
		Begin
			Set @ErrorMessage = 'Computation of DelM in T_Score_Inspect failed for job ' + @JobStr+ '; a corresponding SIC job could not be found'
			exec PostLogEntry 'Error', @ErrorMessage, 'ComputeInspectMassValuesUsingSICStats', 24
			Set @message = @ErrorMessage
		End
		Else
		Begin
			If IsNull(@SICProcessState, 0) = 75
				Set @SICJobExists = 1
			Else
			Begin
				Set @ErrorMessage = 'Computation of DelM in T_Score_Inspect failed for job ' + @JobStr + '; although a SIC job exists, its state is not 75'
				exec PostLogEntry 'Error', @ErrorMessage, 'ComputeInspectMassValuesUsingSICStats', 24
				Set @message = @ErrorMessage
			End
		End
		
		If @SICJobExists = 1
		Begin -- <b>
		
			----------------------------------------------
			-- Count the number of rows in T_Peptides for this job
			----------------------------------------------
			--
			SELECT @RowCountDefined = COUNT(*)
			FROM T_Peptides
			WHERE Analysis_ID = @Job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			----------------------------------------------
			-- Create and populate a table tracking the parent ion m/z value for each fragmentation scan
			----------------------------------------------
			
			CREATE TABLE #TmpParentMZInfo (
				Peptide_ID int NOT NULL,
				Parent_Ion_MH float NULL
			)
			
			CREATE CLUSTERED INDEX #IX_TmpParentMZInfo ON #TmpParentMZInfo (Peptide_ID)
			
			-- Compute and store the observed Parent ion MH values for the peptides in this job
			--
			INSERT INTO #TmpParentMZInfo( Peptide_ID, Parent_Ion_MH)
			SELECT DISTINCT Pep.Peptide_ID,
			                DS_SIC.MZ * Pep.Charge_State - (Pep.Charge_State - 1) * 1.0073 AS Parent_Ion_MH
			FROM T_Peptides Pep
			     INNER JOIN T_Analysis_Description TAD
			       ON Pep.Analysis_ID = TAD.Job
			     INNER JOIN T_Dataset_Stats_SIC DS_SIC
			       ON Pep.Scan_Number = DS_SIC.Frag_Scan_Number
			     INNER JOIN T_Datasets DS
			       ON TAD.Dataset_ID = DS.Dataset_ID AND
			          DS_SIC.Job = DS.SIC_Job
			WHERE (Pep.Analysis_ID = @Job)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount


			----------------------------------------------
			-- Populate the MH column in T_Peptides
			-- We store the theoretical peptide MH value in this column
			----------------------------------------------
			--
			UPDATE T_Peptides
			SET MH = S.Monoisotopic_Mass + 1.0073
			FROM T_Peptides Pep
				INNER JOIN T_Sequence S 
				ON Pep.Seq_ID = S.Seq_ID
			WHERE (Pep.Analysis_ID = @Job) And 
				  (@ForceMHRecalculation <> 0 OR IsNull(Pep.MH, 0) = 0)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			Set @RowCountUpdated = @myRowCount
			
			If @RowCountUpdated > 0
				Set @message = 'Computed MH for ' + Convert(varchar(11), @RowCountUpdated) + ' rows in T_Peptides for job ' + @JobStr
			
			If @ForceMHRecalculation <> 0
			Begin
				-- Make a log entry if the number of updated rows doesn't match @RowCountDefined
				If @RowCountUpdated < @RowCountDefined
				Begin
					Set @ErrorMessage = 'Computation of MH in T_Peptides failed for Inspect job ' + @JobStr + '; only ' + Convert(varchar(11), @RowCountUpdated) + ' rows were updated while ' + Convert(varchar(11), @RowCountDefined) + ' rows exist'
					exec PostLogEntry 'Error', @ErrorMessage, 'ComputeInspectMassValuesUsingSICStats'
				End
				Else
				Begin
					If @RowCountUpdated = 0
					Begin
						-- Make a log entry if @RowCountUpdated = 0
						Set @ErrorMessage = 'Computation of MH in T_Peptides failed for Inspect job  ' + @JobStr + '; 0 rows were updated'
						exec PostLogEntry 'Error', @ErrorMessage, 'ComputeInspectMassValuesUsingSICStats'
					End
				End
			End
						
			
			If @RowCountUpdated > 0 OR @ForceMHRecalculation = 0
			Begin -- <c>
				-- Populate the DelM column in T_Score_Inspect
				-- DelM = Theoretical_Mass - Observed_Mass
				--
				UPDATE T_Score_Inspect
				SET DelM = Pep.MH - PMI.Parent_Ion_MH
				FROM T_Peptides Pep
				     INNER JOIN T_Score_Inspect I
				       ON Pep.Peptide_ID = I.Peptide_ID
				     INNER JOIN #TmpParentMZInfo PMI
				       ON Pep.Peptide_ID = PMI.Peptide_ID
				WHERE (Pep.Analysis_ID = @Job) AND Not Pep.MH Is Null
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				Set @RowCountUpdated2 = @myRowCount
				
				If @message <> ''
					Set @message = @message + '; '
					
				Set @message = @message + 'Computed DelM for ' + Convert(varchar(11), @myRowCount) + ' rows in T_Score_Inspect for job ' + @JobStr
				
				If @RowCountUpdated2 < @RowCountDefined
				Begin
					Set @ErrorMessage = 'Computation of DelM in T_Score_Inspect failed for Inspect job ' + @JobStr + '; only ' + Convert(varchar(11), @RowCountUpdated2) + ' rows were updated while ' + Convert(varchar(11), @RowCountDefined) + ' rows exist'
					exec PostLogEntry 'Error', @ErrorMessage, 'ComputeInspectMassValuesUsingSICStats'
				End
				Else
				Begin
					If @RowCountUpdated2 = 0
					Begin
						-- Make a log entry if @RowCountUpdated2 = 0
						Set @ErrorMessage = 'Computation of DelM in T_Score_Inspect failed for Inspect job  ' + @JobStr + '; 0 rows were updated'
						exec PostLogEntry 'Error', @ErrorMessage, 'ComputeInspectMassValuesUsingSICStats'
					End
				End
				
			End -- </c>

			If @RowCountUpdated + @RowCountUpdated2 > 0
				exec PostLogEntry 'Normal', @message, 'ComputeInspectMassValuesUsingSICStats'
				
		end  -- </b>
	end -- </a>

Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ComputeInspectMassValuesUsingSICStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeInspectMassValuesUsingSICStats] TO [MTS_DB_Lite] AS [dbo]
GO

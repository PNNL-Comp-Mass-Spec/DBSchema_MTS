/****** Object:  StoredProcedure [dbo].[CalculateCleavageStateForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE Procedure dbo.CalculateCleavageStateForAvailableAnalyses
/****************************************************
**
**	Desc: 
**		Calls CalculateCleavageState for jobs in T_Analysis_Description
**      matching state @ProcessState
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/03/2009
**    
*****************************************************/
(
	@ProcessStateMatch int = 31,
	@NextProcessState int = 33,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @JobList varchar(max)
	Set @JobList = ''

	Declare @count int
	Declare @Job int
	Declare @Continue int
	Declare @MatchCount int
	Set @MatchCount = 0
	
	Declare @message varchar(512)
	
	----------------------------------------------
	-- Construct a list of the jobs in T_Analysis_Description that have a Process_State of @ProcessStateMatch
	----------------------------------------------

	If Exists (SELECT * FROM T_Analysis_Description WHERE Process_State = @ProcessStateMatch)
	Begin -- <a>
		
		SELECT TOP ( @numJobsToProcess ) @JobList = @JobList + ', ' + Convert(varchar(20), Job)
		FROM T_Analysis_Description
		WHERE Process_State = @ProcessStateMatch
		ORDER BY Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @Count = @myRowCount

		If @Count > 0
		Begin -- <b>
			-- Remove the leading comma from @JobList
			Set @JobList = Substring(@JobList, 3, Len(@JobList))

			---------------------------------------------------
			-- Calculate cleavage state for the jobs in @JobList
			---------------------------------------------------			
			--
			EXEC @myError = CalculateCleavageStateUsingProteinSequence @JobList=@JobList, @NextProcessState=@NextProcessState, @numJobsProcessed=@numJobsProcessed output
			
			If @myError <> 0
				Set @message = 'Error calling CalculateCleavageStateUsingProteinSequence: ' + Convert(varchar(12), @myError)
			
		End -- </b>
		
	End -- </a>

	
	If @numJobsProcessed = 0
		set @message = 'no analyses were available'

Done:
	return @myError


GO

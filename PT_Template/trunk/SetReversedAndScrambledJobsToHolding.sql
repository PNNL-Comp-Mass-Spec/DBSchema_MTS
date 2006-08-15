/****** Object:  StoredProcedure [dbo].[SetReversedAndScrambledJobsToHolding] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.SetReversedAndScrambledJobsToHolding
/****************************************************
**
**	Desc:	Looks for jobs that were searched against a reversed or
**			scrambled protein database that are in state @ProcessStateMatch
**			Updates their state to 6 = Holding
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	08/02/2006
**    
*****************************************************/
(
	@ProcessStateMatch int = 25,
	@NextProcessState int = 6,
	@numJobsProcessed int=0 OUTPUT
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @message varchar(255)
	Set @message = ''


	UPDATE T_Analysis_Description
	SET Process_State = @NextProcessState, Last_Affected = GetDate()
	WHERE Process_State = @ProcessStateMatch AND (
			Organism_DB_Name LIKE '%scrambled.fasta' OR
			Organism_DB_Name LIKE '%reversed.fasta' OR
			Protein_Options_List LIKE 'seq[_]direction=reversed%' OR
			Protein_Options_List LIKE 'seq[_]direction=scrambled%'
		  )
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error updating jobs to state ' + Convert(varchar(9), IsNull(@NextProcessState, 0)) + ' in T_Analysis_Description'
		execute PostLogEntry 'Error', @message, 'SetReversedAndScrambledJobsToHolding'
		goto done
	End
	Else
		Set @numJobsProcessed = @myRowCount

Done:
	return @myError


GO

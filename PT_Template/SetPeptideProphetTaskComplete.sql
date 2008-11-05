/****** Object:  StoredProcedure [dbo].[SetPeptideProphetTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.SetPeptideProphetTaskComplete
/****************************************************
**
**	Desc: 	Updates task @taskID to the appropriate Process_State
**			based on @completionCode
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth: 	mem
**	Date: 	07/05/2006
**
*****************************************************/
(
	@taskID int,
	@completionCode int = 0, -- 0->Success, 1->UpdateFailed, 2->ResultsFailed
	@message varchar(512) output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	declare @PeptideProphetCalcTimeoutState int
	set @PeptideProphetCalcTimeoutState = 94

	declare @PeptideProphetCalcReadyToLoad int
	set @PeptideProphetCalcReadyToLoad = 96

	If @completionCode = 0
	Begin
		-- Results are now ready; set state to 3 = 'Results Ready'
		Exec SetPeptideProphetTaskState @TaskID, 3, @PeptideProphetCalcReadyToLoad, @message output
	End
	Else
	Begin
		-- Update failed; set state to 6 = 'Update Failed'
		Exec SetPeptideProphetTaskState @TaskID, 6, @PeptideProphetCalcTimeoutState, @message output
	End

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[SetPeptideProphetTaskComplete] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeptideProphetTaskComplete] TO [MTS_DB_Lite]
GO
GRANT EXECUTE ON [dbo].[SetPeptideProphetTaskComplete] TO [pnl\MTSProc]
GO

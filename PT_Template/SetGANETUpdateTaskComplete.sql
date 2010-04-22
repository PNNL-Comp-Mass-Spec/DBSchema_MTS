/****** Object:  StoredProcedure [dbo].[SetGANETUpdateTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure dbo.SetGANETUpdateTaskComplete
/****************************************************
**
**	Desc: 
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 8/26/2003   
**		Updated: 07/05/2004 mem - Modified for use Peptide DB's
**				 08/07/2004 mem - Added call to SetProcessState
**				 05/30/2005 mem - Updated to process batches of jobs using T_NET_Update_Task
**
*****************************************************/
	@TaskID int,
	@completionCode int = 0, -- 0->Success, 1->UpdateFailed
	@message varchar(512)='' output
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	declare @GANETProcessingTimeoutState int
	set @GANETProcessingTimeoutState = 44

	declare @GANETProcessingReadyToLoad int
	set @GANETProcessingReadyToLoad = 46

	If @completionCode = 0
	Begin
		-- Results are now ready; set state to 3 = 'Results Ready'
		Exec SetGANETUpdateTaskState @TaskID, 3, @GANETProcessingReadyToLoad, @message output
	End
	Else
	Begin
		-- Update failed; set state to 6 = 'Update Failed'
		Exec SetGANETUpdateTaskState @TaskID, 6, @GANETProcessingTimeoutState, @message output
	End

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[SetGANETUpdateTaskComplete] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetGANETUpdateTaskComplete] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[SetGANETUpdateTaskComplete] TO [pnl\MTSProc] AS [dbo]
GO

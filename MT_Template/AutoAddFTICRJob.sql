/****** Object:  StoredProcedure [dbo].[AutoAddFTICRJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.AutoAddFTICRJob
/****************************************************
**
**	Desc: 
**		Automatically adds an entry to T_FTICR_Analysis_Description (if not yet present)
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	05/04/2011
**    
*****************************************************/
(
	@Job int,
	@message varchar(512)='' OUTPUT
)
AS
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @JobList varchar(24)
	Declare @entriesAdded int = 0

	set @message = ''
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		If Not Exists (SELECT * FROM T_FTICR_Analysis_Description WHERE Job = @Job)
		Begin
			-----------------------------------------------------------
			-- Try to add the job using ImportNewMSAnalyses
			-----------------------------------------------------------

			Set @JobList = Convert(varchar(24), @Job)
			
			exec ImportNewMSAnalyses @entriesAdded output, @message output, @infoOnly=0, @JobListOverride = @JobList, @PreviewSql=0, @UseCachedDMSDataTables=1
			
		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'AutoAddFTICRJob')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
	End Catch	
	
Done:
	Return @myError


GO

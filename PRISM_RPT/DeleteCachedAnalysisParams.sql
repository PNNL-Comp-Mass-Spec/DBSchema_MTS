/****** Object:  StoredProcedure [dbo].[DeleteCachedAnalysisParams] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.DeleteCachedAnalysisParams
/****************************************************
**
**	Desc: Deletes old analysis parameters in 
**        T_Peak_Matching_Params_Cached and T_MultiAlign_Params_Cached and
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	01/04/2008
**			
*****************************************************/
(
	@DaysToRetainCachedParams real = 2,
	@JobID int = 0,					-- If non-zero, then only deletes parameters for the given job
	@InfoOnly tinyint = 0,
	@message varchar(512) = ''
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @S varchar(2048)
	Declare @SqlCommand varchar(512)
	Declare @SqlWhere varchar(512)
	
	---------------------------------------------------
	-- Validate the input parameters
	---------------------------------------------------
	
	Set @DaysToRetainCachedParams = IsNull(@DaysToRetainCachedParams, 2)
	If @DaysToRetainCachedParams <= 0
		Set @DaysToRetainCachedParams = 0.5

	Set @JobID = IsNull(@JobID, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	
	Set @message = ''
	
	---------------------------------------------------
	-- Define the Date Threshold
	---------------------------------------------------
	
	Declare @DateThreshold datetime
	Set @DateThreshold = DateAdd(hour, -@DaysToRetainCachedParams * 24.0, GetDate())

	---------------------------------------------------
	-- Define the Sql command
	---------------------------------------------------
		
	If @InfoOnly = 0
	Begin
		Set @SqlCommand = 'DELETE FROM'
	End
	Else
	Begin
		Set @SqlCommand = 'SELECT * FROM'
	End
	
	Set @SqlWhere = 'WHERE Cache_Date < ''' + Convert(varchar(64), @DateThreshold) + ''''
	If @JobID <> 0
		Set @SqlWhere = @SqlWhere + ' AND Job_ID = ' + Convert(varchar(12), @JobID)
	
	
	Set @S = @SqlCommand + ' T_Peak_Matching_Params_Cached ' + @SqlWhere
	Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @message = 'Matched ' + Convert(varchar(12), @myRowCount) + ' rows in T_Peak_Matching_Params_Cached'

	Set @S = @SqlCommand + ' T_MultiAlign_Params_Cached ' + @SqlWhere
	Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	Set @message = @message + '; Matched ' + Convert(varchar(12), @myRowCount) + ' rows in T_MultiAlign_Params_Cached'

	If @InfoOnly <> 0
		SELECT @message AS Message

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO

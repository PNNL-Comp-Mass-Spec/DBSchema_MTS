SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetPeakMatchingTaskResultStats]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetPeakMatchingTaskResultStats]
GO


CREATE PROCEDURE dbo.GetPeakMatchingTaskResultStats
/****************************************************	
**  Desc: Looks up various statistics for the given
**		  peak matching task
**
**  Return values: 0 if success, otherwise, error code
**
**  Parameters: PeakMatchingTaskID to lookup
**
**  Auth: mem
**	Date: 08/12/2004
**
****************************************************/
(
	@PeakMatchingTaskID int,
	@JobNumber int=0 OUTPUT,
	@NonUniqueHitsCount int=0 OUTPUT,
	@UMCCount int=0 OUTPUT,
	@UMCCountWithHits int=0 OUTPUT,
	@UniqueMassTagHitCount int=0 OUTPUT,
	@message varchar(512)='' OUTPUT
)
AS
	Set Nocount On

	Declare	@myError int,
			@myRowCount int

	Set @myError = 0
	Set @myRowCount = 0

	Declare @MD_ID int
	Declare @PMTaskStr varchar(11)
	
	-- Clear the output variables
	Set @JobNumber = 0
	Set @NonUniqueHitsCount = 0
	Set @UMCCount = 0
	Set @UMCCountWithHits = 0
	Set @UniqueMassTagHitCount = 0
	set @message = ''
	
	Set @MD_ID = 0
	Set @PMTaskStr = Convert(varchar(11), @PeakMatchingTaskID)

	-- Look up the peak matching Task ID and the associated MD_ID value
	SELECT	@JobNumber = PM.Job, 
			@NonUniqueHitsCount = MMD.MD_Peaks_Count, 
			@UMCCount = MMD.MD_UMC_Count,
			@MD_ID = IsNull(PM.MD_ID, 0)
	FROM	T_Peak_Matching_Task AS PM LEFT OUTER JOIN
			T_Match_Making_Description AS MMD ON PM.MD_ID = MMD.MD_ID
	WHERE	PM.Task_ID = @PeakMatchingTaskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myError <> 0
	Begin
		Set @message = 'Error looking up peak matching task in T_Peak_Matching_Task'
		Goto Done
	End
	Else
	Begin
		If @myRowCount = 0
		Begin
			Set @message = 'Peak matching task ID ' + @PMTaskStr + ' not found in T_Peak_Matching_Task'
			Set @myError = 1
			Goto Done
		End
		Else
		Begin
			If @MD_ID = 0
			Begin
				Set @message = 'MD_ID value not defined for Peak Matching Task ID ' + @PMTaskStr
				Set @myError = 2
				Goto Done
			end
		End
	End

	-- Count the number of UMC's with one or more mass tag hits in state 6 
	SELECT @UMCCountWithHits = COUNT(DISTINCT T_FTICR_UMC_Results.UMC_Ind) 
	FROM T_Match_Making_Description 
		INNER JOIN
		T_FTICR_UMC_Results ON T_Match_Making_Description.MD_ID = T_FTICR_UMC_Results.MD_ID
		INNER JOIN
		T_FTICR_UMC_ResultDetails ON T_FTICR_UMC_Results.UMC_Results_ID = T_FTICR_UMC_ResultDetails.UMC_Results_ID
	WHERE	T_Match_Making_Description.MD_ID = @MD_ID AND
			T_FTICR_UMC_ResultDetails.Match_State = 6
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error looking up UMC count with hits'
		Goto Done
	End

	-- Count the number of mass tag hits
	SELECT @UniqueMassTagHitCount = COUNT(DISTINCT T_FTICR_UMC_ResultDetails.Mass_Tag_ID)		
	FROM T_Match_Making_Description
		INNER JOIN
		T_FTICR_UMC_Results ON T_Match_Making_Description.MD_ID = T_FTICR_UMC_Results.MD_ID
		INNER JOIN
		T_FTICR_UMC_ResultDetails ON T_FTICR_UMC_Results.UMC_Results_ID = T_FTICR_UMC_ResultDetails.UMC_Results_ID
	WHERE	T_Match_Making_Description.MD_ID = @MD_ID AND
			T_FTICR_UMC_ResultDetails.Match_State = 6
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error looking up unique mass tag hit count'
		Goto Done
	End


Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetPeakMatchingTaskResultStats]  TO [DMS_SP_User]
GO


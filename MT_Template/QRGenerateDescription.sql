/****** Object:  StoredProcedure [dbo].[QRGenerateDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Procedure dbo.QRGenerateDescription
/****************************************************	
**  Desc: Returns the list of Jobs that the MDID's for
**        the given QuantitationID correspond to
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID value
**
**  Auth: mem
**	Date: 08/26/2003
**
****************************************************/
(
	@QuantitationID int ,
	@DescriptionSuffix varchar(20) = 'Pro' ,	-- This text gets appended to the job list when making the description; should be kept short
	@Description varchar(32) OUTPUT				-- Description
)
AS

	Set NoCount On

	Declare @JobList varchar(1024),
			@JobListCount int,
			@myError int
	
	Set @JobList = ''
	
	SELECT	@JobList = @JobList + ',' + LTrim(RTrim(Convert(varchar(19), T_Match_Making_Description.MD_Reference_Job)))
	FROM	T_Quantitation_Description INNER JOIN
			T_Quantitation_MDIDs ON 
			T_Quantitation_Description.Quantitation_ID = T_Quantitation_MDIDs.Quantitation_ID
			  INNER JOIN
			T_Match_Making_Description ON 
			T_Quantitation_MDIDs.MD_ID = T_Match_Making_Description.MD_ID
	WHERE	T_Quantitation_Description.Quantitation_ID = @QuantitationID
	ORDER BY MD_Reference_Job
	--
	Select @myError = @@Error
	--
	Set @JobListCount = @@RowCount
	
	If @JobListCount <= 0 OR Len(@JobList) = 0
		-- No jobs found; may hve been an invalid @QuantitationID value
		Set @JobList = 'Job 0'
	Else
	  Begin
		-- Remove the leading ,
		Set @JobList = SubString(@JobList, 2, Len(@JobList)-1)
		
		If @JobListCount = 1
			-- Just one jobs
			Set @JobList = 'Job ' + @JobList
		Else
			-- Multiple jobs
			Set @JobList = 'Jobs ' + @JobList
	  End

	-- Define the description using QID and @DescriptionSuffix (if defined)
	Set @Description = ' (QID' + convert(varchar(19), @QuantitationID)
	
	If Len(IsNull(@DescriptionSuffix, '')) > 0
		Set @Description = @Description + ',' + @DescriptionSuffix
	
	Set @Description = @Description + ')'

	-- Make sure @JobList isn't too long
	If Len(@JobList) > 31 - Len(@Description)
		Set @JobList = SubString(@JobList, 1, 29 - Len(@Description)) + '..'

	-- Add @JobList to the front of @Description
	Set @Description = @JobList + @Description

	Return @myError



GO
GRANT VIEW DEFINITION ON [dbo].[QRGenerateDescription] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRGenerateDescription] TO [MTS_DB_Lite] AS [dbo]
GO

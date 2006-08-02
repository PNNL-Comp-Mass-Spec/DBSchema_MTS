SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ComputeMaxObsAreaByJob]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ComputeMaxObsAreaByJob]
GO


CREATE Procedure dbo.ComputeMaxObsAreaByJob
/****************************************************
**
**	Desc: 
**		Populates column Max_Obs_Area_In_Job in T_Peptides,
**		optionally filtering using @JobFilterList.  If jobs
**		are provided by @JobFilterList then the Max_Obs_Are_In_Job
**		values are reset to 0
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 10/09/2005
**			  10/12/2005 mem - Added parameter @PostLogEntryOnSuccess
**    
*****************************************************/
 	@JobsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList as varchar(1024) = '',
 	@infoOnly tinyint = 0,
 	@PostLogEntryOnSuccess tinyint = 0
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @infoOnly = IsNull(@infoOnly, 0)
	set @JobsUpdated = 0
	set @message = ''

	declare @result int
	declare @JobsToUpdate int
	
	declare @S nvarchar(4000)

	---------------------------------------------------
	-- Create a temporary tables
	---------------------------------------------------
	--

	CREATE TABLE #T_Jobs_To_Update (
		Job int NOT NULL
	)

	---------------------------------------------------
	-- Look for jobs having Max_Obs_Area_In_Job=0 for all peptides
	---------------------------------------------------
	set @S = ''	
	set @S = @S + ' INSERT INTO #T_Jobs_To_Update (Job)'
	set @S = @S + ' SELECT Analysis_ID'
	set @S = @S + ' FROM T_Peptides'
	If Len(IsNull(@JobFilterList, '')) > 0
		Set @S = @S + ' WHERE T_Peptides.Analysis_ID In (' + @JobFilterList + ')'
	set @S = @S + ' GROUP BY Analysis_ID'
	set @S = @S + ' HAVING SUM(Max_Obs_Area_In_Job) = 0'

	exec @result = sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error looking for Jobs with undefined Max_Obs_Area_In_Job values'
		goto Done
	end

	If Len(@JobFilterList) > 0
	Begin
		---------------------------------------------------
		-- Append the jobs in @JobFilterList to #T_Jobs_To_Update
		---------------------------------------------------
		set @S = ''	
		set @S = @S + ' INSERT INTO #T_Jobs_To_Update (Job)'
		set @S = @S + ' SELECT TAD.Job'
		set @S = @S + ' FROM T_Analysis_Description AS TAD LEFT OUTER JOIN '
		set @S = @S +      ' #T_Jobs_To_Update AS JTU ON TAD.Job = JTU.Job'
		set @S = @S + ' WHERE TAD.Job In (' + @JobFilterList + ')'
		set @S = @S +       ' AND JTU.Job Is Null'

		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

	-- Count the number of jobs in #T_Jobs_To_Update	
	SELECT @JobsToUpdate = COUNT(Job)
	FROM #T_Jobs_To_Update
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	
	if @JobsToUpdate > 0
	Begin -- <a>

		If @infoOnly = 0
		Begin -- <b>
			---------------------------------------------------
			-- Reset Max_Obs_Area_In_Job to 0 for the jobs in #T_Jobs_To_Update
			---------------------------------------------------
			--
			UPDATE T_Peptides
			SET Max_Obs_Area_In_Job = 0
			FROM T_Peptides AS Pep INNER JOIN
				 #T_Jobs_To_Update AS JTU ON Pep.Analysis_ID = JTU.Job
			WHERE Max_Obs_Area_In_Job <> 0
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End -- </b>
		
		---------------------------------------------------
		-- Compute the value for Max_Obs_Area_In_Job for the given jobs
		-- Values for jobs in #T_Jobs_To_Update will have been reset to 0 above,
		--  causing them to be processed by this query
		---------------------------------------------------
		--
		set @S = ''

		If @infoOnly <> 0
		Begin
			-- Return the Job and the number of rows that would be updated
			set @S = @S + ' SELECT TP.Analysis_ID, COUNT(TP.Peptide_ID) AS Peptide_Rows_To_Update'
		End
		Else
		Begin
			set @S = @S + ' UPDATE T_Peptides'
			set @S = @S + ' SET Max_Obs_Area_In_Job = 1'
		End

		set @S = @S + ' FROM T_Peptides AS TP INNER JOIN'
		set @S = @S +      ' (	SELECT  Pep.Analysis_ID, Pep.Mass_Tag_ID, '
		set @S = @S +                 ' MIN(Pep.Peptide_ID) AS Min_Peptide_ID'
		set @S = @S +         ' FROM T_Peptides AS Pep INNER JOIN'
		set @S = @S +              ' (  SELECT Pep.Analysis_ID, Pep.Mass_Tag_ID,'
		set @S = @S +                        ' IsNull(MAX(Peak_Area * Peak_SN_Ratio), 0) AS Max_Area_Times_SN'
		set @S = @S +                 ' FROM T_Peptides AS Pep INNER JOIN'
		set @S = @S +                      ' #T_Jobs_To_Update AS JTU ON Pep.Analysis_ID = JTU.Job'
		set @S = @S +                 ' GROUP BY Pep.Analysis_ID, Pep.Mass_Tag_ID'
		set @S = @S +              ' ) AS LookupQ ON'
		set @S = @S +              ' Pep.Analysis_ID = LookupQ.Analysis_ID AND'
		set @S = @S +              ' Pep.Mass_Tag_ID = LookupQ.Mass_Tag_ID AND'
		set @S = @S +              ' LookupQ.Max_Area_Times_SN = IsNull(Pep.Peak_Area * Pep.Peak_SN_Ratio, 0)'
		set @S = @S + ' GROUP BY Pep.Analysis_ID, Pep.Mass_Tag_ID'
		set @S = @S +      ' ) AS BestObsQ ON'
		set @S = @S +      ' TP.Peptide_ID = BestObsQ.Min_Peptide_ID'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @infoOnly <> 0
		Begin
			set @S = @S + ' GROUP BY TP.Analysis_ID'
			set @S = @S + ' ORDER BY TP.Analysis_ID'
		End

		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error populating Max_Obs_Area_In_Job in T_Peptides'
			goto Done
		end
	End -- </a>

Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			set @message = 'Error updating Max_Obs_Area_In_Job in T_Peptides, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'ComputeMaxObsAreaByJob'
		Set @JobsUpdated = 0
	End
	Else
	Begin
		Set @JobsUpdated = @JobsToUpdate
		If @JobsUpdated > 0
		Begin
			set @message = 'Max_Obs_Area_In_Job updated for ' + convert(varchar(12), @JobsUpdated) + ' MS/MS Jobs'
			If @infoOnly <> 0
			Begin
				set @message = 'InfoOnly: ' + @message
				Select @message AS ComputeMaxObsAreaByJob_Message
			End
			Else
			Begin
				If @PostLogEntryOnSuccess <> 0
					execute PostLogEntry 'Normal', @message, 'ComputeMaxObsAreaByJob'
			End
		End
		Else
		Begin
			If @infoOnly <> 0
				Select 'InfoOnly: No jobs needing to be updated were found' As ComputeMaxObsAreaByJob_Message
		End
	End
	
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


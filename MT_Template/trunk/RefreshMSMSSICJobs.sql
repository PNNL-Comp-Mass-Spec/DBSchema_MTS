/****** Object:  StoredProcedure [dbo].[RefreshMSMSSICJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.RefreshMSMSSICJobs
/****************************************************
**
**	Desc: 
**		Populates Dataset_SIC_Job in T_Analysis_Description
**		Will also call RefreshMSMSSICStats for any updated jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/03/2005
**			10/12/2005 mem - Added parameter @PostLogEntryOnSuccess
**						   - Added call to RefreshMSMSSICStats for any jobs updated by this SP
**			12/01/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**						   - Increased size of @peptideDBName from 64 to 128 characters
**    
*****************************************************/
(
 	@jobsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(1024) = '',
 	@infoOnly tinyint = 0,
 	@PostLogEntryOnSuccess tinyint = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @infoOnly = IsNull(@infoOnly, 0)
	set @jobsUpdated = 0
	set @message = ''

	declare @result int
	set @result = 0
		
	declare @peptideDBName varchar(128)
	declare @peptideDBID int
	declare @jobCountToUpdate int
	
	declare @Job int
	declare @JobStr varchar(12)
	
	set @peptideDBName = ''

	declare @S nvarchar(4000)
	declare @continue tinyint
	declare @SICStatsContinue tinyint

	---------------------------------------------------
	-- Create two temporary tables
	---------------------------------------------------
	--
	CREATE TABLE #T_Peptide_Database_List (
		PeptideDBName varchar(128) NOT NULL,
		PDB_ID int
	)


	CREATE TABLE #T_Jobs_To_Update (
		Job int NOT NULL
	)

	---------------------------------------------------
	-- Get peptide database name(s)
	---------------------------------------------------
	--
	INSERT INTO #T_Peptide_Database_List (PeptideDBName, PDB_ID)
	SELECT DISTINCT PDL.PDB_Name, PDL.PDB_ID
	FROM MT_Main.dbo.T_Peptide_Database_List AS PDL INNER JOIN
		T_Analysis_Description AS TAD ON 
		PDL.PDB_ID = TAD.PDB_ID
	WHERE NOT (PDL.PDB_Name IS NULL)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount < 1
	begin
		set @message = 'No analyses with valid peptide DBs were found'
		set @myError = 0
		goto Done
	end


	---------------------------------------------------
	-- Loop through peptide database(s) and look for jobs
	-- that need to be updated
	---------------------------------------------------
	--

	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @peptideDBName = PeptideDBName, @peptideDBID = PDB_ID
		FROM #T_Peptide_Database_List
		ORDER BY PeptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>

			TRUNCATE TABLE #T_Jobs_To_Update
			set @jobCountToUpdate = 0
			
			set @S = ''
			set @S = @S + 'INSERT INTO #T_Jobs_To_Update (Job)'
			set @S = @S + ' SELECT TAD.Job'
			set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN '
			set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Analysis_Description AS PepTAD ON '
			set @S = @S + ' 	TAD.Job = PepTAD.Job INNER JOIN '
			set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Datasets AS DS ON PepTAD.Dataset_ID = DS.Dataset_ID'
			set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(nvarchar(21), @peptideDBID) + ' AND'
			set @S = @S + '    (TAD.Dataset_SIC_Job IS NULL OR IsNull(TAD.Dataset_SIC_Job,0) <> DS.SIC_Job)'

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND TAD.Job In (' + @JobFilterList + ')'

			exec @result = sp_executesql @S
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			set @jobCountToUpdate = @jobCountToUpdate + @myRowCount
			--
			if @myError <> 0
			begin
				set @message = 'Error comparing jobs to those in ' + @peptideDBName + ', examining NET values'
				goto Done
			end

			
			---------------------------------------------------
			-- Remove peptide DB from #T_Peptide_Database_List
			---------------------------------------------------
			DELETE FROM #T_Peptide_Database_List
			WHERE PDB_ID = @peptideDBID 
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			
			if @jobCountToUpdate > 0
			Begin -- <c>
				
				---------------------------------------------------
				-- Update the Dataset_SIC_Job for the appropriate jobs
				---------------------------------------------------
				--
				set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					set @S = @S + 'SELECT JTU.Job'
					
				End
				Else
				Begin
					set @S = @S + 'UPDATE TAD'
					set @S = @S + ' SET Dataset_SIC_Job = DS.SIC_Job'
				End

				set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN '
				set @S = @S +    ' [' + @peptideDBName + '].dbo.T_Analysis_Description AS PepTAD ON '
				set @S = @S +     ' TAD.Job = PepTAD.Job INNER JOIN '
				set @S = @S +       @peptideDBName + '.dbo.T_Datasets AS DS ON '
				set @S = @S +     ' PepTAD.Dataset_ID = DS.Dataset_ID INNER JOIN'
				set @S = @S +     ' #T_Jobs_To_Update AS JTU ON TAD.Job = JTU.Job'

				If @infoOnly <> 0
				Begin
					set @S = @S + ' ORDER BY JTU.Job'
				End

				exec @result = sp_executesql @S
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					set @message = 'Error updating Dataset_SIC_Job values in using ' + @peptideDBName
					goto Done
				end
					
				---------------------------------------------------
				-- Call RefreshMSMSSICStats for each job in #T_Jobs_To_Update
				---------------------------------------------------
				Set @SICStatsContinue = 1
				While @SICStatsContinue = 1
				Begin -- <d>
					SELECT TOP 1 @Job = Job
					FROM #T_Jobs_To_Update
					ORDER BY Job
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					if @myError <> 0
					begin
						set @message = 'Error obtaining next job from #T_Jobs_To_Update in RefreshMSMSSICStats loop'
						goto Done
					end

					If @myRowCount = 0
						Set @SICStatsContinue = 0
					Else
					Begin
						DELETE FROM #T_Jobs_To_Update
						WHERE Job = @Job 
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount

						Set @JobStr = Convert(varchar(12), @Job)
						exec @myError = RefreshMSMSSICStats @JobFilterList = @JobStr, @infoOnly = @infoOnly
						
						if @myError <> 0
						begin
							set @message = 'Error calling RefreshMSMSSICStats for Job ' + Convert(varchar(12), @Job)
							goto Done
						end
					End
					
				End -- </d>
				
				---------------------------------------------------
				-- Increment @jobsUpdated
				---------------------------------------------------

				Set @jobsUpdated = @jobsUpdated + @jobCountToUpdate
				
			End -- </c>
		
		End -- </b>
	End -- </a>

Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			set @message = 'Error updating Dataset_SIC_Job values, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSSICJobs'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			set @message = 'Dataset_SIC_Job values refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs'
			If @infoOnly <> 0
			Begin
				set @message = 'InfoOnly: ' + @message
				Select @message AS RefreshMSMSSICJobs_Message
			End
			Else
			Begin
				If @PostLogEntryOnSuccess <> 0
					execute PostLogEntry 'Normal', @message, 'RefreshMSMSSICJobs'
			End
		End
		Else
		Begin
			If @infoOnly <> 0
				Select 'InfoOnly: No jobs needing to be updated were found' As RefreshMSMSSICJobs_Message
		End
	End
	
	return @myError


GO

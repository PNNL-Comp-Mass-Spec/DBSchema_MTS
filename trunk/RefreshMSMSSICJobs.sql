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
**			09/19/2006 mem - Added support for peptide DBs being located on a separate MTS server, utilizing MT_Main.dbo.PopulatePeptideDBLocationTable to determine DB location given Peptide DB ID
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
	Set nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @jobsUpdated = 0
	Set @message = ''

	Declare @result int
	Set @result = 0
		
	Declare @PeptideDBPath varchar(256)		-- Switched from @peptideDBName to @PeptideDBPath on 9/19/2006
	Declare @PeptideDBID int
	Declare @jobCountToUpdate int

	Declare @PeptideDBCountInvalid int
	Declare @InvalidDBList varchar(1024)
	
	Declare @Job int
	Declare @JobStr varchar(12)
	
	Declare @S nvarchar(4000)
	Declare @continue tinyint
	Declare @SICStatsContinue tinyint

	---------------------------------------------------
	-- Create two temporary tables
	---------------------------------------------------
	--
	CREATE TABLE #T_Peptide_Database_List (
		PeptideDBName varchar(128) NULL,
		PeptideDBID int NULL,
		PeptideDBServer varchar(128) NULL,
		PeptideDBPath varchar(256) NULL
	)

	CREATE TABLE #T_Jobs_To_Update (
		Job int NOT NULL
	)

	---------------------------------------------------
	-- Populate #T_Peptide_Database_List with the PDB_ID values
	-- defined in T_Analysis_Description
	---------------------------------------------------
	--
	INSERT INTO #T_Peptide_Database_List (PeptideDBID)
	SELECT DISTINCT PDB_ID
	FROM T_Analysis_Description TAD
	WHERE NOT PDB_ID IS NULL
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount < 1
	begin
		Set @message = 'No analyses with valid peptide DB IDs were found'
		Set @myError = 0
		goto Done
	end

	---------------------------------------------------
	-- Determine the name and server for each Peptide DB in #T_Peptide_Database_List
	---------------------------------------------------
	--
	exec @myError = MT_Main.dbo.PopulatePeptideDBLocationTable @PreferDBName = 0, @message = @message output

	If @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling MT_Main.dbo.PopulatePeptideDBLocationTable'
		
		Set @message = @message + '; Error Code ' + Convert(varchar(12), @myError)
		Goto Done
	End
	
	Set @PeptideDBCountInvalid = 0
	SELECT @PeptideDBCountInvalid = COUNT(*)
	FROM #T_Peptide_Database_List
	WHERE PeptideDBName Is Null

	If @PeptideDBCountInvalid > 0
	Begin -- <a>
		-- One or more DBs in #T_Peptide_Database_List are unknown
		-- Construct a comma-separated list, post a log entry, 
		--  and delete the invalid databases from #T_Peptide_Database_List
		
		Set @InvalidDBList = ''
		SELECT @InvalidDBList = @InvalidDBList + PeptideDBID + ','
		FROM #T_Peptide_Database_List
		WHERE PeptideDBName Is Null
		ORDER BY PeptideDBID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount > 0
		Begin
			-- Remove the trailing comma
			Set @InvalidDBList = Left(@InvalidDBList, Len(@InvalidDBList)-1)
			
			Set @message = 'Invalid peptide DB ID'
			If @myRowCount > 1
				Set @message = @message + 's'
				
			Set @message = @message + ' defined in T_Analysis_Description: ' + @InvalidDBList
			execute PostLogEntry 'Error', @message, 'RefreshMSMSSICJobs'
			Set @message = ''
			
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBName Is Null
		End
	End

	---------------------------------------------------
	-- Loop through peptide database(s) and look for jobs
	-- that need to be updated
	---------------------------------------------------
	--

	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		Set @PeptideDBPath = ''

		SELECT TOP 1 @PeptideDBPath = PeptideDBPath,
					 @PeptideDBID = PeptideDBID
		FROM #T_Peptide_Database_List
		ORDER BY PeptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>

			TRUNCATE TABLE #T_Jobs_To_Update
			Set @jobCountToUpdate = 0
			
			Set @S = ''
			Set @S = @S + 'INSERT INTO #T_Jobs_To_Update (Job)'
			Set @S = @S + ' SELECT TAD.Job'
			Set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN '
			Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Analysis_Description AS PepTAD ON '
			Set @S = @S + ' 	TAD.Job = PepTAD.Job INNER JOIN '
			Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Datasets AS DS ON PepTAD.Dataset_ID = DS.Dataset_ID'
			Set @S = @S + ' WHERE TAD.PDB_ID = ' + Convert(nvarchar(21), @PeptideDBID) + ' AND'
			Set @S = @S + '    (TAD.Dataset_SIC_Job IS NULL OR IsNull(TAD.Dataset_SIC_Job,0) <> DS.SIC_Job)'

			If Len(IsNull(@JobFilterList, '')) > 0
				Set @S = @S + ' AND TAD.Job In (' + @JobFilterList + ')'

			exec @result = sp_executesql @S
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			Set @jobCountToUpdate = @jobCountToUpdate + @myRowCount
			--
			if @myError <> 0
			begin
				Set @message = 'Error comparing jobs to those in ' + @PeptideDBPath + ', examining NET values'
				goto Done
			end

			
			---------------------------------------------------
			-- Remove peptide DB from #T_Peptide_Database_List
			---------------------------------------------------
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBID = @PeptideDBID 
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			
			if @jobCountToUpdate > 0
			Begin -- <c>
				
				---------------------------------------------------
				-- Update the Dataset_SIC_Job for the appropriate jobs
				---------------------------------------------------
				--
				Set @S = ''

				If @infoOnly <> 0
				Begin
					-- Return the Job and the number of rows that would be updated
					Set @S = @S + 'SELECT JTU.Job'
					
				End
				Else
				Begin
					Set @S = @S + 'UPDATE TAD'
					Set @S = @S + ' Set Dataset_SIC_Job = DS.SIC_Job'
				End

				Set @S = @S + ' FROM T_Analysis_Description AS TAD INNER JOIN '
				Set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Analysis_Description AS PepTAD ON '
				Set @S = @S +     ' TAD.Job = PepTAD.Job INNER JOIN '
				Set @S = @S +     ' ' + @PeptideDBPath + '.dbo.T_Datasets AS DS ON '
				Set @S = @S +     ' PepTAD.Dataset_ID = DS.Dataset_ID INNER JOIN'
				Set @S = @S +     ' #T_Jobs_To_Update AS JTU ON TAD.Job = JTU.Job'

				If @infoOnly <> 0
				Begin
					Set @S = @S + ' ORDER BY JTU.Job'
				End

				exec @result = sp_executesql @S
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					Set @message = 'Error updating Dataset_SIC_Job values in using ' + @PeptideDBPath
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
						Set @message = 'Error obtaining next job from #T_Jobs_To_Update in RefreshMSMSSICStats loop'
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
							Set @message = 'Error calling RefreshMSMSSICStats for Job ' + Convert(varchar(12), @Job)
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
			Set @message = 'Error updating Dataset_SIC_Job values, error code ' + convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'RefreshMSMSSICJobs'
	End
	Else
	Begin
		If @jobsUpdated > 0
		Begin
			Set @message = 'Dataset_SIC_Job values refreshed for ' + convert(varchar(12), @jobsUpdated) + ' MS/MS Jobs'
			If @infoOnly <> 0
			Begin
				Set @message = 'InfoOnly: ' + @message
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

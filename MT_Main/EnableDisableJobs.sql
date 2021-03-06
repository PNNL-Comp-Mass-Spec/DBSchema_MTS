/****** Object:  StoredProcedure [dbo].[EnableDisableJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.EnableDisableJobs
/****************************************************
** 
**	Desc:	Looks for Sql Server Agent jobs with category
**			@CategoryName and enables or disables them
**
**	Return values: 0: success, otherwise, error code
** 
** 
**	Auth:	mem
**	Date:	01/18/2005
**			11/21/2006 mem - Updated to use master.dbo.xp_sqlagent_notify
**						   - Now including server name in the status message
**			11/15/2007 mem - Updated @CategoryName to allow comma separated lists
**    
*****************************************************/
(
	@EnableJobs tinyint,										-- 0 to disable, 1 to enable
	@CategoryName varchar(1024) = 'MTS Auto Update Continuous, DMS Continuous, Database Maintenance',		-- Can be comma-separated list
	@Preview tinyint = 0,										-- 1 to preview jobs that would be affected, 0 to actually make changes
	@message varchar(255) = '' OUTPUT
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set @message = ''
	
	declare @UniqueID int
	declare @continue int
	declare @Job_ID UNIQUEIDENTIFIER

	-- Parameters for calling xp_sqlagent_notify
	declare @op_type     NCHAR(1)
	declare @schedule_id INT
	declare @alert_id    INT
	declare @action_type NCHAR(1)
	declare @nt_user_name nvarchar(100)	
	declare @error_flag  INT				 -- Set to 0 to suppress the error from xp_sqlagent_notify if SQLServer agent is not running
	declare @wmi_namespace nvarchar(128)
	declare @wmi_query     nvarchar(512)
	declare @retval int

	set @op_type= N'J'
	set @schedule_id=Null
	set @alert_id=Null
	set @action_type=N'U'
	SELECT @nt_user_name = ISNULL(NT_CLIENT(), ISNULL(SUSER_SNAME(), FORMATMESSAGE(14205)))
	set @error_flag=1
	set @wmi_namespace=Null
	set @wmi_query=Null

	Declare @CategoryCount int
	
	--------------------------------------------
	-- Validate @EnableJobs
	--------------------------------------------
	Set @EnableJobs = IsNull(@EnableJobs, 1)
	If @EnableJobs <> 0 And @EnableJobs <> 1
		Set @EnableJobs = 1

	CREATE TABLE #TmpJobCategoryList (
		CategoryName varchar(512) NOT NULL,
		Category_ID int NULL
	)
	
	--------------------------------------------
	-- Split @CategoryName on commas and populate a temporary table
	--------------------------------------------
	
	INSERT INTO #TmpJobCategoryList (CategoryName)
	SELECT DISTINCT value
	FROM dbo.udfParseDelimitedList(@CategoryName, ',')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @message = 'Category list empty; unable to continue'
		Set @myError = 50000
		Goto Done
	End
	Else
		Set @CategoryCount = @myRowCount
	
	--------------------------------------------
	-- Look up the Category ID for the categories in #TmpJobCategoryList
	--------------------------------------------
	
	UPDATE #TmpJobCategoryList
	SET Category_ID = SC.Category_ID
	FROM #TmpJobCategoryList JCL INNER JOIN 
	     msdb.dbo.syscategories SC ON JCL.CategoryName = SC.Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		If @CategoryCount = 1
			Set @message = 'Category "' + @CategoryName + '" was not found in msdb.dbo.syscategories on server ' + @@ServerName
		Else
			Set @message = 'Categories in "' + @CategoryName + '" were not found in msdb.dbo.syscategories on server ' + @@ServerName

		Set @myError = 50001
		Goto Done
	End
	
	If @myRowCount < @CategoryCount
	Begin
		Set @message = 'Warning: 1 or more category names not found in msdb.dbo.syscategories on server ' + @@ServerName
	End

	If @Preview <> 0
		SELECT *
		FROM #TmpJobCategoryList
		ORDER BY CategoryName

	-- Remove unknown categories
	DELETE FROM #TmpJobCategoryList
	WHERE Category_ID Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	--------------------------------------------
	-- Populate a temporary table with the information
	-- for the jobs with categories defined in #TmpJobCategoryList
	--------------------------------------------

	CREATE TABLE #TmpJobsToUpdate (
		UniqueID int Identity(1,1),
		job_id UNIQUEIDENTIFIER,
		[Job_Name] [sysname] NOT NULL ,
		[Job_Enabled] [tinyint] NOT NULL ,
		[Job_Description] [nvarchar] (512) NULL ,
		[Category_Name] [sysname] NOT NULL 
	)
	
	INSERT INTO #TmpJobsToUpdate (
		job_id, Job_Name, Job_Enabled, Job_Description, Category_Name
	)
	SELECT S.job_id, S.[name], S.enabled, S.[description], C.[Name]
	FROM msdb.dbo.sysjobs AS S INNER JOIN 
			msdb.dbo.syscategories AS C ON S.Category_ID = C.Category_ID INNER JOIN
			#TmpJobCategoryList JCL ON S.Category_ID = JCL.Category_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @Preview = 1
		Set @message = 'Found '
	Else
	Begin
		If @EnableJobs = 0
			Set @message = 'Disabled '
		Else
			Set @message = 'Enabled '
	End
	Set @message = @message + Convert(Varchar(9), @myRowCount) + ' Jobs matching category(s) "' + @CategoryName + '" on server ' + @@ServerName

	If @Preview = 1
	Begin
		SELECT job_id, Job_Name, Job_Enabled, Job_Description, Category_Name
		FROM #TmpJobsToUpdate
		ORDER BY Job_Name
	End
	Else
	Begin -- <b>
	
		--------------------------------------------
		-- Enable or disable the matching jobs
		--
		-- Ideally we would now call msdb.dbo.sp_update_job 
		--  for each job in #TmpJobsToUpdate, for example:
		--  EXEC msdb.dbo.sp_update_job @Job_ID = @Job_ID, @enabled=@EnableJobs
		--
		-- However, when calling this SP from a linked server the call fails
		--  because MTUser is not a member of the sysadmin role, and sp_update_job
		--  aborts if that is the case
		-- So, instead we'll run an update query on msdb.dbo.sysjobs, and then
		--  we'll call master.dbo.xp_sqlagent_notify for each job in #TmpJobsToUpdate
		--  We have to call master.dbo.xp_sqlagent_notify, otherwise the job's new
		--  enabled/disabled state won't actually take effect
		--------------------------------------------
		
		UPDATE msdb.dbo.sysjobs
		SET Enabled = @EnableJobs
		FROM msdb.dbo.sysjobs SJ INNER JOIN 
				#TmpJobsToUpdate ON SJ.job_id = #TmpJobsToUpdate.job_id
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-- Loop through #TmpJobsToUpdate and call xp_sqlagent_notify for each job
		Set @UniqueID = 0
		Set @continue = 1
		While @Continue = 1
		Begin -- <c>
			SELECT TOP 1 @UniqueID = UniqueID,
							@Job_ID = Job_ID
			FROM #TmpJobsToUpdate
			WHERE UniqueID > @UniqueID
			ORDER BY UniqueID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			IF @myRowCount <> 1
				Set @Continue = 0
			Else
			Begin -- <d>
				-- Call xp_sqlagent_notify to keep SQLServerAgent's cache in-sync
				IF (EXISTS (SELECT *
							FROM msdb.dbo.sysjobservers
							WHERE (job_id = @Job_ID) AND (server_id = 0)))
				Begin -- <e>
					-- Call xp_sqlagent_notify
					-- We cannot use msdb.dbo.sp_sqlagent_notify when calling from a linked server
					--  because MTUser is not a member of the sysadmin role, and sp_sqlagent_notify
					--  aborts if that is the case
					--
					EXECUTE @retval = master.dbo.xp_sqlagent_notify @op_type, 
																	@job_id, 
																	@schedule_id, 
																	@alert_id, 
																	@action_type, 
																	@nt_user_name, 
																	@error_flag, 
																	@@trancount, 
																	@wmi_namespace, 
																	@wmi_query
				End -- </e>
			End -- </d>
		End -- </c>
		
	End -- </b>


Done:
	If @Preview <> 0
		SELECT @message AS Message

	Return @myError


GO
GRANT EXECUTE ON [dbo].[EnableDisableJobs] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EnableDisableJobs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EnableDisableJobs] TO [MTS_DB_Lite] AS [dbo]
GO

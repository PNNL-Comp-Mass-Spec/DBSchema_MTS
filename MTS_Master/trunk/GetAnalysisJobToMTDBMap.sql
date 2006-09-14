/****** Object:  StoredProcedure [dbo].[GetAnalysisJobToMTDBMap] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetAnalysisJobToMTDBMap
/****************************************************
**
**	Desc: Return list of analysis jobs present in MTDBs on the various MTS servers
**        
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	08/31/2006
**    
*****************************************************/
(
	@SummaryList tinyint = 1,				-- Set to 1 to include one row for each job, showing the first and last DB the job is in; set to 0 to show all DBs that the given job is in
	@IncludeDMSInfo tinyint = 0,			-- Set to 1 to link into DMS to return information; will also have the effect of hiding job numbers not present in DMS
	@JobMinimum int = 0,					-- Minimum job number; set both @JobMinimum and @JobMaximum to 0 to return all jobs
	@JobMaximum int = 0,					-- Maximum job number
	@DBNameFilter varchar(2048) = '',		-- Filter: Comma separated list of DB Names or list of DB name match criteria containing a wildcard character (%); for example, 'PT_BSA_A54, PT_Mouse_A66' or 'PT_BSA%'or 'PT_Mouse_A66, PT_BSA%'
	@ServerFilter varchar(128) = '',		-- If supplied, then only examines the databases on the given Server
	@MaximumRowCount int = 0,				-- Set to > 0 to limit the number of rows returned (will return newer jobs first)
	@message varchar(512)='' output
)
As	
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Exec @myError = GetAnalysisJobToDBMap 1, @SummaryList, @IncludeDMSInfo, @JobMinimum, @JobMaximum, @DBNameFilter, @ServerFilter, @MaximumRowCount, @message = @message output
	
	return @myError


GO
GRANT EXECUTE ON [dbo].[GetAnalysisJobToMTDBMap] TO [DMS_SP_User]
GO

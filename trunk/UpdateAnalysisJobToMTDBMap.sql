/****** Object:  StoredProcedure [dbo].[UpdateAnalysisJobToMTDBMap] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.UpdateAnalysisJobToMTDBMap
/****************************************************
**
**	Desc:	Updates the data in table T_Analysis_Job_to_MT_DB_Map by
**			polling MT_Main.dbo.T_Analysis_Job_to_MT_DB_Map on
**			each MTS server
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	08/30/2006
**			09/07/2006 mem - Now populating column Process_State
**    
*****************************************************/
(
	@ServerFilter varchar(128) = '',				-- If supplied, then only examines the given Server
	@PreviewSql tinyint = 0,
	@JobCountUpdatedTotal int = 0 OUTPUT,
	@message varchar(512)='' output
)
As	
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	
	Set @JobCountUpdatedTotal = 0
	Set @message = ''
	
	Declare @Sql nvarchar(2048)
	Declare @SrcSql nvarchar(2048)
	
	Declare @result int
	Set @result = 0

	Declare @ProcessSingleServer tinyint
	Declare @UsingLocalServer tinyint
	
	If Len(@ServerFilter) > 0
		Set @ProcessSingleServer = 1
	Else
		Set @ProcessSingleServer = 0

	Declare @Server varchar(128)
	Declare @ServerID int
	Declare @ServerIDText varchar(9)
	Declare @MTMain varchar(128)

	Declare @Continue int
	Declare @processCount int			-- Count of servers processed

	Declare @JobCountDeletedTotal int
	Set @JobCountDeletedTotal = 0

	-----------------------------------------------------------
	-- Create a temporary table to cache the data from remote MTS servers
	-----------------------------------------------------------
	--
	
	if exists (select * from dbo.sysobjects where id = object_id(N'[#Tmp_Analysis_Job_to_MT_DB_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#Tmp_Analysis_Job_to_MT_DB_Map]

	CREATE TABLE #Tmp_Analysis_Job_to_MT_DB_Map (
		Server_ID int NOT NULL ,
		Job int NOT NULL ,
		MTL_ID int NOT NULL ,
		ResultType varchar(32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		Created datetime NOT NULL ,
		Last_Affected datetime NOT NULL ,
		Process_State int NOT NULL
	)

	-- Add an index to #TmpNewAnalysisJobs on columns Server_ID, Job, and MTL_ID
	CREATE CLUSTERED INDEX #IX_Tmp_Analysis_Job_to_MT_DB_Map ON #Tmp_Analysis_Job_to_MT_DB_Map(Server_ID, Job, MTL_ID)

	-- Add an index suggested by the Database Engine Tuning Advisor
	CREATE NONCLUSTERED INDEX #IX_Tmp_Analysis_Job_to_MT_DB_Map_Server_Job_MTL_ID ON #Tmp_Analysis_Job_to_MT_DB_Map (Server_ID, Job, MTL_ID)
	INCLUDE (ResultType, Created, Last_Affected, Process_State)

	-----------------------------------------------------------
	-- Process each server in V_Active_MTS_Servers
	-----------------------------------------------------------
	--
	Set @processCount = 0
	Set @ServerID = -1
	Set @Continue = 1
	--	
	While @Continue > 0 and @myError = 0
	Begin -- <a>

		SELECT TOP 1
			@ServerID = Server_ID,
			@Server = Server_Name
		FROM  V_Active_MTS_Servers
		WHERE Server_ID > @ServerID
		ORDER BY Server_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Could not get next entry from V_Active_MTS_Servers'
			Set @myError = 50001
			Goto Done
		End
		Set @continue = @myRowCount

		If @continue > 0 And (@ProcessSingleServer = 0 Or Lower(@Server) = Lower(@ServerFilter))
		Begin -- <b>

			-- If @Server is actually this server, then we do not need to prepend table names with the text
			If Lower(@Server) = Lower(@@ServerName)
			Begin
				Set @UsingLocalServer = 1
				Set @MTMain = 'MT_Main.dbo.'
			End
			Else
			Begin
				Set @UsingLocalServer = 0
				Set @MTMain = @Server + '.MT_Main.dbo.'
			End

			Set @ServerIDText = Convert(varchar(9), @ServerID)


			---------------------------------------------------
			-- Construct the Sql to grab the data from T_MT_Database_List
			-- Exclude databases in State 15 = Moved to alternate server
			---------------------------------------------------
			Set @SrcSql = ''
			Set @SrcSql = @SrcSql + ' SELECT ' + @ServerIDText + ' AS Server_ID, AJDM.Job, AJDM.MTL_ID,'
			Set @SrcSql = @SrcSql +          ' AJDM.ResultType, AJDM.Created, AJDM.Last_Affected, IsNull(AJDM.Process_State, 0) AS Process_State'
			Set @SrcSql = @SrcSql + ' FROM ' + @MTMain + 'T_Analysis_Job_to_MT_DB_Map AJDM INNER JOIN '
			Set @SrcSql = @SrcSql +      ' ' + @MTMain + 'T_MT_Database_List MTL ON AJDM.MTL_ID = MTL.MTL_ID'
			Set @SrcSql = @SrcSql + ' WHERE MTL.MTL_State <> 15'

			If @UsingLocalServer = 0
			Begin
				---------------------------------------------------
				-- Polling a remote server; cache the data locally 
				-- since we need to examine it three times
				---------------------------------------------------

				TRUNCATE TABLE #Tmp_Analysis_Job_to_MT_DB_Map
				
				Set @Sql = ''
				Set @Sql = @Sql + ' INSERT INTO #Tmp_Analysis_Job_to_MT_DB_Map (Server_ID, Job, MTL_ID, ResultType,'
				Set @Sql = @Sql +                                             ' Created, Last_Affected, Process_State)'
				Set @Sql = @Sql + ' ' + @SrcSql
				
				If @PreviewSql <> 0
					Print @Sql
				Else
					EXEC sp_executesql @Sql	
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount	
				--
				If @myError <> 0 
				Begin
					Set @message = 'Error caching data from T_Analysis_Job_to_MT_DB_Map on server ' + @Server
					Set @myError = 50002
					Goto Done
				End

				Set @SrcSql =           ' SELECT Server_ID, Job, MTL_ID, ResultType, Created, Last_Affected, Process_State'
				Set @SrcSql = @SrcSql + ' FROM #Tmp_Analysis_Job_to_MT_DB_Map'
			End
			
			---------------------------------------------------
			-- Update T_Analysis_Job_to_MT_DB_Map
			---------------------------------------------------

			-- Delete extra entries
			Set @Sql = ''				
			Set @Sql = @Sql + ' DELETE MasterList'
			Set @Sql = @Sql + ' FROM T_Analysis_Job_to_MT_DB_Map MasterList LEFT OUTER JOIN'
			Set @Sql = @Sql +      ' ( ' + @SrcSql + ' ) SrcQ ON MasterList.Server_ID = SrcQ.Server_ID AND '
			Set @Sql = @Sql +                ' MasterList.Job = SrcQ.Job AND '
			Set @Sql = @Sql +                ' MasterList.MT_DB_ID = SrcQ.MTL_ID'
			Set @Sql = @Sql + ' WHERE MasterList.Server_ID = ' + @ServerIDText + ' AND'
			Set @Sql = @Sql +       ' SrcQ.Server_ID IS NULL'

			If @PreviewSql <> 0
				Print @Sql
			Else
				EXEC sp_executesql @Sql	
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount	
			--
			If @PreviewSql = 0
				Set @JobCountDeletedTotal = @JobCountDeletedTotal + @myRowCount
				
			If @myError <> 0 
			Begin
				Set @message = 'Error deleting extra entries from T_Analysis_Job_to_MT_DB_Map'
				Set @myError = 50002
				Goto Done
			End


			-- Update existing entries
			Set @Sql = ''				
			Set @Sql = @Sql + ' UPDATE MasterList'
			Set @Sql = @Sql + ' Set ResultType = SrcQ.ResultType, Created = SrcQ.Created,'
			Set @Sql = @Sql +     ' Last_Affected = SrcQ.Last_Affected, Process_State = SrcQ.Process_State'
			Set @Sql = @Sql + ' FROM T_Analysis_Job_to_MT_DB_Map MasterList INNER JOIN'
			Set @Sql = @Sql +     ' ( ' + @SrcSql + ' ) SrcQ ON MasterList.Server_ID = SrcQ.Server_ID AND '
			Set @Sql = @Sql +                ' MasterList.Job = SrcQ.Job AND '
			Set @Sql = @Sql +                ' MasterList.MT_DB_ID = SrcQ.MTL_ID'
			Set @Sql = @Sql + ' WHERE MasterList.Created <> SrcQ.Created OR'
			Set @Sql = @Sql +       ' MasterList.Last_Affected <> SrcQ.Last_Affected OR'
			Set @Sql = @Sql +       ' MasterList.Process_State <> SrcQ.Process_State'

			If @PreviewSql <> 0
				Print @Sql
			Else
				EXEC sp_executesql @Sql	
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount	
			--
			If @PreviewSql = 0
				Set @JobCountUpdatedTotal = @JobCountUpdatedTotal + @myRowCount

			If @myError <> 0 
			Begin
				Set @message = 'Error updating existing entries in T_Analysis_Job_to_MT_DB_Map'
				Set @myError = 50003
				Goto Done
			End
	
			
			-- Insert new entries
			Set @Sql = ''				
			Set @Sql = @Sql + ' INSERT INTO T_Analysis_Job_to_MT_DB_Map (Server_ID, Job, MT_DB_ID, ResultType,'
			Set @Sql = @Sql +                                          ' Created, Last_Affected, Process_State)'
			Set @Sql = @Sql + ' SELECT SrcQ.Server_ID, SrcQ.Job, SrcQ.MTL_ID, SrcQ.ResultType,'
			Set @Sql = @Sql +        ' SrcQ.Created, SrcQ.Last_Affected, SrcQ.Process_State'
			Set @Sql = @Sql + ' FROM T_Analysis_Job_to_MT_DB_Map MasterList RIGHT OUTER JOIN'
			Set @Sql = @Sql +      ' ( ' + @SrcSql + ' ) SrcQ ON MasterList.Server_ID = SrcQ.Server_ID AND '
			Set @Sql = @Sql +                ' MasterList.Job = SrcQ.Job AND '
			Set @Sql = @Sql +                ' MasterList.MT_DB_ID = SrcQ.MTL_ID'
			Set @Sql = @Sql + ' WHERE MasterList.Server_ID IS NULL'

			If @PreviewSql <> 0
				Print @Sql
			Else
				EXEC sp_executesql @Sql	
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount	
			--
			If @PreviewSql = 0
				Set @JobCountUpdatedTotal = @JobCountUpdatedTotal + @myRowCount
				
			If @myError <> 0 
			Begin
				Set @message = 'Error inserting new entries into T_Analysis_Job_to_MT_DB_Map'
				Set @myError = 50004
				Goto Done
			End

			Set @processCount = @processCount + 1
		End -- </b>
	End -- </a>

		
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	If @myError <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error updating T_Analysis_Job_to_MT_DB_Map; Error code: ' + convert(varchar(32), @myError)
		
		Exec PostLogEntry 'Error', @message, 'UpdateAnalysisJobToMTDBMap'
	End

	Declare @LogMessage varchar(256)
	Set @LogMessage = 'Updated job tracking for ' + Convert(varchar(9), @JobCountUpdatedTotal)
	If @JobCountUpdatedTotal = 1
		Set @LogMessage = @LogMessage + ' job'
	Else
		Set @LogMessage = @LogMessage + ' jobs'
	--
	Set @LogMessage = @LogMessage + ' on ' + Convert(varchar(9), @processCount) + ' servers'

	If @JobCountDeletedTotal > 0
	Begin
		Set @LogMessage = @LogMessage + '; Deleted ' + Convert(varchar(9), @JobCountDeletedTotal)
		If @JobCountDeletedTotal = 1
			Set @LogMessage = @LogMessage + ' job'
		Else
			Set @LogMessage = @LogMessage + ' jobs'
	End
	
	If @JobCountUpdatedTotal + @JobCountDeletedTotal > 0 
		Exec PostLogEntry 'Normal', @LogMessage, 'UpdateAnalysisJobToMTDBMap'
	
	If Len(@message) = 0
		Set @message = @LogMessage

	return @myError

GO

/****** Object:  StoredProcedure [dbo].[AckErrors] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.AckErrors
/****************************************************
** 
**	Desc:	Displays the errors in T_MTS_DB_Errors that have state DB_Error_State = 1
**
**			If @InfoOnly = 0, then Acknowledges the errors by changing the state of the errors to 2, then updating
**			 T_Log_Entries in the target DB to show ErrorIgnore instead of Error (skipping any DBs listed in @DBSkipList)
**
**			If @DaysToKeepAckedEntries is non-zero, then deletes old entries in T_MTS_DB_Errors that have DB_Error_State > 1
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	02/20/2008
**			03/28/2008 mem - Added parameter @DBMatchList
**			12/09/2008 mem - Updated to examine the value in @ErrorActionCode when calling AckError for each acknowledged error
**    
*****************************************************/
(
	@InfoOnly tinyint = 1,
	@DBMatchList varchar(2048) = '',			-- Databases to process; comma separated list of database names
	@DBSkipList varchar(2048) = '',				-- Databases to skip when @InfoOnly = 0; comma separated list of database names
	@ErrorHoldoffMinutes int = 30,
	@DaysToKeepAckedEntries int = 15,
	@PreviewSql tinyint= 0 ,
	@message varchar(255) = '' OUTPUT
)
As	
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @OnlyUseSpecifiedDBs tinyint
	Set @OnlyUseSpecifiedDBs = 0
	
	Declare @S varchar(2048)
	
	Declare @EntryCount int
	Set @EntryCount = 0
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	Set @ErrorHoldoffMinutes = IsNull(@ErrorHoldoffMinutes, 30)
	Set @DaysToKeepAckedEntries = IsNull(@DaysToKeepAckedEntries, 15)
	Set @DBMatchList = IsNull(@DBMatchList, '')
	Set @DBSkipList = IsNull(@DBSkipList, '')
	Set @InfoOnly = IsNull(@InfoOnly, 1)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	
	set @message = ''
	
	Declare @Sql nvarchar(2048)
	Declare @SqlParams nvarchar(256)
	Declare @CurrentServerPrefix varchar(128)

	Declare @SortID int
	Declare @EntryIDGlobal int
	Declare @Server varchar(128)
	Declare @DatabaseName varchar(256)
	Declare @PostedBy varchar(256)
	Declare @ErrorMessage varchar(4000)
	Declare @ErrorActionCode tinyint
	
	Declare @EntryID int
	Declare @EntryIDText varchar(24)
	
	Declare @Continue int
	Declare @result int
	
	---------------------------------------------------
	-- Create two temporary tables
	---------------------------------------------------
	
	CREATE TABLE #TmpDBsToSkip (
		Database_Name varchar(256) NOT NULL
	)
	
	If Len(@DBSkipList) > 0
	Begin
		INSERT INTO #TmpDBsToSkip (Database_Name)
		SELECT Value
		FROM dbo.udfParseDelimitedListOrdered(@DBSkipList, ',')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	
	End

	CREATE TABLE #TmpDBsToInclude (
		Database_Name varchar(256) NOT NULL
	)
	
	If Len(@DBMatchList) > 0
	Begin
		INSERT INTO #TmpDBsToInclude (Database_Name)
		SELECT Value
		FROM dbo.udfParseDelimitedListOrdered(@DBMatchList, ',')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @OnlyUseSpecifiedDBs = 1
	End
		
	--------------------------------------------------
	-- Create a temporary table to hold the entries to process
	--------------------------------------------------
	
	CREATE TABLE #TmpEntriesToProcess (
		SortID int Identity(1,1) NOT NULL,
		Entry_ID_Global int NOT NULL
	)

	CREATE UNIQUE CLUSTERED INDEX [#IX_TmpEntriesToProcess] ON [dbo].[#TmpEntriesToProcess] 
	(
		[SortID] ASC
	)
	
	---------------------------------------------------
	-- Populate #TmpEntriesToProcess with the entries in T_MTS_DB_Errors that have 
	-- state DB_Error_State =1 and are older than @ErrorHoldoffMinutes minutes
	---------------------------------------------------

	Set @S = ''
	
	Set @S = @S + ' INSERT INTO #TmpEntriesToProcess (Entry_ID_Global)'
	Set @S = @S + ' SELECT Entry_ID_Global'
	Set @S = @S + ' FROM T_MTS_DB_Errors'
	Set @S = @S + ' WHERE (DB_Error_State = 1) AND '
	Set @S = @S +       ' (NOT Database_Name IN (SELECT Database_Name FROM #TmpDBsToSkip)) AND'
	Set @S = @S +       ' (DATEDIFF(minute, Posting_Time, GETDATE()) > ' + Convert(varchar(12), @DaysToKeepAckedEntries) + ')'
	
	If @OnlyUseSpecifiedDBs <> 0
		Set @S = @S + ' AND (Database_Name IN (SELECT Database_Name FROM #TmpDBsToInclude))'
		
	Set @S = @S + ' ORDER BY Server_Name, Database_Name, Entry_ID_Global'
	
	If @PreviewSql <> 0
		Print @S
		
	Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	

	Set @EntryCount = @myRowCount
	
	If @InfoOnly <> 0
	Begin
		SELECT Server_Name, Database_Name, Entry_ID, Posted_By, 
			Posting_Time, Type, Message, Entered_By, 
			DB_Error_State
		FROM T_MTS_DB_Errors DBE INNER JOIN 
			 #TmpEntriesToProcess E ON DBE.Entry_ID_Global = E.Entry_ID_Global
		ORDER BY E.SortID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	
		
	End
	Else
	Begin -- <a>
	

		if @EntryCount > 0
		Begin -- <b>
			-- Process each of the items in #TmpEntriesToProcess
			
			Set @SortID = 0
			Set @Continue = 1
			While @Continue = 1
			Begin -- <c>
				SELECT TOP 1 @SortID = P.SortID,
							 @EntryIDGlobal = P.Entry_ID_Global,
							 @Server = DBE.Server_Name,
							 @DatabaseName = DBE.Database_Name,
							 @EntryID = DBE.Entry_ID,
							 @PostedBy = DBE.Posted_By,
							 @ErrorMessage = DBE.Message
				FROM #TmpEntriesToProcess P INNER JOIN 
				     T_MTS_DB_Errors DBE ON P.Entry_ID_Global = DBE.Entry_ID_Global
				WHERE P.SortID > @SortID
				ORDER BY P.SortID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount	
				
				If @myRowCount = 0
					Set @Continue = 0
				Else
				Begin -- <d>
					
					Set @EntryIDText = Convert(varchar(24), @EntryID)
					
					-- If @Server is actually this server, then we do not need to prepend the SP name with the text
					If Lower(@Server) = Lower(@@ServerName)
						Set @CurrentServerPrefix = ''
					Else
						Set @CurrentServerPrefix = @Server + '.'

					Set @Sql = 'exec ' + @CurrentServerPrefix + '[' + @DatabaseName + '].dbo.AckError ' + @EntryIDText + ', @ErrorActionCode = @ErrorActionCode OUTPUT'
					Set @SqlParams = '@ErrorActionCode tinyint OUTPUT'
					
					If @PreviewSql = 0
					Begin -- <e>
						EXEC @result = sp_executesql @sql, @SqlParams, @ErrorActionCode output
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						
						if @myError = 0 and @result = 0
						Begin
							UPDATE T_MTS_DB_Errors
							SET DB_Error_State = 2, 
								Last_Affected = GetDate(), 
								Ack_User = suser_sname()
							WHERE Entry_ID_Global = @EntryIDGlobal
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount	
							
							If @ErrorActionCode = 1
								Print 'Acknowledged entry ' + @EntryIDText + ' in database ' + @Server + '.' + @DatabaseName + '; ' + @PostedBy + ': ' + @ErrorMessage
							If @ErrorActionCode = 2
								Print 'Skipped entry      ' + @EntryIDText + ' in database ' + @Server + '.' + @DatabaseName + ' since already acknowledged'
							If @ErrorActionCode = 3
								Print 'Did not find entry ' + @EntryIDText + ' in database ' + @Server + '.' + @DatabaseName + '.T_Log_Entries'
							If @ErrorActionCode < 1 Or @ErrorActionCode > 3
								Print 'Unknown value for @ErrorActionCode for entry ' + @EntryIDText + ' in database ' + @Server + '.' + @DatabaseName + '; @ErrorActionCode = ' + Convert(varchar(12), @ErrorActionCode)

						End
						Else
						Begin
							Print 'Error calling the AckError procedure in database ' + @Server + '.' + @DatabaseName + ' for entry ' + @EntryIDText
						End
					End -- </e>
					Else
					Begin
						Print @Sql
					End			
				End -- </d>
			End -- </c>
		End -- </b>
		
		If @DaysToKeepAckedEntries > 0 And @PreviewSql = 0
		Begin
			DELETE FROM T_MTS_DB_Errors
			WHERE (DB_Error_State > 1) AND 
				(DATEDIFF(hour, Last_Affected, GETDATE()) / 24.0 >= @DaysToKeepAckedEntries)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount	
			
			If @myRowCount > 0
			Begin
				Set @message = 'Pruned ' + Convert(varchar(24), @myRowCount)
				If @myRowCount = 1
					Set @message = @message + ' entry'
				Else
					Set @message = @message + ' entries'
				
				Set @message = @message + ' from T_MTS_DB_Errors that are more than ' + Convert(varchar(24), @DaysToKeepAckedEntries) + ' days old'
				
				Exec PostLogEntry 'Normal', @message, 'AckErrors'
				
			End
		End
		
	End -- </a>

	
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[AckErrors] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AckErrors] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[KillProcsForDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[KillProcsForDB]
/****************************************************
**
**	Desc: Kills idle processes associated with the given database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/20/2006
**    
*****************************************************/
(
	@TargetDB varchar(128),					-- Database name to use when filtering processes
	@InfoOnly tinyint = 1,					-- Set to 1 to preview the processes that would be deleted
	@message varchar(255) = '' OUTPUT
)
As	
	set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @S varchar(1024)

	Declare @ProcCountDeleted int
	Set @ProcCountDeleted = 0

	Declare @SPID int
	Declare @continue int

	----------------------------------------------
	-- Construct the SQL to find the processes 
	-- associated with @TargetDB
	----------------------------------------------
	--
	Set @S =             ' SELECT spid'
	If @InfoOnly <> 0
	Begin
		Set @S = @S +      ' , ecid, status,'
		Set @S = @S +      ' loginame=rtrim(loginame),'
		Set @S = @S +      ' hostname, blk=convert(char(5),blocked),'
		Set @S = @S +      ' dbname = CASE WHEN dbid = 0 THEN null'
		Set @S = @S +                    ' WHEN dbid <> 0 THEN db_name(dbid)'
		Set @S = @S +               ' END,'
		Set @S = @S +      ' cmd, request_id'
	End
	Set @S = @S +        ' FROM  master.dbo.sysprocesses'
	Set @S = @S +        ' WHERE spid >= 0 AND spid <= 32765 AND '
	Set @S = @S +              ' dbid <> 0 AND '
	Set @S = @S +              ' db_name(dbid) = ''' + @TargetDB + ''' AND'
	Set @S = @S +              ' status NOT IN (''running'', ''suspended'')'

	If @InfoOnly = 0
	Begin
		create table #TmpProcsToKill (SPID int)
		Set @S = 'INSERT INTO #TmpProcsToKill (SPID) ' + @S
	End

	-- Run the SQL
	Exec (@S)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @myError <> 0
	Begin
		Set @message = 'Error querying sysprocesses using: ' + @S
		Goto Done
	End

	If @InfoOnly = 0
	Begin
		----------------------------------------------
		-- Loop through the entries in #TmpProcsToKill
		-- and delete each one
		----------------------------------------------
		--
		Set @continue = 1
		While @continue = 1
		Begin
			SELECT TOP 1 @SPID = SPID
			FROM #TmpProcsToKill
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myRowCount = 0
				Set @continue = 0
			Else
			Begin
				DELETE FROM #TmpProcsToKill
				WHERE SPID = @SPID

				Set @S = 'KILL ' + Convert(varchar(12), @SPID)
				Exec (@S)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				Set @ProcCountDeleted = @ProcCountDeleted + 1
			End
		End
		drop table #TmpProcsToKill

		Set @message = 'Killed ' + Convert(varchar(12), @ProcCountDeleted) + ' processes associated with database ' + @TargetDB
		SELECT @message as Message
	End

Done:

	Return @myError


GO

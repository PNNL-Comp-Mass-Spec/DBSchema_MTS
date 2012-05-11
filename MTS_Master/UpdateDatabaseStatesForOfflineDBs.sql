/****** Object:  StoredProcedure [dbo].[UpdateDatabaseStatesForOfflineDBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.UpdateDatabaseStatesForOfflineDBs
/****************************************************
** 
**	Desc: Updates the State_ID column in the master DB list tables
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	10/18/2011 mem - Initial version
**    
*****************************************************/
(
	@TableName varchar(64) = 'T_MTS_Peptide_DBs',
	@TableDescription varchar(16) = 'MT',
	@InfoOnly tinyint = 1,
	@message varchar(256) = '' output
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @S varchar(1024)
	Declare @OfflineThresholdDays varchar(12)
	Set @OfflineThresholdDays = 30
	
		
	Set	@InfoOnly = IsNull(@InfoOnly, 0)
	Set @message = ''
	
	--------------------------------------------------------
	-- Find databases in table @TableName that have been offline for at least 30 days
	--------------------------------------------------------
	--

	Set @S = ''
	If @InfoOnly = 0		
		Set @S = @S + ' UPDATE ' + @TableName + ' SET State_ID = 100'
	Else
		Set @S = @S + ' SELECT * FROM ' + @TableName
	
	Set @S = @S + ' WHERE State_ID < 15 AND Last_Online < DATEADD(day, -' + @OfflineThresholdDays + ', GETDATE())'
	
	Exec (@S)	
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myRowCount > 0 AND @InfoOnly = 0
	Begin
		Set @message = 'Changed ' + Convert(varchar(12), @myRowCount) + ' ' + @TableDescription + ' database'
		If @myRowCount <> 1
			Set @message = @message + 's'
			
		Set @message = @message + ' to state 100 since offline for at least ' + @OfflineThresholdDays + ' days'
		Exec PostLogEntry 'Normal', @message, 'UpdateDatabaseStatesForOfflineDBs'
	End
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--

	return @myError

GO

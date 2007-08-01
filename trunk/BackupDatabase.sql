/****** Object:  StoredProcedure [dbo].[BackupDatabase] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.BackupDatabase
/****************************************************
**
**	Desc: Backs up the given database to the given backup path
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 12/29/2004
**    
*****************************************************/
	@DBName varchar(128),
	@BackupPath varchar(255) = '',		-- Path to override value in T_Folder_Paths
	@message varchar(512) = '' Output
AS
	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	
	Declare @TimeStamp varchar(20)
	Declare @DevicePath varchar(400)
	
	If Len(IsNull(@BackupPath, '')) = 0
	Begin
		SELECT @BackupPath = Server_Path
		FROM T_Folder_Paths
		WHERE [Function] = 'Database Backup Path'
	End
	
	If Len(IsNull(@BackupPath, '')) = 0 Or Len(IsNull(@DBName, '')) = 0
	Begin
		Set @message = 'Please provide a valid database name and backup path'
		Select @message as Message
		Goto Done
	End
	
	
	If Right(@BackupPath, 1) <> '\'
		Set @BackupPath = @BackupPath + '\'
	
	-- Construct the time stamp: Year-Month-Day-Hour-Minute, for example: 200412291730
	Set @TimeStamp = Convert(varchar(9), Year(GetDate())) + Convert(varchar(9), Month(GetDate())) + Convert(varchar(9), Day(GetDate())) + Convert(varchar(9), DATEPART(hh, GetDate())) + Convert(varchar(9), DATEPART(mi, GetDate()))
	
	-- Define the path to the backup file
	Set @DevicePath = @BackupPath + @DBName + '\' + @DBName + '_db_' + @TimeStamp + '.BAK'
	
	-- Add the backup path as a new device
	exec @myError = sp_addumpdevice 'disk', 'BUDeviceTemp', @DevicePath
	
	if @myError <> 0
	Begin
		Set @message = 'Error creating device BUDeviceTemp with path ' + @DevicePath
		Goto Done
	End
	
	-- Backup the database to the device
	backup database @DBName to BUDeviceTemp
	
	-- Remove the device
	exec @myError = sp_dropdevice 'BUDeviceTemp'

Done:
	Return @myError

GO

/****** Object:  StoredProcedure [dbo].[BackupPTTemplateDatabase] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[BackupPTTemplateDatabase]
/****************************************************
**
**	Desc: Backs up the PT Template DB to PT_Template_01
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	05/19/2006
**          12/04/2019 mem - Change backup server to Proto-3
**    
*****************************************************/
(
	@BackupPath varchar(255) = '\\proto-3\DB_Backups\MTS_Templates\PT_Template_01',
	@message varchar(512) = '' Output
)
AS
	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	
	declare @DBName varchar(128)
	set @DBName = 'PT_Template_01'
		
	Declare @TimeStamp varchar(20)
	Declare @BackupFilePath varchar(400)
	Declare @BackupName varchar(128)
	
	If Len(IsNull(@BackupPath, '')) = 0
	Begin
		Set @message = 'The backup path must be defined'
		Select @message as Message
		Set @myError = 50000
		Goto Done
	End
	
	If Right(@BackupPath, 1) <> '\'
		Set @BackupPath = @BackupPath + '\'

	-- Define the path to the backup file
	Set @BackupFilePath = @BackupPath + @DBName + '.BAK'
	Set @BackupName = @DBName + '-Full Database Backup'
	
	-- Backup the database to the device
	BACKUP DATABASE @DBName TO  DISK = @BackupFilePath WITH NOFORMAT, INIT,  NAME = @BackupName, SKIP, NOREWIND, NOUNLOAD,  STATS = 10
	
	Set @message = 'Backed up ' + @DBName + ' to ' + @BackupFilePath
	Select @message as Message
	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[BackupPTTemplateDatabase] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[BackupPTTemplateDatabase] TO [MTS_DB_Lite] AS [dbo]
GO

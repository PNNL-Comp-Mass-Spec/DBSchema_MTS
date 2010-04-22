/****** Object:  StoredProcedure [dbo].[GetDBLocation] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetDBLocation
/****************************************************
**
**	Desc: Given a DB Name, returns the databases's
**			server name and full path to the database
**		  Also returns the DB ID and DB type
**		  If the DB Name contains the % sign wildcard, then returns the first
**			matching database (checking in the order given by T_MTS_DB_Types)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/25/2006
**    
*****************************************************/
(
	@DBName varchar(128) = 'MT_BSA_P171',
	@DBType tinyint = 0 output,		-- If 0, then will check all T_MTS tables to find DB; 
									-- If 1, then assumes a PMT tag DB (MT_), 
									-- If 2, then assumes a Peptide DB (PT_), 
									-- If 3, then assumes a Protein DB (ORF_), 
									-- If 4, then assumes a UMC DB (UMC_)
									-- If 5, then assumes a QC Trends DB (QCT_)
	@serverName varchar(64) = '' output,
	@DBPath varchar(256) = '' output,		-- Path to the DB, including the server name, e.g. ServerName.DBName
	@DBID int = 0 output,
	@message varchar(512) = '' output,
	@IncludeDeleted tinyint = 0
)
AS
	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @CallingServerName varchar(64)
	set @CallingServerName = @@ServerName
	
	exec Pogo.MTS_Master.dbo.GetDBLocation	@DBName, 
											@DBType output, 
											@serverName output, 
											@DBPath output, 
											@DBID output, 
											@message output, 
											@IncludeDeleted = @IncludeDeleted,
											@CallingServerName = @CallingServerName


	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(3), @IncludeDeleted)
	Exec PostUsageLogEntry 'GetDBLocation', '', @UsageMessage
	
Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[GetDBLocation] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDBLocation] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDBLocation] TO [MTS_DB_Lite] AS [dbo]
GO

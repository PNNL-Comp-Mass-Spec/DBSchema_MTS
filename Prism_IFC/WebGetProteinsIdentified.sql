/****** Object:  StoredProcedure [dbo].[WebGetProteinsIdentified] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE WebGetProteinsIdentified
/****************************************************
**
**	Desc: 
**	Wrapper for GetProteinsIdentified
**
**		Auth: grk
**		Date: 10/19/2004 grk - initial release
**    
*****************************************************/
	@MTDBName varchar(128) = '',
	@outputColumnNameList varchar(2048) = 'All',
	@criteriaSql varchar(6000) = 'na',
	@returnRowCount varchar(32) = 'False',
	@pepIdentMethod varchar(32) = 'DBSearch(MS/MS-LCQ)',
	@experiments varchar(7000) = 'All',
	@Proteins varchar(7000) = 'All',
	@maximumRowCount varchar(32) = '20',
	@includeSupersededData varchar(32) = 'False',
	@minimumPMTQualityScore varchar(32) = '1.0',
	@message varchar(512) = '' output
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	declare @mrc int
	set @mrc = cast(@maximumRowCount as int)
	
	declare @mpqs float
	set @mpqs = cast(@minimumPMTQualityScore as float)

	if @outputColumnNameList = 'All'
		set @outputColumnNameList = ''

	if @criteriaSql = 'na'
		set @criteriaSql = ''

	if @experiments = 'All'
		set @experiments = ''
	
	if @Proteins = 'All'
		set @Proteins = ''

	exec GetProteinsIdentified 	
			@MTDBName,
			@outputColumnNameList,
			@criteriaSql,
			@returnRowCount,
			@message output,
			@pepIdentMethod,
			@experiments,
			@Proteins,
			@mrc,
			@includeSupersededData,
			@mpqs
/**/
	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[WebGetProteinsIdentified] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebGetProteinsIdentified] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebGetProteinsIdentified] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[GetStatisticsFromExternalDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE GetStatisticsFromExternalDB
/****************************************************
** 
**		Desc: 
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: grk
**		Date: 2/19/2003
**    
*****************************************************/
	@dbName varchar(128) = 'MT_Shewanella_P14',
	@type varchar(8) = 'MT', -- 'PT'
	@mode varchar(24) = 'initial', -- 'final'
	@count1 int output,
	@count2 int output,
	@count3 int output,
	@count4 int output,
	@message varchar(512) output
AS
	SET NOCOUNT ON
	
	-- remember initial values of counts
	declare @count1o int
	declare @count2o int
	declare @count3o int
	declare @count4o int
	set @count1o = @count1
	set @count2o = @count2
	set @count3o = @count3
	set @count4o = @count4

	-- set up base SQL query
	--
	declare @myCount int
	declare @SQL nvarchar(512)

	declare @tableName varchar(64)

	if @type = 'MT'
	begin
		exec GetTableCountFromExternalDB @dbName, 'T_Peptides', @count1 output
		exec GetTableCountFromExternalDB @dbName, 'T_Mass_Tags', @count2 output
		exec GetTableCountFromExternalDB @dbName, 'T_Analysis_Description', @count3 output
		exec GetTableCountFromExternalDB @dbName, 'T_FTICR_Analysis_Description', @count4 output
		--
		if @mode = 'final'
		begin
			set @message = ''
			set @message = @message + ' PT:' + cast( (@count1 - @count1o) as varchar(12))
			set @message = @message + ' MT:' + cast( (@count2 - @count2o) as varchar(12))
			set @message = @message + ' AD:' + cast( (@count3 - @count3o) as varchar(12))
			set @message = @message + ' FAD:' + cast( (@count4 - @count4o) as varchar(12))
		end
	end
	
	if @type = 'PT'
	begin
		exec GetTableCountFromExternalDB @dbName, 'T_Peptides', @count1 output
		exec GetTableCountFromExternalDB @dbName, 'T_Sequence', @count2 output
		exec GetTableCountFromExternalDB @dbName, 'T_Analysis_Description', @count3 output
		--
		if @mode = 'final'
		begin
			set @message = ''
			set @message = @message + ' PT:' + cast( (@count1 - @count1o) as varchar(12))
			set @message = @message + ' SQ:' + cast( (@count2 - @count2o) as varchar(12))
			set @message = @message + ' AD:' + cast( (@count3 - @count3o) as varchar(12))
		end
	end


	RETURN 0



GO
GRANT EXECUTE ON [dbo].[GetStatisticsFromExternalDB] TO [DMS_SP_User]
GO

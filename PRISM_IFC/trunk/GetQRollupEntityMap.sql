/****** Object:  StoredProcedure [dbo].[GetQRollupEntityMap] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetQRollupEntityMap
/****************************************************
**
**	Desc: 
**	Returns list of MD_IDs and Jobs for all Q Rollups 
**  in given MTDB. Can optionally return only the values
**  for a given list of QIDs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@MTDBName				-- Mass tag database name
**		@ShowSuperseded			-- set to 1 to show superseded rollups, in addition to those with State = 3 (Success)
**      @outputColumnNameList	-- list of output columns to include in result set (ignored at present)
**		@QuantitationIDList		-- comma separated list of Quantitation ID values (optional)
**		@message        -- explanation of any error that occurred
**
**	Auth:	mem
**	Date:	10/05/2004
**			10/22/2004 mem - Added PostUsageLogEntry
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			02/20/2006 mem - Now validating that @MTDBName has a state less than 100 in MT_Main
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',
	@ShowSuperseded tinyint = 1,
	@outputColumnNameList varchar(1024) = '',	-- ignored at present
	@QuantitationIDList varchar(1024) = '',		-- Optional: comma separated list of Quantitation ID's
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- validate mass tag DB name
	---------------------------------------------------
	Declare @DBNameLookup varchar(256)
	SELECT  @DBNameLookup = MTL_ID
	FROM MT_Main.dbo.T_MT_Database_List
	WHERE (MTL_Name = @MTDBName) AND MTL_State < 100
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Could not resolve mass tag DB name'
		goto Done
	end

	---------------------------------------------------
	-- build basic query to retrieve data from V_IFC_QID_to_Job_Map
	---------------------------------------------------
	declare @sql nvarchar(1024)
	--
	set @sql = ''
	set @sql = @sql + ' SELECT * FROM DATABASE..V_IFC_QID_to_Job_Map'
	
	if @ShowSuperseded = 1
		set @sql = @sql + ' WHERE [Quantitation_State] = 3 OR [Quantitation_State] = 5'
	else
		set @sql = @sql + ' WHERE [Quantitation_State] = 3'
	
	if Len(IsNull(@QuantitationIDList, '')) > 0
		set @sql = @sql + ' AND Quantitation_ID In (' + @QuantitationIDList + ')'
	
	set @sql = @sql + ' ORDER BY Quantitation_ID, Job, MD_ID'
	
	---------------------------------------------------
	-- tailor basic query to specific MTDB
	---------------------------------------------------

	declare @s nvarchar(1024)
	set @s = ''
	--
	set @s = replace(@sql, 'DATABASE..', '[' + @MTDBName + ']..')

	if @s = ''
	begin
		set @message = 'Could not build dynamic SQL'
		goto Done
	end

	---------------------------------------------------
	-- Return Entities (MD_IDs and Jobs) for given Q Rollups
	---------------------------------------------------
	
	exec @result = sp_executesql @s
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows; ' + @QuantitationIDList
	Exec PostUsageLogEntry 'GetQRollupEntityMap', @MTDBName, @UsageMessage

	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetQRollupEntityMap] TO [DMS_SP_User]
GO

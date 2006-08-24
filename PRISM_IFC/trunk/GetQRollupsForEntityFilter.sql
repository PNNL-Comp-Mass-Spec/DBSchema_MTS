/****** Object:  StoredProcedure [dbo].[GetQRollupsForEntityFilter] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetQRollupsForEntityFilter
/****************************************************
**
**	Desc: 
**	Returns list of Quantitation_IDs that match the
**  given dataset and/or experiment filters in the given MTDB.
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@MTDBName				-- Mass tag database name
**      @DatasetFilter			-- Valid like-clause filter
**      @ExperimentFilter		-- Valid like-clause filter
**		@ShowSuperseded			-- set to 1 to show superseded rollups, in addition to those with State = 3 (Success)
**		@message				-- explanation of any error that occurred
**
**	Auth:	mem
**	Date:	12/27/2004
**			02/17/2005 mem - Added @RequiredQuantitationID parameter
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			02/20/2006 mem - Now validating that @MTDBName has a state less than 100 in MT_Main
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',
	@DatasetFilter varchar(1024) = '',			-- For example: Kolker%
	@ExperimentFilter varchar(1024) = '',		-- For example: QC%
	@RequiredQuantitationID int = 0,			-- If greater than 0, then requires that this QID be present
	@ShowSuperseded tinyint = 1,
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
	declare @sql nvarchar(2048)
	declare @QuantitationStateSql nvarchar(256)
	--
	set @sql = ''
	set @sql = @sql + ' SELECT DISTINCT QJM.Quantitation_ID, QD.SampleName, QJM.Dataset, QJM.Experiment'
	set @sql = @sql + ' FROM DATABASE..V_IFC_QID_to_Job_Map AS QJM INNER JOIN'
    set @sql = @sql + '      DATABASE..T_Quantitation_Description AS QD ON QJM.Quantitation_ID = QD.Quantitation_ID'
	
	if @ShowSuperseded = 1
		set @QuantitationStateSql = 'QD.Quantitation_State In (3,5)'
	else
		set @QuantitationStateSql = 'QD.Quantitation_State = 3'

	set @sql = @sql + ' WHERE (' + @QuantitationStateSql
	
	if Len(IsNull(@DatasetFilter, '')) > 0
		set @sql = @sql + ' AND QJM.Dataset Like ''' + @DatasetFilter + ''''

	if Len(IsNull(@ExperimentFilter, '')) > 0
		set @sql = @sql + ' AND QJM.Experiment Like ''' + @ExperimentFilter + ''''
	
	set @sql = @sql + ')'
	
	if IsNull(@RequiredQuantitationID, 0) > 0
		set @sql = @sql + ' OR (' + @QuantitationStateSql + ' AND QD.Quantitation_ID = ' + Convert(varchar(9), @RequiredQuantitationID) + ')'

	set @sql = @sql + ' ORDER BY QJM.Quantitation_ID'
	
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
	-- Return matching Q Rollups
	---------------------------------------------------
	
	exec @result = sp_executesql @s
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'GetQRollupsForEntityFilter', @MTDBName, @UsageMessage

	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetQRollupsForEntityFilter] TO [DMS_SP_User]
GO

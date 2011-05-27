/****** Object:  StoredProcedure [dbo].[GetQRollupsSummaryWithPath] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetQRollupsSummaryWithPath
/****************************************************
**
**	Desc: 
**	Returns summary list of Q Rollups for given
**	mass tag database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**      @MTDBName       -- name of mass tag database to use
**		@ShowSuperseded	-- set to 1 to show superseded rollups, in addition to those with State = 3 (Success)
**      @outputColumnNameList -- list of output columns to include in result set (ignored at present)
**		@message        -- explanation of any error that occurred
**
**	Auth:	mem
**	Date:	04/14/2004
**			05/12/2004 mem - Now returns [Results Folder Path] for each Q Rollup
**			05/19/2004 mem - Moved placement of the Results Folder Path field to be after the Comment field
**			10/22/2004 mem - Added PostUsageLogEntry
**			04/05/2005 mem - Now returns [Min High Discriminant Score] and [Min SLiC Score]
**			04/07/2005 mem - Now returns [Min Del SLiC Score]
**			05/25/2005 mem - Removed redundant entries for [Unique Mass Tag Count] and [Comparison Mass Tag Count]
**						   - Fixed logic bug involving @ShowSuperseded
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			02/20/2006 mem - Now validating that @MTDBName has a state less than 100 in MT_Main
**			09/07/2006 mem - Now returns [Min High Peptide Prophet Prob]
**			04/10/2007 mem - Replaced ..V_QR_SummaryList with .dbo.V_QR_SummaryList
**			06/13/2007 mem - Now returns [Max Matches per UMC]
**			11/27/2007 mem - Added parameters @QIDMinimum and @QIDMaximum
**			10/13/2010 mem - Now returns [AMT Count 5% FDR], [AMT Count 10% FDR], [AMT Count 25% FDR], [Min Uniq Prob], and [Max FDR]
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',					-- name of mass tag database to use
	@ShowSuperseded tinyint = 1,
	@outputColumnNameList varchar(1024) = '',		-- ignored at present
	@message varchar(512) = '' output,
	@InfoOnly tinyint = 0,
	@QIDMinimum int = 0,							-- Optional, filter
	@QIDMaximum int = 0
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
	-- Validate the inputs
	---------------------------------------------------
	Set @MTDBName = IsNull(@MTDBName, '')
	Set @ShowSuperseded = IsNull(@ShowSuperseded, 1)
	Set @QIDMinimum = IsNull(@QIDMinimum, 0)
	Set @QIDMaximum = IsNull(@QIDMaximum, 0)
	
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
	-- build basic query to get list of Q Rollups from MTDB
	---------------------------------------------------
	declare @sql nvarchar(1024)
	--
	set @sql = ''
	set @sql = @sql + ' SELECT '
	set @sql = @sql + ' QID, 0 as Sel, [Sample Name], Comment, [Results Folder Path],'
	set @sql = @sql + ' [Unique Mass Tag Count], [Comparison Mass Tag Count], '
	set @sql = @sql + ' [AMT Count 5% FDR], [AMT Count 10% FDR], [AMT Count 25% FDR], '
	set @sql = @sql + ' [Threshold % For Inclusion], Normalize, [Std Abu Min], [Std Abu Max],'
	set @sql = @sql + ' [Force Peak Max Abundance], [Min High MS/MS Score], [Min High Discriminant Score], [Min High Peptide Prophet Prob], [Min PMT Quality Score], '
	set @sql = @sql + ' [Max Matches per UMC], [Min SLiC Score], [Min Del SLiC Score],'
	set @sql = @sql + ' [Min Uniq Prob], [Max FDR],'
	set @sql = @sql + ' [Min Peptide Length], [Min Peptide Rep Count],'
	set @sql = @sql + ' [ORF Coverage Computation Level], [Rep Norm Stats],'
	set @sql = @sql + ' [Quantitation State ID], State, [Last Affected]'
	set @sql = @sql + ' FROM DATABASE..V_QR_SummaryList_Ex'
	
	if @ShowSuperseded = 1
		set @sql = @sql + ' WHERE ([Quantitation State ID] = 3 OR [Quantitation State ID] = 5)'
	else
		set @sql = @sql + ' WHERE ([Quantitation State ID] = 3)'
		
	If @QIDMinimum > 0
		set @sql = @sql + ' AND QID >= ' + Convert(varchar(12), @QIDMinimum)

	If @QIDMaximum > 0
		set @sql = @sql + ' AND QID <= ' + Convert(varchar(12), @QIDMaximum)
			
	---------------------------------------------------
	-- tailor basic query to specific MTDB
	---------------------------------------------------

	declare @s nvarchar(1024)
	set @s = ''
	--
	set @s = replace(@sql, 'DATABASE..', '[' + @MTDBName + '].dbo.')

	if @s = ''
	begin
		set @message = 'Could not build dynamic SQL'
		goto Done
	end

	---------------------------------------------------
	-- Return list of Q Rollups
	---------------------------------------------------
	
	if @InfoOnly = 1
		print @S
	else
	Begin
		exec @result = sp_executesql @s
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		Declare @UsageMessage varchar(512)
		Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
		Exec PostUsageLogEntry 'GetQRollupsSummary', @MTDBName, @UsageMessage
	End
		
	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[GetQRollupsSummaryWithPath] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetQRollupsSummaryWithPath] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetQRollupsSummaryWithPath] TO [MTS_DB_Lite] AS [dbo]
GO

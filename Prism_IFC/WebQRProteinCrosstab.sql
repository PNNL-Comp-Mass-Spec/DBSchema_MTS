/****** Object:  StoredProcedure [dbo].[WebQRProteinCrosstab] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.WebQRProteinCrosstab
/****************************************************	
**  Desc: Calls QRProteinCrosstab in the specified mass tag database
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: Mass Tag DB name, Source column name, and QID list
**
**  Auth: 	jee
**	Date:	04/15/2004
**			10/22/2004 mem - Added PostUsageLogEntry
**			11/19/2004 mem - Added three parameters: @SeparateReplicateDataIDs, @AggregateColName, and @AverageAcrossColumns
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			11/28/2006 mem - Added parameter @SortMode, which affects the order in which the results are returned
**			06/13/2007 mem - Expanded the size of @QuantitationIDList to varchar(4000)
**
****************************************************/
(
	@MTDBName varchar(128) = '',
	@SourceColName varchar(128) = 'Abundance_Average',	-- Column to return; use SP QRProteinCrosstabOutputColumns to see available column names
	@QuantitationIDList varchar(4000),					-- Comma separated list of Quantitation ID's
	@message varchar(512) = '' output,
	@SeparateReplicateDataIDs tinyint=1,
	@AggregateColName varchar(128) = '',
	@AverageAcrossColumns tinyint=1,					-- The query is slower if this is enabled
	@SortMode tinyint=0									-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(1024)
	declare @params nvarchar(1024)
	
	If Len(IsNull(@AggregateColName, '')) = 0
		set @AggregateColName = @SourceColName + '_Avg'
		
	set @stmt = N'exec [' + @MTDBName + N'].dbo.QRProteinCrosstab @QuantitationIDList, @SeparateReplicateDataIDs, @SourceColName, @AggregateColName, @AverageAcrossColumns, @SortMode'
	set @params = N'@QuantitationIDList varchar(max),@SeparateReplicateDataIDs tinyint,@SourceColName varchar(128),@AggregateColName varchar(128),@AverageAcrossColumns tinyint,@SortMode tinyint'
	exec @result = sp_executesql @stmt, @params, @QuantitationIDList = @QuantitationIDList, @SeparateReplicateDataIDs = @SeparateReplicateDataIDs, @SourceColName = @SourceColName, @AggregateColName = @AggregateColName, @AverageAcrossColumns = @AverageAcrossColumns, @SortMode = @SortMode
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = @QuantitationIDList + '; ' + @SourceColName
	Exec PostUsageLogEntry 'WebQRProteinCrosstab', @MTDBName, @UsageMessage

	set @message = ''
	RETURN @result


GO
GRANT EXECUTE ON [dbo].[WebQRProteinCrosstab] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebQRProteinCrosstab] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebQRProteinCrosstab] TO [MTS_DB_Lite] AS [dbo]
GO

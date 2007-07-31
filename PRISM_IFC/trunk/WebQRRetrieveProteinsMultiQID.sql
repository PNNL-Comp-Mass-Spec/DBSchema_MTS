/****** Object:  StoredProcedure [dbo].[WebQRRetrieveProteinsMultiQID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.WebQRRetrieveProteinsMultiQID
/****************************************************	
**  Desc: Calls QRRetrieveProteinsMultiQID in the specified mass tag database
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: Mass Tag DB name, QID list, and SeparateReplicateDataIDs option
**
**  Auth: 	jee
**	Date: 	04/15/2004
**			05/06/2004 mem - Added @SeparateReplicateDataIDs parameter
**			05/07/2004 mem - Increased variable size for @stmt from nvarchar(100) to nvarchar(512)
**			10/22/2004 mem - Added PostUsageLogEntry
**			11/19/2004 mem - Added @ReplicateCountAvgMinimum and @Description parameters
**			04/05/2005 mem - Added parameter @VerboseColumnOutput
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			11/28/2006 mem - Added parameter @SortMode, which affects the order in which the results are returned
**			06/13/2007 mem - Expanded the size of @QuantitationIDList to varchar(4000)
**
****************************************************/
(
	@MTDBName varchar(128) = '',				-- Name of mass tag database to use
	@QuantitationIDList varchar(4000),			-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 0,		-- Set to 1 to separate replicate-based QID's
	@message varchar(512) = '' output,
	@ReplicateCountAvgMinimum decimal(9,5)=1,	-- For replicated-based Q rollups, filters the data to only show the results present in this number of replicates or greater
	@Description varchar(32) = '' output,
	@VerboseColumnOutput tinyint = 0,			-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns (at present, this parameter is unused, but is included for symmetry with WebQRRetrievePeptidesMultiQID)
	@SortMode tinyint=2							-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(1024)
	declare @params nvarchar(1024)
	
	set @stmt = N'exec [' + @MTDBName + N'].dbo.QRRetrieveProteinsMultiQID @QuantitationIDList, @SeparateReplicateDataIDs, @ReplicateCountAvgMinimum, @Description OUTPUT, @VerboseColumnOutput, @SortMode'
	set @params = N'@QuantitationIDList varchar(max), @SeparateReplicateDataIDs tinyint, @ReplicateCountAvgMinimum decimal(9,5), @Description varchar(32) OUTPUT, @VerboseColumnOutput tinyint, @SortMode tinyint'
	exec @result = sp_executesql @stmt, @params, @QuantitationIDList = @QuantitationIDList, @SeparateReplicateDataIDs = @SeparateReplicateDataIDs, @ReplicateCountAvgMinimum = @ReplicateCountAvgMinimum, @Description = @Description OUTPUT, @VerboseColumnOutput = @VerboseColumnOutput, @SortMode = @SortMode
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = @QuantitationIDList
	Exec PostUsageLogEntry 'WebQRRetrieveProteinsMultiQID', @MTDBName, @UsageMessage

	set @message = ''
	RETURN @result


GO
GRANT EXECUTE ON [dbo].[WebQRRetrieveProteinsMultiQID] TO [DMS_SP_User]
GO

/****** Object:  StoredProcedure [dbo].[WebQRRetrievePeptidesMultiQID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.WebQRRetrievePeptidesMultiQID
/****************************************************	
**  Desc: Calls QRRetrievePeptidesMultiQID in the specified mass tag database
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: Mass Tag DB name, QID list, and SeparateReplicateDataIDs option
**
**  Auth:	jee
**	Date: 	04/15/2004
**			05/06/2004 mem - Added @SeparateReplicateDataIDs parameter
**			05/07/2004 mem - Increased variable size for @stmt from nvarchar(100) to nvarchar(512)
**			10/22/2004 mem - Added PostUsageLogEntry
**			11/19/2004 mem - Added IncludeRefColumn and @Description parameters
**			04/05/2005 mem - Added parameter @VerboseColumnOutput
**			08/25/2005 mem - Added parameter @IncludePrefixAndSuffixResidues
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
	@IncludeRefColumn tinyint = 1,				-- Set to 1 to include protein information along with the peptide information
	@Description varchar(32)='' OUTPUT,
	@VerboseColumnOutput tinyint = 0,				-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns
	@IncludePrefixAndSuffixResidues tinyint = 0,	-- The query is slower if this is enabled
	@SortMode tinyint=2								-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(1024)
	declare @params nvarchar(1024)
	
	set @stmt = N'exec [' + @MTDBName + N'].dbo.QRRetrievePeptidesMultiQID @QuantitationIDList, @SeparateReplicateDataIDs, @IncludeRefColumn, @Description OUTPUT, @VerboseColumnOutput, @IncludePrefixAndSuffixResidues, @SortMode'
	set @params = N'@QuantitationIDList varchar(max), @SeparateReplicateDataIDs tinyint, @IncludeRefColumn tinyint, @Description varchar(32) OUTPUT, @VerboseColumnOutput tinyint, @IncludePrefixAndSuffixResidues tinyint,@SortMode tinyint'
	exec @result = sp_executesql @stmt, @params, @QuantitationIDList = @QuantitationIDList, @SeparateReplicateDataIDs = @SeparateReplicateDataIDs, @IncludeRefColumn = @IncludeRefColumn, @Description = @Description OUTPUT, @VerboseColumnOutput = @VerboseColumnOutput, @IncludePrefixAndSuffixResidues = @IncludePrefixAndSuffixResidues, @SortMode = @SortMode
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = @QuantitationIDList
	Exec PostUsageLogEntry 'WebQRRetrievePeptidesMultiQID', @MTDBName, @UsageMessage

	set @message = ''
	RETURN @result


GO
GRANT EXECUTE ON [dbo].[WebQRRetrievePeptidesMultiQID] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebQRRetrievePeptidesMultiQID] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebQRRetrievePeptidesMultiQID] TO [MTS_DB_Lite] AS [dbo]
GO
